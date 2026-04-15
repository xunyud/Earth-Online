class AgentRun {
  final String id;
  final String userId;
  final String goal;
  final String channel;
  final String status;
  final String? summary;
  final String? lastError;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  const AgentRun({
    required this.id,
    required this.userId,
    required this.goal,
    required this.channel,
    required this.status,
    this.summary,
    this.lastError,
    this.createdAt,
    this.updatedAt,
    this.startedAt,
    this.finishedAt,
  });

  bool get isTerminal =>
      status == 'succeeded' || status == 'failed' || status == 'cancelled';

  bool get isWaitingApproval => status == 'waiting_approval';

  bool get isWaitingLocalExecution => status == 'waiting_local_execution';

  bool get isActive => !isTerminal;

  factory AgentRun.fromJson(Map<String, dynamic> json) {
    return AgentRun(
      id: '${json['id'] ?? ''}',
      userId: '${json['user_id'] ?? ''}',
      goal: '${json['goal'] ?? ''}'.trim(),
      channel: '${json['channel'] ?? 'desktop'}'.trim(),
      status: '${json['status'] ?? 'queued'}'.trim(),
      summary: _parseOptionalText(json['summary']),
      lastError: _parseOptionalText(json['last_error']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      startedAt: _parseDateTime(json['started_at']),
      finishedAt: _parseDateTime(json['finished_at']),
    );
  }

  static String? _parseOptionalText(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return text;
  }

  static DateTime? _parseDateTime(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}
