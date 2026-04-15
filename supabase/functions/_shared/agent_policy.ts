import { type AgentJson, type AgentRiskLevel } from "./agent_types.ts";

function toText(value: unknown): string {
  if (typeof value === "string") return value.trim();
  if (value == null) return "";
  return String(value).trim();
}

function toRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
}

function toStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.map((item) => toText(item)).filter(Boolean);
}

function extractPrimaryPath(argumentsJson: AgentJson | undefined): string {
  const record = toRecord(argumentsJson);
  return toText(record.path) || toText(record.file_path) || toText(record.cwd);
}

function extractShellCommand(argumentsJson: AgentJson | undefined): string {
  const record = toRecord(argumentsJson);
  return toText(record.command) || toText(record.cmd) || toText(record.script);
}

export function isSensitivePath(path: string): boolean {
  const normalized = path.replace(/\\/g, "/").toLowerCase();
  if (!normalized) return false;
  return normalized.includes("/.ssh/") ||
    normalized.includes("/appdata/") ||
    normalized.includes("/tokens/") ||
    normalized.endsWith("/.env") ||
    normalized.includes("/secrets/") ||
    normalized.includes("/credentials") ||
    normalized.includes("/id_rsa") ||
    normalized.includes("/id_ed25519");
}

export function inferAgentRiskLevel(
  toolName: string,
  argumentsJson?: AgentJson,
): AgentRiskLevel {
  const normalizedTool = toText(toolName).toLowerCase();
  const path = extractPrimaryPath(argumentsJson);
  const command = extractShellCommand(argumentsJson).toLowerCase();
  const record = toRecord(argumentsJson);

  if (!normalizedTool) return "medium";

  if (normalizedTool === "app.navigation.open") return "low";
  if (normalizedTool === "app.weekly_summary.generate") return "low";
  if (normalizedTool === "app.chat.freeform.respond") return "low";

  if (
    normalizedTool === "app.quest.create" ||
    normalizedTool === "app.quest.update" ||
    normalizedTool === "app.quest.split" ||
    normalizedTool === "app.reward.redeem"
  ) {
    return "medium";
  }

  if (normalizedTool.startsWith("app.")) return "medium";

  if (normalizedTool === "file.read_text") {
    const extraPaths = toStringArray(record.paths);
    if (extraPaths.length > 1) return "medium";
    return isSensitivePath(path) ? "high" : "low";
  }

  if (normalizedTool === "file.list_dir") {
    return isSensitivePath(path) ? "high" : "medium";
  }

  if (normalizedTool.startsWith("browser.")) {
    if (
      normalizedTool.includes("submit") ||
      normalizedTool.includes("click") ||
      normalizedTool.includes("fill") ||
      normalizedTool.includes("press")
    ) {
      return "high";
    }
    return "low";
  }

  if (normalizedTool === "shell.exec") {
    const destructivePattern =
      /\b(rm|rmdir|del|erase|mv|move|ren|rename|cp|copy|git\s+(add|commit|push|reset|checkout|restore|clean|rebase|merge|cherry-pick)|npm\s+(install|publish|unpublish)|pnpm\s+(add|remove|install|publish)|yarn\s+(add|remove|install|publish)|flutter\s+pub\s+(add|remove)|dart\s+pub\s+(add|remove)|pip\s+install|cargo\s+publish)\b/i;
    if (destructivePattern.test(command)) return "high";

    const readonlyPattern =
      /\b(git\s+(status|diff|log)|flutter\s+(analyze|test)|dart\s+test|deno\s+test|ls|pwd|dir|type)\b/i;
    if (readonlyPattern.test(command)) return "low";
    return "medium";
  }

  if (
    normalizedTool === "memory.write" ||
    normalizedTool.startsWith("external.write") ||
    normalizedTool.startsWith("api.post")
  ) {
    return "high";
  }

  if (
    normalizedTool === "memory.search" ||
    normalizedTool.startsWith("guide.")
  ) {
    return "low";
  }

  return "medium";
}

export function requiresAgentConfirmation(
  toolName: string,
  argumentsJson?: AgentJson,
): boolean {
  return inferAgentRiskLevel(toolName, argumentsJson) !== "low";
}
