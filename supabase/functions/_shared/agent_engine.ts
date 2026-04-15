import {
  isAgentRunTerminalStatus,
  normalizeAgentRiskLevel,
  normalizeAgentRunStatus,
  normalizeAgentStepKind,
  normalizeAgentStepStatus,
  toAgentText,
  type AgentJson,
  type AgentRiskLevel,
  type AgentRunRow,
  type AgentRunStatus,
  type AgentRunStepRow,
  type AgentStepKind,
  type AgentStepStatus,
} from "./agent_types.ts";
import {
  inferAgentRiskLevel,
  requiresAgentConfirmation,
} from "./agent_policy.ts";
import { gatherGuideMemoryBundle } from "./guide_memory.ts";

export const agentCorsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

export type AgentToolCallDraft = {
  tool_name: string;
  arguments: AgentJson;
  summary: string;
  output_text?: string;
};

export type AgentRunSnapshot = {
  run: SerializedAgentRun;
  steps: SerializedAgentRunStep[];
};

export type SerializedAgentRun = {
  id: string;
  user_id: string;
  goal: string;
  channel: string;
  status: AgentRunStatus;
  summary: string | null;
  last_error: string | null;
  created_at: string | null;
  updated_at: string | null;
  started_at: string | null;
  finished_at: string | null;
};

export type SerializedAgentRunStep = {
  id: string;
  run_id: string;
  step_index: number;
  kind: AgentStepKind;
  tool_name: string | null;
  arguments_json: AgentJson;
  risk_level: AgentRiskLevel;
  needs_confirmation: boolean;
  status: AgentStepStatus;
  summary: string;
  output_text: string | null;
  result_json: AgentJson;
  error_text: string | null;
  created_at: string | null;
  updated_at: string | null;
  started_at: string | null;
  finished_at: string | null;
};

function toRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
}

function toStepIndex(value: unknown): number {
  const parsed = Number(value);
  if (Number.isFinite(parsed) && parsed >= 0) return Math.floor(parsed);
  return 0;
}

export function toErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  try {
    return JSON.stringify(error);
  } catch {
    return String(error);
  }
}

export function serializeAgentRun(row: Partial<AgentRunRow> | null): SerializedAgentRun | null {
  if (!row?.id) return null;
  return {
    id: toAgentText(row.id),
    user_id: toAgentText(row.user_id),
    goal: toAgentText(row.goal),
    channel: toAgentText(row.channel) || "desktop",
    status: normalizeAgentRunStatus(row.status),
    summary: toAgentText(row.summary) || null,
    last_error: toAgentText(row.last_error) || null,
    created_at: toAgentText(row.created_at) || null,
    updated_at: toAgentText(row.updated_at) || null,
    started_at: toAgentText(row.started_at) || null,
    finished_at: toAgentText(row.finished_at) || null,
  };
}

export function serializeAgentRunStep(row: Partial<AgentRunStepRow> | null): SerializedAgentRunStep | null {
  if (!row?.id) return null;
  return {
    id: toAgentText(row.id),
    run_id: toAgentText(row.run_id),
    step_index: toStepIndex(row.step_index),
    kind: normalizeAgentStepKind(row.kind),
    tool_name: toAgentText(row.tool_name) || null,
    arguments_json: (row.arguments_json ?? {}) as AgentJson,
    risk_level: normalizeAgentRiskLevel(row.risk_level),
    needs_confirmation: Boolean(row.needs_confirmation),
    status: normalizeAgentStepStatus(row.status),
    summary: toAgentText(row.summary),
    output_text: toAgentText(row.output_text) || null,
    result_json: (row.result_json ?? null) as AgentJson,
    error_text: toAgentText(row.error_text) || null,
    created_at: toAgentText(row.created_at) || null,
    updated_at: toAgentText(row.updated_at) || null,
    started_at: toAgentText(row.started_at) || null,
    finished_at: toAgentText(row.finished_at) || null,
  };
}

export async function createAgentRun(
  supabase: any,
  opts: {
    userId: string;
    goal: string;
    channel?: string;
    summary?: string;
  },
): Promise<SerializedAgentRun> {
  const payload = {
    user_id: opts.userId,
    goal: toAgentText(opts.goal),
    channel: toAgentText(opts.channel) || "desktop",
    status: "queued",
    summary: toAgentText(opts.summary) || null,
    updated_at: new Date().toISOString(),
  };
  const { data, error } = await supabase
    .from("agent_runs")
    .insert(payload)
    .select("*")
    .single();
  if (error) throw error;
  const run = serializeAgentRun(data);
  if (!run) throw new Error("agent run insert returned empty row");
  return run;
}

export async function appendAgentStep(
  supabase: any,
  opts: {
    runId: string;
    kind: AgentStepKind;
    summary: string;
    toolName?: string;
    argumentsJson?: AgentJson;
    outputText?: string;
    resultJson?: AgentJson;
    errorText?: string;
    status?: AgentStepStatus;
    riskLevel?: AgentRiskLevel;
    needsConfirmation?: boolean;
  },
): Promise<SerializedAgentRunStep> {
  const stepIndex = await nextAgentStepIndex(supabase, opts.runId);
  const riskLevel = opts.riskLevel ?? inferAgentRiskLevel(opts.toolName ?? "", opts.argumentsJson);
  const needsConfirmation = opts.needsConfirmation ?? requiresAgentConfirmation(opts.toolName ?? "", opts.argumentsJson);
  const payload = {
    run_id: opts.runId,
    step_index: stepIndex,
    kind: opts.kind,
    tool_name: toAgentText(opts.toolName) || null,
    arguments_json: opts.argumentsJson ?? {},
    risk_level: riskLevel,
    needs_confirmation: needsConfirmation,
    status: opts.status ?? (needsConfirmation ? "waiting_approval" : "ready"),
    summary: toAgentText(opts.summary),
    output_text: toAgentText(opts.outputText) || null,
    result_json: opts.resultJson ?? null,
    error_text: toAgentText(opts.errorText) || null,
    updated_at: new Date().toISOString(),
  };
  const { data, error } = await supabase
    .from("agent_run_steps")
    .insert(payload)
    .select("*")
    .single();
  if (error) throw error;
  const step = serializeAgentRunStep(data);
  if (!step) throw new Error("agent step insert returned empty row");
  return step;
}

export async function nextAgentStepIndex(supabase: any, runId: string): Promise<number> {
  const { data, error } = await supabase
    .from("agent_run_steps")
    .select("step_index")
    .eq("run_id", runId)
    .order("step_index", { ascending: false })
    .limit(1);
  if (error) throw error;
  const current = Array.isArray(data) && data.length > 0
    ? toStepIndex(toRecord(data[0]).step_index)
    : -1;
  return current + 1;
}

export async function updateAgentRunStatus(
  supabase: any,
  runId: string,
  status: AgentRunStatus,
  extras: {
    summary?: string | null;
    lastError?: string | null;
    startedAt?: string | null;
    finishedAt?: string | null;
  } = {},
): Promise<SerializedAgentRun> {
  const payload: Record<string, unknown> = {
    status,
    updated_at: new Date().toISOString(),
  };
  if (extras.summary !== undefined) payload.summary = extras.summary;
  if (extras.lastError !== undefined) payload.last_error = extras.lastError;
  if (extras.startedAt !== undefined) payload.started_at = extras.startedAt;
  if (extras.finishedAt !== undefined) payload.finished_at = extras.finishedAt;
  const { data, error } = await supabase
    .from("agent_runs")
    .update(payload)
    .eq("id", runId)
    .select("*")
    .single();
  if (error) throw error;
  const run = serializeAgentRun(data);
  if (!run) throw new Error("agent run update returned empty row");
  return run;
}

export async function updateAgentStepStatus(
  supabase: any,
  stepId: string,
  status: AgentStepStatus,
  extras: {
    outputText?: string | null;
    resultJson?: AgentJson;
    errorText?: string | null;
    startedAt?: string | null;
    finishedAt?: string | null;
  } = {},
): Promise<SerializedAgentRunStep> {
  const payload: Record<string, unknown> = {
    status,
    updated_at: new Date().toISOString(),
  };
  if (extras.outputText !== undefined) payload.output_text = extras.outputText;
  if (extras.resultJson !== undefined) payload.result_json = extras.resultJson;
  if (extras.errorText !== undefined) payload.error_text = extras.errorText;
  if (extras.startedAt !== undefined) payload.started_at = extras.startedAt;
  if (extras.finishedAt !== undefined) payload.finished_at = extras.finishedAt;
  const { data, error } = await supabase
    .from("agent_run_steps")
    .update(payload)
    .eq("id", stepId)
    .select("*")
    .single();
  if (error) throw error;
  const step = serializeAgentRunStep(data);
  if (!step) throw new Error("agent step update returned empty row");
  return step;
}

export async function recordAgentStepApproval(
  supabase: any,
  opts: {
    stepId: string;
    userId: string;
    decision: "approved" | "rejected";
    reason?: string;
  },
): Promise<void> {
  const { error } = await supabase.from("agent_step_approvals").insert({
    step_id: opts.stepId,
    user_id: opts.userId,
    decision: opts.decision,
    reason: toAgentText(opts.reason) || null,
  });
  if (error) throw error;
}

export async function loadAgentRunSnapshot(
  supabase: any,
  runId: string,
  userId: string,
): Promise<AgentRunSnapshot | null> {
  const { data: runData, error: runError } = await supabase
    .from("agent_runs")
    .select("*")
    .eq("id", runId)
    .eq("user_id", userId)
    .maybeSingle();
  if (runError) throw runError;
  const run = serializeAgentRun(runData);
  if (!run) return null;

  const { data: stepRows, error: stepError } = await supabase
    .from("agent_run_steps")
    .select("*")
    .eq("run_id", runId)
    .order("step_index", { ascending: true });
  if (stepError) throw stepError;

  const steps = Array.isArray(stepRows)
    ? stepRows
      .map((row) => serializeAgentRunStep(row))
      .filter((row): row is SerializedAgentRunStep => row != null)
    : [];
  return { run, steps };
}

export async function buildAgentPlanningContext(
  supabase: any,
  userId: string,
  goal: string,
  clientContext?: Record<string, unknown>,
) {
  const memory = await gatherGuideMemoryBundle(supabase, userId, {
    scene: "agent",
    userMessage: goal,
    clientContext,
    maxRawItems: 60,
    maxPackedChars: 14000,
  });
  return {
    goal: toAgentText(goal),
    memory_digest: memory.memory_digest,
    memory_refs: memory.memory_refs,
    behavior_signals: memory.behavior_signals,
    packed_context: memory.packed_context,
  };
}

export function buildLocalToolStepDraft(draft: AgentToolCallDraft): {
  kind: "tool_call";
  tool_name: string;
  arguments_json: AgentJson;
  summary: string;
  output_text: string | null;
  risk_level: AgentRiskLevel;
  needs_confirmation: boolean;
  status: AgentStepStatus;
} {
  const riskLevel = inferAgentRiskLevel(draft.tool_name, draft.arguments);
  const needsConfirmation = requiresAgentConfirmation(draft.tool_name, draft.arguments);
  return {
    kind: "tool_call",
    tool_name: draft.tool_name,
    arguments_json: draft.arguments,
    summary: toAgentText(draft.summary),
    output_text: toAgentText(draft.output_text) || null,
    risk_level: riskLevel,
    needs_confirmation: needsConfirmation,
    status: needsConfirmation ? "waiting_approval" : "ready",
  };
}

export function inferRunStatusFromSteps(steps: SerializedAgentRunStep[]): AgentRunStatus {
  const latest = steps.length > 0 ? steps[steps.length - 1] : null;
  if (!latest) return "queued";
  if (latest.status === "waiting_approval") return "waiting_approval";
  if (latest.kind === "tool_call" && latest.status === "ready") {
    return "waiting_local_execution";
  }
  if (latest.status === "running") return "running";
  if (latest.status === "failed") return "failed";
  if (latest.kind === "done" && latest.status === "succeeded") return "succeeded";
  if (isAgentRunTerminalStatus(latest.status)) {
    return latest.status === "cancelled" ? "cancelled" : "failed";
  }
  return "running";
}
