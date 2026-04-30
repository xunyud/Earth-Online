// 单元测试：Sender 注册与信封扩展
// 覆盖 ensureSendersRegistered、resolveSenderName、buildSmartMemoryEnvelope/parseSmartMemoryEnvelope 的具体场景。
// _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import {
  ensureSendersRegistered,
  resolveSenderName,
  SENDER_NAMES,
  senderCache,
} from "../_shared/sender_registry.ts";
import {
  buildSmartMemoryEnvelope,
  parseSmartMemoryEnvelope,
} from "../_shared/evermemos_client.ts";

// ==================== Sender 注册测试 ====================

Deno.test("ensureSendersRegistered — 首次注册成功，5 个 sender 全部缓存", async () => {
  senderCache.clear();

  const registered: string[] = [];
  const mockClient = {
    createSender: async (input: { name: string; metadata?: Record<string, unknown> }) => {
      registered.push(input.name);
      return { sender_id: `id-${input.name}`, name: input.name, metadata: {} };
    },
  };

  await ensureSendersRegistered(mockClient);

  // 验证 5 个 sender 全部注册
  assertEquals(registered.length, 5);
  for (const name of SENDER_NAMES) {
    assertEquals(senderCache.has(name), true, `缓存中应包含 ${name}`);
    assertEquals(senderCache.get(name), `id-${name}`);
  }

  senderCache.clear();
});

Deno.test("ensureSendersRegistered — 重复调用不触发 API", async () => {
  senderCache.clear();

  let apiCallCount = 0;
  const mockClient = {
    createSender: async (input: { name: string; metadata?: Record<string, unknown> }) => {
      apiCallCount++;
      return { sender_id: `id-${input.name}`, name: input.name, metadata: {} };
    },
  };

  // 首次调用：注册 5 个
  await ensureSendersRegistered(mockClient);
  assertEquals(apiCallCount, 5);

  // 第二次调用：不应再触发 API
  await ensureSendersRegistered(mockClient);
  assertEquals(apiCallCount, 5, "第二次调用不应增加 API 调用次数");

  senderCache.clear();
});

Deno.test("ensureSendersRegistered — 单个 sender 注册失败不影响其他", async () => {
  senderCache.clear();

  const failName = "agent-runtime";
  const mockClient = {
    createSender: async (input: { name: string; metadata?: Record<string, unknown> }) => {
      if (input.name === failName) {
        throw new Error("模拟注册失败");
      }
      return { sender_id: `id-${input.name}`, name: input.name, metadata: {} };
    },
  };

  await ensureSendersRegistered(mockClient);

  // 失败的 sender 不在缓存中
  assertEquals(senderCache.has(failName), false, `${failName} 注册失败，不应在缓存中`);

  // 其余 4 个 sender 应注册成功
  for (const name of SENDER_NAMES) {
    if (name === failName) continue;
    assertEquals(senderCache.has(name), true, `${name} 应注册成功并在缓存中`);
  }

  senderCache.clear();
});


// ==================== 信封解析测试 ====================

Deno.test("parseSmartMemoryEnvelope — 含 sender 的信封解析", () => {
  const envelope = buildSmartMemoryEnvelope({
    userId: "test-user",
    eventType: "quest_completed",
    content: "完成了每日任务",
    sender: "guide-assistant",
  });

  const parsed = parseSmartMemoryEnvelope(envelope);
  assertExists(parsed, "解析结果不应为 null");
  assertEquals(parsed.sender, "guide-assistant");
  assertEquals(parsed.eventType, "quest_completed");
  assertEquals(parsed.content, "完成了每日任务");
});

Deno.test("parseSmartMemoryEnvelope — 不含 sender 的信封解析", () => {
  const envelope = buildSmartMemoryEnvelope({
    userId: "test-user",
    eventType: "quest_completed",
    content: "完成了每日任务",
    // 不传 sender
  });

  const parsed = parseSmartMemoryEnvelope(envelope);
  assertExists(parsed, "解析结果不应为 null");
  assertEquals(parsed.sender, undefined, "不含 sender 时应为 undefined");
});

Deno.test("parseSmartMemoryEnvelope — sender 为空字符串时不写入", () => {
  const envelope = buildSmartMemoryEnvelope({
    userId: "test-user",
    eventType: "quest_completed",
    content: "完成了每日任务",
    sender: "",
  });

  const parsed = parseSmartMemoryEnvelope(envelope);
  assertExists(parsed, "解析结果不应为 null");
  assertEquals(parsed.sender, undefined, "空字符串 sender 不应写入信封，解析后应为 undefined");
});

// ==================== resolveSenderName 映射测试 ====================

Deno.test("resolveSenderName — quest_completed 映射到 user-manual", () => {
  assertEquals(resolveSenderName("quest_completed"), "user-manual");
});

Deno.test("resolveSenderName — agent_goal 映射到 agent-runtime", () => {
  assertEquals(resolveSenderName("agent_goal"), "agent-runtime");
});

Deno.test("resolveSenderName — agent_tool_result 映射到 agent-runtime", () => {
  assertEquals(resolveSenderName("agent_tool_result"), "agent-runtime");
});

Deno.test("resolveSenderName — agent_run_complete 映射到 agent-runtime", () => {
  assertEquals(resolveSenderName("agent_run_complete"), "agent-runtime");
});

Deno.test("resolveSenderName — patrol_nudge 映射到 patrol-nudge", () => {
  assertEquals(resolveSenderName("patrol_nudge"), "patrol-nudge");
});

Deno.test("resolveSenderName — habit_chain_break 映射到 patrol-nudge", () => {
  assertEquals(resolveSenderName("habit_chain_break"), "patrol-nudge");
});

Deno.test("resolveSenderName — wechat_message 映射到 wechat-webhook", () => {
  assertEquals(resolveSenderName("wechat_message"), "wechat-webhook");
});

Deno.test("resolveSenderName — guide_chat 映射到 guide-assistant", () => {
  assertEquals(resolveSenderName("guide_chat"), "guide-assistant");
});

Deno.test("resolveSenderName — night_reflection 映射到 guide-assistant", () => {
  assertEquals(resolveSenderName("night_reflection"), "guide-assistant");
});

Deno.test("resolveSenderName — unknown_event 映射到 user-manual", () => {
  assertEquals(resolveSenderName("unknown_event"), "user-manual");
});

Deno.test("resolveSenderName — 显式 source 参数优先于 eventType 推断", () => {
  // quest_completed 默认映射到 user-manual，但显式传入 agent-runtime 时应使用 source
  assertEquals(
    resolveSenderName("quest_completed", "agent-runtime"),
    "agent-runtime",
  );
});
