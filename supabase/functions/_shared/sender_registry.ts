/**
 * Sender 身份注册与事件类型映射模块。
 * 从 sync-user-memory/index.ts 提取，便于属性测试直接导入（避免 edge-runtime 依赖）。
 */

import type { EverMemOSClient } from "./evermemos_client.ts";

// ---------- 常量与类型 ----------

/** 五个写入源的 Sender 名称常量 */
export const SENDER_NAMES = [
  "user-manual",
  "guide-assistant",
  "agent-runtime",
  "patrol-nudge",
  "wechat-webhook",
] as const;

export type SenderName = typeof SENDER_NAMES[number];

/** 模块级缓存：sender name → sender_id 映射，避免重复注册 */
export const senderCache = new Map<string, string>();

// ---------- 辅助函数 ----------

function toErrorMessage(error: unknown) {
  if (error instanceof Error) return error.message;
  try {
    return JSON.stringify(error);
  } catch {
    return String(error);
  }
}

// ---------- 核心函数 ----------

/**
 * 懒加载注册所有 Sender 身份。
 * 首次调用时通过 createSender 注册五个写入源，缓存 sender_id 映射。
 * 已全部注册时直接返回；单个注册失败时记录 warn 日志，不阻塞其他注册。
 */
export async function ensureSendersRegistered(
  client: Pick<EverMemOSClient, "createSender">,
): Promise<void> {
  // 已全部注册，直接返回
  if (senderCache.size >= SENDER_NAMES.length) return;
  for (const name of SENDER_NAMES) {
    if (senderCache.has(name)) continue;
    try {
      const sender = await client.createSender({
        name,
        metadata: { source: "earth-online" },
      });
      senderCache.set(name, sender.sender_id);
    } catch (err) {
      // 注册失败降级为无 sender 写入，不阻塞主流程
      console.warn(
        `sender-register: 注册 ${name} 失败，降级为无 sender 写入`,
        toErrorMessage(err),
      );
    }
  }
}

/**
 * 根据事件类型推断 sender name。
 * 优先使用显式传入的 source 参数（需为有效 sender name），
 * 否则按 eventType 前缀/值匹配规则推断。
 */
export function resolveSenderName(
  eventType: string,
  source?: string,
): SenderName {
  // 显式指定的 source 优先，需为有效 sender name
  if (
    source &&
    (SENDER_NAMES as readonly string[]).includes(source)
  ) {
    return source as SenderName;
  }
  // 按 eventType 规则推断
  if (eventType.startsWith("agent_")) return "agent-runtime";
  if (eventType === "patrol_nudge" || eventType === "habit_chain_break") {
    return "patrol-nudge";
  }
  if (eventType === "wechat_message") return "wechat-webhook";
  if (eventType === "guide_chat" || eventType === "night_reflection") {
    return "guide-assistant";
  }
  // 默认归类为用户手动操作
  return "user-manual";
}
