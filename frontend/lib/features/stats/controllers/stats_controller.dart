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

  // 最近 30 天已签到的日期集合（streak_day > 0）
  Set<DateTime> _checkedInDates = {};
  Set<DateTime> get checkedInDates => _checkedInDates;

  bool get hasData =>
      _dailyStats.isNotEmpty || _xpCurve.isNotEmpty || _tierCounts.isNotEmpty;

  StatsController({required this.questController});

  // ── 新增计算属性 ──

  /// 近 30 天完美日数量
  int get perfectDayCount => _dailyStats.where((s) => s.isPerfect).length;

  /// 日均完成数（近 7 天）
  double get dailyAverage7 {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final recentWeek =
        _dailyStats.where((s) => !s.date.isBefore(weekAgo)).toList();
    if (recentWeek.isEmpty) return 0;
    final total = recentWeek.fold<int>(0, (s, d) => s + d.completedCount);
    return total / 7;
  }

  /// 近 30 天总 XP
  int get recent30DaysXp =>
      _xpCurve.isEmpty ? 0 : _xpCurve.last.cumulativeXp;

  /// 已完成任务总数（从 tier 统计求和）
  int get totalCompleted =>
      _tierCounts.fold<int>(0, (s, t) => s + t.count);

  /// 数据驱动的激励文案
  String get motivationalInsight {
    final h = _highlights;

    // 连续 7 天以上
    if (h.longestStreak >= 7) {
      return '已经连续 ${h.longestStreak} 天保持行动，这种节奏正在悄悄改变你的生活。';
    }

    // 本周完成量可观
    if (h.weeklyCompleted >= 5) {
      return '这周完成了 ${h.weeklyCompleted} 个任务，每一步都在积累力量。';
    }

    // XP 破千
    if (h.totalXp >= 1000 && h.totalXp < 1500) {
      return '经验值突破了 1000！冒险才刚刚开始。';
    }

    // 有最佳日
    if (h.bestDayCount >= 3) {
      return '最佳一天完成了 ${h.bestDayCount} 个任务。那天的你，真的很棒。';
    }

    return '每一步成长都值得被记住。继续前进吧。';
  }

  /// 里程碑列表
  List<MilestoneData> get milestones {
    final h = _highlights;
    final total = totalCompleted;
    return [
      MilestoneData(
        id: 'first_quest',
        label: '首次任务',
        icon: Icons.flag_rounded,
        isEarned: total > 0,
      ),
      MilestoneData(
        id: 'streak_7',
        label: '连续7天',
        icon: Icons.local_fire_department_rounded,
        isEarned: h.longestStreak >= 7,
      ),
      MilestoneData(
        id: 'xp_1000',
        label: 'XP破千',
        icon: Icons.star_rounded,
        isEarned: h.totalXp >= 1000,
      ),
      MilestoneData(
        id: 'level_badge',
        label: 'Lv.${h.currentLevel}',
        icon: Icons.shield_rounded,
        isEarned: true,
      ),
      if (perfectDayCount > 0)
        MilestoneData(
          id: 'perfect_day',
          label: '完美日 x$perfectDayCount',
          icon: Icons.auto_awesome_rounded,
          isEarned: true,
        ),
    ];
  }

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
      // 并行查询四组数据
      final results = await Future.wait([
        _loadDailyStats(userId),
        _loadXpCurve(userId),
        _loadTierCounts(userId),
        _loadCheckedInDates(userId),
      ]);

      _dailyStats = results[0] as List<DailyStats>;
      _xpCurve = results[1] as List<XpDayPoint>;
      _tierCounts = results[2] as List<TierCount>;
      _checkedInDates = results[3] as Set<DateTime>;

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

  /// 从 quest_nodes 统计已完成任务的类型分布（限最近 90 天避免全表扫描）
  Future<List<TierCount>> _loadTierCounts(String userId) async {
    final ninetyDaysAgo =
        DateTime.now().subtract(const Duration(days: 90));
    final res = await _supabase
        .from('quest_nodes')
        .select('quest_tier')
        .eq('user_id', userId)
        .eq('is_completed', true)
        .eq('is_deleted', false)
        .gte('completed_at', ninetyDaysAgo.toIso8601String());

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

  /// 加载最近 30 天已签到的日期（streak_day > 0）
  Future<Set<DateTime>> _loadCheckedInDates(String userId) async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final startDate =
        '${thirtyDaysAgo.year}-${_pad(thirtyDaysAgo.month)}-${_pad(thirtyDaysAgo.day)}';

    final res = await _supabase
        .from('daily_logs')
        .select('date_id, streak_day')
        .eq('user_id', userId)
        .gte('date_id', startDate)
        .gt('streak_day', 0);

    final dates = <DateTime>{};
    for (final row in res) {
      final dateStr = row['date_id'] as String;
      final parts = dateStr.split('-');
      if (parts.length != 3) continue;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        dates.add(DateTime(y, m, d));
      }
    }
    return dates;
  }

  /// 补签指定日期，返回结果消息
  Future<MakeupResult> makeupCheckin(DateTime date) async {
    final dateId = _dateIdFromDate(date);
    try {
      final result = await _supabase.rpc(
        'makeup_checkin',
        params: {'p_date_id': dateId, 'p_cost': 50},
      );
      if (result is List && result.isNotEmpty) {
        final row = result.first;
        final success = row['success'] as bool? ?? false;
        final newStreak = (row['new_streak'] as num?)?.toInt() ?? 0;
        final message = row['message'] as String? ?? '';

        if (success) {
          // 立即更新本地签到日期集合
          _checkedInDates.add(DateTime(date.year, date.month, date.day));
          notifyListeners();
          // 从 DB 重新读取 profile（金币、streak 等）
          await questController.refreshProfile();
          // 重新加载统计数据
          await loadAll();
        }
        return MakeupResult(success: success, message: message, newStreak: newStreak);
      }
      return const MakeupResult(success: false, message: '返回数据异常');
    } catch (e) {
      debugPrint('补签失败: $e');
      return MakeupResult(success: false, message: '补签失败: $e');
    }
  }

  String _dateIdFromDate(DateTime d) =>
      '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

  String _pad(int n) => n.toString().padLeft(2, '0');
}
