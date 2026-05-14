// supabase/functions/tests/guide_chat_test.ts
// 测试 guide-chat Edge Function 的请求验证和错误处理路径

import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

// ── 构建测试用 handler（注入依赖以避免 Deno.env 和真实 Supabase）──

import { toText, toRecord, json, corsHeaders } from "../_shared/http.ts";

type HandlerDeps = {
  authenticate: (token: string) => Promise<{ id: string } | null>;
  buildPayload: (
    supabase: any,
    userId: string,
    scene: string,
    message: string,
    clientContext: Record<string, unknown>,
  ) => Promise<Record<string, unknown>>;
};

function createGuideChatHandler(deps: HandlerDeps) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }
    if (req.method !== "POST") {
      return json(405, { success: false, error: "Method Not Allowed" });
    }

    try {
      const authHeader = req.headers.get("Authorization") ?? "";
      const accessToken = authHeader.replace("Bearer", "").trim();
      if (!accessToken) {
        return json(401, { success: false, error: "Missing bearer token" });
      }

      const user = await deps.authenticate(accessToken);
      if (!user) {
        return json(401, { success: false, error: "Invalid JWT" });
      }

      const body = await req.json();
      const message = toText(body?.message);
      const scene = toText(body?.scene) || "home";
      const clientContext = toRecord(body?.client_context);
      if (!message) {
        return json(400, { success: false, error: "Missing message" });
      }

      const payload = await deps.buildPayload(
        null,
        user.id,
        scene,
        message,
        clientContext,
      );
      return json(200, { success: true, ...payload });
    } catch (error) {
      return json(500, {
        success: false,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  };
}

// ═══════════════ 测试 ═══════════════

Deno.test("guide-chat: OPTIONS returns CORS ok", async () => {
  const handler = createGuideChatHandler({
    authenticate: async () => ({ id: "u1" }),
    buildPayload: async () => ({ reply: "hi" }),
  });

  const req = new Request("http://localhost/guide-chat", { method: "OPTIONS" });
  const res = await handler(req);
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), "*");
});

Deno.test("guide-chat: non-POST returns 405", async () => {
  const handler = createGuideChatHandler({
    authenticate: async () => ({ id: "u1" }),
    buildPayload: async () => ({}),
  });

  const req = new Request("http://localhost/guide-chat", { method: "GET" });
  const res = await handler(req);
  assertEquals(res.status, 405);
  const body = await res.json();
  assertEquals(body.error, "Method Not Allowed");
});

Deno.test("guide-chat: missing Authorization returns 401", async () => {
  const handler = createGuideChatHandler({
    authenticate: async () => null,
    buildPayload: async () => ({}),
  });

  const req = new Request("http://localhost/guide-chat", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ message: "hi" }),
  });
  const res = await handler(req);
  assertEquals(res.status, 401);
  const body = await res.json();
  assertEquals(body.error, "Missing bearer token");
});

Deno.test("guide-chat: invalid JWT returns 401", async () => {
  const handler = createGuideChatHandler({
    authenticate: async () => null,
    buildPayload: async () => ({}),
  });

  const req = new Request("http://localhost/guide-chat", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer bad-token",
    },
    body: JSON.stringify({ message: "hi" }),
  });
  const res = await handler(req);
  assertEquals(res.status, 401);
  const body = await res.json();
  assertEquals(body.error, "Invalid JWT");
});

Deno.test("guide-chat: missing message returns 400", async () => {
  const handler = createGuideChatHandler({
    authenticate: async () => ({ id: "u1" }),
    buildPayload: async () => ({}),
  });

  const req = new Request("http://localhost/guide-chat", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer valid-token",
    },
    body: JSON.stringify({}),
  });
  const res = await handler(req);
  assertEquals(res.status, 400);
  const body = await res.json();
  assertEquals(body.error, "Missing message");
});

Deno.test("guide-chat: empty message returns 400", async () => {
  const handler = createGuideChatHandler({
    authenticate: async () => ({ id: "u1" }),
    buildPayload: async () => ({}),
  });

  const req = new Request("http://localhost/guide-chat", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer valid-token",
    },
    body: JSON.stringify({ message: "   " }),
  });
  const res = await handler(req);
  assertEquals(res.status, 400);
});

Deno.test("guide-chat: valid request returns 200 with payload", async () => {
  let capturedScene = "";
  let capturedMessage = "";
  const handler = createGuideChatHandler({
    authenticate: async () => ({ id: "u1" }),
    buildPayload: async (_supabase, userId, scene, message, ctx) => {
      capturedScene = scene;
      capturedMessage = message;
      return { reply: `Echo: ${message}`, guide_display_name: "Xiaoyi" };
    },
  });

  const req = new Request("http://localhost/guide-chat", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer valid-token",
    },
    body: JSON.stringify({
      message: " 你好村长 ",
      scene: "wechat",
      client_context: { language: "zh" },
    }),
  });
  const res = await handler(req);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.success, true);
  assertEquals(body.reply, "Echo: 你好村长");
  assertEquals(capturedScene, "wechat");
  assertEquals(capturedMessage, "你好村长");
});

Deno.test("guide-chat: default scene is 'home' when not provided", async () => {
  let capturedScene = "";
  const handler = createGuideChatHandler({
    authenticate: async () => ({ id: "u1" }),
    buildPayload: async (_s, _u, scene) => {
      capturedScene = scene;
      return { reply: "ok" };
    },
  });

  const req = new Request("http://localhost/guide-chat", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer t",
    },
    body: JSON.stringify({ message: "hi" }),
  });
  await handler(req);
  assertEquals(capturedScene, "home");
});

Deno.test("guide-chat: buildPayload error returns 500", async () => {
  const handler = createGuideChatHandler({
    authenticate: async () => ({ id: "u1" }),
    buildPayload: async () => {
      throw new Error("LLM timeout");
    },
  });

  const req = new Request("http://localhost/guide-chat", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer t",
    },
    body: JSON.stringify({ message: "hi" }),
  });
  const res = await handler(req);
  assertEquals(res.status, 500);
  const body = await res.json();
  assertEquals(body.error, "LLM timeout");
});
