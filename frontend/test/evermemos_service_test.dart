import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/evermemos_service.dart';
import 'package:frontend/features/quest/models/quest_node.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    originalDebugPrint = debugPrint;
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
  });

  test('syncTodayCompletedQuests 请求体包含 EverMemOS 必填字段', () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{"ok":true}', 200);
    });
    final service = EvermemosService(
      client: client,
      currentUserIdProvider: () => 'user_123',
    );

    await service.syncTodayCompletedQuests([
      _buildCompletedQuest(),
    ]);

    expect(requestBody['message_id'], isA<String>());
    expect((requestBody['message_id'] as String).isNotEmpty, isTrue);
    expect(requestBody['create_time'], isA<String>());
    final createTime = requestBody['create_time'] as String;
    expect(createTime, contains(RegExp(r'(Z|[+-]\d{2}:\d{2})$')));
    expect(requestBody['sender'], 'user_123');
    expect(requestBody.containsKey('sennder'), isFalse);
    expect(requestBody['group_id'], 'quest-log:user_123');
  });

  test('syncTodayCompletedQuests 会组装所有今日已完成任务', () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{"ok":true}', 200);
    });
    final service = EvermemosService(
      client: client,
      currentUserIdProvider: () => 'user_123',
    );
    final quests = <QuestNode>[
      _buildCompletedQuestWith(id: 'q_a', title: '开发小程序'),
      _buildCompletedQuestWith(id: 'q_b', title: '编写100行代码'),
    ];

    final result = await service.syncTodayCompletedQuests(quests);

    final content = (requestBody['content'] as String?) ?? '';
    expect(content, contains('开发小程序'));
    expect(content, contains('编写100行代码'));
    expect(result.syncedCount, 2);
  });

  test('syncTodayCompletedQuests 只上传今日未上传的新完成任务', () async {
    final postedBodies = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      postedBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response('{"ok":true}', 200);
    });
    final service = EvermemosService(
      client: client,
      currentUserIdProvider: () => 'user_123',
    );
    final q1 = _buildCompletedQuestWith(id: 'q_1', title: '任务A');
    final q2 = _buildCompletedQuestWith(id: 'q_2', title: '任务B');
    final q3 = _buildCompletedQuestWith(id: 'q_3', title: '任务C');

    final first = await service.syncTodayCompletedQuests([q1, q2]);
    final second = await service.syncTodayCompletedQuests([q1, q2, q3]);

    expect(postedBodies.length, 2);
    final firstContent = postedBodies[0]['content'] as String;
    final secondContent = postedBodies[1]['content'] as String;
    expect(firstContent, contains('任务A'));
    expect(firstContent, contains('任务B'));
    expect(secondContent, contains('任务C'));
    expect(secondContent.contains('任务A'), isFalse);
    expect(secondContent.contains('任务B'), isFalse);
    expect(first.syncedCount, 2);
    expect(second.syncedCount, 1);
  });

  test('syncTodayCompletedQuests 成功时打印 EverMemOS 返回体', () async {
    final logs = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };

    final client = MockClient((request) async {
      return http.Response('{"status":"queued","request_id":"r1"}', 200);
    });
    final service = EvermemosService(
      client: client,
      currentUserIdProvider: () => 'user_123',
    );

    await service.syncTodayCompletedQuests([_buildCompletedQuest()]);

    expect(logs.any((line) => line.contains('EverMemOS')), isTrue);
    expect(logs.any((line) => line.contains('发送的Payload')), isTrue);
    expect(logs.any((line) => line.contains('"request_id":"r1"')), isTrue);
  });

  test('syncTodayCompletedQuests 失败时也打印 EverMemOS 返回体', () async {
    final logs = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };

    final client = MockClient((request) async {
      return http.Response('{"code":"InvalidParameter"}', 400);
    });
    final service = EvermemosService(
      client: client,
      currentUserIdProvider: () => 'user_123',
    );

    await expectLater(
      () => service.syncTodayCompletedQuests([_buildCompletedQuest()]),
      throwsA(isA<EvermemosSyncException>()),
    );

    expect(logs.any((line) => line.contains('EverMemOS')), isTrue);
    expect(logs.any((line) => line.contains('"InvalidParameter"')), isTrue);
  });

  test('syncTodayCompletedQuests 返回 202 queued 时保留 request_id 供后续轮询', () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"message":"Message accepted and queued for processing","request_id":"req_123","status":"queued"}',
        202,
      );
    });
    final service = EvermemosService(
      client: client,
      currentUserIdProvider: () => 'user_123',
    );

    final result =
        await service.syncTodayCompletedQuests([_buildCompletedQuest()]);

    expect(result.httpStatusCode, 202);
    expect(result.requestId, 'req_123');
    expect(result.status, 'queued');
    expect(result.isQueued, isTrue);
  });

  test('checkMemoryStatus 调用状态接口并附带 request_id 查询参数', () async {
    late Uri requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        '{"success":true,"found":true,"data":{"request_id":"req_1","status":"success"}}',
        200,
      );
    });
    final service = EvermemosService(
      client: client,
      currentUserIdProvider: () => 'user_123',
    );

    final status = await service.checkMemoryStatus('req_1');

    expect(requestedUri.path, '/api/v0/status/request');
    expect(requestedUri.queryParameters['request_id'], 'req_1');
    expect(status.requestId, 'req_1');
    expect(status.status, 'success');
    expect(status.isTerminal, isTrue);
  });

  test('pollMemoryStatus 在状态变为 success 前持续轮询', () async {
    var statusCallCount = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/status/request')) {
        statusCallCount++;
        if (statusCallCount == 1) {
          return http.Response(
            '{"success":true,"found":true,"data":{"request_id":"req_2","status":"queued"}}',
            200,
          );
        }
        return http.Response(
          '{"success":true,"found":true,"data":{"request_id":"req_2","status":"success"}}',
          200,
        );
      }
      if (request.url.path.endsWith('/memories')) {
        return http.Response(
          '{"success":true,"result":{"memories":[{"content":"latest diary","create_time":"2026-03-12T01:00:00Z"}]}}',
          200,
        );
      }
      return http.Response('{"success":false}', 404);
    });
    final service = EvermemosService(
      client: client,
      currentUserIdProvider: () => 'user_123',
    );

    final finalStatus = await service.pollMemoryStatus(
      'req_2',
      maxAttempts: 3,
      interval: Duration.zero,
    );

    expect(statusCallCount, 2);
    expect(finalStatus.status, 'success');
    expect(finalStatus.isTerminal, isTrue);
    expect(finalStatus.latestMemoryText, 'latest diary');
  });

  test('fetchMemoriesForCurrentUser 携带过滤参数并解析最新记忆', () async {
    late Uri requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        '{"code":0,"result":{"memories":[{"content":"older memory","create_time":"2026-03-11T20:00:00Z"},{"content":"latest memory text","create_time":"2026-03-12T01:00:00Z"}]}}',
        200,
      );
    });
    final service = EvermemosService(
      client: client,
      currentUserIdProvider: () => 'user_123',
    );

    final result = await service.fetchMemoriesForCurrentUser();

    expect(requestedUri.path, '/api/v0/memories');
    expect(requestedUri.queryParameters['group_ids'], 'quest-log:user_123');
    expect(requestedUri.queryParameters.length, 1);
    expect(requestedUri.queryParameters['sender'], isNull);
    expect(requestedUri.queryParameters['sennder'], isNull);
    expect(result.latestText, 'latest memory text');
    expect(result.memories.length, 2);
  });

  test('fetchMemoriesForCurrentUser 在 group_ids 被拒绝时降级 user_id', () async {
    final requestedUris = <Uri>[];
    final client = MockClient((request) async {
      requestedUris.add(request.url);
      if (requestedUris.length == 1) {
        return http.Response(
          '{"status":"failed","message":"At least one of user_id or group_ids must be specified"}',
          400,
        );
      }
      return http.Response(
        '{"result":{"memories":[{"content":"fallback memory","create_time":"2026-03-12T02:00:00Z"}]}}',
        200,
      );
    });
    final service = EvermemosService(
      client: client,
      currentUserIdProvider: () => 'user_123',
    );

    final result = await service.fetchMemoriesForCurrentUser();

    expect(requestedUris.length, 2);
    expect(requestedUris[0].path, '/api/v0/memories');
    expect(requestedUris[0].queryParameters['group_ids'], 'quest-log:user_123');
    expect(requestedUris[1].path, '/api/v0/memories');
    expect(requestedUris[1].queryParameters['user_id'], 'user_123');
    expect(result.latestText, 'fallback memory');
  });

  test('generateUserProfile 基于 memories 生成分数标签和建议', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/memories')) {
        return http.Response(
          '{"result":{"memories":[{"content":"finished study plan and reviewed","create_time":"2026-03-10T09:00:00Z"},{"content":"synced project progress and pushed release","create_time":"2026-03-11T10:00:00Z"},{"content":"took a walk after finishing tasks","create_time":"2026-03-12T11:00:00Z"}]}}',
          200,
        );
      }
      return http.Response('{"success":false}', 404);
    });
    final service = EvermemosService(
      client: client,
      currentUserIdProvider: () => 'user_123',
    );

    final profile = await service.generateUserProfile();

    expect(profile.userId, 'user_123');
    expect(profile.memoryCount, 3);
    expect(profile.tags, isNotEmpty);
    expect(profile.summary, isNotEmpty);
    expect(profile.suggestions, isNotEmpty);
    expect(profile.recentMemories, isNotEmpty);
    expect(profile.recentMemories.first.summary, isNotEmpty);
    expect(profile.recentMemories.first.displayTime, isNotEmpty);
    for (final key in EvermemosUserProfileReport.dimensionOrder) {
      expect(profile.scores.containsKey(key), isTrue);
      expect(profile.scores[key]! >= 20, isTrue);
      expect(profile.scores[key]! <= 95, isTrue);
    }
  });

  test('buildUserProfileFromMemories 在空样本时返回默认画像', () {
    final service = EvermemosService(
      client: MockClient((_) async => http.Response('{}', 200)),
      currentUserIdProvider: () => 'user_123',
    );

    final profile = service.buildUserProfileFromMemories(
      userId: 'user_123',
      memories: const [],
    );

    expect(profile.memoryCount, 0);
    expect(profile.tags, isNotEmpty);
    expect(profile.summary, contains('样本不足'));
    expect(profile.recentMemories, isEmpty);
  });

  test('syncTodayCompletedQuests 获取不到当前用户ID时抛出异常', () async {
    final service = EvermemosService(
      client: MockClient((_) async => http.Response('{}', 200)),
      currentUserIdProvider: () => null,
    );

    await expectLater(
      () => service.syncTodayCompletedQuests([_buildCompletedQuest()]),
      throwsA(isA<EvermemosSyncException>()),
    );
  });
}

QuestNode _buildCompletedQuest() {
  return _buildCompletedQuestWith(id: 'q1', title: '完成联调');
}

QuestNode _buildCompletedQuestWith({
  required String id,
  required String title,
  String? description,
}) {
  return QuestNode(
    id: id,
    userId: 'u1',
    title: title,
    description: description,
    questTier: 'Daily',
    isCompleted: true,
    completedAt: DateTime.now(),
    xpReward: 10,
    createdAt: DateTime.now(),
  );
}
