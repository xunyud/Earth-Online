import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  type EverMemCreateMemoryInput,
  type EverMemMemoryKind,
  EverMemOSClient,
  type EverMemSourceStatus,
} from "../_shared/evermemos_client.ts";
import { writeCollectiveMilestone } from "../_shared/collective_memory.ts";
import {
  detectMilestones,
  type MilestoneDetectionContext,
} from "../_shared/milestone_detector.ts";
import { computeXpMultiplier } from "../_shared/guide_memory.ts";
import {
  shouldTriggerMemory100,
  shouldTriggerGuardian30,
  shouldTriggerLivingMemory50,
  type MemoryAchievement,
} from "../_shared/memory_achievements.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function toText(v: unknown) {
  if (typeof v === "string") return v.trim();
  if (v == null) return "";
  return String(v).trim();
}

function toErrorMessage(error: unknown) {
  if (error instanceof Error) return error.message;
  try {
    return JSON.stringify(error);
  } catch {
    return String(error);
  }
}

function toRecord(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
}

function normalizeMemoryKind(value: unknown): EverMemMemoryKind {
  const text = toText(value);
  switch (text) {
    case "task_event":
    case "dialog_event":
    case "profile_signal":
      return text;
    default:
      return "generic";
  }
}

function normalizeSourceStatus(value: unknown): EverMemSourceStatus {
  const text = toText(value);
  switch (text) {
    case "inactive":
    case "muted":
      return text;
    default:
      return "active";
  }
}

// ---------- 里程碑描述模板 ----------

/** 根据里程碑类型生成匿名行为描述 */
function milestoneDescription(
  type: "streak_7day" | "first_clear" | "recovery_from_break",
): string {
  switch (type) {
    case "streak_7day":
      return "一位冒险者连续打卡 7 天，保持了稳定的行动节奏。";
    case "first_clear":
      return "一位冒险者首次清空了任务板，完成了所有活跃任务。";
    case "recovery_from_break":
      return "一位冒险者在断签后重新开始行动，迈出了恢复的第一步。";
  }
}

// ---------- 里程碑检测与写入（任务完成后触发） ----------

/** 格式化日期为 YYYY-MM-DD */
function formatDateId(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/** 查询用户 profile 中的 streak、任务统计和记忆统计数据，供里程碑检测、XP 倍率和成就检测共用 */
async function queryUserProfile(userId: string) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceRole) {
    console.warn("query-profile: 缺少 SUPABASE 环境变量，跳过 profile 查询");
    return null;
  }

  const supabase = createClient(supabaseUrl, serviceRole);

  const { data: profile, error: profileErr } = await supabase
    .from("profiles")
    .select("current_streak,previous_streak,today_completed_count,total_active_task_count,is_first_clear,total_memory_count,memory_streak_days,last_memory_date,guide_memory_reference_count")
    .eq("id", userId)
    .maybeSingle();

  if (profileErr || !profile) {
    console.warn("query-profile: profile 数据缺失", profileErr?.message);
    return null;
  }

  return { supabase, profile };
}

/**
 * 在任务完成事件写入记忆后，检测并写入里程碑到 Collective Space。
 * profile 数据缺失时跳过检测；写入失败仅记录日志，不影响主流程。
 */
async function tryDetectAndWriteMilestones(
  userId: string,
  client: EverMemOSClient,
  profileData: { profile: Record<string, unknown> },
): Promise<void> {
  const { profile } = profileData;

  // 构建检测上下文
  const ctx: MilestoneDetectionContext = {
    userId,
    currentStreak: typeof profile.current_streak === "number" ? profile.current_streak : 0,
    previousStreak: typeof profile.previous_streak === "number" ? profile.previous_streak : 0,
    todayCompletedCount: typeof profile.today_completed_count === "number" ? profile.today_completed_count : 0,
    totalActiveTaskCount: typeof profile.total_active_task_count === "number" ? profile.total_active_task_count : 0,
    isFirstClear: profile.is_first_clear === true,
  };

  const milestones = detectMilestones(ctx);
  if (milestones.length === 0) return;

  // 逐个写入里程碑到 Collective Space
  for (const milestone of milestones) {
    try {
      await writeCollectiveMilestone(client, milestone, milestoneDescription(milestone));
      console.log(`milestone-detect: 写入里程碑 ${milestone} for user ${userId}`);
    } catch (err) {
      console.error(`milestone-detect: 写入里程碑 ${milestone} 失败`, toErrorMessage(err));
    }
  }
}

/**
 * 根据用户 streak 数据计算 XP 倍率并写入 daily_logs。
 * 使用 computeXpMultiplier 替代固定值 1.0，写入失败仅记录日志不影响主流程。
 */
async function tryWriteXpMultiplier(
  userId: string,
  supabase: ReturnType<typeof createClient>,
  profileData: { profile: Record<string, unknown> },
): Promise<void> {
  const { profile } = profileData;
  const currentStreak = typeof profile.current_streak === "number" ? profile.current_streak : 0;
  const previousStreak = typeof profile.previous_streak === "number" ? profile.previous_streak : 0;

  const multiplier = computeXpMultiplier(currentStreak, previousStreak);
  const today = formatDateId(new Date());

  // 先尝试更新当天已有记录的 xp_multiplier
  const { data, error: updateErr } = await supabase
    .from("daily_logs")
    .update({ xp_multiplier: multiplier })
    .eq("user_id", userId)
    .eq("date_id", today)
    .select("date_id");

  if (!updateErr && data && data.length > 0) {
    console.log(`xp-multiplier: 更新 ${today} xp_multiplier=${multiplier} for user ${userId}`);
    return;
  }

  // 当天暂无记录，插入完整行（含 xp_multiplier）
  const { error: insertErr } = await supabase.from("daily_logs").insert({
    user_id: userId,
    date_id: today,
    completed_count: 0,
    is_perfect: false,
    xp_multiplier: multiplier,
  });

  if (insertErr) {
    console.warn(`xp-multiplier: 写入 daily_logs 失败`, toErrorMessage(insertErr));
    return;
  }

  console.log(`xp-multiplier: 插入 ${today} xp_multiplier=${multiplier} for user ${userId}`);
}

// ---------- 记忆成就检测（记忆写入成功后触发） ----------

// 记忆成就判定函数从 _shared/memory_achievements.ts 导入，便于属性测试直接引用

/**
 * 更新 profiles 中的记忆统计列（total_memory_count、memory_streak_days、last_memory_date）。
 * 每次记忆写入成功后调用，递增总数并维护连续天数。
 */
async function updateMemoryStats(
  userId: string,
  supabase: ReturnType<typeof createClient>,
  profile: Record<string, unknown>,
): Promise<{ totalMemoryCount: number; memoryStreakDays: number; guideReferenceCount: number }> {
  const today = formatDateId(new Date());
  const prevCount = typeof profile.total_memory_count === "number" ? profile.total_memory_count : 0;
  const prevStreakDays = typeof profile.memory_streak_days === "number" ? profile.memory_streak_days : 0;
  const lastMemoryDate = profile.last_memory_date ? String(profile.last_memory_date) : "";
  const guideRefCount = typeof profile.guide_memory_reference_count === "number"
    ? profile.guide_memory_reference_count
    : 0;

  // 递增总记忆条数
  const newCount = prevCount + 1;

  // 计算连续天数：如果上次写入日期是昨天则 +1，如果是今天则保持不变，否则重置为 1
  let newStreakDays: number;
  if (lastMemoryDate === today) {
    // 今天已有记忆写入，连续天数不变
    newStreakDays = prevStreakDays;
  } else {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayId = formatDateId(yesterday);
    if (lastMemoryDate === yesterdayId) {
      // 上次写入是昨天，连续天数 +1
      newStreakDays = prevStreakDays + 1;
    } else {
      // 断签或首次写入，重置为 1
      newStreakDays = 1;
    }
  }

  // 更新 profiles 记忆统计列
  const { error: updateErr } = await supabase
    .from("profiles")
    .update({
      total_memory_count: newCount,
      memory_streak_days: newStreakDays,
      last_memory_date: today,
    })
    .eq("id", userId);

  if (updateErr) {
    console.warn("memory-stats: 更新 profiles 记忆统计失败", toErrorMessage(updateErr));
  }

  return {
    totalMemoryCount: newCount,
    memoryStreakDays: newStreakDays,
    guideReferenceCount: guideRefCount,
  };
}

/**
 * 在记忆写入成功后检测并解锁记忆相关成就。
 * 检测三种成就：memory_100、memory_guardian_30、living_memory_50。
 * 检测失败时记录错误日志，不影响记忆写入主流程。
 */
async function tryDetectMemoryAchievements(
  userId: string,
  supabase: ReturnType<typeof createClient>,
  profile: Record<string, unknown>,
): Promise<void> {
  // 先更新记忆统计并获取最新值
  const stats = await updateMemoryStats(userId, supabase, profile);

  // 收集需要检测的成就
  const toCheck: MemoryAchievement[] = [];
  if (shouldTriggerMemory100(stats.totalMemoryCount)) {
    toCheck.push("memory_100");
  }
  if (shouldTriggerGuardian30(stats.memoryStreakDays)) {
    toCheck.push("memory_guardian_30");
  }
  if (shouldTriggerLivingMemory50(stats.guideReferenceCount)) {
    toCheck.push("living_memory_50");
  }

  if (toCheck.length === 0) return;

  // 查询用户已解锁的记忆成就，避免重复写入
  const { data: existing, error: queryErr } = await supabase
    .from("user_achievements")
    .select("achievement_id")
    .eq("user_id", userId)
    .in("achievement_id", toCheck);

  if (queryErr) {
    console.warn("memory-achievement: 查询已解锁成就失败", toErrorMessage(queryErr));
    return;
  }

  const alreadyUnlocked = new Set((existing ?? []).map((r: { achievement_id: string }) => r.achievement_id));
  const newAchievements = toCheck.filter((id) => !alreadyUnlocked.has(id));

  if (newAchievements.length === 0) return;

  // 逐个写入新解锁的成就
  for (const achievementId of newAchievements) {
    const { error: insertErr } = await supabase
      .from("user_achievements")
      .insert({ user_id: userId, achievement_id: achievementId })
      .single();

    if (insertErr) {
      console.warn(`memory-achievement: 写入 ${achievementId} 失败`, toErrorMessage(insertErr));
      continue;
    }

    // 查询成就定义，发放 XP 和金币奖励
    const { data: achDef } = await supabase
      .from("achievements")
      .select("xp_bonus,gold_bonus")
      .eq("id", achievementId)
      .maybeSingle();

    if (achDef) {
      const xpBonus = typeof achDef.xp_bonus === "number" ? achDef.xp_bonus : 0;
      const goldBonus = typeof achDef.gold_bonus === "number" ? achDef.gold_bonus : 0;
      if (xpBonus > 0 || goldBonus > 0) {
        // 使用 service role 直接更新 profiles 发放奖励（与 check_and_unlock_achievements RPC 一致）
        const { data: currentProfile } = await supabase
          .from("profiles")
          .select("total_xp,gold")
          .eq("id", userId)
          .maybeSingle();
        if (currentProfile) {
          const currentXp = typeof currentProfile.total_xp === "number" ? currentProfile.total_xp : 0;
          const currentGold = typeof currentProfile.gold === "number" ? currentProfile.gold : 0;
          const { error: rewardErr } = await supabase
            .from("profiles")
            .update({
              total_xp: Math.max(0, currentXp + xpBonus),
              gold: Math.max(0, currentGold + goldBonus),
            })
            .eq("id", userId);
          if (rewardErr) {
            console.warn(`memory-achievement: 发放 ${achievementId} 奖励失败`, toErrorMessage(rewardErr));
          }
        }
      }
    }

    console.log(`memory-achievement: 解锁 ${achievementId} for user ${userId}`);
  }
}

// ---------- Sender 身份注册与携带（从 _shared/sender_registry.ts 复用） ----------

export {
  ensureSendersRegistered,
  resolveSenderName,
  SENDER_NAMES,
  senderCache,
} from "../_shared/sender_registry.ts";
export type { SenderName } from "../_shared/sender_registry.ts";

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
    const body = await req.json();
    const userId = toText(body?.user_id);
    const eventType = toText(body?.event_type);
    const content = toText(body?.content);
    const metadata = {
      memoryKind: normalizeMemoryKind(body?.memory_kind),
      sourceTaskId: toText(body?.source_task_id),
      sourceTaskTitle: toText(body?.source_task_title),
      sourceStatus: normalizeSourceStatus(body?.source_status),
      summary: toText(body?.summary),
      extra: toRecord(body?.extra),
    };

    if (!userId || !eventType || !content) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "缺少 user_id、event_type 或 content",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const timeoutMsRaw = Number(
      Deno.env.get("EVERMEMOS_SYNC_TIMEOUT_MS") ?? "1500",
    );
    const timeoutMs = Number.isFinite(timeoutMsRaw) && timeoutMsRaw > 0
      ? timeoutMsRaw
      : 1500;
    const client = new EverMemOSClient();
    const signal = AbortSignal.timeout(timeoutMs);

    // 懒加载注册 Sender 身份（首次请求时执行，后续跳过）
    await ensureSendersRegistered(client);

    // 根据事件类型推断写入源标识
    const senderName = resolveSenderName(
      eventType,
      toText(body?.sender),
    );

    try {
      await client.createMemory({
        userId,
        eventType,
        content,
        metadata,
        // sender 字段通过 spread 传递到 buildSmartMemoryEnvelope
        sender: senderName,
      } as EverMemCreateMemoryInput & { sender: string }, signal);

      // 记忆写入成功后，查询 profile 数据用于成就检测和（task_event 时）里程碑/XP 倍率
      try {
        const profileResult = await queryUserProfile(userId);
        if (profileResult) {
          // 记忆成就检测（所有类型的记忆写入都参与统计）
          try {
            await tryDetectMemoryAchievements(
              userId,
              profileResult.supabase,
              profileResult.profile,
            );
          } catch (achErr) {
            console.error("memory-achievement: 异常", toErrorMessage(achErr));
          }

          // 任务完成事件额外执行里程碑检测和 XP 倍率写入
          if (metadata.memoryKind === "task_event") {
            try {
              await tryDetectAndWriteMilestones(userId, client, profileResult);
            } catch (milestoneErr) {
              console.error("milestone-detect: 异常", toErrorMessage(milestoneErr));
            }
            try {
              await tryWriteXpMultiplier(userId, profileResult.supabase, profileResult);
            } catch (xpErr) {
              console.error("xp-multiplier: 异常", toErrorMessage(xpErr));
            }
          }
        }
      } catch (profileErr) {
        // profile 查询失败不影响正常记忆写入流程
        console.error("post-write: profile 查询异常", toErrorMessage(profileErr));
      }

      return new Response(JSON.stringify({ success: true, synced: true }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    } catch (syncErr) {
      console.warn("sync-user-memory skipped:", toErrorMessage(syncErr));
      return new Response(JSON.stringify({ success: true, synced: false }), {
        status: 202,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
  } catch (error) {
    const msg = toErrorMessage(error);
    console.error("sync-user-memory error:", msg);
    return new Response(JSON.stringify({ success: false, error: msg }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
