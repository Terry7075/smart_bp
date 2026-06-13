import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const DEFAULT_GEMINI_MODEL = "gemini-2.5-flash";
const GEMINI_MODEL_FALLBACKS = [
  "gemini-2.5-flash",
  "gemini-2.0-flash",
  "gemini-2.0-flash-lite",
];
const GEMINI_MAX_RETRIES = 2;
const GEMINI_FETCH_TIMEOUT_MS = 25_000;
const GEMINI_TRANSIENT_STATUSES = new Set([429, 500, 502, 503, 504]);

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
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

function buildSystemPrompt(
  displayName?: string,
  contextSummary?: string,
): string {
  const who = displayName?.trim()
    ? `使用者叫做${displayName.trim()}，`
    : "";
  const ctx = contextSummary?.trim()
    ? `\n以下為 App 內真實資料摘要（僅供參考，不可捏造）：\n${contextSummary.trim()}`
    : "";
  return `你是明德 e 達人社區 App 的小幫手，用繁體中文、口語、親切陪長輩聊天。
${who}語氣像鄰居，不要像客服制式稿；每次 2～4 句，不超過 120 字。
對方問天氣、日常閒聊、新聞概況時，請像聊天一樣自然回答；天氣若不確定可建議看中央氣象署，不要捏造精確數字。
若對方問藥單、代購、App 功能，優先依下方資料摘要回答；沒有資料時可輕鬆帶一句「要我幫您查進度也可以說」。
不可捏造醫療建議；健康問題請建議洽醫師或藥師。${ctx}`;
}

type ChatMessage = { role?: string; content?: string };

function buildContents(
  history: ChatMessage[],
  question: string,
): { role: string; parts: { text: string }[] }[] {
  const contents: { role: string; parts: { text: string }[] }[] = [];
  for (const m of history.slice(-8)) {
    const content = m.content?.trim();
    if (!content) continue;
    const role = m.role === "assistant" ? "model" : "user";
    contents.push({ role, parts: [{ text: content }] });
  }
  contents.push({ role: "user", parts: [{ text: question }] });
  return contents;
}

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
  displayName: string | undefined,
  contextSummary: string | undefined,
  contents: { role: string; parts: { text: string }[] }[],
): Promise<Response> {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  return fetchWithTimeout(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      systemInstruction: {
        parts: [{ text: buildSystemPrompt(displayName, contextSummary) }],
      },
      contents,
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 256,
      },
    }),
  });
}

async function callGemini(
  apiKey: string,
  displayName: string | undefined,
  contextSummary: string | undefined,
  contents: { role: string; parts: { text: string }[] }[],
): Promise<string> {
  const models = geminiModelsToTry();
  let lastErrText = "";

  for (const model of models) {
    for (let attempt = 0; attempt < GEMINI_MAX_RETRIES; attempt++) {
      if (attempt > 0) {
        await sleep(1000 * Math.pow(2, attempt - 1));
      }
      const res = await callGeminiOnce(
        apiKey,
        model,
        displayName,
        contextSummary,
        contents,
      );
      if (res.ok) {
        const geminiJson = await res.json();
        const reply =
          geminiJson?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? "";
        if (reply) return reply;
        lastErrText = "empty reply";
        continue;
      }

      lastErrText = await res.text();
      console.error(
        `assistant_casual_chat gemini model=${model} status=${res.status}`,
        lastErrText,
      );
      if (!GEMINI_TRANSIENT_STATUSES.has(res.status)) {
        break;
      }
    }
  }

  throw new Error(lastErrText || "gemini unavailable");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  let body: {
    question?: string;
    display_name?: string;
    context_summary?: string;
    messages?: ChatMessage[];
  };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid json" }, 400);
  }

  const question = body.question?.trim();
  if (!question) {
    return json({ error: "question required" }, 400);
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    return json({ error: "GEMINI_API_KEY not configured" }, 503);
  }

  try {
    const contents = buildContents(body.messages ?? [], question);
    const reply = await callGemini(
      apiKey,
      body.display_name,
      body.context_summary,
      contents,
    );
    return json({ reply, source: "edge_gemini" });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    console.error("assistant_casual_chat failed", message);
    return json({ error: "gemini unavailable", detail: message }, 503);
  }
});
