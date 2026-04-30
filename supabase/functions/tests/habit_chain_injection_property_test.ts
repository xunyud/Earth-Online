// Feature: memory-moat, Property 9: Habit chain injection threshold and cap
// **Validates: Requirements 6.2, 6.3**
//
// 属性测试：验证习惯链注入的过滤阈值和数量上限。
// - 仅注入 confidence >= 0.7 的链
// - 最多注入 2 条
// - 按置信度降序排列
// - 所有链置信度 < 0.7 时不注入任何链

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";
import { filterMentionableChains } from "../_shared/guide_memory.ts";
import type { HabitChain, HabitChainType } from "../_shared/guide_memory.ts";

// ---------- 生成器 ----------

/** 有效的习惯链类型 */
const arbChainType: fc.Arbitrary<HabitChainType> = fc.constantFrom(
  "time_slot",
  "weekly_cycle",
  "push_recover",
);

/** 生成随机 HabitChain，置信度在 [0.0, 1.0] 范围内 */
const arbHabitChain: fc.Arbitrary<HabitChain> = fc.record({
  type: arbChainType,
  description: fc.string({ minLength: 1, maxLength: 50 }),
  consecutiveDays: fc.integer({ min: 1, max: 30 }),
  confidence: fc.double({ min: 0.0, max: 1.0, noNaN: true }),
});

/** 生成置信度严格低于 0.7 的 HabitChain */
const arbLowConfidenceChain: fc.Arbitrary<HabitChain> = fc.record({
  type: arbChainType,
  description: fc.string({ minLength: 1, maxLength: 50 }),
  consecutiveDays: fc.integer({ min: 1, max: 30 }),
  // 0.0 到 0.6999... 之间，确保严格 < 0.7
  confidence: fc.double({ min: 0.0, max: 0.6999, noNaN: true }),
});

/** 生成置信度 >= 0.7 的 HabitChain */
const arbHighConfidenceChain: fc.Arbitrary<HabitChain> = fc.record({
  type: arbChainType,
  description: fc.string({ minLength: 1, maxLength: 50 }),
  consecutiveDays: fc.integer({ min: 1, max: 30 }),
  confidence: fc.double({ min: 0.7, max: 1.0, noNaN: true }),
});

// ---------- Property 9: Habit chain injection threshold and cap ----------

// Feature: memory-moat, Property 9: Habit chain injection threshold and cap
Deno.test("Property 9: 仅注入 confidence >= 0.7 的链", () => {
  fc.assert(
    fc.property(
      fc.array(arbHabitChain, { minLength: 0, maxLength: 20 }),
      (chains: HabitChain[]) => {
        const result = filterMentionableChains(chains);

        // 结果中每条链的置信度必须 >= 0.7
        for (const chain of result) {
          assert(
            chain.confidence >= 0.7,
            `注入的链置信度应 >= 0.7，实际为 ${chain.confidence}`,
          );
        }
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 9: 最多注入 2 条链", () => {
  fc.assert(
    fc.property(
      fc.array(arbHabitChain, { minLength: 0, maxLength: 20 }),
      (chains: HabitChain[]) => {
        const result = filterMentionableChains(chains);

        assert(
          result.length <= 2,
          `注入链数量应 <= 2，实际为 ${result.length}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 9: 按置信度降序排列", () => {
  fc.assert(
    fc.property(
      fc.array(arbHabitChain, { minLength: 0, maxLength: 20 }),
      (chains: HabitChain[]) => {
        const result = filterMentionableChains(chains);

        // 验证降序：每个元素的置信度 >= 下一个元素的置信度
        for (let i = 0; i < result.length - 1; i++) {
          assert(
            result[i].confidence >= result[i + 1].confidence,
            `结果应按置信度降序排列，但索引 ${i} 的置信度 ${result[i].confidence} < 索引 ${i + 1} 的 ${result[i + 1].confidence}`,
          );
        }
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 9: 所有链置信度 < 0.7 时不注入任何链", () => {
  fc.assert(
    fc.property(
      fc.array(arbLowConfidenceChain, { minLength: 1, maxLength: 20 }),
      (chains: HabitChain[]) => {
        const result = filterMentionableChains(chains);

        assertEquals(
          result.length,
          0,
          `所有链置信度 < 0.7 时不应注入任何链，实际注入 ${result.length} 条`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 9: 高置信度链数量 <= 2 时全部注入", () => {
  fc.assert(
    fc.property(
      // 1-2 条高置信度链 + 任意数量低置信度链
      fc.integer({ min: 1, max: 2 }),
      fc.array(arbHighConfidenceChain, { minLength: 1, maxLength: 2 }),
      fc.array(arbLowConfidenceChain, { minLength: 0, maxLength: 10 }),
      (expectedCount: number, highChains: HabitChain[], lowChains: HabitChain[]) => {
        const actualHigh = highChains.slice(0, expectedCount);
        const allChains = [...actualHigh, ...lowChains];
        const result = filterMentionableChains(allChains);

        // 结果数量应等于高置信度链的数量
        assertEquals(
          result.length,
          actualHigh.length,
          `有 ${actualHigh.length} 条高置信度链时应全部注入，实际注入 ${result.length} 条`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 9: 超过 2 条高置信度链时取置信度最高的 2 条", () => {
  fc.assert(
    fc.property(
      // 3-10 条高置信度链
      fc.array(arbHighConfidenceChain, { minLength: 3, maxLength: 10 }),
      (chains: HabitChain[]) => {
        const result = filterMentionableChains(chains);

        // 结果数量应为 2
        assertEquals(
          result.length,
          2,
          `超过 2 条高置信度链时应只取 2 条，实际取 ${result.length} 条`,
        );

        // 结果中的链应是输入中置信度最高的 2 条
        const sortedInput = [...chains]
          .filter((c) => c.confidence >= 0.7)
          .sort((a, b) => b.confidence - a.confidence);
        assertEquals(
          result[0].confidence,
          sortedInput[0].confidence,
          "第一条应为置信度最高的链",
        );
        assertEquals(
          result[1].confidence,
          sortedInput[1].confidence,
          "第二条应为置信度次高的链",
        );
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 9: 空输入返回空列表", () => {
  const result = filterMentionableChains([]);
  assertEquals(result.length, 0, "空输入应返回空列表");
});
