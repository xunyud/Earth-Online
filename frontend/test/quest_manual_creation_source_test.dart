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

    final quickCreateDialog =
        await File('lib/features/quest/widgets/quick_create_dialog_content.dart').readAsString();

    expect(
      quickCreateDialog.contains('enum QuickCreateMode') &&
          quickCreateDialog.contains('QuickCreateMode.newMainWithSides') &&
          quickCreateDialog.contains('QuickCreateMode.attachToExistingMain') &&
          homePage.contains('QuickAddBar(') &&
          homePage.contains('onPlusTap: _showPlusMenu') &&
          !homePage.contains("label: '创建策略'") &&
          quickCreateDialog.contains('quick_add.dialog.mode.new_main.title') &&
          quickCreateDialog.contains('quick_add.dialog.mode.attach.title') &&
          quickCreateDialog.contains('_sideDraftControllers') &&
          homePage.contains('for (final sideTitle in result.sideTitles)') &&
          quickCreateDialog.contains('quick_add.create.tier_main') &&
          quickCreateDialog.contains('quick_add.create.tier_side') &&
          quickCreateDialog.contains('quick_add.dialog.mode.daily.title') &&
          !quickCreateDialog.contains("return '????'") &&
          !quickCreateDialog.contains('保留原本的快速支线创建方式') &&
          !quickCreateDialog.contains('不再使用系统下拉框') &&
          quickCreateDialog.contains('quick_add.dialog.side_description') &&
          !quickCreateDialog.contains('DropdownButtonFormField<String>') &&
          quickCreateDialog.contains('_selectedParentMainQuestId') &&
          quickCreateDialog.contains('title: _attachSideTitleController.text.trim()') &&
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

    final quickCreateDialog =
        await File('lib/features/quest/widgets/quick_create_dialog_content.dart').readAsString();

    expect(
      quickCreateDialog.contains('showTimePicker(') &&
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
