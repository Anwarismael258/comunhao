class ChurchAnnouncement {
  const ChurchAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.pastoralPublicationId,
    required this.pinned,
    this.publishedAt,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final String? pastoralPublicationId;
  final bool pinned;
  final DateTime? publishedAt;
  final DateTime createdAt;

  factory ChurchAnnouncement.fromMap(Map<String, dynamic> map) {
    return ChurchAnnouncement(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      imageUrl: map['image_url'] as String?,
      pastoralPublicationId: map['pastoral_publication_id'] as String?,
      pinned: map['pinned'] as bool? ?? false,
      publishedAt: map['published_at'] == null
          ? null
          : DateTime.parse(map['published_at'] as String).toLocal(),
      createdAt:
          DateTime.tryParse((map['created_at'] as String?) ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
