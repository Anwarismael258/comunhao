class ManagedPrayerRequest {
  const ManagedPrayerRequest({
    required this.id,
    required this.churchId,
    required this.profileId,
    required this.title,
    required this.description,
    required this.isPrivate,
    required this.visibility,
    required this.anonymousRequest,
    required this.allowResponses,
    required this.status,
    required this.createdAt,
    this.requesterName,
    this.requesterPhone,
  });

  final String id;
  final String churchId;
  final String profileId;
  final String title;
  final String description;
  final bool isPrivate;
  final String visibility;
  final bool anonymousRequest;
  final bool allowResponses;
  final String status;
  final DateTime createdAt;
  final String? requesterName;
  final String? requesterPhone;

  String get visibilityLabel => switch (visibility) {
        'anonymous' => 'Anonimo',
        'public' => 'Publico',
        _ => isPrivate ? 'Privado' : 'Publico',
      };

  String get statusLabel => switch (status) {
        'answered' => 'Respondido',
        'closed' => 'Encerrado',
        'archived' => 'Arquivado',
        _ => 'Novo',
      };

  String get requesterLabel {
    if (anonymousRequest || visibility == 'anonymous') {
      return 'Pedido anonimo';
    }
    final name = requesterName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final phone = requesterPhone?.trim();
    if (phone != null && phone.isNotEmpty) {
      return phone;
    }
    return 'Membro';
  }

  factory ManagedPrayerRequest.fromMap(Map<String, dynamic> map) {
    final rawProfile = map['profile'];
    final profile = switch (rawProfile) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => const <String, dynamic>{},
    };

    return ManagedPrayerRequest(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      profileId: (map['profile_id'] as String?) ?? '',
      title: (map['title'] as String?) ?? 'Pedido de oracao',
      description: (map['description'] as String?) ?? '',
      isPrivate: (map['is_private'] as bool?) ?? true,
      visibility: (map['visibility'] as String?) ??
          (((map['is_private'] as bool?) ?? true) ? 'private' : 'public'),
      anonymousRequest: (map['anonymous_request'] as bool?) ?? false,
      allowResponses: (map['allow_responses'] as bool?) ?? true,
      status: (map['status'] as String?) ?? 'new',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      requesterName: profile['full_name'] as String?,
      requesterPhone: profile['phone'] as String?,
    );
  }
}
