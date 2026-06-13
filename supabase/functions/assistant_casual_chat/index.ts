import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const DEFAULT_GEMINI_MODEL = "gemini-2.5-flash";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function buildSystemPrompt(displayName?: string): string {
  const who = displayName?.trim()
    ? `使用者叫做${displayName.trim()}，`
    : "";
  return `你是明德 e 達人社區 App 的小幫手，用繁體中文、口語、親切陪長輩聊天。
${who}語氣像鄰居，不要像客服制式稿；每次 2～4 句，不超過 120 字。
若對方問藥單、代購、App 功能，可輕鬆帶一句「要我幫您查進度也可以說」。
不可捏造醫療建議；健康問題請建議洽醫師或藥師。`;
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
    messages?: { role?: string; content?: string }[];
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

  const model = Deno.env.get("GEMINI_MODEL") ?? DEFAULT_GEMINI_MODEL;
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  const history = (body.messages ?? []).slice(-8);
  const parts: { text: string }[] = [
    { text: buildSystemPrompt(body.display_name) },
  ];
  for (const m of history) {
    const role = m.role === "assistant" ? "model" : "user";
    const content = m.content?.trim();
    if (!content) continue;
    parts.push({ text: `[${role}]: ${content}` });
  }
  parts.push({ text: `[user]: ${question}` });

  const geminiRes = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts }],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 256,
      },
    }),
  });

  if (!geminiRes.ok) {
    const errText = await geminiRes.text();
    console.error("assistant_casual_chat gemini", geminiRes.status, errText);
    return json({ error: "gemini unavailable" }, 503);
  }

  const geminiJson = await geminiRes.json();
  const reply =
    geminiJson?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? "";
  if (!reply) {
    return json({ error: "empty reply" }, 502);
  }

  return json({ reply, source: "edge_gemini" });
});
