import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum WeeklySummaryJobStatus {
  queued,
  running,
  succeeded,
  failed,
  unknown,
}

class WeeklySummaryJob {
  final String id;
  final WeeklySummaryJobStatus status;
  final String? summaryDateId;
  final String? errorMessage;
  final DateTime? finishedAt;
  final DateTime? notifiedAt;

  const WeeklySummaryJob({
    required this.id,
    required this.status,
    this.summaryDateId,
    this.errorMessage,
    this.finishedAt,
    this.notifiedAt,
  });

  bool get isActive =>
      status == WeeklySummaryJobStatus.queued ||
      status == WeeklySummaryJobStatus.running;

  bool get needsReminder =>
      (status == WeeklySummaryJobStatus.succeeded ||
          status == WeeklySummaryJobStatus.failed) &&
      notifiedAt == null;

  bool get isSuccess => status == WeeklySummaryJobStatus.succeeded;

  factory WeeklySummaryJob.fromJson(Map<String, dynamic> json) {
    return WeeklySummaryJob(
      id: (json['id'] ?? '').toString(),
      status: _parseStatus(json['status']?.toString()),
      summaryDateId: _parseOptionalText(json['summary_date_id']),
      errorMessage: _parseOptionalText(json['error_message']),
      finishedAt: _parseDateTime(json['finished_at']),
      notifiedAt: _parseDateTime(json['notified_at']),
    );
  }

  static WeeklySummaryJobStatus _parseStatus(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'queued':
        return WeeklySummaryJobStatus.queued;
      case 'running':
        return WeeklySummaryJobStatus.running;
      case 'succeeded':
        return WeeklySummaryJobStatus.succeeded;
      case 'failed':
        return WeeklySummaryJobStatus.failed;
      default:
        return WeeklySummaryJobStatus.unknown;
    }
  }

  static String? _parseOptionalText(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return text;
  }

  static DateTime? _parseDateTime(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

abstract class WeeklySummaryJobGateway {
  Future<Map<String, dynamic>> invoke(
    String functionName,
    Map<String, dynamic> body,
  );
}

class SupabaseWeeklySummaryJobGateway implements WeeklySummaryJobGateway {
  const SupabaseWeeklySummaryJobGateway();

  @override
  Future<Map<String, dynamic>> invoke(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    final response = await Supabase.instance.client.functions.invoke(
      functionName,
      body: body,
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    throw StateError('函数 $functionName 返回了无法识别的数据格式');
  }
}

typedef PollingTimerFactory = Timer Function(
  Duration duration,
  void Function(Timer timer) callback,
);

class WeeklySummaryJobService extends ChangeNotifier {
  WeeklySummaryJobService({
    WeeklySummaryJobGateway? gateway,
    Future<String?> Function()? currentUserIdProvider,
    Duration pollInterval = const Duration(seconds: 6),
    PollingTimerFactory? pollingTimerFactory,
  })  : _gateway = gateway ?? const SupabaseWeeklySummaryJobGateway(),
        _currentUserIdProvider =
            currentUserIdProvider ?? _defaultCurrentUserIdProvider,
        _pollInterval = pollInterval,
        _pollingTimerFactory = pollingTimerFactory ?? Timer.periodic;

  WeeklySummaryJobService._singleton()
      : _gateway = const SupabaseWeeklySummaryJobGateway(),
        _currentUserIdProvider = _defaultCurrentUserIdProvider,
        _pollInterval = const Duration(seconds: 6),
        _pollingTimerFactory = Timer.periodic;

  static final WeeklySummaryJobService instance =
      WeeklySummaryJobService._singleton();

  final WeeklySummaryJobGateway _gateway;
  final Future<String?> Function() _currentUserIdProvider;
  final Duration _pollInterval;
  final PollingTimerFactory _pollingTimerFactory;

  Timer? _pollTimer;
  WeeklySummaryJob? _latestJob;
  WeeklySummaryJob? _pendingReminder;
  bool _initializing = false;
  bool _refreshing = false;

  WeeklySummaryJob? get latestJob => _latestJob;
  WeeklySummaryJob? get pendingReminder => _pendingReminder;
  bool get hasActiveJob => _latestJob?.isActive ?? false;

  Future<void> initialize() async {
    if (_initializing) return;
    _initializing = true;
    try {
      await refreshStatus();
    } finally {
      _initializing = false;
    }
  }

  Future<WeeklySummaryJob?> enqueue() async {
    final userId = await _currentUserIdProvider();
    if (userId == null || userId.isEmpty) return null;
    final data = await _gateway.invoke(
      'weekly-summary-enqueue',
      <String, dynamic>{'user_id': userId},
    );
    final job = _extractJob(data);
    _applyJob(job);
    return job;
  }

  Future<WeeklySummaryJob?> refreshStatus() async {
    if (_refreshing) return _latestJob;
    final userId = await _currentUserIdProvider();
    if (userId == null || userId.isEmpty) {
      _applyJob(null);
      return null;
    }

    _refreshing = true;
    try {
      final data = await _gateway.invoke(
        'weekly-summary-job',
        <String, dynamic>{'user_id': userId},
      );
      final job = _extractJob(data);
      _applyJob(job);
      return job;
    } finally {
      _refreshing = false;
    }
  }

  Future<void> acknowledgeReminder(String jobId) async {
    final userId = await _currentUserIdProvider();
    if (userId == null || userId.isEmpty) return;
    await _gateway.invoke(
      'weekly-summary-job',
      <String, dynamic>{
        'action': 'acknowledge',
        'user_id': userId,
        'job_id': jobId,
      },
    );
    _pendingReminder = null;
    notifyListeners();
  }

  void _applyJob(WeeklySummaryJob? job) {
    _latestJob = job;
    if (job == null) {
      _pendingReminder = null;
      _stopPolling();
      notifyListeners();
      return;
    }

    if (job.isActive) {
      _pendingReminder = null;
      _startPolling();
    } else {
      _stopPolling();
      _pendingReminder = job.needsReminder ? job : null;
    }
    notifyListeners();
  }

  WeeklySummaryJob? _extractJob(Map<String, dynamic> data) {
    final success = data['success'];
    if (success == false) {
      final error = data['error']?.toString().trim();
      throw StateError(error?.isNotEmpty == true ? error! : '周报任务接口返回失败');
    }
    final rawJob = data['job'];
    if (rawJob is Map<String, dynamic>) {
      return WeeklySummaryJob.fromJson(rawJob);
    }
    if (rawJob is Map) {
      return WeeklySummaryJob.fromJson(
        rawJob.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return null;
  }

  void _startPolling() {
    if (_pollTimer != null) return;
    _pollTimer = _pollingTimerFactory(_pollInterval, (_) {
      unawaited(refreshStatus());
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @visibleForTesting
  void disposeService() {
    _stopPolling();
    _latestJob = null;
    _pendingReminder = null;
    _initializing = false;
    _refreshing = false;
  }

  static Future<String?> _defaultCurrentUserIdProvider() async {
    return Supabase.instance.client.auth.currentUser?.id;
  }
}
