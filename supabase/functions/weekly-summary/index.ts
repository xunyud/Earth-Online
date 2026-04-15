import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { EverMemOSClient } from "../_shared/evermemos_client.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type QuestRow = {
  title: string;
  quest_tier?: string | null;
  xp_reward?: number | null;
  exp?: number | null;
  completed_at?: string | null;
};

const WEEKLY_SUMMARY_PREFIX = "[WEEKLY_SUMMARY]";
type SummaryLanguage = "zh" | "en";

function formatDateId(d: Date) {
  const y = d.getUTCFullYear().toString().padStart(4, "0");
  const m = (d.getUTCMonth() + 1).toString().padStart(2, "0");
  const day = d.getUTCDate().toString().padStart(2, "0");
  return `${y}-${m}-${day}`;
}

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

function localizedText(language: SummaryLanguage, zh: string, en: string) {
  return language === "en" ? en : zh;
}

function resolveRequestedLanguage(body?: Record<string, unknown>) {
  const explicitCode = toText(body?.language_code).toLowerCase();
  if (explicitCode.startsWith("en")) return "en" as const;
  if (explicitCode.startsWith("zh")) return "zh" as const;
  if (body?.is_english === true) return "en" as const;
  if (body?.is_english === false) return "zh" as const;
  return null;
}

function getRequiredEnv(name: string) {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing ${name} env`);
  }
  return value;
}

function getLlmApiKey() {
  const openai = Deno.env.get("OPENAI_API_KEY");
  const deepseek = Deno.env.get("DEEPSEEK_API_KEY");
  const key = openai || deepseek;
  if (!key) {
    throw new Error("Missing OPENAI_API_KEY or DEEPSEEK_API_KEY env");
  }
  return key;
}

function getLlmBaseUrl() {
  const baseUrl = Deno.env.get("OPENAI_BASE_URL") ||
    Deno.env.get("DEEPSEEK_BASE_URL") ||
    "https://api.86gamestore.com";
  const normalized = baseUrl.trim().replace(/\/+$/, "");
  return normalized.endsWith("/v1") ? normalized : `${normalized}/v1`;
}

function runFireAndForget(task: Promise<unknown>) {
  const edgeRuntime = (globalThis as unknown as {
    EdgeRuntime?: { waitUntil?: (p: Promise<unknown>) => void };
  }).EdgeRuntime;
  if (edgeRuntime?.waitUntil) {
    edgeRuntime.waitUntil(task);
    return;
  }
  task.catch((err) =>
    console.warn("fire-and-forget error:", toErrorMessage(err))
  );
}

function syncDiaryMemoryFireAndForget(
  supabaseUrl: string,
  serviceRole: string,
  userId: string,
  summary: string,
) {
  const content = summary.trim();
  if (!content) return;
  const endpoint = `${
    supabaseUrl.replace(/\/+$/, "")
  }/functions/v1/sync-user-memory`;
  const timeoutMsRaw = Number(
    Deno.env.get("EVERMEMOS_SYNC_TIMEOUT_MS") ?? "1500",
  );
  const timeoutMs = Number.isFinite(timeoutMsRaw) && timeoutMsRaw > 0
    ? timeoutMsRaw
    : 1500;
  const signal = AbortSignal.timeout(timeoutMs);
  const request = fetch(endpoint, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${serviceRole}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      user_id: userId,
      event_type: "diary",
      content,
    }),
    signal,
  }).then(async (resp) => {
    if (resp.ok) return;
    const raw = await resp.text();
    console.warn(`sync-user-memory not ok: ${resp.status} ${raw}`);
  }).catch((err) => {
    console.warn("sync-user-memory skipped:", toErrorMessage(err));
  });
  runFireAndForget(request);
}

async function fetchWeeklyQuests(
  supabase: any,
  userId: string,
  sevenDaysAgoIso: string,
): Promise<QuestRow[]> {
  const attempts = [
    supabase
      .from("quest_nodes")
      .select("title,quest_tier,xp_reward,exp,completed_at")
      .eq("user_id", userId)
      .eq("is_completed", true)
      .gte("completed_at", sevenDaysAgoIso)
      .order("completed_at", { ascending: false }),
    supabase
      .from("quest_nodes")
      .select("title,quest_tier,xp_reward,completed_at")
      .eq("user_id", userId)
      .eq("is_completed", true)
      .gte("completed_at", sevenDaysAgoIso)
      .order("completed_at", { ascending: false }),
  ];

  let lastErr: any = null;
  for (const p of attempts) {
    const { data, error } = await p;
    if (!error) return (data ?? []) as QuestRow[];
    lastErr = error;
  }
  throw lastErr ?? new Error("fetchWeeklyQuests failed");
}

async function fetchWeeklyLogs(
  supabase: any,
  _userId: string,
  _sevenDaysAgoIso: string,
  sevenDaysAgoDateId: string,
) {
  // daily_logs 表实际列：date_id, completed_count, is_perfect, encouragement
  const { data, error } = await supabase
    .from("daily_logs")
    .select("*")
    .eq("user_id", _userId)
    .gte("date_id", sevenDaysAgoDateId)
    .order("date_id", { ascending: false });

  if (error) {
    console.error("fetchWeeklyLogs error:", JSON.stringify(error));
    return [];
  }
  return (data ?? []) as Array<Record<string, unknown>>;
}

function normalizeMemoryItems(
  raw: unknown,
): Array<Record<string, unknown> | string> {
  if (Array.isArray(raw)) return raw as Array<Record<string, unknown> | string>;
  if (!raw || typeof raw !== "object") return [];
  const container = raw as Record<string, unknown>;
  const candidates = [
    container.memories,
    container.results,
    container.items,
    container.data,
  ];
  for (const c of candidates) {
    if (Array.isArray(c)) return c as Array<Record<string, unknown> | string>;
  }
  return [];
}

function parseMemoryLine(item: Record<string, unknown> | string) {
  if (typeof item === "string") return item.trim();
  const content = toText(item.content) || toText(item.memory) ||
    toText(item.text) || toText(item.message);
  if (!content) return "";
  const ts = toText(item.create_time) || toText(item.created_at) ||
    toText(item.timestamp) || toText(item.time);
  if (!ts) return content;
  return `[${ts}] ${content}`;
}

function formatMemoryRecallText(
  rawSearchResp: unknown,
  language: SummaryLanguage,
): string {
  const items = normalizeMemoryItems(rawSearchResp);
  if (items.length === 0) {
    return localizedText(
      language,
      "长期记忆回溯：暂无可用历史记忆。",
      "Long-term memory recall: no usable history yet.",
    );
  }
  const lines = items
    .slice(0, 5)
    .map(parseMemoryLine)
    .filter(Boolean);
  if (lines.length === 0) {
    return localizedText(
      language,
      "长期记忆回溯：暂无可用历史记忆。",
      "Long-term memory recall: no usable history yet.",
    );
  }
  const header = localizedText(
    language,
    "长期记忆回溯：",
    "Long-term memory recall:",
  );
  return `${header}\n${
    lines.map((line, idx) => `${idx + 1}. ${line}`).join("\n")
  }`;
}

function extractWeeklyKeyword(
  logs: Array<Record<string, unknown>>,
  language: SummaryLanguage,
): string {
  const rawText = logs
    .map((r) =>
      toText(r.content) ||
      toText(r.text) ||
      toText(r.note) ||
      toText(r.summary) ||
      toText(r.encouragement)
    )
    .filter(Boolean)
    .join(" ");
  if (!rawText) {
    return localizedText(
      language,
      "本周情绪与任务进展",
      "Weekly mood and task progress",
    );
  }
  const tokens = rawText
    .toLowerCase()
    .match(/[a-z]{4,}|[\u4e00-\u9fa5]{2,6}/g) ?? [];
  const stopwords = new Set([
    "本周",
    "今天",
    "然后",
    "因为",
    "我们",
    "你们",
    "他们",
    "就是",
    "这个",
    "那个",
    "任务",
    "完成",
    "自己",
    "感觉",
    "有点",
    "已经",
    "需要",
    "一下",
    "一个",
    "没有",
    "daily",
    "logs",
    "summary",
    "encouragement",
  ]);
  const counter = new Map<string, number>();
  for (const token of tokens) {
    if (stopwords.has(token)) continue;
    counter.set(token, (counter.get(token) ?? 0) + 1);
  }
  const top = [...counter.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([word]) => word);
  if (top.length === 0) {
    return localizedText(
      language,
      "本周情绪与任务进展",
      "Weekly mood and task progress",
    );
  }
  return top.join(" ");
}

function containsCjk(text: string) {
  return /[\u3400-\u9fff]/.test(text);
}

function resolveSummaryLanguage(
  payloadText: string,
  memoryRecallText: string,
  body?: Record<string, unknown>,
) {
  const requested = resolveRequestedLanguage(body);
  if (requested) return requested;

  const sample = `${payloadText}\n${memoryRecallText}`;
  if (containsCjk(sample)) return "zh" as const;
  if (/[A-Za-z]{3,}/.test(sample)) return "en" as const;
  return "zh" as const;
}

function buildWeeklyScaffolding(language: SummaryLanguage) {
  return {
    noQuestLines: localizedText(
      language,
      "- 本周暂无已完成任务记录",
      "- No completed quests recorded this week",
    ),
    noLogLines: localizedText(
      language,
      "- 本周暂无日记记录",
      "- No diary entries recorded this week",
    ),
    emptySnippet: localizedText(language, "(空)", "(empty)"),
    playerIdLabel: localizedText(language, "玩家ID", "Player ID"),
    timeRangeLabel: localizedText(language, "时间范围", "Time Range"),
    questsLabel: localizedText(
      language,
      "【已完成任务】",
      "[Completed Quests]",
    ),
    logsLabel: localizedText(language, "【日记片段】", "[Diary Notes]"),
    unknownDate: localizedText(language, "unknown-date", "unknown-date"),
    memoryRecallEmpty: localizedText(
      language,
      "长期记忆回溯：暂无可用历史记忆。",
      "Long-term memory recall: no usable history yet.",
    ),
  };
}

async function callWeeklyLLM(
  payloadText: string,
  memoryRecallText: string,
  apiKey: string,
  language: "zh" | "en",
) {
  const systemPrompt = language === "en"
    ? `
You are the warm and observant village chief of Earth Online.
Use this week's data and the provided long-term memory recall to write a weekly adventure report that feels continuous, caring, and grounded in real life.

[LONG_TERM_MEMORY_RECALL]
${memoryRecallText}
`.trim()
    : `
你是一个幽默且充满智慧的「地球Online」NPC村长。
请结合本周数据，并参考系统提供的【长期记忆回溯】，在信件中温柔地提及过去，让用户感受到时间连贯的情感陪伴。

【长期记忆回溯】
${memoryRecallText}
`.trim();
  const userPrompt = language === "en"
    ? `
Please write a personalized weekly adventure report based on this week's completed tasks and diary notes.
Requirements:
1. Address the player as "Brave apprentice villager".
2. Summarize the highlights of the week.
3. Reflect on the user's emotional state or rhythm this week and offer encouragement.
4. Give one short action suggestion for next week in the village-chief voice. It must be realistic and actionable in everyday life.
5. Format the answer in Markdown and use a few fitting emoji.

This week's data:
${payloadText}
`.trim()
    : `
请根据玩家本周完成的任务流水和日记记录，生成一份专属的「本周冒险周报」。
要求：
1. 称呼玩家为「勇敢的见习村民」。
2. 总结本周的高光时刻（做了哪些重要的事）。
3. 结合日记分析本周的情绪或状态，并给予鼓励。
4. 给出下周的一条简短的行动建议（NPC口吻），建议必须是现实生活中可执行的（如运动、整理、学习等），禁止虚构场景。
5. 排版使用 Markdown，加入适当的 Emoji。

以下是本周数据：
${payloadText}
`.trim();

  const resp = await fetch(`${getLlmBaseUrl()}/chat/completions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "deepseek-chat",
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.7,
    }),
  });

  if (!resp.ok) {
    const txt = await resp.text();
    throw new Error(`LLM API Error: ${resp.status} - ${txt}`);
  }
  const data = await resp.json();
  const content = data?.choices?.[0]?.message?.content;
  const summary = toText(content);
  if (!summary) throw new Error("LLM returned empty summary");
  return summary;
}

async function saveSummaryToDiary(
  supabase: any,
  userId: string,
  summary: string,
) {
  const today = formatDateId(new Date());
  const encouragement = `${WEEKLY_SUMMARY_PREFIX}\n${summary}`;

  // 先尝试更新当天已有记录，仅写入 encouragement，不覆盖 completed_count / is_perfect
  const { data, error: updateErr } = await supabase
    .from("daily_logs")
    .update({ encouragement })
    .eq("user_id", userId)
    .eq("date_id", today)
    .select("date_id");

  if (!updateErr && data && data.length > 0) return;

  // 当天暂无记录，插入完整行
  const { error: insertErr } = await supabase.from("daily_logs").insert({
    user_id: userId,
    date_id: today,
    completed_count: 0,
    is_perfect: false,
    encouragement,
  });
  if (insertErr) throw insertErr;
}

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
    const supabaseUrl = getRequiredEnv("SUPABASE_URL");
    const serviceRole = getRequiredEnv("SUPABASE_SERVICE_ROLE_KEY");
    const llmApiKey = getLlmApiKey();

    const supabase = createClient(supabaseUrl, serviceRole);
    const body = await req.json();
    const userId = toText(body?.user_id);
    if (!userId) {
      throw new Error("Missing user_id");
    }
    const requestedLanguage = resolveRequestedLanguage(body) ?? "zh";
    const scaffolding = buildWeeklyScaffolding(requestedLanguage);

    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const sevenDaysAgoIso = sevenDaysAgo.toISOString();
    const sevenDaysAgoDateId = formatDateId(sevenDaysAgo);

    const quests = await fetchWeeklyQuests(supabase, userId, sevenDaysAgoIso);
    const logs = await fetchWeeklyLogs(
      supabase,
      userId,
      sevenDaysAgoIso,
      sevenDaysAgoDateId,
    );

    const questLines = quests.length > 0
      ? quests.map((q, i) => {
        const xp = q.xp_reward ?? q.exp ?? 0;
        const tier = q.quest_tier ?? "Unknown";
        return `${i + 1}. [${tier}] ${toText(q.title)} (XP:${xp})`;
      }).join("\n")
      : scaffolding.noQuestLines;

    const logLines = logs.length > 0
      ? logs.map((r, i) => {
        const snippet = toText(r.content) ||
          toText(r.text) ||
          toText(r.note) ||
          toText(r.summary) ||
          toText(r.encouragement);
        const date = toText(r.created_at) ||
          toText(r.date_id) ||
          scaffolding.unknownDate;
        return `${i + 1}. [${date}] ${snippet || scaffolding.emptySnippet}`;
      }).join("\n")
      : scaffolding.noLogLines;

    const promptPayload = `
${scaffolding.playerIdLabel}: ${userId}
${scaffolding.timeRangeLabel}: ${sevenDaysAgoIso} ~ ${now.toISOString()}

${scaffolding.questsLabel}
${questLines}

${scaffolding.logsLabel}
${logLines}
`.trim();

    let memoryRecallText = scaffolding.memoryRecallEmpty;
    try {
      const everMem = new EverMemOSClient();
      const keyword = extractWeeklyKeyword(logs, requestedLanguage);
      const memoryResp = await everMem.searchMemories({
        query: keyword,
        userId,
        memoryTypes: ["episodic_memory"],
        retrieveMethod: "hybrid",
      });
      memoryRecallText = formatMemoryRecallText(memoryResp, requestedLanguage);
    } catch (memoryErr) {
      console.warn(
        "weekly-summary memory search skipped:",
        toErrorMessage(memoryErr),
      );
    }

    const language = resolveSummaryLanguage(
      promptPayload,
      memoryRecallText,
      body,
    );
    const summary = await callWeeklyLLM(
      promptPayload,
      memoryRecallText,
      llmApiKey,
      language,
    );
    await saveSummaryToDiary(supabase, userId, summary);
    syncDiaryMemoryFireAndForget(supabaseUrl, serviceRole, userId, summary);

    return new Response(JSON.stringify({ success: true, summary, language }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    const errorMessage = toErrorMessage(error);
    console.error("weekly-summary error:", errorMessage);
    if (error instanceof Error && error.stack) {
      console.error(error.stack);
    } else {
      console.error("weekly-summary raw error:", error);
    }
    return new Response(
      JSON.stringify({
        success: false,
        error: errorMessage,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      },
    );
  }
});

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/weekly-summary' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"user_id":"<target_user_id>"}'

*/
