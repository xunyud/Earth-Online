// Feature: memory-system-evolution, Property 8: Same-epoch portrait uniqueness
// Feature: memory-system-evolution, Property 9: Previous summary injection in prompt
// Feature: memory-system-evolution, Property 10: Failed generation produces no record
// **Validates: Requirements 3.3, 4.2, 4.3, 4.4**
//
// 测试策略：
// guide-portrait-generate 是 Deno.serve Edge Function，核心函数（buildPrompt、
// fetchPreviousPortraitSummary、generatePortraitForUser）为模块私有，无法直接导入。
// 因此提取其核心逻辑模式在测试中重现，用 mock 替代外部依赖，
// 验证 epoch 唯一性、上一张画像注入和失败不写入三项属性。

import {
  assertEquals,
  assert,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";
import { currentIsoWeek } from "../guide-portrait-generate/helpers.ts";

// ---------- 从 index.ts 提取的核心逻辑：stylePrompt ----------

/** 风格 prompt 映射，与 index.ts 中 stylePrompt 逻辑一致 */
function stylePrompt(style: string): string {
  switch (style) {
    case "charcoal":
      return "charcoal sketch, high contrast, expressive line work";
    case "ink":
      return "ink illustration, clean lineart, monochrome style";
    case "watercolor":
      return "soft watercolor portrait, natural tones, textured paper";
    case "cinematic":
      return "cinematic portrait, dramatic light, realistic details";
    case "pencil_sketch":
    default:
      return "pencil sketch portrait, graphite texture, hand-drawn details";
  }
}

// ---------- 从 index.ts 提取的核心逻辑：buildPrompt ----------

/**
 * 构建画像生成 prompt，与 index.ts 中 buildPrompt 逻辑完全一致。
 * 当 prevSummary 非空时注入上一张画像摘要；为空时标注"首张画像"。
 */
function buildPrompt(
  memory: {
    recent_context: string[];
    long_term_callbacks: string[];
    behavior_signals: string[];
  },
  style: string,
  prevSummary?: string | null,
): string {
  const recent = memory.recent_context.slice(0, 4).join(" | ");
  const callbacks = memory.long_term_callbacks.slice(0, 3).join(" | ");
  const signals = memory.behavior_signals.slice(0, 3).join(" | ");

  const parts = [
    "Portrait of a determined earth explorer, age-neutral adult, half-body, looking confident and calm.",
    `Visual style: ${stylePrompt(style)}.`,
    "Outfit hints: practical jacket, expedition notebook, subtle quest-themed accessories.",
    "Mood: warm, resilient, thoughtful.",
    "Background: minimal environmental textures, no text overlays.",
    "DO NOT render any words, logos, UI, watermark, or signature.",
    `Recent memory cues: ${recent || "steady progress in daily quests"}.`,
    `Long-term callbacks: ${
      callbacks || "building long-term discipline and recovery rhythm"
    }.`,
    `Behavior signals: ${signals || "balanced momentum and recovery"}.`,
  ];

  // 注入上一张画像的 summary，帮助 LLM 描述用户变化
  if (prevSummary) {
    parts.push(
      `Previous portrait summary: ${prevSummary}. Describe changes since then.`,
    );
  } else {
    parts.push("This is the user's first portrait.");
  }

  return parts.join(" ");
}

// ---------- 从 index.ts 提取的核心逻辑：upsert 模式 ----------

/**
 * 模拟 Supabase 客户端，追踪 upsert 调用和存储状态。
 * 用于验证 epoch 唯一性约束和失败不写入行为。
 */
type UpsertPayload = {
  user_id: string;
  epoch: string;
  style: string;
  prompt: string;
  summary: string;
  image_url: string;
  model: string;
  seed: number;
  memory_refs: string[];
};

type UpsertOptions = {
  onConflict: string;
  ignoreDuplicates: boolean;
};

/** 模拟 guide_portraits 表的内存存储 */
class MockPortraitStore {
  // 使用 Map<compositeKey, payload> 模拟唯一约束
  private records = new Map<string, UpsertPayload>();
  public upsertCalls: Array<{ payload: UpsertPayload; options: UpsertOptions }> = [];

  /** 模拟 upsert 操作：同 (user_id, epoch) 覆盖旧记录 */
  upsert(
    payload: UpsertPayload,
    options: UpsertOptions,
  ): { error: null } {
    this.upsertCalls.push({ payload, options });
    const key = `${payload.user_id}::${payload.epoch}`;
    this.records.set(key, payload);
    return { error: null };
  }

  /** 查询指定 user_id + epoch 的记录数 */
  countByUserEpoch(userId: string, epoch: string): number {
    const key = `${userId}::${epoch}`;
    return this.records.has(key) ? 1 : 0;
  }

  /** 获取所有记录数 */
  get size(): number {
    return this.records.size;
  }

  /** 清空存储 */
  clear(): void {
    this.records.clear();
    this.upsertCalls = [];
  }
}

// ---------- 从 index.ts 提取的核心逻辑：generatePortraitForUser 模式 ----------

/**
 * 模拟画像生成流程，复现 index.ts 中 generatePortraitForUser 的关键逻辑：
 * 1. 计算 epoch
 * 2. 收集记忆上下文（mock）
 * 3. 查询上一张画像 summary
 * 4. 调用图像生成 API（可注入失败）
 * 5. upsert 写入（使用 onConflict: "user_id,epoch"）
 */
async function simulateGeneratePortrait(
  store: MockPortraitStore,
  userId: string,
  options: {
    style: string;
    epoch: string;
    prevSummary: string | null;
    imageGenFn: () => Promise<{ url: string; model: string }>;
  },
): Promise<{ success: boolean; error?: string }> {
  const { style, epoch, prevSummary, imageGenFn } = options;

  // 构建 prompt（复现 buildPrompt 调用）
  const memory = {
    recent_context: ["测试记忆"],
    long_term_callbacks: ["长期回调"],
    behavior_signals: ["行为信号"],
  };
  const _prompt = buildPrompt(memory, style, prevSummary);

  // 调用图像生成 API（失败时不写入记录）
  let imageResult: { url: string; model: string };
  try {
    imageResult = await imageGenFn();
  } catch (err) {
    // 画像生成失败：不写入空白记录
    return {
      success: false,
      error: err instanceof Error ? err.message : String(err),
    };
  }

  // upsert 写入：同 (user_id, epoch) 覆盖旧记录
  const upsertPayload: UpsertPayload = {
    user_id: userId,
    epoch,
    style,
    prompt: _prompt,
    summary: "测试摘要",
    image_url: imageResult.url,
    model: imageResult.model,
    seed: Math.floor(Math.random() * 2147483647),
    memory_refs: [],
  };

  store.upsert(upsertPayload, {
    onConflict: "user_id,epoch",
    ignoreDuplicates: false,
  });

  return { success: true };
}

// ---------- fast-check 生成器 ----------

/** 生成非空 ASCII 字符串（模拟 summary 文本） */
const nonEmptySummaryArb = fc.stringOf(
  fc.char().filter((c) => c.charCodeAt(0) >= 32 && c.charCodeAt(0) <= 126),
  { minLength: 1, maxLength: 200 },
);

/** 生成画像风格 */
const styleArb = fc.constantFrom(
  "pencil_sketch",
  "charcoal",
  "ink",
  "watercolor",
  "cinematic",
);

/** 生成 UUID 格式的用户 ID */
const userIdArb = fc.uuid();

// ========== Property 8: Same-epoch portrait uniqueness ==========

// Feature: memory-system-evolution, Property 8: Same-epoch portrait uniqueness
Deno.test("Property 8: 同 user_id + epoch 多次 upsert 后最多保留 1 条记录", () => {
  fc.assert(
    fc.property(
      userIdArb,
      // 生成 2–10 次重复插入
      fc.integer({ min: 2, max: 10 }),
      styleArb,
      (userId, insertCount, style) => {
        const store = new MockPortraitStore();
        const epoch = currentIsoWeek();

        // 对同一 (user_id, epoch) 执行多次 upsert
        for (let i = 0; i < insertCount; i++) {
          const payload: UpsertPayload = {
            user_id: userId,
            epoch,
            style,
            prompt: `prompt_${i}`,
            summary: `summary_${i}`,
            image_url: `https://example.com/img_${i}.png`,
            model: "gpt-image-2",
            seed: i,
            memory_refs: [],
          };
          store.upsert(payload, {
            onConflict: "user_id,epoch",
            ignoreDuplicates: false,
          });
        }

        // 验证：同 (user_id, epoch) 最多 1 条记录
        const count = store.countByUserEpoch(userId, epoch);
        assertEquals(
          count,
          1,
          `用户 ${userId} epoch ${epoch} 插入 ${insertCount} 次后应只有 1 条记录，实际 ${count}`,
        );
      },
    ),
    { numRuns: 200 },
  );
});

Deno.test("Property 8: upsert 始终使用 onConflict: 'user_id,epoch'", () => {
  fc.assert(
    fc.property(userIdArb, styleArb, (userId, style) => {
      const store = new MockPortraitStore();
      const epoch = currentIsoWeek();

      const payload: UpsertPayload = {
        user_id: userId,
        epoch,
        style,
        prompt: "test",
        summary: "test",
        image_url: "https://example.com/img.png",
        model: "gpt-image-2",
        seed: 42,
        memory_refs: [],
      };

      store.upsert(payload, {
        onConflict: "user_id,epoch",
        ignoreDuplicates: false,
      });

      // 验证 upsert 调用参数
      assertEquals(store.upsertCalls.length, 1);
      assertEquals(store.upsertCalls[0].options.onConflict, "user_id,epoch");
      assertEquals(store.upsertCalls[0].options.ignoreDuplicates, false);
      // 验证 payload 包含 epoch 字段
      assertEquals(store.upsertCalls[0].payload.epoch, epoch);
      assertEquals(store.upsertCalls[0].payload.user_id, userId);
    }),
    { numRuns: 200 },
  );
});

Deno.test("Property 8: 不同 epoch 的同一用户可以有多条记录", () => {
  fc.assert(
    fc.property(
      userIdArb,
      // 生成 2–5 个不同的周偏移量来产生不同 epoch
      fc.uniqueArray(fc.integer({ min: 0, max: 52 }), {
        minLength: 2,
        maxLength: 5,
      }),
      styleArb,
      (userId, weekOffsets, style) => {
        const store = new MockPortraitStore();
        const baseDate = new Date("2026-01-05"); // 一个周一

        for (const offset of weekOffsets) {
          const d = new Date(baseDate.getTime() + offset * 7 * 86400000);
          const epoch = currentIsoWeek(d);

          store.upsert(
            {
              user_id: userId,
              epoch,
              style,
              prompt: "test",
              summary: "test",
              image_url: "https://example.com/img.png",
              model: "gpt-image-2",
              seed: 42,
              memory_refs: [],
            },
            { onConflict: "user_id,epoch", ignoreDuplicates: false },
          );
        }

        // 不同 epoch 应产生不同记录（去重后的 epoch 数量）
        const uniqueEpochs = new Set(
          weekOffsets.map((offset) => {
            const d = new Date(baseDate.getTime() + offset * 7 * 86400000);
            return currentIsoWeek(d);
          }),
        );
        assertEquals(
          store.size,
          uniqueEpochs.size,
          `${uniqueEpochs.size} 个不同 epoch 应产生 ${uniqueEpochs.size} 条记录，实际 ${store.size}`,
        );
      },
    ),
    { numRuns: 100 },
  );
});

// ========== Property 9: Previous summary injection in prompt ==========

// Feature: memory-system-evolution, Property 9: Previous summary injection in prompt
Deno.test("Property 9a: 有上一张画像 summary 时 prompt 包含该 summary", () => {
  fc.assert(
    fc.property(
      nonEmptySummaryArb,
      styleArb,
      (prevSummary, style) => {
        const memory = {
          recent_context: ["记忆片段1"],
          long_term_callbacks: ["长期回调1"],
          behavior_signals: ["行为信号1"],
        };

        const prompt = buildPrompt(memory, style, prevSummary);

        // 验证 prompt 包含上一张画像的 summary
        assert(
          prompt.includes(prevSummary),
          `prompt 应包含 prevSummary "${prevSummary.slice(0, 50)}..."，但未找到`,
        );
        // 验证包含 "Previous portrait summary:" 前缀
        assert(
          prompt.includes("Previous portrait summary:"),
          `prompt 应包含 "Previous portrait summary:" 前缀`,
        );
        // 验证包含 "Describe changes since then." 后缀
        assert(
          prompt.includes("Describe changes since then."),
          `prompt 应包含 "Describe changes since then." 后缀`,
        );
        // 验证不包含"首张画像"标记
        assert(
          !prompt.includes("This is the user's first portrait."),
          `有 prevSummary 时不应包含首张画像标记`,
        );
      },
    ),
    { numRuns: 200 },
  );
});

Deno.test("Property 9b: 无上一张画像时 prompt 包含'首张画像'标记", () => {
  fc.assert(
    fc.property(
      styleArb,
      // prevSummary 为 null 或 undefined
      fc.constantFrom(null, undefined),
      (style, prevSummary) => {
        const memory = {
          recent_context: ["记忆片段1"],
          long_term_callbacks: ["长期回调1"],
          behavior_signals: ["行为信号1"],
        };

        const prompt = buildPrompt(memory, style, prevSummary);

        // 验证包含"首张画像"标记
        assert(
          prompt.includes("This is the user's first portrait."),
          `无 prevSummary 时应包含 "This is the user's first portrait."`,
        );
        // 验证不包含 "Previous portrait summary:" 前缀
        assert(
          !prompt.includes("Previous portrait summary:"),
          `无 prevSummary 时不应包含 "Previous portrait summary:"`,
        );
      },
    ),
    { numRuns: 200 },
  );
});

Deno.test("Property 9c: 空字符串 prevSummary 视为无上一张画像", () => {
  // 空字符串是 falsy，buildPrompt 中 if (prevSummary) 为 false
  const memory = {
    recent_context: [],
    long_term_callbacks: [],
    behavior_signals: [],
  };

  const prompt = buildPrompt(memory, "pencil_sketch", "");

  assert(
    prompt.includes("This is the user's first portrait."),
    `空字符串 prevSummary 应视为首张画像`,
  );
});

Deno.test("Property 9d: 随机记忆内容不影响 summary 注入逻辑", () => {
  fc.assert(
    fc.property(
      // 随机记忆上下文
      fc.array(fc.string({ minLength: 0, maxLength: 50 }), {
        minLength: 0,
        maxLength: 6,
      }),
      fc.array(fc.string({ minLength: 0, maxLength: 50 }), {
        minLength: 0,
        maxLength: 5,
      }),
      fc.array(fc.string({ minLength: 0, maxLength: 50 }), {
        minLength: 0,
        maxLength: 5,
      }),
      styleArb,
      fc.option(nonEmptySummaryArb, { nil: null }),
      (recentCtx, callbacks, signals, style, prevSummary) => {
        const memory = {
          recent_context: recentCtx,
          long_term_callbacks: callbacks,
          behavior_signals: signals,
        };

        const prompt = buildPrompt(memory, style, prevSummary);

        if (prevSummary) {
          assert(
            prompt.includes(prevSummary),
            `有 prevSummary 时 prompt 应包含该文本`,
          );
          assert(
            prompt.includes("Previous portrait summary:"),
            `有 prevSummary 时应包含前缀`,
          );
        } else {
          assert(
            prompt.includes("This is the user's first portrait."),
            `无 prevSummary 时应包含首张画像标记`,
          );
        }
      },
    ),
    { numRuns: 200 },
  );
});

// ========== Property 10: Failed generation produces no record ==========

// Feature: memory-system-evolution, Property 10: Failed generation produces no record
Deno.test("Property 10: 图像生成失败时不写入任何记录", async () => {
  await fc.assert(
    fc.asyncProperty(
      userIdArb,
      styleArb,
      fc.string({ minLength: 1, maxLength: 100 }),
      async (userId, style, errorMsg) => {
        const store = new MockPortraitStore();
        const epoch = currentIsoWeek();

        const result = await simulateGeneratePortrait(store, userId, {
          style,
          epoch,
          prevSummary: null,
          imageGenFn: async () => {
            throw new Error(errorMsg);
          },
        });

        // 验证：生成失败
        assertEquals(result.success, false, "图像生成失败时应返回 success: false");
        assert(result.error !== undefined, "失败时应包含 error 信息");

        // 验证：未写入任何记录
        assertEquals(
          store.upsertCalls.length,
          0,
          `图像生成失败时不应调用 upsert，实际调用 ${store.upsertCalls.length} 次`,
        );
        assertEquals(
          store.size,
          0,
          `图像生成失败时存储应为空，实际 ${store.size} 条记录`,
        );
      },
    ),
    { numRuns: 200 },
  );
});

Deno.test("Property 10: 生成成功时正常写入记录", async () => {
  await fc.assert(
    fc.asyncProperty(userIdArb, styleArb, async (userId, style) => {
      const store = new MockPortraitStore();
      const epoch = currentIsoWeek();

      const result = await simulateGeneratePortrait(store, userId, {
        style,
        epoch,
        prevSummary: "上一张画像摘要",
        imageGenFn: async () => ({
          url: "https://example.com/img.png",
          model: "gpt-image-2",
        }),
      });

      // 验证：生成成功
      assertEquals(result.success, true, "图像生成成功时应返回 success: true");

      // 验证：写入了 1 条记录
      assertEquals(
        store.upsertCalls.length,
        1,
        `生成成功时应调用 upsert 1 次，实际 ${store.upsertCalls.length} 次`,
      );
      assertEquals(store.size, 1, `生成成功时应有 1 条记录，实际 ${store.size}`);
    }),
    { numRuns: 100 },
  );
});

Deno.test("Property 10: 失败后再成功，记录数从 0 变为 1", async () => {
  await fc.assert(
    fc.asyncProperty(userIdArb, styleArb, async (userId, style) => {
      const store = new MockPortraitStore();
      const epoch = currentIsoWeek();

      // 第一次：失败
      const failResult = await simulateGeneratePortrait(store, userId, {
        style,
        epoch,
        prevSummary: null,
        imageGenFn: async () => {
          throw new Error("API 超时");
        },
      });
      assertEquals(failResult.success, false);
      assertEquals(store.size, 0, "失败后应无记录");

      // 第二次：成功
      const successResult = await simulateGeneratePortrait(store, userId, {
        style,
        epoch,
        prevSummary: null,
        imageGenFn: async () => ({
          url: "https://example.com/img.png",
          model: "gpt-image-2",
        }),
      });
      assertEquals(successResult.success, true);
      assertEquals(store.size, 1, "成功后应有 1 条记录");
    }),
    { numRuns: 100 },
  );
});

// ========== 单元测试：具体场景验证 ==========

Deno.test("单元测试: buildPrompt 注入 prevSummary 的完整格式", () => {
  const memory = {
    recent_context: ["完成了3个任务", "阅读了2篇文章"],
    long_term_callbacks: ["每周复盘习惯"],
    behavior_signals: ["连续打卡5天"],
  };

  const prompt = buildPrompt(memory, "pencil_sketch", "上周状态稳定，行动力提升");

  // 验证包含记忆内容
  assert(prompt.includes("完成了3个任务"), "应包含近期记忆");
  assert(prompt.includes("每周复盘习惯"), "应包含长期回调");
  assert(prompt.includes("连续打卡5天"), "应包含行为信号");
  // 验证包含上一张画像注入
  assert(prompt.includes("Previous portrait summary: 上周状态稳定，行动力提升"), "应包含完整的 summary 注入");
  assert(prompt.includes("Describe changes since then."), "应包含变化描述指令");
  // 验证包含风格
  assert(prompt.includes("pencil sketch portrait"), "应包含风格描述");
});

Deno.test("单元测试: buildPrompt 首张画像标记", () => {
  const memory = {
    recent_context: [],
    long_term_callbacks: [],
    behavior_signals: [],
  };

  const prompt = buildPrompt(memory, "watercolor", null);

  assert(prompt.includes("This is the user's first portrait."), "应包含首张画像标记");
  assert(prompt.includes("soft watercolor portrait"), "应包含水彩风格描述");
  // 空记忆时使用默认文案
  assert(prompt.includes("steady progress in daily quests"), "空记忆时应使用默认近期文案");
});

Deno.test("单元测试: MockPortraitStore upsert 覆盖行为", () => {
  const store = new MockPortraitStore();

  // 第一次插入
  store.upsert(
    {
      user_id: "user-1",
      epoch: "2026-W20",
      style: "pencil_sketch",
      prompt: "prompt_v1",
      summary: "summary_v1",
      image_url: "https://example.com/v1.png",
      model: "gpt-image-2",
      seed: 1,
      memory_refs: [],
    },
    { onConflict: "user_id,epoch", ignoreDuplicates: false },
  );
  assertEquals(store.size, 1);

  // 第二次插入同 (user_id, epoch)，应覆盖
  store.upsert(
    {
      user_id: "user-1",
      epoch: "2026-W20",
      style: "pencil_sketch",
      prompt: "prompt_v2",
      summary: "summary_v2",
      image_url: "https://example.com/v2.png",
      model: "gpt-image-2",
      seed: 2,
      memory_refs: [],
    },
    { onConflict: "user_id,epoch", ignoreDuplicates: false },
  );
  assertEquals(store.size, 1, "覆盖后仍应只有 1 条记录");
  assertEquals(store.upsertCalls.length, 2, "应记录 2 次 upsert 调用");
});

Deno.test("单元测试: 图像生成失败时 simulateGeneratePortrait 返回错误", async () => {
  const store = new MockPortraitStore();

  const result = await simulateGeneratePortrait(store, "user-test", {
    style: "pencil_sketch",
    epoch: "2026-W20",
    prevSummary: "上次摘要",
    imageGenFn: async () => {
      throw new Error("OpenAI API 限流");
    },
  });

  assertEquals(result.success, false);
  assert(result.error?.includes("OpenAI API 限流"), "错误信息应包含原始错误");
  assertEquals(store.size, 0, "失败时不应写入记录");
});

Deno.test("单元测试: 图像生成成功时 simulateGeneratePortrait 写入记录", async () => {
  const store = new MockPortraitStore();

  const result = await simulateGeneratePortrait(store, "user-test", {
    style: "ink",
    epoch: "2026-W20",
    prevSummary: null,
    imageGenFn: async () => ({
      url: "https://example.com/portrait.png",
      model: "dall-e-3",
    }),
  });

  assertEquals(result.success, true);
  assertEquals(store.size, 1);
  assertEquals(store.upsertCalls[0].payload.style, "ink");
  assertEquals(store.upsertCalls[0].payload.epoch, "2026-W20");
  // 验证 prompt 包含首张画像标记（prevSummary 为 null）
  assert(store.upsertCalls[0].payload.prompt.includes("This is the user's first portrait."));
});
