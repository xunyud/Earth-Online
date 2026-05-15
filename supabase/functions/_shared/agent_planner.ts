import type { SerializedAgentRunStep } from "./agent_engine.ts";
import { toText, toRecord } from "./http.ts"
import { type AgentJson, toAgentJson } from "./agent_types.ts";
import { fetchWithRetry } from "./evermemos_client.ts";

export const MAX_AGENT_STEPS = 10;

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
  const resultRecord = toRecord(resultJson);
  const toolName = toText(completedStep.tool_name);

  // app.* 工具是终态业务动作，执行完直接 done
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

  // 非 app 工具（file.read_text / shell.exec / 自定义）→ 返回中间结果步骤
  // 由 replanAfterToolCompletion 决定是否继续
  return buildIntermediateResultStep(goal, completedStep, resultJson);
}

function buildIntermediateResultStep(
  goal: string,
  completedStep: SerializedAgentRunStep,
  resultJson?: AgentJson,
): AgentPlannerStepDraft[] {
  const resultRecord = toRecord(resultJson);
  const stepArguments = toRecord(completedStep.arguments_json);
  const toolName = toText(completedStep.tool_name);

  if (toolName === "file.read_text") {
    const path = toText(resultRecord.path) || toText(stepArguments.path) ||
      "目标文件";
    const text = toText(resultRecord.text);
    const summaryPrefix = goal.toLowerCase().includes("readme") ? "README" : path;
    const preview = previewText(text);
    const charCount = toNumber(resultRecord["char_count"], text.length);
    return [{
      kind: "message",
      summary: `已读取 ${summaryPrefix}`,
      output_text: preview.length === 0
        ? `已读取 ${path}，正在分析下一步。`
        : `已读取 ${path}（${charCount} 字符）。\n要点：${preview}`,
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
      kind: "message",
      summary: `命令已执行：${command}`,
      output_text: preview.length === 0
        ? `命令 ${command} 已执行（exit ${exitCode}），正在分析结果。`
        : `命令 ${command}（exit ${exitCode}）：\n${preview}`,
      result_json: toAgentJson({
        source_tool: toolName,
        command,
        preview,
        exit_code: exitCode,
      }),
    }];
  }

  return [{
    kind: "message",
    summary: `工具 ${toolName} 执行完成`,
    output_text: "已记录工具结果，正在规划下一步。",
    result_json: toAgentJson({ source_tool: toolName }),
  }];
}

function getReplanApiKey(): string {
  return (
    Deno.env.get("OPENAI_API_KEY") ||
    Deno.env.get("DEEPSEEK_API_KEY") ||
    ""
  ).trim();
}

function getReplanApiBaseUrl(): string {
  const baseUrl = Deno.env.get("OPENAI_BASE_URL") ||
    Deno.env.get("DEEPSEEK_BASE_URL") ||
    "https://api.86gamestore.com";
  const trimmed = baseUrl.trim().replace(/\/+$/, "");
  if (!trimmed) return "https://api.86gamestore.com/v1";
  return trimmed.endsWith("/v1") ? trimmed : `${trimmed}/v1`;
}

function stripJsonFence(text: string): string {
  return text.replace(/```json/gi, "").replace(/```/g, "").trim();
}

type ReplanContext = {
  goal: string;
  completedSteps: SerializedAgentRunStep[];
  latestResult?: AgentJson;
  memoryLines?: string[];
};

/**
 * 多轮循环核心：基于已完成步骤和工具结果，通过 LLM 决定下一步。
 * 返回新的 step drafts（tool_call 继续执行，done 结束 run）。
 * 到达 MAX_AGENT_STEPS 时强制结束。
 */
export async function replanAfterToolCompletion(
  ctx: ReplanContext,
): Promise<AgentPlannerStepDraft[]> {
  const { goal, completedSteps, latestResult, memoryLines } = ctx;

  // 步数防护：已达上限则强制结束
  if (completedSteps.length >= MAX_AGENT_STEPS) {
    return [{
      kind: "done",
      summary: "已达最大执行步数，自动结束",
      output_text: `已执行 ${completedSteps.length} 步，达到单次运行上限。目标「${goal.slice(0, 40)}」的已完成部分已记录。`,
      result_json: toAgentJson({ reason: "max_steps_reached" }),
    }];
  }

  // app.* 工具是终态，不需要 replan（防御性检查）
  const latestStep = completedSteps[completedSteps.length - 1];
  const latestTool = toText(latestStep?.tool_name);
  if (latestTool.startsWith("app.")) {
    return [{
      kind: "done",
      summary: `业务动作完成：${latestTool}`,
      output_text: toText(latestStep?.output_text) || "业务动作已执行。",
    }];
  }

  // 无 API Key 时用启发式 fallback
  const apiKey = getReplanApiKey();
  if (!apiKey) {
    return heuristicContinuation(goal, latestStep, latestResult);
  }

  // 构建 LLM re-planning prompt
  const stepsContext = completedSteps
    .filter((s) => s.kind === "tool_call" || s.kind === "message")
    .slice(-5)
    .map((s, i) => {
      const tool = toText(s.tool_name);
      const output = toText(s.output_text).slice(0, 200);
      return `步骤${i + 1}: [${tool || s.kind}] ${s.summary}${output ? ` → ${output}` : ""}`;
    })
    .join("\n");

  const memoryContext = memoryLines?.length
    ? `\n用户近期记忆：\n${memoryLines.slice(0, 5).join("\n")}`
    : "";

  const systemPrompt = `你是一个任务执行代理的规划器。用户给出了一个目标，agent 已经执行了若干步骤。
你的任务是判断：目标是否已完成？如果未完成，下一步应该做什么？

可用工具：
- app.quest.create: 创建任务 (参数: source_text, title?)
- app.quest.update: 修改任务 (参数: source_text, task_title?)
- app.quest.split: 拆分任务 (参数: source_text, task_title?)
- app.navigation.open: 打开页面 (参数: target=stats|shop|weekly_summary)
- app.weekly_summary.generate: 生成周报
- app.reward.redeem: 兑换奖励 (参数: source_text, reward_title?)
- app.chat.freeform.respond: 自由回复 (参数: source_text, memory_context?)
- file.read_text: 读取文件 (参数: path)
- shell.exec: 执行命令 (参数: command, cwd?)

回复严格 JSON，格式：
{"done": true, "summary": "总结文本"} 表示目标已完成
{"done": false, "next_tool": "工具名", "arguments": {...}, "summary": "下一步说明"} 表示继续执行`;

  const userPrompt = `目标：${goal}

已执行步骤：
${stepsContext}
${memoryContext}

请判断目标是否达成，若未达成则规划下一步。`;

  try {
    const resp = await fetchWithRetry(
      `${getReplanApiBaseUrl()}/chat/completions`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "deepseek-chat",
          temperature: 0.3,
          messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: userPrompt },
          ],
          response_format: { type: "json_object" },
        }),
        signal: AbortSignal.timeout(8000),
      },
    );

    if (!resp.ok) {
      console.warn("replanAfterToolCompletion: LLM HTTP", resp.status);
      return heuristicContinuation(goal, latestStep, latestResult);
    }

    const data = await resp.json();
    const raw = toText(data?.choices?.[0]?.message?.content);
    if (!raw) return heuristicContinuation(goal, latestStep, latestResult);

    const parsed = JSON.parse(stripJsonFence(raw)) as Record<string, unknown>;

    if (parsed.done === true) {
      return [{
        kind: "done",
        summary: toText(parsed.summary) || "目标已完成",
        output_text: toText(parsed.summary) || "所有步骤执行完毕。",
        result_json: toAgentJson({ replanned: true }),
      }];
    }

    const nextTool = toText(parsed.next_tool);
    const args = toRecord(parsed.arguments);
    const summary = toText(parsed.summary) || `执行 ${nextTool}`;

    if (!nextTool) {
      return [{
        kind: "done",
        summary: toText(parsed.summary) || "规划完成",
        output_text: toText(parsed.summary) || "无需更多步骤。",
      }];
    }

    return [{
      kind: "tool_call",
      tool_name: nextTool,
      arguments_json: toAgentJson(args) ?? {},
      summary,
      output_text: `正在${summary}...`,
    }];
  } catch (err) {
    console.warn("replanAfterToolCompletion: LLM 调用失败", err);
    return heuristicContinuation(goal, latestStep, latestResult);
  }
}

function heuristicContinuation(
  goal: string,
  latestStep: SerializedAgentRunStep | undefined,
  latestResult?: AgentJson,
): AgentPlannerStepDraft[] {
  if (!latestStep) {
    return [{
      kind: "done",
      summary: "无可继续步骤",
      output_text: "执行完毕。",
    }];
  }

  const toolName = toText(latestStep.tool_name);
  const resultRecord = toRecord(latestResult);
  const stepArgs = toRecord(latestStep.arguments_json);

  // shell.exec 失败时提供错误摘要而非继续
  if (toolName === "shell.exec") {
    const exitCode = toNumber(resultRecord["exit_code"], 0);
    const stderr = toText(resultRecord.stderr);
    if (exitCode !== 0 && stderr.length > 0) {
      return [{
        kind: "done",
        summary: "命令执行出错",
        output_text: `命令执行失败（exit ${exitCode}）：\n${previewText(stderr)}`,
        result_json: toAgentJson({ exit_code: exitCode, has_error: true }),
      }];
    }
  }

  // file.read_text 后，如果目标包含"创建任务"相关关键词，尝试创建
  if (toolName === "file.read_text") {
    const lowered = goal.toLowerCase();
    if (
      lowered.includes("创建") || lowered.includes("任务") ||
      lowered.includes("create") || lowered.includes("task")
    ) {
      const text = toText(resultRecord.text).slice(0, 500);
      return [{
        kind: "tool_call",
        tool_name: "app.quest.create",
        arguments_json: {
          source_text: `基于文件内容创建任务：${text.slice(0, 200)}`,
          title: goal.slice(0, 50),
        },
        summary: "基于文件内容创建任务",
        output_text: "正在根据读取的内容创建任务...",
      }];
    }
  }

  // 默认：结束 run，返回最终摘要
  const output = toText(latestStep.output_text) || "执行完毕。";
  return [{
    kind: "done",
    summary: `目标「${goal.slice(0, 30)}」处理完成`,
    output_text: output,
    result_json: toAgentJson({ source_tool: toolName }),
  }];
}
