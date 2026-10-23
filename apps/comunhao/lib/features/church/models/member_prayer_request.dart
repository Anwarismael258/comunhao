class MemberPrayerRequest {
  const MemberPrayerRequest({
    required this.id,
    required this.churchId,
    required this.title,
    required this.description,
    required this.isPrivate,
    required this.visibility,
    required this.status,
    required this.profileId,
    required this.anonymousRequest,
    required this.allowResponses,
    required this.createdAt,
    this.responseCount = 0,
  });

  final String id;
  final String churchId;
  final String title;
  final String description;
  final bool isPrivate;
  final String visibility;
  final String status;
  final String? profileId;
  final bool anonymousRequest;
  final bool allowResponses;
  final DateTime createdAt;
  final int responseCount;

  String get visibilityLabel => switch (visibility) {
        'anonymous' => 'Anonimo',
        'public' => 'Publico',
        _ => 'Privado',
      };

  String get statusLabel => switch (status) {
        'answered' => 'Respondido',
        'closed' => 'Fechado',
        _ => 'Novo',
      };

  bool isMine(String currentUserId) => profileId == currentUserId;

  factory MemberPrayerRequest.fromMap(Map<String, dynamic> map) {
    return MemberPrayerRequest(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      title: (map['title'] as String?) ?? 'Pedido de oracao',
      description: (map['description'] as String?) ?? '',
      isPrivate: (map['is_private'] as bool?) ?? true,
      visibility: (map['visibility'] as String?) ??
          ((map['is_private'] as bool?) ?? true ? 'private' : 'public'),
      status: (map['status'] as String?) ?? 'new',
      profileId: map['profile_id'] as String?,
      anonymousRequest: (map['anonymous_request'] as bool?) ?? false,
      allowResponses: (map['allow_responses'] as bool?) ?? true,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      responseCount: _parseResponseCount(map['responses']),
    );
  }

  static int _parseResponseCount(dynamic value) {
    if (value is List) return value.length;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
