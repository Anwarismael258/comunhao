class ManagedAnnouncement {
  const ManagedAnnouncement({
    required this.id,
    required this.churchId,
    required this.title,
    required this.body,
    this.imageUrl,
    this.pastoralPublicationId,
    required this.pinned,
    this.publishedAt,
    required this.createdAt,
  });

  final String id;
  final String churchId;
  final String title;
  final String body;
  final String? imageUrl;
  final String? pastoralPublicationId;
  final bool pinned;
  final DateTime? publishedAt;
  final DateTime createdAt;

  bool get isPublished => publishedAt != null;

  factory ManagedAnnouncement.fromMap(Map<String, dynamic> map) {
    return ManagedAnnouncement(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      title: (map['title'] as String?) ?? 'Anuncio',
      body: (map['body'] as String?) ?? '',
      imageUrl: map['image_url'] as String?,
      pastoralPublicationId: map['pastoral_publication_id'] as String?,
      pinned: (map['pinned'] as bool?) ?? false,
      publishedAt: DateTime.tryParse((map['published_at'] as String?) ?? ''),
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
