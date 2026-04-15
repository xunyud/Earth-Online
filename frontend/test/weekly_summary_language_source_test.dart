import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weekly summary enqueue sends locale context from frontend', () async {
    final source = await File(
      'lib/features/quest/services/weekly_summary_job_service.dart',
    ).readAsString();

    expect(
        source,
        contains(
            "'language_code': AppLocaleController.instance.locale.languageCode"));
    expect(source,
        contains("'is_english': AppLocaleController.instance.isEnglish"));
  });

  test('weekly summary enqueue forwards locale context to background job',
      () async {
    final source =
        await File('../supabase/functions/weekly-summary-enqueue/index.ts')
            .readAsString();

    expect(source, contains('languageCode'));
    expect(source, contains('isEnglish'));
    expect(
        source,
        contains(
            'JSON.stringify({ user_id: userId, language_code: languageCode, is_english: isEnglish })'));
  });

  test(
      'weekly report push forwards locale context into weekly summary generation',
      () async {
    final source =
        await File('../supabase/functions/weekly-report-push/index.ts')
            .readAsString();

    expect(source, contains('language_code: requestedLanguage'));
    expect(source, contains('is_english: requestedLanguage === "en"'));
    expect(source, contains('Weekly Adventure Report'));
  });

  test(
      'weekly summary generation supports english prompt and stable prefix markers',
      () async {
    final source = await File('../supabase/functions/weekly-summary/index.ts')
        .readAsString();

    expect(
        source, contains('const WEEKLY_SUMMARY_PREFIX = "[WEEKLY_SUMMARY]"'));
    expect(source, contains('function resolveSummaryLanguage('));
    expect(source, contains('function localizedText('));
    expect(source, contains('success: true, summary, language'));
    expect(source, contains('Brave apprentice villager'));
  });

  test(
      'life diary recognizes weekly summary marker without relying on chinese-only prefix',
      () async {
    final source = await File('lib/features/quest/screens/life_diary_page.dart')
        .readAsString();

    expect(source, contains('const _weeklySummaryPrefixes = <String>['));
    expect(source, contains("'[WEEKLY_SUMMARY]'"));
    expect(source,
        isNot(contains("static const _weeklySummaryPrefix = '【本周总结】';")));
  });
}
