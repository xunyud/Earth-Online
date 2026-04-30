// 单元测试：个性化每日事件生成
// 覆盖 extractBehaviorSummary、shouldUseFallback 和 generateDailyEvent 的降级逻辑。
// _Requirements: 16.1, 16.2, 16.3_

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import {
  buildEventFallback,
  extractBehaviorSummary,
  generateDailyEvent,
  shouldUseFallback,
} from "../_shared/guide_ai.ts";
import type { GuideMemoryBundle } from "../_shared/guide_memory.ts";

/** 构建测试用 GuideMemoryBundle */
function buildMemoryBundle(
  overrides: Partial<GuideMemoryBundle> = {},
): GuideMemoryBundle {
  return {
    recent_context: [],
    long_term_callbacks: [],
    behavior_signals: [],
    agentic_memory_lines: [],
    memory_refs: [],
    memory_digest: "",
    packed_context: "",
    ...overrides,
  };
}

// ==================== 1. extractBehaviorSummary — 正常提取行为信号 ====================

Deno.test("extractBehaviorSummary — 从标准 packed_context 中提取行为信号摘要", () => {
  const packed = [
    "【当前事实】",
    "1. 今天完成了 3 项任务",
    "",
    "【历史回调】",
    "1. 长期习惯记录",
    "",
    "【行为信号】",
    "1. 连续推进 5 天",
    "2. 夜间活跃度偏高",
    "3. 恢复型任务占比上升",
  ].join("\n");

  const summary = extractBehaviorSummary(packed);
  assert(summary.includes("连续推进 5 天"), "应包含第一条信号");
  assert(summary.includes("夜间活跃度偏高"), "应包含第二条信号");
  assert(summary.includes("恢复型任务占比上升"), "应包含第三条信号");
  // 验证用分号连接
  assert(summary.includes("；"), "信号之间应用分号连接");
});

// ==================== 2. extractBehaviorSummary — 空 packed_context ====================

Deno.test("extractBehaviorSummary — 空字符串返回空", () => {
  assertEquals(extractBehaviorSummary(""), "");
});

// ==================== 3. extractBehaviorSummary — 无行为信号区域 ====================

Deno.test("extractBehaviorSummary — 不含行为信号区域时返回空", () => {
  const packed = "【当前事实】\n1. 今天完成了任务\n\n【历史回调】\n1. 长期记录";
  assertEquals(extractBehaviorSummary(packed), "");
});

// ==================== 4. extractBehaviorSummary — 行为信号区域为空行 ====================

Deno.test("extractBehaviorSummary — 行为信号区域仅含空行时返回空", () => {
  const packed = "【当前事实】\n1. 任务\n\n【行为信号】\n\n";
  assertEquals(extractBehaviorSummary(packed), "");
});

// ==================== 5. shouldUseFallback — 阈值边界测试 ====================

Deno.test("shouldUseFallback — count=0 返回 true", () => {
  assertEquals(shouldUseFallback(0), true);
});

Deno.test("shouldUseFallback — count=2 返回 true", () => {
  assertEquals(shouldUseFallback(2), true);
});

Deno.test("shouldUseFallback — count=3 返回 false（恰好达到阈值）", () => {
  assertEquals(shouldUseFallback(3), false);
});

Deno.test("shouldUseFallback — count=10 返回 false", () => {
  assertEquals(shouldUseFallback(10), false);
});

// ==================== 6. generateDailyEvent — 记忆不足时降级为 fallback ====================

Deno.test("generateDailyEvent — 记忆不足 3 条时降级为 fallback", async () => {
  // 构建只有 2 条 recent_context 的 bundle（不足 3 条）
  const memory = buildMemoryBundle({
    recent_context: ["任务1", "任务2"],
    behavior_signals: ["连续推进"],
    packed_context: "【当前事实】\n1. 任务1\n2. 任务2\n\n【行为信号】\n1. 连续推进",
  });

  const result = await generateDailyEvent(memory);
  const fallback = buildEventFallback(memory);

  // 降级时应返回 fallback 结果
  assertEquals(result.title, fallback.title);
  assertEquals(result.description, fallback.description);
  assertEquals(result.reward_xp, fallback.reward_xp);
  assertEquals(result.reward_gold, fallback.reward_gold);
});

// ==================== 7. generateDailyEvent — 记忆为空时降级 ====================

Deno.test("generateDailyEvent — 记忆为空时降级为 fallback", async () => {
  const memory = buildMemoryBundle({
    recent_context: [],
    packed_context: "",
  });

  const result = await generateDailyEvent(memory);
  const fallback = buildEventFallback(memory);

  assertEquals(result.title, fallback.title);
  assertEquals(result.description, fallback.description);
});

// ==================== 8. extractBehaviorSummary — 单条行为信号 ====================

Deno.test("extractBehaviorSummary — 单条行为信号正确提取", () => {
  const packed = "【行为信号】\n1. 连续推进 3 天";
  const summary = extractBehaviorSummary(packed);
  assertEquals(summary, "连续推进 3 天");
});

// ==================== 9. extractBehaviorSummary — 含习惯链信号 ====================

Deno.test("extractBehaviorSummary — 含习惯链信号时正确提取", () => {
  const packed = [
    "【当前事实】",
    "1. 今天完成了任务",
    "",
    "【行为信号】",
    "1. 连续推进 5 天",
    "2. habit_chain: 每天早上 8 点完成任务（连续7天，置信度85%）",
  ].join("\n");

  const summary = extractBehaviorSummary(packed);
  assert(summary.includes("连续推进 5 天"), "应包含普通信号");
  assert(summary.includes("habit_chain"), "应包含习惯链信号");
});

// ==================== 10. extractBehaviorSummary — 行为信号在末尾（无后续区域） ====================

Deno.test("extractBehaviorSummary — 行为信号在 packed_context 末尾时正确提取", () => {
  const packed = "【行为信号】\n1. 稳定推进\n2. 清盘率高";
  const summary = extractBehaviorSummary(packed);
  assert(summary.includes("稳定推进"), "应包含第一条信号");
  assert(summary.includes("清盘率高"), "应包含第二条信号");
});
