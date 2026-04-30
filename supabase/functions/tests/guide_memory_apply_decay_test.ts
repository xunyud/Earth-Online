// Feature: memory-system-evolution, Property 2: Decay-weighted sort ordering
// Feature: memory-system-evolution, Property 3: Output capped at maxRawItems
// Feature: memory-system-evolution, Property 4: Mid-term memory fallback
// **Validates: Requirements 1.2, 1.3, 1.4**
//
// 属性测试：验证 applyDecayWeights 在任意输入下满足排序、截取和中期兜底三项性质。
// 使用 fast-check 生成随机记忆列表、相关性分数和参数，覆盖各种边界情况。

import { assertEquals, assert } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";
import { applyDecayWeights, computeDecayWeight } from "../_shared/guide_memory.ts";

// 固定参考时间，确保测试确定性
const NOW = new Date("2026-06-01T00:00:00Z").getTime();
const DAY_MS = 24 * 60 * 60 * 1000;

// ---------- 辅助类型与工厂函数 ----------

/** 构造一个合法的 GuideStructuredMemoryItem，仅填充测试所需字段 */
function makeItem(
  ref: string,
  createdAt: number,
  memoryKind = "episodic_memory",
): {
  ref: string;
  rawText: string;
  displayText: string;
  memoryKind: string;
  sourceTaskId: string;
  sourceTaskTitle: string;
  sourceStatus: string;
  createdAt: string | number | null;
} {
  return {
    ref,
    rawText: "",
    displayText: "",
    memoryKind,
    sourceTaskId: "",
    sourceTaskTitle: "",
    sourceStatus: "active",
    createdAt,
  };
}

// ---------- Property 2: Decay-weighted sort ordering ----------

// Feature: memory-system-evolution, Property 2: Decay-weighted sort ordering
Deno.test("Property 2: 输出按 relevance × decayWeight 降序排列", () => {
  fc.assert(
    fc.property(
      // 生成 1–20 条记忆，每条有随机天数偏移（0–200 天）
      fc.array(
        fc.record({
          dayOffset: fc.integer({ min: 0, max: 200 }),
          relevance: fc.double({ min: 0.01, max: 1.0, noNaN: true }),
          kind: fc.constantFrom("episodic_memory", "semantic_memory", "task_event"),
        }),
        { minLength: 1, maxLength: 20 },
      ),
      fc.integer({ min: 1, max: 30 }),
      (entries, maxRawItems) => {
        // 构造记忆条目和分数映射
        const items = entries.map((e, i) =>
          makeItem(`ref_${i}`, NOW - e.dayOffset * DAY_MS, e.kind)
        );
        const scores = new Map<string, number>();
        entries.forEach((e, i) => scores.set(`ref_${i}`, e.relevance));

        const result = applyDecayWeights(items, scores, maxRawItems, NOW);

        // 计算每条输出的 finalScore
        const finalScores = result.map((item) => {
          const relevance = scores.get(item.ref) ?? 0.5;
          const decay = computeDecayWeight(item.createdAt, item.memoryKind, NOW);
          return relevance * decay;
        });

        // 中期兜底可能替换末位条目，因此仅验证前 N-1 条的排序
        // 当 result.length <= 1 时无需验证排序
        const checkLen = result.length > 1 ? result.length - 1 : 0;
        for (let i = 0; i < checkLen - 1; i++) {
          assert(
            finalScores[i] >= finalScores[i + 1],
            `位置 ${i} 的 finalScore (${finalScores[i]}) 应 >= 位置 ${i + 1} 的 (${finalScores[i + 1]})`,
          );
        }
      },
    ),
    { numRuns: 200 },
  );
});

Deno.test("Property 2: 无中期兜底触发时全部严格降序", () => {
  fc.assert(
    fc.property(
      // 生成全部为近期记忆（0–7 天），确保不触发中期兜底
      fc.array(
        fc.record({
          dayOffset: fc.integer({ min: 0, max: 5 }),
          relevance: fc.double({ min: 0.01, max: 1.0, noNaN: true }),
        }),
        { minLength: 3, maxLength: 15 },
      ),
      fc.integer({ min: 1, max: 20 }),
      (entries, maxRawItems) => {
        const items = entries.map((e, i) =>
          makeItem(`ref_${i}`, NOW - e.dayOffset * DAY_MS)
        );
        const scores = new Map<string, number>();
        entries.forEach((e, i) => scores.set(`ref_${i}`, e.relevance));

        const result = applyDecayWeights(items, scores, maxRawItems, NOW);

        // 近期记忆 >= 3 条，不触发兜底，全部严格降序
        const finalScores = result.map((item) => {
          const relevance = scores.get(item.ref) ?? 0.5;
          const decay = computeDecayWeight(item.createdAt, item.memoryKind, NOW);
          return relevance * decay;
        });

        for (let i = 0; i < finalScores.length - 1; i++) {
          assert(
            finalScores[i] >= finalScores[i + 1],
            `位置 ${i} 的 finalScore (${finalScores[i]}) 应 >= 位置 ${i + 1} 的 (${finalScores[i + 1]})`,
          );
        }
      },
    ),
    { numRuns: 100 },
  );
});

// ---------- Property 3: Output capped at maxRawItems ----------

// Feature: memory-system-evolution, Property 3: Output capped at maxRawItems
Deno.test("Property 3: 输出长度不超过 maxRawItems 且不超过输入长度", () => {
  fc.assert(
    fc.property(
      // 生成 0–50 条记忆
      fc.array(
        fc.record({
          dayOffset: fc.integer({ min: 0, max: 300 }),
          relevance: fc.double({ min: 0.0, max: 1.0, noNaN: true }),
          kind: fc.constantFrom("episodic_memory", "semantic_memory", "task_event"),
        }),
        { minLength: 0, maxLength: 50 },
      ),
      // maxRawItems 在 1–20 之间
      fc.integer({ min: 1, max: 20 }),
      (entries, maxRawItems) => {
        const items = entries.map((e, i) =>
          makeItem(`ref_${i}`, NOW - e.dayOffset * DAY_MS, e.kind)
        );
        const scores = new Map<string, number>();
        entries.forEach((e, i) => scores.set(`ref_${i}`, e.relevance));

        const result = applyDecayWeights(items, scores, maxRawItems, NOW);

        // 输出长度 <= maxRawItems
        assert(
          result.length <= maxRawItems,
          `输出长度 ${result.length} 超过 maxRawItems ${maxRawItems}`,
        );
        // 输出长度 <= 输入长度
        assert(
          result.length <= items.length,
          `输出长度 ${result.length} 超过输入长度 ${items.length}`,
        );
      },
    ),
    { numRuns: 200 },
  );
});

Deno.test("Property 3: 空输入返回空数组", () => {
  fc.assert(
    fc.property(
      fc.integer({ min: 1, max: 20 }),
      (maxRawItems) => {
        const result = applyDecayWeights([], new Map(), maxRawItems, NOW);
        assertEquals(result.length, 0, "空输入应返回空数组");
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 3: maxRawItems 为 0 或负数时返回空数组", () => {
  fc.assert(
    fc.property(
      fc.array(
        fc.integer({ min: 0, max: 100 }),
        { minLength: 1, maxLength: 10 },
      ),
      fc.integer({ min: -10, max: 0 }),
      (dayOffsets, maxRawItems) => {
        const items = dayOffsets.map((d, i) => makeItem(`ref_${i}`, NOW - d * DAY_MS));
        const scores = new Map<string, number>();
        items.forEach((item) => scores.set(item.ref, 0.5));

        const result = applyDecayWeights(items, scores, maxRawItems, NOW);
        assertEquals(result.length, 0, `maxRawItems=${maxRawItems} 应返回空数组`);
      },
    ),
    { numRuns: 100 },
  );
});

// ---------- Property 4: Mid-term memory fallback ----------

// Feature: memory-system-evolution, Property 4: Mid-term memory fallback
Deno.test("Property 4: 近期不足 3 条时保留至少 1 条中期记忆", () => {
  fc.assert(
    fc.property(
      // 生成 0–2 条近期记忆（0–7 天）
      fc.array(
        fc.integer({ min: 0, max: 7 }),
        { minLength: 0, maxLength: 2 },
      ),
      // 生成 1–5 条中期记忆（8–90 天）
      fc.array(
        fc.integer({ min: 8, max: 90 }),
        { minLength: 1, maxLength: 5 },
      ),
      // 可选：生成 0–3 条远期记忆（91+ 天）
      fc.array(
        fc.integer({ min: 91, max: 300 }),
        { minLength: 0, maxLength: 3 },
      ),
      fc.integer({ min: 1, max: 20 }),
      (recentDays, midDays, oldDays, maxRawItems) => {
        // 组合所有条目
        const allDays = [...recentDays, ...midDays, ...oldDays];
        const items = allDays.map((d, i) => makeItem(`ref_${i}`, NOW - d * DAY_MS));
        const scores = new Map<string, number>();
        items.forEach((item) => scores.set(item.ref, 0.5));

        const result = applyDecayWeights(items, scores, maxRawItems, NOW);

        // 如果结果为空（maxRawItems 限制或输入为空），跳过验证
        if (result.length === 0) return;

        // 检查输出中是否包含至少 1 条中期记忆（8–90 天）
        const hasMidTerm = result.some((item) => {
          const created = item.createdAt as number;
          const days = (NOW - created) / DAY_MS;
          return days >= 8 && days <= 90;
        });

        assert(
          hasMidTerm,
          `近期记忆 ${recentDays.length} 条（< 3），应至少保留 1 条中期记忆，但输出中未找到`,
        );
      },
    ),
    { numRuns: 200 },
  );
});

Deno.test("Property 4: 近期 >= 3 条时不强制保留中期记忆", () => {
  // 这是一个反向验证：当近期记忆充足时，中期兜底不应干扰正常排序
  fc.assert(
    fc.property(
      // 生成 3–10 条近期记忆（0–7 天），确保近期充足
      fc.array(
        fc.integer({ min: 0, max: 7 }),
        { minLength: 3, maxLength: 10 },
      ),
      fc.integer({ min: 3, max: 15 }),
      (recentDays, maxRawItems) => {
        const items = recentDays.map((d, i) => makeItem(`ref_${i}`, NOW - d * DAY_MS));
        const scores = new Map<string, number>();
        items.forEach((item, i) => scores.set(item.ref, 1.0 - i * 0.05));

        const result = applyDecayWeights(items, scores, maxRawItems, NOW);

        // 全部为近期记忆，排序应严格按 finalScore 降序
        const finalScores = result.map((item) => {
          const relevance = scores.get(item.ref) ?? 0.5;
          const decay = computeDecayWeight(item.createdAt, item.memoryKind, NOW);
          return relevance * decay;
        });

        for (let i = 0; i < finalScores.length - 1; i++) {
          assert(
            finalScores[i] >= finalScores[i + 1],
            `近期充足时排序应严格降序，位置 ${i}: ${finalScores[i]} < ${finalScores[i + 1]}`,
          );
        }
      },
    ),
    { numRuns: 100 },
  );
});
