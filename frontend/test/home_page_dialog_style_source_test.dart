import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HomePage 向导提示与事件弹窗接入统一森林风格弹窗壳', () async {
    final content =
        await File('lib/features/quest/screens/home_page.dart').readAsString();

    expect(
      content.contains("barrierLabel: 'guide_name_dialog'") &&
          content.contains("barrierLabel: 'guide_daily_open_dialog'") &&
          content.contains("barrierLabel: 'guide_daily_event_dialog'") &&
          content.contains('showQuestDialog<String>(') &&
          content.contains('showQuestDialog<void>(') &&
          content.contains('showQuestDialog<bool>(') &&
          content.contains('QuestDialogShell(') &&
          content.contains('QuestDialogInfoCard('),
      isTrue,
      reason: '首页的小忆改名、上线提示和地球突发事件弹窗应统一迁移到共享森林风格弹窗壳。',
    );
  });
}
