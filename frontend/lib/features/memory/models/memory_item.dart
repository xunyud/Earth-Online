/// 单条记忆片段
class MemoryItem {
  final String id;
  final String content;
  final String summary;
  final String memoryKind;
  final String eventType;
  final String sourceTaskTitle;
  final DateTime? createdAt;
  final double score;
  final String sender;
  final bool pinned;
  final String? audioUrl;
  final String? imageUrl;

  const MemoryItem({
    required this.id,
    required this.content,
    required this.summary,
    required this.memoryKind,
    required this.eventType,
    required this.sourceTaskTitle,
    required this.createdAt,
    required this.score,
    this.sender = '',
    this.pinned = false,
    this.audioUrl,
    this.imageUrl,
  });

  factory MemoryItem.fromMap(Map<String, dynamic> map) {
    final rawContent = _str(map['content']) ??
        _str(map['text']) ??
        _str(map['memory']) ??
        _str((map['data'] as Map?)?['content']) ??
        '';

    final parsed = _parseEnvelope(rawContent);

    final createdRaw = map['created_at'] ?? map['create_time'];
    DateTime? createdAt;
    if (createdRaw is String && createdRaw.isNotEmpty) {
      createdAt = DateTime.tryParse(createdRaw);
    } else if (createdRaw is num) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdRaw.toInt());
    }

    final scoreRaw = map['score'] ?? map['similarity'] ?? map['relevance'];
    final score = scoreRaw is num ? scoreRaw.toDouble() : 0.0;

    return MemoryItem(
      id: _str(map['id']) ??
          _str(map['message_id']) ??
          _str((map['data'] as Map?)?['id']) ??
          '',
      content: parsed['content'] ?? rawContent,
      summary: parsed['summary'] ??
          rawContent.substring(0, rawContent.length.clamp(0, 60)),
      memoryKind: parsed['memoryKind'] ?? _str(map['memory_kind']) ?? 'generic',
      eventType: parsed['eventType'] ?? _str(map['event_type']) ?? '',
      sourceTaskTitle: parsed['sourceTaskTitle'] ?? '',
      createdAt: createdAt,
      score: score,
      sender: parsed['sender'] ?? '',
      pinned: parsed['pinned'] == 'true',
      audioUrl: _str(map['audio_url']) ??
          _str((map['metadata'] as Map?)?['audio_url']),
      imageUrl: _str(map['image_url']) ??
          _str((map['metadata'] as Map?)?['image_url']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': _buildEnvelopeContent(),
      'created_at': createdAt?.toIso8601String(),
      'score': score,
      'memory_kind': memoryKind,
      'event_type': eventType,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }

  String _buildEnvelopeContent() {
    final parts = <String>[
      '[smart-p-memory:v1] eventType=$eventType',
      'content=$content',
      'summary=$summary',
      'memoryKind=$memoryKind',
      'sourceTaskTitle=$sourceTaskTitle',
    ];
    if (sender.isNotEmpty) {
      parts.add('sender=$sender');
    }
    parts.add('pinned=$pinned');
    return parts.join(' | ');
  }

  static Map<String, String> _parseEnvelope(String raw) {
    if (!raw.contains('[smart-p-memory:v1]')) return {};
    final result = <String, String>{};
    final parts = raw.split('|');
    for (final part in parts) {
      final kv = part.trim();
      final eqIdx = kv.indexOf('=');
      if (eqIdx < 0) continue;
      final key = kv.substring(0, eqIdx).trim();
      final value = kv.substring(eqIdx + 1).trim();
      switch (key) {
        case 'content':
          result['content'] = value;
        case 'summary':
          result['summary'] = value;
        case 'memoryKind':
          result['memoryKind'] = value;
        case 'eventType':
          result['eventType'] = value;
        case 'sourceTaskTitle':
          result['sourceTaskTitle'] = value;
        case 'sender':
          result['sender'] = value;
        case 'pinned':
          result['pinned'] = value;
      }
    }
    return result;
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }
}

/// 按来源过滤记忆列表
List<MemoryItem> filterBySender(List<MemoryItem> items, String senderFilter) {
  if (senderFilter == 'all') return items;
  return items.where((item) {
    final effectiveSender = item.sender.isEmpty ? 'user-manual' : item.sender;
    return effectiveSender == senderFilter;
  }).toList();
}

/// 从列表中移除指定 ID 的记忆
List<MemoryItem> removeById(List<MemoryItem> items, String mutedId) {
  return items.where((item) => item.id != mutedId).toList();
}
