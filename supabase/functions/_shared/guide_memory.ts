import {
  EverMemOSClient,
  parseSmartMemoryEnvelope,
} from "./evermemos_client.ts";

export type GuideMemoryBundle = {
  recent_context: string[];
  long_term_callbacks: string[];
  behavior_signals: string[];
  /** agentic 检索结果，仅 scene=agent 时有值，用于 agent 规划感知历史 */
  agentic_memory_lines: string[];
  memory_refs: string[];
  memory_digest: string;
  packed_context: string;
};

type GuideClientContext = {
  guide_name?: string;
  active_task_titles?: string[];
  active_task_ids?: string[];
  recently_deleted_task_titles?: string[];
  task_truth_rule?: string;
};

type GatherOptions = {
  scene?: string;
  userMessage?: string;
  clientContext?: Record<string, unknown>;
  maxRawItems?: number;
  maxPackedChars?: number;
};

export type GuideStructuredMemoryItem = {
  ref: string;
  rawText: string;
  displayText: string;
  memoryKind: string;
  sourceTaskId: string;
  sourceTaskTitle: string;
  sourceStatus: string;
  /** 记忆创建时间，支持 ISO 字符串、Unix 毫秒时间戳或 null */
  createdAt: string | number | null;
};

function toText(v: unknown) {
  if (typeof v === "string") return v.trim();
  if (v == null) return "";
  return String(v).trim();
}

function toNum(v: unknown, fallback = 0) {
  if (typeof v === "number" && Number.isFinite(v)) return v;
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
}

function toStringArray(value: unknown) {
  if (!Array.isArray(value)) return [] as string[];
  return value
    .map((item) => toText(item))
    .filter(Boolean);
}

function dateId(d: Date) {
  const y = d.getUTCFullYear().toString().padStart(4, "0");
  const m = (d.getUTCMonth() + 1).toString().padStart(2, "0");
  const day = d.getUTCDate().toString().padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function sameUtcDay(a: string | null, dayStartUtc: Date) {
  if (!a) return false;
  const parsed = new Date(a);
  if (Number.isNaN(parsed.getTime())) return false;
  return (
    parsed.getUTCFullYear() === dayStartUtc.getUTCFullYear() &&
    parsed.getUTCMonth() === dayStartUtc.getUTCMonth() &&
    parsed.getUTCDate() === dayStartUtc.getUTCDate()
  );
}

export function normalizeMemoryItems(
  raw: unknown,
): Array<Record<string, unknown> | string> {
  if (Array.isArray(raw)) return raw as Array<Record<string, unknown> | string>;
  if (!raw || typeof raw !== "object") return [];
  const map = raw as Record<string, unknown>;
  const candidates = [
    map.memories,
    map.results,
    map.items,
    map.data,
    (map.result as Record<string, unknown> | undefined)?.memories,
  ];
  for (const c of candidates) {
    if (Array.isArray(c)) return c as Array<Record<string, unknown> | string>;
  }
  return [];
}

function normalizeMemoryText(item: Record<string, unknown> | string) {
  if (typeof item === "string") return item.trim();
  const txt = toText(item.content) ||
    toText(item.text) ||
    toText(item.memory) ||
    toText(item.message) ||
    toText((item.data as Record<string, unknown> | undefined)?.content);
  return txt;
}

/**
 * 从原始记忆条目列表中过滤出历史反思记忆，最多返回 3 条文本。
 * 纯函数，便于属性测试。
 *
 * 逻辑：
 * 1. 仅保留文本中包含 "night_reflection" 的条目
 * 2. 取前 3 条（最近的 3 条，因为输入已按时间倒序排列）
 * 3. 提取文本内容，过滤空值
 */
export function filterReflectionHistory(
  items: Array<Record<string, unknown> | string>,
): string[] {
  return items
    .filter((item) => {
      const text = normalizeMemoryText(item);
      return text.includes("night_reflection");
    })
    .slice(0, 3)
    .map((item) => normalizeMemoryText(item))
    .filter(Boolean);
}

function normalizeMemoryRef(
  prefix: string,
  item: Record<string, unknown> | string,
  idx: number,
) {
  if (typeof item === "string") return `${prefix}:idx:${idx}`;
  const id = toText(item.id) ||
    toText(item.message_id) ||
    toText(item.request_id) ||
    toText((item.data as Record<string, unknown> | undefined)?.id);
  if (!id) return `${prefix}:idx:${idx}`;
  return `${prefix}:${id}`;
}

function compactLines(lines: string[], max = 60) {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const line of lines) {
    const norm = line.replace(/\s+/g, " ").trim();
    if (!norm) continue;
    if (seen.has(norm)) continue;
    seen.add(norm);
    out.push(norm);
    if (out.length >= max) break;
  }
  return out;
}

function capText(s: string, maxChars: number) {
  if (s.length <= maxChars) return s;
  return `${s.slice(0, Math.max(0, maxChars - 3))}...`;
}

function normalizeTaskKey(value: string) {
  return value.trim().toLowerCase();
}

function buildPackedContext(
  recentContext: string[],
  longTermCallbacks: string[],
  behaviorSignals: string[],
  maxChars: number,
) {
  const sections = [
    `【当前事实】\n${recentContext.map((x, i) => `${i + 1}. ${x}`).join("\n")}`,
    `【历史回调】\n${
      longTermCallbacks.map((x, i) => `${i + 1}. ${x}`).join("\n")
    }`,
    `【行为信号】\n${
      behaviorSignals.map((x, i) => `${i + 1}. ${x}`).join("\n")
    }`,
  ];
  let packed = sections.join("\n\n");
  if (packed.length <= maxChars) return packed;

  const recentTrimmed = recentContext.slice(
    0,
    Math.max(1, Math.floor(recentContext.length * 0.7)),
  );
  const longTrimmed = longTermCallbacks.slice(
    0,
    Math.max(1, Math.floor(longTermCallbacks.length * 0.7)),
  );
  const signalTrimmed = behaviorSignals.slice(
    0,
    Math.max(1, Math.floor(behaviorSignals.length * 0.8)),
  );
  packed = [
    `【当前事实】\n${recentTrimmed.map((x, i) => `${i + 1}. ${x}`).join("\n")}`,
    `【历史回调】\n${longTrimmed.map((x, i) => `${i + 1}. ${x}`).join("\n")}`,
    `【行为信号】\n${signalTrimmed.map((x, i) => `${i + 1}. ${x}`).join("\n")}`,
  ].join("\n\n");
  return capText(packed, maxChars);
}

function fallbackSignal(recentContext: string[]) {
  if (recentContext.length === 0) {
    return "最近有效样本较少，建议先完成一个最小动作再继续观察。";
  }
  return "近期行动仍有连续性，适合用当前任务板优先、历史记忆辅助的方式陪跑。";
}

function buildBehaviorSignals(opts: {
  todayCompletedCount: number;
  lateNightCount: number;
  perfectDays: number;
  streak: number;
  hasRecoveryKeyword: boolean;
  longTermCount: number;
  dialogRecallCount: number;
  recentlyDeletedCount: number;
  structuredMemories?: GuideStructuredMemoryItem[];
}) {
  const signals: string[] = [];
  if (opts.todayCompletedCount >= 5) {
    signals.push("今天完成任务密度较高，属于高强度推进日。");
  } else if (opts.todayCompletedCount >= 2) {
    signals.push("今天有连续推进动作，节奏仍处在可维持区间。");
  }
  if (opts.lateNightCount >= 2) {
    signals.push("近期出现夜间推进迹象，建议增加恢复性安排。");
  }
  if (opts.perfectDays >= 2) {
    signals.push("最近 7 天存在多次清盘日，执行稳定性较好。");
  }
  if (opts.streak >= 3) {
    signals.push(`当前连续打卡 ${opts.streak} 天，习惯链正在形成。`);
  }
  if (!opts.hasRecoveryKeyword && opts.todayCompletedCount > 0) {
    signals.push("恢复关键词偏少，后续可以补一些拉伸、补水或散步类任务。");
  }
  if (opts.longTermCount === 0) {
    signals.push("长期记忆召回偏少，后续可继续积累更稳定的历史样本。");
  }
  if (opts.dialogRecallCount > 0) {
    signals.push(
      `最近三天已有 ${opts.dialogRecallCount} 条向导对话，可用于避免重复话术。`,
    );
  }
  if (opts.recentlyDeletedCount > 0) {
    signals.push("最近有任务被移出当前任务板，历史任务记忆应降低优先级。");
  }

  // 注入习惯链信号：检测用户行为习惯链，将高置信度链注入 behavior_signals
  // 过滤置信度 >= 0.7 的链，按置信度降序取前 2 条
  // 异常时不影响已构建的原始 signals
  if (opts.structuredMemories) {
    try {
      const chains = detectHabitChains(opts.structuredMemories);
      const mentionable = filterMentionableChains(chains);
      for (const chain of mentionable) {
        signals.push(
          `habit_chain: ${chain.description}（连续${chain.consecutiveDays}天，置信度${(chain.confidence * 100).toFixed(0)}%）`,
        );
      }
    } catch {
      // 习惯链检测失败不影响原始信号构建
    }
  }

  return signals;
}

function normalizeClientContext(
  raw: Record<string, unknown> | undefined,
): GuideClientContext {
  const context = raw ?? {};
  return {
    guide_name: toText(context.guide_name),
    active_task_titles: toStringArray(context.active_task_titles),
    active_task_ids: toStringArray(context.active_task_ids),
    recently_deleted_task_titles: toStringArray(
      context.recently_deleted_task_titles,
    ),
    task_truth_rule: toText(context.task_truth_rule),
  };
}

export function normalizeStructuredMemoryItem(
  prefix: string,
  item: Record<string, unknown> | string,
  idx: number,
): GuideStructuredMemoryItem | null {
  const rawText = normalizeMemoryText(item);
  if (!rawText) return null;
  const ref = normalizeMemoryRef(prefix, item, idx);
  const parsed = parseSmartMemoryEnvelope(rawText);
  // 从原始条目中提取创建时间，兼容 EverMemOS 多种字段名
  const createdAt = typeof item === "string"
    ? null
    : (item.timestamp ?? item.created_at ?? item.createdAt ?? null) as
        | string
        | number
        | null;
  return {
    ref,
    rawText,
    displayText: parsed?.summary || rawText,
    memoryKind: parsed?.memoryKind || "generic",
    sourceTaskId: parsed?.sourceTaskId || "",
    sourceTaskTitle: parsed?.sourceTaskTitle || "",
    sourceStatus: parsed?.sourceStatus || "active",
    createdAt,
  };
}

export function shouldKeepStructuredMemoryItem(
  item: GuideStructuredMemoryItem,
  taskState: {
    activeTaskIds: Set<string>;
    deletedTaskIds: Set<string>;
    deletedTaskTitleKeys: Set<string>;
  },
) {
  if (item.sourceStatus === "inactive" || item.sourceStatus === "muted") {
    return false;
  }
  if (item.sourceTaskId) {
    if (taskState.deletedTaskIds.has(item.sourceTaskId)) return false;
    if (
      item.memoryKind === "task_event" && taskState.activeTaskIds.size > 0 &&
      !taskState.activeTaskIds.has(item.sourceTaskId)
    ) {
      return false;
    }
  }
  if (item.sourceTaskTitle) {
    const taskKey = normalizeTaskKey(item.sourceTaskTitle);
    if (taskKey && taskState.deletedTaskTitleKeys.has(taskKey)) return false;
  }
  return true;
}

/**
 * 计算记忆条目的时间衰减权重（基于 Ebbinghaus 遗忘曲线简化模型）。
 *
 * 权重区间：
 *   0–7 天 → 1.0（近期记忆，完全保留）
 *   8–30 天 → 0.6（中期记忆，适度衰减）
 *   31–90 天 → 0.3（远期记忆，显著衰减）
 *   91+ 天 → 0.1（历史记忆，大幅衰减）
 *
 * 特殊规则：
 *   - createdAt 为 null 或无效值时返回 0.1
 *   - memoryKind 为 "semantic_memory" 时始终返回 1.0（提取的行为模式不衰减）
 *
 * @param createdAt 记忆创建时间，支持 ISO 字符串、Unix 毫秒时间戳或 null
 * @param memoryKind 记忆类型，可选；"semantic_memory" 类型不衰减
 * @param now 当前时间的毫秒时间戳，默认 Date.now()；用于测试时注入固定时间
 */
export function computeDecayWeight(
  createdAt: string | number | null,
  memoryKind?: string,
  now?: number,
): number {
  // 语义记忆（提取的行为模式）始终保持最高权重，不受时间衰减影响
  if (memoryKind === "semantic_memory") return 1.0;

  if (!createdAt) return 0.1;

  const created = typeof createdAt === "number"
    ? createdAt
    : new Date(createdAt).getTime();

  if (Number.isNaN(created)) return 0.1;

  const currentTime = now ?? Date.now();
  const daysSinceCreation = (currentTime - created) / (24 * 60 * 60 * 1000);

  if (daysSinceCreation <= 7) return 1.0;
  if (daysSinceCreation <= 30) return 0.6;
  if (daysSinceCreation <= 90) return 0.3;
  return 0.1;
}

/**
 * 对检索结果应用时间衰减权重并重排序，截取前 N 条。
 *
 * 算法流程：
 *   1. 对每条记忆计算 finalScore = relevance × decayWeight
 *   2. 按 finalScore 降序排序
 *   3. 截取前 maxRawItems 条
 *   4. 中期记忆兜底：当截取结果中 7 天内的近期记忆不足 3 条，
 *      且存在未被选中的 8–90 天中期记忆时，用最佳中期记忆替换末位条目
 *
 * @param items 待排序的记忆条目列表
 * @param scores ref → 原始相关性分数的映射；缺失时默认 0.5
 * @param maxRawItems 最大输出条目数
 * @param now 当前时间毫秒时间戳，默认 Date.now()；用于测试注入
 */
export function applyDecayWeights(
  items: GuideStructuredMemoryItem[],
  scores: Map<string, number>,
  maxRawItems: number,
  now?: number,
): GuideStructuredMemoryItem[] {
  if (items.length === 0 || maxRawItems <= 0) return [];

  const currentTime = now ?? Date.now();
  const MS_PER_DAY = 24 * 60 * 60 * 1000;

  // 为每条记忆计算最终分数并排序
  const scored = items.map((item) => {
    const relevance = scores.get(item.ref) ?? 0.5;
    const decay = computeDecayWeight(item.createdAt, item.memoryKind, currentTime);
    return { item, finalScore: relevance * decay };
  });
  scored.sort((a, b) => b.finalScore - a.finalScore);

  // 截取前 N 条
  const selected = scored.slice(0, maxRawItems);

  // 辅助函数：计算条目距今天数
  const daysSince = (createdAt: string | number | null): number => {
    if (!createdAt) return Infinity;
    const created = typeof createdAt === "number"
      ? createdAt
      : new Date(createdAt).getTime();
    if (Number.isNaN(created)) return Infinity;
    return (currentTime - created) / MS_PER_DAY;
  };

  // 统计已选中条目中 7 天内的近期记忆数量
  const recentCount = selected.filter(
    (entry) => daysSince(entry.item.createdAt) <= 7,
  ).length;

  // 中期记忆兜底：近期不足 3 条时，保证至少保留 1 条 8–90 天的中期记忆
  if (recentCount < 3 && selected.length > 0) {
    const selectedRefs = new Set(selected.map((e) => e.item.ref));

    // 已选中的条目中是否已包含中期记忆
    const hasMidTermInSelected = selected.some((entry) => {
      const days = daysSince(entry.item.createdAt);
      return days >= 8 && days <= 90;
    });

    if (!hasMidTermInSelected) {
      // 从未被选中的条目中找最佳中期记忆（finalScore 最高的）
      const midTermCandidates = scored.filter((entry) => {
        if (selectedRefs.has(entry.item.ref)) return false;
        const days = daysSince(entry.item.createdAt);
        return days >= 8 && days <= 90;
      });

      if (midTermCandidates.length > 0) {
        // 用最佳中期记忆替换已选中列表的末位条目
        selected[selected.length - 1] = midTermCandidates[0];
      }
    }
  }

  return selected.map((entry) => entry.item);
}

function buildCurrentTaskFactLines(args: {
  clientContext: GuideClientContext;
  activeTaskTitles: string[];
  recentlyDeletedTaskTitles: string[];
}) {
  const lines: string[] = [];
  const activeTitles = args.activeTaskTitles.slice(0, 8);
  const deletedTitles = args.recentlyDeletedTaskTitles.slice(0, 8);
  if (activeTitles.length > 0) {
    lines.push(`当前任务板上仍存在的任务：${activeTitles.join("、")}`);
  } else {
    lines.push("当前任务板暂时为空。");
  }
  if (deletedTitles.length > 0) {
    lines.push(`最近被移除的任务：${deletedTitles.join("、")}`);
  }
  if (args.clientContext.task_truth_rule) {
    lines.push(`任务事实约束：${args.clientContext.task_truth_rule}`);
  }
  return lines;
}

// ─── 习惯链检测（纯函数，无副作用） ───

/** 习惯链类型：时段习惯 | 周期习惯 | 推进-恢复节奏 */
export type HabitChainType = "time_slot" | "weekly_cycle" | "push_recover";

/** 习惯链结构，描述用户检测到的重复行为模式 */
export type HabitChain = {
  type: HabitChainType;
  /** 人类可读描述，如"每天约 8 点完成任务" */
  description: string;
  /** 连续天数（time_slot/weekly_cycle）或出现次数（push_recover） */
  consecutiveDays: number;
  /** 置信度 0.0–1.0 */
  confidence: number;
};

/**
 * 将 createdAt 解析为 Date 对象，无效值返回 null。
 * 兼容 ISO 字符串和 Unix 毫秒时间戳。
 */
function parseCreatedAt(createdAt: string | number | null): Date | null {
  if (createdAt == null) return null;
  const d = typeof createdAt === "number"
    ? new Date(createdAt)
    : new Date(createdAt);
  return Number.isNaN(d.getTime()) ? null : d;
}

/**
 * 判断两个 YYYY-MM-DD 日期字符串是否为相邻的连续日期。
 */
function isConsecutiveDay(dayA: string, dayB: string): boolean {
  const a = new Date(dayA + "T00:00:00Z");
  const b = new Date(dayB + "T00:00:00Z");
  const diffMs = b.getTime() - a.getTime();
  return diffMs === 24 * 60 * 60 * 1000;
}

/**
 * 从习惯链列表中筛选可注入 behavior_signals 的链。
 * 规则：仅保留置信度 >= 0.7 的链，按置信度降序排列，最多取前 2 条。
 *
 * 此函数为纯函数，从 buildBehaviorSignals 中提取以便属性测试。
 */
export function filterMentionableChains(chains: HabitChain[]): HabitChain[] {
  return chains
    .filter((c) => c.confidence >= 0.7)
    .sort((a, b) => b.confidence - a.confidence)
    .slice(0, 2);
}

/**
 * 检测时段习惯链：连续 N 天（N >= 5）在相同时段（±2h）完成任务。
 *
 * 算法：
 * 1. 按 UTC 日期分组，提取每天最早的任务完成小时
 * 2. 从最早日期向后扫描连续天数，检查相邻天的完成小时差 <= 2
 * 3. 连续天数 >= 5 时生成习惯链，置信度 = min(consecutiveDays / 10, 1.0)
 */
export function detectTimeSlotChains(
  memories: GuideStructuredMemoryItem[],
  _now: Date,
): HabitChain[] {
  // 按 UTC 日期分组，记录每天最早的完成小时
  const dayHourMap = new Map<string, number>();

  for (const mem of memories) {
    const d = parseCreatedAt(mem.createdAt);
    if (!d) continue;
    const key = dateId(d);
    const hour = d.getUTCHours();
    const existing = dayHourMap.get(key);
    // 取每天最早的完成小时
    if (existing === undefined || hour < existing) {
      dayHourMap.set(key, hour);
    }
  }

  if (dayHourMap.size < 5) return [];

  // 按日期排序（升序）
  const sortedDays = [...dayHourMap.entries()]
    .sort((a, b) => a[0].localeCompare(b[0]));

  // 扫描连续天数中完成小时在 ±2h 范围内的最长序列
  const chains: HabitChain[] = [];
  let streakStart = 0;

  for (let i = 1; i <= sortedDays.length; i++) {
    // 检查是否连续日期且小时差 <= 2
    const shouldContinue = i < sortedDays.length &&
      isConsecutiveDay(sortedDays[i - 1][0], sortedDays[i][0]) &&
      Math.abs(sortedDays[i][1] - sortedDays[i - 1][1]) <= 2;

    if (!shouldContinue) {
      const streakLen = i - streakStart;
      if (streakLen >= 5) {
        // 计算该序列的平均完成小时，用于描述
        let totalHour = 0;
        for (let j = streakStart; j < i; j++) {
          totalHour += sortedDays[j][1];
        }
        const avgHour = Math.round(totalHour / streakLen);
        const confidence = Math.min(streakLen / 10, 1.0);
        chains.push({
          type: "time_slot",
          description: `每天约 ${avgHour} 点完成任务`,
          consecutiveDays: streakLen,
          confidence,
        });
      }
      streakStart = i;
    }
  }

  return chains;
}

/**
 * 检测周期习惯链：连续 3 个相同星期几完成特定类型任务。
 *
 * 算法：
 * 1. 按 (星期几, memoryKind) 分组，记录每组出现的周编号
 * 2. 检查连续周编号 >= 3 时生成习惯链
 * 3. 置信度 = min(consecutiveWeeks / 6, 1.0)
 */
export function detectWeeklyCycleChains(
  memories: GuideStructuredMemoryItem[],
  _now: Date,
): HabitChain[] {
  // 星期几名称映射
  const weekdayNames = ["日", "一", "二", "三", "四", "五", "六"];

  // 按 (weekday, memoryKind) 分组，收集出现的 ISO 周编号
  const groupWeeks = new Map<string, Set<number>>();

  for (const mem of memories) {
    const d = parseCreatedAt(mem.createdAt);
    if (!d) continue;
    const weekday = d.getUTCDay(); // 0=Sunday, 6=Saturday
    const kind = mem.memoryKind || "generic";
    const key = `${weekday}:${kind}`;
    // 计算周编号：用距 epoch 的天数除以 7
    const epochDays = Math.floor(d.getTime() / (24 * 60 * 60 * 1000));
    const weekNum = Math.floor(epochDays / 7);

    if (!groupWeeks.has(key)) {
      groupWeeks.set(key, new Set());
    }
    groupWeeks.get(key)!.add(weekNum);
  }

  const chains: HabitChain[] = [];

  for (const [key, weekSet] of groupWeeks) {
    if (weekSet.size < 3) continue;

    // 排序周编号，找最长连续序列
    const sortedWeeks = [...weekSet].sort((a, b) => a - b);
    let maxConsecutive = 1;
    let currentConsecutive = 1;

    for (let i = 1; i < sortedWeeks.length; i++) {
      if (sortedWeeks[i] === sortedWeeks[i - 1] + 1) {
        currentConsecutive++;
        if (currentConsecutive > maxConsecutive) {
          maxConsecutive = currentConsecutive;
        }
      } else {
        currentConsecutive = 1;
      }
    }

    if (maxConsecutive >= 3) {
      const [weekdayStr, kind] = key.split(":");
      const weekday = parseInt(weekdayStr, 10);
      const confidence = Math.min(maxConsecutive / 6, 1.0);
      chains.push({
        type: "weekly_cycle",
        description: `每周${weekdayNames[weekday]}完成 ${kind} 类型任务`,
        consecutiveDays: maxConsecutive * 7,
        confidence,
      });
    }
  }

  return chains;
}

/**
 * 检测推进-恢复节奏：高强度任务后 24h 内完成恢复类任务达 3 次。
 *
 * 算法：
 * 1. 识别高强度任务：memoryKind === "task_event"
 * 2. 识别恢复类任务：memoryKind === "dialog_event" 或 "generic"
 * 3. 对每个高强度任务，检查其后 24h 内是否有恢复类任务
 * 4. 统计匹配次数 >= 3 时生成习惯链
 * 5. 置信度 = min(occurrences / 5, 1.0)
 */
export function detectPushRecoverChains(
  memories: GuideStructuredMemoryItem[],
  _now: Date,
): HabitChain[] {
  const MS_24H = 24 * 60 * 60 * 1000;

  // 分离高强度任务和恢复类任务
  const highIntensity: Date[] = [];
  const recovery: Date[] = [];

  for (const mem of memories) {
    const d = parseCreatedAt(mem.createdAt);
    if (!d) continue;

    if (mem.memoryKind === "task_event") {
      highIntensity.push(d);
    } else if (
      mem.memoryKind === "dialog_event" || mem.memoryKind === "generic"
    ) {
      recovery.push(d);
    }
  }

  if (highIntensity.length === 0 || recovery.length === 0) return [];

  // 按时间升序排序
  highIntensity.sort((a, b) => a.getTime() - b.getTime());
  recovery.sort((a, b) => a.getTime() - b.getTime());

  // 统计"高强度任务后 24h 内有恢复任务"的次数
  let occurrences = 0;
  for (const hiTime of highIntensity) {
    const hiMs = hiTime.getTime();
    // 在恢复任务中查找 24h 内且在高强度任务之后的条目
    const hasRecovery = recovery.some((recTime) => {
      const recMs = recTime.getTime();
      return recMs > hiMs && recMs - hiMs <= MS_24H;
    });
    if (hasRecovery) {
      occurrences++;
    }
  }

  if (occurrences < 3) return [];

  const confidence = Math.min(occurrences / 5, 1.0);
  return [{
    type: "push_recover",
    description: "高强度任务后 24h 内完成恢复活动",
    consecutiveDays: occurrences,
    confidence,
  }];
}

/**
 * 检测用户习惯链（纯函数）。
 *
 * 基于最近 30 天的结构化记忆数据，检测三种行为模式：
 * 1. 时段习惯链：连续 5 天在相同时段（±2h）完成任务
 * 2. 周期习惯链：连续 3 个相同星期几完成特定类型任务
 * 3. 推进-恢复节奏：高强度任务后 24h 内完成恢复类任务达 3 次
 *
 * @param memories 用户最近 30 天的结构化记忆条目
 * @param nowDate 当前时间，默认 new Date()；用于测试注入
 * @returns 检测到的习惯链列表，空输入返回空列表
 */
export function detectHabitChains(
  memories: GuideStructuredMemoryItem[],
  nowDate?: Date,
): HabitChain[] {
  if (!memories || memories.length === 0) return [];

  const chains: HabitChain[] = [];
  const now = nowDate ?? new Date();

  const timeSlotChains = detectTimeSlotChains(memories, now);
  chains.push(...timeSlotChains);

  const weeklyCycleChains = detectWeeklyCycleChains(memories, now);
  chains.push(...weeklyCycleChains);

  const pushRecoverChains = detectPushRecoverChains(memories, now);
  chains.push(...pushRecoverChains);

  return chains;
}

/**
 * 判断习惯链是否即将断裂（预期时间窗口内无匹配行为）。
 *
 * 根据习惯链类型判断预期时间窗口：
 * - time_slot: 当天预期时段已过 2h 但无匹配记忆
 * - weekly_cycle: 当天是预期星期几但无匹配记忆
 * - push_recover: 最近一次高强度任务后 24h 内无恢复类记忆
 *
 * 纯函数，便于属性测试。
 *
 * @param chain 待检查的习惯链
 * @param memories 用户最近的结构化记忆条目
 * @param nowDate 当前时间，默认 new Date()；用于测试注入
 * @returns true 表示习惯链即将断裂，false 表示正常延续
 */
export function isChainBreaking(
  chain: HabitChain,
  memories: GuideStructuredMemoryItem[],
  nowDate?: Date,
): boolean {
  const now = nowDate ?? new Date();
  const todayStr = dateId(now);
  const currentHour = now.getUTCHours();

  // 收集今天的记忆条目
  const todayMemories = memories.filter((mem) => {
    const d = parseCreatedAt(mem.createdAt);
    return d != null && dateId(d) === todayStr;
  });

  if (chain.type === "time_slot") {
    // 从描述中提取预期小时，格式："每天约 N 点完成任务"
    const hourMatch = chain.description.match(/约\s*(\d+)\s*点/);
    if (!hourMatch) return false;
    const expectedHour = parseInt(hourMatch[1], 10);
    // 预期时段已过 2h 才判定为断裂（给用户缓冲时间）
    if (currentHour < expectedHour + 2) return false;
    // 检查今天是否有在预期时段 ±2h 内完成的记忆
    const hasMatch = todayMemories.some((mem) => {
      const d = parseCreatedAt(mem.createdAt);
      if (!d) return false;
      return Math.abs(d.getUTCHours() - expectedHour) <= 2;
    });
    return !hasMatch;
  }

  if (chain.type === "weekly_cycle") {
    // 从描述中提取预期星期几，格式："每周X完成 ... 类型任务"
    const weekdayNames = ["日", "一", "二", "三", "四", "五", "六"];
    const weekdayMatch = chain.description.match(/每周([\u4e00-\u9fa5])/);
    if (!weekdayMatch) return false;
    const expectedWeekday = weekdayNames.indexOf(weekdayMatch[1]);
    if (expectedWeekday < 0) return false;
    // 仅在当天是预期星期几时才检测
    if (now.getUTCDay() !== expectedWeekday) return false;
    // 检查今天是否有匹配的记忆
    return todayMemories.length === 0;
  }

  if (chain.type === "push_recover") {
    // 查找最近一次高强度任务（task_event），检查其后 24h 内是否有恢复类记忆
    const MS_24H = 24 * 60 * 60 * 1000;
    const highIntensityTimes: Date[] = [];
    for (const mem of memories) {
      const d = parseCreatedAt(mem.createdAt);
      if (d && mem.memoryKind === "task_event") {
        highIntensityTimes.push(d);
      }
    }
    if (highIntensityTimes.length === 0) return false;
    // 取最近一次高强度任务
    highIntensityTimes.sort((a, b) => b.getTime() - a.getTime());
    const latestHi = highIntensityTimes[0];
    const elapsed = now.getTime() - latestHi.getTime();
    // 仅在高强度任务后 24h 窗口内检测
    if (elapsed > MS_24H || elapsed < 0) return false;
    // 检查高强度任务之后是否有恢复类记忆
    const hasRecovery = memories.some((mem) => {
      const d = parseCreatedAt(mem.createdAt);
      if (!d) return false;
      if (mem.memoryKind !== "dialog_event" && mem.memoryKind !== "generic") {
        return false;
      }
      const recMs = d.getTime();
      return recMs > latestHi.getTime() && recMs <= now.getTime();
    });
    return !hasRecovery;
  }

  return false;
}

// ─── XP 倍率计算（纯函数，无副作用） ───

/**
 * 基于用户行为模式计算 XP 倍率。
 *
 * 规则：
 *   - 断签（currentStreak = 0）→ 0.8x
 *   - 恢复激励（previousStreak = 0 且 currentStreak = 1）→ 1.3x
 *   - 连续推进（currentStreak >= 3）→ 1.0 + 0.1 × min(currentStreak - 2, 5)，最高 1.5x
 *   - 其他情况 → 1.0x
 *   - 负数输入视为 0
 *
 * @param currentStreak 当前连续天数（非负整数，负数视为 0）
 * @param previousStreak 上一次连续天数（非负整数，负数视为 0）
 * @returns XP 倍率，范围 [0.8, 1.5]
 */
export function computeXpMultiplier(
  currentStreak: number,
  previousStreak: number,
): number {
  // 负数输入视为 0
  const current = Math.max(0, Math.floor(currentStreak));
  const previous = Math.max(0, Math.floor(previousStreak));

  // 断签状态
  if (current === 0) return 0.8;

  // 恢复激励：从断签中恢复
  if (previous === 0 && current === 1) return 1.3;

  // 连续推进：current >= 3，倍率递增，最高 1.5x
  if (current >= 3) {
    return 1.0 + 0.1 * Math.min(current - 2, 5);
  }

  // 默认倍率
  return 1.0;
}


export async function gatherGuideMemoryBundle(
  supabase: any,
  userId: string,
  options: GatherOptions = {},
): Promise<GuideMemoryBundle> {
  const scene = toText(options.scene) || "home";
  const userMessage = toText(options.userMessage);
  const clientContext = normalizeClientContext(options.clientContext);
  const maxRawItems = Math.max(10, options.maxRawItems ?? 60);
  const maxPackedChars = Math.max(2000, options.maxPackedChars ?? 14000);

  const now = new Date();
  const todayStartUtc = new Date(Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate(),
    0,
    0,
    0,
    0,
  ));
  const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const threeDaysAgo = new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000);

  const memoryRefs: string[] = [];

  const [
    questStateResp,
    todayQuestResp,
    dailyLogsResp,
    profileResp,
    dialogResp,
    portraitResp,
  ] = await Promise.all([
    supabase
      .from("quest_nodes")
      .select("id,title,is_deleted,is_reward,is_completed")
      .eq("user_id", userId)
      .limit(400),
    supabase
      .from("quest_nodes")
      .select(
        "id,title,description,completed_at,xp_reward,exp,is_completed,is_deleted",
      )
      .eq("user_id", userId)
      .eq("is_completed", true)
      .order("completed_at", { ascending: false })
      .limit(120),
    supabase
      .from("daily_logs")
      .select(
        "date_id,completed_count,is_perfect,encouragement,streak_day,xp_multiplier",
      )
      .eq("user_id", userId)
      .gte("date_id", dateId(sevenDaysAgo))
      .order("date_id", { ascending: false })
      .limit(20),
    supabase
      .from("profiles")
      .select(
        "id,total_xp,gold,current_streak,longest_streak,last_checkin_date",
      )
      .eq("id", userId)
      .maybeSingle(),
    supabase
      .from("guide_dialog_logs")
      .select("id,scene,role,content,created_at")
      .eq("user_id", userId)
      .gte("created_at", threeDaysAgo.toISOString())
      .order("created_at", { ascending: false })
      .limit(40),
    // 查询最近一次画像记录，用于注入对话上下文
    supabase
      .from("guide_portraits")
      .select("summary,style,model,created_at")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle(),
  ]);

  const questStateRows = Array.isArray(questStateResp.data)
    ? questStateResp.data as Array<Record<string, unknown>>
    : [];
  const taskState = {
    activeTaskIds: new Set<string>(),
    deletedTaskIds: new Set<string>(),
    deletedTaskTitleKeys: new Set<string>(),
  };
  const serverActiveTaskTitles: string[] = [];
  const serverDeletedTaskTitles: string[] = [];
  for (const row of questStateRows) {
    if (row.is_reward === true) continue;
    const id = toText(row.id);
    const title = toText(row.title);
    if (row.is_deleted === true) {
      if (id) taskState.deletedTaskIds.add(id);
      if (title) {
        taskState.deletedTaskTitleKeys.add(normalizeTaskKey(title));
        serverDeletedTaskTitles.push(title);
      }
      continue;
    }
    if (id) taskState.activeTaskIds.add(id);
    // 只把未完成的任务列为"仍在任务板上的任务"，避免 LLM 误判已完成任务为未完成
    if (title && row.is_completed !== true) serverActiveTaskTitles.push(title);
  }

  const activeTaskTitles = compactLines(
    [...(clientContext.active_task_titles ?? []), ...serverActiveTaskTitles],
    20,
  );
  const recentlyDeletedTaskTitles = compactLines(
    [
      ...(clientContext.recently_deleted_task_titles ?? []),
      ...serverDeletedTaskTitles,
    ],
    20,
  );
  for (const title of recentlyDeletedTaskTitles) {
    taskState.deletedTaskTitleKeys.add(normalizeTaskKey(title));
  }

  const todayRows = Array.isArray(todayQuestResp.data)
    ? todayQuestResp.data as Array<Record<string, unknown>>
    : [];
  const todayCompletedRows = todayRows
    .filter((row) => row.is_deleted !== true)
    .filter((row) =>
      sameUtcDay(toText(row.completed_at) || null, todayStartUtc)
    );

  const currentTaskFactLines = buildCurrentTaskFactLines({
    clientContext,
    activeTaskTitles,
    recentlyDeletedTaskTitles,
  });

  const todayContextLines = todayCompletedRows.slice(0, 20).map((row, idx) => {
    const title = toText(row.title) || "未命名任务";
    const desc = toText(row.description);
    const xp = toNum(row.xp_reward ?? row.exp, 0);
    const completedAt = toText(row.completed_at);
    const shortTime = completedAt
      ? new Date(completedAt).toISOString().slice(11, 16)
      : "--:--";
    const suffix = desc ? `；备注：${capText(desc, 32)}` : "";
    const line = `今天 ${shortTime} 完成「${title}」(XP ${
      Math.round(xp)
    })${suffix}`;
    memoryRefs.push(`quest:${toText(row.id) || `idx:${idx}`}`);
    return line;
  });

  const logs = Array.isArray(dailyLogsResp.data)
    ? dailyLogsResp.data as Array<Record<string, unknown>>
    : [];
  const logLines = logs.slice(0, 10).map((row, idx) => {
    const d = toText(row.date_id) || "unknown-date";
    const c = Math.round(toNum(row.completed_count, 0));
    const perfect = row.is_perfect === true ? "清盘日" : "普通日";
    const streak = Math.round(toNum(row.streak_day, 0));
    // encouragement 是系统自动生成的鼓励语，不传入 LLM 上下文，避免被误认为用户原话
    const line = `${d}：完成 ${c} 项，${perfect}，连续 ${streak} 天`;
    memoryRefs.push(`daily_log:${d}:${idx}`);
    return line;
  });

  const profile = (profileResp.data && typeof profileResp.data === "object")
    ? profileResp.data as Record<string, unknown>
    : null;
  const streak = Math.round(toNum(profile?.current_streak, 0));
  const longestStreak = Math.round(toNum(profile?.longest_streak, 0));
  const totalXp = Math.round(toNum(profile?.total_xp, 0));
  const gold = Math.round(toNum(profile?.gold, 0));
  const profileSummary =
    `画像概况：总 XP ${totalXp}，金币 ${gold}，当前连续 ${streak} 天，历史最长 ${longestStreak} 天。`;

  const dialogs = Array.isArray(dialogResp.data)
    ? dialogResp.data as Array<Record<string, unknown>>
    : [];
  const dialogLines = dialogs.slice(0, 8).map((row, idx) => {
    const role = toText(row.role) || "assistant";
    const sceneLabel = toText(row.scene) || "home";
    const content = capText(toText(row.content), 60);
    memoryRefs.push(`dialog:${toText(row.id) || `idx:${idx}`}`);
    return `最近三天 ${sceneLabel}(${role})：${content}`;
  });

  const recentQuery = compactLines([
    "最近任务完成节奏",
    "近期情绪与恢复",
    scene,
    userMessage,
    activeTaskTitles.slice(0, 4).join(" "),
  ], 6).join(" ");
  const longTermQuery = compactLines([
    "长期习惯 反复提到的目标",
    "恢复状态 熬夜 身体感受",
    scene,
    userMessage,
    recentlyDeletedTaskTitles.slice(0, 4).join(" "),
  ], 6).join(" ");

  let recentMemItems: GuideStructuredMemoryItem[] = [];
  let longMemItems: GuideStructuredMemoryItem[] = [];
  let agenticMemLines: string[] = [];
  try {
    const everMem = new EverMemOSClient();
    const recentMemRaw = await everMem.searchMemories({
      userId,
      query: recentQuery,
      memoryTypes: ["episodic_memory"],
      retrieveMethod: "hybrid",
      limit: 12,
    });
    const longMemRaw = await everMem.searchMemories({
      userId,
      query: longTermQuery,
      memoryTypes: ["episodic_memory"],
      retrieveMethod: "hybrid",
      limit: 8,
    });

    recentMemItems = normalizeMemoryItems(recentMemRaw)
      .map((item, idx) =>
        normalizeStructuredMemoryItem("mem_recent", item, idx)
      )
      .filter((item): item is GuideStructuredMemoryItem => item != null)
      .filter((item) => shouldKeepStructuredMemoryItem(item, taskState))
      .slice(0, 12);

    longMemItems = normalizeMemoryItems(longMemRaw)
      .map((item, idx) => normalizeStructuredMemoryItem("mem_long", item, idx))
      .filter((item): item is GuideStructuredMemoryItem => item != null)
      .filter((item) => shouldKeepStructuredMemoryItem(item, taskState))
      .slice(0, 8);

    // 方向4：跨任务记忆关联
    // 基于近期完成任务标题做 group scope 检索，把跨任务历史关联注入长期回调
    if (todayCompletedRows.length > 0 || activeTaskTitles.length > 0) {
      try {
        const crossTaskQuery = compactLines([
          ...todayCompletedRows.slice(0, 4).map((r) => toText(r.title)),
          ...activeTaskTitles.slice(0, 4),
        ], 6).join(" ");
        if (crossTaskQuery.trim()) {
          const crossTaskRaw = await everMem.searchMemories({
            userId,
            query: crossTaskQuery,
            memoryTypes: ["episodic_memory", "semantic_memory"],
            retrieveMethod: "hybrid",
            limit: 6,
          });
          const crossTaskItems = normalizeMemoryItems(crossTaskRaw)
            .map((item, idx) =>
              normalizeStructuredMemoryItem("mem_cross", item, idx)
            )
            .filter((item): item is GuideStructuredMemoryItem => item != null)
            .filter((item) => shouldKeepStructuredMemoryItem(item, taskState))
            // 过滤掉已在 recentMemItems 中出现的 ref，避免重复
            .filter((item) =>
              !recentMemItems.some((r) => r.ref === item.ref)
            )
            .slice(0, 6);
          for (const item of crossTaskItems) {
            memoryRefs.push(item.ref);
            longMemItems.push({
              ...item,
              displayText: `[跨任务关联] ${item.displayText}`,
            });
          }
        }
      } catch {
        // 跨任务检索失败不影响主流程
      }
    }
    if (scene === "agent" && userMessage) {
      try {
        const agenticRaw = await everMem.agenticSearch({
          userId,
          query: userMessage,
          limit: 8,
        });
        const agenticItems = normalizeMemoryItems(agenticRaw)
          .map((item, idx) => normalizeStructuredMemoryItem("mem_agentic", item, idx))
          .filter((item): item is GuideStructuredMemoryItem => item != null)
          .filter((item) => shouldKeepStructuredMemoryItem(item, taskState))
          .slice(0, 8);
        agenticMemLines = agenticItems.map((item) => {
          memoryRefs.push(item.ref);
          return `[agentic] ${capText(item.displayText, 100)}`;
        });
      } catch {
        // agentic 检索失败不影响主流程
      }
    }
  } catch {
    recentMemItems = [];
    longMemItems = [];
  }

  // 对检索结果应用时间衰减权重重排序，提升近期记忆优先级
  // EverMemOS 不返回显式相关性分数，按结果顺序递减赋分（排名越靠前分数越高）
  const buildPositionalScores = (
    items: GuideStructuredMemoryItem[],
  ): Map<string, number> => {
    const scores = new Map<string, number>();
    const total = items.length;
    for (let i = 0; i < total; i++) {
      // 从 1.0 线性递减到 0.5，保证所有条目都有合理的基础分数
      scores.set(items[i].ref, 1.0 - (i / Math.max(total, 1)) * 0.5);
    }
    return scores;
  };

  recentMemItems = applyDecayWeights(
    recentMemItems,
    buildPositionalScores(recentMemItems),
    maxRawItems,
  );
  longMemItems = applyDecayWeights(
    longMemItems,
    buildPositionalScores(longMemItems),
    Math.max(10, Math.floor(maxRawItems / 2)),
  );

  const recentMemLines = recentMemItems.map((item) => {
    memoryRefs.push(item.ref);
    return `近期记忆：${capText(item.displayText, 80)}`;
  });
  const longMemLines = longMemItems.map((item) => {
    memoryRefs.push(item.ref);
    return `长期回调：${capText(item.displayText, 90)}`;
  });

  const allRecent = compactLines(
    [
      ...currentTaskFactLines,
      ...todayContextLines,
      ...logLines,
      ...recentMemLines,
      // agentic 检索结果优先插入，让 agent 规划时能感知最相关历史
      ...agenticMemLines,
      profileSummary,
      ...dialogLines,
    ],
    maxRawItems,
  );
  const allLong = compactLines(
    [
      ...longMemLines,
      ...dialogLines,
      profileSummary,
    ],
    Math.max(10, Math.floor(maxRawItems / 2)),
  );

  const hasRecoveryKeyword = allRecent.join(" ").match(
    /休息|拉伸|睡眠|散步|放松|补水|恢复|冥想|relax|sleep/i,
  ) != null;
  const lateNightCount = todayCompletedRows.filter((row) => {
    const completedAt = toText(row.completed_at);
    if (!completedAt) return false;
    const hour = new Date(completedAt).getHours();
    return hour >= 22 || hour <= 2;
  }).length;
  const perfectDays = logs.filter((r) => r.is_perfect === true).length;
  const behaviorSignals = buildBehaviorSignals({
    todayCompletedCount: todayCompletedRows.length,
    lateNightCount,
    perfectDays,
    streak,
    hasRecoveryKeyword,
    longTermCount: longMemLines.length,
    dialogRecallCount: dialogLines.length,
    recentlyDeletedCount: recentlyDeletedTaskTitles.length,
    structuredMemories: [...recentMemItems, ...longMemItems],
  });

  const recentContext = allRecent.length > 0
    ? allRecent
    : ["今天尚无已完成任务记录。"];

  // 注入最近一次画像摘要，让助手对话时能引用画像生成逻辑
  const portraitRow = portraitResp?.data as Record<string, unknown> | null;
  if (portraitRow) {
    const portraitSummary = toText(portraitRow.summary);
    const portraitStyle = toText(portraitRow.style) || "pencil_sketch";
    const portraitTime = toText(portraitRow.created_at);
    if (portraitSummary) {
      recentContext.push(
        `[记忆画像] 最近一次画像(${portraitStyle})生成于${portraitTime ? new Date(portraitTime).toLocaleDateString("zh-CN") : "近期"}，画像依据：${capText(portraitSummary, 120)}`,
      );
    }
  }

  const longTermCallbacks = allLong.length > 0
    ? allLong
    : ["历史记忆样本暂时偏少，建议继续积累今日行动片段。"];
  const finalSignals = behaviorSignals.length > 0
    ? behaviorSignals
    : [fallbackSignal(recentContext)];

  if (
    !recentContext.some((line) =>
      line.includes("今天") || line.includes("当前任务板")
    )
  ) {
    recentContext.unshift("今天的行动样本暂少，可以先推进一个最小任务。");
  }
  if (
    !longTermCallbacks.some((line) =>
      line.includes("长期") || line.includes("历史")
    )
  ) {
    longTermCallbacks.unshift(
      "长期回调样本仍在积累中，后续会随着更多记录逐渐稳定。",
    );
  }

  let packedContext = buildPackedContext(
    recentContext.slice(0, 30),
    longTermCallbacks.slice(0, 20),
    finalSignals.slice(0, 10),
    maxPackedChars,
  );

  // 夜间反思场景：检索最近 7 天的历史反思记忆，注入 packed_context
  if (scene === "night_reflection") {
    try {
      const everMem = new EverMemOSClient();
      const reflections = await everMem.searchMemories({
        userId,
        query: "夜间反思",
        memoryTypes: ["episodic_memory"],
        limit: 5,
      });
      const reflectionHistory = filterReflectionHistory(
        normalizeMemoryItems(reflections),
      );
      if (reflectionHistory.length > 0) {
        packedContext += `\n\n--- 近期反思记录 ---\n${reflectionHistory.join("\n")}`;
      }
    } catch {
      // 历史反思检索失败不影响正常流程
    }
  }

  const memoryDigest = capText(
    [
      `今日完成 ${todayCompletedRows.length} 项任务，最近 7 天日志 ${logs.length} 条。`,
      `当前任务板任务数：${activeTaskTitles.length}；最近删除任务数：${recentlyDeletedTaskTitles.length}。`,
      `行为信号：${finalSignals.slice(0, 3).join("；")}`,
      `近期片段：${recentContext.slice(0, 2).join("；")}`,
      `长期片段：${longTermCallbacks.slice(0, 2).join("；")}`,
    ].join("\n"),
    1200,
  );

  const uniqueRefs = compactLines(memoryRefs, 200);
  return {
    recent_context: recentContext.slice(0, 30),
    long_term_callbacks: longTermCallbacks.slice(0, 20),
    behavior_signals: finalSignals.slice(0, 10),
    agentic_memory_lines: agenticMemLines,
    memory_refs: uniqueRefs,
    memory_digest: memoryDigest,
    packed_context: packedContext,
  };
}
