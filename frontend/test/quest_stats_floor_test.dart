import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/quest/controllers/quest_controller.dart';
import 'package:frontend/features/quest/models/quest_node.dart';

QuestNode buildQuest({
  required String id,
  required int xpReward,
  required bool isCompleted,
  bool isReward = false,
}) {
  return QuestNode(
    id: id,
    userId: 'user-1',
    title: id,
    questTier: 'Daily',
    isCompleted: isCompleted,
    xpReward: xpReward,
    isReward: isReward,
    createdAt: DateTime.utc(2026, 3, 14),
  );
}

void main() {
  test('completedXpFloor 会统计所有已完成任务经验', () {
    final quests = [
      buildQuest(id: 'q1', xpReward: 30, isCompleted: true, isReward: true),
      buildQuest(id: 'q2', xpReward: 20, isCompleted: true),
      buildQuest(id: 'q3', xpReward: 50, isCompleted: true),
      buildQuest(id: 'q4', xpReward: 80, isCompleted: false),
    ];

    expect(QuestController.completedXpFloor(quests), 100);
    expect(QuestController.completedGoldFloor(quests), 70);
  });

  test('reconcileStatsFloor 会把 XP 和金币提升到最低应有值', () {
    final quests = [
      buildQuest(id: 'q1', xpReward: 30, isCompleted: true, isReward: true),
      buildQuest(id: 'q2', xpReward: 20, isCompleted: true),
      buildQuest(id: 'q3', xpReward: 50, isCompleted: true),
    ];

    final reconciled = QuestController.reconcileStatsFloor(
      currentXp: 30,
      currentGold: 0,
      quests: quests,
      spentGold: 40,
    );

    expect(reconciled.totalXp, 100);
    expect(reconciled.gold, 30);
  });
}
