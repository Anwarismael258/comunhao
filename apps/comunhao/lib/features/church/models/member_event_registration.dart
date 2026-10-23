class MemberEventRegistration {
  const MemberEventRegistration({
    required this.id,
    required this.eventId,
    required this.profileId,
    required this.status,
    this.checkInCode,
    this.checkedInAt,
    this.paymentStatus,
    this.waitingListPosition,
    required this.createdAt,
  });

  final String id;
  final String eventId;
  final String profileId;
  final String status;
  final String? checkInCode;
  final DateTime? checkedInAt;
  final String? paymentStatus;
  final int? waitingListPosition;
  final DateTime createdAt;

  bool get isConfirmed => status == 'confirmed' || status == 'registered';
  bool get isCheckedIn => status == 'checked_in';
  bool get isCancelled => status == 'cancelled';
  bool get isWaitingList => status == 'waiting_list';

  String get statusLabel => switch (status) {
        'checked_in' => 'Presente',
        'cancelled' => 'Cancelado',
        'waiting_list' => waitingListPosition == null
            ? 'Lista de espera'
            : 'Lista de espera #$waitingListPosition',
        'registered' => paymentStatus == 'pending'
            ? 'Inscrito - pagamento pendente'
            : 'Inscrito',
        _ => 'Confirmado',
      };

  factory MemberEventRegistration.fromMap(Map<String, dynamic> map) {
    return MemberEventRegistration(
      id: (map['id'] as String?) ?? '',
      eventId: (map['event_id'] as String?) ?? '',
      profileId: (map['profile_id'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'confirmed',
      checkInCode: map['check_in_code'] as String?,
      checkedInAt: DateTime.tryParse((map['checked_in_at'] as String?) ?? ''),
      paymentStatus: map['payment_status'] as String?,
      waitingListPosition: (map['waiting_list_position'] as num?)?.toInt(),
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
