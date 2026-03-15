import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/quest/models/quest_node.dart';

void main() {
  test('QuestNode fromJson/toJson should map sort_order as double', () {
    final node = QuestNode.fromJson({
      'id': 'id1',
      'user_id': 'u1',
      'parent_id': null,
      'title': 't',
      'quest_tier': 'Main_Quest',
      'sort_order': 123,
      'completed_at': DateTime.utc(2026, 1, 1, 12).toIso8601String(),
      'is_completed': false,
      'is_expanded': true,
      'is_deleted': false,
      'xp_reward': 0,
      'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
    });

    expect(node.sortOrder, 123.0);
    expect(node.toJson()['sort_order'], 123.0);
    expect(node.completedAt, isNotNull);
    expect(node.toJson()['completed_at'], isNotNull);
  });

  test('QuestNode copyWith should allow setting parentId to null', () {
    final node = QuestNode(
      id: 'id1',
      userId: 'u1',
      parentId: 'p1',
      title: 't',
      questTier: 'Main_Quest',
      sortOrder: 1000.0,
      isCompleted: false,
      xpReward: 0,
      createdAt: DateTime.utc(2026, 1, 1),
    );

    final updated = node.copyWith(parentId: null, sortOrder: 2000.0);
    expect(updated.parentId, isNull);
    expect(updated.sortOrder, 2000.0);
  });

  test('QuestNode copyWith should allow clearing description and dueDate', () {
    final node = QuestNode(
      id: 'id1',
      userId: 'u1',
      parentId: null,
      title: 't',
      questTier: 'Main_Quest',
      sortOrder: 1000.0,
      description: 'hello',
      dueDate: DateTime.utc(2026, 1, 2),
      isCompleted: false,
      xpReward: 10,
      createdAt: DateTime.utc(2026, 1, 1),
    );

    final cleared = node.copyWith(description: null, dueDate: null);
    expect(cleared.description, isNull);
    expect(cleared.dueDate, isNull);
  });

  test('QuestNode copyWith should allow clearing completedAt', () {
    final node = QuestNode(
      id: 'id1',
      userId: 'u1',
      parentId: null,
      title: 't',
      questTier: 'Main_Quest',
      isCompleted: true,
      completedAt: DateTime.utc(2026, 1, 2),
      xpReward: 10,
      createdAt: DateTime.utc(2026, 1, 1),
    );

    final updated = node.copyWith(completedAt: null);
    expect(updated.completedAt, isNull);
  });
}
