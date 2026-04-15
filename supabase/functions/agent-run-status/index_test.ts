import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { createAgentRunStatusHandler } from "./index.ts";
import type { AgentRunSnapshot } from "../_shared/agent_engine.ts";

Deno.test("agent-run-status 可以加载自己的 run", async () => {
  const handler = createAgentRunStatusHandler({
    authenticate: async () => ({ id: "user-1" }),
    loadSnapshot: async (runId: string, userId: string) =>
      runId == "run-1" && userId == "user-1"
        ? ({
          run: {
            id: "run-1",
            user_id: "user-1",
            goal: "读取 README",
            channel: "desktop",
            status: "succeeded",
            summary: null,
            last_error: null,
            created_at: null,
            updated_at: null,
            started_at: null,
            finished_at: null,
          },
          steps: [],
        } as AgentRunSnapshot)
        : null,
  });

  const response = await handler(
    new Request("http://localhost/agent-run-status", {
      method: "POST",
      headers: {
        "Authorization": "Bearer valid-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ run_id: "run-1" }),
    }),
  );

  assertEquals(response.status, 200);
});

Deno.test("agent-run-status 对其他用户的 run 返回 404", async () => {
  const handler = createAgentRunStatusHandler({
    authenticate: async () => ({ id: "user-1" }),
    loadSnapshot: async () => null,
  });

  const response = await handler(
    new Request("http://localhost/agent-run-status", {
      method: "POST",
      headers: {
        "Authorization": "Bearer valid-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ run_id: "run-2" }),
    }),
  );

  assertEquals(response.status, 404);
});
