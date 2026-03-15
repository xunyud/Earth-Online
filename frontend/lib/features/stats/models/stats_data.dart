/// 统计面板数据模型

/// 每日任务统计
class DailyStats {
  final DateTime date;
  final int completedCount;
  final bool isPerfect; // 当天所有任务全部完成

  const DailyStats({
    required this.date,
    required this.completedCount,
    this.isPerfect = false,
  });
}

/// XP 日数据点（用于累积曲线）
class XpDayPoint {
  final DateTime date;
  final int xpEarned; // 当天获取的 XP
  final int cumulativeXp; // 截至当天的累积 XP

  const XpDayPoint({
    required this.date,
    required this.xpEarned,
    required this.cumulativeXp,
  });
}

/// 任务分类统计
class TierCount {
  final String tier; // main_quest / side_quest / daily
  final int count;

  const TierCount({
    required this.tier,
    required this.count,
  });
}

/// 亮点数据汇总
class HighlightData {
  final int weeklyCompleted; // 本周完成数
  final int totalXp; // 累计 XP
  final int currentLevel; // 当前等级
  final String levelTitle; // 等级称号
  final int longestStreak; // 最长连续签到
  final int bestDayCount; // 最高效一天的完成数
  final DateTime? bestDayDate; // 最高效那天的日期

  const HighlightData({
    this.weeklyCompleted = 0,
    this.totalXp = 0,
    this.currentLevel = 1,
    this.levelTitle = '见习村民',
    this.longestStreak = 0,
    this.bestDayCount = 0,
    this.bestDayDate,
  });
}
