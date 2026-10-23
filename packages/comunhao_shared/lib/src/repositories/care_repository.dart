import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/care_requests.dart';

class CareRepository {
  CareRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<ChurchJoinRequest>> fetchOwnJoinRequests(String churchId) async {
    final rows = await _client
        .from('church_join_requests')
        .select(
            '*, profile:profiles(full_name, phone, avatar_url, avatar_storage_path)')
        .eq('church_id', churchId)
        .order('created_at', ascending: false);

    return _hydrateJoinAvatars(rows
        .whereType<Map<String, dynamic>>()
        .map(ChurchJoinRequest.fromMap)
        .toList(growable: false));
  }

  Future<List<ChurchJoinRequest>> fetchChurchJoinRequests(
      String churchId) async {
    final rows = await _client
        .from('church_join_requests')
        .select(
            '*, profile:profiles(full_name, phone, avatar_url, avatar_storage_path)')
        .eq('church_id', churchId)
        .order('created_at', ascending: false);

    return _hydrateJoinAvatars(rows
        .whereType<Map<String, dynamic>>()
        .map(ChurchJoinRequest.fromMap)
        .toList(growable: false));
  }

  Future<ChurchJoinRequest> createJoinRequest({
    required String churchId,
    required String requestKind,
    required String fullName,
    required String phone,
    DateTime? birthDate,
    String? gender,
    String? neighborhood,
    String? previousChurch,
    String? reason,
    String? ministryInterest,
    String? observation,
    required bool consent,
  }) async {
    try {
      final row = await _client.rpc(
        'create_church_join_request',
        params: {
          'p_church_id': churchId,
          'p_request_kind': requestKind,
          'p_full_name': fullName,
          'p_phone': phone,
          'p_birth_date': birthDate?.toIso8601String().split('T').first,
          'p_gender': gender,
          'p_neighborhood': neighborhood,
          'p_previous_church': previousChurch,
          'p_reason': reason,
          'p_ministry_interest': ministryInterest,
          'p_observation': observation,
          'p_consent_data_processing': consent,
        },
      );
      return ChurchJoinRequest.fromMap(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      final row = await _client
          .from('church_join_requests')
          .upsert({
            'church_id': churchId,
            'profile_id': _client.auth.currentUser?.id,
            'request_kind': requestKind,
            'requested_role': requestKind,
            'full_name': fullName.trim(),
            'phone': phone.trim(),
            'birth_date': birthDate?.toIso8601String().split('T').first,
            'gender': gender,
            'neighborhood': _nullIfBlank(neighborhood),
            'previous_church': _nullIfBlank(previousChurch),
            'reason': _nullIfBlank(reason),
            'message': _nullIfBlank(reason),
            'ministry_interest': _nullIfBlank(ministryInterest),
            'observation': _nullIfBlank(observation),
            'consent_data_processing': consent,
            'status': 'pending',
          }, onConflict: 'church_id,profile_id')
          .select(
              '*, profile:profiles(full_name, phone, avatar_url, avatar_storage_path)')
          .single();
      return (await _hydrateJoinAvatars([ChurchJoinRequest.fromMap(row)]))
          .first;
    }
  }

  Future<ChurchJoinRequest> respondJoinRequest({
    required String requestId,
    required String response,
  }) async {
    final row = await _client.rpc(
      'respond_church_join_request',
      params: {
        'p_request_id': requestId,
        'p_member_response': response,
      },
    );
    return ChurchJoinRequest.fromMap(Map<String, dynamic>.from(row as Map));
  }

  Future<ChurchJoinRequest> cancelJoinRequest(String requestId) async {
    final row = await _client.rpc(
      'cancel_church_join_request',
      params: {'p_request_id': requestId},
    );
    return ChurchJoinRequest.fromMap(Map<String, dynamic>.from(row as Map));
  }

  Future<ChurchJoinRequest> reviewJoinRequest({
    required String requestId,
    required String status,
    String? notes,
  }) async {
    final row = await _client.rpc(
      'review_church_join_request',
      params: {
        'p_request_id': requestId,
        'p_status': status,
        'p_notes': notes,
      },
    );
    return ChurchJoinRequest.fromMap(Map<String, dynamic>.from(row as Map));
  }

  Future<List<PastoralCareRequest>> fetchOwnPastoralRequests(
    String churchId,
  ) async {
    final rows = await _client
        .from('pastoral_requests')
        .select(
            '*, profile:profiles(full_name, avatar_url, avatar_storage_path), assigned:memberships(profile:profiles(full_name)), responses:pastoral_request_responses(body, internal_only, created_at)')
        .eq('church_id', churchId)
        .order('created_at', ascending: false);

    return _hydratePastoralAvatars(rows
        .whereType<Map<String, dynamic>>()
        .map(PastoralCareRequest.fromMap)
        .toList(growable: false));
  }

  Future<List<PastoralCareRequest>> fetchChurchPastoralRequests(
    String churchId,
  ) async {
    final results = await Future.wait<dynamic>([
      _client
          .from('pastoral_requests')
          .select(
              '*, profile:profiles(full_name, avatar_url, avatar_storage_path), assigned:memberships(profile:profiles(full_name)), responses:pastoral_request_responses(body, internal_only, created_at)')
          .eq('church_id', churchId)
          .order('urgency', ascending: false)
          .order('created_at', ascending: false),
      _client
          .from('prayer_requests')
          .select('''
            id,
            church_id,
            profile_id,
            profile:profiles(full_name, avatar_url, avatar_storage_path),
            title,
            description,
            is_private,
            visibility,
            anonymous_request,
            status,
            created_at
          ''')
          .eq('church_id', churchId)
          .order('created_at', ascending: false)
          .limit(80),
    ]);

    final pastoralRequests = (results[0] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(PastoralCareRequest.fromMap)
        .toList(growable: false);

    final prayerRequests = (results[1] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(PastoralCareRequest.fromPrayerMap)
        .toList(growable: false);

    final items = [
      ...await _hydratePastoralAvatars(pastoralRequests),
      ...await _hydratePastoralAvatars(prayerRequests),
    ];
    items.sort((a, b) {
      final statusCompare =
          _requestStatusRank(a.status).compareTo(_requestStatusRank(b.status));
      if (statusCompare != 0) return statusCompare;
      return b.createdAt.compareTo(a.createdAt);
    });
    return items;
  }

  Future<PastoralCareRequest> createPastoralRequest({
    required String churchId,
    required String category,
    required String title,
    required String message,
    required String urgency,
    required String privacyLevel,
    String? preferredContact,
    String? contactAvailability,
    String? attachmentUrl,
    required bool consentForwarding,
  }) async {
    try {
      final row = await _client.rpc(
        'create_pastoral_request',
        params: {
          'p_church_id': churchId,
          'p_category': category,
          'p_title': title,
          'p_message': message,
          'p_urgency': urgency,
          'p_privacy_level': privacyLevel,
          'p_preferred_contact': preferredContact,
          'p_contact_availability': contactAvailability,
          'p_attachment_url': attachmentUrl,
          'p_consent_forwarding': consentForwarding,
        },
      );
      return PastoralCareRequest.fromMap(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      final row = await _client
          .from('pastoral_requests')
          .insert({
            'church_id': churchId,
            'profile_id': _client.auth.currentUser?.id,
            'request_area': 'pastoral',
            'category': category,
            'title': title.trim(),
            'subject': title.trim(),
            'message': message.trim(),
            'urgency': urgency,
            'confidentiality': privacyLevel,
            'privacy_level': privacyLevel,
            'preferred_contact': _nullIfBlank(preferredContact),
            'contact_availability': _nullIfBlank(contactAvailability),
            'attachment_url': _nullIfBlank(attachmentUrl),
            'consent_forwarding': consentForwarding,
            'hide_body_in_notifications': true,
            'status': 'new',
          })
          .select(
              '*, profile:profiles(full_name, avatar_url, avatar_storage_path), assigned:memberships(profile:profiles(full_name)), responses:pastoral_request_responses(body, internal_only, created_at)')
          .single();
      return (await _hydratePastoralAvatars([PastoralCareRequest.fromMap(row)]))
          .first;
    }
  }

  Future<PastoralCareRequest> updatePastoralRequest({
    required String requestId,
    required String status,
    String? publicResponse,
    String? internalNote,
    String? assignedMembershipId,
  }) async {
    if (requestId.startsWith('prayer_requests:')) {
      final prayerId = requestId.substring('prayer_requests:'.length);
      final prayerStatus = switch (status) {
        'resolved' || 'closed' => 'answered',
        'cancelled' => 'cancelled',
        _ => 'new',
      };
      final row = await _client
          .from('prayer_requests')
          .update({'status': prayerStatus})
          .eq('id', prayerId)
          .select('''
            id,
            church_id,
            profile_id,
            profile:profiles(full_name, avatar_url, avatar_storage_path),
            title,
            description,
            is_private,
            visibility,
            anonymous_request,
            status,
            created_at
          ''')
          .single();
      if (publicResponse?.trim().isNotEmpty == true) {
        await _client.from('prayer_request_responses').insert({
          'prayer_request_id': prayerId,
          'responder_profile_id': _client.auth.currentUser?.id,
          'body': publicResponse!.trim(),
        });
      }
      return (await _hydratePastoralAvatars([
        PastoralCareRequest.fromPrayerMap(row),
      ]))
          .first;
    }

    final row = await _client.rpc(
      'update_pastoral_request_status',
      params: {
        'p_request_id': requestId,
        'p_status': status,
        'p_public_response': publicResponse,
        'p_internal_note': internalNote,
        'p_assigned_membership_id': assignedMembershipId,
      },
    );
    return PastoralCareRequest.fromMap(Map<String, dynamic>.from(row as Map));
  }

  Future<void> recordPastoralOpen(String requestId) async {
    if (requestId.startsWith('prayer_requests:')) {
      return;
    }
    await _client.rpc(
      'record_pastoral_request_open',
      params: {'p_request_id': requestId},
    );
  }

  int _requestStatusRank(String status) {
    return switch (status) {
      'new' => 0,
      'triaged' => 1,
      'assigned' => 2,
      'in_contact' => 3,
      'in_follow_up' => 4,
      'waiting_member' => 5,
      'resolved' => 6,
      'closed' => 7,
      'cancelled' => 8,
      _ => 9,
    };
  }

  Future<List<AdministrativeRequest>> fetchOwnAdministrativeRequests(
    String churchId,
  ) async {
    final rows = await _client
        .from('administrative_requests')
        .select(
            '*, profile:profiles(full_name, avatar_url, avatar_storage_path)')
        .eq('church_id', churchId)
        .order('created_at', ascending: false);
    return _hydrateAdministrativeAvatars(rows
        .whereType<Map<String, dynamic>>()
        .map(AdministrativeRequest.fromMap)
        .toList(growable: false));
  }

  Future<List<AdministrativeRequest>> fetchChurchAdministrativeRequests(
    String churchId,
  ) async {
    final rows = await _client
        .from('administrative_requests')
        .select(
            '*, profile:profiles(full_name, avatar_url, avatar_storage_path)')
        .eq('church_id', churchId)
        .order('created_at', ascending: false);
    return _hydrateAdministrativeAvatars(rows
        .whereType<Map<String, dynamic>>()
        .map(AdministrativeRequest.fromMap)
        .toList(growable: false));
  }

  Future<AdministrativeRequest> createAdministrativeRequest({
    required String churchId,
    required String requestType,
    required String subject,
    required String description,
    String? attachmentUrl,
  }) async {
    try {
      final row = await _client.rpc(
        'create_administrative_request',
        params: {
          'p_church_id': churchId,
          'p_request_type': requestType,
          'p_subject': subject,
          'p_description': description,
          'p_attachment_url': attachmentUrl,
        },
      );
      return AdministrativeRequest.fromMap(
        Map<String, dynamic>.from(row as Map),
      );
    } catch (_) {
      final row = await _client
          .from('administrative_requests')
          .insert({
            'church_id': churchId,
            'profile_id': _client.auth.currentUser?.id,
            'request_type': requestType,
            'subject': subject.trim(),
            'description': description.trim(),
            'attachment_url': _nullIfBlank(attachmentUrl),
            'status': 'new',
          })
          .select(
              '*, profile:profiles(full_name, avatar_url, avatar_storage_path)')
          .single();
      return (await _hydrateAdministrativeAvatars([
        AdministrativeRequest.fromMap(row),
      ]))
          .first;
    }
  }

  Future<AdministrativeRequest> reviewAdministrativeRequest({
    required String requestId,
    required String status,
    String? response,
    String? internalNote,
    String? assignedMembershipId,
  }) async {
    final row = await _client.rpc(
      'review_administrative_request',
      params: {
        'p_request_id': requestId,
        'p_status': status,
        'p_response': response,
        'p_internal_note': internalNote,
        'p_assigned_membership_id': assignedMembershipId,
      },
    );
    return AdministrativeRequest.fromMap(Map<String, dynamic>.from(row as Map));
  }

  Future<List<ChurchRequestTimelineEntry>> fetchTimeline({
    required String table,
    required String requestId,
  }) async {
    final rows = await _client
        .from('church_request_timeline')
        .select()
        .eq('request_table', table)
        .eq('request_id', requestId)
        .order('created_at');
    return rows
        .whereType<Map<String, dynamic>>()
        .map(ChurchRequestTimelineEntry.fromMap)
        .toList(growable: false);
  }

  String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<String?> _signedProfileMediaUrl(String? storagePath) async {
    final path = storagePath?.trim();
    if (path == null || path.isEmpty) return null;
    try {
      return _client.storage.from('profile-media').createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  Future<List<ChurchJoinRequest>> _hydrateJoinAvatars(
    List<ChurchJoinRequest> requests,
  ) async {
    return Future.wait(
      requests.map((request) async {
        if (request.avatarUrl?.trim().isNotEmpty == true) return request;
        final signedUrl =
            await _signedProfileMediaUrl(request.avatarStoragePath);
        if (signedUrl == null) return request;
        return ChurchJoinRequest(
          id: request.id,
          churchId: request.churchId,
          profileId: request.profileId,
          requestKind: request.requestKind,
          fullName: request.fullName,
          avatarUrl: signedUrl,
          avatarStoragePath: request.avatarStoragePath,
          phone: request.phone,
          birthDate: request.birthDate,
          gender: request.gender,
          neighborhood: request.neighborhood,
          previousChurch: request.previousChurch,
          reason: request.reason,
          ministryInterest: request.ministryInterest,
          observation: request.observation,
          status: request.status,
          assignedMembershipId: request.assignedMembershipId,
          informationRequested: request.informationRequested,
          memberResponse: request.memberResponse,
          reviewNotes: request.reviewNotes,
          decisionReason: request.decisionReason,
          createdAt: request.createdAt,
          updatedAt: request.updatedAt,
        );
      }),
    );
  }

  Future<List<PastoralCareRequest>> _hydratePastoralAvatars(
    List<PastoralCareRequest> requests,
  ) async {
    return Future.wait(
      requests.map((request) async {
        if (request.requesterAvatarUrl?.trim().isNotEmpty == true) {
          return request;
        }
        final signedUrl =
            await _signedProfileMediaUrl(request.requesterAvatarStoragePath);
        if (signedUrl == null) return request;
        return PastoralCareRequest(
          id: request.id,
          churchId: request.churchId,
          sourceTable: request.sourceTable,
          profileId: request.profileId,
          requesterName: request.requesterName,
          requesterAvatarUrl: signedUrl,
          requesterAvatarStoragePath: request.requesterAvatarStoragePath,
          category: request.category,
          title: request.title,
          message: request.message,
          urgency: request.urgency,
          privacyLevel: request.privacyLevel,
          preferredContact: request.preferredContact,
          contactAvailability: request.contactAvailability,
          attachmentUrl: request.attachmentUrl,
          consentForwarding: request.consentForwarding,
          assignedMembershipId: request.assignedMembershipId,
          assignedName: request.assignedName,
          latestPublicResponse: request.latestPublicResponse,
          status: request.status,
          createdAt: request.createdAt,
          updatedAt: request.updatedAt,
        );
      }),
    );
  }

  Future<List<AdministrativeRequest>> _hydrateAdministrativeAvatars(
    List<AdministrativeRequest> requests,
  ) async {
    return Future.wait(
      requests.map((request) async {
        if (request.requesterAvatarUrl?.trim().isNotEmpty == true) {
          return request;
        }
        final signedUrl =
            await _signedProfileMediaUrl(request.requesterAvatarStoragePath);
        if (signedUrl == null) return request;
        return AdministrativeRequest(
          id: request.id,
          churchId: request.churchId,
          profileId: request.profileId,
          requesterName: request.requesterName,
          requesterAvatarUrl: signedUrl,
          requesterAvatarStoragePath: request.requesterAvatarStoragePath,
          requestType: request.requestType,
          subject: request.subject,
          description: request.description,
          attachmentUrl: request.attachmentUrl,
          status: request.status,
          assignedMembershipId: request.assignedMembershipId,
          response: request.response,
          createdAt: request.createdAt,
          updatedAt: request.updatedAt,
        );
      }),
    );
  }
}
