import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quick create dialog uses localization keys for new mode copy', () async {
    final source = await File(
      'lib/features/quest/screens/home_page.dart',
    ).readAsString();

    expect(source, contains("context.tr('quick_add.dialog.mode.new_main.title')"));
    expect(source, contains("context.tr('quick_add.dialog.mode.attach.title')"));
    expect(source, contains("context.tr('quick_add.dialog.mode.daily.title')"));
    expect(source, contains("context.tr('quick_add.dialog.daily_due_title')"));
    expect(source, contains("context.tr('quick_add.dialog.side_index'"));

    expect(source, isNot(contains("title: '新建主线并添加支线'")));
    expect(source, isNot(contains("label: '日常节奏'")));
    expect(source, isNot(contains("tooltip: '删除这条支线'")));
  });
}
