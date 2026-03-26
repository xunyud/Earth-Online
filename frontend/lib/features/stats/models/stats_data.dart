import 'package:flutter/material.dart';

class DailyStats {
  final DateTime date;
  final int completedCount;
  final bool isPerfect;

  const DailyStats({
    required this.date,
    required this.completedCount,
    this.isPerfect = false,
  });
}

class XpDayPoint {
  final DateTime date;
  final int xpEarned;
  final int cumulativeXp;

  const XpDayPoint({
    required this.date,
    required this.xpEarned,
    required this.cumulativeXp,
  });
}

class TierCount {
  final String tier;
  final int count;

  const TierCount({
    required this.tier,
    required this.count,
  });
}

class HighlightData {
  final int weeklyCompleted;
  final int totalXp;
  final int currentLevel;
  final String levelTitle;
  final int longestStreak;
  final int bestDayCount;
  final DateTime? bestDayDate;

  const HighlightData({
    this.weeklyCompleted = 0,
    this.totalXp = 0,
    this.currentLevel = 1,
    this.levelTitle = 'level.title.apprentice_villager',
    this.longestStreak = 0,
    this.bestDayCount = 0,
    this.bestDayDate,
  });
}

/// 里程碑数据
class MilestoneData {
  final String id;
  final String label;
  final IconData icon;
  final bool isEarned;

  const MilestoneData({
    required this.id,
    required this.label,
    required this.icon,
    required this.isEarned,
  });
}

/// 补签操作结果
class MakeupResult {
  final bool success;
  final String message;
  final int newStreak;

  const MakeupResult({
    this.success = false,
    this.message = '',
    this.newStreak = 0,
  });
}
