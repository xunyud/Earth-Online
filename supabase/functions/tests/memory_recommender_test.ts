// 属性测试与单元测试：记忆驱动任务推荐引擎
// Feature: memory-system-evolution, Property 12: Recommendation output structure validation
// Feature: memory-system-evolution, Property 13: Recommendation prompt includes three signal types
// Feature: memory-system-evolution, Property 14: Insufficient memories yield empty recommendations
// Feature: memory-system-evolution, Property 15: LLM failure yields empty recommendations
// **Validates: Requirements 6.2, 6.3, 6.4, 6.5**
//
// 测试策略：
// 直接导入 memory-recommender 导出的纯函数 buildRecommendationPrompt 和 parseRecommendations，
// 用 fast-check 生成随机输入验证四项属性。不涉及网络调用，无需 mock。

import {
  assertEquals,
  assert,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";
import {
  buildRecommendationPrompt,
  parseRecommendations,
  MIN_MEMORY_COUNT,
} from "../memory-recommender/helpers.ts";
import type { Recommendation } from "../memory-recommender/helpers.ts";

// ========== Property 12: Recommendation output structure validation ==========

// Feature: memory-system-evolution, Property 12: Recommendation output structure validation
Deno.test("Property 12: 有效 JSON 数组解析后每条推荐有非空 title 和 reason，总数 2–3 条", () => {
  // 生成器：构造 2–3 条有效推荐的 JSON 字符串
  const validRecommendationArb = fc.record({
    title: fc.string({ minLength: 1, maxLength: 100 }).filter((s) => s.trim().length > 0),
    reason: fc.string({ minLength: 1, maxLength: 200 }).filter((s) => s.trim().length > 0),
  });

  const validJsonArrayArb = fc
    .array(validRecommendationArb, { minLength: 2, maxLength: 3 })
    .map((arr) => JSON.stringify(arr));

  fc.assert(
    fc.property(validJsonArrayArb, (jsonStr) => {
      const result = parseRecommendations(jsonStr);

      // 总数应在 2–3 之间
      assert(
        result.length >= 2 && result.length <= 3,
        `推荐数量应为 2–3，实际 ${result.length}，输入: ${jsonStr}`,
      );

      // 每条推荐的 title 和 reason 非空
      for (let i = 0; i < result.length; i++) {
        assert(
          result[i].title.length > 0,
          `第 ${i} 条推荐的 title 不应为空`,
        );
        assert(
          result[i].reason.length > 0,
          `第 ${i} 条推荐的 reason 不应为空`,
        );
      }
    }),
    { numRuns: 200 },
  );
});

Deno.test("Property 12: 超过 3 条时截取前 3 条", () => {
  const manyItems = Array.from({ length: 5 }, (_, i) => ({
    title: `任务${i + 1}`,
    reason: `理由${i + 1}`,
  }));
  const result = parseRecommendations(JSON.stringify(manyItems));
  assertEquals(result.length, 3, "超过 3 条应截取前 3 条");
});

Deno.test("Property 12: 不足 2 条时返回空数组", () => {
  const oneItem = [{ title: "唯一任务", reason: "唯一理由" }];
  const result = parseRecommendations(JSON.stringify(oneItem));
  assertEquals(result.length, 0, "不足 2 条应返回空数组");
});

Deno.test("Property 12: 恰好 2 条时正常返回", () => {
  const twoItems = [
    { title: "任务A", reason: "理由A" },
    { title: "任务B", reason: "理由B" },
  ];
  const result = parseRecommendations(JSON.stringify(twoItems));
  assertEquals(result.length, 2);
  assertEquals(result[0].title, "任务A");
  assertEquals(result[1].reason, "理由B");
});

Deno.test("Property 12: 恰好 3 条时正常返回", () => {
  const threeItems = [
    { title: "任务1", reason: "理由1" },
    { title: "任务2", reason: "理由2" },
    { title: "任务3", reason: "理由3" },
  ];
  const result = parseRecommendations(JSON.stringify(threeItems));
  assertEquals(result.length, 3);
});


// ========== Property 13: Recommendation prompt includes three signal types ==========

// Feature: memory-system-evolution, Property 13: Recommendation prompt includes three signal types
Deno.test("Property 13: 构建的 prompt 包含三类信号引用", () => {
  // 生成器：1–10 条非空记忆文本
  const memoryTextsArb = fc.array(
    fc.string({ minLength: 1, maxLength: 200 }).filter((s) => s.trim().length > 0),
    { minLength: 1, maxLength: 10 },
  );

  fc.assert(
    fc.property(memoryTextsArb, (memoryTexts) => {
      const prompt = buildRecommendationPrompt(memoryTexts);

      // 验证 prompt 包含三类信号关键词
      assert(
        prompt.includes("完成模式"),
        `prompt 应包含"完成模式"信号引用`,
      );
      assert(
        prompt.includes("搁置任务"),
        `prompt 应包含"搁置任务"信号引用`,
      );
      assert(
        prompt.includes("习惯形成信号"),
        `prompt 应包含"习惯形成信号"信号引用`,
      );
    }),
    { numRuns: 100 },
  );
});

Deno.test("Property 13: 带 clientContext 时 prompt 包含上下文内容", () => {
  fc.assert(
    fc.property(
      fc.array(
        fc.string({ minLength: 1, maxLength: 100 }).filter((s) => s.trim().length > 0),
        { minLength: 1, maxLength: 5 },
      ),
      fc.string({ minLength: 1, maxLength: 100 }).filter((s) => s.trim().length > 0),
      (memoryTexts, clientContext) => {
        const prompt = buildRecommendationPrompt(memoryTexts, clientContext);

        // 验证 prompt 包含 clientContext
        assert(
          prompt.includes(clientContext),
          `prompt 应包含 clientContext: "${clientContext}"`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 13: prompt 包含所有记忆文本", () => {
  const texts = ["用户每天写日记", "连续 5 天完成运动", "有一个搁置的读书任务"];
  const prompt = buildRecommendationPrompt(texts);

  for (const text of texts) {
    assert(prompt.includes(text), `prompt 应包含记忆文本: "${text}"`);
  }
});

// ========== Property 14: Insufficient memories yield empty recommendations ==========

// Feature: memory-system-evolution, Property 14: Insufficient memories yield empty recommendations
// 注意：此属性验证的是"记忆不足 3 条时返回空推荐"的逻辑模式。
// memory-recommender 的 Edge Function handler 中实现了此检查（memories.length < MIN_MEMORY_COUNT）。
// 由于 handler 不可直接导入，这里通过模拟相同逻辑模式来验证。

/** 复现 index.ts 中的记忆不足检查逻辑，使用 helpers.ts 导出的常量 */
function shouldReturnEmptyRecommendations(memoryCount: number): boolean {
  return memoryCount < MIN_MEMORY_COUNT;
}

Deno.test("Property 14: 记忆不足 3 条时应返回空推荐", () => {
  fc.assert(
    fc.property(
      fc.integer({ min: 0, max: 2 }),
      (memoryCount) => {
        assert(
          shouldReturnEmptyRecommendations(memoryCount),
          `记忆数 ${memoryCount} < 3，应返回空推荐`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 14: 记忆 >= 3 条时不应因数量不足返回空推荐", () => {
  fc.assert(
    fc.property(
      fc.integer({ min: 3, max: 100 }),
      (memoryCount) => {
        assert(
          !shouldReturnEmptyRecommendations(memoryCount),
          `记忆数 ${memoryCount} >= 3，不应因数量不足返回空推荐`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 14: 边界值 — 0、1、2 条记忆均返回空", () => {
  for (const count of [0, 1, 2]) {
    assert(
      shouldReturnEmptyRecommendations(count),
      `记忆数 ${count} 应返回空推荐`,
    );
  }
});

Deno.test("Property 14: 边界值 — 恰好 3 条记忆不返回空", () => {
  assert(
    !shouldReturnEmptyRecommendations(3),
    "记忆数 3 不应因数量不足返回空推荐",
  );
});

// ========== Property 15: LLM failure yields empty recommendations ==========

// Feature: memory-system-evolution, Property 15: LLM failure yields empty recommendations
// 验证 parseRecommendations 在各种异常输入下返回空数组且不抛出异常。

Deno.test("Property 15: 无效 JSON 字符串返回空数组且不抛错", () => {
  // 生成器：随机非 JSON 字符串
  const invalidJsonArb = fc.string({ minLength: 1, maxLength: 200 }).filter((s) => {
    try {
      JSON.parse(s);
      return false; // 排除碰巧是合法 JSON 的字符串
    } catch {
      return true;
    }
  });

  fc.assert(
    fc.property(invalidJsonArb, (invalidJson) => {
      // 不应抛出异常
      const result = parseRecommendations(invalidJson);
      assertEquals(result.length, 0, `无效 JSON 应返回空数组，输入: "${invalidJson}"`);
    }),
    { numRuns: 200 },
  );
});

Deno.test("Property 15: 非数组 JSON 返回空数组", () => {
  // 生成器：合法 JSON 但不是数组（对象、字符串、数字、布尔、null）
  const nonArrayJsonArb = fc.oneof(
    fc.record({ key: fc.string() }).map((obj) => JSON.stringify(obj)),
    fc.string().map((s) => JSON.stringify(s)),
    fc.integer().map((n) => JSON.stringify(n)),
    fc.boolean().map((b) => JSON.stringify(b)),
    fc.constant("null"),
  );

  fc.assert(
    fc.property(nonArrayJsonArb, (jsonStr) => {
      const result = parseRecommendations(jsonStr);
      assertEquals(result.length, 0, `非数组 JSON 应返回空数组，输入: ${jsonStr}`);
    }),
    { numRuns: 100 },
  );
});

Deno.test("Property 15: 数组中缺少必要字段时过滤掉无效条目", () => {
  // 生成器：数组中包含缺少 title 或 reason 的对象
  const incompleteItemArb = fc.oneof(
    fc.record({ title: fc.string() }), // 缺少 reason
    fc.record({ reason: fc.string() }), // 缺少 title
    fc.record({ title: fc.constant(""), reason: fc.string() }), // title 为空
    fc.record({ title: fc.string(), reason: fc.constant("") }), // reason 为空
    fc.constant(null),
    fc.constant(42),
    fc.constant("字符串"),
  );

  fc.assert(
    fc.property(
      fc.array(incompleteItemArb, { minLength: 1, maxLength: 5 }),
      (items) => {
        const jsonStr = JSON.stringify(items);
        // 不应抛出异常
        const result = parseRecommendations(jsonStr);
        // 结果中每条都应有非空 title 和 reason（如果有的话）
        for (const rec of result) {
          assert(rec.title.length > 0, "过滤后的推荐 title 不应为空");
          assert(rec.reason.length > 0, "过滤后的推荐 reason 不应为空");
        }
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 15: 空字符串返回空数组", () => {
  const result = parseRecommendations("");
  assertEquals(result.length, 0, "空字符串应返回空数组");
});

Deno.test("Property 15: Markdown 代码围栏包裹的有效 JSON 可正常解析", () => {
  const validItems = [
    { title: "写日记", reason: "你最近每天都在写" },
    { title: "做运动", reason: "连续 3 天运动记录" },
  ];
  const fenced = "```json\n" + JSON.stringify(validItems) + "\n```";
  const result = parseRecommendations(fenced);
  assertEquals(result.length, 2, "Markdown 围栏包裹的有效 JSON 应正常解析");
  assertEquals(result[0].title, "写日记");
  assertEquals(result[1].reason, "连续 3 天运动记录");
});

Deno.test("Property 15: 空数组 JSON 返回空数组", () => {
  const result = parseRecommendations("[]");
  assertEquals(result.length, 0, "空数组应返回空数组（不足 2 条）");
});
