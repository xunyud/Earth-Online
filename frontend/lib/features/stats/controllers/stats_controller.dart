import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../quest/controllers/quest_controller.dart';
import '../models/stats_data.dart';

/// 统计面板控制器
/// 从 daily_logs + quest_nodes 加载数据，计算图表所需的各项指标
class StatsController extends ChangeNotifier {
  final QuestController questController;
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<DailyStats> _dailyStats = [];
  List<DailyStats> get dailyStats => _dailyStats;

  List<XpDayPoint> _xpCurve = [];
  List<XpDayPoint> get xpCurve => _xpCurve;

  List<TierCount> _tierCounts = [];
  List<TierCount> get tierCounts => _tierCounts;

  HighlightData _highlights = const HighlightData();
  HighlightData get highlights => _highlights;

  bool get hasData =>
      _dailyStats.isNotEmpty || _xpCurve.isNotEmpty || _tierCounts.isNotEmpty;

  StatsController({required this.questController});

  /// 一次性加载所有统计数据
  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      // 并行查询三组数据
      final results = await Future.wait([
        _loadDailyStats(userId),
        _loadXpCurve(userId),
        _loadTierCounts(userId),
      ]);

      _dailyStats = results[0] as List<DailyStats>;
      _xpCurve = results[1] as List<XpDayPoint>;
      _tierCounts = results[2] as List<TierCount>;

      // 计算亮点数据
      _highlights = _computeHighlights();
    } catch (e) {
      debugPrint('统计数据加载失败: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 从 daily_logs 加载最近 30 天的每日完成统计
  Future<List<DailyStats>> _loadDailyStats(String userId) async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final startDate =
        '${thirtyDaysAgo.year}-${_pad(thirtyDaysAgo.month)}-${_pad(thirtyDaysAgo.day)}';

    final res = await _supabase
        .from('daily_logs')
        .select('date_id, completed_count, is_perfect')
        .eq('user_id', userId)
        .gte('date_id', startDate)
        .order('date_id', ascending: true);

    if (res.isEmpty) return [];

    return res.map((row) {
      final map = row;
      final dateStr = map['date_id'] as String;
      final parts = dateStr.split('-');
      if (parts.length != 3) return null;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y == null || m == null || d == null) return null;
      return DailyStats(
        date: DateTime(
          y,
          m,
          d,
        ),
        completedCount: (map['completed_count'] as num?)?.toInt() ?? 0,
        isPerfect: map['is_perfect'] as bool? ?? false,
      );
    }).whereType<DailyStats>().toList();
  }

  /// 从 quest_nodes 按天聚合已完成任务的 XP
  Future<List<XpDayPoint>> _loadXpCurve(String userId) async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final res = await _supabase
        .from('quest_nodes')
        .select('completed_at, xp_reward')
        .eq('user_id', userId)
        .eq('is_completed', true)
        .eq('is_deleted', false)
        .gte('completed_at', thirtyDaysAgo.toIso8601String())
        .order('completed_at', ascending: true);

    if (res.isEmpty) return [];

    // 按天聚合 XP
    final dayMap = <String, int>{};
    for (final row in res) {
      final map = row;
      final completedAt = map['completed_at'] as String?;
      if (completedAt == null) continue;
      final dt = DateTime.tryParse(completedAt);
      if (dt == null) continue;
      final dayKey = '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}';
      final xp = (map['xp_reward'] as num?)?.toInt() ?? 0;
      dayMap[dayKey] = (dayMap[dayKey] ?? 0) + xp;
    }

    // 生成连续 30 天的数据点（没有数据的天填 0）
    final points = <XpDayPoint>[];
    int cumulative = 0;
    for (int i = 30; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayKey = '${day.year}-${_pad(day.month)}-${_pad(day.day)}';
      final earned = dayMap[dayKey] ?? 0;
      cumulative += earned;
      points.add(XpDayPoint(
        date: DateTime(day.year, day.month, day.day),
        xpEarned: earned,
        cumulativeXp: cumulative,
      ));
    }

    return points;
  }

  /// 从 quest_nodes 统计已完成任务的类型分布
  Future<List<TierCount>> _loadTierCounts(String userId) async {
    final res = await _supabase
        .from('quest_nodes')
        .select('quest_tier')
        .eq('user_id', userId)
        .eq('is_completed', true)
        .eq('is_deleted', false);

    if (res.isEmpty) return [];

    final countMap = <String, int>{};
    for (final row in res) {
      final tier = row['quest_tier'] as String? ?? 'unknown';
      countMap[tier] = (countMap[tier] ?? 0) + 1;
    }

    return countMap.entries
        .map((e) => TierCount(tier: e.key, count: e.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
  }

  /// 计算亮点数据
  HighlightData _computeHighlights() {
    // 本周完成数（最近 7 天 daily_logs 的 completedCount 之和）
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    int weeklyCompleted = 0;
    int bestDayCount = 0;
    DateTime? bestDayDate;

    for (final s in _dailyStats) {
      if (!s.date.isBefore(weekAgo)) {
        weeklyCompleted += s.completedCount;
      }
      if (s.completedCount > bestDayCount) {
        bestDayCount = s.completedCount;
        bestDayDate = s.date;
      }
    }

    final lp = questController.levelProgress;

    return HighlightData(
      weeklyCompleted: weeklyCompleted,
      totalXp: questController.totalXp,
      currentLevel: lp.level,
      levelTitle: lp.title,
      longestStreak: questController.longestStreak,
      bestDayCount: bestDayCount,
      bestDayDate: bestDayDate,
    );
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
