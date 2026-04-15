import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import {
  agentCorsHeaders,
  loadAgentRunSnapshot,
  type AgentRunSnapshot,
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

type AgentRunStatusHandlerDeps = {
  authenticate: (accessToken: string) => Promise<AuthenticatedAgentUser | null>;
  loadSnapshot: (runId: string, userId: string) => Promise<AgentRunSnapshot | null>;
};

function createDefaultAgentRunStatusDeps(): AgentRunStatusHandlerDeps {
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
    loadSnapshot: (runId, userId) => loadAgentRunSnapshot(serviceClient, runId, userId),
  };
}

export function createAgentRunStatusHandler(
  deps: AgentRunStatusHandlerDeps = createDefaultAgentRunStatusDeps(),
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
      if (!runId) {
        return json(400, { success: false, error: "Missing run_id" });
      }

      const snapshot = await deps.loadSnapshot(runId, user.id);
      if (!snapshot) {
        return json(404, { success: false, error: "Run not found" });
      }

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
  Deno.serve(createAgentRunStatusHandler());
}
