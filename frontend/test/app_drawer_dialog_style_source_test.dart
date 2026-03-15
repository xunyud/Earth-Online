import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppDrawer 的昵称与退出弹窗改为统一风格实现', () async {
    final content =
        await File('lib/core/widgets/app_drawer.dart').readAsString();

    expect(
      content.contains("barrierLabel: 'drawer_profile_name_dialog'") &&
          content.contains('showQuestDialog<String>(') &&
          content.contains('showConfirmDialog(') &&
          content.contains('danger: true') &&
          !content.contains('final confirmed = await showDialog<bool>('),
      isTrue,
      reason: '抽屉中的昵称编辑和退出登录确认应复用统一弹窗样式，而不是继续使用原生 AlertDialog。',
    );
  });
}
