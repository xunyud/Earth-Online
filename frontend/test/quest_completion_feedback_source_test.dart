import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('任务完成反馈改为顶部 MaterialBanner，避免被底部输入条遮挡', () async {
    final file = File('lib/features/quest/controllers/quest_controller.dart');
    final content = await file.readAsString();

    expect(
      content.contains('showMaterialBanner(') &&
          content.contains('hideCurrentMaterialBanner()'),
      isTrue,
      reason: '完成/撤销任务的反馈需要显示在顶部可见区域，不能继续依赖容易被底部输入条遮住的 snackbar。',
    );
  });
}
