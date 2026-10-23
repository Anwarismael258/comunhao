class ChurchJoinRequest {
  const ChurchJoinRequest({
    required this.id,
    required this.churchId,
    required this.profileId,
    required this.requestKind,
    required this.fullName,
    this.avatarUrl,
    this.avatarStoragePath,
    this.phone,
    this.birthDate,
    this.gender,
    this.neighborhood,
    this.previousChurch,
    this.reason,
    this.ministryInterest,
    this.observation,
    required this.status,
    this.assignedMembershipId,
    this.informationRequested,
    this.memberResponse,
    this.reviewNotes,
    this.decisionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String churchId;
  final String profileId;
  final String requestKind;
  final String fullName;
  final String? avatarUrl;
  final String? avatarStoragePath;
  final String? phone;
  final DateTime? birthDate;
  final String? gender;
  final String? neighborhood;
  final String? previousChurch;
  final String? reason;
  final String? ministryInterest;
  final String? observation;
  final String status;
  final String? assignedMembershipId;
  final String? informationRequested;
  final String? memberResponse;
  final String? reviewNotes;
  final String? decisionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get statusLabel => switch (status) {
        'pending' => 'Pendente',
        'under_review' => 'Em analise',
        'more_information_required' => 'Aguarda informacoes',
        'approved' => 'Aprovado',
        'rejected' => 'Rejeitado',
        'cancelled' => 'Cancelado',
        _ => status,
      };

  bool get canMemberRespond => status == 'more_information_required';
  bool get canMemberCancel =>
      status == 'pending' ||
      status == 'under_review' ||
      status == 'more_information_required';

  String get requestKindLabel => switch (requestKind) {
        'ministry' => 'Entrada em ministerio',
        'group' => 'Entrada em grupo/celula',
        'volunteer' => 'Servir como voluntario',
        'baptism' => 'Preparacao para batismo',
        'transfer' => 'Transferencia de congregacao',
        _ => 'Pedido de servico',
      };

  factory ChurchJoinRequest.fromMap(Map<String, dynamic> map) {
    final profile = _readProfile(map);
    return ChurchJoinRequest(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      profileId: (map['profile_id'] as String?) ?? '',
      requestKind: (map['request_kind'] as String?) ?? 'ministry',
      fullName: ((map['full_name'] as String?) ??
              (profile['full_name'] as String?) ??
              'Utilizador')
          .trim(),
      avatarUrl: profile['avatar_url'] as String?,
      avatarStoragePath: profile['avatar_storage_path'] as String?,
      phone: (map['phone'] as String?) ?? profile['phone'] as String?,
      birthDate: DateTime.tryParse((map['birth_date'] as String?) ?? ''),
      gender: map['gender'] as String?,
      neighborhood: map['neighborhood'] as String?,
      previousChurch: map['previous_church'] as String?,
      reason: (map['reason'] as String?) ?? map['message'] as String?,
      ministryInterest: map['ministry_interest'] as String?,
      observation: map['observation'] as String?,
      status: (map['status'] as String?) ?? 'pending',
      assignedMembershipId: map['assigned_membership_id'] as String?,
      informationRequested: map['information_requested'] as String?,
      memberResponse: map['member_response'] as String?,
      reviewNotes: map['review_notes'] as String?,
      decisionReason: map['decision_reason'] as String?,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? '') ??
          DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class PastoralCareRequest {
  const PastoralCareRequest({
    required this.id,
    required this.churchId,
    this.sourceTable = 'pastoral_requests',
    this.profileId,
    this.requesterName,
    this.requesterAvatarUrl,
    this.requesterAvatarStoragePath,
    required this.category,
    required this.title,
    required this.message,
    required this.urgency,
    required this.privacyLevel,
    this.preferredContact,
    this.contactAvailability,
    this.attachmentUrl,
    required this.consentForwarding,
    this.assignedMembershipId,
    this.assignedName,
    this.latestPublicResponse,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String churchId;
  final String sourceTable;
  final String? profileId;
  final String? requesterName;
  final String? requesterAvatarUrl;
  final String? requesterAvatarStoragePath;
  final String category;
  final String title;
  final String message;
  final String urgency;
  final String privacyLevel;
  final String? preferredContact;
  final String? contactAvailability;
  final String? attachmentUrl;
  final bool consentForwarding;
  final String? assignedMembershipId;
  final String? assignedName;
  final String? latestPublicResponse;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isUrgent => urgency == 'urgent' || urgency == 'high';
  bool get isConfidential => privacyLevel != 'pastoral_team';

  String get categoryLabel => switch (category) {
        'prayer' => 'Oracao',
        'counseling' => 'Aconselhamento',
        'visit' => 'Visita',
        'social_support' => 'Apoio social',
        'baptism' => 'Batismo',
        'wedding' => 'Casamento',
        'funeral' => 'Funeral',
        _ => 'Pedido pastoral',
      };

  String get urgencyLabel => switch (urgency) {
        'low' => 'Baixa',
        'high' => 'Alta',
        'urgent' => 'Urgente',
        _ => 'Normal',
      };

  String get statusLabel => switch (status) {
        'new' => 'Pendente',
        'triaged' => 'Em analise',
        'assigned' => 'Agendado / atribuido',
        'in_contact' => 'Em contacto',
        'in_follow_up' => 'Em andamento',
        'waiting_member' => 'Aguarda membro',
        'resolved' => 'Concluido',
        'closed' => 'Concluido',
        'cancelled' => 'Cancelado',
        _ => status,
      };

  factory PastoralCareRequest.fromMap(Map<String, dynamic> map) {
    final profile = _readProfile(map);
    final assigned = _readNestedProfile(map['assigned']);
    final latestResponse = _readLatestPublicResponse(map['responses']);
    return PastoralCareRequest(
      id: 'prayer_requests:${(map['id'] as String?) ?? ''}',
      churchId: (map['church_id'] as String?) ?? '',
      sourceTable: (map['source_table'] as String?) ?? 'pastoral_requests',
      profileId: map['profile_id'] as String?,
      requesterName: profile['full_name'] as String?,
      requesterAvatarUrl: profile['avatar_url'] as String?,
      requesterAvatarStoragePath: profile['avatar_storage_path'] as String?,
      category: (map['category'] as String?) ?? 'pastoral',
      title: ((map['title'] as String?) ?? (map['subject'] as String?) ?? '')
          .trim(),
      message: (map['message'] as String?) ?? '',
      urgency: (map['urgency'] as String?) ?? 'normal',
      privacyLevel: (map['privacy_level'] as String?) ??
          (map['confidentiality'] as String?) ??
          'pastor_only',
      preferredContact: map['preferred_contact'] as String?,
      contactAvailability: map['contact_availability'] as String?,
      attachmentUrl: map['attachment_url'] as String?,
      consentForwarding: (map['consent_forwarding'] as bool?) ?? false,
      assignedMembershipId: map['assigned_membership_id'] as String?,
      assignedName: assigned['full_name'] as String?,
      latestPublicResponse: latestResponse,
      status: (map['status'] as String?) ?? 'new',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory PastoralCareRequest.fromPrayerMap(Map<String, dynamic> map) {
    final profile = _readProfile(map);
    final visibility = (map['visibility'] as String?) ??
        ((map['is_private'] as bool?) == true ? 'private' : 'public');
    final anonymous = (map['anonymous_request'] as bool?) == true ||
        visibility == 'anonymous';
    return PastoralCareRequest(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      sourceTable: 'prayer_requests',
      profileId: map['profile_id'] as String?,
      requesterName:
          anonymous ? 'Pedido anonimo' : profile['full_name'] as String?,
      requesterAvatarUrl: anonymous ? null : profile['avatar_url'] as String?,
      requesterAvatarStoragePath:
          anonymous ? null : profile['avatar_storage_path'] as String?,
      category: 'prayer',
      title: ((map['title'] as String?) ?? '').trim(),
      message: (map['description'] as String?) ?? '',
      urgency: 'normal',
      privacyLevel: visibility == 'private' ? 'pastor_only' : 'pastoral_team',
      consentForwarding: visibility != 'private',
      status: switch ((map['status'] as String?) ?? 'new') {
        'answered' => 'resolved',
        'closed' => 'closed',
        'cancelled' => 'cancelled',
        _ => 'new',
      },
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? '') ??
          DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class AdministrativeRequest {
  const AdministrativeRequest({
    required this.id,
    required this.churchId,
    this.profileId,
    this.requesterName,
    this.requesterAvatarUrl,
    this.requesterAvatarStoragePath,
    required this.requestType,
    required this.subject,
    required this.description,
    this.attachmentUrl,
    required this.status,
    this.assignedMembershipId,
    this.response,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String churchId;
  final String? profileId;
  final String? requesterName;
  final String? requesterAvatarUrl;
  final String? requesterAvatarStoragePath;
  final String requestType;
  final String subject;
  final String description;
  final String? attachmentUrl;
  final String status;
  final String? assignedMembershipId;
  final String? response;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get typeLabel => switch (requestType) {
        'member_statement' => 'Declaracao de membro',
        'data_update' => 'Atualizacao de dados',
        'transfer' => 'Transferencia',
        'ministry_entry' => 'Entrada em ministerio',
        'group_entry' => 'Entrada em grupo',
        'space_booking' => 'Reserva de espaco',
        'document' => 'Documento',
        _ => 'Outro',
      };

  String get statusLabel => switch (status) {
        'new' => 'Novo',
        'in_progress' => 'Em atendimento',
        'waiting_member' => 'Aguarda membro',
        'completed' => 'Concluido',
        'closed' => 'Fechado',
        'cancelled' => 'Cancelado',
        _ => status,
      };

  factory AdministrativeRequest.fromMap(Map<String, dynamic> map) {
    final profile = _readProfile(map);
    return AdministrativeRequest(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      profileId: map['profile_id'] as String?,
      requesterName: profile['full_name'] as String?,
      requesterAvatarUrl: profile['avatar_url'] as String?,
      requesterAvatarStoragePath: profile['avatar_storage_path'] as String?,
      requestType: (map['request_type'] as String?) ?? 'other',
      subject: (map['subject'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      attachmentUrl: map['attachment_url'] as String?,
      status: (map['status'] as String?) ?? 'new',
      assignedMembershipId: map['assigned_membership_id'] as String?,
      response: map['response'] as String?,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class ChurchRequestTimelineEntry {
  const ChurchRequestTimelineEntry({
    required this.id,
    required this.action,
    this.publicMessage,
    this.internalNote,
    required this.createdAt,
  });

  final String id;
  final String action;
  final String? publicMessage;
  final String? internalNote;
  final DateTime createdAt;

  factory ChurchRequestTimelineEntry.fromMap(Map<String, dynamic> map) {
    return ChurchRequestTimelineEntry(
      id: (map['id'] as String?) ?? '',
      action: (map['action'] as String?) ?? '',
      publicMessage: map['public_message'] as String?,
      internalNote: map['internal_note'] as String?,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

Map<String, dynamic> _readProfile(Map<String, dynamic> map) {
  final raw = map['profile'];
  return switch (raw) {
    Map<String, dynamic> value => value,
    List<dynamic> value
        when value.isNotEmpty && value.first is Map<String, dynamic> =>
      value.first as Map<String, dynamic>,
    _ => const <String, dynamic>{},
  };
}

Map<String, dynamic> _readNestedProfile(Object? rawAssigned) {
  final assigned = switch (rawAssigned) {
    Map<String, dynamic> value => value,
    List<dynamic> value
        when value.isNotEmpty && value.first is Map<String, dynamic> =>
      value.first as Map<String, dynamic>,
    _ => const <String, dynamic>{},
  };
  final rawProfile = assigned['profile'];
  return switch (rawProfile) {
    Map<String, dynamic> value => value,
    List<dynamic> value
        when value.isNotEmpty && value.first is Map<String, dynamic> =>
      value.first as Map<String, dynamic>,
    _ => const <String, dynamic>{},
  };
}

String? _readLatestPublicResponse(Object? rawResponses) {
  final responses = switch (rawResponses) {
    List<dynamic> value => value.whereType<Map<String, dynamic>>().toList(),
    Map<String, dynamic> value => [value],
    _ => const <Map<String, dynamic>>[],
  };
  final publicResponses = responses
      .where((response) => response['internal_only'] != true)
      .where(
        (response) => ((response['body'] as String?) ?? '').trim().isNotEmpty,
      )
      .toList()
    ..sort((a, b) {
      final aDate = DateTime.tryParse((a['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse((b['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

  if (publicResponses.isEmpty) {
    return null;
  }
  return publicResponses.first['body'] as String?;
}
