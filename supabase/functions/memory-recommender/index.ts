// memory-recommender: 记忆驱动任务推荐 Edge Function
// 功能：基于用户近 30 天行为模式记忆，通过 LLM 生成 2–3 条个性化任务推荐
// 触发方式：由 guide-bootstrap 在初始化阶段调用
// 输入：POST { user_id, client_context? }
// 输出：{ success: boolean, recommendations: Recommendation[] }
// 依赖：EverMemOS API（记忆检索）、DeepSeek LLM（推荐生成）

import "@supabase/functions-js/edge-runtime.d.ts";
import { EverMemOSClient } from "../_shared/evermemos_client.ts";
import {
  buildRecommendationPrompt,
  MIN_MEMORY_COUNT,
  parseRecommendations,
} from "./helpers.ts";
import type { Recommendation } from "./helpers.ts";

// 重新导出类型和纯函数，保持外部接口不变
export { buildRecommendationPrompt, parseRecommendations };
export type { Recommendation };

// ---------- 常量与类型 ----------

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/** 整个函数的超时时间（毫秒） */
const FUNCTION_TIMEOUT_MS = 8_000;

// ---------- 工具函数 ----------

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

function json(status: number, data: unknown) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// ---------- LLM 调用 ----------

/** 获取 LLM API Key，优先 OPENAI_API_KEY，其次 DEEPSEEK_API_KEY */
function getLlmApiKey(): string {
  const key = Deno.env.get("OPENAI_API_KEY") ??
    Deno.env.get("DEEPSEEK_API_KEY") ?? "";
  return key.trim();
}

/** 获取 LLM API Base URL，标准化为以 /v1 结尾 */
function getLlmBaseUrl(): string {
  const baseUrl = (
    Deno.env.get("OPENAI_BASE_URL") ??
      Deno.env.get("DEEPSEEK_BASE_URL") ??
      "https://api.86gamestore.com"
  ).trim().replace(/\/+$/, "");
  return baseUrl.endsWith("/v1") ? baseUrl : `${baseUrl}/v1`;
}

// ---------- 记忆检索 ----------

/**
 * 从 EverMemOS 检索用户最近 30 天的行为模式记忆。
 * 同时检索 episodic_memory 和 semantic_memory 两种类型。
 * 返回原始检索结果数组；检索失败时返回空数组。
 */
async function fetchBehaviorMemories(
  client: EverMemOSClient,
  userId: string,
  signal: AbortSignal,
): Promise<unknown[]> {
  try {
    const result = await client.searchMemories(
      {
        userId,
        query: "用户近期行为模式 完成任务 习惯 搁置",
        memoryTypes: ["episodic_memory", "semantic_memory"],
        limit: 30,
      },
      signal,
    );
    // EverMemOS 返回格式可能是数组或包含 memories 字段的对象
    if (Array.isArray(result)) return result;
    if (result && Array.isArray(result.memories)) return result.memories;
    if (result && Array.isArray(result.results)) return result.results;
    return [];
  } catch (err) {
    console.error("memory-recommender: 记忆检索失败:", toErrorMessage(err));
    return [];
  }
}

/**
 * 从记忆条目中提取文本内容，用于构建 LLM prompt。
 * 兼容多种记忆数据结构。
 */
function extractMemoryText(item: unknown): string {
  if (!item || typeof item !== "object") return "";
  const rec = item as Record<string, unknown>;
  // 优先取 content，其次 summary，最后 text
  const content = toText(rec.content) || toText(rec.summary) ||
    toText(rec.text);
  return content;
}

/** LLM 系统提示词：指导模型输出结构化推荐 */
const SYSTEM_PROMPT =
  `你是一个行为模式分析助手。根据用户的记忆数据，生成个性化的任务推荐。

【输出格式（必须严格遵守）】
你只能输出一个合法 JSON 数组，包含 2–3 个对象，每个对象有两个字段：
[
  { "title": "具体可执行的小动作", "reason": "基于哪条记忆模式推荐" }
]

【规则】
- title 必须是具体、可立即执行的小动作（如"写 10 分钟日记"而非"养成写日记的习惯"）
- reason 必须引用具体的记忆模式（如"你最近连续 5 天都在晚上写复盘"）
- 生成 2–3 条推荐，不多不少
- 只输出 JSON 数组，不要输出任何其他文字
- 禁止输出 Markdown 格式`;

// ---------- LLM 调用生成推荐 ----------

/**
 * 调用 DeepSeek LLM 生成推荐。
 * 失败时返回空数组，不抛出异常。
 */
async function generateRecommendations(
  memoryTexts: string[],
  clientContext?: string,
  signal?: AbortSignal,
): Promise<Recommendation[]> {
  const apiKey = getLlmApiKey();
  if (!apiKey) {
    console.warn("memory-recommender: 缺少 LLM API Key，跳过推荐生成");
    return [];
  }

  const userPrompt = buildRecommendationPrompt(memoryTexts, clientContext);

  try {
    const resp = await fetch(
      `${getLlmBaseUrl()}/chat/completions`,
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
            { role: "system", content: SYSTEM_PROMPT },
            { role: "user", content: userPrompt },
          ],
        }),
        signal,
      },
    );

    if (!resp.ok) {
      console.warn(
        "memory-recommender: LLM 请求失败:",
        resp.status,
        await resp.text(),
      );
      return [];
    }

    const data = await resp.json();
    const content = toText(data?.choices?.[0]?.message?.content);
    if (!content) {
      console.warn("memory-recommender: LLM 返回内容为空");
      return [];
    }

    return parseRecommendations(content);
  } catch (err) {
    console.warn("memory-recommender: LLM 调用异常:", toErrorMessage(err));
    return [];
  }
}

// ---------- 主入口 ----------

Deno.serve(async (req) => {
  // 处理 CORS 预检请求
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json(405, { success: false, error: "Method Not Allowed" });
  }

  // 整个函数 8 秒超时
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), FUNCTION_TIMEOUT_MS);

  try {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const userId = toText(body?.user_id);

    if (!userId) {
      return json(400, {
        success: false,
        error: "Missing user_id",
        recommendations: [],
      });
    }

    const clientContext = toText(body?.client_context) || undefined;

    // 步骤 1：从 EverMemOS 检索行为模式记忆
    const everMem = new EverMemOSClient();
    const memories = await fetchBehaviorMemories(
      everMem,
      userId,
      controller.signal,
    );

    // 步骤 2：记忆不足 3 条时返回空推荐
    if (memories.length < MIN_MEMORY_COUNT) {
      console.log(
        `memory-recommender: 用户 ${userId} 记忆不足 ${MIN_MEMORY_COUNT} 条（实际 ${memories.length}），返回空推荐`,
      );
      return json(200, { success: true, recommendations: [] });
    }

    // 步骤 3：提取记忆文本
    const memoryTexts = memories
      .map(extractMemoryText)
      .filter((text) => text.length > 0);

    // 提取后仍不足 3 条有效文本，返回空推荐
    if (memoryTexts.length < MIN_MEMORY_COUNT) {
      return json(200, { success: true, recommendations: [] });
    }

    // 步骤 4：调用 LLM 生成推荐
    const recommendations = await generateRecommendations(
      memoryTexts,
      clientContext,
      controller.signal,
    );

    return json(200, { success: true, recommendations });
  } catch (err) {
    // 超时或其他未预期错误：返回空推荐，不影响 bootstrap 流程
    const msg = toErrorMessage(err);
    console.error("memory-recommender: 未预期错误:", msg);
    return json(200, { success: true, recommendations: [] });
  } finally {
    clearTimeout(timeout);
  }
});
