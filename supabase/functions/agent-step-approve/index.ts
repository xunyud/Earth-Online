import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import {
  agentCorsHeaders,
  loadAgentRunSnapshot,
  recordAgentStepApproval,
  type AgentRunSnapshot,
  type SerializedAgentRun,
  type SerializedAgentRunStep,
  updateAgentRunStatus,
  updateAgentStepStatus,
} from "../_shared/agent_engine.ts";

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

type AuthenticatedAgentUser = {
  id: string;
};

type AgentStepApproveHandlerDeps = {
  authenticate: (accessToken: string) => Promise<AuthenticatedAgentUser | null>;
  recordApproval: (opts: {
    stepId: string;
    userId: string;
    decision: "approved" | "rejected";
    reason?: string;
  }) => Promise<void>;
  updateStepStatus: (
    stepId: string,
    status: string,
    extras?: {
      outputText?: string | null;
      errorText?: string | null;
      startedAt?: string | null;
      finishedAt?: string | null;
    },
  ) => Promise<SerializedAgentRunStep>;
  updateRunStatus: (
    runId: string,
    status: "waiting_local_execution" | "cancelled",
    extras?: {
      summary?: string | null;
      lastError?: string | null;
      startedAt?: string | null;
      finishedAt?: string | null;
    },
  ) => Promise<SerializedAgentRun>;
  loadSnapshot: (runId: string, userId: string) => Promise<AgentRunSnapshot | null>;
  now: () => string;
};

function createDefaultAgentStepApproveDeps(): AgentStepApproveHandlerDeps {
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
    recordApproval: (opts) => recordAgentStepApproval(serviceClient, opts),
    updateStepStatus: (stepId, status, extras) =>
      updateAgentStepStatus(serviceClient, stepId, status as never, extras),
    updateRunStatus: (runId, status, extras) =>
      updateAgentRunStatus(serviceClient, runId, status, extras),
    loadSnapshot: (runId, userId) => loadAgentRunSnapshot(serviceClient, runId, userId),
    now: () => new Date().toISOString(),
  };
}

export function createAgentStepApproveHandler(
  deps: AgentStepApproveHandlerDeps = createDefaultAgentStepApproveDeps(),
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

      const body = await req.json().catch(() => ({}));
      const runId = toText(body?.run_id);
      const stepId = toText(body?.step_id);
      const decision = toText(body?.decision);
      const reason = toText(body?.reason);
      if (!runId || !stepId || (decision != "approved" && decision != "rejected")) {
        return json(400, { success: false, error: "Missing run_id/step_id or invalid decision" });
      }

      const normalizedDecision = decision as "approved" | "rejected";
      await deps.recordApproval({
        stepId,
        userId: user.id,
        decision: normalizedDecision,
        reason,
      });

      if (normalizedDecision == "approved") {
        await deps.updateStepStatus(stepId, "ready");
        await deps.updateRunStatus(runId, "waiting_local_execution");
      } else {
        const failureMessage = reason.length === 0 ? "用户拒绝执行该步骤" : reason;
        const finishedAt = deps.now();
        await deps.updateStepStatus(stepId, "cancelled", {
          errorText: failureMessage,
          finishedAt,
        });
        await deps.updateRunStatus(runId, "cancelled", {
          lastError: failureMessage,
          finishedAt,
        });
      }

      const snapshot = await deps.loadSnapshot(runId, user.id);
      return json(200, { success: true, ...snapshot });
    } catch (error) {
      return json(500, {
        success: false,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  };
}

if (import.meta.main) {
  Deno.serve(createAgentStepApproveHandler());
}
