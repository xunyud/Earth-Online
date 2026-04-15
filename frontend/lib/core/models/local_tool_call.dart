class LocalToolCall {
  final String stepId;
  final String toolName;
  final Map<String, dynamic> arguments;

  const LocalToolCall({
    required this.stepId,
    required this.toolName,
    required this.arguments,
  });
}
