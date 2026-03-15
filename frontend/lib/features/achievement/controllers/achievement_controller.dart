import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/achievement.dart';

/// 成就系统控制器
/// 管理成就定义、解锁状态、进度值、解锁弹窗队列
class AchievementController extends ChangeNotifier {
  final SupabaseClient _supabase;
  bool _isDisposed = false;

  List<Achievement> _achievements = [];
  final Set<String> _unlockedIds = {};
  bool _isLoading = false;

  /// 待展示的解锁弹窗队列
  final List<Achievement> _unlockQueue = [];

  /// 解锁弹窗触发序列号（UI 监听此值变化来触发弹窗）
  int _unlockSeq = 0;

  List<Achievement> get achievements => _achievements;
  bool get isLoading => _isLoading;
  int get unlockSeq => _unlockSeq;
  bool get hasUnlockToShow => _unlockQueue.isNotEmpty;

  /// 按类别筛选
  List<Achievement> achievementsByCategory(String cat) =>
      _achievements.where((a) => a.category == cat).toList();

  AchievementController({required SupabaseClient supabase})
      : _supabase = supabase;

  /// 弹窗组件消费队列中下一个成就（返回 null 则队列已空）
  Achievement? consumeNextUnlock() {
    if (_unlockQueue.isEmpty) return null;
    return _unlockQueue.removeAt(0);
  }

  /// 加载全部成就定义 + 用户解锁记录 + 进度值
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
      // 并行查询成就定义和解锁记录
      final results = await Future.wait([
        _supabase
            .from('achievements')
            .select()
            .order('sort_order', ascending: true),
        _supabase
            .from('user_achievements')
            .select('achievement_id, unlocked_at')
            .eq('user_id', userId),
      ]);

      final allDefs = results[0] as List;
      final unlocked = results[1] as List;

      // 构建解锁 map
      final unlockedMap = <String, DateTime>{};
      _unlockedIds.clear();
      for (final row in unlocked) {
        final aid = row['achievement_id'] as String;
        _unlockedIds.add(aid);
        final at = row['unlocked_at'] as String?;
        if (at != null) {
          unlockedMap[aid] = DateTime.tryParse(at) ?? DateTime.now();
        }
      }

      // 加载进度值
      final progress = await _loadProgress(userId);

      // 合并
      _achievements = allDefs.map((json) {
        final a = Achievement.fromJson(json);
        a.isUnlocked = _unlockedIds.contains(a.id);
        a.unlockedAt = unlockedMap[a.id];
        a.currentProgress = progress[a.conditionType] ?? 0;
        return a;
      }).toList();
    } catch (e) {
      debugPrint('成就数据加载失败: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 核心方法：检查并解锁某类别的成就
  /// 调用服务端 RPC，返回新解锁的成就列表
  Future<List<Achievement>> checkAchievements(String category) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final res = await _supabase.rpc(
        'check_and_unlock_achievements',
        params: {'p_user_id': userId, 'p_category': category},
      );

      if (res is! List || res.isEmpty) return [];

      final newUnlocks = <Achievement>[];
      for (final row in res) {
        final aid = (row['out_achievement_id'] ?? row['achievement_id']) as String;
        if (_unlockedIds.contains(aid)) continue; // 已知已解锁，跳过

        _unlockedIds.add(aid);

        // 更新本地成就状态
        final local = _achievements.where((a) => a.id == aid).firstOrNull;
        if (local != null) {
          local.isUnlocked = true;
          local.unlockedAt = DateTime.now();
          local.currentProgress = local.conditionValue;
        }

        // 构建弹窗数据
        newUnlocks.add(Achievement(
          id: aid,
          title: (row['out_title'] ?? row['title']) as String? ?? '',
          description: '',
          icon: (row['out_icon'] ?? row['icon']) as String? ?? '🏆',
          category: category,
          conditionType: '',
          conditionValue: 0,
          xpBonus: ((row['out_xp_bonus'] ?? row['xp_bonus']) as num?)?.toInt() ?? 0,
          goldBonus: ((row['out_gold_bonus'] ?? row['gold_bonus']) as num?)?.toInt() ?? 0,
          isUnlocked: true,
        ));
      }

      if (newUnlocks.isNotEmpty) {
        _unlockQueue.addAll(newUnlocks);
        _unlockSeq++;
        notifyListeners();
      }

      return newUnlocks;
    } catch (e) {
      debugPrint('成就检查失败 ($category): $e');
      return [];
    }
  }

  /// 加载各 conditionType 的当前进度值
  Future<Map<String, int>> _loadProgress(String userId) async {
    final result = <String, int>{};

    try {
      // total_completed：累计完成任务数（含已删除的，防止进度倒退）
      final countRes = await _supabase
          .from('quest_nodes')
          .select('id')
          .eq('user_id', userId)
          .eq('is_completed', true);
      result['total_completed'] = (countRes as List).length;

      // 从 profiles 读取 streak / total_xp / first_wechat
      final profileRes = await _supabase
          .from('profiles')
          .select('current_streak, total_xp, last_wechat_interaction')
          .eq('id', userId)
          .maybeSingle();

      if (profileRes != null) {
        result['streak'] = (profileRes['current_streak'] as num?)?.toInt() ?? 0;
        final totalXp = (profileRes['total_xp'] as num?)?.toInt() ?? 0;
        result['total_xp'] = totalXp;
        result['first_wechat'] =
            profileRes['last_wechat_interaction'] == null ? 0 : 1;

        // 计算等级（复制 LevelEngine 逻辑）
        int level = 1;
        int remainder = totalXp;
        int cap = 500;
        while (remainder >= cap) {
          remainder -= cap;
          level++;
          cap = (cap * 1.2).ceil();
        }
        result['level'] = level;
      }

      final activeUncompletedRes = await _supabase
          .from('quest_nodes')
          .select('id')
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .eq('is_completed', false);
      final activeUncompleted = (activeUncompletedRes as List).length;
      result['board_clear'] =
          (result['total_completed'] ?? 0) > 0 && activeUncompleted == 0 ? 1 : 0;
    } catch (e) {
      debugPrint('加载成就进度失败: $e');
    }

    return result;
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
