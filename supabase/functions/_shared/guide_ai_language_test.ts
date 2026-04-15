import { assertEquals, assertMatch } from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  buildChatFallback,
  buildProactiveFallback,
  resolveGuideLanguage,
} from "./guide_ai.ts";
import type { GuideMemoryBundle } from "./guide_memory.ts";

const memory: GuideMemoryBundle = {
  recent_context: ["Project outline due Friday"],
  long_term_callbacks: ["You tend to feel overloaded before deadlines"],
  behavior_signals: ["deadline pressure"],
  memory_refs: ["m1"],
  memory_digest: "Project outline and deadline pressure",
  packed_context: "Project outline due Friday. Deadline pressure building.",
};

Deno.test("resolveGuideLanguage prioritizes explicit English client context", () => {
  assertEquals(
    resolveGuideLanguage(memory, { message: "我今天有点乱", clientContext: { language_code: "en" } }),
    "en",
  );
  assertEquals(
    resolveGuideLanguage(memory, { message: "我今天有点乱", clientContext: { locale: "en-US" } }),
    "en",
  );
  assertEquals(
    resolveGuideLanguage(memory, { message: "我今天有点乱", clientContext: { is_english: true } }),
    "en",
  );
});

Deno.test("resolveGuideLanguage falls back to message content when no context exists", () => {
  assertEquals(
    resolveGuideLanguage(
      { ...memory, recent_context: [], long_term_callbacks: [], behavior_signals: [], memory_digest: "", packed_context: "" },
      { message: "What should I focus on first today?" },
    ),
    "en",
  );
  assertEquals(
    resolveGuideLanguage(
      { ...memory, recent_context: [], long_term_callbacks: [], behavior_signals: [], memory_digest: "", packed_context: "" },
      { message: "我今天有点乱" },
    ),
    "zh",
  );
});

Deno.test("buildChatFallback returns English reply, actions, and task in English mode", () => {
  const draft = buildChatFallback(
    memory,
    "I feel overloaded. Give me a recovery step.",
    { language_code: "en" },
  );

  assertMatch(draft.reply, /I|you|today/i);
  assertEquals(draft.quick_actions, [
    "Continue with today",
    "Review last week",
    "Give me a recovery task",
  ]);
  assertMatch(draft.suggested_task?.title ?? "", /stretch|water|walk|reset/i);
});

Deno.test("buildProactiveFallback returns English copy in English mode", () => {
  const message = buildProactiveFallback(memory, { language_code: "en" });

  assertMatch(message, /recent|memory|start|small/i);
});
