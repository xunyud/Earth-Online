// Feature: memory-moat, Property 21: Multimodal LLM fallback on failure
// **Validates: Requirements 19.4**
//
// 属性测试：验证 callMultimodalLLM 在各种失败场景下始终返回 fallback 值，不抛异常。
// - HTTP 500 响应 → 返回 fallback
// - 超时 → 返回 fallback
// - 非 JSON 响应 → 返回 fallback
// - 无 API Key → 返回 fallback

import {
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";
import {
  callMultimodalLLM,
  type MultimodalContent,
} from "../_shared/guide_ai.ts";

// 保存原始 fetch 和环境变量，测试后恢复
const originalFetch = globalThis.fetch;

function restoreGlobals() {
  globalThis.fetch = originalFetch;
}

/** 构造简单的文本内容输入 */
function makeTextContents(text: string): MultimodalContent[] {
  return [{ type: "text", text }];
}

// ---------- Property 21: Multimodal LLM fallback on failure ----------

// 子属性 1：HTTP 500 响应时返回 fallback
Deno.test("Property 21.1: HTTP 500 响应时返回随机 fallback 值", async () => {
  // 确保有 API Key
  Deno.env.set("OPENAI_API_KEY", "test-key-for-property-test");
  Deno.env.set("OPENAI_BASE_URL", "https://fake-api.test");

  await fc.assert(
    fc.asyncProperty(
      fc.record({
        name: fc.string({ minLength: 1, maxLength: 20 }),
        value: fc.integer(),
      }),
      async (fallback) => {
        // 模拟 HTTP 500 响应
        globalThis.fetch = () =>
          Promise.resolve(new Response("Internal Server Error", { status: 500 }));

        const result = await callMultimodalLLM(
          makeTextContents("测试输入"),
          "测试 system prompt",
          fallback,
        );

        assertEquals(result, fallback, "HTTP 500 时应返回 fallback");
      },
    ),
    { numRuns: 100 },
  );

  restoreGlobals();
  Deno.env.delete("OPENAI_API_KEY");
  Deno.env.delete("OPENAI_BASE_URL");
});

// 子属性 2：fetch 抛出异常（模拟网络错误）时返回 fallback
Deno.test("Property 21.2: 网络错误时返回随机 fallback 值", async () => {
  Deno.env.set("OPENAI_API_KEY", "test-key-for-property-test");
  Deno.env.set("OPENAI_BASE_URL", "https://fake-api.test");

  await fc.assert(
    fc.asyncProperty(
      fc.string({ minLength: 1, maxLength: 50 }),
      async (fallbackStr) => {
        // 模拟网络错误
        globalThis.fetch = () =>
          Promise.reject(new Error("network error"));

        const result = await callMultimodalLLM(
          makeTextContents("测试"),
          "prompt",
          fallbackStr,
        );

        assertEquals(result, fallbackStr, "网络错误时应返回 fallback");
      },
    ),
    { numRuns: 100 },
  );

  restoreGlobals();
  Deno.env.delete("OPENAI_API_KEY");
  Deno.env.delete("OPENAI_BASE_URL");
});


// 子属性 3：非 JSON 响应体时返回 fallback
Deno.test("Property 21.3: 非 JSON 响应体时返回随机 fallback 值", async () => {
  Deno.env.set("OPENAI_API_KEY", "test-key-for-property-test");
  Deno.env.set("OPENAI_BASE_URL", "https://fake-api.test");

  await fc.assert(
    fc.asyncProperty(
      fc.integer({ min: -1000, max: 1000 }),
      async (fallbackNum) => {
        // 模拟返回非 JSON 的 200 响应（choices 中 content 不是有效 JSON）
        globalThis.fetch = () =>
          Promise.resolve(
            new Response(
              JSON.stringify({
                choices: [{ message: { content: "这不是JSON格式的内容" } }],
              }),
              { status: 200, headers: { "Content-Type": "application/json" } },
            ),
          );

        const result = await callMultimodalLLM(
          makeTextContents("测试"),
          "prompt",
          fallbackNum,
        );

        assertEquals(result, fallbackNum, "非 JSON 内容时应返回 fallback");
      },
    ),
    { numRuns: 100 },
  );

  restoreGlobals();
  Deno.env.delete("OPENAI_API_KEY");
  Deno.env.delete("OPENAI_BASE_URL");
});

// 子属性 4：超时时返回 fallback（模拟 AbortError）
Deno.test("Property 21.4: 超时时返回 fallback 值", async () => {
  Deno.env.set("OPENAI_API_KEY", "test-key-for-property-test");
  Deno.env.set("OPENAI_BASE_URL", "https://fake-api.test");

  const fallback = { timeout: true, data: "default" };

  // 模拟 fetch 抛出 AbortError（与 AbortSignal.timeout 行为一致）
  globalThis.fetch = (_input: string | URL | Request, init?: RequestInit) => {
    // 检查 signal 是否已中止，或直接抛出 AbortError 模拟超时
    const err = new DOMException("The operation was aborted", "AbortError");
    return Promise.reject(err);
  };

  const result = await callMultimodalLLM(
    makeTextContents("测试"),
    "prompt",
    fallback,
    { timeoutMs: 1 },
  );

  assertEquals(result, fallback, "超时时应返回 fallback");

  restoreGlobals();
  Deno.env.delete("OPENAI_API_KEY");
  Deno.env.delete("OPENAI_BASE_URL");
});

// 子属性 5：无 API Key 时直接返回 fallback
Deno.test("Property 21.5: 无 API Key 时返回随机 fallback 值", async () => {
  // 确保没有 API Key
  const savedKey = Deno.env.get("OPENAI_API_KEY");
  const savedDeepseekKey = Deno.env.get("DEEPSEEK_API_KEY");
  Deno.env.delete("OPENAI_API_KEY");
  Deno.env.delete("DEEPSEEK_API_KEY");

  await fc.assert(
    fc.asyncProperty(
      fc.array(fc.string(), { minLength: 0, maxLength: 5 }),
      async (fallbackArr) => {
        const result = await callMultimodalLLM(
          makeTextContents("测试"),
          "prompt",
          fallbackArr,
        );

        assertEquals(result, fallbackArr, "无 API Key 时应返回 fallback");
      },
    ),
    { numRuns: 100 },
  );

  // 恢复环境变量
  if (savedKey) Deno.env.set("OPENAI_API_KEY", savedKey);
  if (savedDeepseekKey) Deno.env.set("DEEPSEEK_API_KEY", savedDeepseekKey);
});
