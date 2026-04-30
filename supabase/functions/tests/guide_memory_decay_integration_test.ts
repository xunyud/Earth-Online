// 单元测试：记忆衰减集成测试
// 覆盖 computeDecayWeight 边界值、semantic_memory 不衰减、中期记忆兜底、正常排序
// **Validates: Requirements 1.1, 1.2, 1.3, 1.4**

import {
  assertEquals,
  assert,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import {
  applyDecayWeights,
  computeDecayWeight,
} from "../_shared/guide_memory.ts";

// 固定参考时间，确保测试确定性
const NOW = new Date("2026-06-01T00:00:00Z").getTime();
const DAY_MS = 24 * 60 * 60 * 1000;

/** 构造测试用的 GuideStructuredMemoryItem */
function makeItem(
  ref: string,
  createdAt: string | number | null,
  memoryKind = "episodic_memory",
) {
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

// ========== 1. computeDecayWeight 边界值测试 ==========

Deno.test("computeDecayWeight: 第 0 天 → 权重 1.0", () => {
  // 刚创建的记忆，距今 0 天
  const createdAt = NOW;
  assertEquals(computeDecayWeight(createdAt, undefined, NOW), 1.0);
});

Deno.test("computeDecayWeight: 第 7 天 → 权重 1.0（边界，仍在 0–7 天区间）", () => {
  const createdAt = NOW - 7 * DAY_MS;
  assertEquals(computeDecayWeight(createdAt, undefined, NOW), 1.0);
});

Deno.test("computeDecayWeight: 第 8 天 → 权重 0.6（刚跨入 8–30 天区间）", () => {
  const createdAt = NOW - 8 * DAY_MS;
  assertEquals(computeDecayWeight(createdAt, undefined, NOW), 0.6);
});

Deno.test("computeDecayWeight: 第 30 天 → 权重 0.6（边界，仍在 8–30 天区间）", () => {
  const createdAt = NOW - 30 * DAY_MS;
  assertEquals(computeDecayWeight(createdAt, undefined, NOW), 0.6);
});

Deno.test("computeDecayWeight: 第 31 天 → 权重 0.3（刚跨入 31–90 天区间）", () => {
  const createdAt = NOW - 31 * DAY_MS;
  assertEquals(computeDecayWeight(createdAt, undefined, NOW), 0.3);
});

Deno.test("computeDecayWeight: 第 90 天 → 权重 0.3（边界，仍在 31–90 天区间）", () => {
  const createdAt = NOW - 90 * DAY_MS;
  assertEquals(computeDecayWeight(createdAt, undefined, NOW), 0.3);
});

Deno.test("computeDecayWeight: 第 91 天 → 权重 0.1（刚跨入 91+ 天区间）", () => {
  const createdAt = NOW - 91 * DAY_MS;
  assertEquals(computeDecayWeight(createdAt, undefined, NOW), 0.1);
});

// ========== 2. semantic_memory 始终不衰减 ==========

Deno.test("computeDecayWeight: semantic_memory 第 0 天 → 1.0", () => {
  assertEquals(computeDecayWeight(NOW, "semantic_memory", NOW), 1.0);
});

Deno.test("computeDecayWeight: semantic_memory 第 30 天 → 1.0", () => {
  const createdAt = NOW - 30 * DAY_MS;
  assertEquals(computeDecayWeight(createdAt, "semantic_memory", NOW), 1.0);
});

Deno.test("computeDecayWeight: semantic_memory 第 91 天 → 1.0", () => {
  const createdAt = NOW - 91 * DAY_MS;
  assertEquals(computeDecayWeight(createdAt, "semantic_memory", NOW), 1.0);
});

Deno.test("computeDecayWeight: semantic_memory 第 365 天 → 1.0", () => {
  const createdAt = NOW - 365 * DAY_MS;
  assertEquals(computeDecayWeight(createdAt, "semantic_memory", NOW), 1.0);
});

// ========== 3. applyDecayWeights 中期记忆兜底 ==========

Deno.test("applyDecayWeights: 近期不足时保留至少 1 条中期记忆", () => {
  // 2 条近期（第 1、2 天）、3 条中期（第 15、20、25 天）、2 条远期（第 100、200 天）
  const items = [
    makeItem("recent_1", NOW - 1 * DAY_MS),
    makeItem("recent_2", NOW - 2 * DAY_MS),
    makeItem("mid_1", NOW - 15 * DAY_MS),
    makeItem("mid_2", NOW - 20 * DAY_MS),
    makeItem("mid_3", NOW - 25 * DAY_MS),
    makeItem("old_1", NOW - 100 * DAY_MS),
    makeItem("old_2", NOW - 200 * DAY_MS),
  ];

  // 所有条目赋予相同的相关性分数，排除相关性对排序的干扰
  const scores = new Map<string, number>();
  for (const item of items) scores.set(item.ref, 0.5);

  const result = applyDecayWeights(items, scores, 3, NOW);

  // 输出应包含 3 条
  assertEquals(result.length, 3);

  // 至少 1 条中期记忆（ref 以 "mid_" 开头，即 8–90 天范围）
  const midTermCount = result.filter((item) => {
    const days = (NOW - (item.createdAt as number)) / DAY_MS;
    return days >= 8 && days <= 90;
  }).length;

  assert(midTermCount >= 1, `应至少保留 1 条中期记忆，实际 ${midTermCount} 条`);
});

// ========== 4. 正常排序（无兜底触发） ==========

Deno.test("applyDecayWeights: 近期充足时按 relevance × decayWeight 降序排列", () => {
  // 5 条近期记忆（第 1–5 天），赋予不同的相关性分数
  const items = [
    makeItem("a", NOW - 1 * DAY_MS),
    makeItem("b", NOW - 2 * DAY_MS),
    makeItem("c", NOW - 3 * DAY_MS),
    makeItem("d", NOW - 4 * DAY_MS),
    makeItem("e", NOW - 5 * DAY_MS),
  ];

  const scores = new Map<string, number>([
    ["a", 0.3],
    ["b", 0.9],
    ["c", 0.5],
    ["d", 0.7],
    ["e", 0.1],
  ]);

  const result = applyDecayWeights(items, scores, 5, NOW);

  // 全部在 0–7 天区间，decayWeight 均为 1.0，最终分数 = relevance
  // 期望排序：b(0.9) > d(0.7) > c(0.5) > a(0.3) > e(0.1)
  assertEquals(result.length, 5);
  assertEquals(result[0].ref, "b");
  assertEquals(result[1].ref, "d");
  assertEquals(result[2].ref, "c");
  assertEquals(result[3].ref, "a");
  assertEquals(result[4].ref, "e");

  // 验证降序性质
  const finalScores = result.map((item) => {
    const relevance = scores.get(item.ref) ?? 0.5;
    const decay = computeDecayWeight(item.createdAt, item.memoryKind, NOW);
    return relevance * decay;
  });

  for (let i = 0; i < finalScores.length - 1; i++) {
    assert(
      finalScores[i] >= finalScores[i + 1],
      `位置 ${i}(${finalScores[i]}) 应 >= 位置 ${i + 1}(${finalScores[i + 1]})`,
    );
  }
});
