// Feature: memory-moat, Property 16: Historical reflection injection cap
// **Validates: Requirements 13.2**
//
// 属性测试：验证历史反思记忆注入 LLM prompt 时最多 3 条，且为最近的 3 条。
// 使用 fast-check 生成随机长度的历史反思记忆列表（0–20 条），验证：
// 1. 结果长度 <= 3
// 2. 输入 > 3 条匹配项时，结果为前 3 条（最近的 3 条）
// 3. 输入 <= 3 条匹配项时，全部包含
// 4. 不含 "night_reflection" 的条目被排除

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";
import { filterReflectionHistory } from "../_shared/guide_memory.ts";

// ---------- 生成器 ----------

/** 生成包含 "night_reflection" 关键词的记忆文本（匹配条目） */
const arbMatchingText: fc.Arbitrary<string> = fc
  .tuple(
    fc.string({ minLength: 0, maxLength: 50 }),
    fc.string({ minLength: 0, maxLength: 50 }),
  )
  .map(([prefix, suffix]) => `${prefix}night_reflection${suffix}`);

/** 生成不包含 "night_reflection" 的记忆文本（不匹配条目） */
const arbNonMatchingText: fc.Arbitrary<string> = fc
  .string({ minLength: 1, maxLength: 100 })
  .filter((s) => !s.includes("night_reflection"));

/** 生成匹配的记忆条目（对象形式，模拟 EverMemOS 返回结构） */
const arbMatchingItem: fc.Arbitrary<Record<string, unknown>> = arbMatchingText
  .map((text) => ({ content: text }));

/** 生成不匹配的记忆条目（对象形式） */
const arbNonMatchingItem: fc.Arbitrary<Record<string, unknown>> =
  arbNonMatchingText.map((text) => ({ content: text }));

/** 生成混合记忆列表：随机数量的匹配和不匹配条目 */
const arbMixedItems: fc.Arbitrary<{
  items: Array<Record<string, unknown>>;
  matchCount: number;
}> = fc
  .tuple(
    fc.array(arbMatchingItem, { minLength: 0, maxLength: 20 }),
    fc.array(arbNonMatchingItem, { minLength: 0, maxLength: 10 }),
  )
  .chain(([matching, nonMatching]) =>
    // 随机打乱顺序，但记录匹配条目数量
    fc.shuffledSubarray([...matching, ...nonMatching], {
      minLength: matching.length + nonMatching.length,
      maxLength: matching.length + nonMatching.length,
    }).map((shuffled) => ({
      items: shuffled,
      matchCount: matching.length,
    }))
  );

// ---------- Property 16: Historical reflection injection cap ----------

// Feature: memory-moat, Property 16: Historical reflection injection cap
// 核心属性：结果长度始终 <= 3
Deno.test("Property 16: 结果长度始终 <= 3", () => {
  fc.assert(
    fc.property(
      fc.array(
        fc.oneof(arbMatchingItem, arbNonMatchingItem),
        { minLength: 0, maxLength: 20 },
      ),
      (items: Array<Record<string, unknown>>) => {
        const result = filterReflectionHistory(items);
        assert(
          result.length <= 3,
          `结果长度应 <= 3，实际为 ${result.length}（输入 ${items.length} 条）`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 16: Historical reflection injection cap
// 输入 > 3 条匹配项时，结果恰好为 3 条
Deno.test("Property 16: 超过 3 条匹配项时结果恰好为 3 条", () => {
  fc.assert(
    fc.property(
      fc.array(arbMatchingItem, { minLength: 4, maxLength: 20 }),
      (items: Array<Record<string, unknown>>) => {
        const result = filterReflectionHistory(items);
        assertEquals(
          result.length,
          3,
          `输入 ${items.length} 条匹配项时，结果应恰好为 3 条，实际为 ${result.length}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 16: Historical reflection injection cap
// 输入 <= 3 条匹配项时，全部包含（不丢失）
Deno.test("Property 16: 匹配项 <= 3 条时全部保留", () => {
  fc.assert(
    fc.property(
      fc.integer({ min: 0, max: 3 }).chain((n) =>
        fc.tuple(
          fc.array(arbMatchingItem, { minLength: n, maxLength: n }),
          fc.array(arbNonMatchingItem, { minLength: 0, maxLength: 10 }),
        )
      ),
      ([matching, nonMatching]) => {
        // 匹配项在前，不匹配项在后（模拟实际场景）
        const items = [...matching, ...nonMatching];
        const result = filterReflectionHistory(items);
        assertEquals(
          result.length,
          matching.length,
          `输入 ${matching.length} 条匹配项时，结果应全部保留，实际为 ${result.length}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 16: Historical reflection injection cap
// 不含 "night_reflection" 的条目被完全排除
Deno.test("Property 16: 不含 night_reflection 的条目被排除", () => {
  fc.assert(
    fc.property(
      fc.array(arbNonMatchingItem, { minLength: 1, maxLength: 20 }),
      (items: Array<Record<string, unknown>>) => {
        const result = filterReflectionHistory(items);
        assertEquals(
          result.length,
          0,
          `全部不匹配时结果应为空，实际为 ${result.length}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 16: Historical reflection injection cap
// 结果中的每条文本都包含 "night_reflection"
Deno.test("Property 16: 结果中每条文本都包含 night_reflection", () => {
  fc.assert(
    fc.property(
      fc.array(
        fc.oneof(arbMatchingItem, arbNonMatchingItem),
        { minLength: 0, maxLength: 20 },
      ),
      (items: Array<Record<string, unknown>>) => {
        const result = filterReflectionHistory(items);
        for (const text of result) {
          assert(
            text.includes("night_reflection"),
            `结果中的文本应包含 "night_reflection"，实际为 "${text}"`,
          );
        }
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 16: Historical reflection injection cap
// 结果保持输入顺序中前 3 条匹配项（最近的 3 条）
Deno.test("Property 16: 结果为输入中前 3 条匹配项（最近的 3 条）", () => {
  fc.assert(
    fc.property(
      fc.array(arbMatchingItem, { minLength: 4, maxLength: 20 }),
      (items: Array<Record<string, unknown>>) => {
        const result = filterReflectionHistory(items);

        // 手动计算期望结果：前 3 条匹配项的文本
        const expectedTexts = items
          .filter((item) => {
            const text = typeof item === "string"
              ? item.trim()
              : String(item.content ?? "").trim();
            return text.includes("night_reflection");
          })
          .slice(0, 3)
          .map((item) =>
            typeof item === "string"
              ? item.trim()
              : String(item.content ?? "").trim()
          );

        assertEquals(
          result.length,
          expectedTexts.length,
          "结果长度应与期望一致",
        );
        for (let i = 0; i < result.length; i++) {
          assertEquals(
            result[i],
            expectedTexts[i],
            `第 ${i} 条结果应为输入中第 ${i} 条匹配项`,
          );
        }
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 16: Historical reflection injection cap
// 空输入返回空列表
Deno.test("Property 16: 空输入返回空列表", () => {
  const result = filterReflectionHistory([]);
  assertEquals(result.length, 0, "空输入应返回空列表");
});

// Feature: memory-moat, Property 16: Historical reflection injection cap
// 字符串形式的记忆条目同样适用
Deno.test("Property 16: 字符串形式的记忆条目同样适用", () => {
  fc.assert(
    fc.property(
      fc.array(
        fc.oneof(arbMatchingText, arbNonMatchingText),
        { minLength: 0, maxLength: 20 },
      ),
      (items: string[]) => {
        const result = filterReflectionHistory(items);

        // 验证上限
        assert(result.length <= 3, `结果长度应 <= 3，实际为 ${result.length}`);

        // 验证每条结果包含关键词
        for (const text of result) {
          assert(
            text.includes("night_reflection"),
            `结果文本应包含 "night_reflection"`,
          );
        }

        // 验证匹配数量正确
        const matchCount = items.filter((s) =>
          s.includes("night_reflection")
        ).length;
        assertEquals(
          result.length,
          Math.min(matchCount, 3),
          `结果长度应为 min(匹配数 ${matchCount}, 3)`,
        );
      },
    ),
    { numRuns: 100 },
  );
});
