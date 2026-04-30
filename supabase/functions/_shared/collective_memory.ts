// 群体记忆工具模块 — 匿名化里程碑写入与群体智慧检索
// 使用固定匿名 user_id 写入 Collective Space，确保无法反向追踪到具体用户。
// 依赖 EverMemOSClient 的 createMemory / searchMemories 接口。

import type {
  EverMemOSClient,
} from "./evermemos_client.ts";

// ---------- 常量 ----------

/** 群体记忆空间的 group_id */
export const COLLECTIVE_GROUP_ID = "earth-online-collective";

/** 写入群体记忆时使用的匿名 user_id，防止反向追踪 */
export const ANONYMOUS_USER_ID = "anonymous";

// ---------- 类型 ----------

/** 支持的里程碑事件类型 */
export type MilestoneType =
  | "streak_7day"
  | "first_clear"
  | "recovery_from_break";

// ---------- 辅助函数（从 guide_memory.ts 复用逻辑） ----------

/** 将 EverMemOS 检索结果标准化为数组 */
function normalizeMemoryItems(
  raw: unknown,
): Array<Record<string, unknown> | string> {
  if (Array.isArray(raw)) return raw as Array<Record<string, unknown> | string>;
  if (!raw || typeof raw !== "object") return [];
  const map = raw as Record<string, unknown>;
  const candidates = [
    map.memories,
    map.results,
    map.items,
    map.data,
    (map.result as Record<string, unknown> | undefined)?.memories,
  ];
  for (const c of candidates) {
    if (Array.isArray(c)) return c as Array<Record<string, unknown> | string>;
  }
  return [];
}

/** 从记忆条目中提取文本内容 */
function normalizeMemoryText(item: Record<string, unknown> | string): string {
  if (typeof item === "string") return item.trim();
  const toText = (v: unknown): string => {
    if (typeof v === "string") return v.trim();
    if (v == null) return "";
    return String(v).trim();
  };
  return (
    toText(item.content) ||
    toText(item.text) ||
    toText(item.memory) ||
    toText(item.message) ||
    toText((item.data as Record<string, unknown> | undefined)?.content)
  );
}

// ---------- 核心函数 ----------

/**
 * 将里程碑事件匿名写入 Collective Space。
 * 使用固定 ANONYMOUS_USER_ID 作为 user_id，确保无法追踪到具体用户。
 *
 * @param client - EverMemOS 客户端实例
 * @param milestoneType - 里程碑类型
 * @param description - 行为模式描述（不应包含任何用户标识信息）
 */
export async function writeCollectiveMilestone(
  client: EverMemOSClient,
  milestoneType: MilestoneType,
  description: string,
): Promise<void> {
  await client.createMemory({
    userId: ANONYMOUS_USER_ID,
    eventType: `milestone_${milestoneType}`,
    content: description,
    metadata: {
      memoryKind: "generic",
      summary: description,
      extra: {
        group_id: COLLECTIVE_GROUP_ID,
        milestone_type: milestoneType,
      },
    },
  });
}

/**
 * 从 Collective Space 检索匿名行为模式。
 * 仅检索 semantic_memory 和 episodic_memory 类型，返回纯文本列表。
 *
 * @param client - EverMemOS 客户端实例
 * @param query - 检索关键词
 * @param limit - 最多返回条数，默认 3
 * @returns 匿名行为模式文本数组
 */
export async function searchCollectiveWisdom(
  client: EverMemOSClient,
  query: string,
  limit = 3,
): Promise<string[]> {
  const results = await client.searchMemories({
    userId: ANONYMOUS_USER_ID,
    query,
    groupId: COLLECTIVE_GROUP_ID,
    memoryTypes: ["semantic_memory", "episodic_memory"],
    limit,
  });
  return normalizeMemoryItems(results)
    .map((item) => normalizeMemoryText(item))
    .filter(Boolean)
    .slice(0, limit);
}
