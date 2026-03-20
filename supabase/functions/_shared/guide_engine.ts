import { gatherGuideMemoryBundle } from "./guide_memory.ts";
import {
  generateChat,
  generateDailyEvent,
  generateNightReflection,
  generateProactiveMessage,
  type GuideSuggestedTask,
} from "./guide_ai.ts";

function toText(v: unknown) {
  if (typeof v === "string") return v.trim();
  if (v == null) return "";
  return String(v).trim();
}

function todayDateId() {
  const now = new Date();
  const y = now.getUTCFullYear().toString().padStart(4, "0");
  const m = (now.getUTCMonth() + 1).toString().padStart(2, "0");
  const d = now.getUTCDate().toString().padStart(2, "0");
  return `${y}-${m}-${d}`;
}

export async function ensureGuideSettings(supabase: any, userId: string) {
  const defaults = {
    user_id: userId,
    guide_enabled: true,
    proactive_mode: "daily_first_open",
    memory_mode: "hybrid_deep",
    updated_at: new Date().toISOString(),
  };
  const { data, error } = await supabase
    .from("guide_user_settings")
    .upsert(defaults, { onConflict: "user_id" })
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

function normalizeDailyEvent(row: Record<string, unknown>) {
  return {
    event_id: toText(row.id),
    title: toText(row.title),
    description: toText(row.description),
    reward_xp: Number(row.reward_xp ?? 0) || 0,
    reward_gold: Number(row.reward_gold ?? 0) || 0,
    status: toText(row.status) || "generated",
    reason: toText(row.reason),
    memory_refs: Array.isArray(row.memory_refs) ? row.memory_refs : [],
  };
}

export async function getOrCreateDailyEvent(
  supabase: any,
  userId: string,
  scene: string,
) {
  const dateId = todayDateId();
  const existing = await supabase
    .from("guide_daily_events")
    .select("*")
    .eq("user_id", userId)
    .eq("event_date", dateId)
    .maybeSingle();
  if (existing.data) {
    return normalizeDailyEvent(existing.data as Record<string, unknown>);
  }

  const memory = await gatherGuideMemoryBundle(supabase, userId, {
    scene,
    maxRawItems: 60,
    maxPackedChars: 14000,
  });
  const draft = await generateDailyEvent(memory);
  const payload = {
    user_id: userId,
    event_date: dateId,
    title: draft.title,
    description: draft.description,
    reward_xp: draft.reward_xp,
    reward_gold: draft.reward_gold,
    status: "generated",
    memory_refs: memory.memory_refs.slice(0, 80),
  };
  const { data, error } = await supabase
    .from("guide_daily_events")
    .upsert(payload, { onConflict: "user_id,event_date" })
    .select("*")
    .single();
  if (error) throw error;

  const event = normalizeDailyEvent(data as Record<string, unknown>);
  event.reason = draft.reason;
  return event;
}

async function insertQuestNodeWithFallbacks(
  supabase: any,
  base: Record<string, unknown>,
): Promise<string> {
  const baseWithDefaults: Record<string, unknown> = {
    description: "",
    due_date: null,
    completed_at: null,
    original_context: [],
    xp_reward: 0,
    is_completed: false,
    is_deleted: false,
    is_expanded: true,
    is_reward: false,
    ...base,
  };
  const variants: Array<Record<string, unknown>> = [
    { ...baseWithDefaults, node_type: "task" },
    baseWithDefaults,
    (() => {
      const { xp_reward, ...rest } = baseWithDefaults;
      return { ...rest, exp: xp_reward, node_type: "task" };
    })(),
    (() => {
      const { xp_reward, ...rest } = baseWithDefaults;
      return { ...rest, exp: xp_reward };
    })(),
  ];

  let lastErr: unknown = null;
  for (const payload of variants) {
    const { data, error } = await supabase
      .from("quest_nodes")
      .insert(payload)
      .select("id")
      .single();
    if (!error) {
      const id = toText((data as Record<string, unknown>)?.id);
      if (!id) throw new Error("quest insert succeeded but id is empty");
      return id;
    }
    lastErr = error;
  }
  throw lastErr ?? new Error("failed to insert quest node");
}

export async function acceptOrDismissDailyEvent(
  supabase: any,
  userId: string,
  eventId: string,
  accept: boolean,
) {
  const { data, error } = await supabase
    .from("guide_daily_events")
    .select("*")
    .eq("id", eventId)
    .eq("user_id", userId)
    .single();
  if (error || !data) throw error ?? new Error("daily event not found");

  const event = data as Record<string, unknown>;
  const rewardXp = Number(event.reward_xp ?? 0) || 0;
  const rewardGold = Number(event.reward_gold ?? 0) || 0;
  const handledAt = new Date().toISOString();

  if (!accept) {
    await supabase
      .from("guide_daily_events")
      .update({ status: "dismissed", handled_at: handledAt })
      .eq("id", eventId)
      .eq("user_id", userId);
    return {
      accepted: false,
      inserted_quest_id: null,
      reward_preview: { reward_xp: rewardXp, reward_gold: rewardGold },
    };
  }

  if (toText(event.status) === "accepted") {
    return {
      accepted: true,
      inserted_quest_id: null,
      reward_preview: { reward_xp: rewardXp, reward_gold: rewardGold },
    };
  }

  const questTitle = toText(event.title) || "地球突发事件";
  const questDescription = toText(event.description) ||
    "完成后可获得额外奖励。";
  const sortOrder = -Date.now();
  const insertedQuestId = await insertQuestNodeWithFallbacks(supabase, {
    user_id: userId,
    parent_id: null,
    title: questTitle,
    quest_tier: "Daily",
    sort_order: sortOrder,
    xp_reward: rewardXp > 0 ? rewardXp : 20,
    description: questDescription,
  });

  await supabase
    .from("guide_daily_events")
    .update({ status: "accepted", handled_at: handledAt })
    .eq("id", eventId)
    .eq("user_id", userId);

  if (rewardGold > 0) {
    try {
      await supabase.rpc("increment_custom_stats", {
        delta_xp: 0,
        delta_gold: rewardGold,
      });
    } catch {
      // 奖励发放失败不阻断日常事件主流程。
    }
  }

  return {
    accepted: true,
    inserted_quest_id: insertedQuestId,
    reward_preview: { reward_xp: rewardXp, reward_gold: rewardGold },
  };
}

export async function writeGuideDialogLog(
  supabase: any,
  input: {
    userId: string;
    scene: string;
    role: "user" | "assistant" | "system";
    content: string;
    memoryRefs?: string[];
  },
) {
  const payload = {
    user_id: input.userId,
    scene: input.scene,
    role: input.role,
    content: toText(input.content),
    memory_refs: Array.isArray(input.memoryRefs)
      ? input.memoryRefs.slice(0, 80)
      : [],
  };
  if (!payload.content) return;
  try {
    await supabase.from("guide_dialog_logs").insert(payload);
  } catch {
    // 对话日志写入失败时保留主流程可用。
  }
}

export async function buildGuideBootstrapPayload(
  supabase: any,
  userId: string,
  scene: string,
) {
  const settings = await ensureGuideSettings(supabase, userId);
  const enabled = settings?.guide_enabled !== false;
  const memory = await gatherGuideMemoryBundle(supabase, userId, {
    scene,
    maxRawItems: 60,
    maxPackedChars: 14000,
  });

  if (!enabled) {
    return {
      proactive_message: "",
      daily_event: null,
      memory_digest: memory.memory_digest,
      memory_refs: memory.memory_refs.slice(0, 80),
      trace_id: crypto.randomUUID(),
      behavior_signals: memory.behavior_signals.slice(0, 8),
    };
  }

  const proactiveMessage = await generateProactiveMessage(memory);
  const dailyEvent = await getOrCreateDailyEvent(supabase, userId, scene);
  await writeGuideDialogLog(supabase, {
    userId,
    scene,
    role: "assistant",
    content: proactiveMessage,
    memoryRefs: memory.memory_refs,
  });

  return {
    proactive_message: proactiveMessage,
    daily_event: dailyEvent,
    memory_digest: memory.memory_digest,
    memory_refs: memory.memory_refs.slice(0, 80),
    trace_id: crypto.randomUUID(),
    behavior_signals: memory.behavior_signals.slice(0, 8),
  };
}

export async function buildGuideChatPayload(
  supabase: any,
  userId: string,
  scene: string,
  message: string,
  clientContext?: Record<string, unknown>,
) {
  const memory = await gatherGuideMemoryBundle(supabase, userId, {
    scene,
    userMessage: message,
    clientContext,
    maxRawItems: 60,
    maxPackedChars: 14000,
  });
  const draft = await generateChat(memory, scene, message);

  await Promise.all([
    writeGuideDialogLog(supabase, {
      userId,
      scene,
      role: "user",
      content: message,
      memoryRefs: memory.memory_refs,
    }),
    writeGuideDialogLog(supabase, {
      userId,
      scene,
      role: "assistant",
      content: draft.reply,
      memoryRefs: memory.memory_refs,
    }),
  ]);

  return {
    reply: draft.reply,
    quick_actions: draft.quick_actions,
    suggested_task: draft.suggested_task ?? null,
    memory_refs: memory.memory_refs.slice(0, 80),
  };
}

export async function buildNightReflectionPayload(
  supabase: any,
  userId: string,
  dayId: string,
) {
  const memory = await gatherGuideMemoryBundle(supabase, userId, {
    scene: "night_reflection",
    userMessage: `day:${dayId}`,
    maxRawItems: 60,
    maxPackedChars: 14000,
  });
  const draft = await generateNightReflection(memory, dayId);
  await writeGuideDialogLog(supabase, {
    userId,
    scene: "night_reflection",
    role: "assistant",
    content: `${draft.opening}\n${draft.follow_up_question}`,
    memoryRefs: memory.memory_refs,
  });
  return {
    opening: draft.opening,
    follow_up_question: draft.follow_up_question,
    suggested_task: draft.suggested_task,
    memory_refs: memory.memory_refs.slice(0, 80),
  };
}

export function normalizeSuggestedTask(raw: unknown): GuideSuggestedTask {
  const map = (raw && typeof raw === "object")
    ? raw as Record<string, unknown>
    : {};
  const title = toText(map.title) || "恢复支线：轻量整理";
  const description = toText(map.description) ||
    "用 10 分钟完成一个轻恢复动作。";
  const xp = Number(map.xp_reward ?? 20);
  const xpReward = Number.isFinite(xp)
    ? Math.max(5, Math.min(120, Math.round(xp)))
    : 20;
  const tierRaw = toText(map.quest_tier);
  const questTier = (tierRaw === "Main_Quest" || tierRaw === "Side_Quest" ||
      tierRaw === "Daily")
    ? tierRaw
    : "Daily";
  return {
    title,
    description,
    xp_reward: xpReward,
    quest_tier: questTier,
  };
}
