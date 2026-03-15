import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('设置页新增中文文案保持可读且不包含问号占位', () async {
    final content =
        await File('lib/core/i18n/app_locale_controller.dart').readAsString();

    expect(
      content.contains("settings.subtitle': {\n    'zh': '把向导、外观和语言整理到一个清爽面板里。'") &&
          content.contains("settings.section.guide_desc': {\n    'zh': '决定 AI 什么时候陪你开场，什么时候安静待机。'") &&
          content.contains("settings.theme.forest': {'zh': '森林冒险', 'en': 'Forest Adventure'}") &&
          content.contains("settings.lang.zh': {'zh': '中文', 'en': 'Chinese'}") &&
          content.contains("settings.saved': {'zh': '设置已保存。', 'en': 'Settings saved.'}") &&
          !content.contains("settings.title': {'zh': '????'") &&
          !content.contains("settings.theme.forest': {'zh': '????'") &&
          !content.contains("settings.lang.zh': {'zh': '??'"),
      isTrue,
      reason: '设置页新增中文文案必须保持 UTF-8 可读，不能退化成问号占位。',
    );
  });
}
