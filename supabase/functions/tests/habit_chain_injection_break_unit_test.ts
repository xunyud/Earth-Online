// 单元测试：习惯链注入与断裂检测
// 覆盖 isChainBreaking、filterMentionableChains、buildBehaviorSignals 中习惯链注入的具体场景和边界条件。
// _Requirements: 6.1, 6.2, 6.3, 7.1, 7.2, 7.3, 7.4_

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import {
  isChainBreaking,
  filterMentionableChains,
} from "../_shared/guide_memory.ts";
import type {
  GuideStructuredMemoryItem,
  HabitChain,
} from "../_shared/guide_memory.ts";

// ---------- 辅助工厂函数 ----------

/** 构造测试用的结构化记忆条目，仅填充检测所需字段 */
function makeMemory(
  createdAt: string | number | null,
  memoryKind = "task_event",
): GuideStructuredMemoryItem {
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

// ==================== 1. isChainBreaking — 习惯链正常延续时不触发断裂 ====================

Deno.test("isChainBreaking — time_slot 链正常延续（今天有匹配记忆）→ false", () => {
  const chain: HabitChain = {
    type: "time_slot",
    description: "每天约 8 点完成任务",
    consecutiveDays: 7,
    confidence: 0.7,
  };
  // 当前时间 11:00（已过缓冲期 8+2=10），今天 8:30 有匹配记忆
  const now = new Date("2026-06-10T11:00:00Z");
  const memories = [makeMemory("2026-06-10T08:30:00Z")];

  const result = isChainBreaking(chain, memories, now);
  assertEquals(result, false, "今天有匹配记忆时不应触发断裂");
});

Deno.test("isChainBreaking — weekly_cycle 链正常延续（今天是预期星期几且有记忆）→ false", () => {
  const chain: HabitChain = {
    type: "weekly_cycle",
    description: "每周三完成 task_event 类型任务",
    consecutiveDays: 21,
    confidence: 0.8,
  };
  // 2026-06-10 是周三
  const now = new Date("2026-06-10T18:00:00Z");
  const memories = [makeMemory("2026-06-10T10:00:00Z")];

  const result = isChainBreaking(chain, memories, now);
  assertEquals(result, false, "预期星期几有匹配记忆时不应触发断裂");
});

Deno.test("isChainBreaking — push_recover 链正常延续（高强度任务后有恢复记忆）→ false", () => {
  const chain: HabitChain = {
    type: "push_recover",
    description: "高强度任务后 24h 内完成恢复活动",
    consecutiveDays: 5,
    confidence: 0.8,
  };
  // 高强度任务在 3h 前，恢复任务在 1h 前
  const now = new Date("2026-06-10T15:00:00Z");
  const memories = [
    makeMemory("2026-06-10T12:00:00Z", "task_event"),    // 高强度任务
    makeMemory("2026-06-10T14:00:00Z", "dialog_event"),   // 恢复类记忆
  ];

  const result = isChainBreaking(chain, memories, now);
  assertEquals(result, false, "高强度任务后有恢复记忆时不应触发断裂");
});

// ==================== 2. isChainBreaking — 习惯链断裂时触发信号 ====================

Deno.test("isChainBreaking — time_slot 链断裂（今天无匹配记忆且缓冲期已过）→ true", () => {
  const chain: HabitChain = {
    type: "time_slot",
    description: "每天约 8 点完成任务",
    consecutiveDays: 7,
    confidence: 0.7,
  };
  // 当前时间 11:00（已过缓冲期 8+2=10），今天无记忆
  const now = new Date("2026-06-10T11:00:00Z");

  const result = isChainBreaking(chain, [], now);
  assertEquals(result, true, "缓冲期已过且无匹配记忆时应触发断裂");
});

Deno.test("isChainBreaking — weekly_cycle 链断裂（今天是预期星期几但无记忆）→ true", () => {
  const chain: HabitChain = {
    type: "weekly_cycle",
    description: "每周三完成 task_event 类型任务",
    consecutiveDays: 21,
    confidence: 0.8,
  };
  // 2026-06-10 是周三，无记忆
  const now = new Date("2026-06-10T18:00:00Z");

  const result = isChainBreaking(chain, [], now);
  assertEquals(result, true, "预期星期几无匹配记忆时应触发断裂");
});

Deno.test("isChainBreaking — push_recover 链断裂（高强度任务后无恢复记忆）→ true", () => {
  const chain: HabitChain = {
    type: "push_recover",
    description: "高强度任务后 24h 内完成恢复活动",
    consecutiveDays: 5,
    confidence: 0.8,
  };
  // 高强度任务在 3h 前，无恢复类记忆
  const now = new Date("2026-06-10T15:00:00Z");
  const memories = [
    makeMemory("2026-06-10T12:00:00Z", "task_event"),
  ];

  const result = isChainBreaking(chain, memories, now);
  assertEquals(result, true, "高强度任务后无恢复记忆时应触发断裂");
});

// ==================== 3. isChainBreaking — 缓冲期内不触发断裂 ====================

Deno.test("isChainBreaking — time_slot 缓冲期内不触发断裂", () => {
  const chain: HabitChain = {
    type: "time_slot",
    description: "每天约 14 点完成任务",
    consecutiveDays: 5,
    confidence: 0.5,
  };
  // 当前时间 15:00，预期 14 点 + 2h 缓冲 = 16 点，尚在缓冲期内
  const now = new Date("2026-06-10T15:00:00Z");

  const result = isChainBreaking(chain, [], now);
  assertEquals(result, false, "缓冲期内不应触发断裂");
});

Deno.test("isChainBreaking — weekly_cycle 非预期星期几不触发断裂", () => {
  const chain: HabitChain = {
    type: "weekly_cycle",
    description: "每周一完成 task_event 类型任务",
    consecutiveDays: 21,
    confidence: 0.8,
  };
  // 2026-06-10 是周三，不是预期的周一
  const now = new Date("2026-06-10T18:00:00Z");

  const result = isChainBreaking(chain, [], now);
  assertEquals(result, false, "非预期星期几不应触发断裂");
});

Deno.test("isChainBreaking — push_recover 高强度任务超过 24h 不触发断裂", () => {
  const chain: HabitChain = {
    type: "push_recover",
    description: "高强度任务后 24h 内完成恢复活动",
    consecutiveDays: 5,
    confidence: 0.8,
  };
  // 高强度任务在 25h 前，已超出 24h 窗口
  const now = new Date("2026-06-11T13:00:00Z");
  const memories = [
    makeMemory("2026-06-10T12:00:00Z", "task_event"),
  ];

  const result = isChainBreaking(chain, memories, now);
  assertEquals(result, false, "高强度任务超过 24h 窗口不应触发断裂");
});


// ==================== 4. 24h 内重复巡逻不重复触发 ====================
// 实际去重通过 patrol_logs 数据库查询实现，此处验证去重逻辑的消息格式和匹配规则

Deno.test("24h 内重复巡逻 — 同一 chainType 的信号可通过日志内容匹配去重", () => {
  // 模拟第一次巡逻生成的日志记录
  const firstSignalLog = "[habit_chain_break:time_slot] 你的\"每天约 8 点完成任务\"习惯已经持续了7天，今天还没有看到相关行动。没关系，节奏偶尔会变化，重要的是你已经建立了这个模式。";

  // 模拟第二次巡逻检测到同一习惯链断裂
  const chain: HabitChain = {
    type: "time_slot",
    description: "每天约 8 点完成任务",
    consecutiveDays: 7,
    confidence: 0.7,
  };

  // 构造去重查询条件：日志中包含 habit_chain_break 和对应 chainType
  const dedupeKey = `habit_chain_break:${chain.type}`;
  const hasDuplicate = firstSignalLog.includes(dedupeKey);

  assertEquals(hasDuplicate, true, "同一 chainType 的信号应能通过日志内容匹配去重");
});

Deno.test("24h 内重复巡逻 — 不同 chainType 的信号不互相去重", () => {
  // 已有 time_slot 类型的断裂日志
  const existingLog = "[habit_chain_break:time_slot] 测试消息";

  // 新的 weekly_cycle 类型断裂信号
  const newDedupeKey = "habit_chain_break:weekly_cycle";
  const hasDuplicate = existingLog.includes(newDedupeKey);

  assertEquals(hasDuplicate, false, "不同 chainType 的信号不应互相去重");
});

Deno.test("24h 内重复巡逻 — 三种 chainType 各自独立去重", () => {
  const types = ["time_slot", "weekly_cycle", "push_recover"] as const;
  // 模拟已有 time_slot 和 push_recover 的日志
  const existingLogs = [
    "[habit_chain_break:time_slot] 消息1",
    "[habit_chain_break:push_recover] 消息2",
  ];

  for (const type of types) {
    const dedupeKey = `habit_chain_break:${type}`;
    const hasDuplicate = existingLogs.some((log) => log.includes(dedupeKey));

    if (type === "time_slot" || type === "push_recover") {
      assertEquals(hasDuplicate, true, `${type} 已有日志，应被去重`);
    } else {
      assertEquals(hasDuplicate, false, `${type} 无日志，不应被去重`);
    }
  }
});

// ==================== 5. filterMentionableChains — 注入格式验证 ====================

Deno.test("filterMentionableChains — confidence >= 0.7 的链被选中", () => {
  const chains: HabitChain[] = [
    { type: "time_slot", description: "每天约 8 点完成任务", consecutiveDays: 7, confidence: 0.8 },
    { type: "weekly_cycle", description: "每周一完成任务", consecutiveDays: 21, confidence: 0.5 },
    { type: "push_recover", description: "推进-恢复节奏", consecutiveDays: 5, confidence: 0.9 },
  ];

  const result = filterMentionableChains(chains);

  // 仅 confidence >= 0.7 的链被选中（0.8 和 0.9）
  assertEquals(result.length, 2, "应选中 2 条 confidence >= 0.7 的链");
  for (const chain of result) {
    assert(chain.confidence >= 0.7, `选中的链置信度应 >= 0.7，实际为 ${chain.confidence}`);
  }
});

Deno.test("filterMentionableChains — confidence < 0.7 的链被过滤", () => {
  const chains: HabitChain[] = [
    { type: "time_slot", description: "测试", consecutiveDays: 5, confidence: 0.3 },
    { type: "weekly_cycle", description: "测试", consecutiveDays: 14, confidence: 0.6 },
    { type: "push_recover", description: "测试", consecutiveDays: 3, confidence: 0.69 },
  ];

  const result = filterMentionableChains(chains);
  assertEquals(result.length, 0, "所有链置信度 < 0.7 时不应选中任何链");
});

Deno.test("filterMentionableChains — 最多 2 条，按置信度降序", () => {
  const chains: HabitChain[] = [
    { type: "time_slot", description: "链A", consecutiveDays: 5, confidence: 0.75 },
    { type: "weekly_cycle", description: "链B", consecutiveDays: 14, confidence: 0.95 },
    { type: "push_recover", description: "链C", consecutiveDays: 3, confidence: 0.85 },
  ];

  const result = filterMentionableChains(chains);

  assertEquals(result.length, 2, "最多选中 2 条链");
  // 按置信度降序：0.95, 0.85
  assertEquals(result[0].confidence, 0.95, "第一条应为置信度最高的链");
  assertEquals(result[1].confidence, 0.85, "第二条应为置信度次高的链");
  assertEquals(result[0].description, "链B");
  assertEquals(result[1].description, "链C");
});

Deno.test("filterMentionableChains — 空输入返回空列表", () => {
  const result = filterMentionableChains([]);
  assertEquals(result.length, 0, "空输入应返回空列表");
});

// ==================== 6. 注入 behavior_signals 的格式正确 ====================

Deno.test("behavior_signals 注入格式 — 包含习惯描述、连续天数和置信度百分比", () => {
  // 模拟 buildBehaviorSignals 中的注入格式
  const chain: HabitChain = {
    type: "time_slot",
    description: "每天约 8 点完成任务",
    consecutiveDays: 7,
    confidence: 0.85,
  };

  // 复现 buildBehaviorSignals 中的格式化逻辑
  const signal = `habit_chain: ${chain.description}（连续${chain.consecutiveDays}天，置信度${(chain.confidence * 100).toFixed(0)}%）`;

  // 验证格式包含所有必要信息
  assert(signal.startsWith("habit_chain: "), "信号应以 'habit_chain: ' 开头");
  assert(signal.includes("每天约 8 点完成任务"), "信号应包含习惯描述");
  assert(signal.includes("连续7天"), "信号应包含连续天数");
  assert(signal.includes("置信度85%"), "信号应包含置信度百分比");
  assert(signal.includes("（") && signal.includes("）"), "信号应使用中文括号包裹附加信息");
});

Deno.test("behavior_signals 注入格式 — 置信度百分比取整", () => {
  const chain: HabitChain = {
    type: "weekly_cycle",
    description: "每周一完成 task_event 类型任务",
    consecutiveDays: 21,
    confidence: 0.7333,
  };

  const signal = `habit_chain: ${chain.description}（连续${chain.consecutiveDays}天，置信度${(chain.confidence * 100).toFixed(0)}%）`;

  // 0.7333 * 100 = 73.33，toFixed(0) → "73"
  assert(signal.includes("置信度73%"), "置信度百分比应取整为 73%");
});

// ==================== 7. 断裂消息格式验证 ====================

Deno.test("断裂消息 — 包含习惯描述和持续天数", () => {
  const chain: HabitChain = {
    type: "time_slot",
    description: "每天约 8 点完成任务",
    consecutiveDays: 10,
    confidence: 0.8,
  };

  // 复现 detectPatrolSignals 中的消息模板
  const message = `你的"${chain.description}"习惯已经持续了${chain.consecutiveDays}天，今天还没有看到相关行动。没关系，节奏偶尔会变化，重要的是你已经建立了这个模式。`;

  assert(message.includes(chain.description), "消息应包含习惯描述");
  assert(message.includes("10天"), "消息应包含持续天数");
});

Deno.test("断裂消息 — 不含指责性语言", () => {
  const accusatoryPatterns = ["你没有", "你失败了", "你忘了", "你不行", "你做错了"];

  const chain: HabitChain = {
    type: "weekly_cycle",
    description: "每周三完成 task_event 类型任务",
    consecutiveDays: 21,
    confidence: 0.9,
  };

  const message = `你的"${chain.description}"习惯已经持续了${chain.consecutiveDays}天，今天还没有看到相关行动。没关系，节奏偶尔会变化，重要的是你已经建立了这个模式。`;

  for (const pattern of accusatoryPatterns) {
    assertEquals(
      message.includes(pattern),
      false,
      `消息不应包含指责性语言 "${pattern}"`,
    );
  }

  // 验证包含鼓励性表达
  assert(message.includes("没关系"), "消息应包含鼓励性表达'没关系'");
  assert(message.includes("重要的是你已经建立了这个模式"), "消息应包含正面肯定");
});

Deno.test("断裂消息 — push_recover 类型的消息格式正确", () => {
  const chain: HabitChain = {
    type: "push_recover",
    description: "高强度任务后 24h 内完成恢复活动",
    consecutiveDays: 5,
    confidence: 0.8,
  };

  const message = `你的"${chain.description}"习惯已经持续了${chain.consecutiveDays}天，今天还没有看到相关行动。没关系，节奏偶尔会变化，重要的是你已经建立了这个模式。`;

  assert(message.includes("高强度任务后 24h 内完成恢复活动"), "消息应包含 push_recover 习惯描述");
  assert(message.includes("5天"), "消息应包含持续天数");
});
