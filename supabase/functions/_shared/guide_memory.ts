import { EverMemOSClient } from "./evermemos_client.ts"

export type GuideMemoryBundle = {
  recent_context: string[]
  long_term_callbacks: string[]
  behavior_signals: string[]
  memory_refs: string[]
  memory_digest: string
  packed_context: string
}

type GatherOptions = {
  scene?: string
  userMessage?: string
  maxRawItems?: number
  maxPackedChars?: number
}

function toText(v: unknown) {
  if (typeof v === "string") return v.trim()
  if (v == null) return ""
  return String(v).trim()
}

function toNum(v: unknown, fallback = 0) {
  if (typeof v === "number" && Number.isFinite(v)) return v
  const n = Number(v)
  return Number.isFinite(n) ? n : fallback
}

function dateId(d: Date) {
  const y = d.getUTCFullYear().toString().padStart(4, "0")
  const m = (d.getUTCMonth() + 1).toString().padStart(2, "0")
  const day = d.getUTCDate().toString().padStart(2, "0")
  return `${y}-${m}-${day}`
}

function sameUtcDay(a: string | null, dayStartUtc: Date) {
  if (!a) return false
  const parsed = new Date(a)
  if (Number.isNaN(parsed.getTime())) return false
  return (
    parsed.getUTCFullYear() === dayStartUtc.getUTCFullYear() &&
    parsed.getUTCMonth() === dayStartUtc.getUTCMonth() &&
    parsed.getUTCDate() === dayStartUtc.getUTCDate()
  )
}

function normalizeMemoryItems(raw: unknown): Array<Record<string, unknown> | string> {
  if (Array.isArray(raw)) return raw as Array<Record<string, unknown> | string>
  if (!raw || typeof raw !== "object") return []
  const map = raw as Record<string, unknown>
  const candidates = [
    map.memories,
    map.results,
    map.items,
    map.data,
    (map.result as Record<string, unknown> | undefined)?.memories,
  ]
  for (const c of candidates) {
    if (Array.isArray(c)) return c as Array<Record<string, unknown> | string>
  }
  return []
}

function normalizeMemoryText(item: Record<string, unknown> | string) {
  if (typeof item === "string") return item.trim()
  const txt =
    toText(item.content) ||
    toText(item.text) ||
    toText(item.memory) ||
    toText(item.message) ||
    toText((item.data as Record<string, unknown> | undefined)?.content)
  return txt
}

function normalizeMemoryRef(prefix: string, item: Record<string, unknown> | string, idx: number) {
  if (typeof item === "string") return `${prefix}:idx:${idx}`
  const id =
    toText(item.id) ||
    toText(item.message_id) ||
    toText(item.request_id) ||
    toText((item.data as Record<string, unknown> | undefined)?.id)
  if (!id) return `${prefix}:idx:${idx}`
  return `${prefix}:${id}`
}

function compactLines(lines: string[], max = 60) {
  const seen = new Set<string>()
  const out: string[] = []
  for (const line of lines) {
    const norm = line.replace(/\s+/g, " ").trim()
    if (!norm) continue
    if (seen.has(norm)) continue
    seen.add(norm)
    out.push(norm)
    if (out.length >= max) break
  }
  return out
}

function capText(s: string, maxChars: number) {
  if (s.length <= maxChars) return s
  return `${s.slice(0, Math.max(0, maxChars - 3))}...`
}

function buildPackedContext(
  recentContext: string[],
  longTermCallbacks: string[],
  behaviorSignals: string[],
  maxChars: number,
) {
  const sections = [
    `【近期事实】\n${recentContext.map((x, i) => `${i + 1}. ${x}`).join("\n")}`,
    `【长期回溯】\n${longTermCallbacks.map((x, i) => `${i + 1}. ${x}`).join("\n")}`,
    `【行为信号】\n${behaviorSignals.map((x, i) => `${i + 1}. ${x}`).join("\n")}`,
  ]
  let packed = sections.join("\n\n")
  if (packed.length <= maxChars) return packed

  const recentTrimmed = recentContext.slice(0, Math.max(1, Math.floor(recentContext.length * 0.7)))
  const longTrimmed = longTermCallbacks.slice(0, Math.max(1, Math.floor(longTermCallbacks.length * 0.7)))
  const signalTrimmed = behaviorSignals.slice(0, Math.max(1, Math.floor(behaviorSignals.length * 0.8)))
  packed = [
    `【近期事实】\n${recentTrimmed.map((x, i) => `${i + 1}. ${x}`).join("\n")}`,
    `【长期回溯】\n${longTrimmed.map((x, i) => `${i + 1}. ${x}`).join("\n")}`,
    `【行为信号】\n${signalTrimmed.map((x, i) => `${i + 1}. ${x}`).join("\n")}`,
  ].join("\n\n")
  return capText(packed, maxChars)
}

function fallbackSignal(recentContext: string[]) {
  if (recentContext.length === 0) return "最近活动记录较少，建议先完成一个最小行动再建立节奏。"
  return "近期行动信号稳定，适合把推进与恢复节奏同时安排。"
}

function buildBehaviorSignals(opts: {
  todayCompletedCount: number
  lateNightCount: number
  perfectDays: number
  streak: number
  hasRecoveryKeyword: boolean
  longTermCount: number
  dialogRecallCount: number
}) {
  const signals: string[] = []
  if (opts.todayCompletedCount >= 5) {
    signals.push("今天完成任务密度较高，属于高强度推进日。")
  } else if (opts.todayCompletedCount >= 2) {
    signals.push("今天有连续推进动作，节奏处于可维持区间。")
  }
  if (opts.lateNightCount >= 2) {
    signals.push("近期出现夜间推进迹象，建议补充恢复性任务。")
  }
  if (opts.perfectDays >= 2) {
    signals.push("最近 7 天存在多次清盘日，执行稳定性较好。")
  }
  if (opts.streak >= 3) {
    signals.push(`当前连续打卡 ${opts.streak} 天，习惯链正在形成。`)
  }
  if (!opts.hasRecoveryKeyword && opts.todayCompletedCount > 0) {
    signals.push("恢复关键词出现偏少，可增加拉伸/补水/散步类支线。")
  }
  if (opts.longTermCount === 0) {
    signals.push("长期记忆回溯样本偏少，后续可继续积累上传记忆。")
  }
  if (opts.dialogRecallCount > 0) {
    signals.push(`近三天已有 ${opts.dialogRecallCount} 条向导对话，可用于避免重复话术。`)
  }
  return signals
}

export async function gatherGuideMemoryBundle(
  supabase: any,
  userId: string,
  options: GatherOptions = {},
): Promise<GuideMemoryBundle> {
  const scene = toText(options.scene) || "home"
  const userMessage = toText(options.userMessage)
  const maxRawItems = Math.max(10, options.maxRawItems ?? 60)
  const maxPackedChars = Math.max(2000, options.maxPackedChars ?? 14000)

  const now = new Date()
  const todayStartUtc = new Date(Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate(),
    0,
    0,
    0,
    0,
  ))
  const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)
  const threeDaysAgo = new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000)

  const memoryRefs: string[] = []

  const [
    todayQuestResp,
    dailyLogsResp,
    profileResp,
    dialogResp,
  ] = await Promise.all([
    supabase
      .from("quest_nodes")
      .select("id,title,description,completed_at,xp_reward,exp,is_completed,is_deleted")
      .eq("user_id", userId)
      .eq("is_completed", true)
      .order("completed_at", { ascending: false })
      .limit(120),
    supabase
      .from("daily_logs")
      .select("date_id,completed_count,is_perfect,encouragement,streak_day,xp_multiplier")
      .eq("user_id", userId)
      .gte("date_id", dateId(sevenDaysAgo))
      .order("date_id", { ascending: false })
      .limit(20),
    supabase
      .from("profiles")
      .select("id,total_xp,gold,current_streak,longest_streak,last_checkin_date")
      .eq("id", userId)
      .maybeSingle(),
    supabase
      .from("guide_dialog_logs")
      .select("id,scene,role,content,created_at")
      .eq("user_id", userId)
      .gte("created_at", threeDaysAgo.toISOString())
      .order("created_at", { ascending: false })
      .limit(40),
  ])

  const todayRows = Array.isArray(todayQuestResp.data) ? todayQuestResp.data as Array<Record<string, unknown>> : []
  const todayCompletedRows = todayRows
    .filter((row) => row.is_deleted !== true)
    .filter((row) => sameUtcDay(toText(row.completed_at) || null, todayStartUtc))

  const todayContextLines = todayCompletedRows.slice(0, 20).map((row, idx) => {
    const title = toText(row.title) || "未命名任务"
    const desc = toText(row.description)
    const xp = toNum(row.xp_reward ?? row.exp, 0)
    const completedAt = toText(row.completed_at)
    const shortTime = completedAt ? new Date(completedAt).toISOString().slice(11, 16) : "--:--"
    const suffix = desc ? `；备注：${capText(desc, 32)}` : ""
    const line = `今天 ${shortTime} 完成「${title}」(XP ${Math.round(xp)})${suffix}`
    memoryRefs.push(`quest:${toText(row.id) || `idx:${idx}`}`)
    return line
  })

  const logs = Array.isArray(dailyLogsResp.data) ? dailyLogsResp.data as Array<Record<string, unknown>> : []
  const logLines = logs.slice(0, 10).map((row, idx) => {
    const d = toText(row.date_id) || "unknown-date"
    const c = Math.round(toNum(row.completed_count, 0))
    const perfect = row.is_perfect === true ? "完美日" : "普通日"
    const streak = Math.round(toNum(row.streak_day, 0))
    const encouragement = toText(row.encouragement)
    const line = encouragement
      ? `${d}：完成 ${c} 项，${perfect}，连续 ${streak} 天；记录：${capText(encouragement, 38)}`
      : `${d}：完成 ${c} 项，${perfect}，连续 ${streak} 天`
    memoryRefs.push(`daily_log:${d}:${idx}`)
    return line
  })

  const profile = (profileResp.data && typeof profileResp.data === "object")
    ? profileResp.data as Record<string, unknown>
    : null
  const streak = Math.round(toNum(profile?.current_streak, 0))
  const longestStreak = Math.round(toNum(profile?.longest_streak, 0))
  const totalXp = Math.round(toNum(profile?.total_xp, 0))
  const gold = Math.round(toNum(profile?.gold, 0))
  const profileSummary = `画像概况：总 XP ${totalXp}，金币 ${gold}，当前连续 ${streak} 天，历史最长 ${longestStreak} 天。`

  const dialogs = Array.isArray(dialogResp.data) ? dialogResp.data as Array<Record<string, unknown>> : []
  const dialogLines = dialogs.slice(0, 8).map((row, idx) => {
    const role = toText(row.role) || "assistant"
    const sceneLabel = toText(row.scene) || "home"
    const content = capText(toText(row.content), 60)
    memoryRefs.push(`dialog:${toText(row.id) || `idx:${idx}`}`)
    return `近三天${sceneLabel}(${role})：${content}`
  })

  const recentQuery = compactLines([
    "最近任务完成节奏",
    "近期情绪与恢复",
    scene,
    userMessage,
  ], 4).join(" ")
  const longTermQuery = compactLines([
    "长期习惯 反复提到的目标",
    "恢复状态 熬夜 身体感受",
    scene,
    userMessage,
  ], 4).join(" ")

  let recentMemLines: string[] = []
  let longMemLines: string[] = []
  try {
    const everMem = new EverMemOSClient()
    const recentMemRaw = await everMem.searchMemories({
      userId,
      query: recentQuery,
      memoryTypes: ["episodic_memory"],
      retrieveMethod: "hybrid",
      limit: 12,
    })
    const longMemRaw = await everMem.searchMemories({
      userId,
      query: longTermQuery,
      memoryTypes: ["episodic_memory"],
      retrieveMethod: "hybrid",
      limit: 8,
    })

    recentMemLines = normalizeMemoryItems(recentMemRaw)
      .map((item, idx) => {
        const txt = normalizeMemoryText(item)
        if (!txt) return ""
        memoryRefs.push(normalizeMemoryRef("mem_recent", item, idx))
        return `近期记忆：${capText(txt, 80)}`
      })
      .filter(Boolean)
      .slice(0, 12)

    longMemLines = normalizeMemoryItems(longMemRaw)
      .map((item, idx) => {
        const txt = normalizeMemoryText(item)
        if (!txt) return ""
        memoryRefs.push(normalizeMemoryRef("mem_long", item, idx))
        return `长期回溯：${capText(txt, 90)}`
      })
      .filter(Boolean)
      .slice(0, 8)
  } catch {
    recentMemLines = []
    longMemLines = []
  }

  const allRecent = compactLines(
    [
      ...todayContextLines,
      ...logLines,
      ...recentMemLines,
      profileSummary,
      ...dialogLines,
    ],
    maxRawItems,
  )
  const allLong = compactLines(
    [
      ...longMemLines,
      ...dialogLines,
      profileSummary,
    ],
    Math.max(10, Math.floor(maxRawItems / 2)),
  )

  const hasRecoveryKeyword = allRecent.join(" ").match(/休息|拉伸|睡眠|散步|放松|补水|恢复|冥想|relax|sleep/i) != null
  const lateNightCount = todayCompletedRows.filter((row) => {
    const completedAt = toText(row.completed_at)
    if (!completedAt) return false
    const hour = new Date(completedAt).getHours()
    return hour >= 22 || hour <= 2
  }).length
  const perfectDays = logs.filter((r) => r.is_perfect === true).length
  const behaviorSignals = buildBehaviorSignals({
    todayCompletedCount: todayCompletedRows.length,
    lateNightCount,
    perfectDays,
    streak,
    hasRecoveryKeyword,
    longTermCount: longMemLines.length,
    dialogRecallCount: dialogLines.length,
  })

  const recentContext = allRecent.length > 0
    ? allRecent
    : ["今天尚无已完成任务记录。"]
  const longTermCallbacks = allLong.length > 0
    ? allLong
    : ["历史记忆暂时稀疏，建议先上传今天的行动片段。"]
  const finalSignals = behaviorSignals.length > 0
    ? behaviorSignals
    : [fallbackSignal(recentContext)]

  if (!recentContext.some((l) => l.includes("今天"))) {
    recentContext.unshift("今天的行动样本暂少，可先推进一个最小任务。")
  }
  if (!longTermCallbacks.some((l) => l.includes("长期") || l.includes("近三天") || l.includes("历史"))) {
    longTermCallbacks.unshift("长期回溯样本不足，建议持续记录以提升向导记忆准确度。")
  }

  const packedContext = buildPackedContext(
    recentContext.slice(0, 30),
    longTermCallbacks.slice(0, 20),
    finalSignals.slice(0, 10),
    maxPackedChars,
  )

  const memoryDigest = capText(
    [
      `今日完成 ${todayCompletedRows.length} 项任务，近 7 天日志 ${logs.length} 条。`,
      `行为信号：${finalSignals.slice(0, 3).join("；")}`,
      `最近记忆片段：${recentContext.slice(0, 2).join("；")}`,
      `长期回溯片段：${longTermCallbacks.slice(0, 2).join("；")}`,
    ].join("\n"),
    1200,
  )

  const uniqueRefs = compactLines(memoryRefs, 200)
  return {
    recent_context: recentContext.slice(0, 30),
    long_term_callbacks: longTermCallbacks.slice(0, 20),
    behavior_signals: finalSignals.slice(0, 10),
    memory_refs: uniqueRefs,
    memory_digest: memoryDigest,
    packed_context: packedContext,
  }
}
