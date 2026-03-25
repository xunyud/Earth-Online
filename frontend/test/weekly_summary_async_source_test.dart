import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LifeDiaryPage uses async weekly summary queueing', () async {
    final pageSource =
        await File('lib/features/quest/screens/life_diary_page.dart')
            .readAsString();
    final serviceSource = await File(
      'lib/features/quest/services/weekly_summary_job_service.dart',
    ).readAsString();

    expect(pageSource, contains('_weeklySummaryService.enqueue()'));
    expect(pageSource.contains("invoke('weekly-summary'"), isFalse);
    expect(pageSource, contains("context.tr('diary.weekly.queued')"));
    expect(serviceSource, contains("'weekly-summary-enqueue'"));
  });

  test('app entry wires weekly summary reminders and root navigator', () async {
    final mainSource = await File('lib/main.dart').readAsString();
    final keySource =
        await File('lib/core/constants/app_keys.dart').readAsString();

    expect(
      mainSource,
      contains('WeeklySummaryJobService.instance.initialize()'),
    );
    expect(mainSource, contains('navigatorKey: rootNavigatorKey'));
    expect(keySource, contains('rootNavigatorKey'));
  });

  test('weekly summary completion dialog uses i18n keys', () async {
    final mainSource = await File('lib/main.dart').readAsString();
    final localeSource =
        await File('lib/core/i18n/app_locale_controller.dart').readAsString();

    expect(mainSource, contains("context.tr('weekly.summary.ready_title')"));
    expect(mainSource, contains("context.tr('weekly.summary.failed_title')"));
    expect(mainSource, contains("context.tr('weekly.summary.open_now')"));
    expect(localeSource, contains("'weekly.summary.ready_title'"));
    expect(localeSource, contains("'weekly.summary.failed_title'"));
  });

  test('LifeDiaryPage uses i18n for visible weekly summary copy', () async {
    final pageSource =
        await File('lib/features/quest/screens/life_diary_page.dart')
            .readAsString();
    final localeSource =
        await File('lib/core/i18n/app_locale_controller.dart').readAsString();

    expect(pageSource, contains("context.tr('diary.title')"));
    expect(pageSource, contains("context.tr('diary.weekly.tooltip_idle')"));
    expect(pageSource, contains("context.tr('diary.weekly.tooltip_running')"));
    expect(pageSource, contains("context.tr('diary.push_wechat.tooltip')"));
    expect(pageSource, contains("context.tr('diary.load_failed')"));
    expect(pageSource, contains("context.tr('common.retry')"));
    expect(localeSource, contains("'diary.title'"));
    expect(localeSource, contains("'diary.weekly.tooltip_idle'"));
  });

  test('Supabase config declares weekly summary jobs and migration', () async {
    final configSource = await File('../supabase/config.toml').readAsString();
    final migrationSource = await File(
      '../supabase/migrations/20260325000000_add_weekly_summary_jobs.sql',
    ).readAsString();

    expect(configSource, contains('[functions.weekly-summary-enqueue]'));
    expect(configSource, contains('[functions.weekly-summary-job]'));
    expect(
      migrationSource,
      contains('CREATE TABLE IF NOT EXISTS weekly_summary_jobs'),
    );
    expect(migrationSource, contains('notified_at'));
  });
}
