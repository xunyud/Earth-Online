import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// 来源过滤标签数据：(i18n key, sender 值, 图标)
const senderFilters = <(String, String, IconData?)>[
  ('memory.sender.all', 'all', null),
  ('memory.sender.user_manual', 'user-manual', Icons.edit),
  ('memory.sender.guide_assistant', 'guide-assistant', Icons.smart_toy),
  ('memory.sender.agent_runtime', 'agent-runtime', Icons.settings),
  ('memory.sender.patrol_nudge', 'patrol-nudge', Icons.notifications),
  if (AppConfig.wechatEnabled)
    ('memory.sender.wechat_webhook', 'wechat-webhook', Icons.chat),
];

/// 来源图标映射
const senderIcons = <String, String>{
  'user-manual': '✍️',
  'guide-assistant': '🤖',
  'agent-runtime': '⚙️',
  'patrol-nudge': '🔔',
  'wechat-webhook': '💚',
};

/// 来源 i18n key 映射
const senderLabelKeys = <String, String>{
  'user-manual': 'memory.sender.user_manual',
  'guide-assistant': 'memory.sender.guide_assistant',
  'agent-runtime': 'memory.sender.agent_runtime',
  'patrol-nudge': 'memory.sender.patrol_nudge',
  'wechat-webhook': 'memory.sender.wechat_webhook',
};

/// 来源过滤标签组件
class SenderFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const SenderFilterChip({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5A7654) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF5A7654)
                : const Color(0x335B8A58),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF5A7654).withAlpha(30),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
