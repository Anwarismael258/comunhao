import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/church_calendar_models.dart';

abstract class CalendarRepository {
  Future<List<CalendarEventOccurrence>> fetchOccurrences(
    String churchId, {
    String? eventId,
  });
  Future<List<CalendarEventOccurrence>> generateEventOccurrences(
    String eventId,
  );
  Future<String> openEventCheckin(String occurrenceId, {int minutes});
  Future<void> closeEventCheckin(String occurrenceId);
  Future<void> manualCheckInEvent({
    required String eventId,
    String? occurrenceId,
    String? profileId,
    String? visitorName,
    String? visitorPhone,
    String? notes,
  });
  Future<void> checkInWithQrPayload(String qrPayload);
  Future<EventAttendanceSummary> fetchAttendanceSummary(String eventId);
  Future<List<EventAttendanceRow>> fetchAttendanceRows(String eventId);
  Future<ChildCheckinRecord> manualChildCheckInEvent({
    required String eventId,
    String? occurrenceId,
    required String childName,
    String? guardianName,
    String? guardianPhone,
    String? roomName,
    String? notes,
  });
  Future<ChildCheckinRecord> checkOutChildEvent({
    required String childCheckinId,
    required String securityCode,
    String? pickupPerson,
  });
  Future<int> prepareInternalReminders(String churchId);
  Future<List<ChurchBirthdayMember>> fetchBirthdays(
    String churchId, {
    int days,
  });
  Future<void> sendBirthdayMessage({
    required String churchId,
    required String profileId,
    required String message,
  });
  Future<PlatformCalendarMetrics> fetchPlatformCalendarMetrics();
}

class SupabaseCalendarRepository implements CalendarRepository {
  SupabaseCalendarRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<CalendarEventOccurrence>> fetchOccurrences(
    String churchId, {
    String? eventId,
  }) async {
    var query = _client.from('event_occurrences').select('''
          id,
          event_id,
          church_id,
          occurrence_start_at,
          occurrence_end_at,
          status,
          checkin_opens_at,
          checkin_closes_at,
          qr_expires_at,
          qr_closed_at,
          override_title,
          override_location
        ''').eq('church_id', churchId);

    if (eventId != null) {
      query = query.eq('event_id', eventId);
    }

    final rows = await query
        .gte(
          'occurrence_start_at',
          DateTime.now()
              .subtract(const Duration(days: 7))
              .toUtc()
              .toIso8601String(),
        )
        .order('occurrence_start_at')
        .limit(50);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(CalendarEventOccurrence.fromMap)
        .toList();
  }

  @override
  Future<List<CalendarEventOccurrence>> generateEventOccurrences(
    String eventId,
  ) async {
    final rows = await _client.rpc(
      'generate_event_occurrences',
      params: {'p_event_id': eventId},
    );

    return (rows as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(CalendarEventOccurrence.fromMap)
        .toList();
  }

  @override
  Future<String> openEventCheckin(String occurrenceId,
      {int minutes = 180}) async {
    final result = await _client.rpc(
      'open_event_checkin',
      params: {
        'p_occurrence_id': occurrenceId,
        'p_minutes': minutes,
      },
    );
    return result.toString();
  }

  @override
  Future<void> closeEventCheckin(String occurrenceId) async {
    await _client.rpc(
      'close_event_checkin',
      params: {'p_occurrence_id': occurrenceId},
    );
  }

  @override
  Future<void> manualCheckInEvent({
    required String eventId,
    String? occurrenceId,
    String? profileId,
    String? visitorName,
    String? visitorPhone,
    String? notes,
  }) async {
    await _client.rpc(
      'manual_check_in_event',
      params: {
        'p_event_id': eventId,
        'p_occurrence_id': occurrenceId,
        'p_profile_id': profileId,
        'p_visitor_name': visitorName,
        'p_visitor_phone': visitorPhone,
        'p_notes': notes,
      },
    );
  }

  @override
  Future<void> checkInWithQrPayload(String qrPayload) async {
    await _client.rpc(
      'check_in_event_with_token',
      params: {'p_qr_payload': qrPayload.trim()},
    );
  }

  @override
  Future<EventAttendanceSummary> fetchAttendanceSummary(String eventId) async {
    final result = await _client.rpc(
      'get_event_attendance_summary',
      params: {'p_event_id': eventId},
    );
    return EventAttendanceSummary.fromMap(Map<String, dynamic>.from(result));
  }

  @override
  Future<List<EventAttendanceRow>> fetchAttendanceRows(String eventId) async {
    final rows = await _client.from('event_attendance').select('''
          id,
          participant_type,
          check_in_method,
          checked_in_at,
          checked_out_at,
          notes,
          profile:profiles (
            full_name,
            phone
          ),
          visitor:church_visitors (
            full_name,
            phone
          )
        ''').eq('event_id', eventId).order('checked_in_at');

    return rows
        .whereType<Map<String, dynamic>>()
        .map(EventAttendanceRow.fromMap)
        .toList();
  }

  @override
  Future<ChildCheckinRecord> manualChildCheckInEvent({
    required String eventId,
    String? occurrenceId,
    required String childName,
    String? guardianName,
    String? guardianPhone,
    String? roomName,
    String? notes,
  }) async {
    final result = await _client.rpc(
      'manual_child_check_in_event',
      params: {
        'p_event_id': eventId,
        'p_occurrence_id': occurrenceId,
        'p_child_name': childName,
        'p_guardian_name': guardianName,
        'p_guardian_phone': guardianPhone,
        'p_room_name': roomName,
        'p_notes': notes,
      },
    );
    return ChildCheckinRecord.fromMap(Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<ChildCheckinRecord> checkOutChildEvent({
    required String childCheckinId,
    required String securityCode,
    String? pickupPerson,
  }) async {
    final result = await _client.rpc(
      'check_out_child_event',
      params: {
        'p_child_checkin_id': childCheckinId,
        'p_security_code': securityCode,
        'p_pickup_person': pickupPerson,
      },
    );
    return ChildCheckinRecord.fromMap(Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<int> prepareInternalReminders(String churchId) async {
    final result = await _client.rpc(
      'prepare_event_internal_reminders',
      params: {'p_church_id': churchId},
    );
    return (result as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<ChurchBirthdayMember>> fetchBirthdays(
    String churchId, {
    int days = 31,
  }) async {
    final rows = await _client.rpc(
      'get_visible_birthdays',
      params: {
        'p_church_id': churchId,
        'p_days': days,
      },
    );

    return (rows as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(ChurchBirthdayMember.fromMap)
        .toList();
  }

  @override
  Future<void> sendBirthdayMessage({
    required String churchId,
    required String profileId,
    required String message,
  }) async {
    await _client.rpc(
      'send_birthday_internal_message',
      params: {
        'p_church_id': churchId,
        'p_profile_id': profileId,
        'p_message': message,
      },
    );
  }

  @override
  Future<PlatformCalendarMetrics> fetchPlatformCalendarMetrics() async {
    final result = await _client.rpc('get_church_calendar_metrics');
    return PlatformCalendarMetrics.fromMap(Map<String, dynamic>.from(result));
  }
}
