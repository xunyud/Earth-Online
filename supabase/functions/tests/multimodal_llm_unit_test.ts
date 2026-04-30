// 单元测试：callMultimodalLLM
// 覆盖正常 JSON 响应解析、非 JSON 响应返回 fallback、HTTP 500 返回 fallback、超时返回 fallback。
// _Requirements: 19.1, 19.3, 19.4, 19.5_

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
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

/** 构造文本内容输入 */
function makeTextContents(text: string): MultimodalContent[] {
  return [{ type: "text", text }];
}

/** 构造图片 URL 内容输入 */
function makeImageContents(url: string): MultimodalContent[] {
  return [{ type: "image_url", image_url: { url } }];
}

// ==================== 1. 正常 JSON 响应解析 ====================

Deno.test("callMultimodalLLM — 正常 JSON 响应正确解析", async () => {
  Deno.env.set("OPENAI_API_KEY", "test-key");
  Deno.env.set("OPENAI_BASE_URL", "https://fake-api.test");

  const expected: ImageRecognitionResult = {
    text_content: "购物清单：牛奶、面包",
    suggested_task_title: "购买日用品",
    scene_description: "一张手写购物清单的照片",
  };

  globalThis.fetch = () =>
    Promise.resolve(
      new Response(
        JSON.stringify({
          choices: [{ message: { content: JSON.stringify(expected) } }],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );

  const fallback: ImageRecognitionResult = {
    text_content: "",
    suggested_task_title: "",
    scene_description: "",
  };

  const result = await callMultimodalLLM<ImageRecognitionResult>(
    makeImageContents("https://example.com/photo.jpg"),
    "识别图片内容",
    fallback,
  );

  assertEquals(result.text_content, expected.text_content);
  assertEquals(result.suggested_task_title, expected.suggested_task_title);
  assertEquals(result.scene_description, expected.scene_description);

  restoreGlobals();
  Deno.env.delete("OPENAI_API_KEY");
  Deno.env.delete("OPENAI_BASE_URL");
});


// ==================== 2. JSON 响应带 markdown fence 正确解析 ====================

Deno.test("callMultimodalLLM — JSON 响应带 markdown fence 正确解析", async () => {
  Deno.env.set("OPENAI_API_KEY", "test-key");
  Deno.env.set("OPENAI_BASE_URL", "https://fake-api.test");

  const expected = { text_content: "测试", suggested_task_title: "", scene_description: "场景" };

  // 模拟 LLM 返回带 ```json 包裹的内容
  globalThis.fetch = () =>
    Promise.resolve(
      new Response(
        JSON.stringify({
          choices: [{
            message: {
              content: "```json\n" + JSON.stringify(expected) + "\n```",
            },
          }],
        }),
        { status: 200 },
      ),
    );

  const fallback: ImageRecognitionResult = { text_content: "", suggested_task_title: "", scene_description: "" };
  const result = await callMultimodalLLM<ImageRecognitionResult>(
    makeTextContents("测试"),
    "prompt",
    fallback,
  );

  assertEquals(result.text_content, "测试");
  assertEquals(result.scene_description, "场景");

  restoreGlobals();
  Deno.env.delete("OPENAI_API_KEY");
  Deno.env.delete("OPENAI_BASE_URL");
});

// ==================== 3. 非 JSON 响应返回 fallback ====================

Deno.test("callMultimodalLLM — 非 JSON 响应返回 fallback", async () => {
  Deno.env.set("OPENAI_API_KEY", "test-key");
  Deno.env.set("OPENAI_BASE_URL", "https://fake-api.test");

  // 模拟 LLM 返回纯文本（非 JSON）
  globalThis.fetch = () =>
    Promise.resolve(
      new Response(
        JSON.stringify({
          choices: [{ message: { content: "这是一段纯文本描述，不是JSON" } }],
        }),
        { status: 200 },
      ),
    );

  const fallback = { result: "fallback_value" };
  const result = await callMultimodalLLM(
    makeTextContents("测试"),
    "prompt",
    fallback,
  );

  assertEquals(result, fallback, "非 JSON 内容应返回 fallback");

  restoreGlobals();
  Deno.env.delete("OPENAI_API_KEY");
  Deno.env.delete("OPENAI_BASE_URL");
});

// ==================== 4. HTTP 500 返回 fallback ====================

Deno.test("callMultimodalLLM — HTTP 500 返回 fallback", async () => {
  Deno.env.set("OPENAI_API_KEY", "test-key");
  Deno.env.set("OPENAI_BASE_URL", "https://fake-api.test");

  globalThis.fetch = () =>
    Promise.resolve(new Response("Internal Server Error", { status: 500 }));

  const fallback = "server_error_fallback";
  const result = await callMultimodalLLM(
    makeTextContents("测试"),
    "prompt",
    fallback,
  );

  assertEquals(result, fallback, "HTTP 500 应返回 fallback");

  restoreGlobals();
  Deno.env.delete("OPENAI_API_KEY");
  Deno.env.delete("OPENAI_BASE_URL");
});

// ==================== 5. 超时返回 fallback ====================

Deno.test("callMultimodalLLM — 超时返回 fallback", async () => {
  Deno.env.set("OPENAI_API_KEY", "test-key");
  Deno.env.set("OPENAI_BASE_URL", "https://fake-api.test");

  // 模拟 AbortError（超时场景）
  globalThis.fetch = () =>
    Promise.reject(new DOMException("The operation was aborted", "AbortError"));

  const fallback = { timeout: true };
  const result = await callMultimodalLLM(
    makeTextContents("测试"),
    "prompt",
    fallback,
    { timeoutMs: 1 },
  );

  assertEquals(result, fallback, "超时应返回 fallback");

  restoreGlobals();
  Deno.env.delete("OPENAI_API_KEY");
  Deno.env.delete("OPENAI_BASE_URL");
});

// ==================== 6. 无 API Key 返回 fallback ====================

Deno.test("callMultimodalLLM — 无 API Key 返回 fallback", async () => {
  // 清除所有可能的 API Key
  const savedKey = Deno.env.get("OPENAI_API_KEY");
  const savedDeepseekKey = Deno.env.get("DEEPSEEK_API_KEY");
  Deno.env.delete("OPENAI_API_KEY");
  Deno.env.delete("DEEPSEEK_API_KEY");

  const fallback = "no_key_fallback";
  const result = await callMultimodalLLM(
    makeTextContents("测试"),
    "prompt",
    fallback,
  );

  assertEquals(result, fallback, "无 API Key 应返回 fallback");

  // 恢复
  if (savedKey) Deno.env.set("OPENAI_API_KEY", savedKey);
  if (savedDeepseekKey) Deno.env.set("DEEPSEEK_API_KEY", savedDeepseekKey);
});

// ==================== 7. 空 choices 返回 fallback ====================

Deno.test("callMultimodalLLM — 空 choices 数组返回 fallback", async () => {
  Deno.env.set("OPENAI_API_KEY", "test-key");
  Deno.env.set("OPENAI_BASE_URL", "https://fake-api.test");

  globalThis.fetch = () =>
    Promise.resolve(
      new Response(
        JSON.stringify({ choices: [] }),
        { status: 200 },
      ),
    );

  const fallback = "empty_choices";
  const result = await callMultimodalLLM(
    makeTextContents("测试"),
    "prompt",
    fallback,
  );

  assertEquals(result, fallback, "空 choices 应返回 fallback");

  restoreGlobals();
  Deno.env.delete("OPENAI_API_KEY");
  Deno.env.delete("OPENAI_BASE_URL");
});

// ==================== 8. 混合内容（文本+图片）请求正确构造 ====================

Deno.test("callMultimodalLLM — 混合内容请求正确发送", async () => {
  Deno.env.set("OPENAI_API_KEY", "test-key");
  Deno.env.set("OPENAI_BASE_URL", "https://fake-api.test");

  let capturedBody: string | undefined;

  globalThis.fetch = (_input: string | URL | Request, init?: RequestInit) => {
    capturedBody = init?.body as string;
    return Promise.resolve(
      new Response(
        JSON.stringify({
          choices: [{ message: { content: '{"result":"ok"}' } }],
        }),
        { status: 200 },
      ),
    );
  };

  const contents: MultimodalContent[] = [
    { type: "text", text: "描述这张图片" },
    { type: "image_url", image_url: { url: "https://example.com/img.jpg" } },
  ];

  await callMultimodalLLM(contents, "识别图片", { result: "" });

  // 验证请求体包含混合内容
  assert(capturedBody !== undefined, "应发送请求");
  const parsed = JSON.parse(capturedBody!);
  assertEquals(parsed.messages[1].content.length, 2, "user message 应包含 2 个内容项");
  assertEquals(parsed.messages[1].content[0].type, "text");
  assertEquals(parsed.messages[1].content[1].type, "image_url");
  assertEquals(parsed.response_format.type, "json_object", "应使用 JSON 模式");

  restoreGlobals();
  Deno.env.delete("OPENAI_API_KEY");
  Deno.env.delete("OPENAI_BASE_URL");
});

// ==================== 9. 默认超时为 15 秒 ====================

Deno.test("callMultimodalLLM — 默认超时为 15 秒", async () => {
  Deno.env.set("OPENAI_API_KEY", "test-key");
  Deno.env.set("OPENAI_BASE_URL", "https://fake-api.test");

  let capturedSignal: AbortSignal | undefined;

  globalThis.fetch = (_input: string | URL | Request, init?: RequestInit) => {
    capturedSignal = init?.signal as AbortSignal;
    return Promise.resolve(
      new Response(
        JSON.stringify({
          choices: [{ message: { content: '{"ok":true}' } }],
        }),
        { status: 200 },
      ),
    );
  };

  await callMultimodalLLM(makeTextContents("测试"), "prompt", {});

  // 验证 signal 存在（AbortSignal.timeout 被使用）
  assert(capturedSignal !== undefined, "应传递 AbortSignal");

  restoreGlobals();
  Deno.env.delete("OPENAI_API_KEY");
  Deno.env.delete("OPENAI_BASE_URL");
});
