import 'system_reward_catalog.dart';

class InventoryItem {
  final String id;
  final String rewardTitle;
  final int cost;
  final String? rewardId;
  final bool isEquipped;
  final bool isUsed;
  final String? effectType;
  final String? effectValue;

  const InventoryItem({
    required this.id,
    required this.rewardTitle,
    required this.cost,
    this.rewardId,
    this.isEquipped = false,
    this.isUsed = false,
    this.effectType,
    this.effectValue,
  });

  /// 是否为一次性消耗道具
  bool get isConsumable =>
      effectType == 'xp_boost' ||
      effectType == 'confetti_style' ||
      effectType == 'streak_protect';

  /// 是否为永久道具
  bool get isPermanent =>
      effectType == 'theme_unlock' ||
      effectType == 'card_border' ||
      effectType == 'complete_effect';

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    final rewardTitle = (json['reward_title'] as String?)?.trim() ?? '';
    final costRaw = json['cost'];
    final cost = costRaw is num ? costRaw.round() : 0;
    return InventoryItem(
      id: id,
      rewardTitle: rewardTitle,
      cost: cost,
      rewardId: json['reward_id'] as String?,
      isEquipped: json['is_equipped'] == true,
      isUsed: json['is_used'] == true,
      effectType: json['effect_type'] as String?,
      effectValue: json['effect_value'] as String?,
    );
  }

  SystemRewardDefinition? get systemRewardDefinition =>
      resolveSystemRewardDefinition(rewardTitle);

  String localizedRewardTitle(bool isEnglish) =>
      systemRewardDefinition?.title(isEnglish) ??
      (rewardTitle.isEmpty ? '' : rewardTitle);
}
