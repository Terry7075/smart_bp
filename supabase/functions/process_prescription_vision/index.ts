import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

/**
 * 「藥單 OCR 文字 → 結構化資料」邊緣函式。
 *
 * 流程：
 *   1. Client（Flutter）端使用 ML Kit 把照片離線 OCR 成純文字（`raw_text`）
 *   2. 本函式收到文字 → 用 Gemini「文字模式」整理成結構化 JSON
 *   3. 更新對應 `prescriptions` 列
 *
 * 必要 Secret：`GEMINI_API_KEY`
 * 選填 Secret：`GEMINI_MODEL`（預設 gemini-2.5-flash）
 */
const DEFAULT_GEMINI_MODEL = "gemini-2.5-flash";
const GEMINI_MODEL_FALLBACKS = [
  "gemini-2.5-flash",
  "gemini-2.0-flash-lite",
  "gemini-2.0-flash",
] as const;
const GEMINI_MAX_RETRIES = 2;
const GEMINI_FETCH_TIMEOUT_MS = 20_000;
const RATE_LIMIT_USER_MSG =
  "辨識服務目前太忙碌，請稍後約 1 分鐘再按「再試一次」。";
const OVERLOAD_USER_MSG =
  "AI 小幫手剛剛太忙，請等 30 秒到 1 分鐘後再按「再試一次」。";
const GEMINI_TRANSIENT_STATUSES = new Set([429, 500, 502, 503, 504]);

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type MedicationItem = {
  name?: string;
  genericName?: string;
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

/** systemInstruction：角色設定，與用戶資料分開有助模型更準確遵守規則。 */
function buildSystemInstruction(): string {
  return `你是台灣社區藥師，專門協助長輩整理藥袋資訊。
輸入是 ML Kit 對藥袋照片做 OCR 的原始文字：換行可能錯亂、字可能辨識錯（如 0/O/l/1 混淆）、含警語與條碼雜訊。
請利用上下文推斷正確內容，嚴格依規則輸出，不要加解釋或 markdown 圍欄。

【規則】
1. 過濾病患姓名、身分證、出生日期，不要寫進輸出。
2. hospitalName：取含「醫院」或「診所」的機構名稱（trim）；找不到填空字串。
3. pickupDateInferred：用「今天 + medicationDays」推算 yyyy-MM-dd；無法算時填空字串。
4. medicationDays：抓「共 N 天／給藥 N 日／N 天份」的整數；找不到填 0。
5. medications：陣列，每筆代表一種藥。
   - name：藥名（英文商品名 + 中文名，如「Olmetec 雅脈」）。
   - genericName：藥品「學名／英文成分名」，**極重要**。藥袋上通常印在括號內或英文那行，
     例如「雅脈 (Olmesartan)」→ genericName 填「Olmesartan」；
     「LODIGLIT 15/850」這類複方 → 填全部成分英文名，如「Sitagliptin Metformin」；
     「Amaride」(瑪爾胰) → 填「Glimepiride」。
     這個欄位用來比對藥典圖片，請務必盡力填出**英文成分名**；真的找不到才填空字串。
   - appearance：「顏色/形狀」格式，如「白色/雙凸形錠劑」、「粉紅/圓形」；找不到填空字串。
   - times：24h HH:mm 陣列，依以下對應：
       三餐飯後 / 三餐 → ["09:00","13:00","19:00"]
       三餐飯前       → ["08:00","12:00","18:00"]
       早晚飯後 / 早晚 → ["09:00","19:00"]
       早晚飯前       → ["08:00","18:00"]
       每日一次 / 一天一次 / QD → ["09:00"]
       每日兩次 / BID → ["09:00","19:00"]
       每日三次 / TID → ["09:00","13:00","19:00"]
       每日四次 / QID → ["09:00","13:00","19:00","22:00"]
       睡前 / HS（疊加，不互斥）→ 加上 "22:00"
       找不到時段 → []
   - specialInstructions：飯前／飯後／特殊注意等（簡短；找不到填空字串）`;
}

function buildUserPrompt(today: string, rawText: string): string {
  return `今天日期（台灣時區）：${today}

----- OCR 原始文字 -----
${rawText}
----- 結束 -----`;
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
    const generic = med.genericName?.trim();
    // 顯示／查詢藥名：把學名（英文成分）併進去，例如「雅脈 (Olmesartan)」。
    // 這樣藥典比對（name_en ilike）才命中得到——藥典是用學名建檔，藥袋印的是商品名。
    const displayName = name
      ? (generic && !name.toLowerCase().includes(generic.toLowerCase())
        ? `${name} (${generic})`
        : name)
      : generic;
    if (displayName) names.push(displayName);
    const app = med.appearance?.trim();
    if (app) appearances.push(app);
    for (const t of normalizeTimes(med.times)) timeSet.add(t);
    if (displayName) {
      lines.push(
        `${displayName}${app ? `（${app}）` : ""}${med.specialInstructions ? ` ${med.specialInstructions}` : ""}`,
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

/** Gemini responseSchema：強制輸出符合結構的 JSON。 */
const GEMINI_RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    hospitalName: { type: "string" },
    pickupDateInferred: { type: "string" },
    medicationDays: { type: "integer" },
    medications: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          genericName: { type: "string" },
          appearance: { type: "string" },
          times: { type: "array", items: { type: "string" } },
          specialInstructions: { type: "string" },
        },
      },
    },
  },
};

async function fetchWithTimeout(
  url: string,
  init: RequestInit,
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), GEMINI_FETCH_TIMEOUT_MS);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

async function callGeminiOnce(
  apiKey: string,
  model: string,
  rawText: string,
  today: string,
): Promise<Response> {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  const body = {
    systemInstruction: {
      parts: [{ text: buildSystemInstruction() }],
    },
    contents: [
      {
        role: "user",
        parts: [{ text: buildUserPrompt(today, rawText) }],
      },
    ],
    generationConfig: {
      temperature: 0.1,
      responseMimeType: "application/json",
      responseSchema: GEMINI_RESPONSE_SCHEMA,
    },
  };

  return fetchWithTimeout(url, {
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
        const waitMs = 1000 * Math.pow(2, attempt - 1);
        console.log(
          `[process_prescription_vision] Gemini retry ${attempt + 1}/${GEMINI_MAX_RETRIES} model=${model} after ${waitMs}ms`,
        );
        await sleep(waitMs);
      }

      let res: Response;
      try {
        res = await callGeminiOnce(apiKey, model, rawText, today);
      } catch (fetchErr) {
        // AbortError = timeout；其他為網路斷線，都當 transient 處理。
        const isAbort =
          fetchErr instanceof Error && fetchErr.name === "AbortError";
        console.error(
          `[process_prescription_vision] fetch error model=${model} attempt=${attempt + 1}:`,
          fetchErr,
        );
        sawOverload = true;
        if (isAbort) lastErrText = "timeout";
        if (attempt < GEMINI_MAX_RETRIES - 1) continue;
        break;
      }

      if (!res.ok) {
        lastStatus = res.status;
        lastErrText = await res.text();
        console.error(
          `[process_prescription_vision] Gemini HTTP ${res.status} model=${model}:`,
          lastErrText.slice(0, 300),
        );

        if (res.status === 429) {
          sawRateLimit = true;
          break;
        }
        if (GEMINI_TRANSIENT_STATUSES.has(res.status)) {
          sawOverload = true;
          if (attempt < GEMINI_MAX_RETRIES - 1) continue;
          break;
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
    return json({ error: "GEMINI_API_KEY 尚未設定" }, 500);
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

    // 注意：prescriptions 列已在 client 端以 vision_status='processing' insert，
    // 不需要再 update 一次，省掉一次 round-trip。
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
            status: "cancelled",
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
    return json(
      { error: userMessage, code },
      isRateLimit || isOverload ? 503 : 500,
    );
  }
});
