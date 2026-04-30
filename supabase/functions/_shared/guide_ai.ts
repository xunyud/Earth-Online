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

type GuideLanguage = "zh" | "en";

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
  const key = Deno.env.get("OPENAI_API_KEY") ||
    Deno.env.get("DEEPSEEK_API_KEY") || "";
  return key.trim();
}

export function normalizeOpenAICompatibleBaseUrl(baseUrl: string) {
  const trimmed = baseUrl.trim().replace(/\/+$/, "");
  if (!trimmed) return "https://api.86gamestore.com/v1";
  return trimmed.endsWith("/v1") ? trimmed : `${trimmed}/v1`;
}

function getApiBaseUrl() {
  const baseUrl = Deno.env.get("OPENAI_BASE_URL") ||
    Deno.env.get("DEEPSEEK_BASE_URL") ||
    "https://api.86gamestore.com";
  return normalizeOpenAICompatibleBaseUrl(baseUrl);
}

async function callJsonLLM<T>(
  systemPrompt: string,
  userPrompt: string,
  fallback: T,
): Promise<T> {
  const apiKey = getApiKey();
  if (!apiKey) return fallback;

  try {
    const resp = await fetch(
      `${getApiBaseUrl().replace(/\/+$/, "")}/chat/completions`,
      {
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
      },
    );
    if (!resp.ok) {
      console.warn(
        "guide_ai llm request failed:",
        resp.status,
        await resp.text(),
      );
      return fallback;
    }
    const data = await resp.json();
    const content = toText(data?.choices?.[0]?.message?.content);
    if (!content) return fallback;
    return JSON.parse(stripJsonFence(content)) as T;
  } catch (error) {
    console.warn("guide_ai llm request threw:", error);
    return fallback;
  }
}

/**
 * 多模态输入内容类型，支持文本和图片 URL 两种格式。
 * 用于 callMultimodalLLM 的 contents 参数。
 */
export type MultimodalContent =
  | { type: "text"; text: string }
  | { type: "image_url"; image_url: { url: string } };

/**
 * 图片识别返回结构，包含识别文本、建议任务标题和场景描述。
 */
export type ImageRecognitionResult = {
  text_content: string;
  suggested_task_title: string;
  scene_description: string;
};

/**
 * 统一多模态 LLM 调用函数，支持文本和图片输入。
 * 复用现有 OPENAI_API_KEY 和 OPENAI_BASE_URL 配置。
 * 默认超时 15 秒（图片/音频处理需要更长时间）。
 * 任何失败（HTTP 错误、超时、JSON 解析失败）均返回 fallback 值，不抛异常。
 */
export async function callMultimodalLLM<T>(
  contents: MultimodalContent[],
  systemPrompt: string,
  fallback: T,
  opts?: { timeoutMs?: number },
): Promise<T> {
  const apiKey = getApiKey();
  if (!apiKey) return fallback;

  const timeoutMs = opts?.timeoutMs ?? 15000;

  try {
    const resp = await fetch(
      `${getApiBaseUrl().replace(/\/+$/, "")}/chat/completions`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: Deno.env.get("OPENAI_MODEL") || "deepseek-chat",
          temperature: 0.3,
          messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: contents },
          ],
          response_format: { type: "json_object" },
        }),
        signal: AbortSignal.timeout(timeoutMs),
      },
    );

    if (!resp.ok) {
      console.warn("callMultimodalLLM: HTTP", resp.status);
      return fallback;
    }

    const data = await resp.json();
    const raw = toText(data?.choices?.[0]?.message?.content);
    if (!raw) return fallback;
    return JSON.parse(stripJsonFence(raw)) as T;
  } catch (err) {
    console.warn("callMultimodalLLM: 调用失败，返回 fallback", err);
    return fallback;
  }
}


function pickLine(lines: string[], fallback: string) {
  return lines.length > 0 ? lines[0] : fallback;
}

function toRecord(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
}

function hasAny(text: string, pattern: RegExp) {
  return pattern.test(text);
}

function hasChinese(text: string) {
  return /[\u3400-\u9FFF]/.test(text);
}

function hasEnglishText(text: string) {
  return /[A-Za-z]{3,}/.test(text);
}

export function detectGuideLanguage(
  message: string,
  clientContext?: Record<string, unknown>,
): GuideLanguage {
  const context = toRecord(clientContext);
  const explicitCode = toText(context.language_code).toLowerCase();
  if (explicitCode.startsWith("en")) return "en";
  if (explicitCode.startsWith("zh")) return "zh";
  if (context.is_english === true) return "en";
  if (context.is_english === false) return "zh";
  if (hasChinese(message)) return "zh";
  if (hasEnglishText(message)) return "en";
  return "zh";
}

function containsCjk(text: string) {
  return /[\u3400-\u9fff]/.test(text);
}

export function resolveGuideLanguage(
  memory: GuideMemoryBundle,
  options: {
    message?: string;
    clientContext?: Record<string, unknown>;
  } = {},
): GuideLanguage {
  const context = options.clientContext ?? {};
  const rawCode = toText(context.language_code) || toText(context.locale) ||
    toText(context.lang);
  const normalizedCode = rawCode.toLowerCase();
  if (normalizedCode.startsWith("en")) return "en";
  if (normalizedCode.startsWith("zh")) return "zh";
  if (context.is_english === true) return "en";
  if (context.is_english === false) return "zh";

  const sample = [
    toText(options.message),
    ...memory.recent_context,
    ...memory.long_term_callbacks,
    ...memory.behavior_signals,
    memory.memory_digest,
    memory.packed_context,
  ].join(" ");

  if (containsCjk(sample)) return "zh";
  if (/[A-Za-z]/.test(sample)) return "en";
  return "zh";
}

function buildEnglishQuickActions() {
  return [
    "Continue with today",
    "Review last week",
    "Give me a recovery task",
  ];
}

function buildChineseQuickActions() {
  return ["继续聊今天", "回看上周", "给我一个恢复任务"];
}

export function buildProactiveFallback(
  memory: GuideMemoryBundle,
  clientContext?: Record<string, unknown>,
) {
  const recentCount = memory.recent_context.length;
  const longCount = memory.long_term_callbacks.length;
  if (resolveGuideLanguage(memory, { clientContext }) === "en") {
    return `I reviewed ${recentCount} recent update${
      recentCount === 1 ? "" : "s"
    } and ${longCount} longer-term memor${
      longCount === 1 ? "y" : "ies"
    }. Want to start with one small step?`;
  }
  return `探险家，今天也一起推进吧。我刚复盘了你最近 ${recentCount} 条近况和 ${longCount} 条长期记忆，先从一个最小动作开始如何？`;
}

export function buildEventFallback(
  memory: GuideMemoryBundle,
  clientContext?: Record<string, unknown>,
): GuideDailyEventDraft {
  const language = resolveGuideLanguage(memory, { clientContext });
  const joined = memory.behavior_signals.join(" ");

  if (language === "en") {
    if (
      hasAny(
        joined,
        /late night|fatigue|sleep debt|tired|high pressure|overload/i,
      )
    ) {
      return {
        title:
          "Recovery side quest: take a warm shower and play music for 10 minutes",
        description:
          "You have been pushing hard lately. Tonight, let your body settle first.",
        reward_xp: 30,
        reward_gold: 60,
        reason: "Generated from recent high-pressure signals.",
      };
    }
    if (hasAny(joined, /steady|consistent|streak|routine|momentum/i)) {
      return {
        title:
          "Steady-progress side quest: write down tomorrow's top three priorities",
        description:
          "Spend five minutes ordering tomorrow so the first step is already clear.",
        reward_xp: 25,
        reward_gold: 40,
        reason: "Generated from recent consistency signals.",
      };
    }
    return {
      title:
        "Light side quest: take a 15-minute walk and drink a glass of water",
      description:
        "Reset your body a little now so the next work block feels easier to enter.",
      reward_xp: 20,
      reward_gold: 35,
      reason: "Generated from your recent task rhythm.",
    };
  }

  if (hasAny(joined, /夜间|熬夜|高强度|疲劳|睡眠不足/)) {
    return {
      title: "恢复支线：洗个热水澡，然后听 10 分钟音乐",
      description: "你最近推进得很猛。今晚先让自己放松下来。",
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
  clientContext?: Record<string, unknown>,
): GuideChatDraft {
  const language = resolveGuideLanguage(memory, { message, clientContext });
  const wantsRecovery =
    /恢复|休息|累|放松|拉伸|洗澡|音乐|walk|rest|recover|reset|overloaded|overwhelmed/i
      .test(message);
  const recentCount = memory.recent_context.length;

  if (language === "en") {
    const reply = wantsRecovery
      ? "I hear you. Let us step out of the main track for a moment and start with a recovery-sized action. Want me to suggest one now?"
      : `I reviewed your latest ${recentCount} memor${
        recentCount === 1 ? "y" : "ies"
      }. Do you want to stay with today, review last week, or get one recovery task?`;
    return {
      reply,
      quick_actions: buildEnglishQuickActions(),
      suggested_task: wantsRecovery
        ? {
          title:
            "Recovery side quest: stand up, stretch for 8 minutes, then drink water",
          description:
            "Help your body settle first, then decide whether to keep pushing.",
          xp_reward: 22,
          quest_tier: "Daily",
        }
        : undefined,
    };
  }

  const reply = wantsRecovery
    ? "收到。建议先做恢复型动作，再继续推进主线。要不要我现在给你一条轻量恢复任务？"
    : `我已复盘你最近 ${recentCount} 条记忆。你想继续聊今天，还是回看上周节奏？`;

  return {
    reply,
    quick_actions: buildChineseQuickActions(),
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
  clientContext?: Record<string, unknown>,
): GuideNightReflectionDraft {
  if (resolveGuideLanguage(memory, { clientContext }) === "en") {
    const today = pickLine(
      memory.recent_context,
      "Today's rhythm has already been captured.",
    );
    return {
      opening:
        `Tonight's recap is ready. The key trace from today is: ${today}`,
      follow_up_question:
        "How does your body feel right now? Do you want one light recovery task for tomorrow?",
      suggested_task: {
        title:
          "Tomorrow recovery side quest: stretch for 10 minutes after waking up",
        description:
          "Use one simple movement to lower the friction of starting tomorrow.",
        xp_reward: 24,
        quest_tier: "Daily",
      },
    };
  }

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

/**
 * 从 packed_context 中提取行为信号区域作为行为模式摘要。
 * 解析【行为信号】区域的内容，返回拼接后的摘要文本。
 * packed_context 为空或不含行为信号区域时返回空字符串。
 */
export function extractBehaviorSummary(packedContext: string): string {
  if (!packedContext) return "";
  // 匹配【行为信号】区域，提取到下一个【...】区域或字符串末尾
  const match = packedContext.match(/【行为信号】\n([\s\S]*?)(?=\n【|$)/);
  if (!match || !match[1]) return "";
  const lines = match[1].trim().split("\n").filter((l) => l.trim());
  if (lines.length === 0) return "";
  // 去掉序号前缀（如 "1. "），拼接为摘要
  return lines.map((l) => l.replace(/^\d+\.\s*/, "").trim()).filter(Boolean)
    .join("；");
}

/**
 * 判断是否应使用 fallback（随机生成）路径。
 * 当结构化记忆条数不足 3 条时降级为随机生成。
 */
export function shouldUseFallback(structuredMemoryCount: number): boolean {
  return structuredMemoryCount < 3;
}


export async function generateProactiveMessage(
  memory: GuideMemoryBundle,
  clientContext?: Record<string, unknown>,
) {
  const language = resolveGuideLanguage(memory, { clientContext });
  const fallback = {
    proactive_message: buildProactiveFallback(memory, clientContext),
  };
  const systemPrompt = language === "en"
    ? "You are the user's companion in Earth Online. Based on remembered context, write one gentle proactive check-in sentence. Keep it warm, grounded, and specific. Reference at least one real prior fact. Output JSON only."
    : "你是地球Online的专属向导。基于用户记忆，生成一句主动搭话。语气关心、轻松调低，必须引用至少一条历史事实。只输出JSON。";
  const userPrompt = language === "en"
    ? `
Please generate one proactive check-in based on the remembered context below.
Memory:
${memory.packed_context}

Output format: {"proactive_message":"..."}
`.trim()
    : `
请基于以下记忆生成主动搭话。记忆：
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

export async function generateDailyEvent(
  memory: GuideMemoryBundle,
  clientContext?: Record<string, unknown>,
) {
  const language = resolveGuideLanguage(memory, { clientContext });
  const fallback = buildEventFallback(memory, clientContext);

  // 记忆不足 3 条时降级为随机生成模式（基于 recent_context 条数判断记忆丰富度）
  if (shouldUseFallback(memory.recent_context.length)) {
    return fallback;
  }

  // 从 packed_context 中提取行为模式摘要，注入 LLM prompt 引导个性化生成
  const behaviorSummary = extractBehaviorSummary(memory.packed_context);

  const behaviorInjection = behaviorSummary
    ? language === "en"
      ? `\nRecent behavior patterns: ${behaviorSummary}\nPlease generate a personalized challenge based on the user's actual behavior patterns.`
      : `\n用户近期行为模式：${behaviorSummary}\n请基于用户的实际行为模式生成个性化挑战。`
    : "";

  const systemPrompt = language === "en"
    ? `You are the game master for Earth Online. Generate one small, concrete daily event task from the user's recent and long-term memory. The title must be a specific action the user can do right now. Avoid abstract wording and fictional world-building. Output JSON only.${behaviorInjection}`
    : `你是地球Online的游戏DM。请根据用户近期与长期记忆生成一个每日突发事件任务。Title必须是一个具体的、马上能做的小动作，禁止抽象描述，禁止虚构场景。只输出JSON。${behaviorInjection}`;
  const userPrompt = language === "en"
    ? `
Generate one daily event with this JSON shape:
{
  "title":"one concrete action the user can do now",
  "description":"why this is the right move now",
  "reward_xp":30,
  "reward_gold":50,
  "reason":"cite the memory basis"
}

Memory:
${memory.packed_context}
`.trim()
    : `
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
  clientContext?: Record<string, unknown>,
) {
  const language = resolveGuideLanguage(memory, { message, clientContext });
  const fallback = buildChatFallback(memory, message, clientContext);
  const systemPrompt = language === "en"
    ? "You are the user's companion in Earth Online. Reply from remembered context in a short, grounded way. Avoid generic therapy language. Give practical next-step guidance. If you suggest a task, the title must be a concrete action the user can do immediately. Avoid abstract wording and fictional world-building. You can generate memory portraits based on the user's recent actions and long-term patterns — if the context includes [记忆画像] data, you may reference it naturally to explain what shaped the portrait. Output JSON only."
    : "你是地球Online专属向导。请基于用户记忆回复，不要模板化安慰。保持短句，给出可执行建议。如果建议任务，title必须是一个具体的、马上能做的小动作，禁止抽象描述，禁止虚构场景。你具备记忆画像能力——能根据用户近期行动节奏、长期习惯和行为信号生成专属画像。如果上下文中包含[记忆画像]数据，可以自然地引用它来解释画像的生成依据。只输出JSON。";
  const userPrompt = language === "en"
    ? `
Scene: ${scene}
User message: ${message}
Memory:
${memory.packed_context}

Output format:
{
  "reply":"...",
  "quick_actions":["Continue with today","Review last week","Give me a recovery task"],
  "suggested_task":{
    "title":"a concrete action such as drink water, stretch for 5 minutes, or take a 10-minute walk",
    "description":"why this is the right suggestion now",
    "xp_reward":20,
    "quest_tier":"Daily"
  }
}
suggested_task is optional. The title must be concrete and immediately actionable.
`.trim()
    : `
场景: ${scene}
用户消息: ${message}
记忆:
${memory.packed_context}

输出格式:
{
  "reply":"...",
  "quick_actions":["继续聊今天","回看上周","给我一个恢复任务"],
  "suggested_task":{
    "title":"具体动作，如喝一杯温水、拉伸 5 分钟、出门散步 10 分钟",
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
  clientContext?: Record<string, unknown>,
) {
  const language = resolveGuideLanguage(memory, { clientContext });
  const fallback = buildNightReflectionFallback(memory, clientContext);
  const systemPrompt = language === "en"
    ? "You are the user's night companion in Earth Online. Do a two-part reflection: summarize today, then ask one caring follow-up question, and suggest one concrete task for tomorrow. Avoid abstract wording and fictional world-building. Output JSON only."
    : "你是地球Online夜间向导。请做两轮复盘：先总结今天，再问一个关怀问题，并给出明日建议任务。title必须是一个具体小动作，禁止抽象描述，禁止虚构场景。只输出JSON。";
  const userPrompt = language === "en"
    ? `
Target day: ${dayId}
Memory:
${memory.packed_context}

Output format:
{
  "opening":"...",
  "follow_up_question":"...",
  "suggested_task":{
    "title":"one concrete action the user can actually do",
    "description":"why tomorrow should start here",
    "xp_reward":22,
    "quest_tier":"Daily"
  }
}
`.trim()
    : `
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
    description: "先稳住节奏，再继续推进。",
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
