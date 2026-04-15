import 'package:flutter/material.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../theme/stats_colors.dart';
import '../theme/stats_text_styles.dart';

/// 仪表盘页面 Header
/// 标题"成长仪表盘" + 装饰竖线 + 连续天数副标题
class StatsHeader extends StatelessWidget {
  final int streakDays;
  final Animation<double> animation;

  const StatsHeader({
    Key? key,
    required this.streakDays,
    required this.animation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.08),
          end: Offset.zero,
        ).animate(animation),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 装饰竖线
              Container(
                width: 3,
                height: 40,
                margin: const EdgeInsets.only(right: 12, top: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      StatsColors.goldPrimary,
                      StatsColors.softSage,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('stats.dashboard_title'),
                      style: AppTextStyles.withFontFallback(const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: StatsColors.bodyText,
                      )),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      streakDays > 0
                          ? context.tr(
                              'stats.dashboard_subtitle_streak',
                              params: {'count': '$streakDays'},
                            )
                          : context.tr('stats.dashboard_subtitle_empty'),
                      style: StatsTextStyles.metricLabel.copyWith(
                        fontSize: 13,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
