// Feature: memory-system-evolution, Property 19: Milestone detection correctness
// **Validates: Requirements 10.1, 10.2, 10.3**
//
// 属性测试：验证三种里程碑的检测条件充要性（if-and-only-if）。
// 对任意 MilestoneDetectionContext，检测结果必须严格满足：
//   (a) "streak_7day" ∈ result ⟺ currentStreak=7 ∧ previousStreak=6
//   (b) "first_clear" ∈ result ⟺ todayCompletedCount >= totalActiveTaskCount > 0 ∧ isFirstClear=true
//   (c) "recovery_from_break" ∈ result ⟺ previousStreak=0 ∧ todayCompletedCount > 0 ∧ currentStreak=1

import {
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";
import {
  detectMilestones,
  type MilestoneDetectionContext,
} from "../_shared/milestone_detector.ts";

// ---------- 生成器 ----------

/** 生成随机的 MilestoneDetectionContext */
const arbContext: fc.Arbitrary<MilestoneDetectionContext> = fc.record({
  userId: fc.stringOf(
    fc.constantFrom(..."abcdefghijklmnopqrstuvwxyz0123456789"),
    { minLength: 1, maxLength: 10 },
  ),
  currentStreak: fc.integer({ min: 0, max: 30 }),
  previousStreak: fc.integer({ min: 0, max: 30 }),
  todayCompletedCount: fc.integer({ min: 0, max: 20 }),
  totalActiveTaskCount: fc.integer({ min: 0, max: 20 }),
  isFirstClear: fc.boolean(),
});

// ---------- Property 19: Milestone detection correctness ----------

Deno.test("Property 19(a): streak_7day 充要条件 — currentStreak=7 且 previousStreak=6", () => {
  fc.assert(
    fc.property(arbContext, (ctx) => {
      const result = detectMilestones(ctx);
      const hasStreak7day = result.includes("streak_7day");

      // 充要条件：streak_7day ⟺ currentStreak=7 ∧ previousStreak=6
      const shouldHave = ctx.currentStreak === 7 && ctx.previousStreak === 6;

      assertEquals(
        hasStreak7day,
        shouldHave,
        `streak_7day: ctx=${JSON.stringify(ctx)}, expected=${shouldHave}, got=${hasStreak7day}`,
      );
    }),
    { numRuns: 500 },
  );
});

Deno.test("Property 19(b): first_clear 充要条件 — todayCompleted >= totalActive > 0 且 isFirstClear", () => {
  fc.assert(
    fc.property(arbContext, (ctx) => {
      const result = detectMilestones(ctx);
      const hasFirstClear = result.includes("first_clear");

      // 充要条件：first_clear ⟺ todayCompletedCount >= totalActiveTaskCount > 0 ∧ isFirstClear
      const shouldHave =
        ctx.todayCompletedCount > 0 &&
        ctx.todayCompletedCount >= ctx.totalActiveTaskCount &&
        ctx.totalActiveTaskCount > 0 &&
        ctx.isFirstClear;

      assertEquals(
        hasFirstClear,
        shouldHave,
        `first_clear: ctx=${JSON.stringify(ctx)}, expected=${shouldHave}, got=${hasFirstClear}`,
      );
    }),
    { numRuns: 500 },
  );
});

Deno.test("Property 19(c): recovery_from_break 充要条件 — previousStreak=0 且 todayCompleted > 0 且 currentStreak=1", () => {
  fc.assert(
    fc.property(arbContext, (ctx) => {
      const result = detectMilestones(ctx);
      const hasRecovery = result.includes("recovery_from_break");

      // 充要条件：recovery_from_break ⟺ previousStreak=0 ∧ todayCompletedCount > 0 ∧ currentStreak=1
      const shouldHave =
        ctx.previousStreak === 0 &&
        ctx.todayCompletedCount > 0 &&
        ctx.currentStreak === 1;

      assertEquals(
        hasRecovery,
        shouldHave,
        `recovery_from_break: ctx=${JSON.stringify(ctx)}, expected=${shouldHave}, got=${hasRecovery}`,
      );
    }),
    { numRuns: 500 },
  );
});

Deno.test("Property 19: 检测结果仅包含三种已知类型，无多余元素", () => {
  const validTypes = new Set(["streak_7day", "first_clear", "recovery_from_break"]);
  fc.assert(
    fc.property(arbContext, (ctx) => {
      const result = detectMilestones(ctx);

      // 结果中每个元素都必须是已知类型
      for (const m of result) {
        assertEquals(
          validTypes.has(m),
          true,
          `检测到未知里程碑类型: "${m}"`,
        );
      }

      // 结果中不应有重复元素
      assertEquals(
        result.length,
        new Set(result).size,
        `检测结果包含重复元素: ${JSON.stringify(result)}`,
      );
    }),
    { numRuns: 500 },
  );
});
