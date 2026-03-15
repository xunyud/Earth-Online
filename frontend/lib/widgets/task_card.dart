import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final ParsedTask task;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TaskCard({Key? key, required this.task, this.onTap, this.onLongPress}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text(task.title),
        subtitle: Text('${task.durationMinutes} mins - ${task.priority}'),
        onTap: onTap,
        onLongPress: onLongPress,
        trailing: Icon(
          task.status == 'done' ? Icons.check_circle : Icons.circle_outlined,
          color: task.status == 'done' ? Colors.green : Colors.grey,
        ),
      ),
    );
  }
}
