import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('画像分析文案键已补齐，支持人类可读指标与 AI 评价', () async {
    final file = File('lib/core/i18n/profile_analysis_texts.dart');
    final content = await file.readAsString();

    expect(
      content.contains('profile.analysis_title') &&
          content.contains('profile.analysis_notice') &&
          content.contains('profile.metric.energy') &&
          content.contains('profile.metric.rhythm') &&
          content.contains('profile.evaluation_title'),
      isTrue,
      reason: '新版画像分析面板需要人类可读的指标文案和 AI 评价标题。',
    );
  });
}
