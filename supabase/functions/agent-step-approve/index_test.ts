import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { createAgentStepApproveHandler } from "./index.ts";
import type {
  AgentRunSnapshot,
  SerializedAgentRun,
  SerializedAgentRunStep,
} from "../_shared/agent_engine.ts";

Deno.test("agent-step-approve 批准后将步骤置为 ready", async () => {
  const deps = createApproveDeps();
  const handler = createAgentStepApproveHandler(deps);
  const response = await handler(
    new Request("http://localhost/agent-step-approve", {
      method: "POST",
      headers: {
        "Authorization": "Bearer valid-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        run_id: "run-1",
        step_id: "step-1",
        decision: "approved",
      }),
    }),
  );

  assertEquals(response.status, 200);
  assertEquals(deps.updatedStepStatuses, ["ready"]);
  assertEquals(deps.updatedRunStatuses, ["waiting_local_execution"]);
});

Deno.test("agent-step-approve 拒绝后取消 run 并写入错误文案", async () => {
  const deps = createApproveDeps();
  const handler = createAgentStepApproveHandler(deps);
  const response = await handler(
    new Request("http://localhost/agent-step-approve", {
      method: "POST",
      headers: {
        "Authorization": "Bearer valid-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        run_id: "run-1",
        step_id: "step-1",
        decision: "rejected",
        reason: "不执行",
      }),
    }),
  );

  assertEquals(response.status, 200);
  assertEquals(deps.updatedStepStatuses, ["cancelled"]);
  assertEquals(deps.updatedRunStatuses, ["cancelled"]);
  assertEquals(deps.lastRejectedReason, "不执行");
});

function createApproveDeps() {
  const run: SerializedAgentRun = {
    id: "run-1",
    user_id: "user-1",
    goal: "读取 README",
    channel: "desktop",
    status: "waiting_approval",
    summary: null,
    last_error: null,
    created_at: null,
    updated_at: null,
    started_at: null,
    finished_at: null,
  };
  const step: SerializedAgentRunStep = {
    id: "step-1",
    run_id: "run-1",
    step_index: 0,
    kind: "tool_call",
    tool_name: "file.read_text",
    arguments_json: { path: "README.md" },
    risk_level: "medium",
    needs_confirmation: true,
    status: "waiting_approval",
    summary: "读取 README.md",
    output_text: null,
    result_json: null,
    error_text: null,
    created_at: null,
    updated_at: null,
    started_at: null,
    finished_at: null,
  };

  let lastRejectedReason = "";
  const updatedStepStatuses: string[] = [];
  const updatedRunStatuses: string[] = [];

  return {
    updatedStepStatuses,
    updatedRunStatuses,
    get lastRejectedReason() {
      return lastRejectedReason;
    },
    authenticate: async (accessToken: string) =>
      accessToken == "valid-token" ? { id: "user-1" } : null,
    recordApproval: async (opts: { reason?: string; decision: "approved" | "rejected" }) => {
      if (opts.decision == "rejected") {
        lastRejectedReason = opts.reason ?? "";
      }
    },
    updateStepStatus: async (stepId: string, status: string) => {
      updatedStepStatuses.push(status);
      return { ...step, id: stepId, status } as SerializedAgentRunStep;
    },
    updateRunStatus: async (runId: string, status: "waiting_local_execution" | "cancelled") => {
      updatedRunStatuses.push(status);
      return { ...run, id: runId, status } as SerializedAgentRun;
    },
    loadSnapshot: async () =>
      ({
        run: {
          ...run,
          status: (updatedRunStatuses.at(-1) ?? run.status) as SerializedAgentRun["status"],
        },
        steps: [
          {
            ...step,
            status: (updatedStepStatuses.at(-1) ?? step.status) as SerializedAgentRunStep["status"],
          },
        ],
      } as AgentRunSnapshot),
    now: () => "2026-04-14T00:00:00.000Z",
  };
}
