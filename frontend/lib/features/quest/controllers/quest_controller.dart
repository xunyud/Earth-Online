import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../achievement/controllers/achievement_controller.dart';
import '../models/quest_node.dart';
import '../../../core/services/quest_service.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/utils/level_engine.dart';

typedef QuestDetailsUpdater = Future<void> Function(
  String id, {
  String? title,
  Object? description,
  Object? dueDate,
  int? xpReward,
});

class ProfileStatsFloor {
  final int totalXp;
  final int gold;

  const ProfileStatsFloor({
    required this.totalXp,
    required this.gold,
  });
}

class _GuideOnboardingQuestSpec {
  final int index;
  final int? parentIndex;
  final String title;
  final String description;
  final int xpReward;
  final String questTier;

  const _GuideOnboardingQuestSpec({
    required this.index,
    required this.parentIndex,
    required this.title,
    required this.description,
    required this.xpReward,
    required this.questTier,
  });
}

class QuestController extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _questChannel;
  bool _isDisposed = false;

  static const List<String> _perfectDayEncouragements = [
    '太棒了！今天的面板被你彻底清空，好好休息吧，你值得这一切！',
    '你做到了。不是靠爆发，而是靠稳定的日常。',
    '今日地球 Online：通关成功。明天也请温柔地继续。',
    '完成不是终点，是你对自己的承诺又兑现了一次。',
    '给自己一个拥抱：你把这一天过得很漂亮。',
    '厉害！把任务清空的你，已经在悄悄变强。',
    '今天就到这里吧：你已经很努力了。',
  ];

  List<QuestNode> _quests = [];
  bool _isAnalyzing = false;
  int _moveSeq = 0;
  final Map<String, int> _moveTokenByQuestId = {};
  int _totalXp = 0;
  int _gold = 0;
  int _levelUpSeq = 0;
  int _derivedLevel = 1;
  int _unusedInventoryCount = 0;
  bool _isWechatBound = false;
  bool _weeklyPushEnabled = true;
  int _confettiSeq = 0;
  int _longestStreak = 0;
  int _feedbackBannerSeq = 0;
  final AchievementController _achievementController =
      AchievementController(supabase: Supabase.instance.client);

  List<QuestNode> get quests => _quests;
  List<QuestNode> get activeQuests =>
      _quests.where((q) => !q.isDeleted).toList();
  List<QuestNode> get trashedQuests =>
      _quests.where((q) => q.isDeleted).toList();

  int get boardTotalXp => activeQuests.fold(0, (sum, q) => sum + q.xpReward);

  int get boardCompletedXp => activeQuests
      .where((q) => q.isCompleted)
      .fold(0, (sum, q) => sum + q.xpReward);

  double get boardProgress =>
      boardTotalXp > 0 ? (boardCompletedXp / boardTotalXp) : 0.0;

  bool get isBoardCleared =>
      boardTotalXp > 0 && boardCompletedXp == boardTotalXp;

  int get totalXp => _totalXp;
  int get currentGold => _gold;
  int get unusedInventoryCount => _unusedInventoryCount;
  bool get hasUnusedInventory => _unusedInventoryCount > 0;
  int get levelUpSeq => _levelUpSeq;
  LevelProgress get levelProgress => LevelEngine.fromTotalXp(_totalXp);
  bool get isWechatBound => _isWechatBound;
  bool get weeklyPushEnabled => _weeklyPushEnabled;
  int get confettiSeq => _confettiSeq;
  int get longestStreak => _longestStreak;
  AchievementController get achievementController => _achievementController;
  String? get currentUserId => _supabase.auth.currentUser?.id;

  static double multiplierForStreak(int streak) {
    if (streak < 3) return 1.0;
    if (streak < 7) return 1.5;
    if (streak < 14) return 2.0;
    if (streak < 30) return 2.5;
    return 3.0;
  }

  @visibleForTesting
  static int completedXpFloor(Iterable<QuestNode> quests) {
    return quests
        .where((q) => q.isCompleted)
        .fold<int>(0, (sum, q) => sum + q.xpReward);
  }

  @visibleForTesting
  static int completedGoldFloor(Iterable<QuestNode> quests) {
    return quests
        .where((q) => q.isCompleted && !q.isReward)
        .fold<int>(0, (sum, q) => sum + q.xpReward);
  }

  @visibleForTesting
  static ProfileStatsFloor reconcileStatsFloor({
    required int currentXp,
    required int currentGold,
    required Iterable<QuestNode> quests,
    required int spentGold,
  }) {
    final xpFloor = completedXpFloor(quests);
    final earnedGold = completedGoldFloor(quests);
    final goldFloor = (earnedGold - spentGold).clamp(0, earnedGold);
    final nextXp = currentXp < xpFloor ? xpFloor : currentXp;
    final nextGold = currentGold < goldFloor ? goldFloor : currentGold;
    return ProfileStatsFloor(totalXp: nextXp, gold: nextGold);
  }

  void applyGoldDelta(int delta) {
    if (delta == 0) return;
    final next = _gold + delta;
    _gold = next < 0 ? 0 : next;
    notifyListeners();
  }

  /// 从数据库重新读取 profile（XP、金币、streak 等），供外部调用
  Future<void> refreshProfile() => _fetchProfileProgress();

  String _dateId(DateTime localDate) {
    final y = localDate.year.toString().padLeft(4, '0');
    final m = localDate.month.toString().padLeft(2, '0');
    final d = localDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  bool _isSameLocalDay(DateTime aUtc, DateTime bLocalDay) {
    final a = aUtc.toLocal();
    return a.year == bLocalDay.year &&
        a.month == bLocalDay.month &&
        a.day == bLocalDay.day;
  }

  Future<void> _upsertDailyLogForToday({required bool justClearedBoard}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateId = _dateId(today);

    // 调用签到 RPC，更新连续天数、倍率、保护卡消耗
    try {
      final checkinResult = await _supabase.rpc(
        'checkin_and_get_multiplier',
        params: {'p_date_id': dateId},
      );
      if (checkinResult is List && checkinResult.isNotEmpty) {
        final row = checkinResult.first;
        final streak = (row['streak'] as num?)?.toInt() ?? 0;
        final isNewCheckin = row['is_new_checkin'] as bool? ?? false;
        // 始终用 RPC 返回的 streak 更新本地连续天数
        _longestStreak = streak;
        notifyListeners();
        if (isNewCheckin && streak > 0) {
          _showQuestFeedbackBanner(
            message: '今日签到成功！已连续 $streak 天',
            icon: Icons.local_fire_department_rounded,
            backgroundColor: const Color(0xFFFFF3E0),
            borderColor: const Color(0xFFFF9800),
            textColor: const Color(0xFF5D4037),
          );
        }
      }
    } catch (e) {
      debugPrint('签到 RPC 调用失败（降级处理）: $e');
    }

    final completedCountToday = activeQuests
        .where((q) =>
            q.completedAt != null && _isSameLocalDay(q.completedAt!, today))
        .length;

    bool existingPerfect = false;
    try {
      final existing = await _supabase
          .from('daily_logs')
          .select('is_perfect')
          .eq('user_id', userId)
          .eq('date_id', dateId);
      if (existing.isNotEmpty) {
        existingPerfect = existing.first['is_perfect'] == true;
      }
    } catch (_) {
      existingPerfect = false;
    }

    final shouldSetPerfect = justClearedBoard && boardTotalXp > 0;
    final isPerfect = existingPerfect || shouldSetPerfect;

    final payload = <String, dynamic>{
      'user_id': userId,
      'date_id': dateId,
      'completed_count': completedCountToday,
      'is_perfect': isPerfect,
    };

    if (shouldSetPerfect && !existingPerfect) {
      final pickIndex = DateTime.now().microsecondsSinceEpoch %
          _perfectDayEncouragements.length;
      payload['encouragement'] = _perfectDayEncouragements[pickIndex];
    }

    await _supabase
        .from('daily_logs')
        .upsert(payload, onConflict: 'user_id,date_id');

    if (shouldSetPerfect && !existingPerfect) {
      _showError(payload['encouragement'] as String);
    }
  }

  void _syncMemoryFireAndForget({
    required String userId,
    required String eventType,
    required String content,
    String? memoryKind,
    String? sourceTaskId,
    String? sourceTaskTitle,
    String? sourceStatus,
    String? summary,
    Map<String, dynamic>? extra,
  }) {
    final safeContent = content.trim();
    if (safeContent.isEmpty) return;
    final body = <String, dynamic>{
      'user_id': userId,
      'event_type': eventType,
      'content': safeContent,
      if (memoryKind != null && memoryKind.trim().isNotEmpty)
        'memory_kind': memoryKind.trim(),
      if (sourceTaskId != null && sourceTaskId.trim().isNotEmpty)
        'source_task_id': sourceTaskId.trim(),
      if (sourceTaskTitle != null && sourceTaskTitle.trim().isNotEmpty)
        'source_task_title': sourceTaskTitle.trim(),
      if (sourceStatus != null && sourceStatus.trim().isNotEmpty)
        'source_status': sourceStatus.trim(),
      if (summary != null && summary.trim().isNotEmpty)
        'summary': summary.trim(),
      if (extra != null && extra.isNotEmpty) 'extra': extra,
    };
    () async {
      try {
        await _supabase.functions.invoke(
          'sync-user-memory',
          body: body,
        );
      } catch (_) {}
    }();
  }

  void _syncQuestMemoryBatchFireAndForget({
    required String eventType,
    required Iterable<QuestNode> quests,
    required String sourceStatus,
  }) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    for (final quest in quests) {
      if (quest.isReward) continue;
      final title = quest.title.trim();
      if (title.isEmpty) continue;
      _syncMemoryFireAndForget(
        userId: userId,
        eventType: eventType,
        content: title,
        memoryKind: 'task_event',
        sourceTaskId: quest.id,
        sourceTaskTitle: title,
        sourceStatus: sourceStatus,
      );
    }
  }

  List<TimelineEntry> get timelineEntries {
    final byParent = _groupByParent(activeQuests);
    final entries = <TimelineEntry>[];

    void walkSubtree(QuestNode n, int depth) {
      final kids = byParent[n.id] ?? const <QuestNode>[];
      final hasChildren = kids.isNotEmpty;
      entries.add(
        TimelineEntry(node: n, depth: depth, hasChildren: hasChildren),
      );
      if (hasChildren && n.isExpanded) {
        for (final c in kids) {
          walkSubtree(c, depth + 1);
        }
      }
    }

    final roots = byParent[null] ?? const <QuestNode>[];
    for (final r in roots) {
      walkSubtree(r, 0);
    }

    return entries;
  }

  bool get isAnalyzing => _isAnalyzing;

  Map<String?, List<QuestNode>> _groupByParent(List<QuestNode> nodes) {
    final map = <String?, List<QuestNode>>{};
    for (final n in nodes) {
      (map[n.parentId] ??= <QuestNode>[]).add(n);
    }
    for (final entry in map.entries) {
      entry.value.sort((a, b) {
        final bySort = a.sortOrder.compareTo(b.sortOrder);
        if (bySort != 0) return bySort;
        return a.createdAt.compareTo(b.createdAt);
      });
    }
    return map;
  }

  bool _isAncestor(String ancestorId, String nodeId) {
    final start = _quests.where((q) => q.id == nodeId).toList();
    if (start.isEmpty) return false;
    var current = start.first;
    while (true) {
      final pid = current.parentId;
      if (pid == null) return false;
      if (pid == ancestorId) return true;
      final next = _quests.where((q) => q.id == pid).toList();
      if (next.isEmpty) return false;
      current = next.first;
    }
  }

  void moveQuestByDrop({
    required String questId,
    required int dropIndex,
    required int targetDepth,
  }) {
    final token = ++_moveSeq;
    _moveTokenByQuestId[questId] = token;
    final backup = List<QuestNode>.from(_quests);

    final entries = timelineEntries;
    final fromIndex = entries.indexWhere((e) => e.node.id == questId);
    if (fromIndex == -1) return;

    final nodeIndex = _quests.indexWhere((q) => q.id == questId);
    if (nodeIndex == -1) return;

    final entriesSans = entries.where((e) => e.node.id != questId).toList();
    var dropIndexSans = dropIndex;
    if (dropIndexSans > fromIndex) dropIndexSans -= 1;
    if (dropIndexSans < 0) dropIndexSans = 0;
    if (dropIndexSans > entriesSans.length) dropIndexSans = entriesSans.length;

    TimelineEntry? previous;
    if (dropIndexSans - 1 >= 0 && dropIndexSans - 1 < entriesSans.length) {
      previous = entriesSans[dropIndexSans - 1];
    }

    final maxAllowedDepth = previous != null ? previous.depth + 1 : 0;
    final effectiveDepth = targetDepth.clamp(0, maxAllowedDepth);

    String? newParentId;
    if (effectiveDepth <= 0) {
      newParentId = null;
    } else if (previous == null) {
      newParentId = null;
    } else if (effectiveDepth == previous.depth + 1) {
      newParentId = previous.node.id;
    } else if (effectiveDepth == previous.depth) {
      newParentId = previous.node.parentId;
    } else if (effectiveDepth < previous.depth) {
      for (var i = dropIndexSans - 1; i >= 0; i--) {
        final candidate = entriesSans[i];
        if (candidate.depth == effectiveDepth - 1) {
          newParentId = candidate.node.id;
          break;
        }
      }
    } else {
      newParentId = previous.node.id;
    }

    if (newParentId != null && _isAncestor(questId, newParentId)) {
      return;
    }

    TimelineEntry? aboveSibling;
    for (var i = dropIndexSans - 1; i >= 0; i--) {
      final e = entriesSans[i];
      if (e.depth < effectiveDepth) break;
      if (e.depth == effectiveDepth && e.node.parentId == newParentId) {
        aboveSibling = e;
        break;
      }
    }

    TimelineEntry? belowSibling;
    for (var i = dropIndexSans; i < entriesSans.length; i++) {
      final e = entriesSans[i];
      if (e.depth < effectiveDepth) break;
      if (e.depth == effectiveDepth && e.node.parentId == newParentId) {
        belowSibling = e;
        break;
      }
    }

    double newSortOrder;
    if (aboveSibling == null && belowSibling == null) {
      newSortOrder = 0.0;
    } else if (aboveSibling == null) {
      newSortOrder = belowSibling!.node.sortOrder - 1000.0;
    } else if (belowSibling == null) {
      newSortOrder = aboveSibling.node.sortOrder + 1000.0;
    } else {
      newSortOrder =
          (aboveSibling.node.sortOrder + belowSibling.node.sortOrder) / 2.0;
    }

    _quests[nodeIndex] = _quests[nodeIndex].copyWith(
      parentId: newParentId,
      sortOrder: newSortOrder,
    );
    notifyListeners();

    () async {
      try {
        await _supabase.from('quest_nodes').update({
          'parent_id': newParentId,
          'sort_order': newSortOrder,
        }).eq('id', questId);
      } catch (_) {
        if (_moveTokenByQuestId[questId] != token) return;
        _quests = backup;
        notifyListeners();
        _showError(_t('quest.error.save_failed'));
      }
    }();
  }

  // Initialize: Fetch data and subscribe
  Future<void> init() async {
    await _fetchQuests();
    await _fetchProfileProgress();
    await _reconcileProfileStatsFloor();
    await refreshInventoryCount();
    await _achievementController.loadAll();
    _setupRealtime();
  }

  Future<int?> _fetchSpentGoldTotal() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;
      final rows = await _supabase
          .from('inventory')
          .select('cost')
          .eq('user_id', userId) as List;
      return rows.fold<int>(0, (sum, row) {
        if (row is! Map<String, dynamic>) return sum;
        final rawCost = row['cost'];
        final cost =
            rawCost is num ? rawCost.toInt() : int.tryParse('$rawCost') ?? 0;
        return sum + cost;
      });
    } catch (e) {
      debugPrint('棣冩暉棣冩暉棣冩暉 [AI/DB Error]: $e');
      return null;
    }
  }

  Future<void> _reconcileProfileStatsFloor() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    var nextXp = _totalXp;
    var nextGold = _gold;
    final xpFloor = completedXpFloor(_quests);
    if (nextXp < xpFloor) {
      nextXp = xpFloor;
    }

    final earnedGoldFloor = completedGoldFloor(_quests);
    if (nextGold < earnedGoldFloor) {
      final spentGold = await _fetchSpentGoldTotal();
      if (spentGold != null) {
        final reconciled = reconcileStatsFloor(
          currentXp: nextXp,
          currentGold: nextGold,
          quests: _quests,
          spentGold: spentGold,
        );
        nextXp = reconciled.totalXp;
        nextGold = reconciled.gold;
      }
    }

    if (nextXp == _totalXp && nextGold == _gold) return;

    _totalXp = nextXp;
    _gold = nextGold;
    _derivedLevel = LevelEngine.fromTotalXp(_totalXp).level;
    notifyListeners();

    try {
      await _supabase.from('profiles').update({
        'total_xp': nextXp,
        'gold': nextGold,
      }).eq('id', userId);
    } catch (e) {
      debugPrint('棣冩暉棣冩暉棣冩暉 [AI/DB Error]: $e');
    }
  }

  void _scheduleProfileStatsReconcile() {
    unawaited(_reconcileProfileStatsFloor());
  }

  Future<void> refreshInventoryCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _unusedInventoryCount = 0;
        notifyListeners();
        return;
      }
      final res = await _supabase
          .from('inventory')
          .select('id')
          .eq('user_id', userId)
          .eq('is_used', false);
      _unusedInventoryCount = res.length;
      notifyListeners();
    } catch (_) {
      _unusedInventoryCount = 0;
      notifyListeners();
    }
  }

  Future<void> _fetchQuests() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        _quests = [];
        notifyListeners();
        return;
      }
      final response = await _supabase
          .from('quest_nodes')
          .select()
          .eq('user_id', userId)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true);
      _quests = (response as List).map((e) => QuestNode.fromJson(e)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching quests: $e');
    }
  }

  void _setupRealtime() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final existing = _questChannel;
    if (existing != null) {
      _supabase.removeChannel(existing);
      _questChannel = null;
    }

    _questChannel = _supabase
        .channel('public:quest_nodes:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'quest_nodes',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId),
          callback: (payload) {
            try {
              final newQuest = QuestNode.fromJson(payload.newRecord);
              if (!_quests.any((q) => q.id == newQuest.id)) {
                _quests.add(newQuest);
                notifyListeners();
                _scheduleProfileStatsReconcile();
              }
            } catch (e) {
              debugPrint('Realtime insert parse error: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'quest_nodes',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId),
          callback: (payload) {
            try {
              final updated = QuestNode.fromJson(payload.newRecord);
              final index = _quests.indexWhere((q) => q.id == updated.id);
              if (index == -1) {
                _quests.add(updated);
              } else {
                _quests[index] =
                    updated.copyWith(children: _quests[index].children);
              }
              notifyListeners();
              _scheduleProfileStatsReconcile();
            } catch (e) {
              debugPrint('Realtime update parse error: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'quest_nodes',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId),
          callback: (payload) {
            final id = payload.oldRecord['id'];
            if (id is String) {
              _quests.removeWhere((q) => q.id == id);
              notifyListeners();
              _scheduleProfileStatsReconcile();
            }
          },
        )
        .subscribe();
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    final ch = _questChannel;
    if (ch != null) {
      _supabase.removeChannel(ch);
      _questChannel = null;
    }
    _achievementController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _t(String key, {Map<String, String> params = const {}}) {
    return AppLocaleController.instance.t(key, params: params);
  }

  void showToast(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        content: Text(message),
      ),
    );
  }

  void _showCheer(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: AppColors.mintGreenDark,
            width: 1.1,
          ),
        ),
        content: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded,
                color: Colors.amber, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showXpRewardSnackBar(int xpReward, int goldDelta, int completedCount) {
    final message = (xpReward <= 0 && goldDelta <= 0)
        ? _t(
            'quest.completed.no_reward',
            params: {'count': '$completedCount'},
          )
        : goldDelta <= 0
            ? _t(
                'quest.completed.xp_only',
                params: {'xp': '$xpReward', 'count': '$completedCount'},
              )
            : _t(
                'quest.completed.xp_gold',
                params: {
                  'xp': '$xpReward',
                  'gold': '$goldDelta',
                  'count': '$completedCount',
                },
              );
    _showQuestFeedbackBanner(
      message: message,
      icon: Icons.auto_awesome_rounded,
      backgroundColor: const Color(0xFFE8F5E9),
      borderColor: const Color(0xFF4CAF50),
      textColor: const Color(0xFF2E4D2E),
    );
  }

  void _showQuestFeedbackBanner({
    required String message,
    required IconData icon,
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
  }) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    _feedbackBannerSeq += 1;
    final bannerSeq = _feedbackBannerSeq;
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        dividerColor: borderColor,
        elevation: 0,
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        leading: Icon(icon, color: textColor, size: 20),
        content: Text(
          message,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: Text(
              _t('common.close'),
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (_feedbackBannerSeq != bannerSeq) return;
      scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner();
    });
  }

  Future<void> refreshQuests() async {
    await _fetchQuests();
    await _reconcileProfileStatsFloor();
  }

  Future<QuestNode?> addGuideSuggestedTask({
    required String title,
    required String description,
    int xpReward = 20,
    String questTier = 'Daily',
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _showError(_t('quest.error.no_session'));
      return null;
    }

    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      _showError(_t('quest.error.title_required'));
      return null;
    }

    final normalizedTier = switch (questTier) {
      'Main_Quest' => 'Main_Quest',
      'Side_Quest' => 'Side_Quest',
      _ => 'Daily',
    };
    final normalizedXp = xpReward.clamp(5, 200);
    final normalizedDescription = description.trim();

    final insertPayload = <String, dynamic>{
      'user_id': userId,
      'parent_id': null,
      'title': normalizedTitle,
      'quest_tier': normalizedTier,
      'xp_reward': normalizedXp,
      'is_completed': false,
      'is_deleted': false,
      'sort_order': -DateTime.now().millisecondsSinceEpoch.toDouble(),
      if (normalizedDescription.isNotEmpty)
        'description': normalizedDescription,
    };

    try {
      final row = await _supabase
          .from('quest_nodes')
          .insert(insertPayload)
          .select()
          .single();
      final inserted = QuestNode.fromJson(row);
      final existingIndex = _quests.indexWhere((q) => q.id == inserted.id);
      if (existingIndex == -1) {
        _quests.add(inserted);
      } else {
        _quests[existingIndex] = inserted;
      }
      notifyListeners();
      return inserted;
    } catch (e) {
      debugPrint('Guide task insert failed: $e');
      _showError(_t('quest.error.guide_insert_failed'));
      return null;
    }
  }

  Future<List<QuestNode>> addGuideChildTasks({
    required QuestNode parent,
    required List<String> stepTitles,
    int xpReward = 10,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _showError(_t('quest.error.no_session'));
      return const <QuestNode>[];
    }

    final normalizedTitles = stepTitles
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(3)
        .toList();
    if (normalizedTitles.isEmpty) {
      return const <QuestNode>[];
    }

    final siblings = _quests
        .where((quest) => quest.parentId == parent.id && !quest.isDeleted)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    var nextSortOrder =
        siblings.isEmpty ? 1000.0 : siblings.last.sortOrder + 1000.0;
    final normalizedXp = xpReward.clamp(5, 80);
    final insertedQuests = <QuestNode>[];

    try {
      for (final title in normalizedTitles) {
        final row = await _supabase
            .from('quest_nodes')
            .insert({
              'user_id': userId,
              'parent_id': parent.id,
              'title': title,
              'quest_tier': 'Side_Quest',
              'xp_reward': normalizedXp,
              'is_completed': false,
              'is_deleted': false,
              'sort_order': nextSortOrder,
            })
            .select()
            .single();
        final inserted = QuestNode.fromJson(row);
        insertedQuests.add(inserted);
        _quests.add(inserted);
        nextSortOrder += 1000.0;
      }
      notifyListeners();
      return insertedQuests;
    } catch (e) {
      debugPrint('Guide child tasks insert failed: $e');
      _showError(_t('quest.error.guide_insert_failed'));
      return const <QuestNode>[];
    }
  }

  List<_GuideOnboardingQuestSpec> _buildGuideOnboardingQuestSpecs({
    required String guideName,
  }) {
    return <_GuideOnboardingQuestSpec>[
      _GuideOnboardingQuestSpec(
        index: 0,
        parentIndex: null,
        title: _t('guide.onboarding.parent.title'),
        description: _t('guide.onboarding.parent.description'),
        xpReward: 40,
        questTier: 'Main_Quest',
      ),
      _GuideOnboardingQuestSpec(
        index: 1,
        parentIndex: 0,
        title: _t('guide.onboarding.step.capture.title'),
        description: _t('guide.onboarding.step.capture.description'),
        xpReward: 20,
        questTier: 'Side_Quest',
      ),
      _GuideOnboardingQuestSpec(
        index: 2,
        parentIndex: 0,
        title: _t('guide.onboarding.step.complete.title'),
        description: _t('guide.onboarding.step.complete.description'),
        xpReward: 20,
        questTier: 'Side_Quest',
      ),
      _GuideOnboardingQuestSpec(
        index: 3,
        parentIndex: 0,
        title: _t('guide.onboarding.step.checkin.title'),
        description: _t('guide.onboarding.step.checkin.description'),
        xpReward: 20,
        questTier: 'Side_Quest',
      ),
      _GuideOnboardingQuestSpec(
        index: 4,
        parentIndex: 0,
        title: _t(
          'guide.onboarding.step.assistant.title',
          params: {'name': guideName},
        ),
        description: _t('guide.onboarding.step.assistant.description'),
        xpReward: 20,
        questTier: 'Side_Quest',
      ),
      _GuideOnboardingQuestSpec(
        index: 5,
        parentIndex: 0,
        title: _t('guide.onboarding.step.shop.title'),
        description: _t('guide.onboarding.step.shop.description'),
        xpReward: 20,
        questTier: 'Side_Quest',
      ),
    ];
  }

  Future<List<QuestNode>> addOnboardingTutorialBundle({
    required String guideName,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _showError(_t('quest.error.no_session'));
      return const <QuestNode>[];
    }

    final specs = _buildGuideOnboardingQuestSpecs(guideName: guideName);
    final createdByIndex = <int, QuestNode>{};
    final createdIds = <String>[];
    final rootSortOrder = -DateTime.now().millisecondsSinceEpoch.toDouble();

    Future<void> insertOne(_GuideOnboardingQuestSpec spec) async {
      final parentId = spec.parentIndex == null
          ? null
          : createdByIndex[spec.parentIndex!]?.id;
      final payload = <String, dynamic>{
        'user_id': userId,
        'parent_id': parentId,
        'title': spec.title.trim(),
        'description': spec.description.trim(),
        'quest_tier': spec.questTier,
        'xp_reward': spec.xpReward.clamp(5, 200),
        'is_completed': false,
        'is_deleted': false,
        'sort_order':
            parentId == null ? rootSortOrder : (spec.index * 1000).toDouble(),
      };

      final row =
          await _supabase.from('quest_nodes').insert(payload).select().single();
      final inserted = QuestNode.fromJson(row);
      createdByIndex[spec.index] = inserted;
      createdIds.add(inserted.id);
    }

    try {
      for (final spec in specs.where((item) => item.parentIndex == null)) {
        await insertOne(spec);
      }
      for (final spec in specs.where((item) => item.parentIndex != null)) {
        await insertOne(spec);
      }
    } catch (e) {
      if (createdIds.isNotEmpty) {
        try {
          await _supabase
              .from('quest_nodes')
              .delete()
              .inFilter('id', createdIds);
        } catch (_) {}
      }
      debugPrint('Guide onboarding insert failed: $e');
      _showError(_t('quest.error.guide_insert_failed'));
      return const <QuestNode>[];
    }

    final insertedQuests = createdByIndex.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final quest in insertedQuests) {
      final existingIndex = _quests.indexWhere((item) => item.id == quest.id);
      if (existingIndex == -1) {
        _quests.add(quest);
      } else {
        _quests[existingIndex] = quest;
      }
    }
    notifyListeners();
    return insertedQuests;
  }

  void _showLevelUpSnackBar(int level) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        backgroundColor: const Color(0xFFFFF8E1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFFFFB74D),
            width: 1.1,
          ),
        ),
        content: Text(
          _t('quest.level_up', params: {'level': '$level'}),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Future<void> _applyCustomStatsDelta(int deltaXp, int deltaGold) async {
    if (deltaXp == 0 && deltaGold == 0) return;
    final backupTotal = _totalXp;
    final backupGold = _gold;

    final prevDerivedLevel = _derivedLevel;
    final nextTotal = _totalXp + deltaXp;
    _totalXp = nextTotal < 0 ? 0 : nextTotal;
    final nextGold = _gold + deltaGold;
    _gold = nextGold < 0 ? 0 : nextGold;
    _derivedLevel = LevelEngine.fromTotalXp(_totalXp).level;
    notifyListeners();

    final expectedTotalXp = _totalXp;
    final expectedGold = _gold;
    var persisted = false;
    try {
      await _supabase.rpc(
        'increment_custom_stats',
        params: {'delta_xp': deltaXp, 'delta_gold': deltaGold},
      );
      persisted = true;
    } catch (e) {
      debugPrint('鈿狅笍 increment_custom_stats 澶辫触锛屽皾璇曢檷绾х洿鍐?profiles: $e');
    }

    if (!persisted) {
      try {
        final userId = _supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not logged in');
        }
        await _supabase.from('profiles').update({
          'total_xp': expectedTotalXp,
          'gold': expectedGold,
        }).eq('id', userId);
        persisted = true;
      } catch (e) {
        debugPrint('馃敟馃敟馃敟 [AI/DB Error]: $e');
      }
    }

    if (!persisted) {
      showToast(_t('quest.error.stats_update_failed'));
      _totalXp = backupTotal;
      _gold = backupGold;
      _derivedLevel = LevelEngine.fromTotalXp(_totalXp).level;
      notifyListeners();
      return;
    }

    // 閬垮厤 RPC 鎵ц鎴愬姛浣嗘湭瀹為檯钀藉簱瀵艰嚧 UI 鍥為€€銆?
    final profileSynced =
        await _ensureProfileStats(expectedTotalXp, expectedGold);
    if (!profileSynced) {
      showToast(_t('quest.error.stats_sync_failed'));
      _totalXp = backupTotal;
      _gold = backupGold;
      _derivedLevel = LevelEngine.fromTotalXp(_totalXp).level;
      notifyListeners();
      return;
    }

    if (_derivedLevel > prevDerivedLevel) {
      _levelUpSeq += 1;
      _showLevelUpSnackBar(_derivedLevel);
      notifyListeners();
    }

    await _fetchProfileProgress();
  }

  Future<bool> _ensureProfileStats(int expectedXp, int expectedGold) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;
      final rows = await _supabase
          .from('profiles')
          .select('total_xp,gold')
          .eq('id', userId);
      if (rows.isEmpty) return false;
      final row = rows.first;
      final remoteXp = (row['total_xp'] as int?) ?? 0;
      final remoteGold = (row['gold'] as int?) ?? 0;
      if (remoteXp == expectedXp && remoteGold == expectedGold) {
        return true;
      }
      await _supabase.from('profiles').update({
        'total_xp': expectedXp,
        'gold': expectedGold,
      }).eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('馃敟馃敟馃敟 [AI/DB Error]: $e');
      return false;
    }
  }

  Future<void> _fetchProfileProgress() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final rows = await _supabase
          .from('profiles')
          .select(
              'total_xp,gold,wechat_openid,weekly_push_enabled,current_streak')
          .eq('id', userId);
      if (rows.isNotEmpty) {
        final row = rows.first;
        _totalXp = (row['total_xp'] as int?) ?? _totalXp;
        _gold = (row['gold'] as int?) ?? _gold;
        _isWechatBound = row['wechat_openid'] != null;
        _weeklyPushEnabled = row['weekly_push_enabled'] as bool? ?? true;
        _longestStreak = (row['current_streak'] as int?) ?? _longestStreak;
        _derivedLevel = LevelEngine.fromTotalXp(_totalXp).level;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('馃敟馃敟馃敟 [AI/DB Error]: $e');
    }
  }

  void _showUndoSnackBar(int xpReward, int goldDelta, int count) {
    final message = xpReward <= 0 && goldDelta <= 0
        ? _t('quest.undo.no_reward', params: {'count': '$count'})
        : goldDelta <= 0
            ? _t(
                'quest.undo.xp_only',
                params: {'xp': '$xpReward', 'count': '$count'},
              )
            : _t(
                'quest.undo.xp_gold',
                params: {
                  'xp': '$xpReward',
                  'gold': '$goldDelta',
                  'count': '$count',
                },
              );
    _showQuestFeedbackBanner(
      message: message,
      icon: Icons.undo_rounded,
      backgroundColor: Colors.white,
      borderColor: const Color(0xFFD0D5DD),
      textColor: AppColors.textPrimary,
    );
  }

  static const Object _descriptionUnset = Object();
  static const Object _dueDateUnset = Object();

  Future<void> updateQuestDetails(
    String id, {
    String? title,
    Object? description = _descriptionUnset,
    Object? dueDate = _dueDateUnset,
    int? xpReward,
  }) async {
    final index = _quests.indexWhere((q) => q.id == id);
    if (index == -1) return;
    if (_quests[index].isCompleted || _quests[index].isReward) {
      final msg = _t('quest.error.quest_locked');
      showToast(msg);
      throw StateError(msg);
    }

    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (description != _descriptionUnset) {
      updates['description'] = description as String?;
    }
    if (dueDate != _dueDateUnset) {
      final d = dueDate as DateTime?;
      updates['due_date'] = d?.toUtc().toIso8601String();
    }
    if (xpReward != null) updates['xp_reward'] = xpReward;
    if (updates.isEmpty) return;

    try {
      final row = await _supabase
          .from('quest_nodes')
          .select('is_completed,is_reward')
          .eq('id', id)
          .single();
      if ((row['is_completed'] == true || row['is_reward'] == true)) {
        final msg = _t('quest.error.quest_locked');
        showToast(msg);
        throw StateError(msg);
      }
      await _supabase.from('quest_nodes').update(updates).eq('id', id);
      final old = _quests[index];
      _quests[index] = old.copyWith(
        title: title ?? old.title,
        description: description == _descriptionUnset
            ? old.description
            : description as String?,
        dueDate: dueDate == _dueDateUnset ? old.dueDate : dueDate as DateTime?,
        xpReward: xpReward ?? old.xpReward,
      );
      notifyListeners();
    } catch (_) {
      _showError(_t('quest.error.save_failed'));
      rethrow;
    }
  }

  Future<void> toggleWeeklyPush(bool enabled) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final backup = _weeklyPushEnabled;
    _weeklyPushEnabled = enabled;
    notifyListeners();
    try {
      await _supabase
          .from('profiles')
          .update({'weekly_push_enabled': enabled}).eq('id', userId);
    } catch (_) {
      _weeklyPushEnabled = backup;
      notifyListeners();
      _showError(_t('quest.error.weekly_push_save_failed'));
    }
  }

  // Optimistic UI Updates
  void toggleQuestCompletion(QuestNode quest) {
    final index = _quests.indexWhere((q) => q.id == quest.id);
    if (index == -1) return;

    final newStatus = !_quests[index].isCompleted;

    final idsToUpdate = <String>{quest.id};
    var changed = true;
    while (changed) {
      changed = false;
      for (final q in _quests) {
        if (q.parentId != null && idsToUpdate.contains(q.parentId)) {
          if (idsToUpdate.add(q.id)) {
            changed = true;
          }
        }
      }
    }

    final affected = _quests.where((q) => idsToUpdate.contains(q.id)).toList();
    final toggled = newStatus
        ? affected.where((q) => !q.isCompleted).toList()
        : affected.where((q) => q.isCompleted).toList();
    final sumXp = toggled.fold<int>(0, (sum, q) => sum + q.xpReward);
    final goldRewardXp = toggled
        .where((q) => !q.isReward)
        .fold<int>(0, (sum, q) => sum + q.xpReward);
    final deltaXp = newStatus ? sumXp : -sumXp;
    final deltaGold = newStatus ? goldRewardXp : -goldRewardXp;
    final toggledCount = toggled.length;

    final nowUtc = DateTime.now().toUtc();
    final completedAtValue = newStatus ? nowUtc : null;
    final backup = List<QuestNode>.from(_quests);

    _quests = _quests
        .map((q) => idsToUpdate.contains(q.id) &&
                ((newStatus && !q.isCompleted) || (!newStatus && q.isCompleted))
            ? q.copyWith(isCompleted: newStatus, completedAt: completedAtValue)
            : q)
        .toList();
    notifyListeners();

    if (newStatus) {
      if (toggledCount > 0) {
        _showXpRewardSnackBar(sumXp, goldRewardXp, toggledCount);
      }
    } else {
      _showUndoSnackBar(sumXp, goldRewardXp, toggledCount);
    }

    () async {
      try {
        await _supabase
            .from('quest_nodes')
            .update({
              'is_completed': newStatus,
              'completed_at': completedAtValue?.toIso8601String(),
            })
            .inFilter('id', idsToUpdate.toList())
            .eq('is_completed', !newStatus);

        if (deltaXp != 0 || deltaGold != 0) {
          await _applyCustomStatsDelta(deltaXp, deltaGold);
        }

        await _upsertDailyLogForToday(
            justClearedBoard: newStatus && isBoardCleared);
        await _reconcileProfileStatsFloor();
        final userId = _supabase.auth.currentUser?.id;
        if (newStatus && userId != null) {
          _confettiSeq += 1;
          notifyListeners();
          _achievementController.checkAchievements('special');
          _achievementController.checkAchievements('daily');
          _achievementController.checkAchievements('streak');
          _achievementController.checkAchievements('growth');
          for (final completedQuest
              in toggled.where((item) => !item.isReward)) {
            final title = completedQuest.title.trim();
            if (title.isEmpty) continue;
            _syncMemoryFireAndForget(
              userId: userId,
              eventType: 'quest_completed',
              content: title,
              memoryKind: 'task_event',
              sourceTaskId: completedQuest.id,
              sourceTaskTitle: title,
              sourceStatus: 'active',
            );
          }
        }
      } catch (e) {
        var reason = e.toString();
        if (e is PostgrestException) {
          final detailsText = e.details?.toString() ?? '';
          final hintText = e.hint?.toString() ?? '';
          final parts = <String>[
            if (e.code != null && e.code!.isNotEmpty) 'code=${e.code}',
            e.message,
            if (detailsText.isNotEmpty) 'details=$detailsText',
            if (hintText.isNotEmpty) 'hint=$hintText',
          ];
          reason = parts.join(' | ');
        }
        debugPrint('馃敟馃敟馃敟 [AI/DB Error]: $reason');
        showToast('${_t('quest.error.save_failed')}: $reason');
        _quests = backup;
        notifyListeners();
        _fetchQuests();
      }
    }();
  }

  void nestQuest(QuestNode parent, QuestNode child) {
    final index = _quests.indexWhere((q) => q.id == child.id);
    if (index != -1) {
      _quests[index] =
          child.copyWith(parentId: parent.id, questTier: parent.questTier);
      notifyListeners();
    }

    _supabase
        .from('quest_nodes')
        .update({'parent_id': parent.id, 'quest_tier': parent.questTier})
        .eq('id', child.id)
        .catchError((e) {
          _fetchQuests();
        });
  }

  void changeQuestTier(QuestNode quest, String newTier) {
    final index = _quests.indexWhere((q) => q.id == quest.id);
    if (index != -1) {
      _quests[index] = quest.copyWith(parentId: null, questTier: newTier);
      notifyListeners();
    }

    _supabase
        .from('quest_nodes')
        .update({'quest_tier': newTier, 'parent_id': null})
        .eq('id', quest.id)
        .catchError((e) {
          _fetchQuests();
        });
  }

  void reorderQuest(int oldIndex, int newIndex) {
    reorderQuestWithinParent(null, oldIndex, newIndex);
  }

  void reorderQuestWithinParent(String? parentId, int oldIndex, int newIndex) {
    final siblings = _quests.where((q) => q.parentId == parentId).toList();
    if (siblings.length < 2) return;
    if (oldIndex < 0 ||
        oldIndex >= siblings.length ||
        newIndex < 0 ||
        newIndex > siblings.length) {
      return;
    }

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final moved = siblings.removeAt(oldIndex);
    siblings.insert(newIndex, moved);

    final siblingIdSet = siblings.map((q) => q.id).toSet();
    final rebuilt = <QuestNode>[];
    var inserted = false;

    for (final q in _quests) {
      if (q.parentId == parentId && siblingIdSet.contains(q.id)) {
        if (!inserted) {
          rebuilt.addAll(siblings);
          inserted = true;
        }
      } else {
        rebuilt.add(q);
      }
    }

    if (!inserted) {
      rebuilt.addAll(siblings);
    }

    _quests = rebuilt;
    notifyListeners();
  }

  void deleteQuest(String questId) {
    final idsToDelete = <String>{questId};
    var changed = true;
    while (changed) {
      changed = false;
      for (final q in _quests) {
        if (q.parentId != null && idsToDelete.contains(q.parentId)) {
          if (idsToDelete.add(q.id)) {
            changed = true;
          }
        }
      }
    }

    final backup = <String, QuestNode>{};
    for (final q in _quests) {
      if (idsToDelete.contains(q.id)) {
        backup[q.id] = q;
      }
    }
    final deletedQuests = backup.values.toList(growable: false);

    _quests = _quests
        .map(
            (q) => idsToDelete.contains(q.id) ? q.copyWith(isDeleted: true) : q)
        .toList();
    notifyListeners();

    () async {
      try {
        await _supabase
            .from('quest_nodes')
            .update({'is_deleted': true}).inFilter('id', idsToDelete.toList());
        _syncQuestMemoryBatchFireAndForget(
          eventType: 'quest_deleted',
          quests: deletedQuests,
          sourceStatus: 'inactive',
        );
      } catch (_) {
        _quests = _quests
            .map((q) => backup.containsKey(q.id) ? backup[q.id]! : q)
            .toList();
        notifyListeners();
        _showError(_t('quest.error.save_failed'));
      }
    }();
  }

  void restoreQuest(String questId) {
    final idsToRestore = <String>{questId};
    var changed = true;
    while (changed) {
      changed = false;
      for (final q in _quests) {
        if (q.parentId != null && idsToRestore.contains(q.parentId)) {
          if (idsToRestore.add(q.id)) {
            changed = true;
          }
        }
      }
    }

    final backup = <String, QuestNode>{};
    for (final q in _quests) {
      if (idsToRestore.contains(q.id)) {
        backup[q.id] = q;
      }
    }
    final restoredQuests = backup.values.toList(growable: false);

    _quests = _quests
        .map((q) =>
            idsToRestore.contains(q.id) ? q.copyWith(isDeleted: false) : q)
        .toList();
    notifyListeners();

    () async {
      try {
        await _supabase.from('quest_nodes').update(
            {'is_deleted': false}).inFilter('id', idsToRestore.toList());
        _syncQuestMemoryBatchFireAndForget(
          eventType: 'quest_restored',
          quests: restoredQuests,
          sourceStatus: 'active',
        );
      } catch (_) {
        _quests = _quests
            .map((q) => backup.containsKey(q.id) ? backup[q.id]! : q)
            .toList();
        notifyListeners();
        _showError(_t('quest.error.save_failed'));
      }
    }();
  }

  void permanentlyDeleteQuest(String questId) {
    final idsToDelete = <String>{questId};
    var changed = true;
    while (changed) {
      changed = false;
      for (final q in _quests) {
        if (q.parentId != null && idsToDelete.contains(q.parentId)) {
          if (idsToDelete.add(q.id)) {
            changed = true;
          }
        }
      }
    }

    final deletedQuests = _quests
        .where((q) => idsToDelete.contains(q.id))
        .toList(growable: false);
    final backup = List<QuestNode>.from(_quests);
    _quests = _quests.where((q) => !idsToDelete.contains(q.id)).toList();
    notifyListeners();

    () async {
      try {
        await _supabase
            .from('quest_nodes')
            .delete()
            .inFilter('id', idsToDelete.toList());
        _syncQuestMemoryBatchFireAndForget(
          eventType: 'quest_deleted',
          quests: deletedQuests,
          sourceStatus: 'inactive',
        );
      } catch (_) {
        _quests = backup;
        notifyListeners();
        _showError(_t('quest.error.save_failed'));
      }
    }();
  }

  void toggleQuestExpanded(String questId) {
    final index = _quests.indexWhere((q) => q.id == questId);
    if (index == -1) return;
    _quests[index] =
        _quests[index].copyWith(isExpanded: !_quests[index].isExpanded);
    notifyListeners();
  }

  void toggleExpandAll() {
    final shouldExpand = activeQuests.any((q) => !q.isExpanded);
    _quests = _quests
        .map((q) => q.isDeleted ? q : q.copyWith(isExpanded: shouldExpand))
        .toList();
    notifyListeners();
  }

  void deleteAllActiveQuests() {
    final ids = activeQuests.map((q) => q.id).toList();
    if (ids.isEmpty) return;

    final backup = <String, QuestNode>{};
    for (final q in _quests) {
      if (ids.contains(q.id)) {
        backup[q.id] = q;
      }
    }
    final deletedQuests = backup.values.toList(growable: false);

    _quests = _quests
        .map((q) => q.isDeleted ? q : q.copyWith(isDeleted: true))
        .toList();
    notifyListeners();

    () async {
      try {
        await _supabase
            .from('quest_nodes')
            .update({'is_deleted': true}).eq('is_deleted', false);
        _syncQuestMemoryBatchFireAndForget(
          eventType: 'quest_deleted',
          quests: deletedQuests,
          sourceStatus: 'inactive',
        );
      } catch (_) {
        _quests = _quests
            .map((q) => backup.containsKey(q.id) ? backup[q.id]! : q)
            .toList();
        notifyListeners();
        _showError(_t('quest.error.save_failed'));
      }
    }();
  }

  void restoreAllQuests() {
    if (trashedQuests.isEmpty) return;

    final restoredQuests = List<QuestNode>.from(trashedQuests);
    final backup = List<QuestNode>.from(_quests);
    _quests = _quests.map((q) => q.copyWith(isDeleted: false)).toList();
    notifyListeners();

    () async {
      try {
        await _supabase
            .from('quest_nodes')
            .update({'is_deleted': false}).eq('is_deleted', true);
        _syncQuestMemoryBatchFireAndForget(
          eventType: 'quest_restored',
          quests: restoredQuests,
          sourceStatus: 'active',
        );
      } catch (_) {
        _quests = backup;
        notifyListeners();
        _showError(_t('quest.error.save_failed'));
      }
    }();
  }

  void emptyRecycleBin() {
    final ids = trashedQuests.map((q) => q.id).toList();
    if (ids.isEmpty) return;

    final backup = List<QuestNode>.from(_quests);
    _quests = _quests.where((q) => !q.isDeleted).toList();
    notifyListeners();

    () async {
      try {
        await _supabase.from('quest_nodes').delete().eq('is_deleted', true);
      } catch (_) {
        _quests = backup;
        notifyListeners();
        _showError(_t('quest.error.save_failed'));
      }
    }();
  }

  // Real AI Parsing
  Future<void> simulateAIParsing(String input) async {
    if (_isAnalyzing || input.trim().isEmpty) return;

    _isAnalyzing = true;
    notifyListeners();

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      ParseQuestResult parsed;
      try {
        parsed = await QuestService.parseQuest(input, userId);
      } catch (e) {
        debugPrint('馃敟馃敟馃敟 [AI/DB Error]: $e');
        showToast(e.toString());
        return;
      }

      final cheer = parsed.cheer.trim();
      if (cheer.isNotEmpty) {
        _showCheer(cheer);
      }

      final raw = parsed.quests;
      if (raw.isEmpty) return;

      final specs = <({int i, ParseQuestSpec s})>[];
      for (var i = 0; i < raw.length; i++) {
        specs.add((i: i, s: raw[i]));
      }

      final validByIndex = <int, bool>{
        for (final e in specs) e.i: e.s.title.trim().isNotEmpty,
      };

      final indexToCreated = <int, QuestNode>{};
      Future<void> insertOne({
        required int originalIndex,
        required ParseQuestSpec spec,
        required String? parentId,
      }) async {
        final insertPayload = <String, dynamic>{
          'user_id': userId,
          'parent_id': parentId,
          'title': spec.title.trim(),
          'quest_tier': parentId == null ? 'Main_Quest' : 'Side_Quest',
          'xp_reward': spec.xpReward,
          'is_completed': false,
        };

        final row = await _supabase
            .from('quest_nodes')
            .insert(insertPayload)
            .select()
            .single();
        indexToCreated[originalIndex] = QuestNode.fromJson(row);
      }

      for (final e in specs) {
        if (validByIndex[e.i] != true) continue;
        final p = e.s.parentIndex;
        final isRoot =
            p == null || p < 0 || p >= e.i || validByIndex[p] != true;
        if (!isRoot) continue;
        try {
          await insertOne(originalIndex: e.i, spec: e.s, parentId: null);
        } catch (err) {
          debugPrint('馃敟馃敟馃敟 [AI/DB Error]: $err');
          showToast(err.toString());
          return;
        }
      }

      for (final e in specs) {
        if (validByIndex[e.i] != true) continue;
        if (indexToCreated.containsKey(e.i)) continue;
        final p = e.s.parentIndex;
        final parent = p == null ? null : indexToCreated[p];
        final parentId = parent?.id;
        try {
          await insertOne(originalIndex: e.i, spec: e.s, parentId: parentId);
        } catch (err) {
          debugPrint('馃敟馃敟馃敟 [AI/DB Error]: $err');
          showToast(err.toString());
          return;
        }
      }

      final newQuests = indexToCreated.values.toList();

      final maxSortByParent = <String?, double>{};
      for (final q in _quests) {
        final current = maxSortByParent[q.parentId];
        final v = q.sortOrder;
        if (current == null || v > current) {
          maxSortByParent[q.parentId] = v;
        }
      }

      final normalizedNewQuests = <QuestNode>[];
      final toUpsert = <Map<String, dynamic>>[];
      for (final quest in newQuests) {
        if (quest.sortOrder != 0.0) {
          normalizedNewQuests.add(quest);
          continue;
        }

        final base = maxSortByParent[quest.parentId] ?? 0.0;
        final next = base + 1000.0;
        maxSortByParent[quest.parentId] = next;

        final updated = quest.copyWith(sortOrder: next);
        normalizedNewQuests.add(updated);
        toUpsert.add({
          'id': updated.id,
          'sort_order': updated.sortOrder,
        });
      }

      for (final quest in normalizedNewQuests) {
        if (!_quests.any((q) => q.id == quest.id)) {
          _quests.add(quest);
        }
      }
      notifyListeners();

      if (toUpsert.isNotEmpty) {
        try {
          for (final row in toUpsert) {
            final id = row['id'];
            final sortOrder = row['sort_order'];
            if (id is! String || id.isEmpty) continue;
            if (sortOrder is! num) continue;
            await _supabase
                .from('quest_nodes')
                .update({'sort_order': sortOrder}).eq('id', id);
          }
        } catch (e) {
          debugPrint('馃敟馃敟馃敟 [AI/DB Error]: $e');
          showToast(e.toString());
          _showError(_t('quest.error.save_failed'));
        }
      }
    } catch (e) {
      debugPrint('馃敟馃敟馃敟 [AI/DB Error]: $e');
      showToast(e.toString());
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }
}

class TimelineEntry {
  final QuestNode node;
  final int depth;
  final bool hasChildren;

  TimelineEntry({
    required this.node,
    required this.depth,
    required this.hasChildren,
  });
}
