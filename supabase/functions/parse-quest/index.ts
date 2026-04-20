import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import { corsHeaders } from "../_shared/cors.ts";

console.log("Function 'parse-quest' up and running!");

type AuthenticatedParseQuestUser = {
  id: string;
};

type ParseQuestTask = {
  title: string;
  parent_index: number | null;
  xpReward: number;
};

type ParseQuestPayload = {
  tasks: ParseQuestTask[];
  cheer: string;
};

type ParseQuestHandlerDeps = {
  authenticate: (
    accessToken: string,
  ) => Promise<AuthenticatedParseQuestUser | null>;
  callLlm: (text: string) => Promise<ParseQuestPayload | null>;
};

function json(status: number, data: unknown) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function toText(value: unknown): string {
  if (typeof value === "string") return value.trim();
  if (value == null) return "";
  return String(value).trim();
}

function buildFallbackParseQuestPayload(text: string): ParseQuestPayload {
  const title = toText(text);
  return {
    tasks: title.length === 0
      ? []
      : [
        {
          title,
          parent_index: null,
          xpReward: 20,
        },
      ],
    cheer: "先把这一小步记下来，也是在推进。",
  };
}

function normalizeLlmPayload(parsed: unknown): ParseQuestPayload | null {
  const tasksRaw = Array.isArray((parsed as { tasks?: unknown[] } | null)?.tasks)
    ? (parsed as { tasks: unknown[] }).tasks
    : [];
  const cheerRaw = typeof (parsed as { cheer?: unknown } | null)?.cheer === "string"
    ? ((parsed as { cheer: string }).cheer).trim()
    : "";

  const tasks: ParseQuestTask[] = [];
  for (let i = 0; i < tasksRaw.length; i += 1) {
    const item = tasksRaw[i] as {
      title?: unknown;
      parent_index?: unknown;
      xpReward?: unknown;
    } | null;
    const title = typeof item?.title === "string" ? item.title.trim() : "";
    if (title.length === 0) continue;

    let parent_index: number | null = null;
    if (Number.isInteger(item?.parent_index)) {
      parent_index = item?.parent_index as number;
    }
    if (parent_index !== null && (parent_index < 0 || parent_index >= i)) {
      parent_index = null;
    }

    let xpReward = Number.isFinite(item?.xpReward)
      ? Math.round(item?.xpReward as number)
      : 20;
    if (xpReward < 10) xpReward = 10;
    if (xpReward > 100) xpReward = 100;

    tasks.push({ title, parent_index, xpReward });
  }

  return {
    tasks,
    cheer: cheerRaw.length > 0 && cheerRaw.length <= 60
      ? cheerRaw
      : "先把这一小步记下来，也是在推进。",
  };
}

async function callConfiguredLlm(text: string): Promise<ParseQuestPayload | null> {
  const llmApiKey = Deno.env.get("OPENAI_API_KEY") ??
    Deno.env.get("DEEPSEEK_API_KEY");
  if (!llmApiKey) {
    throw new Error("OPENAI_API_KEY or DEEPSEEK_API_KEY not set");
  }

  const llmBaseUrl = (
    Deno.env.get("OPENAI_BASE_URL") ??
    Deno.env.get("DEEPSEEK_BASE_URL") ??
    "https://api.86gamestore.com"
  ).replace(/\/+$/, "");
  const normalizedLlmBaseUrl = llmBaseUrl.endsWith("/v1")
    ? llmBaseUrl
    : `${llmBaseUrl}/v1`;

  const systemPrompt = `
    你是一个任务拆解助手。你的目标是把用户输入拆解为“纯父子层级”的任务树，并生成一句正常、温暖的鼓励语。
    【输出格式（必须严格遵守）】
    你只能输出一个合法 JSON 对象，且必须包含两个顶级字段：
    {
      "cheer": "string",
      "tasks": [
        {
          "title": "string",
          "parent_index": null 或 integer,
          "xpReward": integer
        }
      ]
    }
    - 禁止输出 Markdown。
    - 禁止输出解释或任何多余文本。
    - 禁止输出除 cheer 与 tasks 以外的顶级字段。
    - tasks 中也禁止输出除 title / parent_index / xpReward 以外的字段。
    【强制规则（极其重要）】
    1) title 绝对不能为 null、空字符串或纯空白，必须保留用户原语言。
    2) 不要用文本描述依赖关系，只能用 parent_index 表达父子层级。
    3) 不在同一天且逻辑无关的任务，要拆成不同主线。
    4) parent_index 只能指向当前任务之前的任务索引。
    5) xpReward 必须是 10 到 100 的整数。
    6) cheer 是一句正常温暖的鼓励语，20 字以内，可选 1 个 emoji。
  `;

  const response = await fetch(`${normalizedLlmBaseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${llmApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "deepseek-chat",
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: text },
      ],
      temperature: 0.5,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`LLM API Error: ${response.status} - ${errorText}`);
  }

  const llmData = await response.json();
  const rawContent = typeof llmData?.choices?.[0]?.message?.content === "string"
    ? llmData.choices[0].message.content
    : "";
  if (rawContent.length === 0) {
    throw new Error("Failed to get LLM response");
  }

  const normalizedContent = rawContent.replace(/```json/g, "")
    .replace(/```/g, "")
    .trim();
  let parsed: unknown;
  try {
    parsed = JSON.parse(normalizedContent);
  } catch (error) {
    console.error("parse-quest llm json parse failed", error);
    throw new Error("Failed to parse LLM JSON");
  }

  return normalizeLlmPayload(parsed);
}

function createDefaultParseQuestDeps(): ParseQuestHandlerDeps {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_ANON_KEY");
  }

  const authClient = createClient(supabaseUrl, supabaseAnonKey);
  return {
    authenticate: async (accessToken) => {
      const { data, error } = await authClient.auth.getUser(accessToken);
      if (error || !data.user) return null;
      return { id: data.user.id };
    },
    callLlm: (text) => callConfiguredLlm(text),
  };
}

export function createParseQuestHandler(
  deps: ParseQuestHandlerDeps = createDefaultParseQuestDeps(),
) {
  return async (req: Request) => {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }

    try {
      const authHeader = req.headers.get("Authorization") ?? "";
      const accessToken = authHeader.replace("Bearer", "").trim();
      if (!accessToken) {
        return json(401, { error: "Missing bearer token" });
      }

      const user = await deps.authenticate(accessToken);
      if (!user) {
        return json(401, {
          error: "Invalid JWT",
          details: null,
        });
      }

      const body = await req.json().catch(() => ({}));
      const text = toText(body?.text);
      const userId = toText(body?.user_id);
      if (!text || !userId) {
        throw new Error("Missing text or user_id");
      }
      if (user.id !== userId) {
        return json(403, { error: "user_id does not match token user" });
      }

      let payload: ParseQuestPayload | null = null;
      try {
        payload = await deps.callLlm(text);
      } catch (error) {
        console.error("parse-quest llm unavailable, fallback enabled", error);
      }

      const normalizedPayload = payload != null && payload.tasks.length > 0
        ? payload
        : buildFallbackParseQuestPayload(text);
      return json(200, normalizedPayload);
    } catch (error) {
      return json(500, {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  };
}

if (import.meta.main) {
  Deno.serve(createParseQuestHandler());
}
