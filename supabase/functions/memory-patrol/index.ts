// memory-patrol: 记忆巡逻 Edge Function
// 功能：检测用户记忆中的模式（任务搁置、习惯断签），主动生成提醒并推送
// 触发方式：pg_cron 定时（每天 09:00 UTC+8）或手动调用（传 user_id）
// 依赖：EverMemOS API、guide_ai.generateProactiveMessage、微信客服消息 API

import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  detectHabitChains,
  gatherGuideMemoryBundle,
  isChainBreaking,
  normalizeMemoryItems,
  normalizeStructuredMemoryItem,
  shouldKeepStructuredMemoryItem,
} from "../_shared/guide_memory.ts";
import type { GuideStructuredMemoryItem } from "../_shared/guide_memory.ts";
import { EverMemOSClient } from "../_shared/evermemos_client.ts";
import { searchCollectiveWisdom } from "../_shared/collective_memory.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function toText(v: unknown): string {
  if (typeof v === "string") return v.trim();
  if (v == null) return "";
  return String(v).trim();
}

function toErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  try {
    return JSON.stringify(error);
  } catch {
    return String(error);
  }
}

function toNum(v: unknown, fallback = 0): number {
  if (typeof v === "number" && Number.isFinite(v)) return v;
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
}

// ---------- 微信推送（复用 weekly-report-push 的模式）----------

let _cachedToken = "";
let _tokenExpiresAt = 0;

async function getWechatAccessToken(): Promise<string> {
  if (_cachedToken && Date.now() < _tokenExpiresAt - 60_000) {
    return _cachedToken;
  }
  const appId = Deno.env.get("WECHAT_APP_ID") ?? "";
  const appSecret = Deno.env.get("WECHAT_APP_SECRET") ?? "";
  if (!appId || !appSecret) {
    throw new Error("Missing WECHAT_APP_ID or WECHAT_APP_SECRET");
  }
  const url =
    `https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=${appId}&secret=${appSecret}`;
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`get access_token HTTP ${resp.status}`);
  const data = await resp.json();
  if (data.errcode) throw new Error(`get access_token errcode=${data.errcode}`);
  _cachedToken = data.access_token;
  _tokenExpiresAt = Date.now() + (data.expires_in ?? 7200) * 1000;
  return _cachedToken;
}

async function sendWechatText(
  openId: string,
  content: string,
): Promise<boolean> {
  try {
    const token = await getWechatAccessToken();
    const url =
      `https://api.weixin.qq.com/cgi-bin/message/custom/send?access_token=${token}`;
    const resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        touser: openId,
        msgtype: "text",
        text: { content },
      }),
    });
    if (!resp.ok) return false;
    const data = await resp.json();
    return !data.errcode || data.errcode === 0;
  } catch {
    return false;
  }
}

// ---------- 记忆模式检测 ----------

type PatrolSignal = {
  kind: "stale_task" | "streak_break" | "long_silence" | "habit_chain_break";
  message: string;
  urgency: "low" | "medium" | "high";
  /** 习惯链断裂信号附带的链类型，用于去重 */
  chainType?: string;
};

/**
 * 基于记忆 bundle 检测需要主动推送的信号。
 * 返回最高优先级的信号（最多1条，避免打扰）。
 *
 * @param bundle 记忆 bundle，包含 recent_context 和 behavior_signals
 * @param profile 用户 profile 数据，包含 streak 和 last_checkin_date
 * @param structuredMemories 可选的结构化记忆条目，用于习惯链断裂检测
 */
function detectPatrolSignals(
  bundle: Awaited<ReturnType<typeof gatherGuideMemoryBundle>>,
  profile: Record<string, unknown> | null,
  structuredMemories?: GuideStructuredMemoryItem[],
): PatrolSignal | null {
  const streak = toNum(profile?.current_streak, 0);
  const lastCheckin = toText(profile?.last_checkin_date);
  const signals: PatrolSignal[] = [];

  // 检测连续打卡断签：streak > 3 但今天还没打卡
  if (streak >= 3 && lastCheckin) {
    const today = new Date().toISOString().slice(0, 10);
    const yesterday = new Date(Date.now() - 86400_000).toISOString().slice(
      0,
      10,
    );
    if (lastCheckin <= yesterday) {
      signals.push({
        kind: "streak_break",
        message:
          `你已经连续打卡 ${streak} 天了，今天还没有记录，要继续保持吗？`,
        urgency: streak >= 7 ? "high" : "medium",
      });
    }
  }

  // 检测任务搁置：recent_context 里有任务但今天完成数为 0
  const hasActiveTasks = bundle.recent_context.some((line) =>
    line.includes("当前任务板上仍存在的任务") && !line.includes("暂时为空")
  );
  const todayCompletedZero = !bundle.recent_context.some((line) =>
    line.includes("今天") && line.includes("完成")
  );
  if (hasActiveTasks && todayCompletedZero) {
    signals.push({
      kind: "stale_task",
      message: "任务板上还有待推进的任务，今天找个小缺口动一下？",
      urgency: "low",
    });
  }

  // 检测长时间沉默：behavior_signals 里有"样本较少"提示
  const hasSilenceSignal = bundle.behavior_signals.some((s) =>
    s.includes("样本较少") || s.includes("建议先完成一个最小动作")
  );
  if (hasSilenceSignal) {
    signals.push({
      kind: "long_silence",
      message: "好久没有新的行动记录了，今天有什么想推进的吗？",
      urgency: "low",
    });
  }

  // 习惯链断裂检测：检查用户已形成的习惯链是否在预期时间窗口内无匹配行为
  if (structuredMemories) {
    try {
      const chains = detectHabitChains(structuredMemories);
      for (const chain of chains) {
        if (isChainBreaking(chain, structuredMemories)) {
          signals.push({
            kind: "habit_chain_break",
            message:
              `你的"${chain.description}"习惯已经持续了${chain.consecutiveDays}天，今天还没有看到相关行动。没关系，节奏偶尔会变化，重要的是你已经建立了这个模式。`,
            urgency: "medium",
            chainType: chain.type,
          });
        }
      }
    } catch (err) {
      console.error("patrol: 习惯链断裂检测失败，跳过", toErrorMessage(err));
    }
  }

  if (signals.length === 0) return null;
  // 返回最高优先级信号
  return signals.sort((a, b) => {
    const order = { high: 0, medium: 1, low: 2 };
    return order[a.urgency] - order[b.urgency];
  })[0];
}

// ---------- 写入 guide_dialog_logs ----------

async function writePatrolLog(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  message: string,
  memoryRefs: string[],
): Promise<void> {
  await supabase.from("guide_dialog_logs").insert({
    user_id: userId,
    scene: "patrol",
    role: "assistant",
    content: message,
    memory_refs: memoryRefs.slice(0, 20),
    created_at: new Date().toISOString(),
  });
}

// ---------- 单用户巡逻 ----------

async function patrolUser(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  wechatOpenId: string | null,
): Promise<
  { userId: string; pushed: boolean; signal: string | null; error?: string }
> {
  try {
    // 收集记忆 bundle
    const bundle = await gatherGuideMemoryBundle(supabase, userId, {
      scene: "patrol",
      maxRawItems: 40,
      maxPackedChars: 8000,
    });

    // 获取 profile 用于 streak 检测
    const { data: profile } = await supabase
      .from("profiles")
      .select("current_streak,last_checkin_date")
      .eq("id", userId)
      .maybeSingle();

    // 从 EverMemOS 检索结构化记忆，用于习惯链断裂检测
    let structuredMemories: GuideStructuredMemoryItem[] | undefined;
    try {
      const everMem = new EverMemOSClient();
      const memRaw = await everMem.searchMemories({
        userId,
        query: "任务完成 习惯 日常",
        memoryTypes: ["episodic_memory"],
        retrieveMethod: "hybrid",
        limit: 30,
      });
      structuredMemories = normalizeMemoryItems(memRaw)
        .map((item, idx) =>
          normalizeStructuredMemoryItem("mem_patrol", item, idx)
        )
        .filter((item): item is GuideStructuredMemoryItem => item != null)
        .filter((item) =>
          shouldKeepStructuredMemoryItem(item, {
            activeTaskIds: new Set(),
            deletedTaskIds: new Set(),
            deletedTaskTitleKeys: new Set(),
          })
        )
        .slice(0, 30);
    } catch (err) {
      console.error(
        "patrol: 检索结构化记忆失败，跳过习惯链检测",
        toErrorMessage(err),
      );
    }

    const signal = detectPatrolSignals(
      bundle,
      profile as Record<string, unknown> | null,
      structuredMemories,
    );
    if (!signal) {
      return { userId, pushed: false, signal: null };
    }

    // 习惯链断裂信号去重：同一习惯链类型 24h 内最多 1 次
    if (signal.kind === "habit_chain_break" && signal.chainType) {
      try {
        const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000)
          .toISOString();
        const { data: recentLogs } = await supabase
          .from("guide_dialog_logs")
          .select("id")
          .eq("user_id", userId)
          .eq("scene", "patrol")
          .gte("created_at", oneDayAgo)
          .like("content", `%habit_chain_break%${signal.chainType}%`)
          .limit(1);
        if (recentLogs && recentLogs.length > 0) {
          // 24h 内已有同类型习惯链断裂提醒，跳过
          return { userId, pushed: false, signal: null };
        }
      } catch {
        // 去重查询失败时允许发送（宁可多发不漏发）
      }
    }

    // 断签信号时注入群体智慧：从 Collective Space 检索匿名恢复经验
    if (signal.kind === "streak_break") {
      try {
        const everMem = new EverMemOSClient();
        const wisdomLines = await searchCollectiveWisdom(
          everMem,
          "断签恢复 重新开始",
          3,
        );
        if (wisdomLines.length > 0) {
          signal.message += `\n\n其他冒险者的经验：${wisdomLines[0]}`;
        }
      } catch {
        // 检索失败不影响推送，使用原有消息
      }
    }

    // 写入对话日志（让 Guide 下次聊天时能感知到这条主动消息）
    // 习惯链断裂信号在 content 中附加元数据，便于后续去重查询
    const logContent = signal.kind === "habit_chain_break" && signal.chainType
      ? `[habit_chain_break:${signal.chainType}] ${signal.message}`
      : signal.message;
    await writePatrolLog(supabase, userId, logContent, bundle.memory_refs);

    // 如果用户绑定了微信，推送微信消息
    let pushed = false;
    if (wechatOpenId) {
      pushed = await sendWechatText(
        wechatOpenId,
        `🌍 地球Online 小忆提醒\n\n${signal.message}`,
      );
    }

    // 同时写入一条 agentic 记忆，让后续检索能感知到这次主动推送
    try {
      const everMem = new EverMemOSClient();
      await everMem.createMemory({
        userId,
        eventType: "patrol_nudge",
        content: `[patrol] ${signal.kind}: ${signal.message}`,
        metadata: {
          memoryKind: "dialog_event",
          summary: signal.message,
          extra: { urgency: signal.urgency, kind: signal.kind },
        },
      });
    } catch {
      // 记忆写入失败不影响推送结果
    }

    return { userId, pushed, signal: signal.kind };
  } catch (err) {
    return { userId, pushed: false, signal: null, error: toErrorMessage(err) };
  }
}

// ---------- 主入口 ----------

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ success: false, error: "Method Not Allowed" }),
      {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceRole) throw new Error("Missing SUPABASE env");

    const supabase = createClient(supabaseUrl, serviceRole);
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const targetUserId = toText(body?.user_id);

    let users: Array<{ id: string; wechat_openid: string | null }> = [];

    if (targetUserId) {
      // 单用户模式：手动触发
      const { data } = await supabase
        .from("profiles")
        .select("id,wechat_openid")
        .eq("id", targetUserId)
        .maybeSingle();
      if (data) users = [data as { id: string; wechat_openid: string | null }];
    } else {
      // 批量模式：查询所有活跃用户（最近 7 天有 daily_log 记录）
      const sevenDaysAgo = new Date(Date.now() - 7 * 86400_000).toISOString()
        .slice(0, 10);
      const { data: activeLogs } = await supabase
        .from("daily_logs")
        .select("user_id")
        .gte("date_id", sevenDaysAgo)
        .limit(200);

      if (activeLogs && activeLogs.length > 0) {
        const userIds = [
          ...new Set(
            (activeLogs as Array<{ user_id: string }>).map((r) => r.user_id),
          ),
        ];
        const { data: profiles } = await supabase
          .from("profiles")
          .select("id,wechat_openid")
          .in("id", userIds);
        users = (profiles ?? []) as Array<
          { id: string; wechat_openid: string | null }
        >;
      }
    }

    if (users.length === 0) {
      return new Response(
        JSON.stringify({ success: true, patrolled: 0, results: [] }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 逐用户巡逻（避免并发过高）
    const results = [];
    for (const user of users) {
      const result = await patrolUser(supabase, user.id, user.wechat_openid);
      results.push(result);
    }

    const pushed = results.filter((r) => r.pushed).length;
    const signaled = results.filter((r) => r.signal).length;

    return new Response(
      JSON.stringify({
        success: true,
        patrolled: users.length,
        signaled,
        pushed,
        results,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: toErrorMessage(error) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
