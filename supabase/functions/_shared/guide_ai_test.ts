import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  buildChatFallback,
  buildEventFallback,
  buildProactiveFallback,
  normalizeOpenAICompatibleBaseUrl,
} from "./guide_ai.ts";
import type { GuideMemoryBundle } from "./guide_memory.ts";

function buildMemoryBundle(
  overrides: Partial<GuideMemoryBundle> = {},
): GuideMemoryBundle {
  return {
    recent_context: [],
    long_term_callbacks: [],
    behavior_signals: [],
    memory_refs: [],
    memory_digest: "",
    packed_context: "",
    ...overrides,
  };
}

Deno.test("buildChatFallback returns English guidance for English input", () => {
  const draft = buildChatFallback(
    buildMemoryBundle({
      recent_context: [
        "You mentioned two meetings tomorrow and a project outline due on Friday.",
      ],
    }),
    "What should I focus on first today?",
  );

  assert(
    /^i\b/i.test(draft.reply) || /focus|today|first/i.test(draft.reply),
    `expected English reply, got: ${draft.reply}`,
  );
  assertEquals(draft.quick_actions.length, 3);
  assert(/continue with today/i.test(draft.quick_actions[0]));
  assert(/review last week/i.test(draft.quick_actions[1]));
  assert(/recovery/i.test(draft.quick_actions[2]));
});

Deno.test("buildProactiveFallback returns English copy for English memory context", () => {
  const message = buildProactiveFallback(
    buildMemoryBundle({
      recent_context: [
        "You have a deadline coming up and two follow-ups from yesterday.",
      ],
      long_term_callbacks: ["You tend to feel overloaded before meetings."],
    }),
  );

  assert(
    /small step|reviewed|recent|memory|today/i.test(message),
    `expected English proactive fallback, got: ${message}`,
  );
});

Deno.test("buildEventFallback returns English event copy for English signals", () => {
  const draft = buildEventFallback(
    buildMemoryBundle({
      behavior_signals: ["late night work", "high pressure", "fatigue"],
    }),
  );

  assert(
    /^[A-Za-z]/.test(draft.title),
    `expected English event title, got: ${draft.title}`,
  );
  assert(
    /^[A-Za-z]/.test(draft.description),
    `expected English event description, got: ${draft.description}`,
  );
});

Deno.test("normalizeOpenAICompatibleBaseUrl appends /v1 for root-compatible endpoints", () => {
  assertEquals(
    normalizeOpenAICompatibleBaseUrl("https://api.86gamestore.com"),
    "https://api.86gamestore.com/v1",
  );
  assertEquals(
    normalizeOpenAICompatibleBaseUrl("https://api.86gamestore.com/"),
    "https://api.86gamestore.com/v1",
  );
  assertEquals(
    normalizeOpenAICompatibleBaseUrl("https://api.86gamestore.com/v1"),
    "https://api.86gamestore.com/v1",
  );
});
