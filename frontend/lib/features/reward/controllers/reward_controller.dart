import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../quest/controllers/quest_controller.dart';
import '../models/reward.dart';
import '../models/inventory_item.dart';
import '../models/system_reward_catalog.dart';

class RewardController extends ChangeNotifier {
  static final List<Map<String, Object>> _dailySystemRewardSeeds =
      buildSystemRewardSeedPayloads();

  final SupabaseClient _supabase;
  final QuestController _questController;

  RewardController({SupabaseClient? supabase, required QuestController quest})
      : _supabase = supabase ?? Supabase.instance.client,
        _questController = quest;

  // 用户自定义奖励
  List<Reward> _customRewards = [];
  // 系统预设商品
  List<Reward> _systemRewards = [];
  bool _loading = false;
  final Map<String, bool> _redeeming = {};
  final Map<String, bool> _deleting = {};
  List<InventoryItem> _inventory = [];
  bool _inventoryLoading = false;
  final Map<String, bool> _using = {};

  // 已拥有的系统商品 reward_id 集合（用于判断是否已购买永久道具）
  Set<String> _ownedRewardIds = {};

  List<Reward> get customRewards => _customRewards;
  List<Reward> get systemRewards => _systemRewards;
  bool get isLoading => _loading;
  bool isRedeeming(String rewardId) => _redeeming[rewardId] == true;
  bool isDeleting(String rewardId) => _deleting[rewardId] == true;
  List<InventoryItem> get inventory => _inventory;
  bool get isInventoryLoading => _inventoryLoading;
  bool isUsing(String itemId) => _using[itemId] == true;

  /// 向后兼容：返回用户自定义奖励
  List<Reward> get rewards => _customRewards;

  /// 按分类分组的系统商品
  List<Reward> get themeRewards =>
      _systemRewards.where((r) => r.category == 'theme').toList();
  List<Reward> get effectRewards =>
      _systemRewards.where((r) => r.category == 'effect').toList();
  List<Reward> get cosmeticRewards =>
      _systemRewards.where((r) => r.category == 'cosmetic').toList();

  /// 检查永久道具是否已拥有
  bool isOwned(String rewardId) => _ownedRewardIds.contains(rewardId);

  /// 背包中可使用的道具（未使用的一次性）
  List<InventoryItem> get usableItems =>
      _inventory.where((i) => !i.isUsed && i.isConsumable).toList();

  /// 背包中已装备的永久道具
  List<InventoryItem> get equippedItems =>
      _inventory.where((i) => i.isPermanent && i.isEquipped).toList();

  /// 背包中未装备的永久道具
  List<InventoryItem> get unequippedItems =>
      _inventory.where((i) => i.isPermanent && !i.isEquipped).toList();

  /// 背包中未使用的自定义奖励（非系统道具）
  List<InventoryItem> get customItems =>
      _inventory.where((i) => !i.isUsed && i.effectType == null).toList();

  static bool isDeprecatedSystemReward(Reward reward) {
    if (!reward.isSystem) return false;
    final title = reward.title.trim();
    final effectValue = (reward.effectValue ?? '').trim().toLowerCase();
    return title == '深海主题' ||
        title == '樱花主题' ||
        title == '熔岩主题' ||
        effectValue == 'ocean_deep' ||
        effectValue == 'sakura' ||
        effectValue == 'lava';
  }

  static bool isSupportedSystemReward(Reward reward) {
    if (!reward.isSystem) return true;
    return systemRewardBaseTitles.contains(reward.title.trim());
  }

  static bool _isDailySystemShopReward(Reward reward) {
    return systemRewardBaseTitles.contains(reward.title.trim()) &&
        reward.effectType == null;
  }

  Future<List<Reward>> _fetchRewards(String userId) async {
    final res = await _supabase
        .from('rewards')
        .select()
        .eq('is_active', true)
        .or('user_id.eq.$userId,is_system.eq.true,user_id.is.null');

    return (res as List)
        .whereType<Map>()
        .map((e) => Reward.fromJson(e.cast<String, dynamic>()))
        .where((r) => r.id.isNotEmpty && r.title.isNotEmpty)
        .where((r) => !isDeprecatedSystemReward(r))
        .where(isSupportedSystemReward)
        .toList();
  }

  Future<bool> _ensureDailySystemRewardsFallback(
    String userId,
    List<Reward> rewards,
  ) async {
    final existingTitles = rewards.map((reward) => reward.title.trim()).toSet();
    final missingPayloads = _dailySystemRewardSeeds
        .where((seed) => !existingTitles.contains(seed['title'] as String))
        .map(
          (seed) => <String, dynamic>{
            'user_id': userId,
            'title': seed['title'],
            'description': seed['description'],
            'cost': seed['cost'],
            'category': 'custom',
            'icon': seed['icon'],
            'is_system': false,
            'is_active': true,
          },
        )
        .toList();

    if (missingPayloads.isEmpty) {
      return false;
    }

    try {
      await _supabase.from('rewards').insert(missingPayloads);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadRewards() async {
    _loading = true;
    notifyListeners();
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _customRewards = [];
        _systemRewards = [];
        return;
      }

      var filteredRewards = await _fetchRewards(userId);
      if (!filteredRewards.any(_isDailySystemShopReward)) {
        final inserted =
            await _ensureDailySystemRewardsFallback(userId, filteredRewards);
        if (inserted) {
          filteredRewards = await _fetchRewards(userId);
        }
      }

      _systemRewards = filteredRewards.where(_isDailySystemShopReward).toList()
        ..sort((a, b) => a.cost.compareTo(b.cost));
      _customRewards = filteredRewards
          .where((r) => !_isDailySystemShopReward(r) && !r.isSystem)
          .toList()
        ..sort((a, b) => a.cost.compareTo(b.cost));
    } catch (_) {
      _customRewards = [];
      _systemRewards = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addReward({required String title, required int cost}) async {
    final t = title.trim();
    if (t.isEmpty) {
      throw Exception('奖励名称不能为空');
    }
    if (cost <= 0) {
      throw Exception('金币必须为正整数');
    }

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('请先登录后再添加商品');
    }
    final payload = <String, dynamic>{
      'user_id': userId,
      'title': t,
      'cost': cost,
      'category': 'custom',
      'is_system': false,
      'is_active': true,
    };
    try {
      final row =
          await _supabase.from('rewards').insert(payload).select().single();
      final reward = Reward.fromJson((row as Map).cast<String, dynamic>());
      if (reward.id.isNotEmpty && reward.title.isNotEmpty) {
        _customRewards = [..._customRewards, reward]
          ..sort((a, b) => a.cost.compareTo(b.cost));
        notifyListeners();
      } else {
        await loadRewards();
      }
    } on PostgrestException catch (e) {
      throw Exception('添加失败：${e.message}');
    } catch (e) {
      throw Exception('添加失败，请稍后重试');
    }
  }

  Future<void> deleteReward(Reward reward) async {
    if (reward.id.isEmpty) return;
    if (isDeleting(reward.id)) return;
    _deleting[reward.id] = true;
    notifyListeners();
    try {
      await _supabase.from('rewards').delete().eq('id', reward.id);
      _customRewards = _customRewards.where((r) => r.id != reward.id).toList();
      notifyListeners();
    } finally {
      _deleting.remove(reward.id);
      notifyListeners();
    }
  }

  Future<bool> buyReward(Reward reward) async {
    if (reward.cost <= 0) return false;
    if (isRedeeming(reward.id)) return false;

    // 永久道具不可重复购买
    if (reward.isPermanent && isOwned(reward.id)) return false;

    _redeeming[reward.id] = true;
    notifyListeners();
    try {
      final res = await _supabase.rpc(
        'buy_reward',
        params: {'r_id': reward.id},
      );
      final ok = res == true ||
          (res is bool && res) ||
          (res is Map && (res['success'] == true || res['ok'] == true));

      if (ok) {
        _questController.applyGoldDelta(-reward.cost);
        if (reward.isPermanent) _ownedRewardIds.add(reward.id);
        await _questController.refreshInventoryCount();
        await loadInventory();
        return true;
      }
      return false;
    } finally {
      _redeeming.remove(reward.id);
      notifyListeners();
    }
  }

  Future<void> loadInventory() async {
    _inventoryLoading = true;
    notifyListeners();
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _inventory = [];
        return;
      }
      final res = await _supabase
          .from('inventory')
          .select(
              'id,reward_id,reward_title,cost,is_used,is_equipped,effect_type,effect_value')
          .eq('user_id', userId)
          .eq('is_used', false);
      final list = (res as List)
          .whereType<Map>()
          .map((e) => InventoryItem.fromJson(e.cast<String, dynamic>()))
          .where((i) => i.id.isNotEmpty && i.rewardTitle.isNotEmpty)
          .toList();
      _inventory = list;

      // 更新已拥有的永久道具集合
      _ownedRewardIds = list
          .where((i) => i.isPermanent && i.rewardId != null)
          .map((i) => i.rewardId!)
          .toSet();
    } catch (_) {
      _inventory = [];
    } finally {
      _inventoryLoading = false;
      notifyListeners();
    }
  }

  Future<void> useItem(InventoryItem item) async {
    if (item.id.isEmpty) {
      throw Exception('Invalid inventory item id');
    }
    if (isUsing(item.id)) return;
    _using[item.id] = true;
    notifyListeners();
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      await _supabase.from('inventory').update({
        'is_used': true,
        'used_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', item.id);

      // 只有自定义奖励（无 effectType）才创建战利品任务
      if (item.effectType == null) {
        final sortOrder = -DateTime.now().millisecondsSinceEpoch.toDouble();
        await _supabase.from('quest_nodes').insert({
          'user_id': _supabase.auth.currentUser!.id,
          'parent_id': null,
          'title': item.rewardTitle,
          'quest_tier': 'Main_Quest',
          'sort_order': sortOrder,
          'xp_reward': item.cost,
          'is_completed': false,
          'is_deleted': false,
          'is_expanded': true,
          'is_reward': true,
          'description': item.systemRewardDefinition?.zhDescription ??
              '放下负担，去好好享受属于你的战利品吧！',
        });
        await _questController.refreshQuests();
      }

      _inventory = _inventory.where((e) => e.id != item.id).toList();
      notifyListeners();
      await _questController.refreshInventoryCount();
    } catch (e) {
      rethrow;
    } finally {
      _using.remove(item.id);
      notifyListeners();
    }
  }

  /// 切换永久道具的装备状态
  Future<void> toggleEquip(InventoryItem item) async {
    if (item.id.isEmpty) return;
    if (isUsing(item.id)) return;
    _using[item.id] = true;
    notifyListeners();
    try {
      final newEquipped = !item.isEquipped;
      await _supabase.from('inventory').update({
        'is_equipped': newEquipped,
      }).eq('id', item.id);

      await loadInventory();
      await _questController.refreshInventoryCount();
    } finally {
      _using.remove(item.id);
      notifyListeners();
    }
  }

  /// 检查并消耗一张双倍 XP 卡，返回倍率（无卡返回 1.0）
  Future<double> consumeXpBoostIfAvailable() async {
    final boost = _inventory.firstWhere(
      (i) => !i.isUsed && i.effectType == 'xp_boost',
      orElse: () => const InventoryItem(id: '', rewardTitle: '', cost: 0),
    );
    if (boost.id.isEmpty) return 1.0;

    try {
      await _supabase.from('inventory').update({
        'is_used': true,
        'used_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', boost.id);

      _inventory = _inventory.where((e) => e.id != boost.id).toList();
      notifyListeners();
      await _questController.refreshInventoryCount();

      final mult = double.tryParse(boost.effectValue ?? '2.0') ?? 2.0;
      return mult;
    } catch (_) {
      return 1.0;
    }
  }
}
