// 单元测试：习惯链检测引擎
// 覆盖 detectHabitChains、detectTimeSlotChains、detectWeeklyCycleChains、detectPushRecoverChains 的具体场景和边界条件。
// _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import {
  detectHabitChains,
  detectTimeSlotChains,
  detectWeeklyCycleChains,
  detectPushRecoverChains,
} from "../_shared/guide_memory.ts";

// ---------- 辅助工厂函数 ----------

/** 构造测试用的结构化记忆条目，仅填充检测所需字段 */
function makeMemory(
  createdAt: string | number | null,
  memoryKind = "task_event",
) {
  return {
    ref: "test-mem",
    rawText: "",
    displayText: "",
    memoryKind,
    sourceTaskId: "",
    sourceTaskTitle: "",
    sourceStatus: "active",
    createdAt,
  };
}

// 固定参考时间，所有测试用例基于此时间点
const NOW = new Date("2026-06-01T00:00:00Z");

// ==================== 1. 空输入返回空列表 ====================

Deno.test("detectHabitChains — 空输入返回空列表", () => {
  const chains = detectHabitChains([], NOW);
  assertEquals(chains.length, 0, "空记忆列表应返回空习惯链列表");
});

Deno.test("detectTimeSlotChains — 空输入返回空列表", () => {
  assertEquals(detectTimeSlotChains([], NOW).length, 0);
});

Deno.test("detectWeeklyCycleChains — 空输入返回空列表", () => {
  assertEquals(detectWeeklyCycleChains([], NOW).length, 0);
});

Deno.test("detectPushRecoverChains — 空输入返回空列表", () => {
  assertEquals(detectPushRecoverChains([], NOW).length, 0);
});


// ==================== 2. 不足 5 天的时段数据不触发 time_slot ====================

Deno.test("detectTimeSlotChains — 4 天连续相同时段不触发 time_slot", () => {
  // 4 天连续在 8 点完成任务，不满足 5 天阈值
  const memories = [
    makeMemory("2026-05-01T08:00:00Z"),
    makeMemory("2026-05-02T08:30:00Z"),
    makeMemory("2026-05-03T09:00:00Z"),
    makeMemory("2026-05-04T08:00:00Z"),
  ];
  const chains = detectTimeSlotChains(memories, NOW);
  assertEquals(chains.length, 0, "仅 4 天连续相同时段不应触发 time_slot 链");
});

Deno.test("detectTimeSlotChains — 3 天连续不触发", () => {
  const memories = [
    makeMemory("2026-05-10T10:00:00Z"),
    makeMemory("2026-05-11T11:00:00Z"),
    makeMemory("2026-05-12T10:30:00Z"),
  ];
  const chains = detectTimeSlotChains(memories, NOW);
  assertEquals(chains.length, 0, "仅 3 天连续不应触发 time_slot 链");
});

// ==================== 3. 恰好 5 天的时段数据触发 time_slot ====================

Deno.test("detectTimeSlotChains — 恰好 5 天连续相同时段触发 time_slot", () => {
  // 5 天连续在 8 点附近（±2h）完成任务
  const memories = [
    makeMemory("2026-05-01T08:00:00Z"),
    makeMemory("2026-05-02T09:00:00Z"),
    makeMemory("2026-05-03T08:30:00Z"),
    makeMemory("2026-05-04T07:00:00Z"),
    makeMemory("2026-05-05T09:00:00Z"),
  ];
  const chains = detectTimeSlotChains(memories, NOW);
  assert(chains.length >= 1, "恰好 5 天连续相同时段应触发 time_slot 链");

  const chain = chains[0];
  assertEquals(chain.type, "time_slot");
  assertEquals(chain.consecutiveDays, 5);
  // 置信度 = min(5 / 10, 1.0) = 0.5
  assertEquals(chain.confidence, 0.5);
  assert(chain.description.length > 0, "描述不应为空");
});

Deno.test("detectTimeSlotChains — 5 天连续但时段差超过 2h 不触发", () => {
  // 5 天连续但相邻天的完成小时差 > 2
  const memories = [
    makeMemory("2026-05-01T06:00:00Z"),
    makeMemory("2026-05-02T09:00:00Z"), // 差 3h，超过 ±2h
    makeMemory("2026-05-03T12:00:00Z"),
    makeMemory("2026-05-04T15:00:00Z"),
    makeMemory("2026-05-05T18:00:00Z"),
  ];
  const chains = detectTimeSlotChains(memories, NOW);
  assertEquals(chains.length, 0, "相邻天时段差超过 2h 不应触发 time_slot 链");
});

// ==================== 4. 跨月边界的连续天数计算 ====================

Deno.test("detectTimeSlotChains — 跨月边界连续 5 天触发 time_slot", () => {
  // 4/29, 4/30, 5/1, 5/2, 5/3 连续 5 天
  const memories = [
    makeMemory("2026-04-29T10:00:00Z"),
    makeMemory("2026-04-30T11:00:00Z"),
    makeMemory("2026-05-01T10:30:00Z"),
    makeMemory("2026-05-02T10:00:00Z"),
    makeMemory("2026-05-03T11:00:00Z"),
  ];
  const chains = detectTimeSlotChains(memories, NOW);
  assert(chains.length >= 1, "跨月边界连续 5 天应触发 time_slot 链");
  assertEquals(chains[0].type, "time_slot");
  assertEquals(chains[0].consecutiveDays, 5);
});

Deno.test("detectTimeSlotChains — 跨年边界连续 5 天触发 time_slot", () => {
  // 12/29, 12/30, 12/31, 1/1, 1/2 跨年连续 5 天
  const memories = [
    makeMemory("2025-12-29T14:00:00Z"),
    makeMemory("2025-12-30T15:00:00Z"),
    makeMemory("2025-12-31T14:30:00Z"),
    makeMemory("2026-01-01T14:00:00Z"),
    makeMemory("2026-01-02T15:00:00Z"),
  ];
  const chains = detectTimeSlotChains(memories, new Date("2026-02-01T00:00:00Z"));
  assert(chains.length >= 1, "跨年边界连续 5 天应触发 time_slot 链");
  assertEquals(chains[0].consecutiveDays, 5);
});

// ==================== 5. 缺少 createdAt 的条目被跳过 ====================

Deno.test("detectHabitChains — 缺少 createdAt 的条目被跳过", () => {
  // 混合有效和 null createdAt，有效条目不足 5 天
  const memories = [
    makeMemory("2026-05-01T08:00:00Z"),
    makeMemory(null),                     // 跳过
    makeMemory("2026-05-02T08:30:00Z"),
    makeMemory(null),                     // 跳过
    makeMemory("2026-05-03T09:00:00Z"),
    makeMemory(null),                     // 跳过
    makeMemory("2026-05-04T08:00:00Z"),
  ];
  // 有效条目仅 4 天（5/1, 5/2, 5/3, 5/4），不足 5 天
  const chains = detectTimeSlotChains(memories, NOW);
  assertEquals(chains.length, 0, "null createdAt 条目被跳过后有效天数不足 5 天，不应触发");
});

Deno.test("detectHabitChains — null createdAt 条目不导致异常", () => {
  const memories = [
    makeMemory(null),
    makeMemory(null),
    makeMemory(null),
  ];
  const chains = detectHabitChains(memories, NOW);
  assertEquals(chains.length, 0, "全部 null createdAt 应返回空列表");
});

Deno.test("detectHabitChains — 混合 null 和有效条目，有效条目满足条件时仍触发", () => {
  // 5 天有效 + 3 个 null，有效条目满足 time_slot 条件
  const memories = [
    makeMemory(null),
    makeMemory("2026-05-01T08:00:00Z"),
    makeMemory(null),
    makeMemory("2026-05-02T09:00:00Z"),
    makeMemory("2026-05-03T08:30:00Z"),
    makeMemory(null),
    makeMemory("2026-05-04T07:00:00Z"),
    makeMemory("2026-05-05T09:00:00Z"),
  ];
  const chains = detectTimeSlotChains(memories, NOW);
  assert(chains.length >= 1, "null 条目被跳过后有效条目满足条件应触发 time_slot 链");
});


// ==================== 6. 连续 3 周相同星期几触发 weekly_cycle ====================

Deno.test("detectWeeklyCycleChains — 连续 3 周相同星期几触发 weekly_cycle", () => {
  // 2026-05-04 是周一，连续 3 个周一完成 task_event
  const memories = [
    makeMemory("2026-05-04T12:00:00Z", "task_event"),
    makeMemory("2026-05-11T12:00:00Z", "task_event"),
    makeMemory("2026-05-18T12:00:00Z", "task_event"),
  ];
  const chains = detectWeeklyCycleChains(memories, NOW);
  assert(chains.length >= 1, "连续 3 周相同星期几应触发 weekly_cycle 链");

  const chain = chains[0];
  assertEquals(chain.type, "weekly_cycle");
  // 置信度 = min(3 / 6, 1.0) = 0.5
  assertEquals(chain.confidence, 0.5);
  assert(chain.description.includes("一"), "描述应包含星期几信息");
});

// ==================== 7. 不足 3 周不触发 weekly_cycle ====================

Deno.test("detectWeeklyCycleChains — 仅 2 周不触发 weekly_cycle", () => {
  // 2 个连续周一
  const memories = [
    makeMemory("2026-05-04T12:00:00Z", "task_event"),
    makeMemory("2026-05-11T12:00:00Z", "task_event"),
  ];
  const chains = detectWeeklyCycleChains(memories, NOW);
  assertEquals(chains.length, 0, "仅 2 周连续不应触发 weekly_cycle 链");
});

Deno.test("detectWeeklyCycleChains — 3 周但不连续不触发", () => {
  // 3 个周一但中间跳过一周（5/4, 5/18, 5/25 — 跳过 5/11）
  const memories = [
    makeMemory("2026-05-04T12:00:00Z", "task_event"),
    makeMemory("2026-05-18T12:00:00Z", "task_event"),
    makeMemory("2026-05-25T12:00:00Z", "task_event"),
  ];
  const chains = detectWeeklyCycleChains(memories, NOW);
  // 5/18 和 5/25 是连续 2 周，5/4 和 5/18 跳过了 5/11，所以最长连续仅 2 周
  assertEquals(chains.length, 0, "3 周但不连续不应触发 weekly_cycle 链");
});

// ==================== 8. 3 组推进-恢复配对触发 push_recover ====================

Deno.test("detectPushRecoverChains — 3 组推进-恢复配对触发 push_recover", () => {
  // 3 组高强度任务（task_event）后 24h 内有恢复任务（dialog_event）
  const memories = [
    // 第 1 组
    makeMemory("2026-05-01T10:00:00Z", "task_event"),
    makeMemory("2026-05-01T14:00:00Z", "dialog_event"),
    // 第 2 组
    makeMemory("2026-05-03T10:00:00Z", "task_event"),
    makeMemory("2026-05-03T18:00:00Z", "dialog_event"),
    // 第 3 组
    makeMemory("2026-05-05T10:00:00Z", "task_event"),
    makeMemory("2026-05-05T20:00:00Z", "dialog_event"),
  ];
  const chains = detectPushRecoverChains(memories, NOW);
  assert(chains.length >= 1, "3 组推进-恢复配对应触发 push_recover 链");

  const chain = chains[0];
  assertEquals(chain.type, "push_recover");
  assert(chain.consecutiveDays >= 3, "出现次数应 >= 3");
  // 置信度 = min(3 / 5, 1.0) = 0.6
  assertEquals(chain.confidence, 0.6);
});

Deno.test("detectPushRecoverChains — 不足 3 组不触发", () => {
  // 仅 2 组配对
  const memories = [
    makeMemory("2026-05-01T10:00:00Z", "task_event"),
    makeMemory("2026-05-01T14:00:00Z", "dialog_event"),
    makeMemory("2026-05-03T10:00:00Z", "task_event"),
    makeMemory("2026-05-03T18:00:00Z", "dialog_event"),
  ];
  const chains = detectPushRecoverChains(memories, NOW);
  assertEquals(chains.length, 0, "仅 2 组配对不应触发 push_recover 链");
});

// ==================== 9. 恢复任务超过 24h 不计入配对 ====================

Deno.test("detectPushRecoverChains — 恢复任务超过 24h 不计入配对", () => {
  // 3 组高强度任务，但恢复任务都在 25h 后（超过 24h 窗口）
  const memories = [
    makeMemory("2026-05-01T10:00:00Z", "task_event"),
    makeMemory("2026-05-02T11:01:00Z", "dialog_event"), // 25h01m 后
    makeMemory("2026-05-04T10:00:00Z", "task_event"),
    makeMemory("2026-05-05T11:01:00Z", "dialog_event"), // 25h01m 后
    makeMemory("2026-05-07T10:00:00Z", "task_event"),
    makeMemory("2026-05-08T11:01:00Z", "dialog_event"), // 25h01m 后
  ];
  const chains = detectPushRecoverChains(memories, NOW);
  assertEquals(chains.length, 0, "恢复任务超过 24h 不应计入配对，不应触发 push_recover 链");
});
