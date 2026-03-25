import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/quest/services/weekly_summary_job_service.dart';

class _FakeWeeklySummaryJobGateway implements WeeklySummaryJobGateway {
  final List<Map<String, dynamic>> responses;
  final List<_GatewayCall> calls = <_GatewayCall>[];

  _FakeWeeklySummaryJobGateway(this.responses);

  @override
  Future<Map<String, dynamic>> invoke(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    calls.add(_GatewayCall(functionName: functionName, body: body));
    if (responses.isEmpty) {
      throw StateError('No fake response queued for $functionName');
    }
    return responses.removeAt(0);
  }
}

class _GatewayCall {
  final String functionName;
  final Map<String, dynamic> body;

  const _GatewayCall({required this.functionName, required this.body});
}

void main() {
  test('WeeklySummaryJob 会识别活跃状态与待提醒状态', () {
    final runningJob = WeeklySummaryJob.fromJson(<String, dynamic>{
      'id': 'job-running',
      'status': 'running',
    });
    final succeededJob = WeeklySummaryJob.fromJson(<String, dynamic>{
      'id': 'job-done',
      'status': 'succeeded',
      'notified_at': null,
    });

    expect(runningJob.isActive, isTrue);
    expect(runningJob.needsReminder, isFalse);
    expect(succeededJob.isActive, isFalse);
    expect(succeededJob.needsReminder, isTrue);
  });

  test('refreshStatus 会记录后端返回的未提醒完成任务', () async {
    final gateway = _FakeWeeklySummaryJobGateway(<Map<String, dynamic>>[
      <String, dynamic>{
        'success': true,
        'job': <String, dynamic>{
          'id': 'job-success',
          'status': 'succeeded',
          'summary_date_id': '2026-03-25',
          'notified_at': null,
        },
      },
    ]);
    final service = WeeklySummaryJobService(
      gateway: gateway,
      currentUserIdProvider: () async => 'user-1',
    );

    await service.refreshStatus();

    expect(service.pendingReminder?.id, 'job-success');
    expect(service.hasActiveJob, isFalse);
    expect(gateway.calls.single.functionName, 'weekly-summary-job');
  });

  test('acknowledgeReminder 会清空提醒并回写服务端状态', () async {
    final gateway = _FakeWeeklySummaryJobGateway(<Map<String, dynamic>>[
      <String, dynamic>{
        'success': true,
        'job': <String, dynamic>{
          'id': 'job-success',
          'status': 'succeeded',
          'notified_at': null,
        },
      },
      <String, dynamic>{'success': true},
    ]);
    final service = WeeklySummaryJobService(
      gateway: gateway,
      currentUserIdProvider: () async => 'user-1',
    );

    await service.refreshStatus();
    await service.acknowledgeReminder('job-success');

    expect(service.pendingReminder, isNull);
    expect(gateway.calls.last.functionName, 'weekly-summary-job');
    expect(gateway.calls.last.body['action'], 'acknowledge');
    expect(gateway.calls.last.body['job_id'], 'job-success');
  });
}
