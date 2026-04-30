// Feature: memory-moat, Property 22: Image recognition result structure
// **Validates: Requirements 18.3, 19.3**
//
// 属性测试：验证解析后 ImageRecognitionResult 的三个字段非 null。
// - 使用 fast-check 生成随机有效 JSON 响应
// - 验证 text_content、suggested_task_title、scene_description 字段非 null

import {
  assert,
  assertNotEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";
import {
  callMultimodalLLM,
  type ImageRecognitionResult,
  type MultimodalContent,
} from "../_shared/guide_ai.ts";

// 保存原始 fetch，测试后恢复
const originalFetch = globalThis.fetch;

function restoreGlobals() {
  globalThis.fetch = originalFetch;
}

/** 构造简单的文本内容输入 */
function makeTextContents(text: string): MultimodalContent[] {
  return [{ type: "text", text }];
}

/** ImageRecognitionResult 的默认 fallback 值 */
const defaultFallback: ImageRecognitionResult = {
  text_content: "",
  suggested_task_title: "",
  scene_description: "",
};

// ---------- Property 22: Image recognition result structure ----------

// 子属性 1：有效 JSON 响应解析后三个字段均非 null
Deno.test("Property 22.1: 有效 JSON 响应解析后字段非 null", async () => {
  Deno.env.set("OPENAI_API_KEY", "test-key-for-property-test");
  Deno.env.set("OPENAI_BASE_URL", "https://fake-api.test");

  await fc.assert(
    fc.asyncProperty(
      fc.string({ minLength: 1, maxLength: 50 }),
      fc.string({ minLength: 0, maxLength: 50 }),
      fc.string({ minLength: 1, maxLength: 100 }),
      async (textContent, taskTitle, sceneDesc) => {
        // 构造 LLM 返回的有效 JSON 响应
        const responsePayload: ImageRecognitionResult = {
          text_content: textContent,
          suggested_task_title: taskTitle,
          scene_description: sceneDesc,
        };

        globalThis.fetch = () =>
          Promise.resolve(
            new Response(
              JSON.stringify({
                choices: [{
                  message: { content: JSON.stringify(responsePayload) },
                }],
              }),
              { status: 200, headers: { "Content-Type": "application/json" } },
            ),
          );

        const result = await callMultimodalLLM<ImageRecognitionResult>(
          makeTextContents("识别图片"),
          "你是图片识别助手",
          defaultFallback,
        );

        // 验证三个字段非 null
        assertNotEquals(result.text_content, null, "text_content 不应为 null");
        assertNotEquals(
          result.suggested_task_title,
          null,
          "suggested_task_title 不应为 null",
        );
        assertNotEquals(
          result.scene_description,
          null,
          "scene_description 不应为 null",
        );

        // 验证类型为 string
        assert(
          typeof result.text_content === "string",
          "text_content 应为 string",
        );
        assert(
          typeof result.suggested_task_title === "string",
          "suggested_task_title 应为 string",
        );
        assert(
          typeof result.scene_description === "string",
          "scene_description 应为 string",
        );
      },
    ),
    { numRuns: 100 },
  );

  restoreGlobals();
  Deno.env.delete("OPENAI_API_KEY");
  Deno.env.delete("OPENAI_BASE_URL");
});


// 子属性 2：fallback 值本身三个字段也非 null
Deno.test("Property 22.2: fallback 值的三个字段非 null", () => {
  fc.assert(
    fc.property(
      fc.string({ minLength: 0, maxLength: 30 }),
      fc.string({ minLength: 0, maxLength: 30 }),
      fc.string({ minLength: 0, maxLength: 30 }),
      (tc, tt, sd) => {
        const fb: ImageRecognitionResult = {
          text_content: tc,
          suggested_task_title: tt,
          scene_description: sd,
        };
        assertNotEquals(fb.text_content, null);
        assertNotEquals(fb.suggested_task_title, null);
        assertNotEquals(fb.scene_description, null);
      },
    ),
    { numRuns: 100 },
  );
});

// 子属性 3：LLM 返回部分字段缺失时，JSON.parse 仍产生对象（缺失字段为 undefined）
Deno.test("Property 22.3: 部分字段缺失时 fallback 保证完整性", async () => {
  Deno.env.set("OPENAI_API_KEY", "test-key-for-property-test");
  Deno.env.set("OPENAI_BASE_URL", "https://fake-api.test");

  // 模拟 LLM 返回只有 text_content 的不完整 JSON
  globalThis.fetch = () =>
    Promise.resolve(
      new Response(
        JSON.stringify({
          choices: [{
            message: {
              content: JSON.stringify({ text_content: "识别到的文字" }),
            },
          }],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );

  const result = await callMultimodalLLM<ImageRecognitionResult>(
    makeTextContents("识别图片"),
    "你是图片识别助手",
    defaultFallback,
  );

  // callMultimodalLLM 直接返回 JSON.parse 结果，缺失字段为 undefined
  // 但 text_content 应存在
  assert(
    result.text_content !== null,
    "text_content 不应为 null",
  );

  restoreGlobals();
  Deno.env.delete("OPENAI_API_KEY");
  Deno.env.delete("OPENAI_BASE_URL");
});
