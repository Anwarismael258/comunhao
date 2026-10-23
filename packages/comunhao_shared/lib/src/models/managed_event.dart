class ManagedEvent {
  const ManagedEvent({
    required this.id,
    required this.churchId,
    required this.title,
    required this.eventType,
    this.description,
    this.location,
    this.category,
    this.status = 'draft',
    this.visibility = 'members',
    this.coverImageUrl,
    this.pastoralPublicationId,
    this.recurrenceRule,
    this.attendanceRequired = false,
    this.isPublic = false,
    this.registrationFeeMzn,
    required this.startsAt,
    this.endsAt,
    required this.registrationRequired,
    this.capacity,
    required this.createdAt,
  });

  final String id;
  final String churchId;
  final String title;
  final String eventType;
  final String? description;
  final String? location;
  final String? category;
  final String status;
  final String visibility;
  final String? coverImageUrl;
  final String? pastoralPublicationId;
  final String? recurrenceRule;
  final bool attendanceRequired;
  final bool isPublic;
  final num? registrationFeeMzn;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool registrationRequired;
  final int? capacity;
  final DateTime createdAt;

  String get eventTypeLabel => switch (eventType) {
        'congresso' => 'Congresso',
        'vigilia' => 'Vigilia',
        'batismo' => 'Batismo',
        'casamento' => 'Casamento',
        'conferencia' => 'Conferencia',
        'ensaio' => 'Ensaio',
        'reuniao' => 'Reuniao',
        'estudo_biblico' => 'Estudo biblico',
        'acao_social' => 'Acao social',
        'transmissao' => 'Transmissao',
        'outro' => 'Outro',
        _ => 'Culto',
      };

  String get statusLabel => switch (status) {
        'published' => 'Publicado',
        'scheduled' => 'Agendado',
        'ongoing' => 'Em curso',
        'completed' => 'Concluido',
        'cancelled' => 'Cancelado',
        'postponed' => 'Adiado',
        'archived' => 'Arquivado',
        _ => 'Rascunho',
      };

  factory ManagedEvent.fromMap(Map<String, dynamic> map) {
    return ManagedEvent(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      title: (map['title'] as String?) ?? 'Evento',
      eventType: (map['event_type'] as String?) ?? 'culto',
      description: map['description'] as String?,
      location: map['location'] as String?,
      category: map['category'] as String?,
      status: (map['status'] as String?) ?? 'draft',
      visibility: (map['visibility'] as String?) ?? 'members',
      coverImageUrl: map['cover_image_url'] as String?,
      pastoralPublicationId: map['pastoral_publication_id'] as String?,
      recurrenceRule: map['recurrence_rule'] as String?,
      attendanceRequired: (map['attendance_required'] as bool?) ?? false,
      isPublic: (map['is_public'] as bool?) ?? false,
      registrationFeeMzn: map['registration_fee_mzn'] as num?,
      startsAt: DateTime.tryParse((map['starts_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endsAt: DateTime.tryParse((map['ends_at'] as String?) ?? ''),
      registrationRequired: (map['registration_required'] as bool?) ?? false,
      capacity: (map['capacity'] as num?)?.toInt(),
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
