class ParsedTask {
  final String id;
  final String title;
  final DateTime? startTime;
  final int durationMinutes;
  final String priority;
  final String status;

  ParsedTask({required this.id, required this.title, this.startTime, required this.durationMinutes, required this.priority, required this.status});

  factory ParsedTask.fromJson(Map<String, dynamic> json) {
    return ParsedTask(
      id: json['id'],
      title: json['title'],
      startTime: json['start_time'] != null ? DateTime.parse(json['start_time']) : null,
      durationMinutes: json['duration_minutes'],
      priority: json['priority'],
      status: json['status'],
    );
  }
}
