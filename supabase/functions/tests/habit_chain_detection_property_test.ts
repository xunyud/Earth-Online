// Feature: memory-moat, Property 5: Time-slot habit chain detection
// Feature: memory-moat, Property 6: Weekly-cycle habit chain detection
// Feature: memory-moat, Property 7: Push-recover habit chain detection
// Feature: memory-moat, Property 8: Habit chain structural invariant
// **Validates: Requirements 5.2, 5.3, 5.4, 5.5**
//
// 属性测试：验证习惯链检测引擎在各种随机输入下的正确性。
// - Property 5: 连续 5 天相同时段完成任务时返回 time_slot 链，不满足时不返回
// - Property 6: 连续 3 个相同星期几完成特定任务时返回 weekly_cycle 链
// - Property 7: 高强度任务后 24h 内恢复任务达 3 次时返回 push_recover 链
// - Property 8: 所有返回的 HabitChain 结构合法

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";
import {
  detectHabitChains,
  detectTimeSlotChains,
  detectWeeklyCycleChains,
  detectPushRecoverChains,
} from "../_shared/guide_memory.ts";
import type { HabitChain } from "../_shared/guide_memory.ts";

// ---------- 辅助常量与工厂函数 ----------

const DAY_MS = 24 * 60 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;

/** 有效的习惯链类型集合 */
const VALID_CHAIN_TYPES = new Set(["time_slot", "weekly_cycle", "push_recover"]);

/** 构造测试用的结构化记忆条目，仅填充检测所需字段 */
function makeMemory(
  createdAt: string | number | null,
  memoryKind = "task_event",
  sourceStatus = "active",
) {
  return {
    ref: `mem-${Math.random().toString(36).slice(2, 8)}`,
    rawText: "",
    displayText: "",
    memoryKind,
    sourceTaskId: "",
    sourceTaskTitle: "",
    sourceStatus,
    createdAt,
  };
}

/**
 * 生成连续 N 天在指定基准小时（±偏移量）完成任务的记忆列表。
 * 用于构造满足 time_slot 检测条件的输入。
 *
 * @param startDate 起始日期
 * @param days 连续天数
 * @param baseHour 基准完成小时（UTC）
 * @param hourOffsets 每天相对基准小时的偏移量数组（长度应 >= days）
 */
function makeConsecutiveDayMemories(
  startDate: Date,
  days: number,
  baseHour: number,
  hourOffsets: number[],
) {
  const memories = [];
  for (let i = 0; i < days; i++) {
    const d = new Date(startDate);
    d.setUTCDate(d.getUTCDate() + i);
    // 设置完成时间为基准小时 + 偏移量，限制在 0-23 范围内
    const hour = Math.max(0, Math.min(23, baseHour + (hourOffsets[i] ?? 0)));
    d.setUTCHours(hour, 0, 0, 0);
    memories.push(makeMemory(d.toISOString()));
  }
  return memories;
}

/**
 * 生成连续 N 周在相同星期几完成特定类型任务的记忆列表。
 * 用于构造满足 weekly_cycle 检测条件的输入。
 *
 * @param startDate 第一周的目标星期几日期
 * @param weeks 连续周数
 * @param memoryKind 记忆类型
 */
function makeWeeklyCycleMemories(
  startDate: Date,
  weeks: number,
  memoryKind: string,
) {
  const memories = [];
  for (let i = 0; i < weeks; i++) {
    const d = new Date(startDate);
    d.setUTCDate(d.getUTCDate() + i * 7);
    d.setUTCHours(12, 0, 0, 0);
    memories.push(makeMemory(d.toISOString(), memoryKind));
  }
  return memories;
}

/**
 * 生成 N 组"高强度任务 + 恢复任务"配对的记忆列表。
 * 高强度任务为 task_event，恢复任务为 dialog_event，间隔在 24h 内。
 *
 * @param startDate 起始日期
 * @param pairs 配对数量
 * @param recoveryDelayHours 每组恢复任务相对高强度任务的延迟小时数数组
 */
function makePushRecoverMemories(
  startDate: Date,
  pairs: number,
  recoveryDelayHours: number[],
) {
  const memories = [];
  for (let i = 0; i < pairs; i++) {
    // 高强度任务：每隔 2 天一次，避免时间重叠
    const hiDate = new Date(startDate);
    hiDate.setUTCDate(hiDate.getUTCDate() + i * 2);
    hiDate.setUTCHours(10, 0, 0, 0);
    memories.push(makeMemory(hiDate.toISOString(), "task_event"));

    // 恢复任务：在高强度任务后 N 小时内
    const delayH = recoveryDelayHours[i] ?? 2;
    const recDate = new Date(hiDate.getTime() + delayH * HOUR_MS);
    memories.push(makeMemory(recDate.toISOString(), "dialog_event"));
  }
  return memories;
}

// ---------- Property 5: Time-slot habit chain detection ----------

// Feature: memory-moat, Property 5: Time-slot habit chain detection
Deno.test("Property 5: 连续 5+ 天相同时段完成任务时返回 time_slot 链", () => {
  // 生成器：产生连续天数的小时序列，确保相邻天的小时差 <= 2
  // 实现检测的是相邻天的小时差，而非与固定基准小时的偏差
  const arbConsecutiveHours = (maxLen: number) =>
    fc.tuple(
      fc.integer({ min: 2, max: 21 }), // 起始小时
      fc.array(fc.integer({ min: -2, max: 2 }), {
        minLength: maxLen - 1,
        maxLength: maxLen - 1,
      }),
    ).map(([start, deltas]) => {
      const hours: number[] = [start];
      for (const delta of deltas) {
        const prev = hours[hours.length - 1];
        hours.push(Math.max(0, Math.min(23, prev + delta)));
      }
      return hours;
    });

  fc.assert(
    fc.property(
      // 连续天数：5 到 15 天
      fc.integer({ min: 5, max: 15 }),
      arbConsecutiveHours(15),
      (days: number, allHours: number[]) => {
        const hours = allHours.slice(0, days);
        const startDate = new Date("2026-05-01T00:00:00Z");
        const now = new Date("2026-06-01T00:00:00Z");

        // 用生成的小时序列构造记忆
        const memories = [];
        for (let i = 0; i < days; i++) {
          const d = new Date(startDate);
          d.setUTCDate(d.getUTCDate() + i);
          d.setUTCHours(hours[i], 0, 0, 0);
          memories.push(makeMemory(d.toISOString()));
        }

        const chains = detectTimeSlotChains(memories, now);

        // 应至少返回一条 time_slot 链
        assert(
          chains.length >= 1,
          `连续 ${days} 天（相邻小时差 <= 2）完成任务，应检测到 time_slot 链，实际返回 ${chains.length} 条。小时序列: [${hours.join(",")}]`,
        );

        const timeSlotChain = chains.find((c) => c.type === "time_slot");
        assert(timeSlotChain !== undefined, "应包含 time_slot 类型的链");
        assert(
          timeSlotChain!.consecutiveDays >= 5,
          `consecutiveDays 应 >= 5，实际为 ${timeSlotChain!.consecutiveDays}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 5: 不足 5 天连续相同时段时不返回 time_slot 链", () => {
  fc.assert(
    fc.property(
      // 连续天数：1 到 4 天
      fc.integer({ min: 1, max: 4 }),
      fc.integer({ min: 2, max: 21 }),
      fc.array(fc.integer({ min: -1, max: 1 }), { minLength: 4, maxLength: 4 }),
      (days: number, baseHour: number, offsets: number[]) => {
        const startDate = new Date("2026-05-01T00:00:00Z");
        const now = new Date("2026-06-01T00:00:00Z");

        const memories = makeConsecutiveDayMemories(startDate, days, baseHour, offsets);
        const chains = detectTimeSlotChains(memories, now);

        // 不应返回 time_slot 链
        assertEquals(
          chains.length,
          0,
          `仅 ${days} 天连续完成，不应检测到 time_slot 链，实际返回 ${chains.length} 条`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// ---------- Property 6: Weekly-cycle habit chain detection ----------

// Feature: memory-moat, Property 6: Weekly-cycle habit chain detection
Deno.test("Property 6: 连续 3+ 个相同星期几完成特定任务时返回 weekly_cycle 链", () => {
  fc.assert(
    fc.property(
      // 连续周数：3 到 8 周
      fc.integer({ min: 3, max: 8 }),
      // 起始星期几偏移（0=周日 ... 6=周六），用于选择目标星期几
      fc.integer({ min: 0, max: 6 }),
      // 记忆类型
      fc.constantFrom("task_event", "dialog_event", "generic"),
      (weeks: number, weekdayOffset: number, kind: string) => {
        // 构造起始日期：2026-05-04 是周一，加偏移量得到目标星期几
        const baseDate = new Date("2026-05-04T00:00:00Z"); // 周一
        const startDate = new Date(baseDate);
        startDate.setUTCDate(startDate.getUTCDate() + weekdayOffset);
        const now = new Date("2026-08-01T00:00:00Z");

        const memories = makeWeeklyCycleMemories(startDate, weeks, kind);
        const chains = detectWeeklyCycleChains(memories, now);

        // 应至少返回一条 weekly_cycle 链
        assert(
          chains.length >= 1,
          `连续 ${weeks} 周在同一星期几完成 ${kind} 任务，应检测到 weekly_cycle 链，实际返回 ${chains.length} 条`,
        );

        const weeklyCycleChain = chains.find((c) => c.type === "weekly_cycle");
        assert(weeklyCycleChain !== undefined, "应包含 weekly_cycle 类型的链");
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 6: 不足 3 个连续周时不返回 weekly_cycle 链", () => {
  fc.assert(
    fc.property(
      // 连续周数：1 到 2 周
      fc.integer({ min: 1, max: 2 }),
      fc.integer({ min: 0, max: 6 }),
      fc.constantFrom("task_event", "dialog_event", "generic"),
      (weeks: number, weekdayOffset: number, kind: string) => {
        const baseDate = new Date("2026-05-04T00:00:00Z");
        const startDate = new Date(baseDate);
        startDate.setUTCDate(startDate.getUTCDate() + weekdayOffset);
        const now = new Date("2026-08-01T00:00:00Z");

        const memories = makeWeeklyCycleMemories(startDate, weeks, kind);
        const chains = detectWeeklyCycleChains(memories, now);

        // 不应返回 weekly_cycle 链
        assertEquals(
          chains.length,
          0,
          `仅 ${weeks} 周连续完成，不应检测到 weekly_cycle 链，实际返回 ${chains.length} 条`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// ---------- Property 7: Push-recover habit chain detection ----------

// Feature: memory-moat, Property 7: Push-recover habit chain detection
Deno.test("Property 7: 高强度任务后 24h 内恢复任务达 3+ 次时返回 push_recover 链", () => {
  fc.assert(
    fc.property(
      // 配对数量：3 到 8 组
      fc.integer({ min: 3, max: 8 }),
      // 每组恢复任务的延迟小时数：1-23h（确保在 24h 内）
      fc.array(fc.integer({ min: 1, max: 23 }), { minLength: 8, maxLength: 8 }),
      (pairs: number, delayHours: number[]) => {
        const startDate = new Date("2026-05-01T00:00:00Z");
        const now = new Date("2026-06-01T00:00:00Z");

        const memories = makePushRecoverMemories(startDate, pairs, delayHours);
        const chains = detectPushRecoverChains(memories, now);

        // 应至少返回一条 push_recover 链
        assert(
          chains.length >= 1,
          `${pairs} 组推进-恢复配对（恢复在 24h 内），应检测到 push_recover 链，实际返回 ${chains.length} 条`,
        );

        const prChain = chains.find((c) => c.type === "push_recover");
        assert(prChain !== undefined, "应包含 push_recover 类型的链");
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 7: 不足 3 组推进-恢复配对时不返回 push_recover 链", () => {
  fc.assert(
    fc.property(
      // 配对数量：1 到 2 组
      fc.integer({ min: 1, max: 2 }),
      fc.array(fc.integer({ min: 1, max: 23 }), { minLength: 2, maxLength: 2 }),
      (pairs: number, delayHours: number[]) => {
        const startDate = new Date("2026-05-01T00:00:00Z");
        const now = new Date("2026-06-01T00:00:00Z");

        const memories = makePushRecoverMemories(startDate, pairs, delayHours);
        const chains = detectPushRecoverChains(memories, now);

        // 不应返回 push_recover 链
        assertEquals(
          chains.length,
          0,
          `仅 ${pairs} 组配对，不应检测到 push_recover 链，实际返回 ${chains.length} 条`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 7: 恢复任务超过 24h 时不计入配对", () => {
  fc.assert(
    fc.property(
      // 配对数量：3 到 6 组，但恢复延迟超过 24h
      fc.integer({ min: 3, max: 6 }),
      fc.array(fc.integer({ min: 25, max: 48 }), { minLength: 6, maxLength: 6 }),
      (pairs: number, delayHours: number[]) => {
        const startDate = new Date("2026-05-01T00:00:00Z");
        const now = new Date("2026-06-01T00:00:00Z");

        const memories = makePushRecoverMemories(startDate, pairs, delayHours);
        const chains = detectPushRecoverChains(memories, now);

        // 恢复任务超过 24h，不应检测到 push_recover 链
        assertEquals(
          chains.length,
          0,
          `恢复任务延迟超过 24h，不应检测到 push_recover 链，实际返回 ${chains.length} 条`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// ---------- Property 8: Habit chain structural invariant ----------

// Feature: memory-moat, Property 8: Habit chain structural invariant
Deno.test("Property 8: detectHabitChains 返回的所有链结构合法", () => {
  // 生成随机记忆列表，调用 detectHabitChains，验证输出结构
  const arbMemoryKind = fc.constantFrom(
    "task_event",
    "dialog_event",
    "generic",
    "episodic_memory",
  );

  // 生成随机时间戳：2026 年 5 月内的随机时间
  const arbTimestamp = fc.integer({
    min: new Date("2026-05-01T00:00:00Z").getTime(),
    max: new Date("2026-05-31T23:59:59Z").getTime(),
  });

  // 生成随机记忆条目
  const arbMemory = fc.record({
    ref: fc.string({ minLength: 1, maxLength: 10 }).map((s) => `mem-${s}`),
    rawText: fc.constant(""),
    displayText: fc.constant(""),
    memoryKind: arbMemoryKind,
    sourceTaskId: fc.constant(""),
    sourceTaskTitle: fc.constant(""),
    sourceStatus: fc.constantFrom("active", "muted"),
    createdAt: fc.oneof(
      arbTimestamp,
      arbTimestamp.map((ts) => new Date(ts).toISOString()),
      fc.constant(null as string | number | null),
    ),
  });

  fc.assert(
    fc.property(
      fc.array(arbMemory, { minLength: 0, maxLength: 50 }),
      (memories) => {
        const now = new Date("2026-06-01T00:00:00Z");
        const chains = detectHabitChains(memories, now);

        // 验证每条链的结构合法性
        for (const chain of chains) {
          // type 必须是有效值
          assert(
            VALID_CHAIN_TYPES.has(chain.type),
            `链类型 "${chain.type}" 不在有效集合 {time_slot, weekly_cycle, push_recover} 中`,
          );

          // description 必须非空
          assert(
            typeof chain.description === "string" && chain.description.length > 0,
            `链描述不应为空，实际为 "${chain.description}"`,
          );

          // consecutiveDays 必须 > 0
          assert(
            typeof chain.consecutiveDays === "number" && chain.consecutiveDays > 0,
            `consecutiveDays 应 > 0，实际为 ${chain.consecutiveDays}`,
          );

          // confidence 必须在 [0.0, 1.0] 范围内
          assert(
            typeof chain.confidence === "number" &&
              chain.confidence >= 0.0 &&
              chain.confidence <= 1.0,
            `confidence 应在 [0.0, 1.0] 范围内，实际为 ${chain.confidence}`,
          );
        }
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 8: 空输入返回空列表，结构不变量仍成立", () => {
  const chains = detectHabitChains([], new Date("2026-06-01T00:00:00Z"));
  assertEquals(chains.length, 0, "空输入应返回空列表");
});

Deno.test("Property 8: 含 null createdAt 的记忆不导致异常", () => {
  fc.assert(
    fc.property(
      // 生成混合 null 和有效时间戳的记忆列表
      fc.array(
        fc.record({
          ref: fc.constant("mem-test"),
          rawText: fc.constant(""),
          displayText: fc.constant(""),
          memoryKind: fc.constantFrom("task_event", "dialog_event"),
          sourceTaskId: fc.constant(""),
          sourceTaskTitle: fc.constant(""),
          sourceStatus: fc.constant("active"),
          createdAt: fc.oneof(
            fc.constant(null as string | number | null),
            fc.constant("invalid-date" as string | number | null),
            fc.integer({
              min: new Date("2026-05-01").getTime(),
              max: new Date("2026-05-31").getTime(),
            }).map((ts) => ts as string | number | null),
          ),
        }),
        { minLength: 0, maxLength: 20 },
      ),
      (memories) => {
        const now = new Date("2026-06-01T00:00:00Z");
        // 不应抛出异常
        const chains = detectHabitChains(memories, now);

        // 返回值应为数组
        assert(Array.isArray(chains), "返回值应为数组");

        // 每条链仍满足结构不变量
        for (const chain of chains) {
          assert(VALID_CHAIN_TYPES.has(chain.type));
          assert(chain.description.length > 0);
          assert(chain.consecutiveDays > 0);
          assert(chain.confidence >= 0.0 && chain.confidence <= 1.0);
        }
      },
    ),
    { numRuns: 100 },
  );
});
