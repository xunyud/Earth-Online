import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  inferAgentRiskLevel,
  isSensitivePath,
  requiresAgentConfirmation,
} from "./agent_policy.ts";

Deno.test("isSensitivePath 会识别敏感目录与凭据文件", () => {
  assertEquals(isSensitivePath("C:/Users/demo/.ssh/id_rsa"), true);
  assertEquals(isSensitivePath("D:/workspace/project/README.md"), false);
});

Deno.test("inferAgentRiskLevel 会将只读 shell 命令识别为低风险", () => {
  assertEquals(
    inferAgentRiskLevel("shell.exec", { command: "git status" }),
    "low",
  );
  assertEquals(
    inferAgentRiskLevel("shell.exec", { command: "flutter analyze" }),
    "low",
  );
});

Deno.test("inferAgentRiskLevel 会将写操作 shell 命令识别为高风险", () => {
  assertEquals(
    inferAgentRiskLevel("shell.exec", { command: "npm install axios" }),
    "high",
  );
  assertEquals(
    inferAgentRiskLevel("shell.exec", { command: "git push origin main" }),
    "high",
  );
});

Deno.test("inferAgentRiskLevel 会将敏感路径文件读取识别为高风险", () => {
  assertEquals(
    inferAgentRiskLevel("file.read_text", { path: "C:/Users/demo/.env" }),
    "high",
  );
});

Deno.test("inferAgentRiskLevel 会按业务动作区分 app 工具风险", () => {
  assertEquals(
    inferAgentRiskLevel("app.navigation.open", { target: "stats" }),
    "low",
  );
  assertEquals(
    inferAgentRiskLevel("app.quest.create", { title: "整理会议材料" }),
    "medium",
  );
  assertEquals(
    inferAgentRiskLevel("app.quest.update", { task_title: "准备周会" }),
    "medium",
  );
  assertEquals(
    inferAgentRiskLevel("app.quest.split", { task_title: "准备周会" }),
    "medium",
  );
  assertEquals(
    inferAgentRiskLevel("app.reward.redeem", { reward_title: "森林主题" }),
    "medium",
  );
  assertEquals(
    inferAgentRiskLevel("app.weekly_summary.generate", {}),
    "low",
  );
  assertEquals(
    inferAgentRiskLevel("app.chat.freeform.respond", { source_text: "你是谁" }),
    "low",
  );
});

Deno.test("requiresAgentConfirmation 仅对非低风险工具返回 true", () => {
  assertEquals(
    requiresAgentConfirmation("browser.open", { url: "https://example.com" }),
    false,
  );
  assertEquals(
    requiresAgentConfirmation("app.navigation.open", { target: "stats" }),
    false,
  );
  assertEquals(
    requiresAgentConfirmation("app.chat.freeform.respond", { source_text: "你是谁" }),
    false,
  );
  assertEquals(
    requiresAgentConfirmation("app.quest.create", { title: "整理会议材料" }),
    true,
  );
  assertEquals(
    requiresAgentConfirmation("browser.click", { selector: "button.submit" }),
    true,
  );
});
