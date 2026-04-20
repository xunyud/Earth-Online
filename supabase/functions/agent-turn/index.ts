import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import {
  agentCorsHeaders,
  appendAgentStep,
  buildAgentPlanningContext,
  buildLocalToolStepDraft,
  createAgentRun,
  inferRunStatusFromSteps,
  loadAgentRunSnapshot,
  type AgentRunSnapshot,
  type SerializedAgentRun,
  type SerializedAgentRunStep,
  updateAgentRunStatus,
} from "../_shared/agent_engine.ts";
import {
  planAgentGoal,
  type AgentPlanningResult,
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

type AgentTurnHandlerDeps = {
  authenticate: (accessToken: string) => Promise<AuthenticatedAgentUser | null>;
  buildPlanningContext: (
    userId: string,
    goal: string,
    clientContext?: Record<string, unknown>,
  ) => Promise<{
    memory_digest: string;
    behavior_signals: unknown;
    memory_refs: unknown;
  }>;
  createRun: (opts: {
    userId: string;
    goal: string;
    channel?: string;
    summary?: string;
  }) => Promise<SerializedAgentRun>;
  appendStep: (opts: {
    runId: string;
    kind: AgentPlannerStepDraft["kind"];
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
  planGoal: (goal: string, clientContext?: Record<string, unknown>) => AgentPlanningResult;
  now: () => string;
};

function createDefaultAgentTurnDeps(): AgentTurnHandlerDeps {
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
    buildPlanningContext: (userId, goal, clientContext) =>
      buildAgentPlanningContext(serviceClient, userId, goal, clientContext),
    createRun: (opts) => createAgentRun(serviceClient, opts),
    appendStep: (opts) => appendAgentStep(serviceClient, opts as never),
    updateRunStatus: (runId, status, extras) =>
      updateAgentRunStatus(serviceClient, runId, status, extras),
    loadSnapshot: (runId, userId) => loadAgentRunSnapshot(serviceClient, runId, userId),
    planGoal: (goal, clientContext) => planAgentGoal(goal, clientContext),
    now: () => new Date().toISOString(),
  };
}

async function appendPlannedStep(
  deps: AgentTurnHandlerDeps,
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

export function createAgentTurnHandler(
  deps: AgentTurnHandlerDeps = createDefaultAgentTurnDeps(),
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
      const goal = toText(body.goal);
      const channel = toText(body.channel) || "desktop";
      const clientContext = toRecord(body.client_context);
      if (!goal) {
        return json(400, { success: false, error: "Missing goal" });
      }

      const planningContext = await deps.buildPlanningContext(
        user.id,
        goal,
        clientContext,
      );
      const run = await deps.createRun({
        userId: user.id,
        goal,
        channel,
        summary: planningContext.memory_digest,
      });
      const startedAt = deps.now();

      await deps.appendStep({
        runId: run.id,
        kind: "message",
        summary: `收到目标：${goal}`,
        status: "succeeded",
        resultJson: toAgentJson({
          behavior_signals: planningContext.behavior_signals,
          memory_refs: planningContext.memory_refs,
        }),
        needsConfirmation: false,
        riskLevel: "low",
      });

      const plan = deps.planGoal(goal, clientContext);
      for (const draft of plan.steps) {
        await appendPlannedStep(deps, run.id, draft);
      }

      const snapshot = await deps.loadSnapshot(run.id, user.id);
      const runStatus = snapshot ? inferRunStatusFromSteps(snapshot.steps) : "queued";
      await deps.updateRunStatus(run.id, runStatus, {
        startedAt,
        finishedAt: isAgentRunTerminalStatus(runStatus) ? deps.now() : null,
      });

      const finalSnapshot = await deps.loadSnapshot(run.id, user.id);
      return json(200, { success: true, ...finalSnapshot });
    } catch (error) {
      return json(500, {
        success: false,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  };
}

if (import.meta.main) {
  Deno.serve(createAgentTurnHandler());
}
