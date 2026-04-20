import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { createParseQuestHandler } from "./index.ts";

Deno.test("parse-quest 在上游 LLM 401 时回退到基础任务解析", async () => {
  const handler = createParseQuestHandler({
    authenticate: async (accessToken: string) =>
      accessToken == "valid-token" ? { id: "user-1" } : null,
    callLlm: async () => {
      throw new Error("LLM API Error: 401 - invalid api key");
    },
  });

  const response = await handler(
    new Request("http://localhost/parse-quest", {
      method: "POST",
      headers: {
        "Authorization": "Bearer valid-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        text: "生成听歌任务",
        user_id: "user-1",
      }),
    }),
  );

  assertEquals(response.status, 200);
  const payload = await response.json();
  assertEquals(payload.tasks, [
    {
      title: "生成听歌任务",
      parent_index: null,
      xpReward: 20,
    },
  ]);
  assertEquals(typeof payload.cheer, "string");
});
