import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { createAgentTurnHandler } from "./index.ts";
import { planAgentGoal } from "../_shared/agent_planner.ts";
import type {
  AgentRunSnapshot,
  SerializedAgentRun,
  SerializedAgentRunStep,
} from "../_shared/agent_engine.ts";

Deno.test("agent-turn 缺少 goal 时返回 400", async () => {
  const handler = createAgentTurnHandler(createTurnDeps());
  const response = await handler(
    new Request("http://localhost/agent-turn", {
      method: "POST",
      headers: {
        "Authorization": "Bearer valid-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({}),
    }),
  );

  assertEquals(response.status, 400);
});

Deno.test("agent-turn 会为业务型导航目标生成 app.navigation.open 步骤", async () => {
  const deps = createTurnDeps();
  const handler = createAgentTurnHandler(deps);
  const response = await handler(
    new Request("http://localhost/agent-turn", {
      method: "POST",
      headers: {
        "Authorization": "Bearer valid-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ goal: "打开统计页" }),
    }),
  );

  assertEquals(response.status, 200);
  const payload = await response.json();
  assertEquals(payload.success, true);
  assertExists(payload.run);
  assertExists(payload.steps);
  assertEquals(payload.steps.length, 2);
  assertEquals(payload.steps[0].output_text, null);
  assertEquals(payload.steps[1].tool_name, "app.navigation.open");
  assertEquals(payload.steps[1].arguments_json.target, "stats");
  assertEquals(
    deps.recordedRunStatuses.at(-1)?.status,
    "waiting_local_execution",
  );
});

function createTurnDeps() {
  const run: SerializedAgentRun = {
    id: "run-1",
    user_id: "user-1",
    goal: "打开统计页",
    channel: "desktop",
    status: "queued",
    summary: null,
    last_error: null,
    created_at: null,
    updated_at: null,
    started_at: null,
    finished_at: null,
  };
  const steps: SerializedAgentRunStep[] = [];
  const recordedRunStatuses: Array<{ status: string; extras?: unknown }> = [];

  return {
    recordedRunStatuses,
    authenticate: async (accessToken: string) =>
      accessToken == "valid-token" ? { id: "user-1" } : null,
    buildPlanningContext: async () => ({
      memory_digest: "memory digest",
      behavior_signals: ["focus"],
      memory_refs: ["mem-1"],
    }),
    createRun: async () => run,
    appendStep: async (opts: Record<string, unknown>) => {
      const step = toSerializedStep(run.id, steps.length, opts);
      steps.push(step);
      return step;
    },
    updateRunStatus: async (
      runId: string,
      status: string,
      extras?: unknown,
    ) => {
      recordedRunStatuses.push({ status, extras });
      return { ...run, id: runId, status } as SerializedAgentRun;
    },
    loadSnapshot: async () => ({
      run: {
        ...run,
        status: (recordedRunStatuses.at(-1)?.status ??
          "queued") as SerializedAgentRun["status"],
      },
      steps: [...steps],
    } as AgentRunSnapshot),
    planGoal: (goal: string, clientContext?: Record<string, unknown>) =>
      planAgentGoal(goal, clientContext),
    now: () => "2026-04-14T00:00:00.000Z",
  };
}

function toSerializedStep(
  runId: string,
  stepIndex: number,
  opts: Record<string, unknown>,
): SerializedAgentRunStep {
  return {
    id: `step-${stepIndex + 1}`,
    run_id: runId,
    step_index: stepIndex,
    kind: `${opts.kind ?? "message"}` as SerializedAgentRunStep["kind"],
    tool_name: typeof opts.toolName === "string" ? opts.toolName : null,
    arguments_json: (opts.argumentsJson ??
      {}) as SerializedAgentRunStep["arguments_json"],
    risk_level:
      (opts.riskLevel ?? "low") as SerializedAgentRunStep["risk_level"],
    needs_confirmation: opts.needsConfirmation === true,
    status: `${opts.status ?? "succeeded"}` as SerializedAgentRunStep["status"],
    summary: `${opts.summary ?? ""}`,
    output_text: typeof opts.outputText === "string" ? opts.outputText : null,
    result_json:
      (opts.resultJson ?? null) as SerializedAgentRunStep["result_json"],
    error_text: typeof opts.errorText === "string" ? opts.errorText : null,
    created_at: null,
    updated_at: null,
    started_at: null,
    finished_at: null,
  };
}
