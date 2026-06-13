// Supabase Edge Function: check_health_alerts
//
// 讀取每位 elder 的最新健康指標，對照 alert_rules 表，
// 判斷是否超出閾值 + 冷卻時間，若是則寫入 notification_outbox。
//
// 觸發方式：
//   - Supabase Cron（每 5–10 分鐘）
//   - 或長輩 / 志工開監測頁時前端手動 invoke 一次

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

interface AlertRule {
  id: string;
  metric_type: string;
  min_value: number | null;
  max_value: number | null;
  severity: string;
  cooldown_minutes: number;
}

interface MetricRow {
  user_id: string;
  metric_type: string;
  value: number;
  recorded_at: string;
}

interface Profile {
  id: string;
  name: string;
}

Deno.serve(async (_req) => {
  try {
    // 1. 取所有啟用的告警規則
    const { data: rules, error: ruleErr } = await supabase
      .from("alert_rules")
      .select("id, metric_type, min_value, max_value, severity, cooldown_minutes")
      .eq("enabled", true);

    if (ruleErr) throw ruleErr;
    if (!rules || rules.length === 0) {
      return new Response(JSON.stringify({ processed: 0 }), { status: 200 });
    }

    // 2. 取所有 elder profiles
    const { data: elders, error: elderErr } = await supabase
      .from("profiles")
      .select("id, name")
      .eq("role", "elder");

    if (elderErr) throw elderErr;
    if (!elders || elders.length === 0) {
      return new Response(JSON.stringify({ processed: 0 }), { status: 200 });
    }

    // 3. 取全部 volunteer 的 id，用於廣播 outbox
    const { data: volunteers } = await supabase
      .from("profiles")
      .select("id")
      .eq("role", "volunteer");

    const volunteerIds: string[] = (volunteers ?? []).map((v: { id: string }) => v.id);

    // 4. 對每位長輩 × 每條規則評估
    const windowMs = 15 * 60 * 1000; // 讀最近 15 分鐘的指標
    const now = new Date();
    const windowStart = new Date(now.getTime() - windowMs).toISOString();

    let alertCount = 0;

    for (const elder of elders as Profile[]) {
      const uid = elder.id;

      // 取過去 15 分鐘最新一筆各指標
      const { data: metrics } = await supabase
        .from("health_metrics")
        .select("user_id, metric_type, value, recorded_at")
        .eq("user_id", uid)
        .gte("recorded_at", windowStart)
        .order("recorded_at", { ascending: false });

      if (!metrics || metrics.length === 0) continue;

      // 每種指標只看最新一筆
      const latestByType = new Map<string, MetricRow>();
      for (const m of metrics as MetricRow[]) {
        if (!latestByType.has(m.metric_type)) {
          latestByType.set(m.metric_type, m);
        }
      }

      for (const rule of rules as AlertRule[]) {
        const latest = latestByType.get(rule.metric_type);
        if (!latest) continue;

        const v = latest.value;
        const breached =
          (rule.min_value !== null && v < rule.min_value) ||
          (rule.max_value !== null && v > rule.max_value);

        if (!breached) continue;

        // 冷卻檢查：同一 (user, rule) 在冷卻期內已有告警？
        const cooldownStart = new Date(
          now.getTime() - rule.cooldown_minutes * 60 * 1000
        ).toISOString();

        const { count } = await supabase
          .from("alert_events")
          .select("id", { count: "exact", head: true })
          .eq("user_id", uid)
          .eq("rule_id", rule.id)
          .gte("triggered_at", cooldownStart);

        if ((count ?? 0) > 0) continue;

        // 寫入 alert_events
        const { error: evtErr } = await supabase.from("alert_events").insert({
          user_id: uid,
          rule_id: rule.id,
          metric_type: rule.metric_type,
          metric_value: v,
          triggered_at: now.toISOString(),
        });
        if (evtErr) {
          console.error("alert_events insert error:", evtErr);
          continue;
        }

        // 組通知內容
        const metricLabel = metricLabel_(rule.metric_type);
        const title = `⚠️ ${elder.name} 的健康指標異常`;
        const body = `${metricLabel} ${v} 已超出正常範圍（規則：${rule.min_value ?? "-"} ~ ${rule.max_value ?? "-"} ${unitFor(rule.metric_type)}）`;
        const payload = {
          type: "health_alert",
          elder_id: uid,
          elder_name: elder.name,
          metric_type: rule.metric_type,
          metric_value: v,
          severity: rule.severity,
        };

        // 長輩本人
        await supabase.from("notification_outbox").insert({
          target_user_id: uid,
          elder_user_id: uid,
          title,
          body,
          payload,
          status: "pending",
        });

        // 所有志工
        for (const vid of volunteerIds) {
          await supabase.from("notification_outbox").insert({
            target_user_id: vid,
            elder_user_id: uid,
            title,
            body,
            payload,
            status: "pending",
          });
        }

        alertCount++;
      }
    }

    return new Response(
      JSON.stringify({ processed: elders.length, alerts_triggered: alertCount }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("check_health_alerts error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

function metricLabel_(type: string): string {
  const map: Record<string, string> = {
    heart_rate: "心率",
    resting_heart_rate: "靜息心率",
    steps: "步數",
    sleep_minutes: "睡眠時間",
    blood_oxygen: "血氧",
  };
  return map[type] ?? type;
}

function unitFor(type: string): string {
  const map: Record<string, string> = {
    heart_rate: "bpm",
    resting_heart_rate: "bpm",
    steps: "步",
    sleep_minutes: "分",
    blood_oxygen: "%",
  };
  return map[type] ?? "";
}
