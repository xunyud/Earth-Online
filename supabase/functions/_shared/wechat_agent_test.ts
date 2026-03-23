import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  formatWechatGuideReply,
  parseBoundWechatMessage,
} from "./wechat_agent.ts";

Deno.test("parseBoundWechatMessage 会识别问村长前缀", () => {
  const result = parseBoundWechatMessage("问村长：我今天有点乱");

  assertEquals(result, {
    kind: "guide_chat",
    message: "我今天有点乱",
  });
});

Deno.test("parseBoundWechatMessage 会识别收下建议指令", () => {
  const result = parseBoundWechatMessage("收下建议");

  assertEquals(result, { kind: "accept_suggestion" });
});

Deno.test("parseBoundWechatMessage 默认保持普通任务录入", () => {
  const result = parseBoundWechatMessage("明天下午去医院复诊");

  assertEquals(result, {
    kind: "task_capture",
    text: "明天下午去医院复诊",
  });
});

Deno.test("parseBoundWechatMessage 会把求助型自然语言识别为聊天", () => {
  const result = parseBoundWechatMessage("我现在很乱，帮我稳一下节奏");

  assertEquals(result, {
    kind: "guide_chat",
    message: "我现在很乱，帮我稳一下节奏",
  });
});

Deno.test("parseBoundWechatMessage 会把恢复建议类提问识别为聊天", () => {
  const result = parseBoundWechatMessage("能不能给我一个恢复任务？");

  assertEquals(result, {
    kind: "guide_chat",
    message: "能不能给我一个恢复任务？",
  });
});

Deno.test("formatWechatGuideReply 会附加名字和收下建议提示", () => {
  const reply = formatWechatGuideReply("阿木", "可以，我们先把节奏稳下来。", {
    title: "恢复支线：散步 10 分钟",
    description: "先离开屏幕活动一下",
    xp_reward: 18,
    quest_tier: "Daily",
  });

  assertEquals(
    reply,
    "阿木：可以，我们先把节奏稳下来。\n\n建议任务：恢复支线：散步 10 分钟\n回复“收下建议”即可创建。",
  );
});
