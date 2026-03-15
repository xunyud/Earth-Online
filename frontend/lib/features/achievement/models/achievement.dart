/// 成就数据模型

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final String category; // quest / streak / xp / special
  final String conditionType;
  final int conditionValue;
  final int xpBonus;
  final int goldBonus;
  final int sortOrder;

  /// 运行时状态（由 Controller 填充）
  bool isUnlocked;
  DateTime? unlockedAt;
  int currentProgress;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.conditionType,
    required this.conditionValue,
    this.xpBonus = 0,
    this.goldBonus = 0,
    this.sortOrder = 0,
    this.isUnlocked = false,
    this.unlockedAt,
    this.currentProgress = 0,
  });

  /// 进度百分比（0.0 ~ 1.0）
  double get progressPercent =>
      conditionValue > 0
          ? (currentProgress / conditionValue).clamp(0.0, 1.0)
          : 0.0;

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      category: json['category'] as String,
      conditionType: json['condition_type'] as String,
      conditionValue: (json['condition_value'] as num).toInt(),
      xpBonus: (json['xp_bonus'] as num?)?.toInt() ?? 0,
      goldBonus: (json['gold_bonus'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
