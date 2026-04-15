class AgentStep {
  final String id;
  final String runId;
  final int stepIndex;
  final String kind;
  final String? toolName;
  final Map<String, dynamic> argumentsJson;
  final String riskLevel;
  final bool needsConfirmation;
  final String status;
  final String summary;
  final String? outputText;
  final Map<String, dynamic>? resultJson;
  final String? errorText;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  const AgentStep({
    required this.id,
    required this.runId,
    required this.stepIndex,
    required this.kind,
    required this.toolName,
    required this.argumentsJson,
    required this.riskLevel,
    required this.needsConfirmation,
    required this.status,
    required this.summary,
    this.outputText,
    this.resultJson,
    this.errorText,
    this.createdAt,
    this.updatedAt,
    this.startedAt,
    this.finishedAt,
  });

  bool get isWaitingApproval => status == 'waiting_approval';
  bool get isReady => status == 'ready';
  bool get isRunning => status == 'running';
  bool get isSucceeded => status == 'succeeded';
  bool get isFailed => status == 'failed';
  bool get isTerminal => isSucceeded || isFailed || status == 'cancelled';
  bool get isToolCall => kind == 'tool_call';

  factory AgentStep.fromJson(Map<String, dynamic> json) {
    return AgentStep(
      id: '${json['id'] ?? ''}',
      runId: '${json['run_id'] ?? ''}',
      stepIndex: _parseInt(json['step_index']),
      kind: '${json['kind'] ?? 'message'}'.trim(),
      toolName: _parseOptionalText(json['tool_name']),
      argumentsJson: _parseMap(json['arguments_json']),
      riskLevel: '${json['risk_level'] ?? 'low'}'.trim(),
      needsConfirmation: json['needs_confirmation'] == true,
      status: '${json['status'] ?? 'planned'}'.trim(),
      summary: '${json['summary'] ?? ''}'.trim(),
      outputText: _parseOptionalText(json['output_text']),
      resultJson: _parseNullableMap(json['result_json']),
      errorText: _parseOptionalText(json['error_text']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      startedAt: _parseDateTime(json['started_at']),
      finishedAt: _parseDateTime(json['finished_at']),
    );
  }

  static int _parseInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
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

  static Map<String, dynamic> _parseMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return <String, dynamic>{};
  }

  static Map<String, dynamic>? _parseNullableMap(Object? value) {
    final parsed = _parseMap(value);
    if (parsed.isEmpty) return null;
    return parsed;
  }
}
