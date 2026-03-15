import 'package:flutter/material.dart';
import 'task_card.dart';
import '../models/task.dart';

class TimelineView extends StatelessWidget {
  final List<ParsedTask> tasks;

  const TimelineView({Key? key, required this.tasks}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        return Row(
          children: [
            // Vertical Line
            Container(
              width: 2,
              height: 80, // Approximate height
              color: Colors.grey,
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
            Expanded(child: TaskCard(task: tasks[index])),
          ],
        );
      },
    );
  }
}
