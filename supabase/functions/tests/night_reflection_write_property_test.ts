// Feature: memory-moat, Property 15: Night reflection memory write format
// **Validates: Requirements 12.1, 12.3**
//
// 属性测试：验证夜间反思记忆写入载荷的格式正确性。
// 使用 fast-check 生成随机 opening、follow_up_question、dayId（YYYY-MM-DD 格式），
// 验证写入记忆的 eventType、memoryKind、content、summary、sender 格式正确。

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";
import { buildNightReflectionWritePayload } from "../_shared/guide_engine.ts";

// ---------- 生成器 ----------

/** 生成非空随机文本，模拟 opening 或 follow_up_question */
const arbNonEmptyText: fc.Arbitrary<string> = fc.string({
  minLength: 1,
  maxLength: 200,
});

/** 生成 YYYY-MM-DD 格式的 dayId */
const arbDayId: fc.Arbitrary<string> = fc
  .record({
    year: fc.integer({ min: 2020, max: 2030 }),
    month: fc.integer({ min: 1, max: 12 }),
    day: fc.integer({ min: 1, max: 28 }), // 使用 28 避免无效日期
  })
  .map(({ year, month, day }) => {
    const mm = String(month).padStart(2, "0");
    const dd = String(day).padStart(2, "0");
    return `${year}-${mm}-${dd}`;
  });

/** 生成随机 userId */
const arbUserId: fc.Arbitrary<string> = fc.string({
  minLength: 1,
  maxLength: 50,
});

// ---------- Property 15: Night reflection memory write format ----------

// Feature: memory-moat, Property 15: Night reflection memory write format
Deno.test("Property 15: eventType 始终为 night_reflection", () => {
  fc.assert(
    fc.property(
      arbUserId,
      arbNonEmptyText,
      arbNonEmptyText,
      arbDayId,
      (userId: string, opening: string, followUp: string, dayId: string) => {
        const payload = buildNightReflectionWritePayload(
          userId,
          opening,
          followUp,
          dayId,
        );
        assertEquals(
          payload.eventType,
          "night_reflection",
          `eventType 应为 "night_reflection"，实际为 "${payload.eventType}"`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 15: Night reflection memory write format
Deno.test("Property 15: content 包含 opening 和 follow_up_question 且以 \\n\\n 分隔", () => {
  fc.assert(
    fc.property(
      arbUserId,
      arbNonEmptyText,
      arbNonEmptyText,
      arbDayId,
      (userId: string, opening: string, followUp: string, dayId: string) => {
        const payload = buildNightReflectionWritePayload(
          userId,
          opening,
          followUp,
          dayId,
        );

        // content 应为 opening + "\n\n" + follow_up_question
        const expected = `${opening}\n\n${followUp}`;
        assertEquals(
          payload.content,
          expected,
          "content 应为 opening + '\\n\\n' + follow_up_question",
        );

        // content 必须包含 opening 和 follow_up_question
        assert(
          payload.content.includes(opening),
          `content 应包含 opening "${opening}"`,
        );
        assert(
          payload.content.includes(followUp),
          `content 应包含 follow_up_question "${followUp}"`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 15: Night reflection memory write format
Deno.test("Property 15: summary 匹配 '<dayId> 夜间反思' 格式", () => {
  fc.assert(
    fc.property(
      arbUserId,
      arbNonEmptyText,
      arbNonEmptyText,
      arbDayId,
      (userId: string, opening: string, followUp: string, dayId: string) => {
        const payload = buildNightReflectionWritePayload(
          userId,
          opening,
          followUp,
          dayId,
        );

        const expectedSummary = `${dayId} 夜间反思`;
        assertEquals(
          payload.metadata?.summary,
          expectedSummary,
          `summary 应为 "${expectedSummary}"，实际为 "${payload.metadata?.summary}"`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 15: Night reflection memory write format
Deno.test("Property 15: memoryKind 始终为 dialog_event", () => {
  fc.assert(
    fc.property(
      arbUserId,
      arbNonEmptyText,
      arbNonEmptyText,
      arbDayId,
      (userId: string, opening: string, followUp: string, dayId: string) => {
        const payload = buildNightReflectionWritePayload(
          userId,
          opening,
          followUp,
          dayId,
        );
        assertEquals(
          payload.metadata?.memoryKind,
          "dialog_event",
          `memoryKind 应为 "dialog_event"，实际为 "${payload.metadata?.memoryKind}"`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 15: Night reflection memory write format
Deno.test("Property 15: sender 始终为 guide-assistant", () => {
  fc.assert(
    fc.property(
      arbUserId,
      arbNonEmptyText,
      arbNonEmptyText,
      arbDayId,
      (userId: string, opening: string, followUp: string, dayId: string) => {
        const payload = buildNightReflectionWritePayload(
          userId,
          opening,
          followUp,
          dayId,
        );
        assertEquals(
          payload.sender,
          "guide-assistant",
          `sender 应为 "guide-assistant"，实际为 "${payload.sender}"`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 15: Night reflection memory write format
Deno.test("Property 15: sourceStatus 始终为 active", () => {
  fc.assert(
    fc.property(
      arbUserId,
      arbNonEmptyText,
      arbNonEmptyText,
      arbDayId,
      (userId: string, opening: string, followUp: string, dayId: string) => {
        const payload = buildNightReflectionWritePayload(
          userId,
          opening,
          followUp,
          dayId,
        );
        assertEquals(
          payload.metadata?.sourceStatus,
          "active",
          `sourceStatus 应为 "active"，实际为 "${payload.metadata?.sourceStatus}"`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 15: Night reflection memory write format
Deno.test("Property 15: userId 正确传递", () => {
  fc.assert(
    fc.property(
      arbUserId,
      arbNonEmptyText,
      arbNonEmptyText,
      arbDayId,
      (userId: string, opening: string, followUp: string, dayId: string) => {
        const payload = buildNightReflectionWritePayload(
          userId,
          opening,
          followUp,
          dayId,
        );
        assertEquals(
          payload.userId,
          userId,
          `userId 应正确传递，期望 "${userId}"，实际为 "${payload.userId}"`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 15: Night reflection memory write format
// 综合验证：随机输入下所有字段同时满足格式要求
Deno.test("Property 15: 综合验证所有字段格式", () => {
  fc.assert(
    fc.property(
      arbUserId,
      arbNonEmptyText,
      arbNonEmptyText,
      arbDayId,
      (userId: string, opening: string, followUp: string, dayId: string) => {
        const payload = buildNightReflectionWritePayload(
          userId,
          opening,
          followUp,
          dayId,
        );

        // 所有字段同时验证
        assertEquals(payload.eventType, "night_reflection");
        assertEquals(payload.content, `${opening}\n\n${followUp}`);
        assertEquals(payload.metadata?.summary, `${dayId} 夜间反思`);
        assertEquals(payload.metadata?.memoryKind, "dialog_event");
        assertEquals(payload.metadata?.sourceStatus, "active");
        assertEquals(payload.sender, "guide-assistant");
        assertEquals(payload.userId, userId);

        // dayId 格式验证：summary 中的日期部分匹配 YYYY-MM-DD
        const summaryDateMatch = payload.metadata?.summary?.match(
          /^(\d{4}-\d{2}-\d{2}) 夜间反思$/,
        );
        assert(
          summaryDateMatch !== null,
          `summary 应匹配 "YYYY-MM-DD 夜间反思" 格式，实际为 "${payload.metadata?.summary}"`,
        );
        assertEquals(
          summaryDateMatch![1],
          dayId,
          "summary 中的日期应与 dayId 一致",
        );
      },
    ),
    { numRuns: 100 },
  );
});
