// Feature: memory-moat, Property 2: Envelope sender round-trip
// **Validates: Requirements 2.6, 4.3, 11.3**
//
// 属性测试：验证 buildSmartMemoryEnvelope → parseSmartMemoryEnvelope 的 round-trip 正确性。
// 对任意有效 sender name 和 pinned boolean，构建信封后解析应恢复原值。
// 使用 fast-check 从五个有效 sender name 中随机选取，配合随机 pinned 布尔值。

import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";
import {
  buildSmartMemoryEnvelope,
  parseSmartMemoryEnvelope,
} from "../_shared/evermemos_client.ts";

// 五个有效的 sender name，与设计文档定义一致
const VALID_SENDER_NAMES = [
  "user-manual",
  "guide-assistant",
  "agent-runtime",
  "patrol-nudge",
  "wechat-webhook",
] as const;

Deno.test("Property 2: sender name round-trip — build 后 parse 恢复原始 sender", () => {
  fc.assert(
    fc.property(
      // 从五个有效值中随机选取 sender name
      fc.constantFrom(...VALID_SENDER_NAMES),
      // 生成随机内容文本（非空）
      fc.string({ minLength: 1, maxLength: 200 }),
      (sender: string, content: string) => {
        const envelope = buildSmartMemoryEnvelope({
          userId: "test-user",
          eventType: "test_event",
          content,
          sender,
        });

        const parsed = parseSmartMemoryEnvelope(envelope);
        assertExists(parsed, "解析结果不应为 null");
        assertEquals(
          parsed.sender,
          sender,
          `sender round-trip 失败：输入 "${sender}"，解析得到 "${parsed.sender}"`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 2: pinned boolean round-trip — build 后 parse 恢复原始 pinned 值", () => {
  fc.assert(
    fc.property(
      // 随机 pinned 布尔值
      fc.boolean(),
      fc.string({ minLength: 1, maxLength: 200 }),
      (pinned: boolean, content: string) => {
        const envelope = buildSmartMemoryEnvelope({
          userId: "test-user",
          eventType: "test_event",
          content,
          pinned,
        });

        const parsed = parseSmartMemoryEnvelope(envelope);
        assertExists(parsed, "解析结果不应为 null");
        assertEquals(
          parsed.pinned,
          pinned,
          `pinned round-trip 失败：输入 ${pinned}，解析得到 ${parsed.pinned}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 2: sender + pinned 联合 round-trip — 两个字段同时保持一致", () => {
  fc.assert(
    fc.property(
      fc.constantFrom(...VALID_SENDER_NAMES),
      fc.boolean(),
      fc.string({ minLength: 1, maxLength: 200 }),
      (sender: string, pinned: boolean, content: string) => {
        const envelope = buildSmartMemoryEnvelope({
          userId: "test-user",
          eventType: "test_event",
          content,
          sender,
          pinned,
        });

        const parsed = parseSmartMemoryEnvelope(envelope);
        assertExists(parsed, "解析结果不应为 null");
        assertEquals(
          parsed.sender,
          sender,
          `联合测试 sender 不匹配：输入 "${sender}"，得到 "${parsed.sender}"`,
        );
        assertEquals(
          parsed.pinned,
          pinned,
          `联合测试 pinned 不匹配：输入 ${pinned}，得到 ${parsed.pinned}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});
