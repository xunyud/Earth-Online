import 'package:flutter/material.dart';
import '../models/quest_node.dart';
import '../controllers/quest_controller.dart';
import 'quest_item.dart';

class SubQuestList extends StatelessWidget {
  final List<QuestNode> children;
  final List<QuestNode> quests;
  final ValueChanged<QuestNode> onChildCompleted;
  final QuestDetailsUpdater onUpdateDetails;

  const SubQuestList(
      {Key? key,
      required this.children,
      required this.quests,
      required this.onChildCompleted,
      required this.onUpdateDetails,
      })
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Theme isn't used currently, but kept for future styling consistency if needed
    // final theme = Theme.of(context).extension<QuestTheme>()!;
    return Container(
      margin: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(25), // 0.1 * 255 ~= 25
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withAlpha(76)), // 0.3 * 255 ~= 76
      ),
      child: Column(
        children: children.map((child) {
          return QuestItem(
            quest: child,
            quests: quests,
            onCompleted: onChildCompleted,
            onUpdateDetails: onUpdateDetails,
          );
        }).toList(),
      ),
    );
  }
}
