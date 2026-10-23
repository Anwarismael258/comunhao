class ChurchCommunication {
  const ChurchCommunication({
    required this.id,
    required this.churchId,
    required this.channel,
    required this.audienceType,
    this.targetRole,
    this.ministryId,
    this.ministryName,
    this.membershipId,
    this.memberName,
    required this.title,
    required this.body,
    required this.status,
    this.scheduledAt,
    this.sentAt,
    required this.createdAt,
  });

  final String id;
  final String churchId;
  final String channel;
  final String audienceType;
  final String? targetRole;
  final String? ministryId;
  final String? ministryName;
  final String? membershipId;
  final String? memberName;
  final String title;
  final String body;
  final String status;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final DateTime createdAt;

  String get channelLabel => switch (channel) {
        'sms' => 'SMS',
        'whatsapp' => 'WhatsApp',
        'email' => 'Email',
        _ => 'Push',
      };

  String get audienceLabel => switch (audienceType) {
        'group' => 'Grupo: ${_roleLabel(targetRole)}',
        'ministry' => 'Ministerio: ${ministryName ?? 'Selecionado'}',
        'person' => 'Pessoa: ${memberName ?? 'Selecionada'}',
        _ => 'Todos',
      };

  String get statusLabel => switch (status) {
        'queued' => 'Na fila',
        'sent' => 'Enviado',
        'failed' => 'Falhou',
        'cancelled' => 'Cancelado',
        _ => 'Rascunho',
      };

  factory ChurchCommunication.fromMap(Map<String, dynamic> map) {
    final rawMinistry = map['ministry'];
    final ministry = switch (rawMinistry) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => const <String, dynamic>{},
    };

    final rawMembership = map['membership'];
    final membership = switch (rawMembership) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => const <String, dynamic>{},
    };

    final rawProfile = membership['profile'];
    final profile = switch (rawProfile) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => const <String, dynamic>{},
    };

    return ChurchCommunication(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      channel: (map['channel'] as String?) ?? 'push',
      audienceType: (map['audience_type'] as String?) ?? 'all',
      targetRole: map['target_role'] as String?,
      ministryId: map['ministry_id'] as String?,
      ministryName: ministry['name'] as String?,
      membershipId: map['membership_id'] as String?,
      memberName: profile['full_name'] as String?,
      title: (map['title'] as String?) ?? 'Comunicacao',
      body: (map['body'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'draft',
      scheduledAt: DateTime.tryParse((map['scheduled_at'] as String?) ?? ''),
      sentAt: DateTime.tryParse((map['sent_at'] as String?) ?? ''),
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static String _roleLabel(String? role) => switch (role) {
        'pastor' => 'Pastores',
        'church_admin' => 'Administradores',
        'leader' => 'Lideres',
        'member' => 'Membros',
        _ => 'Grupo',
      };
}
