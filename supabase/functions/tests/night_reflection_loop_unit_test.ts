// 单元测试：夜间反思记忆闭环
// 覆盖 buildNightReflectionWritePayload 的字段格式、filterReflectionHistory 的过滤与截断逻辑。
// _Requirements: 12.1, 12.3, 12.4, 13.1, 13.2, 13.3_

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { buildNightReflectionWritePayload } from "../_shared/guide_engine.ts";
import { filterReflectionHistory } from "../_shared/guide_memory.ts";

// ==================== 1. buildNightReflectionWritePayload — eventType 为 "night_reflection" ====================

Deno.test("buildNightReflectionWritePayload — eventType 为 night_reflection", () => {
  const payload = buildNightReflectionWritePayload(
    "user-001",
    "今天你完成了 3 个任务",
    "明天有什么计划？",
    "2026-04-25",
  );
  assertEquals(payload.eventType, "night_reflection");
});

// ==================== 2. buildNightReflectionWritePayload — summary 格式为 "<dayId> 夜间反思" ====================

Deno.test("buildNightReflectionWritePayload — summary 格式为 '<dayId> 夜间反思'", () => {
  const payload = buildNightReflectionWritePayload(
    "user-001",
    "开场白",
    "追问",
    "2026-05-01",
  );
  assertEquals(payload.metadata?.summary, "2026-05-01 夜间反思");
});

// ==================== 3. buildNightReflectionWritePayload — content 为 opening + "\n\n" + follow_up_question ====================

Deno.test("buildNightReflectionWritePayload — content 为 opening + '\\n\\n' + follow_up_question", () => {
  const opening = "今天你完成了早起打卡";
  const followUp = "你觉得明天能继续吗？";
  const payload = buildNightReflectionWritePayload(
    "user-001",
    opening,
    followUp,
    "2026-04-25",
  );
  assertEquals(payload.content, `${opening}\n\n${followUp}`);
});

// ==================== 4. buildNightReflectionWritePayload — sender 为 "guide-assistant" ====================

Deno.test("buildNightReflectionWritePayload — sender 为 guide-assistant", () => {
  const payload = buildNightReflectionWritePayload(
    "user-001",
    "开场白",
    "追问",
    "2026-04-25",
  );
  assertEquals(payload.sender, "guide-assistant");
});

// ==================== 5. buildNightReflectionWritePayload — memoryKind 为 "dialog_event" ====================

Deno.test("buildNightReflectionWritePayload — memoryKind 为 dialog_event", () => {
  const payload = buildNightReflectionWritePayload(
    "user-001",
    "开场白",
    "追问",
    "2026-04-25",
  );
  assertEquals(payload.metadata?.memoryKind, "dialog_event");
});

// ==================== 6. filterReflectionHistory — 正常输入返回最多 3 条匹配文本 ====================

Deno.test("filterReflectionHistory — 正常输入返回最多 3 条匹配文本", () => {
  const items = [
    { content: "eventType=night_reflection | 第一条反思" },
    { content: "eventType=night_reflection | 第二条反思" },
    { content: "eventType=night_reflection | 第三条反思" },
  ];
  const result = filterReflectionHistory(items);
  assertEquals(result.length, 3);
  // 每条结果都应包含 night_reflection
  for (const text of result) {
    assert(text.includes("night_reflection"), `结果应包含 night_reflection: ${text}`);
  }
});

// ==================== 7. filterReflectionHistory — 空输入返回空列表 ====================

Deno.test("filterReflectionHistory — 空输入返回空列表", () => {
  const result = filterReflectionHistory([]);
  assertEquals(result.length, 0);
});

// ==================== 8. filterReflectionHistory — 不含 night_reflection 的条目被排除 ====================

Deno.test("filterReflectionHistory — 不含 night_reflection 的条目被排除", () => {
  const items = [
    { content: "eventType=task_complete | 完成了跑步" },
    { content: "eventType=night_reflection | 今天的反思" },
    { content: "eventType=guide_chat | 普通对话" },
    "一条纯字符串记忆，不含关键词",
  ];
  const result = filterReflectionHistory(items);
  assertEquals(result.length, 1);
  assert(result[0].includes("night_reflection"), "唯一结果应包含 night_reflection");
});

// ==================== 9. filterReflectionHistory — 超过 3 条匹配时截断为 3 条 ====================

Deno.test("filterReflectionHistory — 超过 3 条匹配时截断为 3 条", () => {
  const items = [
    { content: "eventType=night_reflection | 反思1" },
    { content: "eventType=night_reflection | 反思2" },
    { content: "eventType=night_reflection | 反思3" },
    { content: "eventType=night_reflection | 反思4" },
    { content: "eventType=night_reflection | 反思5" },
  ];
  const result = filterReflectionHistory(items);
  assertEquals(result.length, 3, "超过 3 条匹配时应截断为 3 条");
  // 应保留前 3 条（输入已按时间倒序排列，取最近的 3 条）
  assert(result[0].includes("反思1"), "第一条应为输入中的第一条");
  assert(result[1].includes("反思2"), "第二条应为输入中的第二条");
  assert(result[2].includes("反思3"), "第三条应为输入中的第三条");
});

// ==================== 补充：filterReflectionHistory — 字符串类型输入也能正确过滤 ====================

Deno.test("filterReflectionHistory — 字符串类型输入也能正确过滤", () => {
  const items: Array<Record<string, unknown> | string> = [
    "eventType=night_reflection | 字符串形式的反思",
    "普通字符串，不含关键词",
    "另一条 night_reflection 记录",
  ];
  const result = filterReflectionHistory(items);
  assertEquals(result.length, 2, "应匹配 2 条含 night_reflection 的字符串");
});

// ==================== 补充：buildNightReflectionWritePayload — userId 正确传递 ====================

Deno.test("buildNightReflectionWritePayload — userId 正确传递", () => {
  const payload = buildNightReflectionWritePayload(
    "test-user-xyz",
    "开场白",
    "追问",
    "2026-04-25",
  );
  assertEquals(payload.userId, "test-user-xyz");
});

// ==================== 补充：buildNightReflectionWritePayload — sourceStatus 为 active ====================

Deno.test("buildNightReflectionWritePayload — sourceStatus 为 active", () => {
  const payload = buildNightReflectionWritePayload(
    "user-001",
    "开场白",
    "追问",
    "2026-04-25",
  );
  assertEquals(payload.metadata?.sourceStatus, "active");
});
