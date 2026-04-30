import { gatherGuideMemoryBundle } from "./guide_memory.ts";
import {
  generateChat,
  generateDailyEvent,
  generateNightReflection,
  generateProactiveMessage,
  type GuideSuggestedTask,
} from "./guide_ai.ts";
import {
  EverMemOSClient,
  type EverMemCreateMemoryInput,
} from "./evermemos_client.ts";

export type GuideDialogExtraPayload = {
  channel?: string;
  quick_actions?: string[];
  suggested_task?: GuideSuggestedTask | null;
};

const DEFAULT_GUIDE_DISPLAY_NAME = "Xiaoyi";

function toText(v: unknown) {
  if (typeof v === "string") return v.trim();
  if (v == null) return "";
  return String(v).trim();
}

function toRecord(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
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

export async function resolveGuideDisplayName(
  supabase: any,
  userId: string,
  clientContext?: Record<string, unknown>,
) {
  const settings = await ensureGuideSettings(supabase, userId);
  const settingsName = toText(settings?.display_name);
  const clientName = toText(toRecord(clientContext).guide_name);
  return settingsName || clientName ||
    localizedGuideText(clientContext, {
      zh: "小忆",
      en: DEFAULT_GUIDE_DISPLAY_NAME,
    });
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
  clientContext?: Record<string, unknown>,
) {
  const dateId = todayDateId();
  const existing = await supabase
    .from("guide_daily_events")
    .select("*")
    .eq("user_id", userId)
    .eq("event_date", dateId)
    .maybeSingle();
  if (existing.data) {
    const normalized = normalizeDailyEvent(
      existing.data as Record<string, unknown>,
    );
    if (!shouldRefreshDailyEventForLanguage(normalized, clientContext)) {
      return normalized;
    }
  }

  const memory = await gatherGuideMemoryBundle(supabase, userId, {
    scene,
    clientContext,
    maxRawItems: 60,
    maxPackedChars: 14000,
  });
  const draft = await generateDailyEvent(memory, clientContext);
  const payload = {
    user_id: userId,
    event_date: dateId,
    title: draft.title,
    description: draft.description,
    reason: draft.reason,
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
  clientContext?: Record<string, unknown>,
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

  const questTitle = toText(event.title) || localizedGuideText(clientContext, {
    zh: "地球突发事件",
    en: "Earth Dynamic Event",
  });
  const questDescription = toText(event.description) ||
    localizedGuideText(clientContext, {
      zh: "完成后可获得额外奖励。",
      en: "Complete it to earn extra rewards.",
    });
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
    extraPayload?: GuideDialogExtraPayload;
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
    ...(input.extraPayload ? { extra_payload: input.extraPayload } : {}),
  };
  if (!payload.content) return;
  try {
    await supabase.from("guide_dialog_logs").insert(payload);
  } catch {
    // 对话日志写入失败时保留主流程可用。
  }
}

/** 推荐条目结构：title 为具体可执行的小动作，reason 为推荐理由 */
type Recommendation = { title: string; reason: string };

/**
 * 调用 memory-recommender Edge Function 获取个性化任务推荐。
 * 使用 8 秒超时，任何失败（网络、非 200、解析异常）均返回空数组，
 * 确保不影响 bootstrap 主流程。
 */
async function fetchRecommendations(
  userId: string,
  clientContext: Record<string, unknown>,
): Promise<Recommendation[]> {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceRoleKey) return [];

    const resp = await fetch(
      `${supabaseUrl}/functions/v1/memory-recommender`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify({ user_id: userId, client_context: clientContext }),
        signal: AbortSignal.timeout(8000),
      },
    );
    if (!resp.ok) return [];

    const data = await resp.json();
    return Array.isArray(data?.recommendations) ? data.recommendations : [];
  } catch {
    // 推荐失败不影响 bootstrap 主流程
    return [];
  }
}


export async function buildGuideBootstrapPayload(
  supabase: any,
  userId: string,
  scene: string,
  clientContext?: Record<string, unknown>,
) {
  const settings = await ensureGuideSettings(supabase, userId);
  const guideDisplayName = await resolveGuideDisplayName(
    supabase,
    userId,
    clientContext,
  );
  const nextClientContext = {
    ...toRecord(clientContext),
    guide_name: guideDisplayName,
  };
  const enabled = settings?.guide_enabled !== false;
  const memory = await gatherGuideMemoryBundle(supabase, userId, {
    scene,
    clientContext: nextClientContext,
    maxRawItems: 60,
    maxPackedChars: 14000,
  });

  // 调用 memory-recommender 获取个性化任务推荐（8s 超时，失败不影响主流程）
  const recommendations = await fetchRecommendations(userId, nextClientContext);

  if (!enabled) {
    return {
      proactive_message: "",
      daily_event: null,
      memory_digest: memory.memory_digest,
      memory_refs: memory.memory_refs.slice(0, 80),
      trace_id: crypto.randomUUID(),
      behavior_signals: memory.behavior_signals.slice(0, 8),
      guide_display_name: guideDisplayName,
      recommendations,
    };
  }

  const proactiveMessage = await generateProactiveMessage(
    memory,
    nextClientContext,
  );
  const dailyEvent = await getOrCreateDailyEvent(
    supabase,
    userId,
    scene,
    nextClientContext,
  );
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
    guide_display_name: guideDisplayName,
    recommendations,
  };
}

function inferRequestedLanguage(clientContext?: Record<string, unknown>) {
  const context = toRecord(clientContext);
  const rawCode = toText(context.language_code) || toText(context.locale) ||
    toText(context.lang);
  const normalizedCode = rawCode.toLowerCase();
  if (normalizedCode.startsWith("en")) return "en" as const;
  if (normalizedCode.startsWith("zh")) return "zh" as const;
  if (context.is_english === true) return "en" as const;
  if (context.is_english === false) return "zh" as const;
  return null;
}

function localizedGuideText(
  clientContext: Record<string, unknown> | undefined,
  values: { zh: string; en: string },
) {
  return inferRequestedLanguage(clientContext) === "en" ? values.en : values.zh;
}

function containsCjk(text: string) {
  return /[\u3400-\u9fff]/.test(text);
}

function shouldRefreshDailyEventForLanguage(
  event: ReturnType<typeof normalizeDailyEvent>,
  clientContext?: Record<string, unknown>,
) {
  if (event.status && event.status !== "generated") return false;
  const requestedLanguage = inferRequestedLanguage(clientContext);
  if (!requestedLanguage) return false;
  const sample = [
    toText(event.title),
    toText(event.description),
    toText(event.reason),
  ].join(" ");
  if (!sample) return false;
  if (requestedLanguage === "en") {
    return containsCjk(sample);
  }
  return /[A-Za-z]/.test(sample) && !containsCjk(sample);
}

export function buildGuideAssistantExtraPayload(input: {
  quickActions?: string[];
  suggestedTask?: GuideSuggestedTask | null;
  channel?: string;
}): GuideDialogExtraPayload | undefined {
  const quickActions = Array.isArray(input.quickActions)
    ? input.quickActions.map((item) => toText(item)).filter(Boolean).slice(0, 3)
    : [];
  const payload: GuideDialogExtraPayload = {};
  const channel = toText(input.channel);
  if (channel) payload.channel = channel;
  if (quickActions.length > 0) payload.quick_actions = quickActions;
  if (input.suggestedTask) payload.suggested_task = input.suggestedTask;
  return Object.keys(payload).length > 0 ? payload : undefined;
}

export async function buildGuideChatPayload(
  supabase: any,
  userId: string,
  scene: string,
  message: string,
  clientContext?: Record<string, unknown>,
) {
  const guideDisplayName = await resolveGuideDisplayName(
    supabase,
    userId,
    clientContext,
  );
  const nextClientContext = {
    ...toRecord(clientContext),
    guide_name: guideDisplayName,
  };
  const memory = await gatherGuideMemoryBundle(supabase, userId, {
    scene,
    userMessage: message,
    clientContext: nextClientContext,
    maxRawItems: 60,
    maxPackedChars: 14000,
  });
  const draft = await generateChat(memory, scene, message, nextClientContext);

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
      extraPayload: buildGuideAssistantExtraPayload({
        quickActions: draft.quick_actions,
        suggestedTask: draft.suggested_task ?? null,
        channel: scene === "wechat" ? "wechat" : "app",
      }),
    }),
  ]);

  return {
    reply: draft.reply,
    quick_actions: draft.quick_actions,
    suggested_task: draft.suggested_task ?? null,
    memory_refs: memory.memory_refs.slice(0, 80),
    guide_display_name: guideDisplayName,
  };
}

export async function getLatestSuggestedTask(
  supabase: any,
  userId: string,
  scene: string,
): Promise<GuideSuggestedTask | null> {
  const { data, error } = await supabase
    .from("guide_dialog_logs")
    .select("extra_payload,created_at")
    .eq("user_id", userId)
    .eq("scene", scene)
    .eq("role", "assistant")
    .order("created_at", { ascending: false })
    .limit(5);

  if (error) throw error;

  for (const row of data ?? []) {
    const extraPayload = toRecord(
      (row as Record<string, unknown>).extra_payload,
    );
    const rawTask = extraPayload.suggested_task;
    if (rawTask) {
      return normalizeSuggestedTask(rawTask);
    }
  }

  return null;
}

export async function acceptLatestSuggestedTask(
  supabase: any,
  userId: string,
  scene: string,
) {
  const suggestedTask = await getLatestSuggestedTask(supabase, userId, scene);
  if (!suggestedTask) {
    return {
      accepted: false,
      inserted_quest_id: null,
      task: null,
    };
  }

  const insertedQuestId = await insertQuestNodeWithFallbacks(supabase, {
    user_id: userId,
    parent_id: null,
    title: suggestedTask.title,
    quest_tier: suggestedTask.quest_tier,
    sort_order: -Date.now(),
    xp_reward: suggestedTask.xp_reward,
    description: suggestedTask.description,
  });

  return {
    accepted: true,
    inserted_quest_id: insertedQuestId,
    task: suggestedTask,
  };
}

export async function buildNightReflectionPayload(
  supabase: any,
  userId: string,
  dayId: string,
  clientContext?: Record<string, unknown>,
) {
  const memory = await gatherGuideMemoryBundle(supabase, userId, {
    scene: "night_reflection",
    userMessage: `day:${dayId}`,
    clientContext,
    maxRawItems: 60,
    maxPackedChars: 14000,
  });
  const draft = await generateNightReflection(memory, dayId, clientContext);
  await writeGuideDialogLog(supabase, {
    userId,
    scene: "night_reflection",
    role: "assistant",
    content: `${draft.opening}\n${draft.follow_up_question}`,
    memoryRefs: memory.memory_refs,
  });

  // 将反思内容写入 EverMemOS，形成夜间反思记忆闭环
  try {
    const client = new EverMemOSClient();
    const writePayload = buildNightReflectionWritePayload(
      userId,
      draft.opening,
      draft.follow_up_question,
      dayId,
    );
    await client.createMemory(writePayload, AbortSignal.timeout(3000));
  } catch (err) {
    console.warn("night-reflection: 反思写入记忆失败，不影响正常流程", err);
  }

  return {
    opening: draft.opening,
    follow_up_question: draft.follow_up_question,
    suggested_task: draft.suggested_task,
    memory_refs: memory.memory_refs.slice(0, 80),
  };
}

/**
 * 构建夜间反思记忆写入载荷（纯函数，便于属性测试）。
 * 从 opening、follow_up_question、dayId 构造写入 EverMemOS 的完整参数。
 */
export function buildNightReflectionWritePayload(
  userId: string,
  opening: string,
  followUpQuestion: string,
  dayId: string,
): EverMemCreateMemoryInput & { sender: string } {
  return {
    userId,
    eventType: "night_reflection",
    content: `${opening}\n\n${followUpQuestion}`,
    metadata: {
      memoryKind: "dialog_event",
      summary: `${dayId} 夜间反思`,
      sourceStatus: "active",
    },
    sender: "guide-assistant",
  };
}


export function normalizeSuggestedTask(raw: unknown): GuideSuggestedTask {
  const map = (raw && typeof raw === "object")
    ? raw as Record<string, unknown>
    : {};
  const language = inferRequestedLanguage(map);
  const title = toText(map.title) ||
    (language === "en" ? "Recovery Quest: Light Reset" : "恢复支线：轻量整理");
  const description = toText(map.description) ||
    (language === "en"
      ? "Take 10 minutes for one small recovery action."
      : "用 10 分钟完成一个轻恢复动作。");
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
