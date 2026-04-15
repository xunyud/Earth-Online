import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { planAgentGoal } from "./agent_planner.ts";
import type { AgentJson } from "./agent_types.ts";

function toolArguments(value: AgentJson) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("expected tool arguments object");
  }
  return value as Record<string, AgentJson>;
}

Deno.test("planAgentGoal 为任务创建意图生成 app.quest.create 步骤", () => {
  const result = planAgentGoal("帮我创建一个今天能开做的任务：整理会议材料");

  assertEquals(result.steps.length, 1);
  assertEquals(result.steps[0].kind, "tool_call");
  if (result.steps[0].kind !== "tool_call") {
    throw new Error("expected tool_call step");
  }
  assertEquals(result.steps[0].tool_name, "app.quest.create");
  assertEquals(
    toolArguments(result.steps[0].arguments_json)["source_text"],
    "帮我创建一个今天能开做的任务：整理会议材料",
  );
  assertStringIncludes(`${result.summary}`, "任务");
});

Deno.test("planAgentGoal 为任务修改意图生成 app.quest.update 步骤", () => {
  const result = planAgentGoal("把“准备周会”改成明晚截止");

  assertEquals(result.steps.length, 1);
  assertEquals(result.steps[0].kind, "tool_call");
  if (result.steps[0].kind !== "tool_call") {
    throw new Error("expected tool_call step");
  }
  assertEquals(result.steps[0].tool_name, "app.quest.update");
  assertEquals(
    toolArguments(result.steps[0].arguments_json)["task_title"],
    "准备周会",
  );
});

Deno.test("planAgentGoal 为任务拆分意图生成 app.quest.split 步骤", () => {
  const result = planAgentGoal("把“准备周会”拆成三步");

  assertEquals(result.steps.length, 1);
  assertEquals(result.steps[0].kind, "tool_call");
  if (result.steps[0].kind !== "tool_call") {
    throw new Error("expected tool_call step");
  }
  assertEquals(result.steps[0].tool_name, "app.quest.split");
  assertEquals(
    toolArguments(result.steps[0].arguments_json)["task_title"],
    "准备周会",
  );
});

Deno.test("planAgentGoal 为周报生成意图生成 app.weekly_summary.generate 步骤", () => {
  const result = planAgentGoal("帮我生成本周周报");

  assertEquals(result.steps.length, 1);
  assertEquals(result.steps[0].kind, "tool_call");
  if (result.steps[0].kind !== "tool_call") {
    throw new Error("expected tool_call step");
  }
  assertEquals(result.steps[0].tool_name, "app.weekly_summary.generate");
});

Deno.test("planAgentGoal 为导航意图生成 app.navigation.open 步骤", () => {
  const result = planAgentGoal("打开统计页");

  assertEquals(result.steps.length, 1);
  assertEquals(result.steps[0].kind, "tool_call");
  if (result.steps[0].kind !== "tool_call") {
    throw new Error("expected tool_call step");
  }
  assertEquals(result.steps[0].tool_name, "app.navigation.open");
  assertEquals(
    toolArguments(result.steps[0].arguments_json)["target"],
    "stats",
  );
});

Deno.test("planAgentGoal 为奖励兑换意图生成 app.reward.redeem 步骤", () => {
  const result = planAgentGoal("帮我兑换森林主题");

  assertEquals(result.steps.length, 1);
  assertEquals(result.steps[0].kind, "tool_call");
  if (result.steps[0].kind !== "tool_call") {
    throw new Error("expected tool_call step");
  }
  assertEquals(result.steps[0].tool_name, "app.reward.redeem");
});

Deno.test("planAgentGoal 对普通聊天输入生成 app.chat.freeform.respond 步骤", () => {
  const result = planAgentGoal("你是谁");

  assertEquals(result.steps.length, 1);
  assertEquals(result.steps[0].kind, "tool_call");
  if (result.steps[0].kind !== "tool_call") {
    throw new Error("expected tool_call step");
  }
  assertEquals(result.steps[0].tool_name, "app.chat.freeform.respond");
  assertEquals(toolArguments(result.steps[0].arguments_json)["source_text"], "你是谁");
});
