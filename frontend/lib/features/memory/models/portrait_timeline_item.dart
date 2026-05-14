/// 画像时间线条目，对应 guide_portraits 表中的一条记录
class PortraitTimelineItem {
  final String id;
  final String epoch;
  final String summary;
  final String imageUrl;
  final DateTime? createdAt;

  const PortraitTimelineItem({
    required this.id,
    required this.epoch,
    required this.summary,
    required this.imageUrl,
    required this.createdAt,
  });

  factory PortraitTimelineItem.fromMap(Map<String, dynamic> map) {
    final createdRaw = map['created_at'];
    DateTime? createdAt;
    if (createdRaw is String && createdRaw.isNotEmpty) {
      createdAt = DateTime.tryParse(createdRaw);
    }
    return PortraitTimelineItem(
      id: '${map['id'] ?? ''}',
      epoch: '${map['epoch'] ?? ''}',
      summary: '${map['summary'] ?? ''}',
      imageUrl: '${map['image_url'] ?? map['imageUrl'] ?? ''}',
      createdAt: createdAt,
    );
  }
}
