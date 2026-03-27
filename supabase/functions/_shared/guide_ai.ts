import type { GuideMemoryBundle } from "./guide_memory.ts";

export type GuideSuggestedTask = {
  title: string;
  description: string;
  xp_reward: number;
  quest_tier: "Daily" | "Side_Quest" | "Main_Quest";
};

export type GuideDailyEventDraft = {
  title: string;
  description: string;
  reward_xp: number;
  reward_gold: number;
  reason: string;
};

export type GuideChatDraft = {
  reply: string;
  quick_actions: string[];
  suggested_task?: GuideSuggestedTask;
};

export type GuideNightReflectionDraft = {
  opening: string;
  follow_up_question: string;
  suggested_task: GuideSuggestedTask;
};

function toText(v: unknown) {
  if (typeof v === "string") return v.trim();
  if (v == null) return "";
  return String(v).trim();
}

function toInt(v: unknown, fallback: number, min: number, max: number) {
  const n = Number(v);
  if (!Number.isFinite(n)) return fallback;
  const rounded = Math.round(n);
  if (rounded < min) return min;
  if (rounded > max) return max;
  return rounded;
}

function stripJsonFence(text: string) {
  return text.replace(/```json/gi, "").replace(/```/g, "").trim();
}

function getApiKey() {
  const key = Deno.env.get("DEEPSEEK_API_KEY") ||
    Deno.env.get("OPENAI_API_KEY") || "";
  return key.trim();
}

async function callJsonLLM<T>(
  systemPrompt: string,
  userPrompt: string,
  fallback: T,
): Promise<T> {
  const apiKey = getApiKey();
  if (!apiKey) return fallback;

  try {
    const resp = await fetch("https://api.deepseek.com/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "deepseek-chat",
        temperature: 0.5,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
      }),
    });
    if (!resp.ok) return fallback;
    const data = await resp.json();
    const content = toText(data?.choices?.[0]?.message?.content);
    if (!content) return fallback;
    return JSON.parse(stripJsonFence(content)) as T;
  } catch {
    return fallback;
  }
}

function pickLine(lines: string[], fallback: string) {
  return lines.length > 0 ? lines[0] : fallback;
}

function hasAny(text: string, pattern: RegExp) {
  return pattern.test(text);
}

export function buildProactiveFallback(memory: GuideMemoryBundle) {
  const recentCount = memory.recent_context.length;
  const longCount = memory.long_term_callbacks.length;
  return `探险家，今天也一起推进吧。我刚复盘了你最近 ${recentCount} 条近况和 ${longCount} 条长期记忆，先从一个最小动作开始如何？`;
}

export function buildEventFallback(
  memory: GuideMemoryBundle,
): GuideDailyEventDraft {
  const joined = memory.behavior_signals.join(" ");
  if (hasAny(joined, /夜间|熬夜|高强度|疲劳|睡眠不足/)) {
    return {
      title: "恢复支线：洗个热水澡，然后听 10 分钟音乐",
      description: "你最近推进很猛。今晚先让自己放松下来。",
      reward_xp: 30,
      reward_gold: 60,
      reason: "依据近期高强度信号生成。",
    };
  }
  if (hasAny(joined, /连续|稳定|清盘|连胜/)) {
    return {
      title: "稳态支线：写下明天最重要的三件事并排好顺序",
      description: "花 5 分钟预排，明天醒来就知道先做什么。",
      reward_xp: 25,
      reward_gold: 40,
      reason: "依据连续推进信号生成。",
    };
  }
  return {
    title: "轻量支线：出门走 15 分钟，回来喝一杯水",
    description: "活动一下身体，补充水分，之后做事会更专注。",
    reward_xp: 20,
    reward_gold: 35,
    reason: "依据近期任务节奏生成。",
  };
}

export function buildChatFallback(
  memory: GuideMemoryBundle,
  message: string,
): GuideChatDraft {
  const wantsRecovery = /恢复|休息|累|睡|放松|拉伸|洗澡|音乐|walk|rest|recover/i
    .test(message);
  const recentCount = memory.recent_context.length;
  const reply = wantsRecovery
    ? "收到。建议先做恢复型动作，再继续推进主线。要不要我现在给你一条轻量恢复任务？"
    : `我已复盘你最近 ${recentCount} 条记忆。你想继续聊今天，还是回看上周节奏？`;

  return {
    reply,
    quick_actions: ["继续聊今天", "回看上周", "给我一个恢复任务"],
    suggested_task: wantsRecovery
      ? {
        title: "恢复支线：站起来拉伸 8 分钟，再喝一杯水",
        description: "先让身体动起来，补充水分后再继续推进。",
        xp_reward: 22,
        quest_tier: "Daily",
      }
      : undefined,
  };
}

export function buildNightReflectionFallback(
  memory: GuideMemoryBundle,
): GuideNightReflectionDraft {
  const today = pickLine(memory.recent_context, "今天的节奏已经记录完成。");
  return {
    opening: `今夜结算完成。你今天的关键足迹是：${today}`,
    follow_up_question:
      "现在身体感觉如何？要不要我给你加一个明天可执行的轻恢复任务？",
    suggested_task: {
      title: "明日恢复支线：起床后拉伸 10 分钟",
      description: "用一个简单的动作开启新一天，降低启动压力。",
      xp_reward: 24,
      quest_tier: "Daily",
    },
  };
}

export async function generateProactiveMessage(memory: GuideMemoryBundle) {
  const fallback = { proactive_message: buildProactiveFallback(memory) };
  const systemPrompt =
    "你是地球Online的专属向导。基于用户记忆，生成一句主动搭话。语气关心+轻松调侃，必须引用至少一条历史事实。只输出JSON。";
  const userPrompt = `
请基于以下记忆生成主动搭话。
记忆：
${memory.packed_context}

输出格式：{"proactive_message":"..."}
`.trim();
  const llm = await callJsonLLM<{ proactive_message?: string }>(
    systemPrompt,
    userPrompt,
    fallback,
  );
  return capLen(
    toText(llm?.proactive_message) || fallback.proactive_message,
    280,
  );
}

export async function generateDailyEvent(memory: GuideMemoryBundle) {
  const fallback = buildEventFallback(memory);
  const systemPrompt =
    "你是地球Online的游戏GM。请根据用户近期与长期记忆生成一个每日突发事件任务。title必须是一个具体的、马上能做的小动作（如'出门散步15分钟''整理书桌''给朋友发一条消息'），禁止抽象描述（如'恢复节奏''提升效率'），禁止虚构场景（如铁匠铺、新手村）。只输出JSON。";
  const userPrompt = `
请生成每日突发事件，字段如下：
{
  "title":"一个具体可执行的小动作",
  "description":"为什么现在建议做这件事",
  "reward_xp":30,
  "reward_gold":50,
  "reason":"引用记忆依据"
}

记忆：
${memory.packed_context}
`.trim();
  const llm = await callJsonLLM<Partial<GuideDailyEventDraft>>(
    systemPrompt,
    userPrompt,
    fallback,
  );
  return sanitizeEventDraft(llm, fallback);
}

export async function generateChat(
  memory: GuideMemoryBundle,
  scene: string,
  message: string,
) {
  const fallback = buildChatFallback(memory, message);
  const systemPrompt =
    "你是地球Online专属向导。请基于用户记忆回复，不要模板化寒暄。保持短句，给出可执行建议。如果建议任务，title必须是一个具体的、马上能做的小动作（如'喝一杯水''站起来拉伸5分钟''出门走10分钟'），禁止抽象描述（如'恢复节奏''调整状态'）。禁止虚构场景。只输出JSON。";
  const userPrompt = `
场景: ${scene}
用户消息: ${message}
记忆:
${memory.packed_context}

输出格式:
{
  "reply":"...",
  "quick_actions":["继续聊今天","回看上周","给我一个恢复任务"],
  "suggested_task":{
    "title":"具体动作，如：喝一杯温水、拉伸5分钟、出门散步10分钟",
    "description":"为什么建议做这件事",
    "xp_reward":20,
    "quest_tier":"Daily"
  }
}
suggested_task 可省略。title 必须是具体可执行的小动作，不能是抽象描述。
`.trim();
  const llm = await callJsonLLM<Partial<GuideChatDraft>>(
    systemPrompt,
    userPrompt,
    fallback,
  );
  return sanitizeChatDraft(llm, fallback);
}

export async function generateNightReflection(
  memory: GuideMemoryBundle,
  dayId: string,
) {
  const fallback = buildNightReflectionFallback(memory);
  const systemPrompt =
    "你是地球Online夜间向导。请做两轮复盘：先总结今天，再问一个关怀问题，并给出明日建议任务。title必须是一个具体小动作（如'晨间拉伸10分钟''喝一杯温水''整理明天要用的东西'），禁止抽象描述，禁止虚构场景。只输出JSON。";
  const userPrompt = `
目标日期: ${dayId}
记忆:
${memory.packed_context}

输出格式:
{
  "opening":"...",
  "follow_up_question":"...",
  "suggested_task":{
    "title":"一个具体可执行的小动作",
    "description":"为什么建议明天做这件事",
    "xp_reward":22,
    "quest_tier":"Daily"
  }
}
`.trim();
  const llm = await callJsonLLM<Partial<GuideNightReflectionDraft>>(
    systemPrompt,
    userPrompt,
    fallback,
  );
  return sanitizeNightReflectionDraft(llm, fallback);
}

function sanitizeSuggestedTask(
  raw: unknown,
  fallback: GuideSuggestedTask,
): GuideSuggestedTask {
  const map = raw && typeof raw === "object"
    ? raw as Record<string, unknown>
    : {};
  const tierRaw = toText(map.quest_tier);
  const tier = (tierRaw === "Main_Quest" || tierRaw === "Side_Quest" ||
      tierRaw === "Daily")
    ? tierRaw
    : fallback.quest_tier;
  return {
    title: toText(map.title) || fallback.title,
    description: toText(map.description) || fallback.description,
    xp_reward: toInt(map.xp_reward, fallback.xp_reward, 5, 120),
    quest_tier: tier as GuideSuggestedTask["quest_tier"],
  };
}

function sanitizeEventDraft(
  raw: Partial<GuideDailyEventDraft> | undefined,
  fallback: GuideDailyEventDraft,
): GuideDailyEventDraft {
  return {
    title: toText(raw?.title) || fallback.title,
    description: toText(raw?.description) || fallback.description,
    reward_xp: toInt(raw?.reward_xp, fallback.reward_xp, 0, 200),
    reward_gold: toInt(raw?.reward_gold, fallback.reward_gold, 0, 2000),
    reason: toText(raw?.reason) || fallback.reason,
  };
}

function sanitizeChatDraft(
  raw: Partial<GuideChatDraft> | undefined,
  fallback: GuideChatDraft,
): GuideChatDraft {
  const reply = toText(raw?.reply) || fallback.reply;
  const actions = Array.isArray(raw?.quick_actions)
    ? raw!.quick_actions!.map((x) => toText(x)).filter(Boolean).slice(0, 3)
    : fallback.quick_actions;
  const fallbackTask = fallback.suggested_task || {
    title: "恢复支线：闭眼深呼吸 3 分钟",
    description: "先稳定节奏，再继续推进。",
    xp_reward: 12,
    quest_tier: "Daily" as const,
  };
  const suggestedTask = raw?.suggested_task
    ? sanitizeSuggestedTask(raw.suggested_task, fallbackTask)
    : fallback.suggested_task;
  return {
    reply: capLen(reply, 500),
    quick_actions: actions.length > 0 ? actions : fallback.quick_actions,
    suggested_task: suggestedTask,
  };
}

function sanitizeNightReflectionDraft(
  raw: Partial<GuideNightReflectionDraft> | undefined,
  fallback: GuideNightReflectionDraft,
): GuideNightReflectionDraft {
  return {
    opening: capLen(toText(raw?.opening) || fallback.opening, 500),
    follow_up_question: capLen(
      toText(raw?.follow_up_question) || fallback.follow_up_question,
      220,
    ),
    suggested_task: sanitizeSuggestedTask(
      raw?.suggested_task,
      fallback.suggested_task,
    ),
  };
}

function capLen(text: string, max: number) {
  if (text.length <= max) return text;
  return `${text.slice(0, Math.max(0, max - 3))}...`;
}
