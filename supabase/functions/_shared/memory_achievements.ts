// 记忆成就阈值判定函数（纯函数，无副作用）
// 从 sync-user-memory/index.ts 提取到 _shared 以便属性测试直接导入，
// 避免 Deno.serve Edge Function 的 edge-runtime 依赖问题。

/** 记忆成就类型 */
export type MemoryAchievement =
  | "memory_100"
  | "memory_guardian_30"
  | "living_memory_50";

/**
 * 判断是否应触发"记忆百条"成就。
 * 累计记忆条数 >= 100 时返回 true。
 */
export function shouldTriggerMemory100(totalMemoryCount: number): boolean {
  return totalMemoryCount >= 100;
}

/**
 * 判断是否应触发"记忆守护者"成就。
 * 连续 30 天每天至少 1 条记忆写入时返回 true。
 */
export function shouldTriggerGuardian30(consecutiveDays: number): boolean {
  return consecutiveDays >= 30;
}

/**
 * 判断是否应触发"活的记忆"成就。
 * 记忆被 Guide 引用累计 >= 50 次时返回 true。
 */
export function shouldTriggerLivingMemory50(referenceCount: number): boolean {
  return referenceCount >= 50;
}
