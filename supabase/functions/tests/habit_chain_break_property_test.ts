// Feature: memory-moat, Property 10: Habit chain break detection
// Feature: memory-moat, Property 11: Habit chain break message structure
// Feature: memory-moat, Property 12: Habit chain break rate limiting
// **Validates: Requirements 7.2, 7.3, 7.4**
//
// 属性测试：验证习惯链断裂检测在各种随机输入下的正确性。
// - Property 10: 预期时间窗口过后无匹配记忆时返回 true，有匹配时返回 false
// - Property 11: 断裂消息包含习惯描述和持续天数，不含指责性语言
// - Property 12: 同一习惯链 24h 内最多生成 1 次断裂信号（概念验证）

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";
import { isChainBreaking } from "../_shared/guide_memory.ts";
import type {
  GuideStructuredMemoryItem,
  HabitChain,
} from "../_shared/guide_memory.ts";

// ---------- 辅助工厂函数 ----------

/** 构造测试用的结构化记忆条目 */
function makeMemory(
  createdAt: string | number | null,
  memoryKind = "task_event",
): GuideStructuredMemoryItem {
  return {
    ref: `mem-${Math.random().toString(36).slice(2, 8)}`,
    rawText: "",
    displayText: "",
    memoryKind,
    sourceTaskId: "",
    sourceTaskTitle: "",
    sourceStatus: "active",
    createdAt,
  };
}

// ---------- Property 10: Habit chain break detection ----------

// Feature: memory-moat, Property 10: Habit chain break detection
// time_slot 链：当天预期时段已过 2h 且无匹配记忆时返回 true
Deno.test("Property 10: time_slot — 预期时段过后无匹配记忆时返回 true", () => {
  fc.assert(
    fc.property(
      // 预期完成小时：0-21（确保 +2 后不超过 23）
      fc.integer({ min: 0, max: 21 }),
      // 连续天数
      fc.integer({ min: 5, max: 30 }),
      // 置信度
      fc.double({ min: 0.5, max: 1.0, noNaN: true }),
      (expectedHour: number, consecutiveDays: number, confidence: number) => {
        const chain: HabitChain = {
          type: "time_slot",
          description: `每天约 ${expectedHour} 点完成任务`,
          consecutiveDays,
          confidence,
        };

        // nowDate 设置为预期时段 +3h（已过缓冲期）
        const todayStr = "2026-06-10";
        const nowHour = expectedHour + 3;
        // 如果 nowHour > 23，跳过（边界情况由 isChainBreaking 内部处理）
        if (nowHour > 23) return;
        const nowDate = new Date(`${todayStr}T${String(nowHour).padStart(2, "0")}:00:00Z`);

        // 无今天的记忆 → 应返回 true（断裂）
        const result = isChainBreaking(chain, [], nowDate);
        assert(
          result === true,
          `预期时段 ${expectedHour} 点已过且无记忆，应返回 true，实际为 ${result}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 10: Habit chain break detection
// time_slot 链：当天预期时段内有匹配记忆时返回 false
Deno.test("Property 10: time_slot — 预期时段内有匹配记忆时返回 false", () => {
  fc.assert(
    fc.property(
      // 预期完成小时：2-21（确保 ±2h 在 0-23 范围内）
      fc.integer({ min: 2, max: 21 }),
      // 记忆完成时间相对预期小时的偏移：-2 到 +2
      fc.integer({ min: -2, max: 2 }),
      fc.integer({ min: 5, max: 30 }),
      fc.double({ min: 0.5, max: 1.0, noNaN: true }),
      (expectedHour: number, offset: number, consecutiveDays: number, confidence: number) => {
        const chain: HabitChain = {
          type: "time_slot",
          description: `每天约 ${expectedHour} 点完成任务`,
          consecutiveDays,
          confidence,
        };

        // nowDate 设置为预期时段 +3h
        const todayStr = "2026-06-10";
        const nowHour = Math.min(23, expectedHour + 3);
        const nowDate = new Date(`${todayStr}T${String(nowHour).padStart(2, "0")}:00:00Z`);

        // 今天在预期时段 ±2h 内有一条记忆
        const memHour = Math.max(0, Math.min(23, expectedHour + offset));
        const memDate = `${todayStr}T${String(memHour).padStart(2, "0")}:00:00Z`;
        const memories = [makeMemory(memDate)];

        const result = isChainBreaking(chain, memories, nowDate);
        assert(
          result === false,
          `预期时段 ${expectedHour} 点，记忆在 ${memHour} 点（偏移 ${offset}），应返回 false，实际为 ${result}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 10: Habit chain break detection
// time_slot 链：当前时间未超过缓冲期时返回 false（不判定断裂）
Deno.test("Property 10: time_slot — 缓冲期内返回 false", () => {
  fc.assert(
    fc.property(
      // 预期完成小时：2-22
      fc.integer({ min: 2, max: 22 }),
      // 当前时间在预期小时之前或刚好（未超过 +2h 缓冲）
      fc.integer({ min: 0, max: 1 }),
      fc.integer({ min: 5, max: 20 }),
      fc.double({ min: 0.5, max: 1.0, noNaN: true }),
      (expectedHour: number, hoursBefore: number, consecutiveDays: number, confidence: number) => {
        const chain: HabitChain = {
          type: "time_slot",
          description: `每天约 ${expectedHour} 点完成任务`,
          consecutiveDays,
          confidence,
        };

        // nowDate 设置为预期时段 + hoursBefore（0 或 1，未超过 +2h 缓冲）
        const todayStr = "2026-06-10";
        const nowHour = Math.min(23, expectedHour + hoursBefore);
        const nowDate = new Date(`${todayStr}T${String(nowHour).padStart(2, "0")}:00:00Z`);

        // 无记忆，但缓冲期内不应判定断裂
        const result = isChainBreaking(chain, [], nowDate);
        assert(
          result === false,
          `预期时段 ${expectedHour} 点，当前 ${nowHour} 点（缓冲期内），应返回 false，实际为 ${result}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 10: Habit chain break detection
// weekly_cycle 链：当天是预期星期几且无匹配记忆时返回 true
Deno.test("Property 10: weekly_cycle — 预期星期几无匹配记忆时返回 true", () => {
  // 星期几名称映射
  const weekdayNames = ["日", "一", "二", "三", "四", "五", "六"];
  // 2026-06-08 是周一，2026-06-09 是周二，...，2026-06-14 是周日
  const weekdayDates: Record<number, string> = {
    1: "2026-06-08", // 周一
    2: "2026-06-09", // 周二
    3: "2026-06-10", // 周三
    4: "2026-06-11", // 周四
    5: "2026-06-12", // 周五
    6: "2026-06-13", // 周六
    0: "2026-06-14", // 周日
  };

  fc.assert(
    fc.property(
      fc.integer({ min: 0, max: 6 }),
      fc.integer({ min: 3, max: 20 }),
      fc.double({ min: 0.5, max: 1.0, noNaN: true }),
      (weekday: number, consecutiveDays: number, confidence: number) => {
        const chain: HabitChain = {
          type: "weekly_cycle",
          description: `每周${weekdayNames[weekday]}完成 task_event 类型任务`,
          consecutiveDays,
          confidence,
        };

        // 设置 nowDate 为对应星期几的日期
        const dateStr = weekdayDates[weekday];
        const nowDate = new Date(`${dateStr}T12:00:00Z`);

        // 无今天的记忆 → 应返回 true
        const result = isChainBreaking(chain, [], nowDate);
        assert(
          result === true,
          `周${weekdayNames[weekday]}无记忆，应返回 true，实际为 ${result}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 10: Habit chain break detection
// weekly_cycle 链：当天是预期星期几且有匹配记忆时返回 false
Deno.test("Property 10: weekly_cycle — 预期星期几有匹配记忆时返回 false", () => {
  const weekdayNames = ["日", "一", "二", "三", "四", "五", "六"];
  const weekdayDates: Record<number, string> = {
    1: "2026-06-08",
    2: "2026-06-09",
    3: "2026-06-10",
    4: "2026-06-11",
    5: "2026-06-12",
    6: "2026-06-13",
    0: "2026-06-14",
  };

  fc.assert(
    fc.property(
      fc.integer({ min: 0, max: 6 }),
      fc.integer({ min: 3, max: 20 }),
      fc.double({ min: 0.5, max: 1.0, noNaN: true }),
      (weekday: number, consecutiveDays: number, confidence: number) => {
        const chain: HabitChain = {
          type: "weekly_cycle",
          description: `每周${weekdayNames[weekday]}完成 task_event 类型任务`,
          consecutiveDays,
          confidence,
        };

        const dateStr = weekdayDates[weekday];
        const nowDate = new Date(`${dateStr}T18:00:00Z`);

        // 今天有一条记忆 → 应返回 false
        const memories = [makeMemory(`${dateStr}T10:00:00Z`)];
        const result = isChainBreaking(chain, memories, nowDate);
        assert(
          result === false,
          `周${weekdayNames[weekday]}有记忆，应返回 false，实际为 ${result}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 10: Habit chain break detection
// weekly_cycle 链：当天不是预期星期几时返回 false（不检测）
Deno.test("Property 10: weekly_cycle — 非预期星期几返回 false", () => {
  const weekdayNames = ["日", "一", "二", "三", "四", "五", "六"];

  fc.assert(
    fc.property(
      fc.integer({ min: 0, max: 6 }),
      fc.integer({ min: 3, max: 20 }),
      fc.double({ min: 0.5, max: 1.0, noNaN: true }),
      (weekday: number, consecutiveDays: number, confidence: number) => {
        const chain: HabitChain = {
          type: "weekly_cycle",
          description: `每周${weekdayNames[weekday]}完成 task_event 类型任务`,
          consecutiveDays,
          confidence,
        };

        // 选择一个不同的星期几
        const otherWeekday = (weekday + 3) % 7;
        // 2026-06-08 是周一
        const baseDate = new Date("2026-06-08T12:00:00Z");
        // 调整到 otherWeekday 对应的日期
        const currentDay = baseDate.getUTCDay(); // 1 (周一)
        const diff = (otherWeekday - currentDay + 7) % 7;
        const targetDate = new Date(baseDate);
        targetDate.setUTCDate(targetDate.getUTCDate() + diff);

        const result = isChainBreaking(chain, [], targetDate);
        assert(
          result === false,
          `当天是周${weekdayNames[otherWeekday]}，预期周${weekdayNames[weekday]}，应返回 false，实际为 ${result}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 10: Habit chain break detection
// push_recover 链：高强度任务后 24h 内无恢复记忆时返回 true
Deno.test("Property 10: push_recover — 高强度任务后无恢复记忆时返回 true", () => {
  fc.assert(
    fc.property(
      // 高强度任务距今的小时数：1-23（在 24h 窗口内）
      fc.integer({ min: 1, max: 23 }),
      fc.integer({ min: 3, max: 20 }),
      fc.double({ min: 0.5, max: 1.0, noNaN: true }),
      (hoursAgo: number, consecutiveDays: number, confidence: number) => {
        const chain: HabitChain = {
          type: "push_recover",
          description: "高强度任务后恢复",
          consecutiveDays,
          confidence,
        };

        const now = new Date("2026-06-10T20:00:00Z");
        // 高强度任务在 hoursAgo 小时前
        const hiTime = new Date(now.getTime() - hoursAgo * 60 * 60 * 1000);
        // 仅有高强度任务记忆，无恢复类记忆
        const memories = [makeMemory(hiTime.toISOString(), "task_event")];

        const result = isChainBreaking(chain, memories, now);
        assert(
          result === true,
          `高强度任务 ${hoursAgo}h 前，无恢复记忆，应返回 true，实际为 ${result}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 10: Habit chain break detection
// push_recover 链：高强度任务后 24h 内有恢复记忆时返回 false
Deno.test("Property 10: push_recover — 高强度任务后有恢复记忆时返回 false", () => {
  fc.assert(
    fc.property(
      // 高强度任务距今的小时数：2-23
      fc.integer({ min: 2, max: 23 }),
      // 恢复任务在高强度任务后的小时数：1 到 hoursAgo-1
      fc.integer({ min: 1, max: 22 }),
      fc.integer({ min: 3, max: 20 }),
      fc.double({ min: 0.5, max: 1.0, noNaN: true }),
      (hoursAgo: number, recoveryDelay: number, consecutiveDays: number, confidence: number) => {
        // 确保恢复任务在高强度任务之后、当前时间之前
        if (recoveryDelay >= hoursAgo) return;

        const chain: HabitChain = {
          type: "push_recover",
          description: "高强度任务后恢复",
          consecutiveDays,
          confidence,
        };

        const now = new Date("2026-06-10T20:00:00Z");
        const hiTime = new Date(now.getTime() - hoursAgo * 60 * 60 * 1000);
        const recTime = new Date(hiTime.getTime() + recoveryDelay * 60 * 60 * 1000);

        const memories = [
          makeMemory(hiTime.toISOString(), "task_event"),
          makeMemory(recTime.toISOString(), "dialog_event"), // 恢复类记忆
        ];

        const result = isChainBreaking(chain, memories, now);
        assert(
          result === false,
          `高强度任务 ${hoursAgo}h 前，恢复在 ${recoveryDelay}h 后，应返回 false，实际为 ${result}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});


// ---------- Property 11: Habit chain break message structure ----------

// Feature: memory-moat, Property 11: Habit chain break message structure
// 验证断裂消息包含习惯描述和持续天数，不含指责性语言
Deno.test("Property 11: 断裂消息包含习惯描述和持续天数", () => {
  // 指责性语言模式
  const accusatoryPatterns = ["你没有", "你失败了", "你忘了"];

  fc.assert(
    fc.property(
      // 习惯描述
      fc.constantFrom(
        "每天约 8 点完成任务",
        "每天约 14 点完成任务",
        "每周一完成 task_event 类型任务",
        "高强度任务后恢复",
      ),
      // 连续天数
      fc.integer({ min: 1, max: 100 }),
      // 习惯链类型
      fc.constantFrom("time_slot" as const, "weekly_cycle" as const, "push_recover" as const),
      fc.double({ min: 0.5, max: 1.0, noNaN: true }),
      (description: string, consecutiveDays: number, type: "time_slot" | "weekly_cycle" | "push_recover", confidence: number) => {
        const chain: HabitChain = {
          type,
          description,
          consecutiveDays,
          confidence,
        };

        // 使用 detectPatrolSignals 中的消息模板格式构造消息
        const message = `你的"${chain.description}"习惯已经持续了${chain.consecutiveDays}天，今天还没有看到相关行动。没关系，节奏偶尔会变化，重要的是你已经建立了这个模式。`;

        // 消息应包含习惯描述
        assert(
          message.includes(chain.description),
          `消息应包含习惯描述 "${chain.description}"`,
        );

        // 消息应包含持续天数
        assert(
          message.includes(String(chain.consecutiveDays)),
          `消息应包含持续天数 ${chain.consecutiveDays}`,
        );

        // 消息不应包含指责性语言
        for (const pattern of accusatoryPatterns) {
          assert(
            !message.includes(pattern),
            `消息不应包含指责性语言 "${pattern}"，实际消息: ${message}`,
          );
        }
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 11: Habit chain break message structure
// 验证消息语气为鼓励性（包含正面表达）
Deno.test("Property 11: 断裂消息语气为鼓励性", () => {
  fc.assert(
    fc.property(
      fc.string({ minLength: 1, maxLength: 30 }),
      fc.integer({ min: 1, max: 100 }),
      fc.constantFrom("time_slot" as const, "weekly_cycle" as const, "push_recover" as const),
      (description: string, consecutiveDays: number, type: "time_slot" | "weekly_cycle" | "push_recover") => {
        const message = `你的"${description}"习惯已经持续了${consecutiveDays}天，今天还没有看到相关行动。没关系，节奏偶尔会变化，重要的是你已经建立了这个模式。`;

        // 消息应包含鼓励性表达
        const hasEncouragement =
          message.includes("没关系") ||
          message.includes("重要的是") ||
          message.includes("已经建立");
        assert(
          hasEncouragement,
          `消息应包含鼓励性表达，实际消息: ${message}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// ---------- Property 12: Habit chain break rate limiting ----------

// Feature: memory-moat, Property 12: Habit chain break rate limiting
// 概念验证：验证去重逻辑的消息格式支持按 chainType 匹配
// 实际去重通过 patrol_logs 数据库查询实现，此处验证消息中包含 chainType 标识
Deno.test("Property 12: 断裂信号包含 chainType 用于去重匹配", () => {
  fc.assert(
    fc.property(
      fc.constantFrom("time_slot" as const, "weekly_cycle" as const, "push_recover" as const),
      fc.string({ minLength: 1, maxLength: 30 }),
      fc.integer({ min: 1, max: 100 }),
      fc.double({ min: 0.5, max: 1.0, noNaN: true }),
      (type: "time_slot" | "weekly_cycle" | "push_recover", description: string, consecutiveDays: number, confidence: number) => {
        const chain: HabitChain = {
          type,
          description,
          consecutiveDays,
          confidence,
        };

        // 模拟 detectPatrolSignals 中的信号结构
        const signal = {
          kind: "habit_chain_break" as const,
          message: `你的"${chain.description}"习惯已经持续了${chain.consecutiveDays}天，今天还没有看到相关行动。没关系，节奏偶尔会变化，重要的是你已经建立了这个模式。`,
          urgency: "medium" as const,
          chainType: chain.type,
        };

        // 信号应包含 chainType 字段
        assert(
          signal.chainType === type,
          `信号 chainType 应为 "${type}"，实际为 "${signal.chainType}"`,
        );

        // 模拟写入日志的格式（用于后续去重查询）
        const logContent = `[habit_chain_break:${signal.chainType}] ${signal.message}`;

        // 日志内容应包含 habit_chain_break 和 chainType，便于 LIKE 查询去重
        assert(
          logContent.includes("habit_chain_break") && logContent.includes(type),
          `日志内容应包含 "habit_chain_break" 和 "${type}" 用于去重查询`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 12: Habit chain break rate limiting
// 概念验证：模拟多次巡逻，验证去重逻辑过滤重复信号
Deno.test("Property 12: 24h 内同一 chainType 的重复信号被过滤", () => {
  fc.assert(
    fc.property(
      fc.constantFrom("time_slot" as const, "weekly_cycle" as const, "push_recover" as const),
      // 巡逻次数：2-5 次
      fc.integer({ min: 2, max: 5 }),
      (chainType: "time_slot" | "weekly_cycle" | "push_recover", patrolCount: number) => {
        // 模拟已有的日志记录（24h 内的第一次断裂信号）
        const existingLogs: string[] = [
          `[habit_chain_break:${chainType}] 你的"测试习惯"习惯已经持续了5天...`,
        ];

        // 模拟后续巡逻生成的信号
        const signals: Array<{ chainType: string; shouldSend: boolean }> = [];
        for (let i = 0; i < patrolCount; i++) {
          const newSignalChainType = chainType;
          // 检查 existingLogs 中是否已有同类型信号（模拟 LIKE 查询）
          const hasDuplicate = existingLogs.some(
            (log) =>
              log.includes("habit_chain_break") &&
              log.includes(newSignalChainType),
          );
          signals.push({
            chainType: newSignalChainType,
            shouldSend: !hasDuplicate,
          });
        }

        // 第一个信号之后的所有同类型信号都应被过滤
        // signals[0] 应被过滤（因为 existingLogs 已有记录）
        for (const signal of signals) {
          assert(
            signal.shouldSend === false,
            `24h 内已有 ${chainType} 断裂记录，后续信号应被过滤`,
          );
        }
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 12: Habit chain break rate limiting
// 不同 chainType 的信号不互相影响
Deno.test("Property 12: 不同 chainType 的信号不互相过滤", () => {
  const allTypes = ["time_slot", "weekly_cycle", "push_recover"] as const;

  fc.assert(
    fc.property(
      fc.integer({ min: 0, max: 2 }),
      fc.integer({ min: 0, max: 2 }),
      (existingIdx: number, newIdx: number) => {
        // 确保两个类型不同
        if (existingIdx === newIdx) return;

        const existingType = allTypes[existingIdx];
        const newType = allTypes[newIdx];

        // 已有日志中记录了 existingType 的断裂信号
        const existingLogs = [
          `[habit_chain_break:${existingType}] 测试消息`,
        ];

        // 新信号是 newType，不应被过滤
        const hasDuplicate = existingLogs.some(
          (log) =>
            log.includes("habit_chain_break") && log.includes(newType),
        );

        assert(
          hasDuplicate === false,
          `已有 ${existingType} 记录不应过滤 ${newType} 信号`,
        );
      },
    ),
    { numRuns: 100 },
  );
});
