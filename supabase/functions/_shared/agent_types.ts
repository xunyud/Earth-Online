export const agentRunStatuses = [
  "queued",
  "running",
  "waiting_approval",
  "waiting_local_execution",
  "succeeded",
  "failed",
  "cancelled",
] as const;

export type AgentRunStatus = typeof agentRunStatuses[number];

export const agentStepKinds = [
  "message",
  "tool_call",
  "approval_request",
  "result",
  "error",
  "done",
] as const;

export type AgentStepKind = typeof agentStepKinds[number];

export const agentStepStatuses = [
  "planned",
  "waiting_approval",
  "ready",
  "running",
  "succeeded",
  "failed",
  "cancelled",
] as const;

export type AgentStepStatus = typeof agentStepStatuses[number];

export const agentRiskLevels = ["low", "medium", "high"] as const;

export type AgentRiskLevel = typeof agentRiskLevels[number];

export type AgentJson =
  | null
  | boolean
  | number
  | string
  | AgentJson[]
  | { [key: string]: AgentJson };

export type AgentRunRow = {
  id: string;
  user_id: string;
  goal: string;
  channel?: string | null;
  status: AgentRunStatus | string;
  summary?: string | null;
  last_error?: string | null;
  created_at?: string | null;
  updated_at?: string | null;
  started_at?: string | null;
  finished_at?: string | null;
};

export type AgentRunStepRow = {
  id: string;
  run_id: string;
  step_index: number;
  kind: AgentStepKind | string;
  tool_name?: string | null;
  arguments_json?: AgentJson;
  risk_level?: AgentRiskLevel | string | null;
  needs_confirmation?: boolean | null;
  status?: AgentStepStatus | string | null;
  summary?: string | null;
  output_text?: string | null;
  result_json?: AgentJson;
  error_text?: string | null;
  created_at?: string | null;
  updated_at?: string | null;
  started_at?: string | null;
  finished_at?: string | null;
};

export type AgentStepApprovalRow = {
  id: string;
  step_id: string;
  user_id: string;
  decision: "approved" | "rejected" | string;
  reason?: string | null;
  created_at?: string | null;
};

export function toAgentText(value: unknown): string {
  if (typeof value === "string") return value.trim();
  if (value == null) return "";
  return String(value).trim();
}

export function toAgentJson(value: unknown): AgentJson {
  if (value == null) return null;
  if (
    typeof value === "string" ||
    typeof value === "number" ||
    typeof value === "boolean"
  ) {
    return value;
  }
  if (Array.isArray(value)) {
    return value.map((item) => toAgentJson(item));
  }
  if (typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>).map((
      [key, item],
    ) => [key, toAgentJson(item)] as const);
    return Object.fromEntries(entries);
  }
  return toAgentText(value);
}

export function normalizeAgentRunStatus(value: unknown): AgentRunStatus {
  const text = toAgentText(value);
  return (agentRunStatuses as readonly string[]).includes(text)
    ? text as AgentRunStatus
    : "queued";
}

export function normalizeAgentStepKind(value: unknown): AgentStepKind {
  const text = toAgentText(value);
  return (agentStepKinds as readonly string[]).includes(text)
    ? text as AgentStepKind
    : "message";
}

export function normalizeAgentStepStatus(value: unknown): AgentStepStatus {
  const text = toAgentText(value);
  return (agentStepStatuses as readonly string[]).includes(text)
    ? text as AgentStepStatus
    : "planned";
}

export function normalizeAgentRiskLevel(value: unknown): AgentRiskLevel {
  const text = toAgentText(value);
  return (agentRiskLevels as readonly string[]).includes(text)
    ? text as AgentRiskLevel
    : "low";
}

export function isAgentRunTerminalStatus(status: AgentRunStatus | string): boolean {
  return status === "succeeded" || status === "failed" || status === "cancelled";
}

export function isAgentStepTerminalStatus(status: AgentStepStatus | string): boolean {
  return status === "succeeded" || status === "failed" || status === "cancelled";
}
