class QuestNode {
  final String id;
  final String userId;
  final String? parentId;
  final String title;
  final String questTier; // 'Main_Quest', 'Side_Quest', 'Daily'
  final double sortOrder;
  final String? description;
  final DateTime? dueDate;
  final int? dailyDueMinutes;
  final bool isCompleted;
  final DateTime? completedAt;
  final bool isExpanded;
  final bool isDeleted;
  final int xpReward;
  final bool isReward;
  final DateTime createdAt;
  List<QuestNode> children = []; // For tree structure
  static const Object _parentIdUnset = Object();
  static const Object _descriptionUnset = Object();
  static const Object _dueDateUnset = Object();
  static const Object _dailyDueMinutesUnset = Object();
  static const Object _completedAtUnset = Object();
  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  QuestNode({
    required this.id,
    required this.userId,
    this.parentId,
    required this.title,
    required this.questTier,
    this.sortOrder = 0.0,
    this.description,
    this.dueDate,
    this.dailyDueMinutes,
    required this.isCompleted,
    this.completedAt,
    this.isExpanded = true,
    this.isDeleted = false,
    required this.xpReward,
    this.isReward = false,
    required this.createdAt,
    this.children = const [],
  });

  factory QuestNode.fromJson(Map<String, dynamic> json) {
    final xpRaw = json['xp_reward'] ?? json['exp'];
    final xp = xpRaw is num ? xpRaw.round() : int.tryParse('$xpRaw') ?? 0;
    return QuestNode(
      id: json['id'],
      userId: json['user_id'],
      parentId: json['parent_id'],
      title: json['title'],
      questTier: (json['quest_tier'] as String?) ?? 'Main_Quest',
      sortOrder: _toDouble(json['sort_order']),
      description: json['description'] as String?,
      dueDate: json['due_date'] == null
          ? null
          : DateTime.parse(json['due_date'] as String),
      dailyDueMinutes: _toInt(json['daily_due_minutes']),
      isCompleted: json['is_completed'] ?? false,
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      isExpanded: json['is_expanded'] ?? true,
      isDeleted: json['is_deleted'] ?? false,
      xpReward: xp,
      isReward: json['is_reward'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'parent_id': parentId,
      'title': title,
      'quest_tier': questTier,
      'sort_order': sortOrder,
      'description': description,
      'due_date': dueDate?.toUtc().toIso8601String(),
      'daily_due_minutes': dailyDueMinutes,
      'is_completed': isCompleted,
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'is_expanded': isExpanded,
      'is_deleted': isDeleted,
      'xp_reward': xpReward,
      'is_reward': isReward,
      'created_at': createdAt.toIso8601String(),
    };
  }

  QuestNode copyWith({
    String? id,
    String? userId,
    Object? parentId = _parentIdUnset,
    String? title,
    String? questTier,
    double? sortOrder,
    Object? description = _descriptionUnset,
    Object? dueDate = _dueDateUnset,
    Object? dailyDueMinutes = _dailyDueMinutesUnset,
    bool? isCompleted,
    Object? completedAt = _completedAtUnset,
    bool? isExpanded,
    bool? isDeleted,
    int? xpReward,
    bool? isReward,
    DateTime? createdAt,
    List<QuestNode>? children,
  }) {
    return QuestNode(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      parentId: parentId == _parentIdUnset ? this.parentId : parentId as String?,
      title: title ?? this.title,
      questTier: questTier ?? this.questTier,
      sortOrder: sortOrder ?? this.sortOrder,
      description: description == _descriptionUnset
          ? this.description
          : description as String?,
      dueDate:
          dueDate == _dueDateUnset ? this.dueDate : dueDate as DateTime?,
      dailyDueMinutes: dailyDueMinutes == _dailyDueMinutesUnset
          ? this.dailyDueMinutes
          : dailyDueMinutes as int?,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt == _completedAtUnset
          ? this.completedAt
          : completedAt as DateTime?,
      isExpanded: isExpanded ?? this.isExpanded,
      isDeleted: isDeleted ?? this.isDeleted,
      xpReward: xpReward ?? this.xpReward,
      isReward: isReward ?? this.isReward,
      createdAt: createdAt ?? this.createdAt,
      children: children ?? this.children,
    );
  }
}
