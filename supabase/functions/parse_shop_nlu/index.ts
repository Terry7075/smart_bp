import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const DEFAULT_GEMINI_MODEL = "gemini-2.5-flash";

type ShopNluJson = {
  confidence: number;
  source: string;
  intent: string;
  category_key?: string;
  category_label?: string;
  brand_name?: string;
  spec?: string;
  quantity?: number;
  unit_label?: string;
  price_preference?: string;
  wants_last_purchase?: boolean;
  missing_fields?: string[];
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function validateNlu(raw: Record<string, unknown>): ShopNluJson {
  const allowedIntents = [
    "record_demand",
    "query_price",
    "query_status",
    "cancel",
    "view_recorded",
    "casual",
  ];
  const allowedCategories = [
    "tissue",
    "egg",
    "milk",
    "rice",
    "oil",
    "detergent",
    "unknown",
  ];
  const intent = allowedIntents.includes(String(raw.intent))
    ? String(raw.intent)
    : "record_demand";
  let categoryKey = raw.category_key != null ? String(raw.category_key) : undefined;
  if (categoryKey && !allowedCategories.includes(categoryKey)) {
    categoryKey = "unknown";
  }
  const missing = Array.isArray(raw.missing_fields)
    ? raw.missing_fields.map(String).filter((f) =>
        ["category", "brand", "spec", "quantity"].includes(f)
      )
    : [];
  const conf = Math.min(1, Math.max(0, Number(raw.confidence) || 0.6));
  return {
    confidence: conf,
    source: "edge_gemini",
    intent,
    category_key: categoryKey,
    category_label: raw.category_label != null ? String(raw.category_label) : undefined,
    brand_name: raw.brand_name != null ? String(raw.brand_name) : undefined,
    spec: raw.spec != null ? String(raw.spec) : undefined,
    quantity: Math.max(1, Math.min(99, Number(raw.quantity) || 1)),
    unit_label: raw.unit_label != null ? String(raw.unit_label) : undefined,
    price_preference:
      raw.price_preference === "budget" ? "budget" : undefined,
    wants_last_purchase: raw.wants_last_purchase === true,
    missing_fields: missing,
  };
}

function buildPrompt(utterance: string): string {
  return `你是全聯物資代購 NLU 解析器。只回 JSON，不要 markdown。
輸入：「${utterance}」
輸出 schema：
{
  "confidence": 0.0-1.0,
  "intent": "record_demand|query_price|query_status|cancel|view_recorded|casual",
  "category_key": "tissue|egg|milk|rice|oil|detergent|unknown",
  "category_label": "中文品類",
  "brand_name": "品牌或null",
  "spec": "規格如抽取式/捲筒或null",
  "quantity": 整數,
  "unit_label": "包/顆/瓶等",
  "price_preference": "budget或null",
  "wants_last_purchase": boolean,
  "missing_fields": ["category","brand","spec"] 子集
}
規則：便宜/划算 → price_preference=budget；上次買的 → wants_last_purchase=true。`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  let body: { utterance?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid json" }, 400);
  }

  const utterance = body.utterance?.trim();
  if (!utterance) {
    return json({ error: "utterance required" }, 400);
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    const fallback = validateNlu({
      confidence: 0.5,
      intent: "record_demand",
      category_key: "unknown",
      missing_fields: ["category"],
    });
    return json({ result: { ...fallback, raw_utterance: utterance } });
  }

  const model = Deno.env.get("GEMINI_MODEL") ?? DEFAULT_GEMINI_MODEL;
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  const geminiRes = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: buildPrompt(utterance) }] }],
      generationConfig: {
        temperature: 0.1,
        responseMimeType: "application/json",
      },
    }),
  });

  if (!geminiRes.ok) {
    const errText = await geminiRes.text();
    console.error("gemini error", geminiRes.status, errText);
    return json({ error: "gemini unavailable" }, 503);
  }

  const geminiJson = await geminiRes.json();
  const text =
    geminiJson?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(text);
  } catch {
    parsed = { confidence: 0.55, intent: "record_demand", category_key: "unknown" };
  }

  const result = validateNlu(parsed);
  return json({
    result: {
      ...result,
      raw_utterance: utterance,
      match_layer: "edge_gemini",
    },
  });
});
