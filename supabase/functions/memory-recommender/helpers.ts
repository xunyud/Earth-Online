// memory-recommender 纯函数模块
// 提取自 index.ts，便于测试直接导入（不依赖 edge-runtime 和 Deno.serve）
// 包含：推荐解析、prompt 构建等无副作用的纯逻辑

// ---------- 类型定义 ----------

/** 单条推荐：具体可执行的小动作 + 推荐理由 */
export type Recommendation = {
  title: string; // 具体可执行的小动作
  reason: string; // 基于哪条记忆模式推荐
};

/** 行为模式记忆最少条数阈值，不足时返回空推荐 */
export const MIN_MEMORY_COUNT = 3;

// ---------- 工具函数 ----------

/** 将任意值转为 trim 后的字符串 */
function toText(v: unknown): string {
  if (typeof v === "string") return v.trim();
  if (v == null) return "";
  return String(v).trim();
}

/** 将错误转为可读字符串 */
function toErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  try {
    return JSON.stringify(error);
  } catch {
    return String(error);
  }
}

/** 去除 LLM 返回内容中的 Markdown 代码围栏 */
function stripJsonFence(text: string): string {
  return text.replace(/```json\s*/gi, "").replace(/```\s*/g, "").trim();
}

// ---------- LLM Prompt 构建 ----------

/**
 * 构建推荐生成的 LLM prompt。
 * 包含三类信号：完成模式、搁置任务、习惯形成信号。
 * @param memoryTexts - 用户近 30 天行为模式记忆文本列表
 * @param clientContext - 可选的用户当前上下文
 * @returns 完整的 LLM user prompt 字符串
 */
export function buildRecommendationPrompt(
  memoryTexts: string[],
  clientContext?: string,
): string {
  const memorySummary = memoryTexts
    .map((text, i) => `${i + 1}. ${text}`)
    .join("\n");

  let prompt = `以下是用户近 30 天的行为模式记忆：

${memorySummary}

请基于以上记忆，分析以下三类信号并生成 2–3 条个性化任务推荐：

1. **完成模式**：用户近期高频完成的任务类型，推荐同类型的下一步行动
2. **搁置任务**：创建后超过 7 天未推进的任务，提醒用户重新启动或拆解
3. **习惯形成信号**：连续 3 天以上的重复行为，鼓励用户巩固或升级该习惯`;

  if (clientContext) {
    prompt += `\n\n用户当前上下文：${clientContext}`;
  }

  return prompt;
}

// ---------- 推荐解析与验证 ----------

/**
 * 解析并验证 LLM 返回的推荐列表。
 * 确保每条推荐都有非空的 title 和 reason，总数在 2–3 条之间。
 * 解析失败或格式异常时返回空数组。
 * @param raw - LLM 返回的原始字符串（可能包含 Markdown 围栏）
 * @returns 验证通过的推荐数组，异常时返回空数组
 */
export function parseRecommendations(raw: string): Recommendation[] {
  try {
    const parsed = JSON.parse(stripJsonFence(raw));
    if (!Array.isArray(parsed)) return [];

    const recommendations: Recommendation[] = [];
    for (const item of parsed) {
      if (!item || typeof item !== "object") continue;
      const title = toText(item.title);
      const reason = toText(item.reason);
      if (title && reason) {
        recommendations.push({ title, reason });
      }
    }

    // 验证数量：必须 2–3 条，否则视为异常
    if (recommendations.length < 2 || recommendations.length > 3) {
      console.warn(
        `memory-recommender: LLM 返回 ${recommendations.length} 条推荐，期望 2–3 条`,
      );
      // 如果有 2 条以上，截取前 3 条；不足 2 条则返回空
      if (recommendations.length > 3) return recommendations.slice(0, 3);
      if (recommendations.length < 2) return [];
    }

    return recommendations;
  } catch (err) {
    console.warn("memory-recommender: 推荐解析失败:", toErrorMessage(err));
    return [];
  }
}
