// 属性测试与单元测试：知识提取批量处理
// Feature: memory-system-evolution, Property 5: Batch processing covers all active users
// Feature: memory-system-evolution, Property 6: Flush error isolation
// **Validates: Requirements 2.2, 2.4**
//
// 测试策略：
// knowledge-extraction 是 Deno.serve Edge Function，无法直接导入 handler。
// 因此提取其核心批量处理逻辑模式（flushForUser + 串行循环）在测试中重现，
// 用 mock 替代 EverMemOSClient，验证批量覆盖和错误隔离两项属性。

import {
  assertEquals,
  assert,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";

// ---------- 从 knowledge-extraction/index.ts 提取的核心逻辑 ----------

/**
 * 将错误转为字符串消息，与 index.ts 中 toErrorMessage 逻辑一致。
 */
function toErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  try {
    return JSON.stringify(error);
  } catch {
    return String(error);
  }
}

/**
 * 对单个用户执行知识提取。
 * 复现 index.ts 中 flushForUser 的错误隔离逻辑：
 * 成功返回 null，失败返回错误描述字符串，不抛出异常。
 */
async function flushForUser(
  flushFn: (userId: string) => Promise<void>,
  userId: string,
): Promise<string | null> {
  try {
    await flushFn(userId);
    return null;
  } catch (err) {
    const msg = toErrorMessage(err);
    return `${userId}: ${msg}`;
  }
}

/**
 * 批量处理逻辑，复现 index.ts 中 Deno.serve handler 的串行循环。
 * 逐用户调用 flushForUser，收集成功数和错误列表。
 */
async function batchFlush(
  userIds: string[],
  flushFn: (userId: string) => Promise<void>,
): Promise<{ processed: number; errors: string[] }> {
  const errors: string[] = [];
  let processed = 0;

  for (const userId of userIds) {
    const err = await flushForUser(flushFn, userId);
    if (err) {
      errors.push(err);
    } else {
      processed++;
    }
  }

  return { processed, errors };
}

// ---------- 辅助：生成唯一用户 ID 列表 ----------

/** fast-check 生成器：1–20 个唯一用户 ID */
const uniqueUserIdsArb = fc
  .uniqueArray(fc.uuid(), { minLength: 1, maxLength: 20 });

// ========== Property 5: Batch processing covers all active users ==========

// Feature: memory-system-evolution, Property 5: Batch processing covers all active users
Deno.test("Property 5: 批量处理对每个活跃用户恰好调用一次 flush", async () => {
  await fc.assert(
    fc.asyncProperty(uniqueUserIdsArb, async (userIds) => {
      // 记录每个用户被调用的次数
      const callCounts = new Map<string, number>();

      const mockFlush = async (userId: string): Promise<void> => {
        callCounts.set(userId, (callCounts.get(userId) ?? 0) + 1);
      };

      await batchFlush(userIds, mockFlush);

      // 验证：每个用户恰好被调用一次
      for (const userId of userIds) {
        const count = callCounts.get(userId) ?? 0;
        if (count !== 1) {
          throw new Error(
            `用户 ${userId} 应被调用恰好 1 次，实际 ${count} 次`,
          );
        }
      }

      // 验证：没有额外用户被调用
      if (callCounts.size !== userIds.length) {
        throw new Error(
          `调用的用户数 ${callCounts.size} 应等于输入用户数 ${userIds.length}`,
        );
      }
    }),
    { numRuns: 100 },
  );
});

Deno.test("Property 5: 空用户列表不触发任何 flush 调用", async () => {
  let callCount = 0;
  const mockFlush = async (_userId: string): Promise<void> => {
    callCount++;
  };

  const result = await batchFlush([], mockFlush);

  assertEquals(callCount, 0, "空列表不应触发任何调用");
  assertEquals(result.processed, 0);
  assertEquals(result.errors.length, 0);
});

// ========== Property 6: Flush error isolation ==========

// Feature: memory-system-evolution, Property 6: Flush error isolation
Deno.test("Property 6: 单用户失败不影响其他用户的处理", async () => {
  await fc.assert(
    fc.asyncProperty(
      // 生成 2–20 个唯一用户 ID
      fc.uniqueArray(fc.uuid(), { minLength: 2, maxLength: 20 }),
      // 生成一个失败概率（0–100%），用于确定哪些用户失败
      fc.integer({ min: 0, max: 100 }),
      async (userIds, failPercent) => {
        // 根据 failPercent 确定失败用户集合（确定性：基于索引）
        const failSet = new Set<string>();
        for (let i = 0; i < userIds.length; i++) {
          if ((i * 100) / userIds.length < failPercent) {
            failSet.add(userIds[i]);
          }
        }

        // 记录成功处理的用户
        const successfulUsers: string[] = [];

        const mockFlush = async (userId: string): Promise<void> => {
          if (failSet.has(userId)) {
            throw new Error(`模拟失败: ${userId}`);
          }
          successfulUsers.push(userId);
        };

        const result = await batchFlush(userIds, mockFlush);

        // 验证：成功数 = 总数 - 失败数
        const expectedSuccessCount = userIds.length - failSet.size;
        if (result.processed !== expectedSuccessCount) {
          throw new Error(
            `成功数应为 ${expectedSuccessCount}（总 ${userIds.length} - 失败 ${failSet.size}），实际 ${result.processed}`,
          );
        }

        // 验证：错误数 = 失败用户数
        if (result.errors.length !== failSet.size) {
          throw new Error(
            `错误数应为 ${failSet.size}，实际 ${result.errors.length}`,
          );
        }

        // 验证：所有非失败用户都被成功处理
        const expectedSuccessful = userIds.filter((uid) => !failSet.has(uid));
        if (successfulUsers.length !== expectedSuccessful.length) {
          throw new Error(
            `成功处理的用户数应为 ${expectedSuccessful.length}，实际 ${successfulUsers.length}`,
          );
        }
        for (const uid of expectedSuccessful) {
          if (!successfulUsers.includes(uid)) {
            throw new Error(`非失败用户 ${uid} 应被成功处理`);
          }
        }
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 6: 全部用户失败时 processed 为 0", async () => {
  await fc.assert(
    fc.asyncProperty(uniqueUserIdsArb, async (userIds) => {
      const mockFlush = async (userId: string): Promise<void> => {
        throw new Error(`全部失败: ${userId}`);
      };

      const result = await batchFlush(userIds, mockFlush);

      if (result.processed !== 0) {
        throw new Error(`全部失败时 processed 应为 0，实际 ${result.processed}`);
      }
      if (result.errors.length !== userIds.length) {
        throw new Error(
          `错误数应等于用户数 ${userIds.length}，实际 ${result.errors.length}`,
        );
      }
    }),
    { numRuns: 50 },
  );
});

Deno.test("Property 6: 全部用户成功时 errors 为空", async () => {
  await fc.assert(
    fc.asyncProperty(uniqueUserIdsArb, async (userIds) => {
      const mockFlush = async (_userId: string): Promise<void> => {
        // 全部成功，不抛异常
      };

      const result = await batchFlush(userIds, mockFlush);

      if (result.processed !== userIds.length) {
        throw new Error(
          `全部成功时 processed 应等于用户数 ${userIds.length}，实际 ${result.processed}`,
        );
      }
      if (result.errors.length !== 0) {
        throw new Error(
          `全部成功时 errors 应为空，实际 ${result.errors.length}`,
        );
      }
    }),
    { numRuns: 50 },
  );
});

// ========== 单元测试：具体场景验证 ==========

Deno.test("单元测试: flushForUser 成功时返回 null", async () => {
  const mockFlush = async (_userId: string): Promise<void> => {};
  const result = await flushForUser(mockFlush, "user-123");
  assertEquals(result, null);
});

Deno.test("单元测试: flushForUser 失败时返回包含 userId 的错误字符串", async () => {
  const mockFlush = async (_userId: string): Promise<void> => {
    throw new Error("网络超时");
  };
  const result = await flushForUser(mockFlush, "user-456");
  assert(result !== null, "失败时应返回非 null");
  assert(result!.includes("user-456"), "错误信息应包含 userId");
  assert(result!.includes("网络超时"), "错误信息应包含原始错误描述");
});

Deno.test("单元测试: 批量处理 3 个用户，第 2 个失败", async () => {
  const userIds = ["alice", "bob", "charlie"];
  const callOrder: string[] = [];

  const mockFlush = async (userId: string): Promise<void> => {
    callOrder.push(userId);
    if (userId === "bob") {
      throw new Error("bob 的 flush 失败");
    }
  };

  const result = await batchFlush(userIds, mockFlush);

  // 验证调用顺序（串行）
  assertEquals(callOrder, ["alice", "bob", "charlie"]);

  // 验证结果
  assertEquals(result.processed, 2);
  assertEquals(result.errors.length, 1);
  assert(result.errors[0].includes("bob"));
});

Deno.test("单元测试: 批量处理保持串行顺序", async () => {
  const userIds = ["u1", "u2", "u3", "u4", "u5"];
  const callOrder: string[] = [];

  const mockFlush = async (userId: string): Promise<void> => {
    // 模拟异步延迟，验证串行执行
    await new Promise((resolve) => setTimeout(resolve, 1));
    callOrder.push(userId);
  };

  await batchFlush(userIds, mockFlush);

  // 串行执行应保持输入顺序
  assertEquals(callOrder, userIds);
});
