import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/church_announcement.dart';
import '../models/church_birthday.dart';
import '../models/church_branding.dart';
import '../models/church_event.dart';
import '../models/church_member.dart';
import '../models/donation_campaign.dart';
import '../models/member_event_registration.dart';
import '../models/member_donation_record.dart';
import '../models/member_prayer_request.dart';
import '../models/member_wallet_summary.dart';
import '../models/prayer_response.dart';

abstract class ChurchRepository {
  Future<List<ChurchBranding>> fetchChurches({String? query});
  Future<ChurchBranding?> fetchChurchBySlug(String slug);
  Future<ChurchBranding?> fetchChurchByCode(String code);
  Future<ChurchBranding?> fetchChurchForUser(String userId);
  Future<List<ChurchBranding>> fetchChurchesForUser(String userId);
  Future<ChurchMember?> fetchMemberForUser(String userId, {String? churchId});
  Future<ChurchMember> requestMembership(String churchId);
  Future<ChurchMember> acceptInvite(String token);
  Future<List<ChurchAnnouncement>> fetchAnnouncements(String churchId);
  Future<List<ChurchEvent>> fetchUpcomingEvents(String churchId);
  Future<List<DonationCampaign>> fetchActiveCampaigns(String churchId);
  Future<List<ChurchCommunication>> fetchChurchCommunications(String churchId);
  Future<List<ChurchBirthday>> fetchUpcomingBirthdays(
    String churchId, {
    int limit,
  });
  Future<List<MemberEventRegistration>> fetchOwnEventRegistrations(
    String churchId,
  );
  Future<MemberEventRegistration> registerForEvent(String eventId);
  Future<MemberEventRegistration> cancelEventRegistration(String eventId);
  Future<MemberEventRegistration> checkInToEvent(String registrationId);
  Future<void> checkInWithQrPayload(String qrPayload);
  Future<MemberWalletSummary?> fetchMemberWallet();
  Future<void> updateMyProfileName(String fullName);
  Future<MemberWalletSummary> depositMemberWallet({
    required num amount,
    String? provider,
  });
  Future<List<MemberDonationRecord>> fetchOwnDonations(String churchId);
  Future<List<MemberPrayerRequest>> fetchOwnPrayerRequests(String churchId);
  Future<List<MemberPrayerRequest>> fetchPrayerFeed(String churchId);
  Future<MemberPrayerRequest> createPrayerRequest({
    required String churchId,
    required String title,
    required String description,
    required String visibility,
    required bool anonymousRequest,
    required bool allowResponses,
  });
  Future<List<PrayerResponse>> fetchPrayerResponses(String prayerRequestId);
  Future<PrayerResponse> createPrayerResponse({
    required String prayerRequestId,
    required String body,
  });
}

class SupabaseChurchRepository implements ChurchRepository {
  SupabaseChurchRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _currentUserId => _client.auth.currentUser?.id;

  static const _churchSelect = '''
    id,
    name,
    slug,
    join_code,
    app_name,
    logo_url,
    primary_color,
    secondary_color,
    phone,
    email,
    city,
    country,
    tagline,
    hero_title,
    hero_subtitle,
    default_currency,
    subscription_status,
    trial_ends_at,
    subscription_ends_at,
    church_payment_settings (
      provider,
      account_name,
      account_number,
      instructions,
      is_primary
    )
  ''';

  static const _churchSelectWithSubscription = '''
    $_churchSelect,
    church_subscriptions (
      church_id,
      plan_code,
      status,
      trial_ends_at,
      current_period_ends_at,
      grace_period_ends_at
    )
  ''';

  Map<String, dynamic>? _pickCurrentMembershipRow(List<dynamic> rows) {
    final memberships = rows.whereType<Map<String, dynamic>>().toList();
    if (memberships.isEmpty) {
      return null;
    }

    for (final membership in memberships) {
      if ((membership['status'] as String?) == 'active') {
        return membership;
      }
    }

    return memberships.first;
  }

  Future<List<Map<String, dynamic>>> _fetchChurchRows({
    required String select,
    String? query,
    bool activeOnly = true,
  }) async {
    final request = _client.from('churches').select(select);

    if (activeOnly) {
      request.eq('active', true);
    }

    if (query != null && query.isNotEmpty) {
      final safeQuery = query.replaceAll(',', '');
      request.or(
        'name.ilike.%$safeQuery%,slug.ilike.%$safeQuery%,join_code.ilike.%$safeQuery%,phone.ilike.%$safeQuery%',
      );
    }

    final rows = await request.order('name').limit(50);
    return rows.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  @override
  Future<List<ChurchBranding>> fetchChurches({String? query}) async {
    final normalizedQuery = query?.trim();
    final effectiveQuery = normalizedQuery == null || normalizedQuery.isEmpty
        ? null
        : normalizedQuery;

    try {
      final rows = await _client.rpc(
        'list_public_churches_with_member_counts',
        params: {
          'p_query': effectiveQuery,
          'p_limit': 50,
        },
      );
      final churches = (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ChurchBranding.fromMap)
          .toList(growable: false);
      if (churches.isNotEmpty) {
        return churches;
      }
    } catch (_) {
      // Older databases may not have the public search RPC yet.
    }

    List<Map<String, dynamic>> rows = const [];
    try {
      rows = await _fetchChurchRows(
        select: _churchSelectWithSubscription,
        query: effectiveQuery,
      );
    } catch (_) {
      rows = const [];
    }

    if (rows.isEmpty) {
      rows = await _fetchChurchRows(
        select: _churchSelect,
        query: effectiveQuery,
      );
    }

    if (rows.isEmpty) {
      try {
        rows = await _fetchChurchRows(
          select: _churchSelect,
          query: effectiveQuery,
          activeOnly: false,
        );
      } catch (_) {
        rows = const [];
      }
    }

    return _withActiveMemberCounts(rows.map(ChurchBranding.fromMap).toList());
  }

  Future<List<ChurchBranding>> _withActiveMemberCounts(
    List<ChurchBranding> churches,
  ) async {
    if (churches.isEmpty) return churches;
    final ids = churches.map((church) => church.id).toList(growable: false);
    try {
      final rows = await _client
          .from('memberships')
          .select('church_id')
          .inFilter('church_id', ids)
          .eq('status', 'active')
          .eq('role', 'member')
          .limit(10000);
      final counts = <String, int>{};
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final churchId = row['church_id'] as String?;
        if (churchId == null || churchId.isEmpty) continue;
        counts[churchId] = (counts[churchId] ?? 0) + 1;
      }
      return churches
          .map(
            (church) => church.copyWith(
              activeMemberCount: counts[church.id] ?? church.activeMemberCount,
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return churches;
    }
  }

  @override
  Future<ChurchBranding?> fetchChurchBySlug(String slug) async {
    final normalizedSlug = slug.trim();
    if (normalizedSlug.isEmpty) {
      return null;
    }

    final row = await _client
        .from('churches')
        .select(_churchSelectWithSubscription)
        .eq('active', true)
        .eq('slug', normalizedSlug)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return ChurchBranding.fromMap(row);
  }

  @override
  Future<ChurchBranding?> fetchChurchByCode(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      return null;
    }

    final row = await _client
        .from('churches')
        .select(_churchSelectWithSubscription)
        .eq('active', true)
        .eq('join_code', normalizedCode)
        .maybeSingle();

    if (row != null) {
      return ChurchBranding.fromMap(row);
    }

    return fetchChurchBySlug(code.trim());
  }

  @override
  Future<ChurchBranding?> fetchChurchForUser(String userId) async {
    final churches = await fetchChurchesForUser(userId);
    return churches.isEmpty ? null : churches.first;
  }

  @override
  Future<List<ChurchBranding>> fetchChurchesForUser(String userId) async {
    final rows = await _client
        .from('memberships')
        .select('''
          role,
          status,
          created_at,
          church:churches (
            $_churchSelectWithSubscription
          )
        ''')
        .eq('profile_id', userId)
        .order('created_at', ascending: false)
        .limit(20);

    return rows
        .whereType<Map<String, dynamic>>()
        .where((row) => row['status'] == 'active')
        .map((row) => row['church'])
        .whereType<Map<String, dynamic>>()
        .map(ChurchBranding.fromMap)
        .toList(growable: false);
  }

  @override
  Future<ChurchMember?> fetchMemberForUser(String userId,
      {String? churchId}) async {
    var request = _client.from('memberships').select('''
          id,
          church_id,
          profile_id,
          role,
          status,
          member_code,
          baptism_date,
          created_at,
          profile:profiles (
            id,
            full_name,
            phone,
            birth_date,
            avatar_url,
            avatar_storage_path
          ),
          ministry_members (
            role,
            ministry:church_ministries (
              name
            )
          )
        ''').eq('profile_id', userId);
    if (churchId != null && churchId.isNotEmpty)
      request = request.eq('church_id', churchId);
    final rows = await request.order('created_at', ascending: false).limit(20);

    final row = _pickCurrentMembershipRow(rows);

    if (row == null) {
      return null;
    }

    final authMetadata = _client.auth.currentUser?.userMetadata;
    final metadataName = (authMetadata?['full_name'] as String?) ??
        (authMetadata?['name'] as String?);

    return _withSignedAvatarUrl(
      ChurchMember.fromMap(row, fallbackFullName: metadataName),
    );
  }

  @override
  Future<ChurchMember> requestMembership(String churchId) async {
    final row = await _client.rpc(
      'request_comunhao_membership',
      params: {'p_church_id': churchId},
    );
    final user = _client.auth.currentUser;
    return ChurchMember.fromMap(
      Map<String, dynamic>.from(row as Map),
      fallbackFullName: (user?.userMetadata?['full_name'] as String?) ??
          (user?.userMetadata?['name'] as String?),
    );
  }

  @override
  Future<ChurchMember> acceptInvite(String token) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) {
      throw ArgumentError('Introduz o codigo do convite.');
    }
    final row = await _client.rpc(
      'accept_comunhao_invite',
      params: {'p_token': cleanToken},
    );
    final user = _client.auth.currentUser;
    return ChurchMember.fromMap(
      Map<String, dynamic>.from(row as Map),
      fallbackFullName: (user?.userMetadata?['full_name'] as String?) ??
          (user?.userMetadata?['name'] as String?),
    );
  }

  Future<ChurchMember> _withSignedAvatarUrl(ChurchMember member) async {
    final storagePath = member.avatarStoragePath?.trim();
    if (storagePath == null || storagePath.isEmpty) {
      return member;
    }

    try {
      final signedUrl = await _client.storage
          .from('profile-media')
          .createSignedUrl(storagePath, 60 * 60);
      return member.copyWith(avatarUrl: signedUrl);
    } catch (_) {
      return member;
    }
  }

  @override
  Future<List<ChurchAnnouncement>> fetchAnnouncements(String churchId) async {
    List<dynamic> rows;
    try {
      rows = await _client
          .from('announcements')
          .select(
            'id, title, body, image_url, pastoral_publication_id, pinned, published_at, created_at',
          )
          .eq('church_id', churchId)
          .not('published_at', 'is', null)
          .order('pinned', ascending: false)
          .order('created_at', ascending: false)
          .limit(80);
    } catch (_) {
      try {
        rows = await _client
            .from('announcements')
            .select(
              'id, title, body, image_url, pinned, published_at, created_at',
            )
            .eq('church_id', churchId)
            .not('published_at', 'is', null)
            .order('pinned', ascending: false)
            .order('created_at', ascending: false)
            .limit(80);
      } catch (_) {
        rows = await _client
            .from('announcements')
            .select('id, title, body, pinned, published_at, created_at')
            .eq('church_id', churchId)
            .not('published_at', 'is', null)
            .order('pinned', ascending: false)
            .order('created_at', ascending: false)
            .limit(80);
      }
    }

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ChurchAnnouncement.fromMap)
        .toList();
  }

  @override
  Future<List<ChurchCommunication>> fetchChurchCommunications(
    String churchId,
  ) async {
    final rows = await _client
        .from('church_communications')
        .select('''
          id,
          church_id,
          channel,
          audience_type,
          target_role,
          ministry_id,
          membership_id,
          title,
          body,
          status,
          scheduled_at,
          sent_at,
          created_at,
          ministry:church_ministries (
            id,
            name
          ),
          membership:memberships (
            id,
            profile:profiles (
              full_name
            )
          )
        ''')
        .eq('church_id', churchId)
        .or('status.eq.queued,status.eq.sent')
        .order('created_at', ascending: false)
        .limit(12);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ChurchCommunication.fromMap)
        .toList();
  }

  @override
  Future<List<ChurchEvent>> fetchUpcomingEvents(String churchId) async {
    List<dynamic> rows;
    try {
      rows = await _client
          .from('events')
          .select(
            'id, title, event_type, description, location, cover_image_url, pastoral_publication_id, starts_at, ends_at, registration_required, capacity, registration_fee_mzn, created_at',
          )
          .eq('church_id', churchId)
          .eq('status', 'published')
          .eq('is_demo', false)
          .gte('starts_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(80);
    } catch (_) {
      try {
        rows = await _client
            .from('events')
            .select(
              'id, title, event_type, description, location, cover_image_url, starts_at, ends_at, registration_required, capacity, registration_fee_mzn, created_at',
            )
            .eq('church_id', churchId)
            .eq('event_status', 'published')
            .eq('is_demo', false)
            .gte('starts_at', DateTime.now().toUtc().toIso8601String())
            .order('created_at', ascending: false)
            .limit(80);
      } catch (_) {
        rows = await _client
            .from('events')
            .select(
              'id, title, description, location, starts_at, ends_at, registration_required, capacity, created_at',
            )
            .eq('church_id', churchId)
            .gte('starts_at', DateTime.now().toUtc().toIso8601String())
            .order('created_at', ascending: false)
            .limit(80);
      }
    }

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ChurchEvent.fromMap)
        .toList();
  }

  @override
  Future<List<ChurchBirthday>> fetchUpcomingBirthdays(
    String churchId, {
    int limit = 6,
  }) async {
    final rows = await _client.rpc(
      'get_church_birthdays',
      params: {
        'p_church_id': churchId,
        'p_limit': limit,
      },
    );

    return (rows as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(ChurchBirthday.fromMap)
        .toList();
  }

  @override
  Future<List<MemberEventRegistration>> fetchOwnEventRegistrations(
    String churchId,
  ) async {
    final userId = _currentUserId;
    if (userId == null) {
      return const [];
    }

    final rows = await _client
        .from('event_registrations')
        .select('''
          id,
          event_id,
          profile_id,
          status,
          check_in_code,
          checked_in_at,
          payment_status,
          waiting_list_position,
          created_at,
          event:events (
            church_id
          )
        ''')
        .eq('profile_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return rows
        .whereType<Map<String, dynamic>>()
        .where((row) {
          final rawEvent = row['event'];
          final event = switch (rawEvent) {
            Map<String, dynamic> value => value,
            List<dynamic> value
                when value.isNotEmpty && value.first is Map<String, dynamic> =>
              value.first as Map<String, dynamic>,
            _ => const <String, dynamic>{},
          };
          return event['church_id'] == churchId;
        })
        .map(MemberEventRegistration.fromMap)
        .toList();
  }

  @override
  Future<MemberEventRegistration> registerForEvent(String eventId) async {
    final result = await _client.rpc(
      'register_for_event',
      params: {'p_event_id': eventId},
    );
    return MemberEventRegistration.fromMap(
      Map<String, dynamic>.from(result as Map),
    );
  }

  @override
  Future<MemberEventRegistration> cancelEventRegistration(
      String eventId) async {
    final result = await _client.rpc(
      'cancel_event_registration',
      params: {'p_event_id': eventId},
    );
    return MemberEventRegistration.fromMap(
      Map<String, dynamic>.from(result as Map),
    );
  }

  @override
  Future<MemberEventRegistration> checkInToEvent(String registrationId) async {
    final result = await _client.rpc(
      'check_in_to_event',
      params: {'p_registration_id': registrationId},
    );
    return MemberEventRegistration.fromMap(
      Map<String, dynamic>.from(result as Map),
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
  Future<MemberWalletSummary?> fetchMemberWallet() async {
    final row = await _client.rpc('get_member_wallet_summary');
    if (row == null) {
      return null;
    }
    return MemberWalletSummary.fromMap(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<void> updateMyProfileName(String fullName) async {
    final userId = _currentUserId;
    final cleanName = fullName.trim();
    if (userId == null || userId.isEmpty) {
      throw StateError('Sessao expirada. Entra novamente para editar o nome.');
    }
    if (cleanName.length < 2) {
      throw ArgumentError('Introduz um nome valido.');
    }

    await _client
        .from('profiles')
        .update({'full_name': cleanName}).eq('id', userId);
  }

  @override
  Future<MemberWalletSummary> depositMemberWallet({
    required num amount,
    String? provider,
  }) async {
    final row = await _client.rpc(
      'deposit_member_wallet',
      params: {
        'p_amount': amount,
        'p_provider': provider,
      },
    );
    return MemberWalletSummary.fromMap(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<List<DonationCampaign>> fetchActiveCampaigns(String churchId) async {
    List<dynamic> rows;
    try {
      rows = await _client.rpc(
        'get_active_campaigns_with_progress',
        params: {'p_church_id': churchId},
      ) as List<dynamic>;
    } catch (_) {
      try {
        rows = await _client
            .from('donation_campaigns')
            .select(
              'id, title, description, image_url, pastoral_publication_id, target_amount, start_at, end_at, active, created_at, is_demo',
            )
            .eq('church_id', churchId)
            .eq('active', true)
            .eq('is_demo', false)
            .order('created_at', ascending: false)
            .limit(80);
      } catch (_) {
        try {
          rows = await _client
              .from('donation_campaigns')
              .select(
                'id, title, description, image_url, target_amount, start_at, end_at, active, created_at, is_demo',
              )
              .eq('church_id', churchId)
              .eq('active', true)
              .eq('is_demo', false)
              .order('created_at', ascending: false)
              .limit(80);
        } catch (_) {
          rows = await _client
              .from('donation_campaigns')
              .select(
                'id, title, description, target_amount, start_at, end_at, active, created_at',
              )
              .eq('church_id', churchId)
              .eq('active', true)
              .order('created_at', ascending: false)
              .limit(80);
        }
      }
    }

    return rows
        .whereType<Map<String, dynamic>>()
        .where((row) => row['is_demo'] != true)
        .map(DonationCampaign.fromMap)
        .toList();
  }

  @override
  Future<List<MemberDonationRecord>> fetchOwnDonations(String churchId) async {
    final userId = _currentUserId;
    if (userId == null) {
      return const [];
    }

    final rows = await _client
        .from('donations')
        .select('''
          id,
          amount,
          currency,
          donation_type,
          provider,
          status,
          created_at,
          campaign:donation_campaigns (
            title
          )
        ''')
        .eq('church_id', churchId)
        .eq('profile_id', userId)
        .order('created_at', ascending: false)
        .limit(20);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(MemberDonationRecord.fromMap)
        .toList();
  }

  @override
  Future<List<MemberPrayerRequest>> fetchOwnPrayerRequests(
      String churchId) async {
    final userId = _currentUserId;
    if (userId == null) {
      return const [];
    }

    final rows = await _client
        .from('prayer_requests')
        .select('''
          church_id,
          profile_id,
          id,
          title,
          description,
          is_private,
          visibility,
          anonymous_request,
          allow_responses,
          status,
          created_at,
          responses:prayer_request_responses(id)
        ''')
        .eq('church_id', churchId)
        .eq('profile_id', userId)
        .order('created_at', ascending: false)
        .limit(20);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(MemberPrayerRequest.fromMap)
        .toList();
  }

  @override
  Future<List<MemberPrayerRequest>> fetchPrayerFeed(String churchId) async {
    final rows = await _client
        .from('prayer_requests')
        .select('''
          church_id,
          profile_id,
          id,
          title,
          description,
          is_private,
          visibility,
          anonymous_request,
          allow_responses,
          status,
          created_at,
          responses:prayer_request_responses(id)
        ''')
        .eq('church_id', churchId)
        .or('visibility.eq.public,visibility.eq.anonymous,is_private.eq.false')
        .neq('visibility', 'private')
        .order('created_at', ascending: false)
        .limit(24);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(MemberPrayerRequest.fromMap)
        .toList();
  }

  @override
  Future<MemberPrayerRequest> createPrayerRequest({
    required String churchId,
    required String title,
    required String description,
    required String visibility,
    required bool anonymousRequest,
    required bool allowResponses,
  }) async {
    final normalizedVisibility =
        visibility == 'anonymous' ? 'anonymous' : visibility;
    final isPrivate = normalizedVisibility == 'private';
    final row = await _client.from('prayer_requests').insert({
      'church_id': churchId,
      'profile_id': _client.auth.currentUser?.id,
      'title': title.trim(),
      'description': description.trim(),
      'is_private': isPrivate,
      'visibility': normalizedVisibility,
      'anonymous_request':
          anonymousRequest || normalizedVisibility == 'anonymous',
      'allow_responses': allowResponses,
      'status': 'new',
    }).select('''
          church_id,
          profile_id,
          id,
          title,
          description,
          is_private,
          visibility,
          anonymous_request,
          allow_responses,
          status,
          created_at,
          responses:prayer_request_responses(id)
        ''').single();

    return MemberPrayerRequest.fromMap(row);
  }

  @override
  Future<List<PrayerResponse>> fetchPrayerResponses(
      String prayerRequestId) async {
    final rows = await _client.from('prayer_request_responses').select('''
          id,
          prayer_request_id,
          church_id,
          responder_profile_id,
          body,
          created_at
        ''').eq('prayer_request_id', prayerRequestId).order('created_at');

    return rows
        .whereType<Map<String, dynamic>>()
        .map(PrayerResponse.fromMap)
        .toList();
  }

  @override
  Future<PrayerResponse> createPrayerResponse({
    required String prayerRequestId,
    required String body,
  }) async {
    final row = await _client.from('prayer_request_responses').insert({
      'prayer_request_id': prayerRequestId,
      'responder_profile_id': _currentUserId,
      'body': body.trim(),
    }).select('''
          id,
          prayer_request_id,
          church_id,
          responder_profile_id,
          body,
          created_at
        ''').single();

    return PrayerResponse.fromMap(row);
  }
}

class DemoChurchRepository implements ChurchRepository {
  DemoChurchRepository({ChurchBranding? church})
      : _church = church ?? ChurchBranding.demo();

  final ChurchBranding _church;

  @override
  Future<List<ChurchBranding>> fetchChurches({String? query}) async {
    if (query == null || query.trim().isEmpty) {
      return [_church];
    }

    final q = query.trim().toLowerCase();
    final matches = _church.name.toLowerCase().contains(q) ||
        _church.slug.toLowerCase().contains(q) ||
        (_church.joinCode?.toLowerCase().contains(q) ?? false);

    return matches ? [_church] : [];
  }

  @override
  Future<ChurchBranding?> fetchChurchBySlug(String slug) async {
    return _church.slug == slug.trim() ? _church : null;
  }

  @override
  Future<ChurchBranding?> fetchChurchByCode(String code) async {
    final normalized = code.trim().toUpperCase();
    return _church.joinCode == normalized || _church.slug == code.trim()
        ? _church
        : null;
  }

  @override
  Future<ChurchBranding?> fetchChurchForUser(String userId) async => _church;

  @override
  Future<List<ChurchBranding>> fetchChurchesForUser(String userId) async =>
      [_church];

  @override
  Future<ChurchMember?> fetchMemberForUser(String userId,
      {String? churchId}) async {
    return const ChurchMember(
      membershipId: 'demo-membership',
      id: 'demo-member',
      churchId: 'demo-church',
      fullName: 'Sara',
      role: 'pastor',
      status: 'active',
      memberCode: 'VIDA-PASTOR',
      phone: '+258877688695',
      ministries: ['Louvor'],
    );
  }

  @override
  Future<ChurchMember> requestMembership(String churchId) async {
    return ChurchMember(
      membershipId: 'demo-request',
      id: 'demo-user',
      churchId: churchId,
      fullName: 'Membro',
      role: 'member',
      status: 'pending',
    );
  }

  @override
  Future<ChurchMember> acceptInvite(String token) async => ChurchMember(
        membershipId: 'demo-invite',
        id: 'demo-user',
        churchId: _church.id,
        fullName: 'Membro',
        role: 'member',
        status: 'active',
      );

  @override
  Future<List<ChurchAnnouncement>> fetchAnnouncements(String churchId) async {
    final now = DateTime.now();
    return [
      ChurchAnnouncement(
        id: 'a1',
        title: 'Campanha de construcao',
        body: 'Meta do mes: 150.000 MZN.',
        pinned: true,
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      ChurchAnnouncement(
        id: 'a2',
        title: 'Conferencia da juventude',
        body: 'Inscricoes abertas ate sexta-feira.',
        pinned: false,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
    ];
  }

  @override
  Future<List<ChurchCommunication>> fetchChurchCommunications(
    String churchId,
  ) async {
    return [
      ChurchCommunication(
        id: 'comm-1',
        churchId: 'demo-church',
        channel: 'push',
        audienceType: 'all',
        title: 'Mensagem do pastor',
        body: 'Continua firme na fe e prepara-te para o culto de domingo.',
        status: 'sent',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    ];
  }

  @override
  Future<List<ChurchEvent>> fetchUpcomingEvents(String churchId) async {
    final now = DateTime.now();
    return [
      ChurchEvent(
        id: 'e1',
        title: 'Culto de domingo',
        eventType: 'culto',
        location: 'Templo central',
        startsAt: now.add(const Duration(days: 1)),
        registrationRequired: false,
        createdAt: now.subtract(const Duration(minutes: 20)),
      ),
      ChurchEvent(
        id: 'e2',
        title: 'Encontro de lideres',
        eventType: 'reuniao',
        location: 'Sala 2',
        startsAt: now.add(const Duration(days: 3)),
        registrationRequired: true,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  @override
  Future<List<ChurchBirthday>> fetchUpcomingBirthdays(
    String churchId, {
    int limit = 6,
  }) async {
    final now = DateTime.now();
    return [
      ChurchBirthday(
        profileId: 'demo-member',
        fullName: 'Sara',
        role: 'pastor',
        birthDate: DateTime(1988, 9, 12),
        nextBirthday: DateTime(now.year, now.month, now.day).add(
          const Duration(days: 4),
        ),
      ),
      ChurchBirthday(
        profileId: 'demo-member-2',
        fullName: 'Membro Vida Nova',
        role: 'member',
        birthDate: DateTime(1994, 7, 20),
        nextBirthday: DateTime(now.year, now.month, now.day).add(
          const Duration(days: 12),
        ),
      ),
    ].take(limit).toList(growable: false);
  }

  @override
  Future<List<MemberEventRegistration>> fetchOwnEventRegistrations(
    String churchId,
  ) async {
    return [
      MemberEventRegistration(
        id: 'reg-1',
        eventId: 'e1',
        profileId: 'demo-member',
        status: 'confirmed',
        checkInCode: 'VIDA-0001',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  @override
  Future<MemberEventRegistration> registerForEvent(String eventId) async {
    return MemberEventRegistration(
      id: 'reg-$eventId',
      eventId: eventId,
      profileId: 'demo-member',
      status: 'confirmed',
      checkInCode: 'VIDA-0002',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<MemberEventRegistration> cancelEventRegistration(
      String eventId) async {
    return MemberEventRegistration(
      id: 'reg-$eventId',
      eventId: eventId,
      profileId: 'demo-member',
      status: 'cancelled',
      checkInCode: 'VIDA-0002',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<MemberEventRegistration> checkInToEvent(String registrationId) async {
    return MemberEventRegistration(
      id: registrationId,
      eventId: 'e1',
      profileId: 'demo-member',
      status: 'checked_in',
      checkInCode: 'VIDA-0001',
      checkedInAt: DateTime.now(),
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    );
  }

  @override
  Future<void> checkInWithQrPayload(String qrPayload) async {}

  @override
  Future<MemberWalletSummary?> fetchMemberWallet() async {
    return const MemberWalletSummary(
      id: 'wallet-demo',
      phone: '+258827688695',
      currency: 'MZN',
      availableBalance: 2000,
      pendingBalance: 0,
      totalReceived: 2000,
      totalContributed: 0,
      provider: 'mpesa',
    );
  }

  @override
  Future<void> updateMyProfileName(String fullName) async {}

  @override
  Future<MemberWalletSummary> depositMemberWallet({
    required num amount,
    String? provider,
  }) async {
    return MemberWalletSummary(
      id: 'wallet-demo',
      phone: '+258827688695',
      currency: 'MZN',
      availableBalance: 2000 + amount,
      pendingBalance: 0,
      totalReceived: 2000 + amount,
      totalContributed: 0,
      provider: provider ?? 'mpesa',
    );
  }

  @override
  Future<List<DonationCampaign>> fetchActiveCampaigns(String churchId) async {
    return [
      DonationCampaign(
        id: 'c1',
        title: 'Construcao do templo',
        description: 'Contribui para a fase final da obra.',
        targetAmount: 150000,
        active: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];
  }

  @override
  Future<List<MemberDonationRecord>> fetchOwnDonations(String churchId) async {
    return [
      MemberDonationRecord(
        id: 'd1',
        amount: 2500,
        currency: 'MZN',
        donationType: 'tithe',
        provider: 'mpesa',
        status: 'recorded',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    ];
  }

  @override
  Future<List<MemberPrayerRequest>> fetchOwnPrayerRequests(
      String churchId) async {
    return [
      MemberPrayerRequest(
        id: 'p1',
        churchId: churchId,
        title: 'Saude da familia',
        description: 'Em acompanhamento pela lideranca.',
        isPrivate: true,
        visibility: 'private',
        status: 'new',
        profileId: 'demo-member',
        anonymousRequest: false,
        allowResponses: true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    ];
  }

  @override
  Future<List<MemberPrayerRequest>> fetchPrayerFeed(String churchId) async {
    return [
      MemberPrayerRequest(
        id: 'p2',
        churchId: churchId,
        title: 'Prova de emprego',
        description: 'Peco oracao por uma nova oportunidade profissional.',
        isPrivate: false,
        visibility: 'public',
        status: 'answered',
        profileId: 'demo-member-2',
        anonymousRequest: false,
        allowResponses: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 10)),
      ),
    ];
  }

  @override
  Future<MemberPrayerRequest> createPrayerRequest({
    required String churchId,
    required String title,
    required String description,
    required String visibility,
    required bool anonymousRequest,
    required bool allowResponses,
  }) async {
    return MemberPrayerRequest(
      id: 'demo-prayer',
      churchId: churchId,
      title: title,
      description: description,
      isPrivate: visibility == 'private',
      visibility: visibility,
      status: 'new',
      profileId: 'demo-member',
      anonymousRequest: anonymousRequest,
      allowResponses: allowResponses,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<PrayerResponse>> fetchPrayerResponses(
      String prayerRequestId) async {
    return [
      PrayerResponse(
        id: 'resp-1',
        prayerRequestId: prayerRequestId,
        churchId: 'demo-church',
        responderProfileId: 'demo-member',
        body: 'Estamos contigo em oracao esta semana.',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
    ];
  }

  @override
  Future<PrayerResponse> createPrayerResponse({
    required String prayerRequestId,
    required String body,
  }) async {
    return PrayerResponse(
      id: 'resp-new',
      prayerRequestId: prayerRequestId,
      churchId: 'demo-church',
      responderProfileId: 'demo-member',
      body: body,
      createdAt: DateTime.now(),
    );
  }
}
