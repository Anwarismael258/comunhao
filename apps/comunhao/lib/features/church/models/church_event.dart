class ChurchEvent {
  const ChurchEvent({
    required this.id,
    required this.title,
    required this.eventType,
    this.description,
    this.location,
    this.coverImageUrl,
    this.pastoralPublicationId,
    required this.startsAt,
    this.endsAt,
    required this.registrationRequired,
    this.capacity,
    this.registrationFeeMzn,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String eventType;
  final String? description;
  final String? location;
  final String? coverImageUrl;
  final String? pastoralPublicationId;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool registrationRequired;
  final int? capacity;
  final num? registrationFeeMzn;
  final DateTime createdAt;

  String get eventTypeLabel => switch (eventType) {
        'culto' => 'Culto',
        'congresso' => 'Congresso',
        'vigilia' => 'Vigília',
        'batismo' => 'Batismo',
        'casamento' => 'Casamento',
        'conferencia' => 'Conferência',
        'ensaio' => 'Ensaio',
        'reuniao' => 'Reunião',
        _ => 'Evento',
      };

  factory ChurchEvent.fromMap(Map<String, dynamic> map) {
    return ChurchEvent(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      eventType: (map['event_type'] as String?) ?? 'outro',
      description: map['description'] as String?,
      location: map['location'] as String?,
      coverImageUrl: map['cover_image_url'] as String?,
      pastoralPublicationId: map['pastoral_publication_id'] as String?,
      startsAt: DateTime.parse(map['starts_at'] as String).toLocal(),
      endsAt: map['ends_at'] == null
          ? null
          : DateTime.parse(map['ends_at'] as String).toLocal(),
      registrationRequired: map['registration_required'] as bool? ?? false,
      capacity: map['capacity'] as int?,
      registrationFeeMzn: map['registration_fee_mzn'] as num?,
      createdAt:
          DateTime.tryParse((map['created_at'] as String?) ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
