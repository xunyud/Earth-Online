import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_auth_service.dart';

enum GuideErrorType {
  authExpired,
  network,
  service,
  unknown,
}

class GuideServiceException implements Exception {
  final GuideErrorType type;
  final String message;
  final int? statusCode;

  const GuideServiceException({
    required this.type,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => message;
}

class GuideSuggestedTask {
  final String title;
  final String description;
  final int xpReward;
  final String questTier;

  const GuideSuggestedTask({
    required this.title,
    required this.description,
    required this.xpReward,
    required this.questTier,
  });

  factory GuideSuggestedTask.fromMap(Map<String, dynamic> map) {
    final xpRaw = map['xp_reward'];
    final xp = xpRaw is num ? xpRaw.round() : int.tryParse('$xpRaw') ?? 20;
    final tierRaw = (map['quest_tier'] as String?)?.trim();
    final tier = switch (tierRaw) {
      'Main_Quest' => 'Main_Quest',
      'Side_Quest' => 'Side_Quest',
      _ => 'Daily',
    };
    return GuideSuggestedTask(
      title: (map['title'] as String?)?.trim() ?? '鎭㈠浠诲姟',
      description: (map['description'] as String?)?.trim() ?? '',
      xpReward: xp.clamp(5, 200),
      questTier: tier,
    );
  }
}

class GuideDailyEvent {
  final String eventId;
  final String title;
  final String description;
  final int rewardXp;
  final int rewardGold;
  final String status;
  final String reason;
  final List<String> memoryRefs;

  const GuideDailyEvent({
    required this.eventId,
    required this.title,
    required this.description,
    required this.rewardXp,
    required this.rewardGold,
    required this.status,
    required this.reason,
    required this.memoryRefs,
  });

  bool get isPending => status == 'generated';

  factory GuideDailyEvent.fromMap(Map<String, dynamic> map) {
    final xpRaw = map['reward_xp'];
    final goldRaw = map['reward_gold'];
    final refsRaw = map['memory_refs'];
    final refs = refsRaw is List
        ? refsRaw
            .map((item) => '$item')
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];
    return GuideDailyEvent(
      eventId: (map['event_id'] as String?)?.trim() ??
          (map['id'] as String?)?.trim() ??
          '',
      title: (map['title'] as String?)?.trim() ?? '鍦扮悆绐佸彂浜嬩欢',
      description: (map['description'] as String?)?.trim() ?? '',
      rewardXp: (xpRaw is num ? xpRaw.round() : int.tryParse('$xpRaw') ?? 0)
          .clamp(0, 9999),
      rewardGold:
          (goldRaw is num ? goldRaw.round() : int.tryParse('$goldRaw') ?? 0)
              .clamp(0, 999999),
      status: (map['status'] as String?)?.trim() ?? 'generated',
      reason: (map['reason'] as String?)?.trim() ?? '',
      memoryRefs: refs,
    );
  }
}

class GuideBootstrapResult {
  final String proactiveMessage;
  final GuideDailyEvent? dailyEvent;
  final String memoryDigest;
  final String traceId;
  final List<String> behaviorSignals;
  final List<String> memoryRefs;

  const GuideBootstrapResult({
    required this.proactiveMessage,
    required this.dailyEvent,
    required this.memoryDigest,
    required this.traceId,
    required this.behaviorSignals,
    required this.memoryRefs,
  });

  factory GuideBootstrapResult.fromMap(Map<String, dynamic> map) {
    final behaviorRaw = map['behavior_signals'];
    final refsRaw = map['memory_refs'];
    return GuideBootstrapResult(
      proactiveMessage: (map['proactive_message'] as String?)?.trim() ?? '',
      dailyEvent: map['daily_event'] is Map<String, dynamic>
          ? GuideDailyEvent.fromMap(map['daily_event'] as Map<String, dynamic>)
          : null,
      memoryDigest: (map['memory_digest'] as String?)?.trim() ?? '',
      traceId: (map['trace_id'] as String?)?.trim() ?? '',
      behaviorSignals: behaviorRaw is List
          ? behaviorRaw
              .map((item) => '$item')
              .where((item) => item.trim().isNotEmpty)
              .toList()
          : <String>[],
      memoryRefs: refsRaw is List
          ? refsRaw
              .map((item) => '$item')
              .where((item) => item.isNotEmpty)
              .toList()
          : <String>[],
    );
  }
}

enum GuideChatIntent {
  companion,
  advice,
  action,
}

GuideChatIntent _guideChatIntentFromRaw(dynamic value) {
  final text = value == null ? '' : '$value'.trim().toLowerCase();
  switch (text) {
    case 'action':
      return GuideChatIntent.action;
    case 'advice':
      return GuideChatIntent.advice;
    case 'companion':
    default:
      return GuideChatIntent.companion;
  }
}

class GuideMessageCard {
  final String label;
  final String content;

  const GuideMessageCard({
    required this.label,
    required this.content,
  });

  factory GuideMessageCard.fromMap(Map<String, dynamic> map) {
    return GuideMessageCard(
      label: (map['label'] as String?)?.trim() ?? '',
      content: (map['content'] as String?)?.trim() ?? '',
    );
  }
}

class GuideResultCard {
  final String label;
  final String title;
  final String description;

  const GuideResultCard({
    required this.label,
    required this.title,
    required this.description,
  });

  factory GuideResultCard.fromMap(Map<String, dynamic> map) {
    return GuideResultCard(
      label: (map['label'] as String?)?.trim() ?? '',
      title: (map['title'] as String?)?.trim() ?? '',
      description: (map['description'] as String?)?.trim() ?? '',
    );
  }
}

class GuideTaskEditDraft {
  final String taskId;
  final String taskTitle;
  final String action;
  final String updatedTitle;
  final String updatedDescription;
  final int? updatedXpReward;
  final List<String> subtasks;

  const GuideTaskEditDraft({
    required this.taskId,
    required this.taskTitle,
    required this.action,
    required this.updatedTitle,
    required this.updatedDescription,
    required this.updatedXpReward,
    required this.subtasks,
  });

  factory GuideTaskEditDraft.fromMap(Map<String, dynamic> map) {
    final subtasksRaw = map['subtasks'];
    final xpRaw = map['updated_xp_reward'];
    return GuideTaskEditDraft(
      taskId: (map['task_id'] as String?)?.trim() ?? '',
      taskTitle: (map['task_title'] as String?)?.trim() ?? '',
      action: (map['action'] as String?)?.trim() ?? '',
      updatedTitle: (map['updated_title'] as String?)?.trim() ?? '',
      updatedDescription: (map['updated_description'] as String?)?.trim() ?? '',
      updatedXpReward: xpRaw is num ? xpRaw.round() : int.tryParse('$xpRaw'),
      subtasks: subtasksRaw is List
          ? subtasksRaw
              .map((item) => '$item')
              .where((item) => item.trim().isNotEmpty)
              .toList()
          : const <String>[],
    );
  }
}

class GuideChatResult {
  final String reply;
  final GuideChatIntent intent;
  final List<String> quickActions;
  final GuideMessageCard? messageCard;
  final GuideResultCard? resultCard;
  final GuideSuggestedTask? suggestedTask;
  final GuideTaskEditDraft? taskEditDraft;
  final List<String> memoryRefs;

  const GuideChatResult({
    required this.reply,
    required this.intent,
    required this.quickActions,
    required this.messageCard,
    required this.resultCard,
    required this.suggestedTask,
    required this.taskEditDraft,
    required this.memoryRefs,
  });

  factory GuideChatResult.fromMap(Map<String, dynamic> map) {
    final actionsRaw = map['quick_actions'];
    final refsRaw = map['memory_refs'];
    final messageCardRaw = map['message_card'];
    final resultCardRaw = map['result_card'];
    final taskEditDraftRaw = map['task_edit_draft'];
    return GuideChatResult(
      reply: (map['reply'] as String?)?.trim() ?? '',
      intent: _guideChatIntentFromRaw(map['intent']),
      quickActions: actionsRaw is List
          ? actionsRaw
              .map((item) => '$item')
              .where((item) => item.trim().isNotEmpty)
              .toList()
          : const <String>[],
      messageCard: messageCardRaw is Map<String, dynamic>
          ? GuideMessageCard.fromMap(messageCardRaw)
          : messageCardRaw is Map
              ? GuideMessageCard.fromMap(
                  messageCardRaw.map((key, value) => MapEntry('$key', value)),
                )
              : null,
      resultCard: resultCardRaw is Map<String, dynamic>
          ? GuideResultCard.fromMap(resultCardRaw)
          : resultCardRaw is Map
              ? GuideResultCard.fromMap(
                  resultCardRaw.map((key, value) => MapEntry('$key', value)),
                )
              : null,
      suggestedTask: map['suggested_task'] is Map<String, dynamic>
          ? GuideSuggestedTask.fromMap(
              map['suggested_task'] as Map<String, dynamic>,
            )
          : null,
      taskEditDraft: taskEditDraftRaw is Map<String, dynamic>
          ? GuideTaskEditDraft.fromMap(taskEditDraftRaw)
          : taskEditDraftRaw is Map
              ? GuideTaskEditDraft.fromMap(
                  taskEditDraftRaw.map((key, value) => MapEntry('$key', value)),
                )
              : null,
      memoryRefs: refsRaw is List
          ? refsRaw
              .map((item) => '$item')
              .where((item) => item.isNotEmpty)
              .toList()
          : const <String>[],
    );
  }
}

class GuideNightReflectionResult {
  final String opening;
  final String followUpQuestion;
  final GuideSuggestedTask suggestedTask;
  final List<String> memoryRefs;

  const GuideNightReflectionResult({
    required this.opening,
    required this.followUpQuestion,
    required this.suggestedTask,
    required this.memoryRefs,
  });

  factory GuideNightReflectionResult.fromMap(Map<String, dynamic> map) {
    final refsRaw = map['memory_refs'];
    const fallbackTask = GuideSuggestedTask(
      title: '明日恢复支线：拉伸 10 分钟',
      description: '用短恢复动作降低明天的启动压力。',
      xpReward: 20,
      questTier: 'Daily',
    );
    return GuideNightReflectionResult(
      opening: (map['opening'] as String?)?.trim() ?? '',
      followUpQuestion: (map['follow_up_question'] as String?)?.trim() ?? '',
      suggestedTask: map['suggested_task'] is Map<String, dynamic>
          ? GuideSuggestedTask.fromMap(
              map['suggested_task'] as Map<String, dynamic>,
            )
          : fallbackTask,
      memoryRefs: refsRaw is List
          ? refsRaw
              .map((item) => '$item')
              .where((item) => item.isNotEmpty)
              .toList()
          : const <String>[],
    );
  }
}

class GuideEventAcceptResult {
  final bool accepted;
  final String? insertedQuestId;
  final int rewardXp;
  final int rewardGold;

  const GuideEventAcceptResult({
    required this.accepted,
    required this.insertedQuestId,
    required this.rewardXp,
    required this.rewardGold,
  });

  factory GuideEventAcceptResult.fromMap(Map<String, dynamic> map) {
    final reward = map['reward_preview'];
    final rewardMap =
        reward is Map<String, dynamic> ? reward : const <String, dynamic>{};
    final xpRaw = rewardMap['reward_xp'];
    final goldRaw = rewardMap['reward_gold'];
    return GuideEventAcceptResult(
      accepted: map['accepted'] == true,
      insertedQuestId: (map['inserted_quest_id'] as String?)?.trim(),
      rewardXp: (xpRaw is num ? xpRaw.round() : int.tryParse('$xpRaw') ?? 0)
          .clamp(0, 99999),
      rewardGold:
          (goldRaw is num ? goldRaw.round() : int.tryParse('$goldRaw') ?? 0)
              .clamp(0, 999999),
    );
  }
}

class GuidePortraitResult {
  final String imageUrl;
  final String model;
  final int seed;
  final String style;
  final String summary;
  final List<String> memoryRefs;
  final String traceId;

  const GuidePortraitResult({
    required this.imageUrl,
    required this.model,
    required this.seed,
    required this.style,
    required this.summary,
    required this.memoryRefs,
    required this.traceId,
  });

  factory GuidePortraitResult.fromMap(Map<String, dynamic> map) {
    final wrapped = _castStringDynamicMap(map['data']);
    final refsRaw = map['memory_refs'] ?? wrapped['memory_refs'];
    final seedRaw = map['seed'] ?? wrapped['seed'];
    return GuidePortraitResult(
      imageUrl: _firstNonEmptyText(
        [
          map['image_url'],
          map['imageUrl'],
          map['url'],
          wrapped['image_url'],
          wrapped['imageUrl'],
          wrapped['url']
        ],
      ),
      model: _firstNonEmptyText([map['model'], wrapped['model']],
          fallback: 'flux'),
      seed: seedRaw is num ? seedRaw.round() : int.tryParse('$seedRaw') ?? -1,
      style: _firstNonEmptyText([map['style'], wrapped['style']],
          fallback: 'pencil_sketch'),
      summary: _firstNonEmptyText([map['summary'], wrapped['summary']]),
      traceId: _firstNonEmptyText([
        map['trace_id'],
        map['traceId'],
        wrapped['trace_id'],
        wrapped['traceId']
      ]),
      memoryRefs: refsRaw is List
          ? refsRaw
              .map((item) => '$item')
              .where((item) => item.trim().isNotEmpty)
              .toList()
          : const <String>[],
    );
  }
}

String _firstNonEmptyText(List<dynamic> values, {String fallback = ''}) {
  for (final value in values) {
    final text = value == null ? '' : '$value'.trim();
    if (text.isNotEmpty) {
      return text;
    }
  }
  return fallback;
}

Map<String, dynamic> _castStringDynamicMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return const <String, dynamic>{};
}

class GuideService {
  GuideService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  String? _normalizeDisplayName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<String?> resolveDisplayName({String? localFallback}) async {
    final normalizedLocal = _normalizeDisplayName(localFallback);
    final userId =
        SupabaseAuthService.instance.getCurrentUserId()?.trim() ?? '';
    if (userId.isEmpty) {
      return normalizedLocal;
    }

    try {
      final row = await _supabase
          .from('guide_user_settings')
          .upsert({
            'user_id': userId,
            if (normalizedLocal != null) 'display_name': normalizedLocal,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'user_id')
          .select('display_name')
          .single();
      final serverValue = _normalizeDisplayName(row['display_name'] as String?);
      return serverValue ?? normalizedLocal;
    } catch (_) {
      return normalizedLocal;
    }
  }

  Future<void> saveDisplayName(String? value) async {
    final userId =
        SupabaseAuthService.instance.getCurrentUserId()?.trim() ?? '';
    if (userId.isEmpty) return;

    await _supabase.from('guide_user_settings').upsert({
      'user_id': userId,
      'display_name': _normalizeDisplayName(value),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }

  Future<GuideBootstrapResult> bootstrap({String scene = 'home'}) async {
    final data = await _invoke('guide-bootstrap', body: {'scene': scene});
    return GuideBootstrapResult.fromMap(data);
  }

  Future<GuideChatResult> chat({
    required String message,
    String scene = 'home',
    Map<String, dynamic>? clientContext,
  }) async {
    final body = <String, dynamic>{
      'message': message,
      'scene': scene,
    };
    if (clientContext != null && clientContext.isNotEmpty) {
      body['client_context'] = clientContext;
    }
    final data = await _invoke('guide-chat', body: body);
    return GuideChatResult.fromMap(data);
  }

  Future<GuideNightReflectionResult> nightReflection({
    String? dayId,
    String? uploadRequestId,
  }) async {
    final body = <String, dynamic>{};
    if (dayId != null && dayId.trim().isNotEmpty) {
      body['day_id'] = dayId.trim();
    }
    if (uploadRequestId != null && uploadRequestId.trim().isNotEmpty) {
      body['upload_request_id'] = uploadRequestId.trim();
    }
    final data = await _invoke('guide-night-reflection', body: body);
    return GuideNightReflectionResult.fromMap(data);
  }

  Future<GuideDailyEvent> generateEvent({String scene = 'home'}) async {
    final data = await _invoke('guide-event-generate', body: {'scene': scene});
    return GuideDailyEvent.fromMap(data);
  }

  Future<GuideEventAcceptResult> acceptEvent({
    required String eventId,
    required bool accept,
  }) async {
    final data = await _invoke(
      'guide-event-accept',
      body: {
        'event_id': eventId,
        'accept': accept,
      },
    );
    return GuideEventAcceptResult.fromMap(data);
  }

  Future<GuidePortraitResult> generatePortrait({
    String scene = 'profile',
    String style = 'pencil_sketch',
    bool forceRefresh = true,
  }) async {
    final data = await _invoke(
      'guide-portrait-generate',
      body: {
        'scene': scene,
        'style': style,
        'force_refresh': forceRefresh,
      },
    );
    return GuidePortraitResult.fromMap(data);
  }

  Future<Map<String, dynamic>> _invoke(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    final accessToken =
        await SupabaseAuthService.instance.getValidAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw const GuideServiceException(
        type: GuideErrorType.authExpired,
        message: '鐢ㄦ埛浼氳瘽宸插け鏁堬紝璇烽噸鏂扮櫥褰曞悗閲嶈瘯',
      );
    }
    try {
      final response = await _supabase.functions.invoke(
        functionName,
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
        body: body ?? const <String, dynamic>{},
      );
      if (response.status < 200 || response.status >= 300) {
        final status = response.status;
        final message =
            '$functionName 璋冪敤澶辫触: status=$status data=${response.data}';
        if (status == 401 || status == 403) {
          throw GuideServiceException(
            type: GuideErrorType.authExpired,
            message: message,
            statusCode: status,
          );
        }
        if (status >= 500) {
          throw GuideServiceException(
            type: GuideErrorType.service,
            message: message,
            statusCode: status,
          );
        }
        throw GuideServiceException(
          type: GuideErrorType.unknown,
          message: message,
          statusCode: status,
        );
      }
      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['success'] == false) {
          final errorText = '${data['error'] ?? '$functionName 杩斿洖澶辫触'}';
          throw GuideServiceException(
            type: _inferErrorType(errorText),
            message: errorText,
          );
        }
        return data;
      }
      if (data is Map) {
        final casted = data.map(
          (key, value) => MapEntry('$key', value),
        );
        if (casted['success'] == false) {
          final errorText = '${casted['error'] ?? '$functionName 杩斿洖澶辫触'}';
          throw GuideServiceException(
            type: _inferErrorType(errorText),
            message: errorText,
          );
        }
        return casted;
      }
      throw GuideServiceException(
        type: GuideErrorType.service,
        message: '$functionName 杩斿洖鏍煎紡寮傚父',
      );
    } on GuideServiceException {
      rethrow;
    } catch (e) {
      final message = '$e';
      throw GuideServiceException(
        type: _inferErrorType(message),
        message: message,
      );
    }
  }

  GuideErrorType _inferErrorType(String message) {
    final text = message.toLowerCase();
    if (text.contains('jwt') ||
        text.contains('session') ||
        text.contains('unauthorized') ||
        text.contains('forbidden') ||
        text.contains('401') ||
        text.contains('403')) {
      return GuideErrorType.authExpired;
    }
    if (text.contains('socket') ||
        text.contains('network') ||
        text.contains('timeout') ||
        text.contains('connection') ||
        text.contains('dns')) {
      return GuideErrorType.network;
    }
    if (text.contains('500') ||
        text.contains('502') ||
        text.contains('503') ||
        text.contains('504')) {
      return GuideErrorType.service;
    }
    return GuideErrorType.unknown;
  }
}
