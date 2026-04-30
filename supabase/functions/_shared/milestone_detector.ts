// 里程碑检测模块 — 根据用户行为上下文识别里程碑事件
// 检测三种里程碑：连续7天打卡、首次清盘、从断签中恢复。
// 纯函数实现，不依赖外部服务，便于测试。

import type { MilestoneType } from "./collective_memory.ts";

// ---------- 类型 ----------

/** 里程碑检测所需的用户行为上下文 */
export type MilestoneDetectionContext = {
  /** 用户 ID（仅用于日志，不写入群体记忆） */
  userId: string;
  /** 当前连续打卡天数 */
  currentStreak: number;
  /** 上一次记录的连续打卡天数（变更前的值） */
  previousStreak: number;
  /** 今天已完成的任务数 */
  todayCompletedCount: number;
  /** 当前活跃任务总数 */
  totalActiveTaskCount: number;
  /** 是否为用户历史上首次清盘 */
  isFirstClear: boolean;
};

// ---------- 核心函数 ----------

/**
 * 根据用户行为上下文检测已达成的里程碑事件。
 * 返回检测到的里程碑类型数组，可能为空（无里程碑）或包含多个（同时达成）。
 *
 * 检测规则：
 * - streak_7day：currentStreak=7 且 previousStreak=6（连续打卡从6天升至7天）
 * - first_clear：todayCompletedCount >= totalActiveTaskCount > 0 且 isFirstClear=true
 * - recovery_from_break：previousStreak=0 且 todayCompletedCount > 0 且 currentStreak=1
 */
export function detectMilestones(ctx: MilestoneDetectionContext): MilestoneType[] {
  const milestones: MilestoneType[] = [];

  // 连续 7 天打卡：streak 从 6 变为 7
  if (ctx.currentStreak === 7 && ctx.previousStreak === 6) {
    milestones.push("streak_7day");
  }

  // 首次清盘：今天完成所有活跃任务且历史首次
  if (
    ctx.todayCompletedCount > 0 &&
    ctx.todayCompletedCount >= ctx.totalActiveTaskCount &&
    ctx.totalActiveTaskCount > 0 &&
    ctx.isFirstClear
  ) {
    milestones.push("first_clear");
  }

  // 从断签中恢复：之前 streak 为 0，今天完成了任务，当前 streak 为 1
  if (
    ctx.previousStreak === 0 &&
    ctx.todayCompletedCount > 0 &&
    ctx.currentStreak === 1
  ) {
    milestones.push("recovery_from_break");
  }

  return milestones;
}
