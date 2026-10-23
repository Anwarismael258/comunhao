import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/internal_notification.dart';

class NotificationRepository {
  NotificationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _profileId {
    final id = _client.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw StateError('Utilizador nao autenticado.');
    }
    return id;
  }

  Future<List<InternalNotification>> fetchNotifications(
      {int limit = 40}) async {
    final rows = await _client
        .from('internal_notifications')
        .select('*, churches(name)')
        .eq('recipient_profile_id', _profileId)
        .filter('archived_at', 'is', null)
        .order('created_at', ascending: false)
        .limit(limit);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(InternalNotification.fromMap)
        .toList(growable: false);
  }

  Future<int> fetchUnreadCount() async {
    final rows = await _client
        .from('internal_notifications')
        .select('id')
        .eq('recipient_profile_id', _profileId)
        .filter('read_at', 'is', null)
        .filter('archived_at', 'is', null)
        .limit(100);

    return rows.length;
  }

  Future<void> markRead(String notificationId) async {
    await _client.rpc(
      'mark_internal_notification_read',
      params: {'p_notification_id': notificationId},
    );
  }

  Future<void> markAllRead() async {
    await _client.rpc('mark_all_internal_notifications_read');
  }

  Future<void> archive(String notificationId) async {
    await _client.rpc(
      'archive_internal_notification',
      params: {'p_notification_id': notificationId},
    );
  }

  Future<NotificationPreferences> fetchPreferences() async {
    await _client.rpc('ensure_notification_preferences');
    final row = await _client
        .from('notification_preferences')
        .select()
        .eq('profile_id', _profileId)
        .single();

    return NotificationPreferences.fromMap(row);
  }

  Future<NotificationPreferences> savePreferences(
    NotificationPreferences preferences,
  ) async {
    final row = await _client
        .from('notification_preferences')
        .update(preferences.toUpdateMap())
        .eq('profile_id', _profileId)
        .select()
        .single();

    return NotificationPreferences.fromMap(row);
  }
}
