// Feature: memory-system-evolution, Property 1: Decay weight computation
// **Validates: Requirements 1.1, 2.3**
//
// 属性测试：验证 computeDecayWeight 在任意输入下返回正确的衰减权重区间。
// 使用 fast-check 生成随机时间戳和 memoryKind，覆盖所有权重分段和特殊规则。

import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";
import { computeDecayWeight } from "../_shared/guide_memory.ts";

// 固定参考时间，确保测试确定性
const NOW = new Date("2026-06-01T00:00:00Z").getTime();
const DAY_MS = 24 * 60 * 60 * 1000;

Deno.test("Property 1: 随机天数偏移下权重区间正确", () => {
  fc.assert(
    fc.property(
      // 生成 0–400 天的随机偏移量，覆盖所有衰减区间
      fc.integer({ min: 0, max: 400 }),
      // 生成随机 memoryKind：semantic_memory、episodic_memory 或 undefined
      fc.constantFrom("semantic_memory", "episodic_memory", undefined),
      (dayOffset: number, memoryKind: string | undefined) => {
        const createdAt = NOW - dayOffset * DAY_MS;
        const weight = computeDecayWeight(createdAt, memoryKind, NOW);

        // 语义记忆始终返回 1.0，不受时间衰减影响
        if (memoryKind === "semantic_memory") {
          assertEquals(weight, 1.0, `semantic_memory 应始终为 1.0，实际 ${weight}`);
          return;
        }

        // 非语义记忆按天数区间验证权重
        if (dayOffset <= 7) {
          assertEquals(weight, 1.0, `0–7 天应为 1.0，dayOffset=${dayOffset}，实际 ${weight}`);
        } else if (dayOffset <= 30) {
          assertEquals(weight, 0.6, `8–30 天应为 0.6，dayOffset=${dayOffset}，实际 ${weight}`);
        } else if (dayOffset <= 90) {
          assertEquals(weight, 0.3, `31–90 天应为 0.3，dayOffset=${dayOffset}，实际 ${weight}`);
        } else {
          assertEquals(weight, 0.1, `91+ 天应为 0.1，dayOffset=${dayOffset}，实际 ${weight}`);
        }
      },
    ),
    { numRuns: 200 }, // 至少 100 次迭代，设为 200 增强覆盖
  );
});

Deno.test("Property 1: ISO 字符串格式的 createdAt 同样满足权重区间", () => {
  fc.assert(
    fc.property(
      fc.integer({ min: 0, max: 400 }),
      fc.constantFrom("episodic_memory", undefined),
      (dayOffset: number, memoryKind: string | undefined) => {
        // 使用 ISO 字符串而非数字时间戳
        const createdAtMs = NOW - dayOffset * DAY_MS;
        const createdAtStr = new Date(createdAtMs).toISOString();
        const weight = computeDecayWeight(createdAtStr, memoryKind, NOW);

        if (dayOffset <= 7) {
          assertEquals(weight, 1.0);
        } else if (dayOffset <= 30) {
          assertEquals(weight, 0.6);
        } else if (dayOffset <= 90) {
          assertEquals(weight, 0.3);
        } else {
          assertEquals(weight, 0.1);
        }
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 1: createdAt 为 null 时返回 0.1", () => {
  fc.assert(
    fc.property(
      fc.constantFrom("episodic_memory", "semantic_memory", undefined),
      (memoryKind: string | undefined) => {
        // semantic_memory 优先级高于 null 检查，始终返回 1.0
        if (memoryKind === "semantic_memory") {
          assertEquals(computeDecayWeight(null, memoryKind, NOW), 1.0);
        } else {
          assertEquals(computeDecayWeight(null, memoryKind, NOW), 0.1);
        }
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 1: createdAt 为无效字符串（NaN）时返回 0.1", () => {
  fc.assert(
    fc.property(
      // 生成不可解析为日期的随机字符串
      fc.stringOf(fc.constantFrom("x", "?", "!", "#", "abc"), { minLength: 1, maxLength: 10 }),
      fc.constantFrom("episodic_memory", undefined),
      (invalidStr: string, memoryKind: string | undefined) => {
        const weight = computeDecayWeight(invalidStr, memoryKind, NOW);
        assertEquals(weight, 0.1, `无效 createdAt "${invalidStr}" 应返回 0.1，实际 ${weight}`);
      },
    ),
    { numRuns: 100 },
  );
});

Deno.test("Property 1: semantic_memory 在任意时间戳下始终返回 1.0", () => {
  fc.assert(
    fc.property(
      // 生成任意 createdAt：数字时间戳、null、或 ISO 字符串
      fc.oneof(
        fc.integer({ min: 0, max: NOW }).map((ts) => ts as string | number | null),
        fc.constant(null as string | number | null),
        fc.integer({ min: 0, max: 400 }).map((d) =>
          new Date(NOW - d * DAY_MS).toISOString() as string | number | null
        ),
      ),
      (createdAt: string | number | null) => {
        const weight = computeDecayWeight(createdAt, "semantic_memory", NOW);
        assertEquals(weight, 1.0, `semantic_memory 应始终为 1.0，createdAt=${createdAt}`);
      },
    ),
    { numRuns: 100 },
  );
});
