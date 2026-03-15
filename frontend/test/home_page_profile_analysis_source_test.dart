import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('画像弹窗使用人类可读指标，并展示 AI 评价而不是记忆锚点', () async {
    final file = File('lib/features/quest/screens/home_page.dart');
    final content = await file.readAsString();

    expect(
      content.contains('_PortraitInsightChart(') &&
          content.contains('_PortraitEvaluationSection(') &&
          content.contains('_PortraitReadableMetricGrid(') &&
          !content.contains("profile.meta.model") &&
          !content.contains("profile.meta.seed") &&
          !content.contains("profile.meta.style") &&
          !content.contains("profile.meta.trace_id") &&
          !content.contains("profile.memory_refs"),
      isTrue,
      reason: '画像弹窗应展示给人看的指标与 AI 评价，不能继续暴露技术字段或记忆锚点计数。',
    );
  });
}
