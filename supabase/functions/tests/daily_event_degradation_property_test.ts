// Feature: memory-moat, Property 20: Daily event memory degradation
// **Validates: Requirements 16.1, 16.3**
//
// 属性测试：验证 generateDailyEvent 的记忆降级逻辑。
// - 记忆不足 3 条时使用 fallback 路径（shouldUseFallback 返回 true）
// - 记忆 >= 3 条时 shouldUseFallback 返回 false，prompt 应包含行为摘要
// - extractBehaviorSummary 从 packed_context 中正确提取行为信号区域

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";
import {
  extractBehaviorSummary,
  shouldUseFallback,
} from "../_shared/guide_ai.ts";

// ---------- Property 20: Daily event memory degradation ----------

// 子属性 1：记忆不足 3 条时 shouldUseFallback 返回 true
Deno.test("Property 20.1: 记忆条数 < 3 时 shouldUseFallback 返回 true", () => {
  fc.assert(
    fc.property(
      fc.integer({ min: 0, max: 2 }),
      (count: number) => {
        assertEquals(
          shouldUseFallback(count),
          true,
          `记忆条数 ${count} < 3，应使用 fallback，但返回 false`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// 子属性 2：记忆 >= 3 条时 shouldUseFallback 返回 false
Deno.test("Property 20.2: 记忆条数 >= 3 时 shouldUseFallback 返回 false", () => {
  fc.assert(
    fc.property(
      fc.integer({ min: 3, max: 1000 }),
      (count: number) => {
        assertEquals(
          shouldUseFallback(count),
          false,
          `记忆条数 ${count} >= 3，不应使用 fallback，但返回 true`,
        );
      },
    ),
    { numRuns: 200 },
  );
});

// 子属性 3：随机长度（0–10）的记忆列表，验证降级阈值一致性
Deno.test("Property 20.3: 随机长度 0–10 的记忆列表，阈值 3 分界正确", () => {
  fc.assert(
    fc.property(
      fc.integer({ min: 0, max: 10 }),
      (count: number) => {
        const result = shouldUseFallback(count);
        if (count < 3) {
          assertEquals(result, true, `count=${count} 应降级`);
        } else {
          assertEquals(result, false, `count=${count} 不应降级`);
        }
      },
    ),
    { numRuns: 200 },
  );
});

// 子属性 4：extractBehaviorSummary 对含行为信号的 packed_context 返回非空摘要
Deno.test("Property 20.4: 含行为信号的 packed_context 提取出非空摘要", () => {
  // 生成随机行为信号行
  const signalLineArb = fc.stringOf(
    fc.constantFrom(
      ..."连续推进稳定清盘夜间高强度恢复习惯链abcdefghijklmnopqrstuvwxyz".split(""),
    ),
    { minLength: 2, maxLength: 30 },
  );

  fc.assert(
    fc.property(
      fc.array(signalLineArb, { minLength: 1, maxLength: 5 }),
      (signals: string[]) => {
        // 构造包含【行为信号】区域的 packed_context
        const signalSection = signals
          .map((s, i) => `${i + 1}. ${s}`)
          .join("\n");
        const packedContext =
          `【当前事实】\n1. 今天完成了 3 项任务\n\n【历史回调】\n1. 长期习惯\n\n【行为信号】\n${signalSection}`;

        const summary = extractBehaviorSummary(packedContext);
        assert(
          summary.length > 0,
          `含 ${signals.length} 条行为信号的 packed_context 应提取出非空摘要，实际为空`,
        );
        // 验证摘要中包含原始信号内容（去掉序号后）
        for (const signal of signals) {
          if (signal.trim()) {
            assert(
              summary.includes(signal.trim()),
              `摘要应包含信号 "${signal.trim()}"，实际摘要: "${summary}"`,
            );
          }
        }
      },
    ),
    { numRuns: 100 },
  );
});

// 子属性 5：extractBehaviorSummary 对空或无行为信号的 packed_context 返回空字符串
Deno.test("Property 20.5: 空或无行为信号的 packed_context 返回空字符串", () => {
  // 空字符串
  assertEquals(extractBehaviorSummary(""), "");

  // 不含【行为信号】区域的随机文本
  fc.assert(
    fc.property(
      fc.string({ minLength: 0, maxLength: 200 }).filter(
        (s) => !s.includes("【行为信号】"),
      ),
      (text: string) => {
        assertEquals(
          extractBehaviorSummary(text),
          "",
          `不含【行为信号】的文本应返回空字符串`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// 子属性 6：shouldUseFallback 对负数输入也返回 true（防御性）
Deno.test("Property 20.6: 负数输入时 shouldUseFallback 返回 true", () => {
  fc.assert(
    fc.property(
      fc.integer({ min: -1000, max: -1 }),
      (count: number) => {
        assertEquals(
          shouldUseFallback(count),
          true,
          `负数 count=${count} 应使用 fallback`,
        );
      },
    ),
    { numRuns: 100 },
  );
});
