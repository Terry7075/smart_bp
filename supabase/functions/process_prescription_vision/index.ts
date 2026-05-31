import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

/**
 * 「藥單 OCR 文字 → 結構化資料」邊緣函式。
 *
 * 流程：
 *   1. Client（Flutter）端使用 ML Kit 把照片離線 OCR 成純文字（`raw_text`）
 *   2. 本函式收到文字 → 用 Gemini「文字模式」(`generateContent` 不附圖) 解析
 *      成 `{hospitalName, pickupDateInferred, medicationDays, medications}`
 *   3. 更新對應 `prescriptions` 列；UI 用回傳的 `data` 顯示確認頁
 *
 * 為什麼從 Vision 模式改成 OCR + Text 模式？
 * - Vision 端配額較緊、503 過載常見；text-only 流量便宜很多、過載罕見
 * - 不必上傳整張藥單圖到 Storage，省頻寬、保隱私
 * - ML Kit 中文辨識率對台灣藥袋（印刷字）很夠用，把「看字」交回裝置端
 */
/** Google AI Studio 已下架 gemini-1.5-flash；可用 Secret GEMINI_MODEL 覆寫 */
const DEFAULT_GEMINI_MODEL = "gemini-2.5-flash";
const GEMINI_MODEL_FALLBACKS = [
  "gemini-2.5-flash",
  "gemini-2.0-flash",
  "gemini-flash-latest",
] as const;
const GEMINI_MAX_RETRIES = 3;
const RATE_LIMIT_USER_MSG =
  "辨識服務目前太忙碌，請稍後約 1 分鐘再按「再試一次」。";
const OVERLOAD_USER_MSG =
  "AI 小幫手剛剛太忙，請等 30 秒到 1 分鐘後再按「再試一次」。";
/** Gemini 端可以視為「過載／暫時不可用」的 HTTP 狀態碼，全部走「換模型 +
 * 指數退避」的相同 retry 路徑。實務上 503 最常見（模型過載），但 502/504
 * 偶爾也會出現在 Google 自家 GFE 路徑。 */
const GEMINI_TRANSIENT_STATUSES = new Set([429, 500, 502, 503, 504]);

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type MedicationItem = {
  name?: string;
  appearance?: string;
  times?: string[];
  specialInstructions?: string;
};

type GeminiPayload = {
  hospitalName?: string;
  pickupDateInferred?: string;
  medicationDays?: number;
  medications?: MedicationItem[];
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function todayIsoInTaipei(): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Taipei",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  const y = parts.find((p) => p.type === "year")?.value ?? "1970";
  const m = parts.find((p) => p.type === "month")?.value ?? "01";
  const d = parts.find((p) => p.type === "day")?.value ?? "01";
  return `${y}-${m}-${d}`;
}

function buildSystemPrompt(today: string, rawText: string): string {
  // 「文字模式」prompt：把整段 OCR 文字當輸入，請 Gemini 萃取結構化欄位。
  // 設計重點：
  // - 明確告知這是 ML Kit OCR 出來的「雜訊文字」（換行不準、字會錯）
  // - 要求純 JSON，禁止 ```markdown``` 圍欄
  // - 給出 `today`，幫 Gemini 把「給藥天數」推成 `pickupDateInferred`
  // - 提示要過濾個資（姓名、身分證、生日），避免長輩資料寫進 notes
  return `你是一位台灣專業的社區藥師，現在正在協助長輩整理處方籤。
我會給你一段「ML Kit 從藥袋照片擷取出的 OCR 文字」，由於拍照角度與字體限制，
這段文字可能：(a) 順序錯亂；(b) 部分字辨識錯誤；(c) 含有警語、副作用、條碼亂碼等雜訊。
請利用上下文推斷正確內容，並嚴格依下列規則回傳：

1. 請過濾掉病患姓名、身分證字號、出生日期，不要寫進結果。
2. 「藥袋日期」優先採手寫標記；無手寫時用印刷日期。
3. 「服藥時段」請轉成 24 小時制 HH:mm 陣列。若藥單寫「三餐飯後」請輸出 ["08:00","13:00","19:00"]；
   「早晚飯後」輸出 ["08:00","19:00"]；「睡前」加上 "22:00"。
4. 「外觀」（appearance）寫法盡量「顏色/形狀」，例：粉紅/圓形、白色/橢圓形。
5. medicationDays 抓「共 N 天 / 給藥 N 日」這類數值；找不到回 null。
6. pickupDateInferred 用「今天 + medicationDays」推算；無 medicationDays 時回 null。

今天日期（台灣）是：${today}。
請務必嚴格以「純 JSON」回傳，不要包含 markdown 圍欄（不要 \`\`\`json ）：
{"hospitalName":"醫院名稱(trim後)","pickupDateInferred":"yyyy-MM-dd 或 null","medicationDays":28,"medications":[{"name":"藥名","appearance":"粉紅/圓形","times":["08:00","19:00"],"specialInstructions":"飯後服用"}]}

----- 以下是 OCR 原始文字 -----
${rawText}
----- 文字結束 -----`;
}

function parseGeminiJson(text: string): GeminiPayload {
  let cleaned = text.trim();
  if (cleaned.startsWith("```")) {
    cleaned = cleaned.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "");
  }
  const start = cleaned.indexOf("{");
  const end = cleaned.lastIndexOf("}");
  if (start >= 0 && end > start) {
    cleaned = cleaned.slice(start, end + 1);
  }
  return JSON.parse(cleaned) as GeminiPayload;
}

function normalizeTimes(times: string[] | undefined): string[] {
  if (!times?.length) return [];
  const out = new Set<string>();
  for (const t of times) {
    const m = t.trim().match(/^(\d{1,2})\s*[:：]\s*(\d{1,2})$/);
    if (!m) continue;
    const h = Number(m[1]);
    const min = Number(m[2]);
    if (h < 0 || h > 23 || min < 0 || min > 59) continue;
    out.add(
      `${h.toString().padStart(2, "0")}:${min.toString().padStart(2, "0")}`,
    );
  }
  return [...out].sort();
}

function aggregateMedications(meds: MedicationItem[]) {
  const names: string[] = [];
  const appearances: string[] = [];
  const timeSet = new Set<string>();
  const lines: string[] = [];

  for (const med of meds) {
    const name = med.name?.trim();
    if (name) names.push(name);
    const app = med.appearance?.trim();
    if (app) appearances.push(app);
    for (const t of normalizeTimes(med.times)) timeSet.add(t);
    if (name) {
      lines.push(
        `${name}${app ? `（${app}）` : ""}${med.specialInstructions ? ` ${med.specialInstructions}` : ""}`,
      );
    }
  }

  return {
    medicationName: names.length ? names.join("、") : null,
    pillAppearance: appearances.length ? appearances.join("；") : null,
    takeMedicineTimes: [...timeSet].sort(),
    notesPreview: lines.join("\n"),
  };
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function geminiModelsToTry(): string[] {
  const fromEnv = Deno.env.get("GEMINI_MODEL")?.trim();
  const ordered = [
    ...(fromEnv ? [fromEnv] : []),
    DEFAULT_GEMINI_MODEL,
    ...GEMINI_MODEL_FALLBACKS,
  ];
  return [...new Set(ordered)];
}

async function callGeminiOnce(
  apiKey: string,
  model: string,
  rawText: string,
  today: string,
): Promise<Response> {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  // 純文字模式：把 OCR 結果整段塞進 prompt，不再附帶 inlineData 圖片。
  const body = {
    contents: [
      {
        role: "user",
        parts: [
          { text: buildSystemPrompt(today, rawText) },
        ],
      },
    ],
    generationConfig: {
      temperature: 0.2,
      responseMimeType: "application/json",
    },
  };

  return fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

async function callGemini(
  apiKey: string,
  rawText: string,
  today: string,
): Promise<GeminiPayload> {
  const models = geminiModelsToTry();
  let lastStatus = 0;
  let lastErrText = "";
  let sawRateLimit = false;
  let sawOverload = false;

  for (const model of models) {
    for (let attempt = 0; attempt < GEMINI_MAX_RETRIES; attempt++) {
      if (attempt > 0) {
        // 指數退避：1s → 2s → 4s。Gemini 過載通常 5~10 秒會緩解，
        // 第三次 retry 對 503/500 還是常常救得回來。
        const waitMs = 1000 * Math.pow(2, attempt - 1);
        console.log(
          `[process_prescription_vision] Retry ${attempt + 1}/${GEMINI_MAX_RETRIES} model=${model} after ${waitMs}ms`,
        );
        await sleep(waitMs);
      }

      const res = await callGeminiOnce(apiKey, model, rawText, today);

      if (!res.ok) {
        lastStatus = res.status;
        lastErrText = await res.text();
        console.error(
          `[process_prescription_vision] Gemini HTTP ${res.status} model=${model} attempt=${attempt + 1}:`,
          lastErrText,
        );

        // 統一處理 429（rate limit）與 5xx（model overload / GFE 暫時不可用）：
        // 都是 transient 錯誤，先在本模型 retry；retry 用完再換 fallback 模型。
        if (GEMINI_TRANSIENT_STATUSES.has(res.status)) {
          if (res.status === 429) sawRateLimit = true;
          else sawOverload = true;
          if (attempt < GEMINI_MAX_RETRIES - 1) continue;
          break; // 換下一個模型
        }

        if (res.status === 404) break; // 模型已下線，換下一個

        throw new Error(
          `Gemini API 失敗 (${res.status}, model=${model})`,
        );
      }

      const data = await res.json();
      const text =
        data?.candidates?.[0]?.content?.parts?.map((p: { text?: string }) =>
          p.text ?? ""
        ).join("") ?? "";

      if (!text.trim()) {
        throw new Error("Gemini 回傳內容為空");
      }

      try {
        console.log(
          `[process_prescription_vision] Gemini OK model=${model}`,
        );
        return parseGeminiJson(text);
      } catch (e) {
        console.error("[process_prescription_vision] JSON parse failed:", text);
        throw new Error(`Gemini JSON 解析失敗: ${e}`);
      }
    }
  }

  // 全部 model × retry 都失敗，依「最常見的暫時錯誤」決定要哪一段給長輩看的訊息。
  if (sawRateLimit) {
    throw new Error(`RATE_LIMIT:${RATE_LIMIT_USER_MSG}`);
  }
  if (sawOverload) {
    throw new Error(`OVERLOAD:${OVERLOAD_USER_MSG}`);
  }

  throw new Error(
    `Gemini API 失敗 (${lastStatus})，已嘗試: ${models.join(", ")}${lastErrText ? ` — ${lastErrText.slice(0, 200)}` : ""}`,
  );
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const geminiKey = Deno.env.get("GEMINI_API_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    console.error("[process_prescription_vision] Missing Supabase env");
    return json({ error: "Server configuration error" }, 500);
  }
  if (!geminiKey) {
    console.error("[process_prescription_vision] Missing GEMINI_API_KEY");
    return json({ error: "GEMINI_API_KEY not configured" }, 500);
  }

  let prescriptionId = "";
  let storagePath = "";
  let rawText = "";

  try {
    const body = await req.json();
    prescriptionId = String(body?.prescription_id ?? "").trim();
    rawText = String(body?.raw_text ?? "");
    // storage_path 現為「選填」，僅作為原圖檔案備存路徑寫進 DB 方便日後追查；
    // 整個流程不再依賴 Storage 下載做 OCR/Vision。
    storagePath = String(body?.storage_path ?? "").trim();

    if (!prescriptionId) {
      return json({ error: "prescription_id 為必填" }, 400);
    }
    if (!rawText.trim()) {
      return json(
        {
          error:
            "raw_text 為必填：請在 client 端先以 ML Kit 取出文字後再呼叫此函式。",
        },
        400,
      );
    }
    // 上限保護：超過 12 KB 的文字幾乎全是 OCR 噪音（條碼、警語），裁掉避免 prompt 爆炸。
    if (rawText.length > 12000) {
      console.warn(
        `[process_prescription_vision] raw_text 過長 (${rawText.length}), 截斷至 12000`,
      );
      rawText = rawText.slice(0, 12000);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    await supabase
      .from("prescriptions")
      .update({ vision_status: "processing" })
      .eq("id", prescriptionId);

    const today = todayIsoInTaipei();
    const parsed = await callGemini(geminiKey, rawText, today);
    const meds = Array.isArray(parsed.medications) ? parsed.medications : [];
    const agg = aggregateMedications(meds);

    const hospitalName = parsed.hospitalName?.trim() || null;
    const pickupDate = parsed.pickupDateInferred?.trim() || null;
    const medicationDays =
      typeof parsed.medicationDays === "number"
        ? parsed.medicationDays
        : null;

    const updatePayload: Record<string, unknown> = {
      hospital_name: hospitalName,
      pickup_date: pickupDate,
      medication_days: medicationDays,
      medications_detail: meds,
      medication_name: agg.medicationName ?? "（藥名請見藥袋或備註）",
      pill_appearance: agg.pillAppearance,
      take_medicine_times: agg.takeMedicineTimes,
      vision_status: "completed",
      status: "active",
      source: "ocr",
      notes: agg.notesPreview || JSON.stringify(parsed),
    };
    // 只有當 client 真的上傳了原圖到 prescription-photos bucket 才寫入路徑。
    // 新流程預設不上傳，所以多數情況這欄會維持 NULL。
    if (storagePath) {
      updatePayload.photo_storage_path = storagePath;
    }

    const { error: updateError } = await supabase
      .from("prescriptions")
      .update(updatePayload)
      .eq("id", prescriptionId);

    if (updateError) {
      console.error(
        "[process_prescription_vision] DB update failed:",
        updateError,
      );
      return json({ error: "資料庫更新失敗", detail: updateError.message }, 500);
    }

    return json({
      ok: true,
      prescription_id: prescriptionId,
      data: {
        hospitalName,
        pickupDateInferred: pickupDate,
        medicationDays,
        medications: meds,
        takeMedicineTimes: agg.takeMedicineTimes,
        medicationName: agg.medicationName,
        pillAppearance: agg.pillAppearance,
        isInferred: Boolean(pickupDate && medicationDays),
      },
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    // 兩種 prefix 各對應一個既定的 client-friendly 訊息；rate_limit 是「服務太忙」，
    // overload 是「AI 模型過載」。前端依 code 決定要不要 retry／顯示哪一條訊息。
    const isRateLimit = message.startsWith("RATE_LIMIT:");
    const isOverload = message.startsWith("OVERLOAD:");
    const userMessage = isRateLimit
      ? message.slice("RATE_LIMIT:".length)
      : isOverload
      ? message.slice("OVERLOAD:".length)
      : message;
    console.error("[process_prescription_vision] Unhandled:", message);

    if (prescriptionId) {
      try {
        const supabase = createClient(
          supabaseUrl!,
          serviceRoleKey!,
          { auth: { persistSession: false } },
        );
        await supabase
          .from("prescriptions")
          .update({
            vision_status: "failed",
            notes: `Vision 失敗: ${userMessage}`,
          })
          .eq("id", prescriptionId);
      } catch (inner) {
        console.error("[process_prescription_vision] Failed status update:", inner);
      }
    }

    const code = isRateLimit
      ? "rate_limit"
      : isOverload
      ? "overload"
      : undefined;
    // 對 client 統一回 503（暫時不可用，建議稍後重試）／ 500（伺服器錯誤）。
    // 用 503 是因為 supabase_flutter 的 FunctionException 可以靠 status 判斷
    // 「是否值得自動重試」。
    return json(
      { error: userMessage, code },
      isRateLimit || isOverload ? 503 : 500,
    );
  }
});
