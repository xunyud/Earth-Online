import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared dialogs and quick add bar read copy from i18n keys', () async {
    final confirmSource =
        await File('lib/shared/widgets/confirm_dialog.dart').readAsString();
    final quickAddSource =
        await File('lib/features/quest/widgets/quick_add_bar.dart')
            .readAsString();
    final localeSource =
        await File('lib/core/i18n/app_locale_controller.dart').readAsString();

    expect(confirmSource, contains("context.tr('common.cancel')"));
    expect(confirmSource, contains("context.tr('common.confirm')"));
    expect(confirmSource, contains("context.tr('confirm_dialog.dont_ask')"));
    expect(quickAddSource, contains("context.tr('quick_add.hint')"));
    expect(quickAddSource, contains("context.tr('common.send')"));
    expect(localeSource, contains("'confirm_dialog.dont_ask'"));
    expect(localeSource, contains("'quick_add.hint'"));
  });

  test('achievement screens use i18n keys for static labels', () async {
    final pageSource =
        await File('lib/features/achievement/screens/achievement_page.dart')
            .readAsString();
    final cardSource =
        await File('lib/features/achievement/widgets/achievement_card.dart')
            .readAsString();
    final overlaySource = await File(
      'lib/features/achievement/widgets/achievement_unlock_overlay.dart',
    ).readAsString();
    final localeSource =
        await File('lib/core/i18n/app_locale_controller.dart').readAsString();

    expect(pageSource, contains("context.tr('achievement.page_title')"));
    expect(pageSource, contains("'achievement.unlocked_progress'"));
    expect(cardSource, contains("context.tr('achievement.detail_title')"));
    expect(cardSource, contains("context.tr('achievement.status_unlocked')"));
    expect(
      cardSource,
      contains("'achievement.target.total_completed'"),
    );
    expect(
      overlaySource,
      contains("context.tr('achievement.unlocked_badge')"),
    );
    expect(localeSource, contains("'achievement.page_title'"));
    expect(localeSource, contains("'achievement.unlocked_badge'"));
  });

  test('stats screens and level titles use i18n keys', () async {
    final highlightSource =
        await File('lib/features/stats/widgets/highlight_cards.dart')
            .readAsString();
    final levelEngineSource =
        await File('lib/core/utils/level_engine.dart').readAsString();
    final localeSource =
        await File('lib/core/i18n/app_locale_controller.dart').readAsString();

    expect(
      highlightSource,
      contains("context.tr('stats.highlight.weekly_completed')"),
    );
    expect(highlightSource, contains("context.tr(data.levelTitle)"));
    expect(levelEngineSource, contains('level.title.apprentice_villager'));
    expect(localeSource, contains("'stats.title'"));
    expect(localeSource, contains("'level.title.apprentice_villager'"));
  });
}
