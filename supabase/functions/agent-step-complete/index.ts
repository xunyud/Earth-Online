import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import {
  agentCorsHeaders,
  appendAgentStep,
  buildLocalToolStepDraft,
  inferRunStatusFromSteps,
  loadAgentRunSnapshot,
  syncAgentEventToMemory,
  type AgentRunSnapshot,
  type SerializedAgentRun,
  type SerializedAgentRunStep,
  updateAgentRunStatus,
  updateAgentStepStatus,
} from "../_shared/agent_engine.ts";
import {
  continueAgentAfterTool,
  type AgentPlannerStepDraft,
} from "../_shared/agent_planner.ts";
import {
  isAgentRunTerminalStatus,
  type AgentJson,
  type AgentRunStatus,
  toAgentJson,
} from "../_shared/agent_types.ts";

function json(status: number, data: unknown) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...agentCorsHeaders, "Content-Type": "application/json" },
  });
}

function toText(value: unknown): string {
  if (typeof value === "string") return value.trim();
  if (value == null) return "";
  return String(value).trim();
}

function toRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
}

type AuthenticatedAgentUser = {
  id: string;
};

type AgentStepCompleteHandlerDeps = {
  authenticate: (accessToken: string) => Promise<AuthenticatedAgentUser | null>;
  updateStepStatus: (
    stepId: string,
    status: string,
    extras?: {
      outputText?: string | null;
      resultJson?: AgentJson;
      errorText?: string | null;
      startedAt?: string | null;
      finishedAt?: string | null;
    },
  ) => Promise<SerializedAgentRunStep>;
  appendStep: (opts: {
    runId: string;
    kind: AgentPlannerStepDraft["kind"] | "error";
    summary: string;
    toolName?: string;
    argumentsJson?: AgentJson;
    outputText?: string | null;
    resultJson?: AgentJson;
    errorText?: string;
    status?: string;
    riskLevel?: "low" | "medium" | "high";
    needsConfirmation?: boolean;
  }) => Promise<SerializedAgentRunStep>;
  updateRunStatus: (
    runId: string,
    status: AgentRunStatus,
    extras?: {
      summary?: string | null;
      lastError?: string | null;
      startedAt?: string | null;
      finishedAt?: string | null;
    },
  ) => Promise<SerializedAgentRun>;
  loadSnapshot: (runId: string, userId: string) => Promise<AgentRunSnapshot | null>;
  continueRun: (
    goal: string,
    completedStep: SerializedAgentRunStep,
    resultJson?: AgentJson,
  ) => AgentPlannerStepDraft[];
  now: () => string;
};

function createDefaultAgentStepCompleteDeps(): AgentStepCompleteHandlerDeps {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !supabaseAnonKey || !serviceRole) {
    throw new Error("Missing SUPABASE env");
  }

  const authClient = createClient(supabaseUrl, supabaseAnonKey);
  const serviceClient = createClient(supabaseUrl, serviceRole);

  return {
    authenticate: async (accessToken) => {
      const { data, error } = await authClient.auth.getUser(accessToken);
      if (error || !data.user) return null;
      return { id: data.user.id };
    },
    updateStepStatus: (stepId, status, extras) =>
      updateAgentStepStatus(serviceClient, stepId, status as never, extras),
    appendStep: (opts) => appendAgentStep(serviceClient, opts as never),
    updateRunStatus: (runId, status, extras) =>
      updateAgentRunStatus(serviceClient, runId, status, extras),
    loadSnapshot: (runId, userId) => loadAgentRunSnapshot(serviceClient, runId, userId),
    continueRun: (goal, completedStep, resultJson) =>
      continueAgentAfterTool(goal, completedStep, resultJson),
    now: () => new Date().toISOString(),
  };
}

async function appendPlannedStep(
  deps: AgentStepCompleteHandlerDeps,
  runId: string,
  draft: AgentPlannerStepDraft,
) {
  if (draft.kind === "tool_call") {
    const toolStep = buildLocalToolStepDraft({
      tool_name: draft.tool_name,
      arguments: draft.arguments_json,
      summary: draft.summary,
      output_text: draft.output_text ?? undefined,
    });
    await deps.appendStep({
      runId,
      kind: toolStep.kind,
      toolName: toolStep.tool_name,
      argumentsJson: toAgentJson(toolStep.arguments_json),
      summary: toolStep.summary,
      outputText: toolStep.output_text ?? null,
      status: toolStep.status,
      riskLevel: toolStep.risk_level,
      needsConfirmation: toolStep.needs_confirmation,
    });
    return;
  }

  await deps.appendStep({
    runId,
    kind: draft.kind,
    summary: draft.summary,
    outputText: draft.output_text ?? null,
    resultJson: toAgentJson(draft.result_json),
    status: "succeeded",
    riskLevel: "low",
    needsConfirmation: false,
  });
}

export function createAgentStepCompleteHandler(
  deps: AgentStepCompleteHandlerDeps = createDefaultAgentStepCompleteDeps(),
) {
  return async (req: Request) => {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: agentCorsHeaders });
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

      const body = toRecord(await req.json().catch(() => ({})));
      const runId = toText(body.run_id);
      const stepId = toText(body.step_id);
      const success = body.success === true;
      const outputText = toText(body.output_text);
      const errorText = toText(body.error_text);
      const resultRecord = toRecord(body.result_json);
      const resultJson = Object.keys(resultRecord).length === 0
        ? undefined
        : toAgentJson(resultRecord);
      if (!runId || !stepId) {
        return json(400, { success: false, error: "Missing run_id or step_id" });
      }

      const finishedAt = deps.now();
      await deps.updateStepStatus(
        stepId,
        success ? "succeeded" : "failed",
        {
          outputText,
          errorText: errorText.length === 0 ? null : errorText,
          resultJson,
          startedAt: finishedAt,
          finishedAt,
        },
      );

      if (!success) {
        const failureMessage = errorText.length === 0 ? "本地工具执行失败" : errorText;
        await deps.appendStep({
          runId,
          kind: "error",
          summary: "本地工具执行失败",
          outputText: failureMessage,
          errorText: failureMessage,
          resultJson,
          status: "failed",
          riskLevel: "medium",
          needsConfirmation: false,
        });
        await deps.updateRunStatus(runId, "failed", {
          lastError: failureMessage,
          finishedAt,
        });
        const snapshot = await deps.loadSnapshot(runId, user.id);
        return json(200, { success: true, ...snapshot });
      }

      const snapshotAfterTool = await deps.loadSnapshot(runId, user.id);
      if (!snapshotAfterTool) {
        return json(404, { success: false, error: "Run not found" });
      }

      const completedStep = snapshotAfterTool.steps.find((item) => item.id === stepId);
      if (!completedStep) {
        return json(404, { success: false, error: "Step not found" });
      }

      // 把工具执行结果写入 EverMemOS 记忆，让 agent 后续规划能感知历史操作
      if (completedStep.tool_name) {
        const toolSummary = outputText.length > 0
          ? outputText.slice(0, 120)
          : `工具 ${completedStep.tool_name} 执行完成`;
        syncAgentEventToMemory(
          user.id,
          "agent_tool_result",
          `[工具执行] ${completedStep.tool_name}：${toolSummary}`,
          {
            sourceTaskId: runId,
            sourceTaskTitle: snapshotAfterTool.run.goal.slice(0, 60),
            summary: toolSummary,
            extra: {
              tool_name: completedStep.tool_name,
              step_id: stepId,
              run_id: runId,
            },
          },
        );
      }

      const continuationDrafts = deps.continueRun(
        snapshotAfterTool.run.goal,
        completedStep,
        resultJson,
      );
      for (const draft of continuationDrafts) {
        await appendPlannedStep(deps, runId, draft);
      }

      const finalSnapshot = await deps.loadSnapshot(runId, user.id);
      const runStatus = finalSnapshot
        ? inferRunStatusFromSteps(finalSnapshot.steps)
        : "running";
      await deps.updateRunStatus(runId, runStatus, {
        lastError: null,
        finishedAt: isAgentRunTerminalStatus(runStatus) ? deps.now() : null,
      });

      // run 进入终态时写入完成记忆
      if (isAgentRunTerminalStatus(runStatus) && snapshotAfterTool.run.goal) {
        syncAgentEventToMemory(
          user.id,
          "agent_run_complete",
          `[agent完成] ${snapshotAfterTool.run.goal.slice(0, 80)}，状态：${runStatus}`,
          {
            sourceTaskId: runId,
            sourceTaskTitle: snapshotAfterTool.run.goal.slice(0, 60),
            summary: `agent run ${runStatus}：${snapshotAfterTool.run.goal.slice(0, 60)}`,
            extra: { run_id: runId, status: runStatus },
          },
        );
      }

      const updatedSnapshot = await deps.loadSnapshot(runId, user.id);
      return json(200, { success: true, ...updatedSnapshot });
    } catch (error) {
      return json(500, {
        success: false,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  };
}

if (import.meta.main) {
  Deno.serve(createAgentStepCompleteHandler());
}
