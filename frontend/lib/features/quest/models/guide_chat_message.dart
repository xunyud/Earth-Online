/// Guide 对话消息模型
class GuideChatMessage {
  final String role;
  final String content;
  final int memoryRefCount;

  /// 实际记忆片段 ID 列表，用于前端记忆可见性展示
  final List<String> memoryRefs;
  final String? agentStepId;

  const GuideChatMessage({
    required this.role,
    required this.content,
    this.memoryRefCount = 0,
    this.memoryRefs = const <String>[],
    this.agentStepId,
  });
}
