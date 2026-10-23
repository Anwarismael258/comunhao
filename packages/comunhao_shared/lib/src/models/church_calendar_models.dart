class CalendarEventOccurrence {
  const CalendarEventOccurrence({
    required this.id,
    required this.eventId,
    required this.churchId,
    required this.startsAt,
    this.endsAt,
    required this.status,
    this.checkinOpensAt,
    this.checkinClosesAt,
    this.qrExpiresAt,
    this.qrClosedAt,
    this.overrideTitle,
    this.overrideLocation,
  });

  final String id;
  final String eventId;
  final String churchId;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String status;
  final DateTime? checkinOpensAt;
  final DateTime? checkinClosesAt;
  final DateTime? qrExpiresAt;
  final DateTime? qrClosedAt;
  final String? overrideTitle;
  final String? overrideLocation;

  bool get checkinOpen =>
      qrExpiresAt != null &&
      qrClosedAt == null &&
      qrExpiresAt!.isAfter(DateTime.now());

  factory CalendarEventOccurrence.fromMap(Map<String, dynamic> map) {
    return CalendarEventOccurrence(
      id: (map['id'] as String?) ?? '',
      eventId: (map['event_id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      startsAt:
          DateTime.tryParse((map['occurrence_start_at'] as String?) ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      endsAt: DateTime.tryParse((map['occurrence_end_at'] as String?) ?? ''),
      status: (map['status'] as String?) ?? 'scheduled',
      checkinOpensAt:
          DateTime.tryParse((map['checkin_opens_at'] as String?) ?? ''),
      checkinClosesAt:
          DateTime.tryParse((map['checkin_closes_at'] as String?) ?? ''),
      qrExpiresAt: DateTime.tryParse((map['qr_expires_at'] as String?) ?? ''),
      qrClosedAt: DateTime.tryParse((map['qr_closed_at'] as String?) ?? ''),
      overrideTitle: map['override_title'] as String?,
      overrideLocation: map['override_location'] as String?,
    );
  }
}

class EventAttendanceSummary {
  const EventAttendanceSummary({
    required this.total,
    required this.members,
    required this.visitors,
    required this.children,
    required this.manual,
    required this.qr,
  });

  final int total;
  final int members;
  final int visitors;
  final int children;
  final int manual;
  final int qr;

  factory EventAttendanceSummary.fromMap(Map<String, dynamic> map) {
    int value(String key) => (map[key] as num?)?.toInt() ?? 0;
    return EventAttendanceSummary(
      total: value('total'),
      members: value('members'),
      visitors: value('visitors'),
      children: value('children'),
      manual: value('manual'),
      qr: value('qr'),
    );
  }
}

class EventAttendanceRow {
  const EventAttendanceRow({
    required this.id,
    required this.participantType,
    required this.checkInMethod,
    required this.checkedInAt,
    this.checkedOutAt,
    this.name,
    this.phone,
    this.notes,
  });

  final String id;
  final String participantType;
  final String checkInMethod;
  final DateTime checkedInAt;
  final DateTime? checkedOutAt;
  final String? name;
  final String? phone;
  final String? notes;

  String get participantLabel => switch (participantType) {
        'visitor' => 'Visitante',
        'child' => 'Crianca',
        'leader' => 'Lider',
        'guest' => 'Convidado',
        _ => 'Membro',
      };

  factory EventAttendanceRow.fromMap(Map<String, dynamic> map) {
    final profile = switch (map['profile']) {
      Map<String, dynamic> value => value,
      _ => const <String, dynamic>{},
    };
    final visitor = switch (map['visitor']) {
      Map<String, dynamic> value => value,
      _ => const <String, dynamic>{},
    };
    return EventAttendanceRow(
      id: (map['id'] as String?) ?? '',
      participantType: (map['participant_type'] as String?) ?? 'member',
      checkInMethod: (map['check_in_method'] as String?) ?? 'manual',
      checkedInAt: DateTime.tryParse((map['checked_in_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      checkedOutAt: DateTime.tryParse((map['checked_out_at'] as String?) ?? ''),
      name: (profile['full_name'] as String?) ??
          (visitor['full_name'] as String?) ??
          map['participant_name'] as String?,
      phone: (profile['phone'] as String?) ?? visitor['phone'] as String?,
      notes: map['notes'] as String?,
    );
  }
}

class ChildCheckinRecord {
  const ChildCheckinRecord({
    required this.id,
    required this.childName,
    required this.securityCode,
    required this.checkedInAt,
    this.guardianName,
    this.guardianPhone,
    this.roomName,
    this.checkedOutAt,
  });

  final String id;
  final String childName;
  final String securityCode;
  final DateTime checkedInAt;
  final String? guardianName;
  final String? guardianPhone;
  final String? roomName;
  final DateTime? checkedOutAt;

  factory ChildCheckinRecord.fromMap(Map<String, dynamic> map) {
    return ChildCheckinRecord(
      id: (map['id'] as String?) ?? '',
      childName: (map['child_name'] as String?) ?? 'Crianca',
      securityCode: (map['security_code'] as String?) ?? '',
      checkedInAt: DateTime.tryParse((map['checked_in_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      guardianName: map['guardian_name'] as String?,
      guardianPhone: map['guardian_phone'] as String?,
      roomName: map['room_name'] as String?,
      checkedOutAt: DateTime.tryParse((map['checked_out_at'] as String?) ?? ''),
    );
  }
}

class ChurchBirthdayMember {
  const ChurchBirthdayMember({
    required this.profileId,
    required this.fullName,
    this.phone,
    this.birthDate,
    required this.daysUntil,
  });

  final String profileId;
  final String fullName;
  final String? phone;
  final DateTime? birthDate;
  final int daysUntil;

  factory ChurchBirthdayMember.fromMap(Map<String, dynamic> map) {
    return ChurchBirthdayMember(
      profileId: (map['profile_id'] as String?) ?? '',
      fullName: (map['full_name'] as String?) ?? 'Membro',
      phone: map['phone'] as String?,
      birthDate: DateTime.tryParse((map['birth_date'] as String?) ?? ''),
      daysUntil: (map['days_until'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlatformCalendarMetrics {
  const PlatformCalendarMetrics({
    required this.churches,
    required this.events,
    required this.upcomingEvents,
    required this.openCheckins,
    required this.attendances,
    required this.birthdaysNext31Days,
  });

  final int churches;
  final int events;
  final int upcomingEvents;
  final int openCheckins;
  final int attendances;
  final int birthdaysNext31Days;

  factory PlatformCalendarMetrics.fromMap(Map<String, dynamic> map) {
    int value(String key) => (map[key] as num?)?.toInt() ?? 0;
    return PlatformCalendarMetrics(
      churches: value('churches'),
      events: value('events'),
      upcomingEvents: value('upcoming_events'),
      openCheckins: value('open_checkins'),
      attendances: value('attendances'),
      birthdaysNext31Days: value('birthdays_next_31_days'),
    );
  }
}
