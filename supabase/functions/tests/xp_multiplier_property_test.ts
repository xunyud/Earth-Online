// Feature: memory-moat, Property 17: XP multiplier computation
// **Validates: Requirements 14.2, 14.3, 14.4**
//
// 属性测试：验证 computeXpMultiplier 在各种随机 (currentStreak, previousStreak) 输入下的正确性。
// - 返回值始终在 [0.8, 1.5] 范围内
// - currentStreak = 0 始终返回 0.8
// - previousStreak = 0 且 currentStreak = 1 始终返回 1.3
// - currentStreak >= 3 返回正确的公式值
// - currentStreak = 1 或 2（previousStreak > 0）返回 1.0
// - 负数输入与 0 产生相同结果

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";
import { computeXpMultiplier } from "../_shared/guide_memory.ts";

// ---------- Property 17: XP multiplier computation ----------

// 子属性 1：返回值始终在 [0.8, 1.5] 范围内
Deno.test("Property 17.1: 任意非负整数对，返回值始终在 [0.8, 1.5]", () => {
  fc.assert(
    fc.property(
      fc.nat({ max: 1000 }),
      fc.nat({ max: 1000 }),
      (currentStreak: number, previousStreak: number) => {
        const result = computeXpMultiplier(currentStreak, previousStreak);
        assert(
          result >= 0.8 && result <= 1.5,
          `输入 (current=${currentStreak}, previous=${previousStreak}) 返回 ${result}，超出 [0.8, 1.5] 范围`,
        );
      },
    ),
    { numRuns: 200 },
  );
});

// 子属性 2：currentStreak = 0 始终返回 0.8（断签状态）
Deno.test("Property 17.2: currentStreak = 0 时始终返回 0.8", () => {
  fc.assert(
    fc.property(
      fc.nat({ max: 1000 }),
      (previousStreak: number) => {
        const result = computeXpMultiplier(0, previousStreak);
        assertEquals(
          result,
          0.8,
          `断签状态 (current=0, previous=${previousStreak}) 应返回 0.8，实际返回 ${result}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// 子属性 3：previousStreak = 0 且 currentStreak = 1 始终返回 1.3（恢复激励）
Deno.test("Property 17.3: previousStreak = 0 且 currentStreak = 1 时返回 1.3", () => {
  // 此条件固定，用单次断言即可，但为一致性仍用属性测试框架
  const result = computeXpMultiplier(1, 0);
  assertEquals(
    result,
    1.3,
    `恢复激励 (current=1, previous=0) 应返回 1.3，实际返回 ${result}`,
  );
});

// 子属性 4：currentStreak >= 3 返回正确的公式值 1.0 + 0.1 × min(currentStreak - 2, 5)
Deno.test("Property 17.4: currentStreak >= 3 时返回公式计算值", () => {
  fc.assert(
    fc.property(
      fc.integer({ min: 3, max: 1000 }),
      fc.nat({ max: 1000 }),
      (currentStreak: number, previousStreak: number) => {
        const result = computeXpMultiplier(currentStreak, previousStreak);
        const expected = 1.0 + 0.1 * Math.min(currentStreak - 2, 5);

        // 使用浮点数容差比较
        assert(
          Math.abs(result - expected) < 1e-10,
          `连续推进 (current=${currentStreak}, previous=${previousStreak}) 应返回 ${expected}，实际返回 ${result}`,
        );

        // 额外验证：公式值应在 [1.1, 1.5] 范围内
        assert(
          result >= 1.1 && result <= 1.5,
          `连续推进倍率应在 [1.1, 1.5]，实际为 ${result}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// 子属性 5：currentStreak = 1 或 2（previousStreak > 0）返回 1.0（默认倍率）
Deno.test("Property 17.5: currentStreak 为 1 或 2 且 previousStreak > 0 时返回 1.0", () => {
  fc.assert(
    fc.property(
      fc.constantFrom(1, 2),
      fc.integer({ min: 1, max: 1000 }),
      (currentStreak: number, previousStreak: number) => {
        const result = computeXpMultiplier(currentStreak, previousStreak);
        assertEquals(
          result,
          1.0,
          `默认倍率 (current=${currentStreak}, previous=${previousStreak}) 应返回 1.0，实际返回 ${result}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// 子属性 6：负数输入与 0 产生相同结果
Deno.test("Property 17.6: 负数输入视为 0，与显式传 0 结果一致", () => {
  fc.assert(
    fc.property(
      fc.integer({ min: -1000, max: -1 }),
      fc.nat({ max: 1000 }),
      (negativeStreak: number, otherStreak: number) => {
        // 负数 currentStreak 应等价于 currentStreak = 0
        const withNeg = computeXpMultiplier(negativeStreak, otherStreak);
        const withZero = computeXpMultiplier(0, otherStreak);
        assertEquals(
          withNeg,
          withZero,
          `负数 currentStreak=${negativeStreak} 应等价于 0，但返回 ${withNeg} ≠ ${withZero}`,
        );
      },
    ),
    { numRuns: 100 },
  );

  fc.assert(
    fc.property(
      fc.nat({ max: 1000 }),
      fc.integer({ min: -1000, max: -1 }),
      (currentStreak: number, negPrevious: number) => {
        // 负数 previousStreak 应等价于 previousStreak = 0
        const withNeg = computeXpMultiplier(currentStreak, negPrevious);
        const withZero = computeXpMultiplier(currentStreak, 0);
        assertEquals(
          withNeg,
          withZero,
          `负数 previousStreak=${negPrevious} 应等价于 0，但返回 ${withNeg} ≠ ${withZero}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});
