// Feature: memory-moat, Property 13: Muted memory filtering
// **Validates: Requirements 10.1, 10.2, 10.3**
//
// 属性测试：验证 shouldKeepStructuredMemoryItem 对各种 sourceStatus 值的过滤行为。
// - muted 状态 → 返回 false
// - inactive 状态 → 返回 false
// - active 状态（无任务关联过滤）→ 返回 true
// 使用空 taskState 隔离 sourceStatus 过滤逻辑。

import { assert } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";
import { shouldKeepStructuredMemoryItem } from "../_shared/guide_memory.ts";
import type { GuideStructuredMemoryItem } from "../_shared/guide_memory.ts";

// ---------- 辅助工厂函数 ----------

/** 构造测试用的结构化记忆条目，仅 sourceStatus 可变 */
function makeItem(sourceStatus: string): GuideStructuredMemoryItem {
  return {
    ref: `mem-${Math.random().toString(36).slice(2, 8)}`,
    rawText: "测试记忆内容",
    displayText: "测试记忆内容",
    memoryKind: "task_event",
    sourceTaskId: "",
    sourceTaskTitle: "",
    sourceStatus,
    createdAt: new Date().toISOString(),
  };
}

/** 空 taskState，隔离 sourceStatus 过滤逻辑 */
const emptyTaskState = {
  activeTaskIds: new Set<string>(),
  deletedTaskIds: new Set<string>(),
  deletedTaskTitleKeys: new Set<string>(),
};

// ---------- Property 13: Muted memory filtering ----------

// Feature: memory-moat, Property 13: Muted memory filtering
// muted 状态的记忆条目始终被过滤（返回 false）
Deno.test("Property 13: sourceStatus 为 muted 时返回 false", () => {
  fc.assert(
    fc.property(
      // 生成随机 ref 和 rawText，确保 muted 过滤与其他字段无关
      fc.string({ minLength: 1, maxLength: 50 }),
      fc.string({ minLength: 1, maxLength: 100 }),
      fc.constantFrom("task_event", "dialog_event", "generic"),
      (ref: string, rawText: string, memoryKind: string) => {
        const item: GuideStructuredMemoryItem = {
          ref,
          rawText,
          displayText: rawText,
          memoryKind,
          sourceTaskId: "",
          sourceTaskTitle: "",
          sourceStatus: "muted",
          createdAt: new Date().toISOString(),
        };

        const result = shouldKeepStructuredMemoryItem(item, emptyTaskState);
        assert(
          result === false,
          `sourceStatus 为 "muted" 时应返回 false，实际为 ${result}（ref="${ref}", memoryKind="${memoryKind}"）`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 13: Muted memory filtering
// inactive 状态的记忆条目同样被过滤（返回 false）
Deno.test("Property 13: sourceStatus 为 inactive 时返回 false", () => {
  fc.assert(
    fc.property(
      fc.string({ minLength: 1, maxLength: 50 }),
      fc.string({ minLength: 1, maxLength: 100 }),
      fc.constantFrom("task_event", "dialog_event", "generic"),
      (ref: string, rawText: string, memoryKind: string) => {
        const item: GuideStructuredMemoryItem = {
          ref,
          rawText,
          displayText: rawText,
          memoryKind,
          sourceTaskId: "",
          sourceTaskTitle: "",
          sourceStatus: "inactive",
          createdAt: new Date().toISOString(),
        };

        const result = shouldKeepStructuredMemoryItem(item, emptyTaskState);
        assert(
          result === false,
          `sourceStatus 为 "inactive" 时应返回 false，实际为 ${result}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 13: Muted memory filtering
// active 状态且无任务关联时返回 true（不被过滤）
Deno.test("Property 13: sourceStatus 为 active 且无任务关联时返回 true", () => {
  fc.assert(
    fc.property(
      fc.string({ minLength: 1, maxLength: 50 }),
      fc.string({ minLength: 1, maxLength: 100 }),
      fc.constantFrom("task_event", "dialog_event", "generic"),
      (ref: string, rawText: string, memoryKind: string) => {
        const item: GuideStructuredMemoryItem = {
          ref,
          rawText,
          displayText: rawText,
          memoryKind,
          sourceTaskId: "",
          sourceTaskTitle: "",
          sourceStatus: "active",
          createdAt: new Date().toISOString(),
        };

        const result = shouldKeepStructuredMemoryItem(item, emptyTaskState);
        assert(
          result === true,
          `sourceStatus 为 "active" 且无任务关联时应返回 true，实际为 ${result}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// Feature: memory-moat, Property 13: Muted memory filtering
// 随机 sourceStatus 值列表中，muted 和 inactive 始终被过滤，其他值不被过滤
Deno.test("Property 13: 随机 sourceStatus 值的过滤一致性", () => {
  fc.assert(
    fc.property(
      fc.array(
        fc.oneof(
          // 已知状态值
          fc.constantFrom("active", "inactive", "muted"),
          // 随机字符串模拟未知状态
          fc.stringOf(fc.char(), { minLength: 1, maxLength: 20 }),
        ),
        { minLength: 1, maxLength: 20 },
      ),
      (statusList: string[]) => {
        for (const status of statusList) {
          const item = makeItem(status);
          const result = shouldKeepStructuredMemoryItem(item, emptyTaskState);

          if (status === "muted" || status === "inactive") {
            assert(
              result === false,
              `sourceStatus 为 "${status}" 时应返回 false，实际为 ${result}`,
            );
          } else {
            // 非 muted/inactive 状态，且无任务关联 → 应返回 true
            assert(
              result === true,
              `sourceStatus 为 "${status}" 时（非 muted/inactive）应返回 true，实际为 ${result}`,
            );
          }
        }
      },
    ),
    { numRuns: 100 },
  );
});
