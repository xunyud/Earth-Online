import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HomePage builds guide client context with locale metadata', () async {
    final source =
        await File('lib/features/quest/screens/home_page.dart').readAsString();

    expect(source, contains("'language_code':"));
    expect(source, contains("'is_english':"));
  });

  test('GuideService forwards optional client context for bootstrap and chat',
      () async {
    final source =
        await File('lib/core/services/guide_service.dart').readAsString();

    expect(source, contains("Future<GuideBootstrapResult> bootstrap({"));
    expect(source, contains("body['client_context'] = clientContext;"));
    expect(
      source,
      contains("final data = await _invoke('guide-chat', body: body);"),
    );
  });

  test('QuickAddBar speech locale follows current app language', () async {
    final source = await File('lib/features/quest/widgets/quick_add_bar.dart')
        .readAsString();

    expect(source, contains("localeId: context.isEnglish ? 'en_US' : 'zh_CN'"));
  });

  test('HomePage caches and waits for local agent step results', () async {
    final source =
        await File('lib/features/quest/screens/home_page.dart').readAsString();

    expect(source, contains('_localAgentStepResults'));
    expect(
      source,
      contains('return _waitForLocalAgentStepResult(pendingStepId);'),
    );
    expect(
      source,
      contains("final cachedResult = _localAgentStepResults[step.id];"),
    );
  });

  test('HomePage prefers local step output before previous assistant text',
      () async {
    final source =
        await File('lib/features/quest/screens/home_page.dart').readAsString();

    expect(
      source,
      contains("final localOutput = localResult?.outputText.trim() ?? '';"),
    );
    expect(source, contains('reply: localOutput.isNotEmpty'));
    expect(source, contains(": (latest ?? fallbackReply),"));
  });

  test('GuidePanelDialog does not render process bubbles', () async {
    final source =
        await File('lib/features/quest/widgets/guide_panel_dialog.dart')
            .readAsString();

    expect(source, isNot(contains('AgentStepTimeline(')));
    expect(source, isNot(contains('AgentApprovalCard(')));
    expect(source, isNot(contains('_GuideAgentTimelineCard(')));
    expect(source, isNot(contains('_GuideInfoMessageCard(')));
    expect(source, isNot(contains('_GuideResultStatusCard(')));
  });
}
