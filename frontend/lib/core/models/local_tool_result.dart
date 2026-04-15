class LocalToolResult {
  final bool success;
  final String outputText;
  final Map<String, dynamic>? resultJson;
  final String? errorText;

  const LocalToolResult({
    required this.success,
    required this.outputText,
    this.resultJson,
    this.errorText,
  });
}
