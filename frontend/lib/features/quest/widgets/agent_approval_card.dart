import 'package:flutter/material.dart';

import '../../../core/constants/app_text_styles.dart';
import '../models/agent_step.dart';

class AgentApprovalCard extends StatelessWidget {
  final AgentStep step;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const AgentApprovalCard({
    super.key,
    required this.step,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFAF0),
            Color(0xFFF8F3E3),
          ],
        ),
        border: Border.all(color: const Color(0x33B07A12)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '待确认操作',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF8A6212),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              step.summary,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF47351A),
              ),
            ),
            if ((step.toolName ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '工具：${step.toolName} · 风险：${step.riskLevel}',
                style: AppTextStyles.caption.copyWith(
                  color: const Color(0xFF7A6337),
                ),
              ),
            ],
            if (step.argumentsJson.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                step.argumentsJson.toString(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  height: 1.4,
                  color: const Color(0xFF6D5A35),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                OutlinedButton(
                  onPressed: busy ? null : onReject,
                  child: const Text('取消'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: busy ? null : onApprove,
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('确认执行'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
