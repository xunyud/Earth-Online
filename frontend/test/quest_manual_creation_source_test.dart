import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'manual quick create should support integrated main creation and keep side quest attachment inside the same modal',
      () async {
    final homePage =
        await File('lib/features/quest/screens/home_page.dart').readAsString();
    final controller =
        await File('lib/features/quest/controllers/quest_controller.dart')
            .readAsString();

    expect(
      homePage.contains('enum _QuickCreateMode') &&
          homePage.contains('_QuickCreateMode.newMainWithSides') &&
          homePage.contains('_QuickCreateMode.attachToExistingMain') &&
          homePage.contains('QuickAddBar(') &&
          homePage.contains('onPlusTap: _showPlusMenu') &&
          !homePage.contains("label: '创建策略'") &&
          homePage.contains('新建主线并添加支线') &&
          homePage.contains('挂到已有主线') &&
          homePage.contains('_sideDraftControllers') &&
          homePage.contains('for (final sideTitle in result.sideTitles)') &&
          homePage.contains(
            "return _normalizedSideTitles.isEmpty ? '创建主线' : '创建主线和支线';",
          ) &&
          homePage.contains("return '创建支线';") &&
          homePage.contains("return '创建日常任务';") &&
          !homePage.contains("return '????'") &&
          !homePage.contains('保留原本的快速支线创建方式') &&
          !homePage.contains('不再使用系统下拉框') &&
          homePage.contains('只创建一条支线，并挂到选中的主线上。') &&
          !homePage.contains('DropdownButtonFormField<String>') &&
          homePage.contains('_selectedParentMainQuestId') &&
          homePage.contains('title: _attachSideTitleController.text.trim()') &&
          !homePage.contains(
            "mode: _QuickCreateMode.attachToExistingMain,\n            title: _attachSideTitleController.text.trim(),\n            sideTitles:",
          ) &&
          controller.contains('Future<QuestNode?> createManualQuest(') &&
          controller.contains("'parent_id': normalizedParentId,") &&
          controller.contains("normalizedTier == 'Side_Quest'"),
      isTrue,
      reason:
          'Quick create should support new main+side drafting while still allowing a side quest to attach to an existing Main_Quest in the same modal.',
    );
  });

  test(
      'daily quest creation and editing should use a time picker instead of a date-only deadline',
      () async {
    final homePage =
        await File('lib/features/quest/screens/home_page.dart').readAsString();
    final editSheet =
        await File('lib/features/quest/widgets/quest_edit_sheet.dart')
            .readAsString();
    final item =
        await File('lib/features/quest/widgets/quest_item.dart').readAsString();

    expect(
      homePage.contains('showTimePicker(') &&
          homePage.contains('dailyDueMinutes') &&
          editSheet.contains('showTimePicker(') &&
          editSheet.contains('daily_due_minutes') &&
          item.contains('daily_due_minutes'),
      isTrue,
      reason:
          'Daily quests should capture, store, and display a daily HH:mm deadline instead of a calendar date.',
    );
  });
}
