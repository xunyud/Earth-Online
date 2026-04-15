import 'package:flutter/material.dart';
import '../../../core/constants/app_text_styles.dart';
import '../theme/stats_colors.dart';

/// Pill 形分段切换控件
/// 用于图表的 7天/30天 切换等场景
class SegmentedToggle extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const SegmentedToggle({
    Key? key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: StatsColors.dividerLine,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(labels.length, (i) {
          final isSelected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? StatsColors.cardSurface : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
                boxShadow: isSelected
                    ? const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                labels[i],
                style: AppTextStyles.withFontFallback(TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? StatsColors.bodyText
                      : StatsColors.subtitleText,
                )),
              ),
            ),
          );
        }),
      ),
    );
  }
}
