/**
 * agent_tool_execution_test.ts
 * 覆盖 agent 工具执行路径的关键场景：
 * 1. planner 对 file/shell 意图的路由（修复后的新路径）
 * 2. continueAgentAfterTool 各工具的 continuation 输出
 * 3. agent-step-complete handler 的成功/失败分支
 *
 * 日期：2026-04-22
 * 执行者：Kiro
 */

import {
  assertEquals,
  assertExists,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { planAgentGoal, continueAgentAfterTool } from "./agent_planner.ts";
import { createAgentStepCompleteHandler } from "../agent-step-complete/index.ts";
import type {
  AgentRunSnapshot,
  SerializedAgentRun,
  SerializedAgentRunStep,
} from "./agent_engine.ts";
import type { AgentJson, AgentRunStatus } from "./agent_types.ts";
import type { AgentPlannerStepDraft } from "./agent_planner.ts";

// ─── 辅助函数 ────────────────────────────────────────────────────────────────

function makeStep(
  overrides: Partial<SerializedAgentRunStep> = {},
): SerializedAgentRunStep {
  return {
    id: "step-1",
    run_id: "run-1",
    step_index: 0,
    kind: "tool_call",
    tool_name: null,
    arguments_json: {},
    risk_level: "low",
    needs_confirmation: false,
    status: "succeeded",
    summary: "",
    output_text: null,
    result_json: null,
    error_text: null,
    created_at: null,
    updated_at: null,
    started_at: null,
    finished_at: null,
    ...overrides,
  };
}

function makeRun(status: AgentRunStatus = "running"): SerializedAgentRun {
  return {
    id: "run-1",
    user_id: "user-1",
    goal: "test goal",
    channel: "desktop",
    status,
    summary: null,
    last_error: null,
    created_at: null,
    updated_at: null,
    started_at: null,
    finished_at: null,
  };
}

// ─── 1. Planner：file/shell 意图路由（修复后不再是死代码）────────────────────

Deno.test("planAgentGoal 为 README 文件意图生成 file.read_text 步骤", () => {
  const result = planAgentGoal("帮我读一下 README.md 的内容");

  assertEquals(result.steps.length, 1);
  assertEquals(result.steps[0].kind, "tool_call");
  if (result.steps[0].kind !== "tool_call") throw new Error("expected tool_call");
  assertEquals(result.steps[0].tool_name, "file.read_text");
  const args = result.steps[0].arguments_json as Record<string, AgentJson>;
  assertExists(args["path"]);
  assertStringIncludes(`${args["path"]}`, "README");
});

Deno.test("planAgentGoal 为 check file 意图生成 file.read_text 步骤", () => {
  const result = planAgentGoal("check the config file");

  assertEquals(result.steps[0].kind, "tool_call");
  if (result.steps[0].kind !== "tool_call") throw new Error("expected tool_call");
  assertEquals(result.steps[0].tool_name, "file.read_text");
});

Deno.test("planAgentGoal 为 run tests 意图生成 shell.exec 步骤", () => {
  const result = planAgentGoal("run tests and show me the output");

  assertEquals(result.steps[0].kind, "tool_call");
  if (result.steps[0].kind !== "tool_call") throw new Error("expected tool_call");
  assertEquals(result.steps[0].tool_name, "shell.exec");
  const args = result.steps[0].arguments_json as Record<string, AgentJson>;
  assertStringIncludes(`${args["command"]}`, "flutter test");
});

Deno.test("planAgentGoal 为 analyze 意图生成 flutter analyze shell 步骤", () => {
  const result = planAgentGoal("analyze the project for errors");

  assertEquals(result.steps[0].kind, "tool_call");
  if (result.steps[0].kind !== "tool_call") throw new Error("expected tool_call");
  assertEquals(result.steps[0].tool_name, "shell.exec");
  const args = result.steps[0].arguments_json as Record<string, AgentJson>;
  assertStringIncludes(`${args["command"]}`, "flutter analyze");
});

Deno.test("planAgentGoal file 意图不会被 freeform chat 拦截", () => {
  // 修复前 normalizedGoal.length > 0 会先命中，导致 file.read_text 永远不出现
  const result = planAgentGoal("read the documentation file");
  const toolName = result.steps[0].kind === "tool_call"
    ? result.steps[0].tool_name
    : null;
  assertEquals(toolName, "file.read_text");
});

// ─── 2. continueAgentAfterTool：各工具的 continuation 输出 ──────────────────

Deno.test("continueAgentAfterTool 为 file.read_text 生成 done 步骤并包含预览", () => {
  const completedStep = makeStep({
    tool_name: "file.read_text",
    arguments_json: { path: "README.md" },
  });
  const resultJson: AgentJson = {
    path: "README.md",
    text: "# Earth Online\n\nA memory-aware productivity game.",
    char_count: 48,
  };

  const drafts = continueAgentAfterTool("读取 README", completedStep, resultJson);

  assertEquals(drafts.length, 1);
  assertEquals(drafts[0].kind, "done");
  assertStringIncludes(drafts[0].summary, "README");
  assertStringIncludes(`${drafts[0].output_text}`, "README.md");
});

Deno.test("continueAgentAfterTool 为 shell.exec 生成 done 步骤并包含命令摘要", () => {
  const completedStep = makeStep({
    tool_name: "shell.exec",
    arguments_json: { command: "git status", cwd: "." },
  });
  const resultJson: AgentJson = {
    command: "git status",
    stdout: "On branch main\nnothing to commit",
    stderr: "",
    exit_code: 0,
  };

  const drafts = continueAgentAfterTool("执行 git status", completedStep, resultJson);

  assertEquals(drafts.length, 1);
  assertEquals(drafts[0].kind, "done");
  assertStringIncludes(drafts[0].summary, "git status");
  assertStringIncludes(`${drafts[0].output_text}`, "git status");
});

Deno.test("continueAgentAfterTool 为 app.quest.create 生成 done 步骤", () => {
  const completedStep = makeStep({
    tool_name: "app.quest.create",
    output_text: "已创建任务：整理会议材料",
  });

  const drafts = continueAgentAfterTool("创建任务", completedStep);

  assertEquals(drafts.length, 1);
  assertEquals(drafts[0].kind, "done");
  assertStringIncludes(drafts[0].summary, "app.quest.create");
});

Deno.test("continueAgentAfterTool 为 app.navigation.open 生成 done 步骤", () => {
  const completedStep = makeStep({
    tool_name: "app.navigation.open",
    output_text: "已打开统计页",
  });

  const drafts = continueAgentAfterTool("打开统计页", completedStep);

  assertEquals(drafts.length, 1);
  assertEquals(drafts[0].kind, "done");
});

Deno.test("continueAgentAfterTool 对未知工具也生成 done 步骤", () => {
  const completedStep = makeStep({ tool_name: "unknown.tool" });

  const drafts = continueAgentAfterTool("unknown", completedStep);

  assertEquals(drafts.length, 1);
  assertEquals(drafts[0].kind, "done");
});

// ─── 3. agent-step-complete handler：成功/失败分支 ───────────────────────────

function makeCompleteHandlerDeps(opts: {
  stepToReturn?: Partial<SerializedAgentRunStep>;
  runStatus?: AgentRunStatus;
  continuationDrafts?: AgentPlannerStepDraft[];
}) {
  const steps: SerializedAgentRunStep[] = [];
  const runStatuses: AgentRunStatus[] = [];

  const baseStep = makeStep(opts.stepToReturn ?? {});
  const run = makeRun(opts.runStatus ?? "running");

  return {
    runStatuses,
    steps,
    authenticate: async (token: string) =>
      token === "valid" ? { id: "user-1" } : null,
    updateStepStatus: async (
      stepId: string,
      status: string,
      extras?: Record<string, unknown>,
    ) => ({ ...baseStep, id: stepId, status } as SerializedAgentRunStep),
    appendStep: async (opts: Record<string, unknown>) => {
      const step = makeStep({
        id: `appended-${steps.length}`,
        kind: `${opts.kind ?? "done"}` as SerializedAgentRunStep["kind"],
        summary: `${opts.summary ?? ""}`,
        status: `${opts.status ?? "succeeded"}` as SerializedAgentRunStep["status"],
      });
      steps.push(step);
      return step;
    },
    updateRunStatus: async (runId: string, status: AgentRunStatus) => {
      runStatuses.push(status);
      return { ...run, id: runId, status } as SerializedAgentRun;
    },
    loadSnapshot: async (runId: string, userId: string): Promise<AgentRunSnapshot> => ({
      run: { ...run, id: runId },
      steps: [{ ...baseStep, id: "step-1" }],
    }),
    continueRun: (
      goal: string,
      completedStep: SerializedAgentRunStep,
      resultJson?: AgentJson,
    ): AgentPlannerStepDraft[] =>
      opts.continuationDrafts ?? [{
        kind: "done",
        summary: "完成",
        output_text: "已完成工具执行。",
      }],
    now: () => "2026-04-22T00:00:00.000Z",
  };
}

Deno.test("agent-step-complete 成功时追加 continuation 步骤并更新 run 状态", async () => {
  const deps = makeCompleteHandlerDeps({
    stepToReturn: { id: "step-1", tool_name: "app.quest.create", status: "succeeded" },
  });
  const handler = createAgentStepCompleteHandler(deps as never);

  const response = await handler(
    new Request("http://localhost/agent-step-complete", {
      method: "POST",
      headers: { "Authorization": "Bearer valid", "Content-Type": "application/json" },
      body: JSON.stringify({
        run_id: "run-1",
        step_id: "step-1",
        success: true,
        output_text: "已创建任务：整理会议材料",
        result_json: { created_task_id: "quest-abc", created_task_title: "整理会议材料" },
      }),
    }),
  );

  assertEquals(response.status, 200);
  const payload = await response.json();
  assertEquals(payload.success, true);
  assertExists(payload.run);
  assertExists(payload.steps);
  // continuation 步骤已追加
  assertEquals(deps.steps.length, 1);
  assertEquals(deps.steps[0].kind, "done");
});

Deno.test("agent-step-complete 失败时追加 error 步骤并将 run 标记为 failed", async () => {
  const deps = makeCompleteHandlerDeps({
    stepToReturn: { id: "step-1", tool_name: "shell.exec", status: "failed" },
  });
  const handler = createAgentStepCompleteHandler(deps as never);

  const response = await handler(
    new Request("http://localhost/agent-step-complete", {
      method: "POST",
      headers: { "Authorization": "Bearer valid", "Content-Type": "application/json" },
      body: JSON.stringify({
        run_id: "run-1",
        step_id: "step-1",
        success: false,
        error_text: "命令执行失败：exit code 1",
      }),
    }),
  );

  assertEquals(response.status, 200);
  const payload = await response.json();
  assertEquals(payload.success, true);
  // error 步骤已追加
  assertEquals(deps.steps.length, 1);
  assertEquals(deps.steps[0].kind, "error");
  // run 被标记为 failed
  assertEquals(deps.runStatuses.at(-1), "failed");
});

Deno.test("agent-step-complete 缺少 run_id 时返回 400", async () => {
  const deps = makeCompleteHandlerDeps({});
  const handler = createAgentStepCompleteHandler(deps as never);

  const response = await handler(
    new Request("http://localhost/agent-step-complete", {
      method: "POST",
      headers: { "Authorization": "Bearer valid", "Content-Type": "application/json" },
      body: JSON.stringify({ step_id: "step-1", success: true }),
    }),
  );

  assertEquals(response.status, 400);
});

Deno.test("agent-step-complete 无效 token 时返回 401", async () => {
  const deps = makeCompleteHandlerDeps({});
  const handler = createAgentStepCompleteHandler(deps as never);

  const response = await handler(
    new Request("http://localhost/agent-step-complete", {
      method: "POST",
      headers: { "Authorization": "Bearer invalid", "Content-Type": "application/json" },
      body: JSON.stringify({ run_id: "run-1", step_id: "step-1", success: true }),
    }),
  );

  assertEquals(response.status, 401);
});
