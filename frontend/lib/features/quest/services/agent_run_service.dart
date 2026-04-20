import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/agent_service.dart';
import '../models/agent_run.dart';
import '../models/agent_step.dart';

class AgentRunService extends ChangeNotifier {
  AgentRunService({
    AgentRunClient? agentService,
    Duration pollInterval = const Duration(seconds: 4),
    Timer Function(Duration duration, void Function(Timer timer) callback)?
        pollingTimerFactory,
  })  : _agentService = agentService ?? AgentService(),
        _pollInterval = pollInterval,
        _pollingTimerFactory = pollingTimerFactory ?? Timer.periodic;

  final AgentRunClient _agentService;
  final Duration _pollInterval;
  final Timer Function(Duration duration, void Function(Timer timer) callback)
      _pollingTimerFactory;

  Timer? _pollTimer;
  AgentRun? _currentRun;
  List<AgentStep> _steps = const <AgentStep>[];
  bool _busy = false;
  bool _refreshing = false;
  final Set<String> _reportedLocalStepIds = <String>{};
  final Set<String> _reportingLocalStepIds = <String>{};

  AgentRun? get currentRun => _currentRun;
  List<AgentStep> get steps => _steps;
  AgentStep? get latestStep => _steps.isEmpty ? null : _steps.last;
  bool get isBusy => _busy;
  bool get hasWaitingApproval => latestStep?.isWaitingApproval ?? false;
  bool get hasWaitingLocalExecution =>
      _currentRun?.isWaitingLocalExecution ?? false;

  Future<AgentRunSnapshot> startRun({
    required String goal,
    String channel = 'desktop',
    Map<String, dynamic>? clientContext,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      final snapshot = await _agentService.startRun(
        goal: goal,
        channel: channel,
        clientContext: clientContext,
      );
      _applySnapshot(snapshot);
      return snapshot;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<AgentRunSnapshot?> refresh() async {
    final runId = _currentRun?.id;
    if (runId == null || runId.isEmpty) return null;
    if (_refreshing) return null;
    _refreshing = true;
    try {
      final snapshot = await _agentService.pollRunStatus(runId: runId);
      _applySnapshot(snapshot);
      return snapshot;
    } catch (_) {
      _stopPolling();
      return null;
    } finally {
      _refreshing = false;
    }
  }

  Future<AgentRunSnapshot?> approveLatestStep({String? reason}) async {
    final run = _currentRun;
    final step = latestStep;
    if (run == null || step == null || !step.isWaitingApproval) return null;
    final snapshot = await _agentService.approveStep(
      runId: run.id,
      stepId: step.id,
      reason: reason,
    );
    _applySnapshot(snapshot);
    return snapshot;
  }

  Future<AgentRunSnapshot?> rejectLatestStep({String? reason}) async {
    final run = _currentRun;
    final step = latestStep;
    if (run == null || step == null || !step.isWaitingApproval) return null;
    final snapshot = await _agentService.rejectStep(
      runId: run.id,
      stepId: step.id,
      reason: reason,
    );
    _applySnapshot(snapshot);
    return snapshot;
  }

  Future<AgentRunSnapshot?> reportLatestLocalResult({
    required bool success,
    String outputText = '',
    String? errorText,
    Map<String, dynamic>? resultJson,
  }) async {
    final run = _currentRun;
    final step = latestStep;
    if (run == null || step == null || !step.isToolCall) return null;
    if (!(step.isReady || step.isRunning)) return null;
    if (_reportedLocalStepIds.contains(step.id) ||
        _reportingLocalStepIds.contains(step.id)) {
      return null;
    }

    _reportingLocalStepIds.add(step.id);
    try {
      final snapshot = await _agentService.reportLocalStepResult(
        runId: run.id,
        stepId: step.id,
        success: success,
        outputText: outputText,
        errorText: errorText,
        resultJson: resultJson,
      );
      _reportedLocalStepIds.add(step.id);
      _applySnapshot(snapshot);
      return snapshot;
    } finally {
      _reportingLocalStepIds.remove(step.id);
    }
  }

  void _applySnapshot(AgentRunSnapshot snapshot) {
    final previousRunId = _currentRun?.id;
    if (previousRunId != null && previousRunId != snapshot.run.id) {
      _reportedLocalStepIds.clear();
      _reportingLocalStepIds.clear();
    }
    _currentRun = snapshot.run;
    _steps = snapshot.steps;
    if (_currentRun?.isActive == true) {
      _startPolling();
    } else {
      _stopPolling();
    }
    notifyListeners();
  }

  void _startPolling() {
    _pollTimer ??= _pollingTimerFactory(_pollInterval, (_) {
      unawaited(refresh());
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
