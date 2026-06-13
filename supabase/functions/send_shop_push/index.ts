import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@9";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isDeliverableFcmToken(token: string): boolean {
  if (!token || token.length < 20) return false;
  const lower = token.toLowerCase();
  if (lower.includes("pending") || lower.startsWith("debug_")) return false;
  return true;
}

function buildFcmDataPayload(
  body: {
    title?: string;
    body_text?: string;
    payload?: Record<string, unknown>;
  },
  route: string,
): Record<string, string> {
  const data: Record<string, string> = {
    click_action: "FLUTTER_NOTIFICATION_CLICK",
    route,
    title: body.title ?? "明德 e 達人",
    body_text: body.body_text ?? "您有新的代購通知",
  };
  if (body.payload) {
    for (const [k, v] of Object.entries(body.payload)) {
      if (v != null) data[k] = String(v);
    }
  }
  return data;
}

async function fetchAndroidTokens(
  admin: ReturnType<typeof createClient>,
  userIds: string[],
  platformFilter: string,
): Promise<string[]> {
  if (userIds.length === 0) return [];
  const { data } = await admin
    .from("device_tokens")
    .select("fcm_token")
    .in("user_id", userIds)
    .eq("platform", platformFilter);
  const raw: string[] = [];
  for (const row of data ?? []) {
    if (row.fcm_token) raw.push(row.fcm_token);
  }
  return [...new Set(raw)].filter(isDeliverableFcmToken);
}

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

let cachedAccessToken: { token: string; expiresAt: number } | null = null;

async function getFcmV1AccessToken(sa: ServiceAccount): Promise<string> {
  const now = Date.now();
  if (cachedAccessToken && cachedAccessToken.expiresAt > now + 60_000) {
    return cachedAccessToken.token;
  }
  const client = new JWT({
    email: sa.client_email,
    key: sa.private_key,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const creds = await client.authorize();
  const token = creds.access_token;
  if (!token) throw new Error("FCM OAuth token missing");
  cachedAccessToken = {
    token,
    expiresAt: now + (creds.expiry_date ?? now + 3_500_000),
  };
  return token;
}

async function sendFcmV1One(
  projectId: string,
  accessToken: string,
  fcmToken: string,
  title: string,
  bodyText: string,
  dataPayload: Record<string, string>,
): Promise<number> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title, body: bodyText },
          data: dataPayload,
          android: {
            priority: "HIGH",
            notification: { channel_id: "mindu_order_status" },
          },
        },
      }),
    },
  );
  return res.status;
}

async function sendFcmLegacyBatch(
  fcmKey: string,
  tokens: string[],
  title: string,
  bodyText: string,
  dataPayload: Record<string, string>,
): Promise<{ success: boolean; status: number | null }> {
  if (tokens.length === 0) return { success: false, status: null };
  const fcmRes = await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      Authorization: `key=${fcmKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      registration_ids: tokens,
      priority: "high",
      notification: { title, body: bodyText },
      data: dataPayload,
    }),
  });
  return { success: fcmRes.ok, status: fcmRes.status };
}

async function sendToTokens(
  tokens: string[],
  title: string,
  bodyText: string,
  dataPayload: Record<string, string>,
  fcmKey: string | undefined,
  serviceAccount: ServiceAccount | null,
): Promise<{ success: boolean; statuses: number[] }> {
  if (tokens.length === 0) return { success: false, statuses: [] };

  const statuses: number[] = [];

  if (serviceAccount) {
    const accessToken = await getFcmV1AccessToken(serviceAccount);
    let anyOk = false;
    for (const t of tokens) {
      const status = await sendFcmV1One(
        serviceAccount.project_id,
        accessToken,
        t,
        title,
        bodyText,
        dataPayload,
      );
      statuses.push(status);
      if (status >= 200 && status < 300) anyOk = true;
    }
    return { success: anyOk, statuses };
  }

  if (fcmKey) {
    const { success, status } = await sendFcmLegacyBatch(
      fcmKey,
      tokens,
      title,
      bodyText,
      dataPayload,
    );
    if (status != null) statuses.push(status);
    return { success, statuses };
  }

  return { success: false, statuses };
}

function parseServiceAccount(raw: string | undefined): ServiceAccount | null {
  if (!raw?.trim()) return null;
  try {
    const j = JSON.parse(raw);
    if (j.project_id && j.client_email && j.private_key) {
      return j as ServiceAccount;
    }
  } catch {
    return null;
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const fcmKey = Deno.env.get("FCM_SERVER_KEY");
  const serviceAccount = parseServiceAccount(
    Deno.env.get("FCM_SERVICE_ACCOUNT_JSON"),
  );

  if (!serviceKey || !supabaseUrl) {
    return json({ error: "server misconfigured" }, 500);
  }

  const fcmReady = !!serviceAccount || !!fcmKey;

  let body: {
    user_id?: string;
    user_ids?: string[];
    elder_user_id?: string;
    target_role?: string;
    event_type?: string;
    title?: string;
    body_text?: string;
    payload?: Record<string, unknown>;
    platform?: string;
  };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid json" }, 400);
  }

  const platformFilter = body.platform ?? "android";
  const admin = createClient(supabaseUrl, serviceKey);
  const title = body.title ?? "明德 e 達人";
  const bodyText = body.body_text ?? "您有新的代購通知";
  const defaultRoute =
    typeof body.payload?.route === "string"
      ? body.payload.route
      : "/volunteer/shop-orders";
  let totalTokens = 0;
  let anySuccess = false;
  const fcmStatuses: number[] = [];

  const dispatch = async (userIds: string[], route: string) => {
    const tokens = await fetchAndroidTokens(admin, userIds, platformFilter);
    totalTokens += tokens.length;
    if (!fcmReady || tokens.length === 0) return;
    const dataPayload = buildFcmDataPayload(body, route);
    const { success, statuses } = await sendToTokens(
      tokens,
      title,
      bodyText,
      dataPayload,
      fcmKey,
      serviceAccount,
    );
    if (success) anySuccess = true;
    fcmStatuses.push(...statuses);
  };

  if (body.elder_user_id) {
    await dispatch([body.elder_user_id], defaultRoute);
  } else if (body.user_ids && body.user_ids.length > 0) {
    await dispatch(body.user_ids, defaultRoute);
  } else if (body.user_id) {
    await dispatch([body.user_id], defaultRoute);
  } else if (body.target_role) {
    const { data: profiles } = await admin
      .from("profiles")
      .select("id")
      .eq("role", body.target_role);
    const ids = (profiles ?? []).map((p: { id: string }) => p.id);
    await dispatch(ids, defaultRoute);
  }

  await admin.from("push_notifications_log").insert({
    user_id: body.user_id ?? body.elder_user_id ?? null,
    event_type: body.event_type ?? "shop_event",
    payload: {
      ...(body.payload ?? {}),
      platform: platformFilter,
      fcm_api: serviceAccount ? "v1" : fcmKey ? "legacy" : "none",
      fcm_statuses: fcmStatuses,
      token_count: totalTokens,
    },
    success: anySuccess,
  });

  return json({
    ok: true,
    sent: anySuccess,
    token_count: totalTokens,
    platform: platformFilter,
    fcm_api: serviceAccount ? "v1" : fcmKey ? "legacy" : "none",
    degraded: !fcmReady,
  });
});
