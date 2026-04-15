import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/quest/models/agent_run.dart';
import '../../features/quest/models/agent_step.dart';
import 'guide_service.dart';
import 'supabase_auth_service.dart';

abstract class AgentRunClient {
  Future<AgentRunSnapshot> startRun({
    required String goal,
    String channel = 'desktop',
    Map<String, dynamic>? clientContext,
  });

  Future<AgentRunSnapshot> pollRunStatus({
    required String runId,
  });

  Future<AgentRunSnapshot> approveStep({
    required String runId,
    required String stepId,
    String? reason,
  });

  Future<AgentRunSnapshot> rejectStep({
    required String runId,
    required String stepId,
    String? reason,
  });

  Future<AgentRunSnapshot> reportLocalStepResult({
    required String runId,
    required String stepId,
    required bool success,
    String outputText = '',
    String? errorText,
    Map<String, dynamic>? resultJson,
  });
}

class AgentRunSnapshot {
  final AgentRun run;
  final List<AgentStep> steps;

  const AgentRunSnapshot({
    required this.run,
    required this.steps,
  });

  AgentStep? get latestStep => steps.isEmpty ? null : steps.last;
}

class AgentService implements AgentRunClient {
  AgentService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<AgentRunSnapshot> startRun({
    required String goal,
    String channel = 'desktop',
    Map<String, dynamic>? clientContext,
  }) async {
    final data = await _invoke(
      'agent-turn',
      body: <String, dynamic>{
        'goal': goal,
        'channel': channel,
        if (clientContext != null && clientContext.isNotEmpty)
          'client_context': clientContext,
      },
    );
    return AgentRunSnapshot(
      run: AgentRun.fromJson(_parseMap(data['run'])),
      steps: _parseSteps(data['steps']),
    );
  }

  @override
  Future<AgentRunSnapshot> pollRunStatus({
    required String runId,
  }) async {
    final data = await _invoke(
      'agent-run-status',
      body: <String, dynamic>{'run_id': runId},
    );
    return AgentRunSnapshot(
      run: AgentRun.fromJson(_parseMap(data['run'])),
      steps: _parseSteps(data['steps']),
    );
  }

  @override
  Future<AgentRunSnapshot> approveStep({
    required String runId,
    required String stepId,
    String? reason,
  }) async {
    final data = await _invoke(
      'agent-step-approve',
      body: <String, dynamic>{
        'run_id': runId,
        'step_id': stepId,
        'decision': 'approved',
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    return AgentRunSnapshot(
      run: AgentRun.fromJson(_parseMap(data['run'])),
      steps: _parseSteps(data['steps']),
    );
  }

  @override
  Future<AgentRunSnapshot> rejectStep({
    required String runId,
    required String stepId,
    String? reason,
  }) async {
    final data = await _invoke(
      'agent-step-approve',
      body: <String, dynamic>{
        'run_id': runId,
        'step_id': stepId,
        'decision': 'rejected',
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    return AgentRunSnapshot(
      run: AgentRun.fromJson(_parseMap(data['run'])),
      steps: _parseSteps(data['steps']),
    );
  }

  @override
  Future<AgentRunSnapshot> reportLocalStepResult({
    required String runId,
    required String stepId,
    required bool success,
    String outputText = '',
    String? errorText,
    Map<String, dynamic>? resultJson,
  }) async {
    final data = await _invoke(
      'agent-step-complete',
      body: <String, dynamic>{
        'run_id': runId,
        'step_id': stepId,
        'success': success,
        'output_text': outputText,
        if (errorText != null && errorText.trim().isNotEmpty)
          'error_text': errorText.trim(),
        if (resultJson != null && resultJson.isNotEmpty) 'result_json': resultJson,
      },
    );
    return AgentRunSnapshot(
      run: AgentRun.fromJson(_parseMap(data['run'])),
      steps: _parseSteps(data['steps']),
    );
  }

  Future<Map<String, dynamic>> _invoke(
    String functionName, {
    required Map<String, dynamic> body,
  }) async {
    final accessToken =
        await SupabaseAuthService.instance.getValidAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw const GuideServiceException(
        type: GuideErrorType.authExpired,
        message: '用户会话已失效，请重新登录后再试',
      );
    }
    try {
      final response = await _supabase.functions.invoke(
        functionName,
        headers: <String, String>{'Authorization': 'Bearer $accessToken'},
        body: body,
      );
      if (response.status < 200 || response.status >= 300) {
        throw GuideServiceException(
          type: response.status == 401 || response.status == 403
              ? GuideErrorType.authExpired
              : response.status >= 500
                  ? GuideErrorType.service
                  : GuideErrorType.unknown,
          message: '$functionName 调用失败: status=${response.status} data=${response.data}',
          statusCode: response.status,
        );
      }
      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['success'] == false) {
          throw GuideServiceException(
            type: GuideErrorType.service,
            message: '${data['error'] ?? '$functionName 返回失败'}',
          );
        }
        return data;
      }
      if (data is Map) {
        final casted = data.map((key, value) => MapEntry('$key', value));
        if (casted['success'] == false) {
          throw GuideServiceException(
            type: GuideErrorType.service,
            message: '${casted['error'] ?? '$functionName 返回失败'}',
          );
        }
        return casted;
      }
      throw const GuideServiceException(
        type: GuideErrorType.service,
        message: 'Agent 接口返回格式异常',
      );
    } on GuideServiceException {
      rethrow;
    } catch (e) {
      throw GuideServiceException(
        type: GuideErrorType.unknown,
        message: '$e',
      );
    }
  }

  static Map<String, dynamic> _parseMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return <String, dynamic>{};
  }

  static List<AgentStep> _parseSteps(Object? value) {
    if (value is! List) return const <AgentStep>[];
    return value
        .map((item) => _parseMap(item))
        .map(AgentStep.fromJson)
        .toList(growable: false);
  }
}
