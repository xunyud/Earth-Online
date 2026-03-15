import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('simulateAIParsing 需要在分析中阻止重复提交', () async {
    final file = File('lib/features/quest/controllers/quest_controller.dart');
    final content = await file.readAsString();

    expect(
      content.contains('if (_isAnalyzing || input.trim().isEmpty) return;') ||
          content.contains('if (_isAnalyzing) return;'),
      isTrue,
      reason: 'simulateAIParsing 缺少并发闸门，重复点击可能并发触发 parse-quest。',
    );
  });
}
