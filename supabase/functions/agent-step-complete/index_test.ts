import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { createAgentStepCompleteHandler } from "./index.ts";
import { continueAgentAfterTool } from "../_shared/agent_planner.ts";
import type {
  AgentRunSnapshot,
  SerializedAgentRun,
  SerializedAgentRunStep,
} from "../_shared/agent_engine.ts";
import type { AgentJson } from "../_shared/agent_types.ts";

Deno.test("agent-step-complete appends a done step after successful file tool execution", async () => {
  const deps = createStepCompleteDeps();
  const handler = createAgentStepCompleteHandler(deps);
  const response = await handler(
    new Request("http://localhost/agent-step-complete", {
      method: "POST",
      headers: {
        "Authorization": "Bearer valid-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        run_id: "run-1",
        step_id: "step-1",
        success: true,
        output_text: "Read README.md successfully",
        result_json: {
          path: "README.md",
          text: "README explains the product and how to run it.",
          char_count: 1024,
        },
      }),
    }),
  );

  assertEquals(response.status, 200);
  assertEquals(deps.appendedKinds, ["done"]);
  assertEquals(deps.updatedRunStatuses.at(-1), "succeeded");
});

Deno.test("agent-step-complete appends an error step and fails the run", async () => {
  const deps = createStepCompleteDeps();
  const handler = createAgentStepCompleteHandler(deps);
  const response = await handler(
    new Request("http://localhost/agent-step-complete", {
      method: "POST",
      headers: {
        "Authorization": "Bearer valid-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        run_id: "run-1",
        step_id: "step-1",
        success: false,
        error_text: "Read failed",
      }),
    }),
  );

  assertEquals(response.status, 200);
  assertEquals(deps.appendedKinds, ["error"]);
  assertEquals(deps.updatedRunStatuses.at(-1), "failed");
});

Deno.test("agent-step-complete appends a user-facing done step for business actions", async () => {
  const deps = createStepCompleteDeps({
    goal: "Open the stats page",
    initialToolName: "app.navigation.open",
    initialArgumentsJson: { target: "stats" },
  });
  const handler = createAgentStepCompleteHandler(deps);
  const response = await handler(
    new Request("http://localhost/agent-step-complete", {
      method: "POST",
      headers: {
        "Authorization": "Bearer valid-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        run_id: "run-1",
        step_id: "step-1",
        success: true,
        output_text: "Opened the stats page",
        result_json: {
          navigation_target: "stats",
        },
      }),
    }),
  );

  assertEquals(response.status, 200);
  const payload = await response.json();
  assertEquals(payload.steps[1].kind, "done");
  assertEquals(payload.steps[1].output_text, "Opened the stats page");
});

function createStepCompleteDeps(
  options: {
    goal?: string;
    initialToolName?: string;
    initialArgumentsJson?: AgentJson;
  } = {},
) {
  const run: SerializedAgentRun = {
    id: "run-1",
    user_id: "user-1",
    goal: options.goal ?? "check the README",
    channel: "desktop",
    status: "waiting_local_execution",
    summary: null,
    last_error: null,
    created_at: null,
    updated_at: null,
    started_at: null,
    finished_at: null,
  };

  const steps: SerializedAgentRunStep[] = [
    {
      id: "step-1",
      run_id: "run-1",
      step_index: 0,
      kind: "tool_call",
      tool_name: options.initialToolName ?? "file.read_text",
      arguments_json: options.initialArgumentsJson ?? { path: "README.md" },
      risk_level: "low",
      needs_confirmation: false,
      status: "ready",
      summary: "Initial tool step",
      output_text: null,
      result_json: null,
      error_text: null,
      created_at: null,
      updated_at: null,
      started_at: null,
      finished_at: null,
    },
  ];

  const appendedKinds: string[] = [];
  const updatedRunStatuses: string[] = [];

  return {
    appendedKinds,
    updatedRunStatuses,
    authenticate: async (accessToken: string) =>
      accessToken == "valid-token" ? { id: "user-1" } : null,
    updateStepStatus: async (
      stepId: string,
      status: string,
      extras?: {
        outputText?: string | null;
        resultJson?: AgentJson;
        errorText?: string | null;
      },
    ) => {
      steps[0] = {
        ...steps[0],
        id: stepId,
        status: status as SerializedAgentRunStep["status"],
        output_text: extras?.outputText ?? null,
        result_json: (extras?.resultJson ?? null) as AgentJson,
        error_text: extras?.errorText ?? null,
      };
      return steps[0];
    },
    appendStep: async (opts: Record<string, unknown>) => {
      appendedKinds.push(`${opts.kind ?? "message"}`);
      const step: SerializedAgentRunStep = {
        id: `step-${steps.length + 1}`,
        run_id: "run-1",
        step_index: steps.length,
        kind: `${opts.kind ?? "message"}` as SerializedAgentRunStep["kind"],
        tool_name: typeof opts.toolName === "string" ? opts.toolName : null,
        arguments_json: (opts.argumentsJson ??
          {}) as SerializedAgentRunStep["arguments_json"],
        risk_level:
          (opts.riskLevel ?? "low") as SerializedAgentRunStep["risk_level"],
        needs_confirmation: opts.needsConfirmation === true,
        status: `${
          opts.status ?? "succeeded"
        }` as SerializedAgentRunStep["status"],
        summary: `${opts.summary ?? ""}`,
        output_text: typeof opts.outputText === "string"
          ? opts.outputText
          : null,
        result_json:
          (opts.resultJson ?? null) as SerializedAgentRunStep["result_json"],
        error_text: typeof opts.errorText === "string" ? opts.errorText : null,
        created_at: null,
        updated_at: null,
        started_at: null,
        finished_at: null,
      };
      steps.push(step);
      return step;
    },
    updateRunStatus: async (runId: string, status: string) => {
      updatedRunStatuses.push(status);
      return { ...run, id: runId, status } as SerializedAgentRun;
    },
    loadSnapshot: async () => ({
      run: {
        ...run,
        status: (updatedRunStatuses.at(-1) ??
          run.status) as SerializedAgentRun["status"],
      },
      steps: [...steps],
    } as AgentRunSnapshot),
    continueRun: (
      goal: string,
      completedStep: SerializedAgentRunStep,
      resultJson?: AgentJson,
    ) => continueAgentAfterTool(goal, completedStep, resultJson),
    now: () => "2026-04-14T00:00:00.000Z",
  };
}
