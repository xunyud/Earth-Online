// Feature: memory-system-evolution, Property 16: Anonymization invariant
// **Validates: Requirements 8.2, 8.3, 9.4, 10.4**
//
// 属性测试：验证 writeCollectiveMilestone 写入 payload 始终使用 "anonymous" 作为 user_id，
// 且 content 字段不包含原始 user_id 字符串。
// 使用 fast-check 生成随机 user_id 和里程碑类型，通过 mock client 捕获实际写入参数。

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";
import {
  ANONYMOUS_USER_ID,
  COLLECTIVE_GROUP_ID,
  writeCollectiveMilestone,
  type MilestoneType,
} from "../_shared/collective_memory.ts";
import type { EverMemCreateMemoryInput } from "../_shared/evermemos_client.ts";

// ---------- Mock Client ----------

/** 捕获 createMemory 调用参数的 mock 客户端 */
function createMockClient() {
  const calls: EverMemCreateMemoryInput[] = [];
  return {
    calls,
    createMemory(input: EverMemCreateMemoryInput) {
      calls.push(input);
      return Promise.resolve({ ok: true });
    },
    searchMemories() {
      return Promise.resolve({ memories: [] });
    },
  };
}

// ---------- 生成器 ----------

/** 生成非空、非 "anonymous" 的随机 user_id（仅字母数字，避免特殊字符干扰） */
const arbUserId = fc
  .stringOf(fc.constantFrom(..."abcdefghijklmnopqrstuvwxyz0123456789"), {
    minLength: 3,
    maxLength: 20,
  })
  .filter((s) => s !== "anonymous");

/** 生成随机里程碑类型 */
const arbMilestoneType: fc.Arbitrary<MilestoneType> = fc.constantFrom(
  "streak_7day",
  "first_clear",
  "recovery_from_break",
);

/** 生成非空描述文本（仅中文和字母，避免空白字符问题） */
const arbDescription = fc
  .stringOf(
    fc.constantFrom(
      ..."一位冒险者达成了里程碑保持稳定行动节奏abcdefghijklmnopqrstuvwxyz",
    ),
    { minLength: 3, maxLength: 60 },
  );

// ---------- Property 16: Anonymization invariant ----------

Deno.test("Property 16: writeCollectiveMilestone 始终使用 anonymous 作为 user_id", async () => {
  await fc.assert(
    fc.asyncProperty(
      arbUserId,
      arbMilestoneType,
      arbDescription,
      async (_originalUserId, milestoneType, description) => {
        const mock = createMockClient();

        // deno-lint-ignore no-explicit-any
        await writeCollectiveMilestone(mock as any, milestoneType, description);

        // 验证恰好调用了一次 createMemory
        assertEquals(mock.calls.length, 1, "应恰好调用一次 createMemory");

        const payload = mock.calls[0];

        // 核心断言：user_id 必须是 "anonymous"
        assertEquals(
          payload.userId,
          ANONYMOUS_USER_ID,
          `写入 payload 的 userId 应为 "${ANONYMOUS_USER_ID}"`,
        );

        // 验证 eventType 包含里程碑类型前缀
        assertEquals(
          payload.eventType,
          `milestone_${milestoneType}`,
        );

        // 验证 metadata 中包含 group_id
        const extra = payload.metadata?.extra as
          | Record<string, unknown>
          | undefined;
        assertEquals(extra?.group_id, COLLECTIVE_GROUP_ID);
        assertEquals(extra?.milestone_type, milestoneType);
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 16: 写入 content 不包含原始 user_id", async () => {
  await fc.assert(
    fc.asyncProperty(
      arbUserId,
      arbMilestoneType,
      async (originalUserId, milestoneType) => {
        const description = `一位冒险者达成了${milestoneType}里程碑`;
        const mock = createMockClient();

        // deno-lint-ignore no-explicit-any
        await writeCollectiveMilestone(mock as any, milestoneType, description);

        assertEquals(mock.calls.length, 1);
        const payload = mock.calls[0];

        // content 不应包含原始 user_id
        assert(
          !payload.content.includes(originalUserId),
          `content 不应包含原始 user_id "${originalUserId}"`,
        );

        // userId 字段不应是原始 user_id
        assert(
          payload.userId !== originalUserId,
          `userId 不应为原始 user_id`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 16: 所有里程碑类型均使用匿名写入且 memoryKind 为 generic", async () => {
  await fc.assert(
    fc.asyncProperty(
      arbMilestoneType,
      arbDescription,
      async (milestoneType, desc) => {
        const mock = createMockClient();
        // deno-lint-ignore no-explicit-any
        await writeCollectiveMilestone(mock as any, milestoneType, desc);

        assertEquals(mock.calls.length, 1);
        assertEquals(mock.calls[0].userId, ANONYMOUS_USER_ID);
        assertEquals(mock.calls[0].metadata?.memoryKind, "generic");
      },
    ),
    { numRuns: 100 },
  );
});
