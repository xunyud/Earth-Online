// Feature: memory-moat, Property 18: Memory count achievement threshold
// Feature: memory-moat, Property 19: Memory guardian streak achievement
// **Validates: Requirements 15.2, 15.3**
//
// 属性测试：验证记忆成就阈值判定函数在各种随机输入下的正确性。
// - Property 18: 累计记忆 >= 100 时触发 memory_100，< 100 时不触发
// - Property 19: 连续 30 天每天 >= 1 条记忆时触发 memory_guardian_30，< 30 时不触发

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";
import {
  shouldTriggerMemory100,
  shouldTriggerGuardian30,
} from "../_shared/memory_achievements.ts";

// ---------- Property 18: Memory count achievement threshold ----------

// 子属性 18.1：累计记忆 >= 100 时始终触发 memory_100
Deno.test("Property 18.1: 累计记忆 >= 100 时始终触发 memory_100", () => {
  fc.assert(
    fc.property(
      fc.integer({ min: 100, max: 100000 }),
      (count: number) => {
        const result = shouldTriggerMemory100(count);
        assertEquals(
          result,
          true,
          `累计记忆 ${count} >= 100，应触发 memory_100，实际返回 ${result}`,
        );
      },
    ),
    { numRuns: 200 },
  );
});

// 子属性 18.2：累计记忆 < 100 时始终不触发 memory_100
Deno.test("Property 18.2: 累计记忆 < 100 时始终不触发 memory_100", () => {
  fc.assert(
    fc.property(
      fc.integer({ min: 0, max: 99 }),
      (count: number) => {
        const result = shouldTriggerMemory100(count);
        assertEquals(
          result,
          false,
          `累计记忆 ${count} < 100，不应触发 memory_100，实际返回 ${result}`,
        );
      },
    ),
    { numRuns: 200 },
  );
});

// 子属性 18.3：恰好 100 条为边界值，应触发
Deno.test("Property 18.3: 恰好 100 条记忆为边界值，应触发 memory_100", () => {
  assertEquals(shouldTriggerMemory100(100), true);
  assertEquals(shouldTriggerMemory100(99), false);
});

// ---------- Property 19: Memory guardian streak achievement ----------

// 子属性 19.1：连续天数 >= 30 时始终触发 memory_guardian_30
Deno.test("Property 19.1: 连续天数 >= 30 时始终触发 memory_guardian_30", () => {
  fc.assert(
    fc.property(
      fc.integer({ min: 30, max: 10000 }),
      (days: number) => {
        const result = shouldTriggerGuardian30(days);
        assertEquals(
          result,
          true,
          `连续 ${days} 天 >= 30，应触发 memory_guardian_30，实际返回 ${result}`,
        );
      },
    ),
    { numRuns: 200 },
  );
});

// 子属性 19.2：连续天数 < 30 时始终不触发 memory_guardian_30
Deno.test("Property 19.2: 连续天数 < 30 时始终不触发 memory_guardian_30", () => {
  fc.assert(
    fc.property(
      fc.integer({ min: 0, max: 29 }),
      (days: number) => {
        const result = shouldTriggerGuardian30(days);
        assertEquals(
          result,
          false,
          `连续 ${days} 天 < 30，不应触发 memory_guardian_30，实际返回 ${result}`,
        );
      },
    ),
    { numRuns: 200 },
  );
});

// 子属性 19.3：恰好 30 天为边界值，应触发
Deno.test("Property 19.3: 恰好 30 天为边界值，应触发 memory_guardian_30", () => {
  assertEquals(shouldTriggerGuardian30(30), true);
  assertEquals(shouldTriggerGuardian30(29), false);
});
