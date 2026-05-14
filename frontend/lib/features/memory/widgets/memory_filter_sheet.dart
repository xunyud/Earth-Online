import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';

/// 筛选条件结果
class MemoryFilterResult {
  final String? dateRange; // '7d', '30d', null(全部)
  final String? kind; // memory kind, null(全部)

  const MemoryFilterResult({this.dateRange, this.kind});

  bool get isActive => dateRange != null || kind != null;
}

/// 记忆筛选底部弹出 Sheet
class MemoryFilterSheet extends StatefulWidget {
  final MemoryFilterResult currentFilter;

  const MemoryFilterSheet({super.key, required this.currentFilter});

  @override
  State<MemoryFilterSheet> createState() => _MemoryFilterSheetState();
}

class _MemoryFilterSheetState extends State<MemoryFilterSheet> {
  late String? _dateRange;
  late String? _kind;

  static const _kinds = <(String, String)>[
    ('generic', 'memory.kind.generic'),
    ('task_event', 'memory.kind.task'),
    ('dialog_event', 'memory.kind.dialog'),
    ('profile_signal', 'memory.kind.profile'),
    ('agent_goal', 'memory.kind.agent_goal'),
    ('agent_tool', 'memory.kind.agent_tool'),
    ('agent_run', 'memory.kind.agent_run'),
    ('patrol_nudge', 'memory.kind.patrol'),
  ];

  @override
  void initState() {
    super.initState();
    _dateRange = widget.currentFilter.dateRange;
    _kind = widget.currentFilter.kind;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.tr('memory.filter.title'),
                style: AppTextStyles.heading2.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _dateRange = null;
                  _kind = null;
                }),
                child: Text(context.tr('memory.filter.reset')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('memory.filter.date_range'),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _filterChip(context.tr('memory.filter.date_all'), null, _dateRange,
                  (v) => setState(() => _dateRange = v)),
              _filterChip(context.tr('memory.filter.date_7d'), '7d', _dateRange,
                  (v) => setState(() => _dateRange = v)),
              _filterChip(context.tr('memory.filter.date_30d'), '30d', _dateRange,
                  (v) => setState(() => _dateRange = v)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('memory.filter.kind'),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _filterChip(context.tr('memory.filter.kind_all'), null, _kind,
                  (v) => setState(() => _kind = v)),
              for (final (value, labelKey) in _kinds)
                _filterChip(context.tr(labelKey), value, _kind,
                    (v) => setState(() => _kind = v)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  MemoryFilterResult(dateRange: _dateRange, kind: _kind),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A7654),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(context.tr('memory.filter.apply')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    String label,
    String? value,
    String? groupValue,
    ValueChanged<String?> onSelected,
  ) {
    final isSelected = value == groupValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(isSelected ? null : value),
    );
  }
}
