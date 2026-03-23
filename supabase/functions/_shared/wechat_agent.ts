import type { GuideSuggestedTask } from "./guide_ai.ts";

function toText(value: unknown) {
  if (typeof value === "string") return value.trim();
  if (value == null) return "";
  return String(value).trim();
}

function matchesAnyPattern(text: string, patterns: RegExp[]) {
  return patterns.some((pattern) => pattern.test(text));
}

function shouldRouteToGuideChat(text: string) {
  const guidePatterns = [
    /[\?\uff1f]/,
    /\u5e2e\u6211/,
    /\u7a33\u4e00\u4e0b/,
    /\u6062\u590d\u4efb\u52a1/,
    /\u6062\u590d\u652f\u7ebf/,
    /\u804a\u804a/,
    /\u600e\u4e48\u529e/,
    /\u6709\u70b9\u4e71/,
    /\u4e0d\u5b89/,
    /\u7126\u8651/,
    /\u8ff7\u832b/,
    /\u5361\u4f4f/,
    /\u7d2f\u6b7b/,
  ];
  if (matchesAnyPattern(text, guidePatterns)) {
    return true;
  }

  const taskPatterns = [
    /\d{1,2}[:\uff1a]\d{2}/,
    /\u4eca\u5929|\u660e\u5929|\u4eca\u665a|\u4e0b\u5348|\u4e0a\u5348|\u5468[\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u65e5\u5929]/,
    /\u53bb|\u505a|\u5b8c\u6210|\u63d0\u4ea4|\u6574\u7406|\u590d\u76d8|\u5f00\u4f1a|\u8054\u7cfb|\u8d2d\u4e70|\u56de\u590d|\u63d0\u9192/,
  ];
  if (matchesAnyPattern(text, taskPatterns)) {
    return false;
  }

  const relaxedGuidePatterns = [
    /\u6211\u73b0\u5728/,
    /\u6211\u89c9\u5f97/,
    /\u6211\u60f3/,
    /\u80fd\u4e0d\u80fd/,
    /\u53ef\u4e0d\u53ef\u4ee5/,
  ];
  return matchesAnyPattern(text, relaxedGuidePatterns);
}

export function parseBoundWechatMessage(content: string) {
  const text = toText(content);
  if (!text) return { kind: "empty" } as const;
  if (
    text === "\u6536\u4e0b\u5efa\u8bae" ||
    text === "\u6536\u4e0b\u4efb\u52a1"
  ) {
    return { kind: "accept_suggestion" } as const;
  }

  const guidePrefixes = [
    "\u95ee\u6751\u957f\uff1a",
    "\u95ee\u6751\u957f:",
    "\u6751\u957f\uff1a",
    "\u6751\u957f:",
  ];
  for (const prefix of guidePrefixes) {
    if (text.startsWith(prefix)) {
      const message = toText(text.slice(prefix.length));
      if (!message) return { kind: "empty" } as const;
      return {
        kind: "guide_chat",
        message,
      } as const;
    }
  }

  if (shouldRouteToGuideChat(text)) {
    return {
      kind: "guide_chat",
      message: text,
    } as const;
  }

  return {
    kind: "task_capture",
    text,
  } as const;
}

export function formatWechatGuideReply(
  guideName: string,
  reply: string,
  suggestedTask?: GuideSuggestedTask | null,
) {
  const cleanGuideName = toText(guideName) || "\u5c0f\u5fc6";
  const cleanReply = toText(reply) ||
    "\u6211\u5728\uff0c\u60f3\u548c\u6211\u804a\u804a\u73b0\u5728\u6700\u5361\u7684\u5730\u65b9\u5417\uff1f";
  const guidePrefix = `${cleanGuideName}\uff1a`;
  const replyWithName = cleanReply.startsWith(guidePrefix)
    ? cleanReply
    : `${guidePrefix}${cleanReply}`;

  if (!suggestedTask) return replyWithName;
  return `${replyWithName}\n\n\u5efa\u8bae\u4efb\u52a1\uff1a${suggestedTask.title}\n\u56de\u590d\u201c\u6536\u4e0b\u5efa\u8bae\u201d\u5373\u53ef\u521b\u5efa\u3002`;
}
