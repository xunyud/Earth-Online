import 'system_reward_catalog.dart';

class Reward {
  final String id;
  final String title;
  final int cost;
  final String? description;
  final String category; // custom / theme / effect / cosmetic
  final String? icon;
  final String?
      effectType; // theme_unlock / xp_boost / confetti_style / streak_protect / card_border / complete_effect
  final String? effectValue;
  final bool isSystem;

  const Reward({
    required this.id,
    required this.title,
    required this.cost,
    this.description,
    this.category = 'custom',
    this.icon,
    this.effectType,
    this.effectValue,
    this.isSystem = false,
  });

  /// 是否为一次性消耗道具
  bool get isConsumable => category == 'effect';

  /// 是否为永久道具（主题/装饰）
  bool get isPermanent => category == 'theme' || category == 'cosmetic';

  factory Reward.fromJson(Map<String, dynamic> json) {
    final id = _toStringOrEmpty(json['id']);
    final title = _toStringOrEmpty(json['title']);
    final cost = _toIntOrZero(json['cost']);

    return Reward(
      id: id,
      title: title,
      cost: cost,
      description: _toNullableString(json['description']),
      category: _toNullableString(json['category']) ?? 'custom',
      icon: _toNullableString(json['icon']),
      effectType: _toNullableString(json['effect_type']),
      effectValue: _toNullableString(json['effect_value']),
      isSystem: json['is_system'] == true,
    );
  }

  static String _toStringOrEmpty(dynamic value) =>
      value == null ? '' : value.toString().trim();

  static String? _toNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int _toIntOrZero(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  SystemRewardDefinition? get systemRewardDefinition =>
      resolveSystemRewardDefinition(title);

  String localizedTitle(bool isEnglish) =>
      systemRewardDefinition?.title(isEnglish) ?? (title.isEmpty ? '' : title);

  String? localizedDescription(bool isEnglish) =>
      systemRewardDefinition?.description(isEnglish) ?? description;

  List<String> localizedLookupTitles(bool isEnglish) {
    final base = systemRewardDefinition;
    if (base == null) {
      final trimmed = title.trim();
      return trimmed.isEmpty ? const <String>[] : <String>[trimmed];
    }
    return <String>[
      base.title(isEnglish),
      base.title(false),
      base.title(true),
      ...base.aliases,
    ];
  }
}
