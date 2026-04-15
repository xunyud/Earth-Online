import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/quest/models/quest_node.dart';
import '../config/app_config.dart';
import '../i18n/app_locale_controller.dart';

class EvermemosSyncResult {
  final int syncedCount;
  final String content;
  final int httpStatusCode;
  final String? requestId;
  final String? status;

  const EvermemosSyncResult({
    required this.syncedCount,
    required this.content,
    required this.httpStatusCode,
    this.requestId,
    this.status,
  });

  bool get isQueued => status == 'queued' || httpStatusCode == 202;
}

class EvermemosRequestStatusResult {
  final String requestId;
  final String status;
  final Map<String, dynamic> rawBody;
  final Map<String, dynamic>? data;
  final EvermemosMemoryFetchResult? memoryFetchResult;

  const EvermemosRequestStatusResult({
    required this.requestId,
    required this.status,
    required this.rawBody,
    this.data,
    this.memoryFetchResult,
  });

  bool get isTerminal {
    final normalized = status.toLowerCase();
    return normalized == 'success' ||
        normalized == 'completed' ||
        normalized == 'failed' ||
        normalized == 'error' ||
        normalized == 'cancelled';
  }

  bool get isSuccess {
    final normalized = status.toLowerCase();
    return normalized == 'success' || normalized == 'completed';
  }

  String? get latestMemoryText => memoryFetchResult?.latestText;

  EvermemosRequestStatusResult copyWith({
    EvermemosMemoryFetchResult? memoryFetchResult,
  }) {
    return EvermemosRequestStatusResult(
      requestId: requestId,
      status: status,
      rawBody: rawBody,
      data: data,
      memoryFetchResult: memoryFetchResult ?? this.memoryFetchResult,
    );
  }
}

class EvermemosMemoryFetchResult {
  final String userId;
  final String groupId;
  final Map<String, dynamic> rawBody;
  final List<Map<String, dynamic>> memories;
  final Map<String, dynamic>? latestMemory;
  final String? latestText;

  const EvermemosMemoryFetchResult({
    required this.userId,
    required this.groupId,
    required this.rawBody,
    required this.memories,
    this.latestMemory,
    this.latestText,
  });
}

class EvermemosMemorySnippet {
  final String summary;
  final String content;
  final DateTime? timestamp;
  final String displayTime;

  const EvermemosMemorySnippet({
    required this.summary,
    required this.content,
    required this.timestamp,
    required this.displayTime,
  });
}

class EvermemosUserProfileReport {
  static const List<String> dimensionOrder = <String>[
    'execution',
    'consistency',
    'growth',
    'wellbeing',
    'social',
  ];

  final String userId;
  final int memoryCount;
  final Map<String, double> scores;
  final List<String> tags;
  final String summary;
  final List<String> strengths;
  final List<String> suggestions;
  final List<String> highlights;
  final List<EvermemosMemorySnippet> recentMemories;

  const EvermemosUserProfileReport({
    required this.userId,
    required this.memoryCount,
    required this.scores,
    required this.tags,
    required this.summary,
    required this.strengths,
    required this.suggestions,
    required this.highlights,
    required this.recentMemories,
  });
}

class EvermemosService {
  EvermemosService({
    http.Client? client,
    String? Function()? currentUserIdProvider,
  })  : _client = client ?? http.Client(),
        _currentUserIdProvider = currentUserIdProvider ??
            (() => Supabase.instance.client.auth.currentUser?.id);

  final http.Client _client;
  final Random _random = Random();
  final String? Function() _currentUserIdProvider;
  final Set<String> _uploadedQuestIdsToday = <String>{};
  String? _uploadedQuestDayKey;

  bool get _isEnglish => AppLocaleController.instance.isEnglish;

  String _txt(String zh, String en) => _isEnglish ? en : zh;

  void dispose() {
    _client.close();
  }

  Future<EvermemosSyncResult> syncTodayCompletedQuests(
    List<QuestNode> quests,
  ) async {
    final todayCompleted = _extractTodayCompletedQuests(quests);
    if (todayCompleted.isEmpty) {
      throw EvermemosSyncException(
        _txt(
          '今天还没有已完成任务可供上传。',
          'There are no completed quests from today to upload yet.',
        ),
      );
    }
    _resetUploadedQuestCacheIfNeeded();
    final unsyncedTodayCompleted = todayCompleted
        .where((quest) => !_uploadedQuestIdsToday.contains(quest.id))
        .toList();
    if (unsyncedTodayCompleted.isEmpty) {
      throw EvermemosSyncException(
        _txt(
          '今天的新完成任务都已上传，无需重复上传。',
          'All newly completed quests from today were already uploaded.',
        ),
      );
    }
    final userId = _currentUserIdProvider()?.trim() ?? '';
    if (userId.isEmpty) {
      throw EvermemosSyncException(
        _txt(
          '未检测到当前登录用户，禁止上传无主记忆。',
          'No signed-in user was found, so orphan memories cannot be uploaded.',
        ),
      );
    }

    debugPrint(
      '🧠 今日待上传任务(${unsyncedTodayCompleted.length}): ${unsyncedTodayCompleted.map((q) => q.title).join('、')}',
    );

    final content = _buildMemoryContent(unsyncedTodayCompleted);
    final uri = Uri.parse('${AppConfig.evermemosBaseUrl}/memories');
    final payload = <String, dynamic>{
      'content': content,
      'message_id': _generateMessageId(),
      'create_time': _createTimeIso8601(),
      'sender': userId,
      // group_id acts as namespace to isolate memories per user.
      'group_id': 'quest-log:$userId',
      'group_name': 'Quest Log - $userId',
    };
    debugPrint('🧠 发送的Payload: ${jsonEncode(payload)}');

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConfig.evermemosApiKey}',
      },
      body: jsonEncode(payload),
    );

    debugPrint('🧠 EverMemOS 响应状态码: ${response.statusCode}');
    debugPrint('🧠 EverMemOS 完整返回体: ${response.body}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EvermemosSyncException(
        _txt(
          '上传失败 (${response.statusCode})：${response.body}',
          'Upload failed (${response.statusCode}): ${response.body}',
        ),
      );
    }

    final decodedBody = _tryDecodeJsonObject(response.body);
    _uploadedQuestIdsToday.addAll(unsyncedTodayCompleted.map((q) => q.id));

    return EvermemosSyncResult(
      syncedCount: unsyncedTodayCompleted.length,
      content: content,
      httpStatusCode: response.statusCode,
      requestId: decodedBody?['request_id'] as String?,
      status: decodedBody?['status'] as String?,
    );
  }

  Future<EvermemosRequestStatusResult> checkMemoryStatus(
      String requestId) async {
    final uri =
        Uri.parse('${AppConfig.evermemosBaseUrl}/status/request').replace(
      queryParameters: {'request_id': requestId},
    );

    debugPrint('🔎 EverMemOS 状态探路 GET: $uri');
    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer ${AppConfig.evermemosApiKey}',
      },
    );

    debugPrint('🔎 EverMemOS 状态查询响应码: ${response.statusCode}');
    debugPrint('🔎 EverMemOS 状态查询返回体: ${response.body}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EvermemosSyncException(
        _txt(
          '状态查询失败 (${response.statusCode})：${response.body}',
          'Status check failed (${response.statusCode}): ${response.body}',
        ),
      );
    }

    final body = _tryDecodeJsonObject(response.body);
    final data = body?['data'];
    final dataMap = data is Map<String, dynamic> ? data : null;
    final status =
        (dataMap?['status'] ?? body?['status'] ?? 'unknown').toString();
    final foundRequestId =
        (dataMap?['request_id'] ?? body?['request_id'] ?? requestId).toString();

    return EvermemosRequestStatusResult(
      requestId: foundRequestId,
      status: status,
      rawBody: body ?? const {},
      data: dataMap,
    );
  }

  Future<EvermemosRequestStatusResult> pollMemoryStatus(
    String requestId, {
    int maxAttempts = 10,
    Duration interval = const Duration(seconds: 2),
  }) async {
    EvermemosRequestStatusResult? lastStatus;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      debugPrint(
          '🔁 EverMemOS 轮询 attempt=$attempt/$maxAttempts request_id=$requestId');
      final current = await checkMemoryStatus(requestId);
      lastStatus = current;
      if (current.isTerminal) {
        if (current.isSuccess) {
          try {
            final memoryFetchResult = await fetchMemoriesForCurrentUser();
            return current.copyWith(memoryFetchResult: memoryFetchResult);
          } catch (e) {
            debugPrint('⚠️ EverMemOS 任务成功但拉取记忆失败: $e');
          }
        }
        return current;
      }
      if (attempt < maxAttempts) {
        await Future<void>.delayed(interval);
      }
    }

    if (lastStatus != null) {
      return lastStatus;
    }

    throw EvermemosSyncException(
      _txt(
        '状态轮询失败：未获取到有效返回。',
        'Status polling failed: no valid response was received.',
      ),
    );
  }

  Future<EvermemosMemoryFetchResult> fetchMemoriesForCurrentUser() async {
    final userId = _currentUserIdProvider()?.trim() ?? '';
    if (userId.isEmpty) {
      throw EvermemosSyncException(
        _txt(
          '未检测到当前登录用户，无法拉取记忆。',
          'No signed-in user was found, so memories cannot be fetched.',
        ),
      );
    }

    final groupId = 'quest-log:$userId';
    final uri = Uri.parse('${AppConfig.evermemosBaseUrl}/memories').replace(
      queryParameters: {
        // EverMemOS requires at least one of user_id or group_ids.
        // We use group_ids as the per-user namespace filter.
        'group_ids': groupId,
      },
    );
    final fallbackUri =
        Uri.parse('${AppConfig.evermemosBaseUrl}/memories').replace(
      queryParameters: {
        // Fallback path for deployments that only accept user_id.
        'user_id': userId,
      },
    );

    debugPrint('📖 EverMemOS 拉取记忆 GET: $uri');
    var response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer ${AppConfig.evermemosApiKey}',
      },
    );

    debugPrint('📖 EverMemOS 拉取响应码: ${response.statusCode}');
    debugPrint('📖 拉取真实记忆结果: ${response.body}');

    if (response.statusCode == 400 &&
        _isMissingFilterValidationError(response.body)) {
      debugPrint('⚠️ group_ids 查询被拒绝，降级使用 user_id 继续拉取。');
      debugPrint('📖 EverMemOS 拉取记忆 GET (fallback): $fallbackUri');
      response = await _client.get(
        fallbackUri,
        headers: {
          'Authorization': 'Bearer ${AppConfig.evermemosApiKey}',
        },
      );
      debugPrint('📖 EverMemOS 拉取响应码 (fallback): ${response.statusCode}');
      debugPrint('📖 拉取真实记忆结果 (fallback): ${response.body}');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EvermemosSyncException(
        _txt(
          '拉取记忆失败 (${response.statusCode})：${response.body}',
          'Memory fetch failed (${response.statusCode}): ${response.body}',
        ),
      );
    }

    final body =
        _tryDecodeJsonObject(response.body) ?? const <String, dynamic>{};
    final memories = _extractMemories(body);
    final latestMemory = _pickLatestMemory(memories);
    final latestText = _extractMemoryText(latestMemory);

    return EvermemosMemoryFetchResult(
      userId: userId,
      groupId: groupId,
      rawBody: body,
      memories: memories,
      latestMemory: latestMemory,
      latestText: latestText,
    );
  }

  Future<EvermemosUserProfileReport> generateUserProfile() async {
    final fetched = await fetchMemoriesForCurrentUser();
    return buildUserProfileFromMemories(
      userId: fetched.userId,
      memories: fetched.memories,
    );
  }

  EvermemosUserProfileReport buildUserProfileFromMemories({
    required String userId,
    required List<Map<String, dynamic>> memories,
  }) {
    if (memories.isEmpty) {
      return EvermemosUserProfileReport(
        userId: userId,
        memoryCount: 0,
        scores: const <String, double>{
          'execution': 50,
          'consistency': 50,
          'growth': 50,
          'wellbeing': 50,
          'social': 50,
        },
        tags: <String>[
          _txt('等待记录积累', 'Waiting for More Memories'),
          _txt('初始探索者', 'Early Explorer'),
        ],
        summary: _txt(
          '当前记忆样本不足，先记录几条今天的真实行动，画像会越来越准确。',
          'There are not enough memory samples yet. Record a few real actions from today and the portrait will become more accurate.',
        ),
        strengths: <String>[
          _txt('建议先连续记录 3 天再生成完整画像。', 'Record for 3 days first before generating a full portrait.'),
        ],
        suggestions: <String>[
          _txt(
            '每天至少上传 1 条记忆，优先记录“完成了什么”和“为什么做”。',
            'Upload at least one memory each day, focusing on what you finished and why you did it.',
          ),
          _txt(
            '任务完成后补一句感受，画像会更快识别你的节奏。',
            'Add one line about how it felt after finishing a quest so the portrait can learn your rhythm faster.',
          ),
        ],
        highlights: const <String>[],
        recentMemories: const <EvermemosMemorySnippet>[],
      );
    }

    final contents = memories
        .map(_extractMemoryText)
        .whereType<String>()
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    final memoryCount = memories.length;
    final activeDays = _countActiveDays(memories);

    final executionHits = _countKeywordHits(contents, const <String>[
      '完成',
      '搞定',
      '执行',
      '推进',
      '提交',
      'finish',
      'done',
    ]);
    final growthHits = _countKeywordHits(contents, const <String>[
      '学习',
      '复盘',
      '总结',
      '优化',
      '改进',
      '成长',
      'improve',
      'learn',
    ]);
    final wellbeingHits = _countKeywordHits(contents, const <String>[
      '休息',
      '睡眠',
      '运动',
      '散步',
      '喝水',
      '放松',
      '冥想',
      'self-care',
    ]);
    final socialHits = _countKeywordHits(contents, const <String>[
      '沟通',
      '协作',
      '讨论',
      '同步',
      '家人',
      '朋友',
      '微信',
      '团队',
    ]);

    double scoreExecution =
        45 + executionHits * 3.4 + min(memoryCount, 18) * 0.8;
    double scoreConsistency =
        40 + activeDays * 4.6 + min(memoryCount, 16) * 0.6;
    double scoreGrowth = 42 + growthHits * 3.6 + min(memoryCount, 15) * 0.5;
    double scoreWellbeing =
        38 + wellbeingHits * 4.0 + max(0, 8 - (memoryCount ~/ 4)) * 0.8;
    double scoreSocial = 40 + socialHits * 4.1 + min(memoryCount, 12) * 0.45;

    final scores = <String, double>{
      'execution': _clampScore(scoreExecution),
      'consistency': _clampScore(scoreConsistency),
      'growth': _clampScore(scoreGrowth),
      'wellbeing': _clampScore(scoreWellbeing),
      'social': _clampScore(scoreSocial),
    };

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top1 = sorted[0];
    final top2 = sorted[1];
    final low1 = sorted[sorted.length - 1];
    final low2 = sorted[sorted.length - 2];

    final tags = {
      _tagForDimension(top1.key),
      _tagForDimension(top2.key),
      if (memoryCount >= 10) _txt('持续行动者', 'Consistent Doer'),
    }.toList();

    final summary =
        _isEnglish
            ? 'You left $memoryCount life records across the last $activeDays days. '
                '${_labelOf(top1.key)} (${top1.value.toStringAsFixed(0)}) and '
                '${_labelOf(top2.key)} (${top2.value.toStringAsFixed(0)}) are the most stable dimensions, which suggests you are forming a clear action rhythm.'
            : '最近 $activeDays 天你留下了 $memoryCount 条生存记录。${_labelOf(top1.key)}'
                '（${top1.value.toStringAsFixed(0)}）与${_labelOf(top2.key)}'
                '（${top2.value.toStringAsFixed(0)}）表现最稳定，说明你已经形成了清晰的行动节奏。';

    final strengths = <String>[
      _isEnglish
          ? '${_labelOf(top1.key)} leads right now (${top1.value.toStringAsFixed(0)}), showing strong forward momentum.'
          : '近阶段「${_labelOf(top1.key)}」维度领先（${top1.value.toStringAsFixed(0)}分），关键行动推进感明显。',
      _isEnglish
          ? 'You stayed consistent in ${_labelOf(top2.key)}, with recent activity spanning $activeDays days.'
          : '你在${_labelOf(top2.key)}上保持连续输出，最近活跃记录覆盖 $activeDays 天。',
      if (executionHits > 0 || growthHits > 0)
        _txt(
          '行动/成长关键词累计命中 ${executionHits + growthHits} 次，目标感较强。',
          'Action and growth keywords appeared ${executionHits + growthHits} times, which suggests a strong sense of direction.',
        ),
    ];

    final suggestions = <String>[
      _suggestionForDimension(low1.key),
      _suggestionForDimension(low2.key),
      if (wellbeingHits <= 1)
        _txt(
          '本周可以补 1 条“休息或运动”记忆，帮助节奏更可持续。',
          'Add one “rest or exercise” memory this week to make your rhythm more sustainable.',
        ),
    ];

    final recentMemories = _buildRecentMemorySnippets(memories, maxCount: 5);
    final highlights = recentMemories
        .map((snippet) => snippet.summary)
        .toList(growable: false);

    return EvermemosUserProfileReport(
      userId: userId,
      memoryCount: memoryCount,
      scores: scores,
      tags: tags,
      summary: summary,
      strengths: strengths,
      suggestions: suggestions,
      highlights: highlights,
      recentMemories: recentMemories,
    );
  }

  List<QuestNode> _extractTodayCompletedQuests(List<QuestNode> quests) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return quests.where((quest) {
      if (!quest.isCompleted || quest.completedAt == null || quest.isDeleted) {
        return false;
      }
      final completedLocal = quest.completedAt!.toLocal();
      final completedDay = DateTime(
        completedLocal.year,
        completedLocal.month,
        completedLocal.day,
      );
      return completedDay == today;
    }).toList()
      ..sort((a, b) => a.completedAt!.compareTo(b.completedAt!));
  }

  String _buildMemoryContent(List<QuestNode> quests) {
    final buffer = StringBuffer()
      ..writeln(_txt(
        '请将以下任务整理为一段温暖的地球日记。',
        'Please turn the following tasks into a warm Earth diary entry.',
      ))
      ..writeln(_txt(
        '要求：使用第一人称或温暖第二人称；避免“报告称/未提及”等机器腔。',
        'Requirements: use first person or a warm second person voice, and avoid robotic phrasing.',
      ))
      ..writeln(_txt(
        '保留真实行动细节，并给出积极、有人情味的表达。',
        'Keep the real action details and express them in a positive, human way.',
      ))
      ..writeln('')
      ..writeln(_txt(
        '今天我在地球上完成了 ${quests.length} 件行动：',
        'Today I completed ${quests.length} actions on Earth:',
      ));
    for (var i = 0; i < quests.length; i++) {
      buffer.writeln('${i + 1}. ${quests[i].title}');
    }
    final descriptions = quests
        .map((q) => q.description?.trim())
        .whereType<String>()
        .where((d) => d.isNotEmpty)
        .toList();
    if (descriptions.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln(
        _txt(
          '补充背景：${descriptions.take(3).join('；')}',
          'Extra context: ${descriptions.take(3).join('; ')}',
        ),
      );
    }
    return buffer.toString().trim();
  }

  String _generateMessageId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomPart = _random.nextInt(1 << 32).toRadixString(16);
    return 'msg_${timestamp}_$randomPart';
  }

  String _createTimeIso8601() {
    return DateTime.now().toUtc().toIso8601String();
  }

  bool _isMissingFilterValidationError(String responseBody) {
    final lower = responseBody.toLowerCase();
    return lower.contains('at least one of user_id or group_ids');
  }

  void _resetUploadedQuestCacheIfNeeded() {
    final now = DateTime.now();
    final dayKey = '${now.year}-${now.month}-${now.day}';
    if (_uploadedQuestDayKey != dayKey) {
      _uploadedQuestDayKey = dayKey;
      _uploadedQuestIdsToday.clear();
    }
  }

  int _countActiveDays(List<Map<String, dynamic>> memories) {
    final dayKeys = <String>{};
    for (final memory in memories) {
      final dt = _extractMemoryDateTime(memory);
      if (dt == null) continue;
      final day = DateTime(dt.year, dt.month, dt.day);
      dayKeys.add(day.toIso8601String());
    }
    return dayKeys.length;
  }

  int _countKeywordHits(List<String> texts, List<String> keywords) {
    if (texts.isEmpty || keywords.isEmpty) return 0;
    var total = 0;
    for (final text in texts) {
      final lower = text.toLowerCase();
      for (final keyword in keywords) {
        if (lower.contains(keyword.toLowerCase())) {
          total++;
        }
      }
    }
    return total;
  }

  double _clampScore(double value) {
    if (value < 20) return 20;
    if (value > 95) return 95;
    return value;
  }

  String _labelOf(String dimension) {
    switch (dimension) {
      case 'execution':
        return _txt('执行力', 'Execution');
      case 'consistency':
        return _txt('稳定性', 'Consistency');
      case 'growth':
        return _txt('成长性', 'Growth');
      case 'wellbeing':
        return _txt('自我照顾', 'Wellbeing');
      case 'social':
        return _txt('协作沟通', 'Social');
      default:
        return dimension;
    }
  }

  String _tagForDimension(String dimension) {
    switch (dimension) {
      case 'execution':
        return _txt('行动推进者', 'Momentum Builder');
      case 'consistency':
        return _txt('节奏稳定者', 'Rhythm Keeper');
      case 'growth':
        return _txt('成长探索者', 'Growth Explorer');
      case 'wellbeing':
        return _txt('自我照顾者', 'Self-Care Keeper');
      case 'social':
        return _txt('协作连接者', 'Connection Builder');
      default:
        return _txt('均衡玩家', 'Balanced Player');
    }
  }

  String _suggestionForDimension(String dimension) {
    switch (dimension) {
      case 'execution':
        return _txt(
          '把大目标拆成 25 分钟小任务，每天至少推进一个最小动作。',
          'Break large goals into 25-minute tasks and move at least one small step forward each day.',
        );
      case 'consistency':
        return _txt(
          '固定一个每日复盘时间，哪怕只写 2 句话，也能提高连续性。',
          'Fix one daily review time. Even two sentences can improve consistency.',
        );
      case 'growth':
        return _txt(
          '每周挑 1 次任务做“复盘+改进”，把经验写成可复用清单。',
          'Pick one task each week for review and improvement, then turn the lessons into a reusable checklist.',
        );
      case 'wellbeing':
        return _txt(
          '在任务列表中加入“休息/运动/补水”型任务，保持长期续航。',
          'Add rest, exercise, or hydration quests to your list to support long-term energy.',
        );
      case 'social':
        return _txt(
          '把关键进展同步给同伴或家人，建立外部反馈回路。',
          'Share key progress with a teammate or family member to build an external feedback loop.',
        );
      default:
        return _txt(
          '继续保持记录，画像会随着样本增加而更准确。',
          'Keep recording consistently and the portrait will become more accurate as samples grow.',
        );
    }
  }

  List<EvermemosMemorySnippet> _buildRecentMemorySnippets(
    List<Map<String, dynamic>> memories, {
    int maxCount = 5,
  }) {
    final sorted = List<Map<String, dynamic>>.from(memories)
      ..sort((a, b) {
        final aTime = _extractMemoryDateTime(a);
        final bTime = _extractMemoryDateTime(b);
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

    final dedupe = <String>{};
    final snippets = <EvermemosMemorySnippet>[];

    for (final memory in sorted) {
      final content = _extractMemoryText(memory)?.trim();
      if (content == null || content.isEmpty) continue;
      final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (dedupe.contains(normalized)) continue;
      dedupe.add(normalized);

      final dt = _extractMemoryDateTime(memory)?.toLocal();
      snippets.add(
        EvermemosMemorySnippet(
          summary: _toSummary(normalized),
          content: normalized,
          timestamp: dt,
          displayTime: _formatSnippetTime(dt),
        ),
      );
      if (snippets.length >= maxCount) break;
    }
    return snippets;
  }

  String _toSummary(String content, {int maxLength = 34}) {
    if (content.length <= maxLength) return content;
    return '${content.substring(0, maxLength)}...';
  }

  String _formatSnippetTime(DateTime? dt) {
    if (dt == null) return _txt('时间未知', 'Unknown time');
    final now = DateTime.now();
    final local = dt.toLocal();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (sameDay) {
      return _txt(
        '今天 ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}',
        'Today ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}',
      );
    }
    if (local.year == now.year) {
      return _txt(
        '${local.month}月${local.day}日',
        '${local.month}/${local.day}',
      );
    }
    return '${local.year}/${local.month}/${local.day}';
  }

  String _twoDigits(int n) {
    if (n >= 10) return '$n';
    return '0$n';
  }

  List<Map<String, dynamic>> _extractMemories(Map<String, dynamic> body) {
    final candidates = <dynamic>[
      body['memories'],
      (body['result'] as Map?)?['memories'],
      (body['data'] as Map?)?['memories'],
      body['data'],
    ];

    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return const [];
  }

  Map<String, dynamic>? _pickLatestMemory(List<Map<String, dynamic>> memories) {
    if (memories.isEmpty) return null;
    final sorted = List<Map<String, dynamic>>.from(memories);
    sorted.sort((a, b) {
      final aTime = _extractMemoryDateTime(a);
      final bTime = _extractMemoryDateTime(b);
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return sorted.first;
  }

  DateTime? _extractMemoryDateTime(Map<String, dynamic> memory) {
    final raw = memory['create_time'] ??
        memory['created_at'] ??
        memory['created_time'] ??
        memory['timestamp'];

    if (raw is String) {
      return DateTime.tryParse(raw)?.toUtc();
    }
    if (raw is int) {
      if (raw > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
      }
      if (raw > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true);
      }
    }
    if (raw is num) {
      final value = raw.toInt();
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      }
      if (value > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
      }
    }
    return null;
  }

  String? _extractMemoryText(Map<String, dynamic>? memory) {
    if (memory == null) return null;
    const directTextKeys = ['content', 'text', 'summary', 'memory', 'message'];
    for (final key in directTextKeys) {
      final value = memory[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final nestedData = memory['data'];
    if (nestedData is Map) {
      for (final key in directTextKeys) {
        final value = nestedData[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    return null;
  }

  Map<String, dynamic>? _tryDecodeJsonObject(String jsonText) {
    try {
      final decoded = jsonDecode(jsonText);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}

class EvermemosSyncException implements Exception {
  final String message;

  const EvermemosSyncException(this.message);

  @override
  String toString() => message;
}
