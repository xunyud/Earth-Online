// 单元测试：XP 倍率计算与记忆成就检测
// 覆盖 computeXpMultiplier 的各分支和边界值，以及三种记忆成就的阈值判定。
// _Requirements: 14.2, 14.3, 14.4, 15.2, 15.3, 15.4_

import {
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { computeXpMultiplier } from "../_shared/guide_memory.ts";
import {
  shouldTriggerMemory100,
  shouldTriggerGuardian30,
  shouldTriggerLivingMemory50,
} from "../_shared/memory_achievements.ts";

// ==================== 1. computeXpMultiplier — 断签状态返回 0.8 ====================

Deno.test("computeXpMultiplier — streak=0 返回 0.8（断签状态）", () => {
  assertEquals(computeXpMultiplier(0, 5), 0.8);
});

// ==================== 2. computeXpMultiplier — 恢复激励返回 1.3 ====================

Deno.test("computeXpMultiplier — streak=1 且 prev=0 返回 1.3（恢复激励）", () => {
  assertEquals(computeXpMultiplier(1, 0), 1.3);
});

// ==================== 3. computeXpMultiplier — 连续推进 streak=3 返回 1.1 ====================

Deno.test("computeXpMultiplier — streak=3 返回 1.1（连续推进起始）", () => {
  // 公式：1.0 + 0.1 × min(3 - 2, 5) = 1.0 + 0.1 × 1 = 1.1
  assertEquals(computeXpMultiplier(3, 2), 1.1);
});

// ==================== 4. computeXpMultiplier — streak=10 返回 1.5（上限） ====================

Deno.test("computeXpMultiplier — streak=10 返回 1.5（上限封顶）", () => {
  // 公式：1.0 + 0.1 × min(10 - 2, 5) = 1.0 + 0.1 × 5 = 1.5
  assertEquals(computeXpMultiplier(10, 5), 1.5);
});

// ==================== 5. computeXpMultiplier — 默认倍率 ====================

Deno.test("computeXpMultiplier — streak=2 且 prev=1 返回 1.0（默认倍率）", () => {
  assertEquals(computeXpMultiplier(2, 1), 1.0);
});

// ==================== 6. shouldTriggerMemory100 — 恰好 100 条触发 ====================

Deno.test("shouldTriggerMemory100 — 恰好 100 条记忆触发成就", () => {
  assertEquals(shouldTriggerMemory100(100), true);
});

// ==================== 7. shouldTriggerMemory100 — 99 条不触发 ====================

Deno.test("shouldTriggerMemory100 — 99 条记忆不触发成就", () => {
  assertEquals(shouldTriggerMemory100(99), false);
});

// ==================== 8. shouldTriggerGuardian30 — 连续 30 天触发 ====================

Deno.test("shouldTriggerGuardian30 — 连续 30 天触发守护者成就", () => {
  assertEquals(shouldTriggerGuardian30(30), true);
});

// ==================== 9. shouldTriggerGuardian30 — 连续 29 天不触发 ====================

Deno.test("shouldTriggerGuardian30 — 连续 29 天不触发守护者成就", () => {
  assertEquals(shouldTriggerGuardian30(29), false);
});

// ==================== 10. shouldTriggerLivingMemory50 — 恰好 50 次触发 ====================

Deno.test("shouldTriggerLivingMemory50 — 恰好 50 次引用触发活的记忆成就", () => {
  assertEquals(shouldTriggerLivingMemory50(50), true);
});

// ==================== 11. shouldTriggerLivingMemory50 — 49 次不触发 ====================

Deno.test("shouldTriggerLivingMemory50 — 49 次引用不触发活的记忆成就", () => {
  assertEquals(shouldTriggerLivingMemory50(49), false);
});

// ==================== 12. 成就检测失败不影响记忆写入（逻辑验证） ====================
// 验证三个判定函数均为纯函数，不抛异常，即使输入为 0 或极大值

Deno.test("成就判定函数为纯函数，不抛异常", () => {
  // 零值输入
  assertEquals(shouldTriggerMemory100(0), false);
  assertEquals(shouldTriggerGuardian30(0), false);
  assertEquals(shouldTriggerLivingMemory50(0), false);

  // 极大值输入
  assertEquals(shouldTriggerMemory100(999999), true);
  assertEquals(shouldTriggerGuardian30(999999), true);
  assertEquals(shouldTriggerLivingMemory50(999999), true);
});
