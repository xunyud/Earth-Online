// Feature: memory-moat, Property 1: Sender registration idempotence
// Feature: memory-moat, Property 3: Event type to sender mapping
// **Validates: Requirements 1.2, 2.1, 2.2, 2.3, 2.4, 2.5**
//
// 属性测试：
// Property 1 — 多次调用 ensureSendersRegistered 后，每个 sender name 的 createSender 最多被调用 1 次。
// Property 3 — resolveSenderName 对各类 event_type 返回正确的 sender name，且返回值始终在 SENDER_NAMES 中。

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";
import {
  ensureSendersRegistered,
  resolveSenderName,
  SENDER_NAMES,
  senderCache,
} from "../_shared/sender_registry.ts";

// 有效 sender name 集合，用于验证返回值
const VALID_SENDER_SET = new Set<string>(SENDER_NAMES);

// ---------- Property 1: Sender registration idempotence ----------

Deno.test("Property 1: 多次调用 ensureSendersRegistered，每个 sender 的 createSender 最多调用 1 次", async () => {
  await fc.assert(
    fc.asyncProperty(
      // 生成调用次数：1 到 5 次
      fc.integer({ min: 1, max: 5 }),
      async (callCount: number) => {
        // 每次迭代前清空缓存，确保测试隔离
        senderCache.clear();

        // 记录每个 sender name 的 createSender 调用次数
        const callCounts = new Map<string, number>();

        // 构造 mock client，仅实现 createSender 方法
        const mockClient = {
          createSender: async (input: { name: string; metadata?: Record<string, unknown> }) => {
            const current = callCounts.get(input.name) ?? 0;
            callCounts.set(input.name, current + 1);
            return { sender_id: `mock-id-${input.name}`, name: input.name, metadata: {} };
          },
        };

        // 多次调用 ensureSendersRegistered
        for (let i = 0; i < callCount; i++) {
          await ensureSendersRegistered(mockClient);
        }

        // 验证：每个 sender name 的 createSender 最多被调用 1 次
        for (const name of SENDER_NAMES) {
          const count = callCounts.get(name) ?? 0;
          assert(
            count <= 1,
            `sender "${name}" 的 createSender 被调用了 ${count} 次（调用 ensureSendersRegistered ${callCount} 次），期望最多 1 次`,
          );
        }

        // 清理缓存，避免影响后续迭代
        senderCache.clear();
      },
    ),
    { numRuns: 100 },
  );
});

// ---------- Property 3: Event type to sender mapping ----------

Deno.test("Property 3: agent_ 前缀事件映射到 agent-runtime", () => {
  fc.assert(
    fc.property(
      // 生成以 agent_ 开头的随机事件类型
      fc.stringOf(
        fc.constantFrom(..."abcdefghijklmnopqrstuvwxyz0123456789_"),
        { minLength: 1, maxLength: 20 },
      ).map((suffix) => `agent_${suffix}`),
      (eventType: string) => {
        const result = resolveSenderName(eventType);
        assertEquals(result, "agent-runtime",
          `agent_ 前缀事件 "${eventType}" 应映射到 "agent-runtime"，实际得到 "${result}"`);
        assert(VALID_SENDER_SET.has(result), `返回值 "${result}" 不在 SENDER_NAMES 中`);
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 3: patrol_nudge 和 habit_chain_break 映射到 patrol-nudge", () => {
  fc.assert(
    fc.property(
      fc.constantFrom("patrol_nudge", "habit_chain_break"),
      (eventType: string) => {
        const result = resolveSenderName(eventType);
        assertEquals(result, "patrol-nudge",
          `事件 "${eventType}" 应映射到 "patrol-nudge"，实际得到 "${result}"`);
        assert(VALID_SENDER_SET.has(result), `返回值 "${result}" 不在 SENDER_NAMES 中`);
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 3: wechat_message 映射到 wechat-webhook", () => {
  fc.assert(
    fc.property(
      fc.constant("wechat_message"),
      (eventType: string) => {
        const result = resolveSenderName(eventType);
        assertEquals(result, "wechat-webhook",
          `事件 "${eventType}" 应映射到 "wechat-webhook"，实际得到 "${result}"`);
        assert(VALID_SENDER_SET.has(result), `返回值 "${result}" 不在 SENDER_NAMES 中`);
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 3: guide_chat 和 night_reflection 映射到 guide-assistant", () => {
  fc.assert(
    fc.property(
      fc.constantFrom("guide_chat", "night_reflection"),
      (eventType: string) => {
        const result = resolveSenderName(eventType);
        assertEquals(result, "guide-assistant",
          `事件 "${eventType}" 应映射到 "guide-assistant"，实际得到 "${result}"`);
        assert(VALID_SENDER_SET.has(result), `返回值 "${result}" 不在 SENDER_NAMES 中`);
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 3: 未知事件类型映射到 user-manual", () => {
  // 排除所有已知前缀和精确匹配的事件类型
  const isKnownType = (s: string) =>
    s.startsWith("agent_") ||
    s === "patrol_nudge" ||
    s === "habit_chain_break" ||
    s === "wechat_message" ||
    s === "guide_chat" ||
    s === "night_reflection";

  fc.assert(
    fc.property(
      fc.stringOf(
        fc.constantFrom(..."abcdefghijklmnopqrstuvwxyz0123456789_"),
        { minLength: 1, maxLength: 30 },
      ).filter((s) => !isKnownType(s)),
      (eventType: string) => {
        const result = resolveSenderName(eventType);
        assertEquals(result, "user-manual",
          `未知事件 "${eventType}" 应映射到 "user-manual"，实际得到 "${result}"`);
        assert(VALID_SENDER_SET.has(result), `返回值 "${result}" 不在 SENDER_NAMES 中`);
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 3: 返回值始终在 SENDER_NAMES 中（混合随机事件类型）", () => {
  // 混合生成器：包含已知类型和完全随机的未知类型
  const arbEventType = fc.oneof(
    fc.constantFrom("agent_goal", "agent_tool_result", "agent_run_complete"),
    fc.constantFrom("patrol_nudge", "habit_chain_break"),
    fc.constant("wechat_message"),
    fc.constantFrom("guide_chat", "night_reflection"),
    // 完全随机的事件类型字符串
    fc.stringOf(
      fc.constantFrom(..."abcdefghijklmnopqrstuvwxyz0123456789_"),
      { minLength: 0, maxLength: 30 },
    ),
  );

  fc.assert(
    fc.property(arbEventType, (eventType: string) => {
      const result = resolveSenderName(eventType);
      assert(
        VALID_SENDER_SET.has(result),
        `事件 "${eventType}" 的映射结果 "${result}" 不在 SENDER_NAMES 中`,
      );
    }),
    { numRuns: 200 },
  );
});
