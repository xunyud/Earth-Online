import 'package:flutter/material.dart';
import '../i18n/app_locale_controller.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const String englishFontFamily = 'Segoe UI';
  static const String chineseFontFamily = 'Noto Sans SC';

  static const List<String> englishFontFamilyFallback = <String>[
    'Aptos',
    'Segoe UI Variable Display',
    'Segoe UI',
    'Helvetica Neue',
    'Arial',
    'Noto Sans',
    'Noto Sans SC',
    'Noto Sans CJK SC',
    'PingFang SC',
    'Hiragino Sans GB',
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'Source Han Sans SC',
    'WenQuanYi Micro Hei',
    'Segoe UI Emoji',
    'Apple Color Emoji',
    'Noto Color Emoji',
  ];

  static const List<String> chineseFontFamilyFallback = <String>[
    'Noto Sans SC',
    'Noto Sans CJK SC',
    'PingFang SC',
    'Hiragino Sans GB',
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'Source Han Sans SC',
    'WenQuanYi Micro Hei',
    'Segoe UI',
    'Helvetica Neue',
    'Arial',
    'Noto Sans',
    'Segoe UI Emoji',
    'Apple Color Emoji',
    'Noto Color Emoji',
  ];

  static bool get _isEnglish => AppLocaleController.instance.isEnglish;

  static String currentFontFamily({bool? isEnglish}) {
    return (isEnglish ?? _isEnglish) ? englishFontFamily : chineseFontFamily;
  }

  static List<String> currentFontFamilyFallback({bool? isEnglish}) {
    return List<String>.unmodifiable(
      (isEnglish ?? _isEnglish)
          ? englishFontFamilyFallback
          : chineseFontFamilyFallback,
    );
  }

  static TextTheme applyFontFallback(TextTheme textTheme, {bool? isEnglish}) {
    TextStyle? withFallback(TextStyle? style) => style == null
        ? null
        : AppTextStyles.withFontFallback(style, isEnglish: isEnglish);

    return textTheme.copyWith(
      displayLarge: withFallback(textTheme.displayLarge),
      displayMedium: withFallback(textTheme.displayMedium),
      displaySmall: withFallback(textTheme.displaySmall),
      headlineLarge: withFallback(textTheme.headlineLarge),
      headlineMedium: withFallback(textTheme.headlineMedium),
      headlineSmall: withFallback(textTheme.headlineSmall),
      titleLarge: withFallback(textTheme.titleLarge),
      titleMedium: withFallback(textTheme.titleMedium),
      titleSmall: withFallback(textTheme.titleSmall),
      bodyLarge: withFallback(textTheme.bodyLarge),
      bodyMedium: withFallback(textTheme.bodyMedium),
      bodySmall: withFallback(textTheme.bodySmall),
      labelLarge: withFallback(textTheme.labelLarge),
      labelMedium: withFallback(textTheme.labelMedium),
      labelSmall: withFallback(textTheme.labelSmall),
    );
  }

  static TextStyle withFontFallback(TextStyle style, {bool? isEnglish}) {
    final preferredFallback = currentFontFamilyFallback(isEnglish: isEnglish);
    final currentFallback = style.fontFamilyFallback ?? const <String>[];
    final mergedFallback = <String>[
      ...currentFallback,
      ...preferredFallback.where((font) => !currentFallback.contains(font)),
    ];
    return style.copyWith(
      fontFamily: currentFontFamily(isEnglish: isEnglish),
      fontFamilyFallback: mergedFallback,
    );
  }

  static TextStyle get heading1 => withFontFallback(
        const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
      );

  static TextStyle get heading2 => withFontFallback(
        const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
      );

  static TextStyle get body => withFontFallback(
        const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
      );

  static TextStyle get caption => withFontFallback(
        const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
      );

  static TextStyle get button => withFontFallback(
        const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.pureWhite,
        ),
      );
}
