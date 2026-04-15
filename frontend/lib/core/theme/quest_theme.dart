import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

@immutable
class QuestTheme extends ThemeExtension<QuestTheme> {
  final Color mainQuestColor;
  final Color sideQuestColor;
  final Color dailyQuestColor;
  final TextStyle questTitleStyle;

  // New Design System Properties
  final Color backgroundColor;
  final Color surfaceColor;
  final Color primaryAccentColor;

  const QuestTheme({
    required this.mainQuestColor,
    required this.sideQuestColor,
    required this.dailyQuestColor,
    required this.questTitleStyle,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.primaryAccentColor,
  });

  @override
  QuestTheme copyWith({
    Color? mainQuestColor,
    Color? sideQuestColor,
    Color? dailyQuestColor,
    TextStyle? questTitleStyle,
    Color? backgroundColor,
    Color? surfaceColor,
    Color? primaryAccentColor,
  }) {
    return QuestTheme(
      mainQuestColor: mainQuestColor ?? this.mainQuestColor,
      sideQuestColor: sideQuestColor ?? this.sideQuestColor,
      dailyQuestColor: dailyQuestColor ?? this.dailyQuestColor,
      questTitleStyle: questTitleStyle ?? this.questTitleStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      primaryAccentColor: primaryAccentColor ?? this.primaryAccentColor,
    );
  }

  @override
  QuestTheme lerp(ThemeExtension<QuestTheme>? other, double t) {
    if (other is! QuestTheme) return this;
    return QuestTheme(
      mainQuestColor: Color.lerp(mainQuestColor, other.mainQuestColor, t)!,
      sideQuestColor: Color.lerp(sideQuestColor, other.sideQuestColor, t)!,
      dailyQuestColor: Color.lerp(dailyQuestColor, other.dailyQuestColor, t)!,
      questTitleStyle:
          TextStyle.lerp(questTitleStyle, other.questTitleStyle, t)!,
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t)!,
      surfaceColor: Color.lerp(surfaceColor, other.surfaceColor, t)!,
      primaryAccentColor:
          Color.lerp(primaryAccentColor, other.primaryAccentColor, t)!,
    );
  }

  // Factory for "Fresh Breath" Theme (Default)
  static QuestTheme freshBreath() {
    return QuestTheme(
      mainQuestColor: AppColors.mintGreen,
      sideQuestColor: AppColors.skyBlue,
      dailyQuestColor: AppColors.softBlue,
      questTitleStyle: AppTextStyles.heading2,
      backgroundColor: AppColors.warmWhite,
      surfaceColor: AppColors.pureWhite,
      primaryAccentColor: AppColors.mintGreenDark,
    );
  }

  static QuestTheme forestAdventure() {
    return QuestTheme(
      mainQuestColor: AppColors.goldAccent,
      sideQuestColor: AppColors.steelBlue,
      dailyQuestColor: AppColors.limeGreen,
      questTitleStyle: AppTextStyles.heading2,
      backgroundColor: AppColors.parchmentBg,
      surfaceColor: AppColors.parchmentSurface,
      primaryAccentColor: AppColors.forestGreen,
    );
  }

  // Legacy
  static QuestTheme brightWorld() {
    return freshBreath();
  }
}
