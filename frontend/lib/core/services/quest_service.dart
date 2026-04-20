import 'dart:async';
import 'dart:io';

import 'package:http/http.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../i18n/app_locale_controller.dart';
import 'supabase_auth_service.dart';
import '../../features/quest/models/quest_node.dart';

class ParseQuestSpec {
  final String title;
  final int? parentIndex;
  final int xpReward;

  const ParseQuestSpec({
    required this.title,
    required this.parentIndex,
    required this.xpReward,
  });

  factory ParseQuestSpec.fromJson(Map<String, dynamic> json) {
    final rawTitle = (json['title'] as String?)?.trim() ?? '';
    final rawParent = json['parent_index'];
    final rawXp = json['xpReward'];

    final parentIndex = rawParent is int ? rawParent : null;
    final xp = rawXp is num ? rawXp.round() : 20;

    return ParseQuestSpec(
      title: rawTitle,
      parentIndex: parentIndex,
      xpReward: xp,
    );
  }
}

class ParseQuestResult {
  final List<ParseQuestSpec> quests;
  final String cheer;

  const ParseQuestResult({required this.quests, required this.cheer});
}

class ParseQuestFunctionResult {
  final int status;
  final dynamic data;

  const ParseQuestFunctionResult({
    required this.status,
    this.data,
  });
}

typedef ParseQuestInvoker = Future<ParseQuestFunctionResult> Function({
  required String accessToken,
  required Map<String, dynamic> body,
});

class QuestService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<ParseQuestResult> parseQuest(
    String text,
    String userId, {
    ParseQuestInvoker? invoker,
    String? accessTokenOverride,
    Duration retryDelay = const Duration(milliseconds: 350),
  }) async {
    final accessToken = accessTokenOverride ??
        await SupabaseAuthService.instance.getValidAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception(AppLocaleController.instance.t('quest.parse.auth_retry'));
    }

    final body = <String, dynamic>{
      'text': text,
      'user_id': userId,
    };
    final execute = invoker ?? _invokeParseQuest;

    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await execute(
          accessToken: accessToken,
          body: body,
        );

        if (response.status != 200) {
          throw Exception(
            'Failed to parse quest: ${response.status}, data: ${response.data}',
          );
        }

        final data = response.data;
        if (data is! Map) {
          throw Exception('Invalid parse-quest response');
        }

        final cheer = (data['cheer'] as String?)?.trim() ?? '';
        final tasksRaw = data['tasks'];
        if (tasksRaw is! List) {
          throw Exception('Invalid parse-quest tasks');
        }

        final quests = tasksRaw
            .whereType<Map>()
            .map((e) => ParseQuestSpec.fromJson(e.cast<String, dynamic>()))
            .toList();

        return ParseQuestResult(
          quests: quests,
          cheer: cheer.isEmpty
              ? AppLocaleController.instance.t('quest.parse.default_cheer')
              : cheer,
        );
      } catch (error) {
        lastError = error;
        if (!_shouldRetryParseQuestError(error) || attempt == 1) {
          break;
        }
        if (retryDelay > Duration.zero) {
          await Future<void>.delayed(retryDelay);
        }
      }
    }

    final fallback = _buildFallbackParseQuestResult(text);
    if (fallback != null) {
      return fallback;
    }

    if (_shouldRetryParseQuestError(lastError)) {
      throw Exception(AppLocaleController.instance.t('quest.parse.network_retry'));
    }
    throw Exception(
      AppLocaleController.instance
          .t('quest.parse.failed', params: {'error': '$lastError'}),
    );
  }

  static ParseQuestResult? _buildFallbackParseQuestResult(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return null;
    return ParseQuestResult(
      quests: <ParseQuestSpec>[
        ParseQuestSpec(
          title: normalized,
          parentIndex: null,
          xpReward: 20,
        ),
      ],
      cheer: AppLocaleController.instance.t('quest.parse.default_cheer'),
    );
  }

  static Future<ParseQuestFunctionResult> _invokeParseQuest({
    required String accessToken,
    required Map<String, dynamic> body,
  }) async {
    final response = await _supabase.functions.invoke(
      'parse-quest',
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
      body: body,
    );
    return ParseQuestFunctionResult(
      status: response.status,
      data: response.data,
    );
  }

  static bool _shouldRetryParseQuestError(Object? error) {
    if (error is SocketException || error is ClientException) {
      return true;
    }
    final text = '$error'.toLowerCase();
    return text.contains('socketexception') ||
        text.contains('connection failed') ||
        text.contains('errno = 10055');
  }

  static List<QuestNode> buildTree(List<QuestNode> flatList) {
    final nodeMap = <String, QuestNode>{};
    final roots = <QuestNode>[];

    for (final node in flatList) {
      node.children = [];
      nodeMap[node.id] = node;
    }

    for (final node in flatList) {
      if (node.parentId != null) {
        if (nodeMap.containsKey(node.parentId)) {
          nodeMap[node.parentId]!.children.add(node);
        }
      } else {
        roots.add(node);
      }
    }

    return roots;
  }
}
