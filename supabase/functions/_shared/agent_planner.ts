import type { SerializedAgentRunStep } from "./agent_engine.ts";
import { type AgentJson, toAgentJson } from "./agent_types.ts";

export type AgentPlannerStepDraft =
  | {
    kind: "tool_call";
    tool_name: string;
    arguments_json: AgentJson;
    summary: string;
    output_text?: string | null;
  }
  | {
    kind: "message" | "done";
    summary: string;
    output_text?: string | null;
    result_json?: AgentJson;
  };

export type AgentPlanningResult = {
  summary: string;
  steps: AgentPlannerStepDraft[];
};

function toText(value: unknown): string {
  if (typeof value === "string") return value.trim();
  if (value == null) return "";
  return String(value).trim();
}

function toRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
}

function localized(prefersEnglish: boolean, zh: string, en: string): string {
  return prefersEnglish ? en : zh;
}

function extractQuotedText(goal: string): string {
  const match = goal.match(/[“"'`](.+?)[”"'`]/);
  return match?.[1]?.trim() ?? "";
}

function extractAfterDelimiter(goal: string): string {
  const match = goal.match(/[:：]\s*(.+)$/);
  return match?.[1]?.trim() ?? "";
}

function extractTaskTitle(goal: string): string {
  const quoted = extractQuotedText(goal);
  if (quoted.length > 0) return quoted;

  const afterColon = extractAfterDelimiter(goal);
  if (afterColon.length > 0) return afterColon;

  return goal
    .replace(/^(帮我|请帮我|please|help me)\s*/i, "")
    .replace(/(创建|生成|新增|安排|添加|create|add|generate)\s*/i, "")
    .replace(/(一个|一条|任务|task)\s*/gi, "")
    .trim();
}

function extractRewardTitle(goal: string): string {
  const quoted = extractQuotedText(goal);
  if (quoted.length > 0) return quoted;
  return goal
    .replace(/^(帮我|请帮我|please|help me)\s*/i, "")
    .replace(/(兑换|redeem)\s*/i, "")
    .replace(/(奖励|reward)\s*/i, "")
    .trim();
}

function isTaskCreateIntent(loweredGoal: string): boolean {
  const hasCreateVerb = loweredGoal.includes("创建") ||
    loweredGoal.includes("生成") ||
    loweredGoal.includes("新增") ||
    loweredGoal.includes("安排") ||
    loweredGoal.includes("添加") ||
    loweredGoal.includes("create") ||
    loweredGoal.includes("add") ||
    loweredGoal.includes("generate");
  const hasTaskWord = loweredGoal.includes("任务") ||
    loweredGoal.includes("task");

  return loweredGoal.includes("创建任务") ||
    loweredGoal.includes("生成任务") ||
    loweredGoal.includes("新增任务") ||
    loweredGoal.includes("安排任务") ||
    loweredGoal.includes("create task") ||
    loweredGoal.includes("add task") ||
    loweredGoal.includes("generate task") ||
    (hasCreateVerb && hasTaskWord) ||
    (loweredGoal.includes("帮我创建") && loweredGoal.includes("任务")) ||
    (loweredGoal.includes("帮我生成") && loweredGoal.includes("任务"));
}

function isTaskUpdateIntent(loweredGoal: string): boolean {
  return loweredGoal.includes("修改任务") ||
    loweredGoal.includes("更新任务") ||
    loweredGoal.includes("改成") ||
    loweredGoal.includes("截止") ||
    loweredGoal.includes("到期") ||
    loweredGoal.includes("xp") ||
    loweredGoal.includes("rename") ||
    loweredGoal.includes("update task") ||
    loweredGoal.includes("due");
}

function isTaskSplitIntent(loweredGoal: string): boolean {
  return loweredGoal.includes("拆成") ||
    loweredGoal.includes("拆解") ||
    loweredGoal.includes("分成") ||
    loweredGoal.includes("分解") ||
    loweredGoal.includes("子任务") ||
    loweredGoal.includes("subtask") ||
    loweredGoal.includes("break down") ||
    loweredGoal.includes("split");
}

function isWeeklySummaryGenerateIntent(loweredGoal: string): boolean {
  const hasWeekly = loweredGoal.includes("周报") ||
    loweredGoal.includes("周总结") ||
    loweredGoal.includes("weekly report") ||
    loweredGoal.includes("weekly summary");
  const hasGenerate = loweredGoal.includes("生成") ||
    loweredGoal.includes("写") ||
    loweredGoal.includes("summarize") ||
    loweredGoal.includes("generate");
  return hasWeekly && hasGenerate;
}

function isWeeklySummaryOpenIntent(loweredGoal: string): boolean {
  return (loweredGoal.includes("打开") || loweredGoal.includes("open")) &&
    (loweredGoal.includes("周报") ||
      loweredGoal.includes("周总结") ||
      loweredGoal.includes("weekly"));
}

function isStatsOpenIntent(loweredGoal: string): boolean {
  return (loweredGoal.includes("统计") || loweredGoal.includes("stats")) &&
    (loweredGoal.includes("打开") ||
      loweredGoal.includes("查看") ||
      loweredGoal.includes("open") ||
      loweredGoal.includes("show"));
}

function isShopOpenIntent(loweredGoal: string): boolean {
  return (loweredGoal.includes("商店") || loweredGoal.includes("shop")) &&
    (loweredGoal.includes("打开") ||
      loweredGoal.includes("查看") ||
      loweredGoal.includes("open") ||
      loweredGoal.includes("show"));
}

function isRewardRedeemIntent(loweredGoal: string): boolean {
  return loweredGoal.includes("兑换") || loweredGoal.includes("redeem");
}

function isFileIntent(loweredGoal: string): boolean {
  return loweredGoal.includes("readme") ||
    loweredGoal.includes("read ") ||
    loweredGoal.includes("check ") ||
    loweredGoal.includes("file") ||
    loweredGoal.includes("文件") ||
    loweredGoal.includes("文档");
}

function isShellIntent(loweredGoal: string): boolean {
  return loweredGoal.includes("run tests") ||
    loweredGoal.includes("test") ||
    loweredGoal.includes("analyze") ||
    loweredGoal.includes("shell") ||
    loweredGoal.includes("terminal") ||
    loweredGoal.includes("命令") ||
    loweredGoal.includes("终端");
}

function extractReferencedPath(goal: string): string {
  const pathMatch = goal.match(
    /([A-Za-z]:[\\/][^\n]+|[A-Za-z0-9_./\\-]+\.(md|txt|json|yaml|yml|dart|ts|js))/i,
  );
  if (pathMatch?.[1]?.trim()) return pathMatch[1].trim();
  return "README.md";
}

function previewText(text: string, maxLength = 220): string {
  const normalized = text
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .slice(0, 3)
    .join(" ");
  if (normalized.length <= maxLength) return normalized;
  return `${normalized.slice(0, maxLength)}...`;
}

function toNumber(value: unknown, fallback: number): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

export function planAgentGoal(
  goal: string,
  clientContext?: Record<string, unknown>,
): AgentPlanningResult {
  const normalizedGoal = goal.trim();
  const loweredGoal = normalizedGoal.toLowerCase();
  const languageCode = toText(clientContext?.language_code).toLowerCase();
  const prefersEnglish = languageCode.startsWith("en") ||
    clientContext?.is_english === true;

  // 从 clientContext 中提取 agentic 记忆上下文，供 freeform 路径注入
  const agenticMemoryLines: string[] = Array.isArray(clientContext?._agentic_memory_lines)
    ? (clientContext._agentic_memory_lines as unknown[])
        .map((x) => toText(x))
        .filter(Boolean)
    : [];

  if (isStatsOpenIntent(loweredGoal)) {
    return {
      summary: localized(prefersEnglish, "打开统计页", "Open the stats view"),
      steps: [{
        kind: "tool_call",
        tool_name: "app.navigation.open",
        arguments_json: { target: "stats", source_text: normalizedGoal },
        summary: localized(prefersEnglish, "打开统计页", "Open stats"),
        output_text: localized(
          prefersEnglish,
          "准备打开统计页。",
          "Preparing to open the stats view.",
        ),
      }],
    };
  }

  if (isShopOpenIntent(loweredGoal)) {
    return {
      summary: localized(
        prefersEnglish,
        "打开奖励商店",
        "Open the reward shop",
      ),
      steps: [{
        kind: "tool_call",
        tool_name: "app.navigation.open",
        arguments_json: { target: "shop", source_text: normalizedGoal },
        summary: localized(prefersEnglish, "打开商店", "Open shop"),
        output_text: localized(
          prefersEnglish,
          "准备打开奖励商店。",
          "Preparing to open the reward shop.",
        ),
      }],
    };
  }

  if (isWeeklySummaryOpenIntent(loweredGoal)) {
    return {
      summary: localized(prefersEnglish, "打开周报页面", "Open weekly summary"),
      steps: [{
        kind: "tool_call",
        tool_name: "app.navigation.open",
        arguments_json: {
          target: "weekly_summary",
          source_text: normalizedGoal,
        },
        summary: localized(prefersEnglish, "打开周报", "Open weekly summary"),
        output_text: localized(
          prefersEnglish,
          "准备打开周报页面。",
          "Preparing to open the weekly summary view.",
        ),
      }],
    };
  }

  if (isWeeklySummaryGenerateIntent(loweredGoal)) {
    return {
      summary: localized(prefersEnglish, "生成周报", "Generate weekly summary"),
      steps: [{
        kind: "tool_call",
        tool_name: "app.weekly_summary.generate",
        arguments_json: { source_text: normalizedGoal },
        summary: localized(
          prefersEnglish,
          "生成周报",
          "Generate weekly summary",
        ),
        output_text: localized(
          prefersEnglish,
          "准备生成本周周报。",
          "Preparing to generate this week's summary.",
        ),
      }],
    };
  }

  if (isRewardRedeemIntent(loweredGoal)) {
    const rewardTitle = extractRewardTitle(normalizedGoal);
    return {
      summary: localized(prefersEnglish, "兑换奖励", "Redeem reward"),
      steps: [{
        kind: "tool_call",
        tool_name: "app.reward.redeem",
        arguments_json: {
          source_text: normalizedGoal,
          ...(rewardTitle.length > 0 ? { reward_title: rewardTitle } : {}),
        },
        summary: localized(prefersEnglish, "兑换奖励", "Redeem reward"),
        output_text: localized(
          prefersEnglish,
          "准备检查并兑换奖励。",
          "Preparing to check and redeem the reward.",
        ),
      }],
    };
  }

  if (isTaskSplitIntent(loweredGoal)) {
    const taskTitle = extractTaskTitle(normalizedGoal);
    return {
      summary: localized(prefersEnglish, "拆分任务", "Split task"),
      steps: [{
        kind: "tool_call",
        tool_name: "app.quest.split",
        arguments_json: {
          source_text: normalizedGoal,
          ...(taskTitle.length > 0 ? { task_title: taskTitle } : {}),
        },
        summary: localized(prefersEnglish, "拆分任务", "Split task"),
        output_text: localized(
          prefersEnglish,
          "准备把任务拆成更容易开始的步骤。",
          "Preparing to split the task into smaller starting steps.",
        ),
      }],
    };
  }

  if (isTaskUpdateIntent(loweredGoal)) {
    const taskTitle = extractTaskTitle(normalizedGoal);
    return {
      summary: localized(prefersEnglish, "修改任务", "Update task"),
      steps: [{
        kind: "tool_call",
        tool_name: "app.quest.update",
        arguments_json: {
          source_text: normalizedGoal,
          ...(taskTitle.length > 0 ? { task_title: taskTitle } : {}),
        },
        summary: localized(prefersEnglish, "修改任务", "Update task"),
        output_text: localized(
          prefersEnglish,
          "准备更新这条任务。",
          "Preparing to update the task.",
        ),
      }],
    };
  }

  if (isTaskCreateIntent(loweredGoal)) {
    const title = extractTaskTitle(normalizedGoal);
    return {
      summary: localized(prefersEnglish, "生成任务", "Create task"),
      steps: [{
        kind: "tool_call",
        tool_name: "app.quest.create",
        arguments_json: {
          source_text: normalizedGoal,
          ...(title.length > 0 ? { title } : {}),
        },
        summary: localized(prefersEnglish, "生成任务", "Create task"),
        output_text: localized(
          prefersEnglish,
          "准备生成一条新任务。",
          "Preparing to create a new task.",
        ),
      }],
    };
  }

  if (isFileIntent(loweredGoal)) {
    const path = extractReferencedPath(normalizedGoal);
    return {
      summary: prefersEnglish
        ? `Read ${path} before continuing`
        : `先读取 ${path} 再继续分析`,
      steps: [{
        kind: "tool_call",
        tool_name: "file.read_text",
        arguments_json: { path },
        summary: prefersEnglish ? `Read ${path}` : `读取 ${path}`,
        output_text: prefersEnglish
          ? "Fetching the file content for the next step."
          : "先获取文件内容，再继续总结。",
      }],
    };
  }

  if (isShellIntent(loweredGoal)) {
    const command = loweredGoal.includes("analyze")
      ? "flutter analyze"
      : loweredGoal.includes("test")
      ? "flutter test"
      : "git status";
    return {
      summary: prefersEnglish
        ? `Run ${command} for inspection`
        : `先执行 ${command} 获取现场信息`,
      steps: [{
        kind: "tool_call",
        tool_name: "shell.exec",
        arguments_json: { command, cwd: "." },
        summary: prefersEnglish ? `Run ${command}` : `执行 ${command}`,
        output_text: prefersEnglish
          ? "Collecting terminal output for the next summary step."
          : "先收集终端结果，再继续总结。",
      }],
    };
  }

  if (normalizedGoal.length > 0) {
    return {
      summary: localized(prefersEnglish, "自由聊天", "Free chat"),
      steps: [{
        kind: "tool_call",
        tool_name: "app.chat.freeform.respond",
        arguments_json: {
          source_text: normalizedGoal,
          // 注入 agentic 记忆上下文，让 freeform 回复能感知用户历史
          ...(agenticMemoryLines.length > 0
            ? { memory_context: agenticMemoryLines.join("\n") }
            : {}),
        },
        summary: localized(prefersEnglish, "继续聊天", "Continue chat"),
        output_text: localized(
          prefersEnglish,
          "Preparing a context-aware companion reply.",
          "准备生成基于上下文的陪伴式回复。",
        ),
      }],
    };
  }

  return {
    summary: prefersEnglish
      ? "Need more detail before choosing an action"
      : "还需要更具体的目标才能继续",
    steps: [{
      kind: "done",
      summary: prefersEnglish ? "Clarify the target" : "请先澄清目标",
      output_text: prefersEnglish
        ? "Please tell me whether you want to chat, generate a weekly summary, create a task, update a task, split a task, or open a product surface."
        : "请告诉我是想聊天、生成周报、创建任务、修改任务、拆分任务，还是打开某个产品页面。",
      result_json: { clarification_needed: true },
    }],
  };
}

export function continueAgentAfterTool(
  goal: string,
  completedStep: SerializedAgentRunStep,
  resultJson?: AgentJson,
): AgentPlannerStepDraft[] {
  const loweredGoal = goal.trim().toLowerCase();
  const resultRecord = toRecord(resultJson);
  const stepArguments = toRecord(completedStep.arguments_json);
  const toolName = toText(completedStep.tool_name);

  if (toolName === "file.read_text") {
    const path = toText(resultRecord.path) || toText(stepArguments.path) ||
      "目标文件";
    const text = toText(resultRecord.text);
    const summaryPrefix = loweredGoal.includes("readme") ? "README" : path;
    const preview = previewText(text);
    const charCount = toNumber(resultRecord["char_count"], text.length);
    return [{
      kind: "done",
      summary: `总结 ${summaryPrefix} 的读取结果`,
      output_text: preview.length === 0
        ? `已读取 ${path}，可以继续下一步。`
        : `已读取 ${path}。\n要点预览：${preview}`,
      result_json: toAgentJson({
        source_tool: toolName,
        path,
        preview,
        char_count: charCount,
      }),
    }];
  }

  if (toolName === "shell.exec") {
    const command = toText(resultRecord.command) ||
      toText(stepArguments.command) || "shell command";
    const stdout = toText(resultRecord.stdout);
    const stderr = toText(resultRecord.stderr);
    const preview = previewText(stdout.length > 0 ? stdout : stderr);
    const exitCode = toNumber(resultRecord["exit_code"], 0);
    return [{
      kind: "done",
      summary: `总结命令结果：${command}`,
      output_text: preview.length === 0
        ? `命令 ${command} 已执行完成。`
        : `命令 ${command} 已执行完成。\n摘要：${preview}`,
      result_json: toAgentJson({
        source_tool: toolName,
        command,
        preview,
        exit_code: exitCode,
      }),
    }];
  }

  if (toolName.startsWith("app.")) {
    const outputText = toText(completedStep.output_text) ||
      toText(resultRecord.output_text) || "业务动作已执行完成。";
    return [{
      kind: "done",
      summary: `完成业务动作：${toolName}`,
      output_text: outputText,
      result_json: toAgentJson({
        source_tool: toolName,
        ...resultRecord,
      }),
    }];
  }

  return [{
    kind: "done",
    summary: "本地工具执行完成",
    output_text: "已记录本地工具结果，可以继续下一步。",
    result_json: toAgentJson({ source_tool: toolName }),
  }];
}
