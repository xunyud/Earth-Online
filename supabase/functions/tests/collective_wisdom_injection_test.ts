// Feature: memory-system-evolution, Property 17 & 18: Collective wisdom injection
// **Validates: Requirements 9.2, 9.3**
//
// Property 17: 验证注入消息包含"其他冒险者的经验："前缀
// Property 18: 验证检索失败或无结果时消息不变
//
// 测试策略：模拟 searchCollectiveWisdom 的行为，验证注入逻辑的正确性。
// 由于注入逻辑内联在 patrolUser 中，此处提取核心注入逻辑进行独立测试。

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";

// ---------- 提取的注入逻辑（与 memory-patrol/index.ts 中的实现一致） ----------

type PatrolSignal = {
  kind: "stale_task" | "streak_break" | "long_silence";
  message: string;
  urgency: "low" | "medium" | "high";
};

/**
 * 模拟群体智慧注入逻辑：与 memory-patrol 中 patrolUser 的注入代码保持一致。
 * 当 signal.kind === "streak_break" 时，调用 searchFn 检索群体经验并注入消息。
 * 检索失败或无结果时保持原始消息不变。
 */
async function injectCollectiveWisdom(
  signal: PatrolSignal,
  searchFn: (query: string, limit: number) => Promise<string[]>,
): Promise<string> {
  const originalMessage = signal.message;
  if (signal.kind === "streak_break") {
    try {
      const wisdomLines = await searchFn("断签恢复 重新开始", 3);
      if (wisdomLines.length > 0) {
        return originalMessage + `\n\n其他冒险者的经验：${wisdomLines[0]}`;
      }
    } catch {
      // 检索失败不影响推送，使用原有消息
    }
  }
  return originalMessage;
}

// ---------- 生成器 ----------

/** 生成随机的原始推送消息 */
const arbOriginalMessage = fc.stringOf(
  fc.constantFrom(
    ..."你已经连续打卡天了今天还没有记录要继续保持吗任务板上还有待推进的任务abcdefghijklmnopqrstuvwxyz0123456789",
  ),
  { minLength: 5, maxLength: 80 },
);

/** 生成随机的群体智慧文本（非空） */
const arbWisdomText = fc.stringOf(
  fc.constantFrom(
    ..."一位冒险者在断签后重新开始行动保持了稳定的节奏恢复打卡习惯abcdefghijklmnopqrstuvwxyz",
  ),
  { minLength: 3, maxLength: 60 },
);

/** 生成随机的信号类型 */
const arbSignalKind: fc.Arbitrary<PatrolSignal["kind"]> = fc.constantFrom(
  "stale_task",
  "streak_break",
  "long_silence",
);

/** 生成随机的紧急程度 */
const arbUrgency: fc.Arbitrary<PatrolSignal["urgency"]> = fc.constantFrom(
  "low",
  "medium",
  "high",
);

// ---------- Property 17: Collective wisdom injection format ----------

Deno.test("Property 17: 注入消息包含'其他冒险者的经验：'前缀", async () => {
  await fc.assert(
    fc.asyncProperty(
      arbOriginalMessage,
      arbWisdomText,
      arbUrgency,
      async (originalMsg, wisdomText, urgency) => {
        const signal: PatrolSignal = {
          kind: "streak_break",
          message: originalMsg,
          urgency,
        };

        // 模拟检索成功返回一条结果
        const searchFn = async (_q: string, _l: number) => [wisdomText];
        const result = await injectCollectiveWisdom(signal, searchFn);

        // 结果必须包含"其他冒险者的经验："前缀
        assert(
          result.includes("其他冒险者的经验："),
          `注入后消息应包含"其他冒险者的经验："前缀，实际: "${result}"`,
        );

        // 结果必须包含原始消息
        assert(
          result.includes(originalMsg),
          `注入后消息应保留原始内容，原始: "${originalMsg}"，实际: "${result}"`,
        );

        // 结果必须包含智慧文本
        assert(
          result.includes(wisdomText),
          `注入后消息应包含智慧文本，智慧: "${wisdomText}"，实际: "${result}"`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 17: 注入格式为 '原始消息\\n\\n其他冒险者的经验：{智慧文本}'", async () => {
  await fc.assert(
    fc.asyncProperty(
      arbOriginalMessage,
      arbWisdomText,
      async (originalMsg, wisdomText) => {
        const signal: PatrolSignal = {
          kind: "streak_break",
          message: originalMsg,
          urgency: "medium",
        };

        const searchFn = async (_q: string, _l: number) => [wisdomText];
        const result = await injectCollectiveWisdom(signal, searchFn);

        // 验证精确格式
        const expected = `${originalMsg}\n\n其他冒险者的经验：${wisdomText}`;
        assertEquals(
          result,
          expected,
          `注入格式不匹配`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// ---------- Property 18: Collective search failure preserves original message ----------

Deno.test("Property 18: 检索失败时消息不变", async () => {
  await fc.assert(
    fc.asyncProperty(
      arbOriginalMessage,
      arbUrgency,
      async (originalMsg, urgency) => {
        const signal: PatrolSignal = {
          kind: "streak_break",
          message: originalMsg,
          urgency,
        };

        // 模拟检索抛出异常
        const searchFn = async (_q: string, _l: number): Promise<string[]> => {
          throw new Error("EverMemOS 检索超时");
        };
        const result = await injectCollectiveWisdom(signal, searchFn);

        // 消息应保持不变
        assertEquals(
          result,
          originalMsg,
          `检索失败时消息应保持不变，原始: "${originalMsg}"，实际: "${result}"`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 18: 检索返回空数组时消息不变", async () => {
  await fc.assert(
    fc.asyncProperty(
      arbOriginalMessage,
      arbUrgency,
      async (originalMsg, urgency) => {
        const signal: PatrolSignal = {
          kind: "streak_break",
          message: originalMsg,
          urgency,
        };

        // 模拟检索返回空结果
        const searchFn = async (_q: string, _l: number): Promise<string[]> => [];
        const result = await injectCollectiveWisdom(signal, searchFn);

        // 消息应保持不变
        assertEquals(
          result,
          originalMsg,
          `检索无结果时消息应保持不变，原始: "${originalMsg}"，实际: "${result}"`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// ---------- 单元测试：非 streak_break 信号不触发注入 ----------

Deno.test("Property 17/18: 非 streak_break 信号不触发群体智慧注入", async () => {
  await fc.assert(
    fc.asyncProperty(
      arbOriginalMessage,
      arbWisdomText,
      fc.constantFrom("stale_task" as const, "long_silence" as const),
      arbUrgency,
      async (originalMsg, wisdomText, kind, urgency) => {
        const signal: PatrolSignal = {
          kind,
          message: originalMsg,
          urgency,
        };

        // 即使检索能返回结果，非 streak_break 信号也不应注入
        const searchFn = async (_q: string, _l: number) => [wisdomText];
        const result = await injectCollectiveWisdom(signal, searchFn);

        assertEquals(
          result,
          originalMsg,
          `非 streak_break 信号不应注入群体智慧，kind="${kind}"`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// ---------- 单元测试：多条智慧结果只取第一条 ----------

Deno.test("单元测试: 多条智慧结果只注入第一条", async () => {
  const signal: PatrolSignal = {
    kind: "streak_break",
    message: "你已经连续打卡 5 天了",
    urgency: "medium",
  };

  const wisdomLines = [
    "一位冒险者在断签后第二天就恢复了打卡",
    "一位冒险者通过降低目标重新开始",
    "一位冒险者找到了新的动力来源",
  ];

  const searchFn = async (_q: string, _l: number) => wisdomLines;
  const result = await injectCollectiveWisdom(signal, searchFn);

  assert(result.includes(wisdomLines[0]), "应包含第一条智慧");
  assert(!result.includes(wisdomLines[1]), "不应包含第二条智慧");
  assert(!result.includes(wisdomLines[2]), "不应包含第三条智慧");
  assertEquals(
    result,
    `你已经连续打卡 5 天了\n\n其他冒险者的经验：${wisdomLines[0]}`,
  );
});
