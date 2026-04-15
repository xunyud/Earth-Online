import 'package:flutter/material.dart';

import '../../../core/constants/app_text_styles.dart';
import '../models/agent_step.dart';

class AgentStepTimeline extends StatelessWidget {
  final List<AgentStep> steps;

  const AgentStepTimeline({
    super.key,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withAlpha(188),
        border: Border.all(color: const Color(0x1F4B7D4D)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '执行轨迹',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF4F724D),
              ),
            ),
            const SizedBox(height: 12),
            ...steps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _statusColor(step).withAlpha(28),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(
                        _statusIcon(step),
                        size: 16,
                        color: _statusColor(step),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.summary.isEmpty ? '未命名步骤' : step.summary,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF243826),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _metaText(step),
                            style: AppTextStyles.caption.copyWith(
                              color: const Color(0xFF6B7D6B),
                            ),
                          ),
                          if ((step.outputText ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              step.outputText!.trim(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                height: 1.45,
                                color: const Color(0xFF4A5C4A),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _statusIcon(AgentStep step) {
    if (step.isWaitingApproval) return Icons.help_outline_rounded;
    if (step.isRunning) return Icons.sync_rounded;
    if (step.isSucceeded) return Icons.check_circle_rounded;
    if (step.isFailed) return Icons.error_outline_rounded;
    if (step.isToolCall) return Icons.smart_toy_rounded;
    return Icons.chat_bubble_outline_rounded;
  }

  static Color _statusColor(AgentStep step) {
    if (step.isWaitingApproval) return const Color(0xFFB07A12);
    if (step.isRunning) return const Color(0xFF446BCE);
    if (step.isSucceeded) return const Color(0xFF3D7A42);
    if (step.isFailed) return const Color(0xFFB84F4F);
    return const Color(0xFF5A7654);
  }

  static String _metaText(AgentStep step) {
    final tool = step.toolName?.trim() ?? '';
    final risk = step.riskLevel.trim().isEmpty ? 'low' : step.riskLevel.trim();
    final base = tool.isEmpty ? step.status : '$tool · $risk · ${step.status}';
    return base;
  }
}
