import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  buildLocalToolStepDraft,
  inferRunStatusFromSteps,
  serializeAgentRun,
  serializeAgentRunStep,
} from "./agent_engine.ts";
import { toAgentJson } from "./agent_types.ts";

Deno.test("serializeAgentRun 会归一化状态与空字段", () => {
  const row = serializeAgentRun({
    id: "run-1",
    user_id: "user-1",
    goal: " 读取 README ",
    status: "running",
    summary: " ",
  });

  assertEquals(row?.goal, "读取 README");
  assertEquals(row?.status, "running");
  assertEquals(row?.summary, null);
});

Deno.test("serializeAgentRunStep 会填充默认值", () => {
  const row = serializeAgentRunStep({
    id: "step-1",
    run_id: "run-1",
    step_index: 2,
    kind: "tool_call",
    tool_name: "file.read_text",
    status: "ready",
  });

  assertEquals(row?.risk_level, "low");
  assertEquals(row?.needs_confirmation, false);
  assertEquals(row?.arguments_json, {});
});

Deno.test("buildLocalToolStepDraft 会为高风险 shell 标记确认", () => {
  const draft = buildLocalToolStepDraft({
    tool_name: "shell.exec",
    arguments: { command: "git push origin main" },
    summary: "推送主分支",
  });

  assertEquals(draft.risk_level, "high");
  assertEquals(draft.needs_confirmation, true);
  assertEquals(draft.status, "waiting_approval");
});

Deno.test("inferRunStatusFromSteps 会根据末尾 step 推断 waiting_local_execution", () => {
  const status = inferRunStatusFromSteps([
    {
      id: "step-1",
      run_id: "run-1",
      step_index: 0,
      kind: "tool_call",
      tool_name: "file.read_text",
      arguments_json: {},
      risk_level: "low",
      needs_confirmation: false,
      status: "ready",
      summary: "读取文件",
      output_text: null,
      result_json: null,
      error_text: null,
      created_at: null,
      updated_at: null,
      started_at: null,
      finished_at: null,
    },
  ]);

  assertEquals(status, "waiting_local_execution");
});

Deno.test("inferRunStatusFromSteps 会识别 done+succeeded", () => {
  const status = inferRunStatusFromSteps([
    {
      id: "step-2",
      run_id: "run-1",
      step_index: 1,
      kind: "done",
      tool_name: null,
      arguments_json: {},
      risk_level: "low",
      needs_confirmation: false,
      status: "succeeded",
      summary: "已完成",
      output_text: null,
      result_json: null,
      error_text: null,
      created_at: null,
      updated_at: null,
      started_at: null,
      finished_at: null,
    },
  ]);

  assertEquals(status, "succeeded");
  assertExists(status);
});

Deno.test("toAgentJson 会递归归一化对象与数组结构", () => {
  const normalized = toAgentJson({
    behavior_signals: ["focus", 3, true, { mode: "deep" }],
    memory_refs: [
      { id: "memo-1", score: 0.8 },
      null,
    ],
    fallback: undefined,
  });

  assertEquals(normalized, {
    behavior_signals: ["focus", 3, true, { mode: "deep" }],
    memory_refs: [
      { id: "memo-1", score: 0.8 },
      null,
    ],
    fallback: null,
  });
});
