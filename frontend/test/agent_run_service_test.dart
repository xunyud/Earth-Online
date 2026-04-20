import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/agent_service.dart';
import 'package:frontend/features/quest/models/agent_run.dart';
import 'package:frontend/features/quest/models/agent_step.dart';
import 'package:frontend/features/quest/services/agent_run_service.dart';

void main() {
  test('AgentRunService 会启动轮询并应用 refresh 快照', () async {
    final timer = _FakePeriodicTimer();
    final client = _FakeAgentRunClient(
      startRunSnapshot: _snapshot(
        runStatus: 'running',
        steps: <AgentStep>[
          _step(
            id: 'step-ready',
            status: 'ready',
            toolName: 'file.read_text',
            summary: '读取 README.md',
          ),
        ],
      ),
      pollSnapshots: <AgentRunSnapshot>[
        _snapshot(
          runStatus: 'waiting_local_execution',
          steps: <AgentStep>[
            _step(
              id: 'step-ready',
              status: 'running',
              toolName: 'file.read_text',
              summary: '读取 README.md',
            ),
          ],
        ),
      ],
    );

    final service = AgentRunService(
      agentService: client,
      pollingTimerFactory: (duration, callback) {
        timer.attach(callback);
        return timer;
      },
    );

    await service.startRun(goal: '读取 README');
    expect(service.currentRun?.status, 'running');
    expect(timer.isActive, isTrue);

    timer.fire();
    await Future<void>.delayed(Duration.zero);

    expect(client.pollRunStatusCallCount, 1);
    expect(service.currentRun?.status, 'waiting_local_execution');
    expect(service.latestStep?.status, 'running');
  });

  test('AgentRunService 上报本地结果后会停止终态轮询', () async {
    final timer = _FakePeriodicTimer();
    final client = _FakeAgentRunClient(
      startRunSnapshot: _snapshot(
        runStatus: 'waiting_local_execution',
        steps: <AgentStep>[
          _step(
            id: 'step-ready',
            status: 'ready',
            toolName: 'shell.exec',
            summary: '执行 git status',
          ),
        ],
      ),
      reportSnapshot: _snapshot(
        runStatus: 'succeeded',
        steps: <AgentStep>[
          _step(
            id: 'step-ready',
            status: 'succeeded',
            toolName: 'shell.exec',
            summary: '执行 git status',
          ),
          _step(
            id: 'step-done',
            kind: 'done',
            status: 'succeeded',
            summary: '已完成总结',
            outputText: '仓库状态已总结',
          ),
        ],
      ),
    );

    final service = AgentRunService(
      agentService: client,
      pollingTimerFactory: (duration, callback) {
        timer.attach(callback);
        return timer;
      },
    );

    await service.startRun(goal: '执行 git status');
    expect(timer.isActive, isTrue);

    final snapshot = await service.reportLatestLocalResult(
      success: true,
      outputText: '命令执行完成',
      resultJson: const <String, dynamic>{'stdout': 'clean'},
    );

    expect(snapshot, isNotNull);
    expect(client.reportLocalStepResultCallCount, 1);
    expect(service.currentRun?.status, 'succeeded');
    expect(timer.isActive, isFalse);
  });

  test('AgentRunService 不会对同一 ready step 重复上报本地结果', () async {
    final completer = Completer<AgentRunSnapshot>();
    final client = _FakeAgentRunClient(
      startRunSnapshot: _snapshot(
        runStatus: 'waiting_local_execution',
        steps: <AgentStep>[
          _step(
            id: 'step-ready',
            status: 'ready',
            toolName: 'file.read_text',
            summary: '读取 README.md',
          ),
        ],
      ),
      reportFuture: completer.future,
    );

    final service = AgentRunService(agentService: client);
    await service.startRun(goal: '读取 README');

    final first = service.reportLatestLocalResult(
      success: true,
      outputText: '已读取 README',
    );
    final second = await service.reportLatestLocalResult(
      success: true,
      outputText: '重复上报',
    );

    expect(second, isNull);
    expect(client.reportLocalStepResultCallCount, 1);

    completer.complete(
      _snapshot(
        runStatus: 'succeeded',
        steps: <AgentStep>[
          _step(
            id: 'step-ready',
            status: 'succeeded',
            toolName: 'file.read_text',
            summary: '读取 README.md',
          ),
          _step(
            id: 'step-done',
            kind: 'done',
            status: 'succeeded',
            summary: '输出总结',
          ),
        ],
      ),
    );

    expect(await first, isNotNull);
  });

  test('AgentRunService 鍦ㄨ疆璇㈠け璐ユ椂浼氬仠姝㈣疆璇㈠苟杩斿洖 null', () async {
    final timer = _FakePeriodicTimer();
    final client = _FakeAgentRunClient(
      startRunSnapshot: _snapshot(
        runStatus: 'running',
        steps: <AgentStep>[
          _step(
            id: 'step-ready',
            status: 'ready',
            toolName: 'file.read_text',
            summary: '璇诲彇 README.md',
          ),
        ],
      ),
      pollError: StateError('unsupported token algorithm'),
    );

    final service = AgentRunService(
      agentService: client,
      pollingTimerFactory: (duration, callback) {
        timer.attach(callback);
        return timer;
      },
    );

    await service.startRun(goal: '璇诲彇 README');
    expect(timer.isActive, isTrue);

    final snapshot = await service.refresh();

    expect(snapshot, isNull);
    expect(client.pollRunStatusCallCount, 1);
    expect(timer.isActive, isFalse);
    expect(service.currentRun?.status, 'running');
  });
}

AgentRunSnapshot _snapshot({
  required String runStatus,
  required List<AgentStep> steps,
}) {
  return AgentRunSnapshot(
    run: AgentRun.fromJson(<String, dynamic>{
      'id': 'run-1',
      'user_id': 'user-1',
      'goal': '读取 README',
      'channel': 'desktop',
      'status': runStatus,
    }),
    steps: steps,
  );
}

AgentStep _step({
  required String id,
  String kind = 'tool_call',
  required String status,
  String? toolName,
  required String summary,
  String? outputText,
}) {
  return AgentStep.fromJson(<String, dynamic>{
    'id': id,
    'run_id': 'run-1',
    'step_index': id == 'step-ready' ? 0 : 1,
    'kind': kind,
    'tool_name': toolName,
    'risk_level': 'low',
    'needs_confirmation': false,
    'status': status,
    'summary': summary,
    'output_text': outputText,
  });
}

class _FakePeriodicTimer implements Timer {
  void Function(Timer timer)? _callback;
  bool _active = false;
  int _tick = 0;

  void attach(void Function(Timer timer) callback) {
    _callback = callback;
    _active = true;
  }

  void fire() {
    if (!_active || _callback == null) return;
    _tick += 1;
    _callback!(this);
  }

  @override
  void cancel() {
    _active = false;
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;
}

class _FakeAgentRunClient implements AgentRunClient {
  _FakeAgentRunClient({
    required this.startRunSnapshot,
    Iterable<AgentRunSnapshot> pollSnapshots = const <AgentRunSnapshot>[],
    this.pollError,
    this.reportSnapshot,
    this.reportFuture,
  }) : _pollSnapshots = Queue<AgentRunSnapshot>.from(pollSnapshots);

  final AgentRunSnapshot startRunSnapshot;
  final Queue<AgentRunSnapshot> _pollSnapshots;
  final Object? pollError;
  final AgentRunSnapshot? reportSnapshot;
  final Future<AgentRunSnapshot>? reportFuture;

  int pollRunStatusCallCount = 0;
  int reportLocalStepResultCallCount = 0;

  @override
  Future<AgentRunSnapshot> startRun({
    required String goal,
    String channel = 'desktop',
    Map<String, dynamic>? clientContext,
  }) async {
    return startRunSnapshot;
  }

  @override
  Future<AgentRunSnapshot> pollRunStatus({
    required String runId,
  }) async {
    pollRunStatusCallCount += 1;
    if (pollError != null) throw pollError!;
    return _pollSnapshots.removeFirst();
  }

  @override
  Future<AgentRunSnapshot> approveStep({
    required String runId,
    required String stepId,
    String? reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AgentRunSnapshot> rejectStep({
    required String runId,
    required String stepId,
    String? reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AgentRunSnapshot> reportLocalStepResult({
    required String runId,
    required String stepId,
    required bool success,
    String outputText = '',
    String? errorText,
    Map<String, dynamic>? resultJson,
  }) {
    reportLocalStepResultCallCount += 1;
    if (reportFuture != null) return reportFuture!;
    final snapshot = reportSnapshot;
    if (snapshot == null) {
      throw StateError('reportSnapshot 未配置');
    }
    return Future<AgentRunSnapshot>.value(snapshot);
  }
}
