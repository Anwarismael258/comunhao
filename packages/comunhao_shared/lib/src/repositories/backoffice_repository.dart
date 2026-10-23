import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/church_application.dart';
import '../models/church_asset.dart';
import '../models/church_communication.dart';
import '../models/church_expense.dart';
import '../models/church_ministry.dart';
import '../models/church_overview.dart';
import '../models/church_subscription.dart';
import '../models/church_subscription_request.dart';
import '../models/church_visitor.dart';
import '../models/launch_readiness.dart';
import '../models/managed_announcement.dart';
import '../models/managed_campaign.dart';
import '../models/managed_church.dart';
import '../models/managed_event.dart';
import '../models/managed_member.dart';
import '../models/managed_prayer_request.dart';
import '../models/managed_prayer_response.dart';
import '../models/platform_audit_log.dart';
import '../models/platform_dashboard_snapshot.dart';
import '../models/platform_user.dart';
import '../models/subscription_plan.dart';

abstract class BackofficeRepository {
  Future<List<String>> fetchCurrentPlatformRoles();
  Future<PlatformDashboardSnapshot> fetchPlatformDashboard();
  Future<LaunchReadinessSnapshot> fetchLaunchReadiness();
  Future<LaunchChecklistItem> updateLaunchChecklistItem({
    required String itemKey,
    required String status,
    String? notes,
    String? responsible,
  });
  Future<List<PlatformUser>> fetchPlatformUsers();
  Future<List<PlatformAuditLog>> fetchPlatformAuditLogs({
    int limit,
    String? churchId,
  });
  Future<PlatformUser> setPlatformRole({
    required String profileId,
    required String role,
    required bool active,
  });
  Future<List<ChurchApplication>> fetchOwnChurchApplications();
  Future<ChurchApplication> saveChurchApplication(
      ChurchApplication application);
  Future<ChurchApplication> submitChurchApplication(String applicationId);
  Future<List<ManagedChurch>> fetchManagedChurches();
  Future<void> updateManagedChurchName({
    required String churchId,
    required String name,
  });
  Future<void> updateManagedChurchProfile({
    required String churchId,
    required String name,
    String? phone,
    String? email,
    String? tagline,
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
  });
  Future<Map<String, dynamic>> deleteManagedChurch(String churchId);
  Future<List<ManagedMember>> fetchChurchMembers(String churchId);
  Future<ManagedMember> updateChurchMember({
    required String membershipId,
    String? role,
    String? status,
  });
  Future<List<ManagedAnnouncement>> fetchChurchAnnouncements(String churchId);
  Future<ManagedAnnouncement> saveChurchAnnouncement({
    String? announcementId,
    required String churchId,
    required String title,
    required String body,
    String? imageUrl,
    required bool pinned,
    DateTime? publishedAt,
  });
  Future<void> deleteChurchAnnouncement(String announcementId);
  Future<List<ManagedCampaign>> fetchChurchCampaigns(String churchId);
  Future<ManagedCampaign> saveChurchCampaign({
    String? campaignId,
    required String churchId,
    required String title,
    String? description,
    String? imageUrl,
    num? targetAmount,
    DateTime? startAt,
    DateTime? endAt,
    required bool active,
    required String status,
  });
  Future<void> archiveChurchCampaign(String campaignId);
  Future<List<ManagedEvent>> fetchChurchEvents(String churchId);
  Future<ManagedEvent> saveChurchEvent({
    String? eventId,
    required String churchId,
    required String title,
    required String eventType,
    String? description,
    String? location,
    String? category,
    String? status,
    String? visibility,
    String? coverImageUrl,
    String? recurrenceRule,
    bool? attendanceRequired,
    bool? isPublic,
    num? registrationFeeMzn,
    required DateTime startsAt,
    DateTime? endsAt,
    required bool registrationRequired,
    int? capacity,
  });
  Future<void> deleteChurchEvent(String eventId);
  Future<List<ManagedPrayerRequest>> fetchChurchPrayerRequests(
    String churchId, {
    int limit,
  });
  Future<List<ManagedPrayerResponse>> fetchPrayerRequestResponses(
    String prayerRequestId,
  );
  Future<ManagedPrayerResponse> respondToPrayerRequest({
    required String prayerRequestId,
    required String body,
  });
  Future<List<ChurchMinistry>> fetchChurchMinistries(String churchId);
  Future<ChurchMinistry> saveChurchMinistry({
    String? ministryId,
    required String churchId,
    required String name,
    String? description,
    String? leaderMembershipId,
    required bool active,
    required List<String> memberMembershipIds,
  });
  Future<void> deleteChurchMinistry(String ministryId);
  Future<List<ChurchAsset>> fetchChurchAssets(String churchId);
  Future<ChurchAsset> saveChurchAsset({
    String? assetId,
    required String churchId,
    required String category,
    required String name,
    required int quantity,
    required String itemCondition,
    String? location,
    String? notes,
  });
  Future<void> deleteChurchAsset(String assetId);
  Future<List<ChurchVisitor>> fetchChurchVisitors(String churchId);
  Future<ChurchVisitor> saveChurchVisitor({
    String? visitorId,
    required String churchId,
    required String fullName,
    String? phone,
    required String status,
    required DateTime firstVisitAt,
    String? notes,
  });
  Future<void> deleteChurchVisitor(String visitorId);
  Future<List<ChurchExpense>> fetchChurchExpenses(String churchId);
  Future<ChurchExpense> saveChurchExpense({
    String? expenseId,
    required String churchId,
    required String category,
    required String title,
    required num amount,
    required DateTime spentAt,
    String? notes,
    String? vendorName,
    String? paymentMethod,
    String? paymentReference,
    String? proofUrl,
    String? costCenter,
    String status,
  });
  Future<void> deleteChurchExpense(String expenseId);
  Future<List<ChurchCommunication>> fetchChurchCommunications(String churchId);
  Future<ChurchCommunication> saveChurchCommunication({
    String? communicationId,
    required String churchId,
    required String channel,
    required String audienceType,
    String? targetRole,
    String? ministryId,
    String? membershipId,
    required String title,
    required String body,
    required String status,
    DateTime? scheduledAt,
  });
  Future<void> deleteChurchCommunication(String communicationId);
  Future<ChurchSubscription?> fetchChurchSubscription(String churchId);
  Future<List<SubscriptionPlan>> fetchSubscriptionPlans();
  Future<List<ChurchSubscriptionRequest>> fetchChurchSubscriptionRequests(
    String churchId,
  );
  Future<ChurchSubscriptionRequest> requestSubscriptionPlan({
    required String churchId,
    required String planCode,
    String? paymentProvider,
    String? payerPhone,
    String? paymentReference,
    String? paymentNotes,
  });
  Future<Map<String, dynamic>> createPaysuiteCheckout({
    required num amountMzn,
    required String provider,
    required String phone,
    required String description,
  });
  Future<List<ChurchApplication>> fetchApplicationsForReview();
  Future<List<ChurchOverview>> fetchChurchOverviews();
  Future<ChurchOverview> setChurchActiveState({
    required String churchId,
    required bool active,
    String? notes,
  });
  Future<ChurchOverview> transferChurchOwnership({
    required String churchId,
    required String newOwnerProfileId,
    String newRole,
    String? notes,
  });
  Future<Map<String, dynamic>> resetChurchWorkspace({
    required String churchId,
    String? notes,
  });
  Future<String?> reviewChurchApplication({
    required String applicationId,
    required String decision,
    String? notes,
  });
  Future<List<ChurchSubscriptionRequest>> fetchPendingSubscriptionRequests();
  Future<ChurchSubscription?> reviewSubscriptionRequest({
    required String requestId,
    required String decision,
    int? periodDays,
    String? notes,
  });
  Future<ChurchSubscription> adminUpdateChurchSubscription({
    required String churchId,
    required String status,
    String? planCode,
    int? periodDays,
    int? graceDays,
    String? notes,
  });
}

class SupabaseBackofficeRepository implements BackofficeRepository {
  SupabaseBackofficeRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _churchOverviewSelect = '''
          id,
          name,
          slug,
          join_code,
          city,
          active,
          created_at,
          church_settings (
            owner_profile_id,
            owner:profiles (
              full_name,
              phone
            )
          ),
          church_subscriptions (
            church_id,
            plan_code,
            status,
            trial_ends_at,
            current_period_ends_at,
            grace_period_ends_at,
            admin_notes
          )
        ''';

  static const String _legacyChurchOverviewSelect = '''
          id,
          name,
          slug,
          join_code,
          city,
          active,
          created_at,
          church_subscriptions (
            church_id,
            plan_code,
            status,
            trial_ends_at,
            current_period_ends_at,
            grace_period_ends_at,
            admin_notes
          )
        ''';

  String? get _currentUserId => _client.auth.currentUser?.id;

  Map<String, dynamic>? _extractSingleMap(Object? rawValue) {
    return switch (rawValue) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => null,
    };
  }

  bool _looksLikeSchemaDrift(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('column') ||
        raw.contains('schema cache') ||
        raw.contains('pgrst204') ||
        raw.contains('42703');
  }

  Future<List<ChurchSubscriptionRequest>> _hydrateSubscriptionRequestRows(
    List<dynamic> rows,
  ) async {
    final requestRows = rows
        .whereType<Map<String, dynamic>>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);

    final churchIds = requestRows
        .map((row) => row['church_id'])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final requesterIds = requestRows
        .map((row) => row['requested_by'])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (churchIds.isNotEmpty) {
      final churchRows = await _client
          .from('churches')
          .select('id, name, city')
          .inFilter('id', churchIds);
      final churchesById = {
        for (final church in churchRows.whereType<Map<String, dynamic>>())
          if (church['id'] is String) church['id'] as String: church,
      };
      for (final request in requestRows) {
        final churchId = request['church_id'];
        final church = churchId is String ? churchesById[churchId] : null;
        if (church != null) {
          request['church'] = church;
        }
      }
    }

    if (requesterIds.isNotEmpty) {
      final profileRows = await _client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', requesterIds);
      final profilesById = {
        for (final profile in profileRows.whereType<Map<String, dynamic>>())
          if (profile['id'] is String) profile['id'] as String: profile,
      };
      for (final request in requestRows) {
        final requesterId = request['requested_by'];
        final profile =
            requesterId is String ? profilesById[requesterId] : null;
        if (profile != null) {
          request['requester'] = profile;
        }
      }
    }

    return requestRows.map(ChurchSubscriptionRequest.fromMap).toList();
  }

  Future<PlatformUser?> _fetchPlatformUserById(String profileId) async {
    final row = await _client.from('profiles').select('''
          id,
          full_name,
          phone,
          birth_date,
          created_at,
          platform_roles (
            id,
            role,
            status,
            created_at
          ),
          memberships (
            role,
            status,
            church:churches (
              name,
              slug
            )
          )
        ''').eq('id', profileId).maybeSingle();

    if (row == null) {
      return null;
    }

    return PlatformUser.fromMap(row);
  }

  Future<ChurchOverview?> _fetchChurchOverviewById(String churchId) async {
    Map<String, dynamic>? row;
    try {
      row = await _client
          .from('churches')
          .select(_churchOverviewSelect)
          .eq('id', churchId)
          .maybeSingle();
    } catch (_) {
      row = await _client
          .from('churches')
          .select(_legacyChurchOverviewSelect)
          .eq('id', churchId)
          .maybeSingle();
    }

    if (row == null) {
      return null;
    }

    return ChurchOverview.fromMap(row);
  }

  Future<ChurchMinistry?> _fetchChurchMinistryById(String ministryId) async {
    final row = await _client.from('church_ministries').select('''
          id,
          church_id,
          name,
          description,
          active,
          leader_membership_id,
          created_at,
          leader:memberships!church_ministries_leader_membership_id_fkey (
            id,
            profile:profiles (
              full_name
            )
          ),
          ministry_members (
            membership_id
          )
        ''').eq('id', ministryId).maybeSingle();

    if (row == null) {
      return null;
    }

    return ChurchMinistry.fromMap(row);
  }

  Future<ChurchAsset?> _fetchChurchAssetById(String assetId) async {
    final row = await _client.from('church_assets').select('''
          id,
          church_id,
          category,
          name,
          quantity,
          item_condition,
          location,
          notes,
          created_at
        ''').eq('id', assetId).maybeSingle();

    if (row == null) {
      return null;
    }

    return ChurchAsset.fromMap(row);
  }

  Future<ChurchVisitor?> _fetchChurchVisitorById(String visitorId) async {
    final row = await _client.from('church_visitors').select('''
          id,
          church_id,
          full_name,
          phone,
          status,
          first_visit_at,
          notes,
          created_at
        ''').eq('id', visitorId).maybeSingle();

    if (row == null) {
      return null;
    }

    return ChurchVisitor.fromMap(row);
  }

  Future<ChurchExpense?> _fetchChurchExpenseById(String expenseId) async {
    final row = await _client.from('church_expenses').select('''
          id,
          church_id,
          category,
          title,
          amount,
          currency,
          spent_at,
          notes,
          vendor_name,
          payment_method,
          payment_reference,
          proof_url,
          cost_center,
          status,
          approved_at,
          paid_at,
          rejection_reason,
          is_demo,
          created_at
        ''').eq('id', expenseId).maybeSingle();

    if (row == null) {
      return null;
    }

    return ChurchExpense.fromMap(row);
  }

  Future<ChurchCommunication?> _fetchChurchCommunicationById(
    String communicationId,
  ) async {
    final row = await _client.from('church_communications').select('''
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
        ''').eq('id', communicationId).maybeSingle();

    if (row == null) {
      return null;
    }

    return ChurchCommunication.fromMap(row);
  }

  Future<void> _tryCreatePlatformAuditLog({
    required String action,
    required String targetType,
    String? targetId,
    String? churchId,
    required String summary,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _client.rpc(
        'create_platform_audit_log',
        params: {
          'p_action': action,
          'p_target_type': targetType,
          'p_target_id': targetId,
          'p_church_id': churchId,
          'p_summary': summary,
          'p_details': details ?? const <String, dynamic>{},
        },
      );
    } catch (_) {
      // Best effort while older environments catch up with the new migration.
    }
  }

  @override
  Future<List<String>> fetchCurrentPlatformRoles() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      return const [];
    }

    try {
      final result = await _client.rpc('get_current_platform_roles');
      return (result as List<dynamic>)
          .map((role) => role.toString())
          .where((role) => role.isNotEmpty)
          .toList();
    } catch (_) {
      // Older environments may not have the RPC yet.
    }

    final rows = await _client
        .from('platform_roles')
        .select('role')
        .eq('profile_id', currentUser.id)
        .eq('status', 'active');

    return rows
        .whereType<Map<String, dynamic>>()
        .map((row) => (row['role'] as String?) ?? '')
        .where((role) => role.isNotEmpty)
        .toList();
  }

  @override
  Future<PlatformDashboardSnapshot> fetchPlatformDashboard() async {
    try {
      final result = await _client.rpc('get_platform_dashboard_snapshot');
      return PlatformDashboardSnapshot.fromMap(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (_) {
      // Fall back while older environments catch up with the latest migration.
    }

    final results = await Future.wait<dynamic>([
      _client.from('churches').select('''
        id,
        active,
        church_subscriptions (
          status
        )
      '''),
      _client.from('memberships').select('profile_id, role, status'),
      _client.from('church_applications').select('id, status'),
      _client.from('church_subscription_requests').select('id, status'),
      _client.rpc(
        'get_wallet_withdrawal_requests',
        params: {'p_limit': 500},
      ),
      _client.rpc(
        'get_wallet_dashboard',
        params: {'p_owner_type': 'platform'},
      ),
    ]);

    final churchRows = (results[0] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();
    final membershipRows = (results[1] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();
    final applicationRows = (results[2] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();
    final requestRows = (results[3] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();
    final withdrawalRows = (results[4] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();
    final walletRows = (results[5] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();

    var activeChurches = 0;
    for (final row in churchRows) {
      final subscription = _extractSingleMap(row['church_subscriptions']);
      final status =
          subscription == null ? null : subscription['status'] as String?;
      final churchIsActive = (row['active'] as bool?) ?? true;
      final isOperational =
          status == null || (status != 'suspended' && status != 'cancelled');
      if (churchIsActive && isOperational) {
        activeChurches += 1;
      }
    }

    final activeMemberships = membershipRows
        .where((row) => (row['status'] as String?) == 'active')
        .toList();

    return PlatformDashboardSnapshot(
      totalChurches: churchRows.length,
      activeChurches: activeChurches,
      inactiveChurches: churchRows.length - activeChurches,
      totalMembers: activeMemberships.length,
      totalPastors: activeMemberships
          .where((row) => (row['role'] as String?) == 'pastor')
          .length,
      pendingApplications: applicationRows
          .where((row) => (row['status'] as String?) == 'submitted')
          .length,
      pendingPlanRequests: requestRows
          .where((row) => (row['status'] as String?) == 'pending')
          .length,
      pendingWithdrawals: withdrawalRows.where((row) {
        final status = row['status'] as String?;
        return status == 'pending' || status == 'processing';
      }).length,
      monthRevenue: walletRows.fold<num>(
        0,
        (sum, row) => sum + ((row['incoming_month'] as num?) ?? 0),
      ),
      trialChurches: churchRows.where((row) {
        final subscription = _extractSingleMap(row['church_subscriptions']);
        return (subscription?['status'] as String?) == 'trial';
      }).length,
      suspendedChurches: churchRows.where((row) {
        final subscription = _extractSingleMap(row['church_subscriptions']);
        final status = subscription?['status'] as String?;
        return status == 'suspended' || status == 'cancelled';
      }).length,
    );
  }

  @override
  Future<LaunchReadinessSnapshot> fetchLaunchReadiness() async {
    final result = await _client.rpc(
      'get_launch_readiness_snapshot',
      params: {'p_refresh': true},
    );
    return LaunchReadinessSnapshot.fromMap(
      Map<String, dynamic>.from(result as Map),
    );
  }

  @override
  Future<LaunchChecklistItem> updateLaunchChecklistItem({
    required String itemKey,
    required String status,
    String? notes,
    String? responsible,
  }) async {
    final result = await _client.rpc(
      'update_launch_checklist_item',
      params: {
        'p_item_key': itemKey,
        'p_status': status,
        'p_notes': notes,
        'p_responsible': responsible,
      },
    );
    return LaunchChecklistItem.fromMap(
      Map<String, dynamic>.from(result as Map),
    );
  }

  @override
  Future<List<PlatformUser>> fetchPlatformUsers() async {
    final rows = await _client.from('profiles').select('''
          id,
          full_name,
          phone,
          birth_date,
          created_at,
          platform_roles (
            id,
            role,
            status,
            created_at
          ),
          memberships (
            role,
            status,
            church:churches (
              name,
              slug
            )
          )
        ''').order('created_at', ascending: false);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(PlatformUser.fromMap)
        .toList();
  }

  @override
  Future<List<PlatformAuditLog>> fetchPlatformAuditLogs({
    int limit = 100,
    String? churchId,
  }) async {
    try {
      final query = _client.from('platform_audit_logs').select('''
            id,
            action,
            target_type,
            target_id,
            church_id,
            church_name,
            actor_profile_id,
            actor_name,
            actor_phone,
            summary,
            details,
            created_at
          ''');
      final filtered = churchId != null && churchId.isNotEmpty
          ? query.eq('church_id', churchId)
          : query;
      final rows =
          await filtered.order('created_at', ascending: false).limit(limit);

      return rows
          .whereType<Map<String, dynamic>>()
          .map(PlatformAuditLog.fromMap)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<PlatformUser> setPlatformRole({
    required String profileId,
    required String role,
    required bool active,
  }) async {
    if (active) {
      await _client.from('platform_roles').upsert(
        {
          'profile_id': profileId,
          'role': role,
          'status': 'active',
        },
        onConflict: 'profile_id,role',
      );
    } else {
      await _client
          .from('platform_roles')
          .update({'status': 'revoked'})
          .eq('profile_id', profileId)
          .eq('role', role);
    }

    final user = await _fetchPlatformUserById(profileId);
    if (user == null) {
      throw StateError('Utilizador nao encontrado depois da atualizacao.');
    }

    await _tryCreatePlatformAuditLog(
      action: 'platform_role.updated',
      targetType: 'profile',
      targetId: profileId,
      summary:
          '${active ? 'Ativado' : 'Revogado'} o papel $role para ${user.fullName}.',
      details: {
        'role': role,
        'active': active,
        'profile_id': profileId,
        'profile_name': user.fullName,
      },
    );
    return user;
  }

  @override
  Future<List<ChurchApplication>> fetchOwnChurchApplications() async {
    final rows = await _client.from('church_applications').select('''
          id,
          pastor_profile_id,
          church_name,
          city,
          province,
          country,
          phone,
          email,
          applicant_role,
          logo_url,
          primary_color,
          secondary_color,
          tagline,
          mpesa,
          emola,
          bank_name,
          bank_account_name,
          bank_account_number,
          status,
          submitted_at,
          reviewed_at,
          review_notes,
          approved_church_id
        ''').order('created_at', ascending: false);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ChurchApplication.fromMap)
        .toList();
  }

  @override
  Future<ChurchApplication> saveChurchApplication(
    ChurchApplication application,
  ) async {
    final payload = application.toWriteMap();

    final row = application.id == null
        ? await _client
            .from('church_applications')
            .insert(payload)
            .select()
            .single()
        : await _client
            .from('church_applications')
            .update(payload)
            .eq('id', application.id!)
            .select()
            .single();

    return ChurchApplication.fromMap(row);
  }

  @override
  Future<ChurchApplication> submitChurchApplication(
      String applicationId) async {
    final row = await _client.rpc(
      'submit_church_application',
      params: {'p_application_id': applicationId},
    );

    return ChurchApplication.fromMap(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<List<ManagedChurch>> fetchManagedChurches() async {
    Future<List<dynamic>> fetchRows() {
      return _client
          .from('memberships')
          .select('''
          role,
          status,
          church:churches (
            id,
            name,
            slug,
            join_code,
            city,
            phone,
            email,
            tagline,
            logo_url,
            primary_color,
            secondary_color,
            church_subscriptions (
              church_id,
              plan_code,
              status,
              trial_ends_at,
              current_period_ends_at,
              grace_period_ends_at,
              admin_notes
            )
          )
        ''')
          .inFilter('role', ['pastor', 'church_admin'])
          .eq('status', 'active')
          .order('created_at');
    }

    var rows = await fetchRows();
    final churchIds = rows
        .whereType<Map<String, dynamic>>()
        .map((row) => _extractSingleMap(row['church']))
        .whereType<Map<String, dynamic>>()
        .map((church) => church['id'])
        .whereType<String>()
        .toSet();

    var refreshedAny = false;
    for (final churchId in churchIds) {
      try {
        await _client.rpc(
          'refresh_church_subscription_state',
          params: {'p_church_id': churchId},
        );
        refreshedAny = true;
      } catch (_) {
        // Older databases do not expose the refresh RPC yet; the nested
        // subscription still lets the app resolve the effective status locally.
      }
    }

    if (refreshedAny) {
      rows = await fetchRows();
    }

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ManagedChurch.fromMembershipMap)
        .toList();
  }

  @override
  Future<void> updateManagedChurchName({
    required String churchId,
    required String name,
  }) async {
    final cleanName = name.trim();
    if (cleanName.length < 2) {
      throw ArgumentError('Introduz um nome valido para a igreja.');
    }

    await _client.from('churches').update({'name': cleanName}).eq(
      'id',
      churchId,
    );
  }

  @override
  Future<void> updateManagedChurchProfile({
    required String churchId,
    required String name,
    String? phone,
    String? email,
    String? tagline,
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
  }) async {
    final cleanName = name.trim();
    if (cleanName.length < 2) {
      throw ArgumentError('Introduz um nome valido para a igreja.');
    }

    String? cleanText(String? value) {
      final clean = value?.trim();
      return clean == null || clean.isEmpty ? null : clean;
    }

    await _client.from('churches').update({
      'name': cleanName,
      'phone': cleanText(phone),
      'email': cleanText(email),
      'tagline': cleanText(tagline),
      'logo_url': cleanText(logoUrl),
      'primary_color': cleanText(primaryColor),
      'secondary_color': cleanText(secondaryColor),
    }).eq('id', churchId);
  }

  @override
  Future<Map<String, dynamic>> deleteManagedChurch(String churchId) async {
    final result = await _client.rpc(
      'delete_own_church',
      params: {'p_church_id': churchId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<List<ManagedMember>> fetchChurchMembers(String churchId) async {
    final rows = await _client.from('memberships').select('''
          id,
          church_id,
          profile_id,
          role,
          status,
          entry_date,
          approved_at,
          neighborhood,
          gender,
          last_activity_at,
          created_at,
          profile:profiles (
            id,
            full_name,
            phone,
            birth_date
          )
        ''').eq('church_id', churchId).order('created_at');

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ManagedMember.fromMap)
        .toList();
  }

  @override
  Future<ManagedMember> updateChurchMember({
    required String membershipId,
    String? role,
    String? status,
  }) async {
    final payload = <String, dynamic>{
      if (role != null) 'role': role,
      if (status != null) 'status': status,
    };
    if (payload.isEmpty) {
      throw ArgumentError('Nenhuma alteracao foi fornecida.');
    }

    final row = await _client
        .from('memberships')
        .update(payload)
        .eq('id', membershipId)
        .select('''
          id,
          church_id,
          profile_id,
          role,
          status,
          created_at,
          profile:profiles (
            id,
            full_name,
            phone,
            birth_date
          )
        ''').single();

    return ManagedMember.fromMap(row);
  }

  @override
  Future<List<ManagedAnnouncement>> fetchChurchAnnouncements(
    String churchId,
  ) async {
    List<dynamic> rows;
    try {
      rows = await _client
          .from('announcements')
          .select('''
            id,
            church_id,
            title,
            body,
            image_url,
            pastoral_publication_id,
            pinned,
            published_at,
            created_at
          ''')
          .eq('church_id', churchId)
          .order('pinned', ascending: false)
          .order('created_at', ascending: false);
    } catch (_) {
      try {
        rows = await _client
            .from('announcements')
            .select('''
              id,
              church_id,
              title,
              body,
              image_url,
              pinned,
              published_at,
              created_at
            ''')
            .eq('church_id', churchId)
            .order('pinned', ascending: false)
            .order('created_at', ascending: false);
      } catch (_) {
        rows = await _client
            .from('announcements')
            .select('''
              id,
              church_id,
              title,
              body,
              pinned,
              published_at,
              created_at
            ''')
            .eq('church_id', churchId)
            .order('pinned', ascending: false)
            .order('created_at', ascending: false);
      }
    }

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ManagedAnnouncement.fromMap)
        .toList();
  }

  @override
  Future<ManagedAnnouncement> saveChurchAnnouncement({
    String? announcementId,
    required String churchId,
    required String title,
    required String body,
    String? imageUrl,
    required bool pinned,
    DateTime? publishedAt,
  }) async {
    final payload = <String, dynamic>{
      'church_id': churchId,
      'title': title.trim(),
      'body': body.trim(),
      'image_url':
          imageUrl == null || imageUrl.trim().isEmpty ? null : imageUrl.trim(),
      'pinned': pinned,
      'published_at': publishedAt?.toUtc().toIso8601String(),
      if (announcementId == null && _currentUserId != null)
        'created_by': _currentUserId,
    };

    try {
      final row = announcementId == null
          ? await _client.from('announcements').insert(payload).select('''
                id,
                church_id,
                title,
                body,
                image_url,
                pastoral_publication_id,
                pinned,
                published_at,
                created_at
              ''').single()
          : await _client
              .from('announcements')
              .update(payload)
              .eq('id', announcementId)
              .select('''
                id,
                church_id,
                title,
                body,
                image_url,
                pastoral_publication_id,
                pinned,
                published_at,
                created_at
              ''').single();

      return ManagedAnnouncement.fromMap(row);
    } catch (error) {
      if (!_looksLikeSchemaDrift(error)) {
        rethrow;
      }

      final legacyPayload = <String, dynamic>{
        'church_id': churchId,
        'title': title.trim(),
        'body': body.trim(),
        'pinned': pinned,
        'published_at': publishedAt?.toUtc().toIso8601String(),
        if (announcementId == null && _currentUserId != null)
          'created_by': _currentUserId,
      };

      final row = announcementId == null
          ? await _client.from('announcements').insert(legacyPayload).select('''
                id,
                church_id,
                title,
                body,
                pinned,
                published_at,
                created_at
              ''').single()
          : await _client
              .from('announcements')
              .update(legacyPayload)
              .eq('id', announcementId)
              .select('''
                id,
                church_id,
                title,
                body,
                pinned,
                published_at,
                created_at
              ''').single();

      return ManagedAnnouncement.fromMap(row);
    }
  }

  @override
  Future<void> deleteChurchAnnouncement(String announcementId) async {
    await _client.from('announcements').delete().eq('id', announcementId);
  }

  @override
  Future<List<ManagedCampaign>> fetchChurchCampaigns(String churchId) async {
    try {
      final rows = await _client.rpc(
        'get_church_campaigns_with_progress',
        params: {'p_church_id': churchId},
      );

      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ManagedCampaign.fromMap)
          .toList();
    } catch (_) {
      try {
        final rows = await _client
            .from('donation_campaigns')
            .select('''
              id,
              church_id,
              title,
              description,
              image_url,
              target_amount,
              start_at,
              end_at,
              active,
              campaign_status,
              created_at
            ''')
            .eq('church_id', churchId)
            .order('created_at', ascending: false);

        return rows
            .whereType<Map<String, dynamic>>()
            .map(ManagedCampaign.fromMap)
            .toList();
      } catch (_) {
        final rows = await _client
            .from('donation_campaigns')
            .select('''
              id,
              church_id,
              title,
              description,
              target_amount,
              start_at,
              end_at,
              active,
              created_at
            ''')
            .eq('church_id', churchId)
            .order('created_at', ascending: false);

        return rows
            .whereType<Map<String, dynamic>>()
            .map(ManagedCampaign.fromMap)
            .toList();
      }
    }
  }

  @override
  Future<ManagedCampaign> saveChurchCampaign({
    String? campaignId,
    required String churchId,
    required String title,
    String? description,
    String? imageUrl,
    num? targetAmount,
    DateTime? startAt,
    DateTime? endAt,
    required bool active,
    required String status,
  }) async {
    final payload = <String, dynamic>{
      'church_id': churchId,
      'title': title.trim(),
      'description': description?.trim(),
      'image_url': imageUrl?.trim(),
      'target_amount': targetAmount,
      'start_at': startAt?.toUtc().toIso8601String(),
      'end_at': endAt?.toUtc().toIso8601String(),
      'active': active,
      'campaign_status': status,
      if (campaignId == null && _currentUserId != null)
        'created_by': _currentUserId,
    };

    try {
      final row = campaignId == null
          ? await _client.from('donation_campaigns').insert(payload).select('''
                id,
                church_id,
                title,
                description,
                image_url,
                pastoral_publication_id,
                target_amount,
                start_at,
                end_at,
                active,
                campaign_status,
                created_at
              ''').single()
          : await _client
              .from('donation_campaigns')
              .update(payload)
              .eq('id', campaignId)
              .select('''
                id,
                church_id,
                title,
                description,
                image_url,
                pastoral_publication_id,
                target_amount,
                start_at,
                end_at,
                active,
                campaign_status,
                created_at
              ''').single();

      return ManagedCampaign.fromMap(row);
    } catch (_) {
      final legacyPayload = <String, dynamic>{
        'church_id': churchId,
        'title': title.trim(),
        'description': description?.trim(),
        'image_url': imageUrl?.trim(),
        'target_amount': targetAmount,
        'start_at': startAt?.toUtc().toIso8601String(),
        'end_at': endAt?.toUtc().toIso8601String(),
        'active': active,
        'campaign_status': status,
        if (campaignId == null && _currentUserId != null)
          'created_by': _currentUserId,
      };
      final row = campaignId == null
          ? await _client
              .from('donation_campaigns')
              .insert(legacyPayload)
              .select()
              .single()
          : await _client
              .from('donation_campaigns')
              .update(legacyPayload)
              .eq('id', campaignId)
              .select()
              .single();

      return ManagedCampaign.fromMap(row);
    }
  }

  @override
  Future<void> archiveChurchCampaign(String campaignId) async {
    try {
      await _client.from('donation_campaigns').update(
          {'active': false, 'campaign_status': 'closed'}).eq('id', campaignId);
    } catch (_) {
      await _client
          .from('donation_campaigns')
          .update({'active': false}).eq('id', campaignId);
    }
  }

  @override
  Future<List<ManagedEvent>> fetchChurchEvents(String churchId) async {
    List<dynamic> rows;
    try {
      rows = await _client.from('events').select('''
            id,
            church_id,
            title,
            event_type,
            description,
            location,
            category,
            status,
            visibility,
            cover_image_url,
            pastoral_publication_id,
            recurrence_rule,
            attendance_required,
            is_public,
            registration_fee_mzn,
            starts_at,
            ends_at,
            registration_required,
            capacity,
            created_at
          ''').eq('church_id', churchId).order('starts_at');
    } catch (_) {
      try {
        rows = await _client.from('events').select('''
              id,
              church_id,
              title,
              event_type,
              description,
              location,
              category,
              status,
              visibility,
              cover_image_url,
              recurrence_rule,
              attendance_required,
              is_public,
              registration_fee_mzn,
              starts_at,
              ends_at,
              registration_required,
              capacity,
              created_at
            ''').eq('church_id', churchId).order('starts_at');
      } catch (_) {
        rows = await _client.from('events').select('''
              id,
              church_id,
              title,
              description,
              location,
              status:event_status,
              starts_at,
              ends_at,
              registration_required,
              capacity,
              created_at
            ''').eq('church_id', churchId).order('starts_at');
      }
    }

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ManagedEvent.fromMap)
        .toList();
  }

  @override
  Future<ManagedEvent> saveChurchEvent({
    String? eventId,
    required String churchId,
    required String title,
    required String eventType,
    String? description,
    String? location,
    String? category,
    String? status,
    String? visibility,
    String? coverImageUrl,
    String? recurrenceRule,
    bool? attendanceRequired,
    bool? isPublic,
    num? registrationFeeMzn,
    required DateTime startsAt,
    DateTime? endsAt,
    required bool registrationRequired,
    int? capacity,
  }) async {
    final payload = <String, dynamic>{
      'church_id': churchId,
      'title': title.trim(),
      'event_type': eventType,
      'description': description == null || description.trim().isEmpty
          ? null
          : description.trim(),
      'location':
          location == null || location.trim().isEmpty ? null : location.trim(),
      'category':
          category == null || category.trim().isEmpty ? null : category.trim(),
      'status': status ?? 'draft',
      'visibility': visibility ?? 'members',
      'cover_image_url': coverImageUrl == null || coverImageUrl.trim().isEmpty
          ? null
          : coverImageUrl.trim(),
      'recurrence_rule': recurrenceRule == null || recurrenceRule.trim().isEmpty
          ? null
          : recurrenceRule.trim(),
      'attendance_required': attendanceRequired ?? true,
      'is_public': isPublic ?? false,
      'registration_fee_mzn': registrationFeeMzn,
      'payment_required': (registrationFeeMzn ?? 0) > 0,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt?.toUtc().toIso8601String(),
      'registration_required': registrationRequired,
      'capacity': capacity,
      if (eventId == null && _currentUserId != null)
        'created_by': _currentUserId,
    };

    try {
      final row = eventId == null
          ? await _client.from('events').insert(payload).select('''
                id,
                church_id,
                title,
                event_type,
                description,
                location,
                category,
                status,
                visibility,
                cover_image_url,
                pastoral_publication_id,
                recurrence_rule,
                attendance_required,
                is_public,
                registration_fee_mzn,
                starts_at,
                ends_at,
                registration_required,
                capacity,
                created_at
              ''').single()
          : await _client
              .from('events')
              .update(payload)
              .eq('id', eventId)
              .select('''
                id,
                church_id,
                title,
                event_type,
                description,
                location,
                category,
                status,
                visibility,
                cover_image_url,
                recurrence_rule,
                attendance_required,
                is_public,
                registration_fee_mzn,
                starts_at,
                ends_at,
                registration_required,
                capacity,
                created_at
              ''').single();

      return ManagedEvent.fromMap(row);
    } catch (error) {
      if (!_looksLikeSchemaDrift(error)) {
        rethrow;
      }

      final compatiblePayload = Map<String, dynamic>.from(payload)
        ..remove('payment_required');

      try {
        final row = eventId == null
            ? await _client.from('events').insert(compatiblePayload).select('''
                  id,
                  church_id,
                  title,
                  event_type,
                  description,
                  location,
                  category,
                  status,
                  visibility,
                  cover_image_url,
                  pastoral_publication_id,
                  recurrence_rule,
                  attendance_required,
                  is_public,
                  registration_fee_mzn,
                  starts_at,
                  ends_at,
                  registration_required,
                  capacity,
                  created_at
                ''').single()
            : await _client
                .from('events')
                .update(compatiblePayload)
                .eq('id', eventId)
                .select('''
                  id,
                  church_id,
                  title,
                  event_type,
                  description,
                  location,
                  category,
                  status,
                  visibility,
                  cover_image_url,
                  recurrence_rule,
                  attendance_required,
                  is_public,
                  registration_fee_mzn,
                  starts_at,
                  ends_at,
                  registration_required,
                  capacity,
                  created_at
                ''').single();

        return ManagedEvent.fromMap(row);
      } catch (_) {
        // Fall through to the oldest schema shape below.
      }

      final legacyPayload = <String, dynamic>{
        'church_id': churchId,
        'title': title.trim(),
        'event_type': eventType,
        'description': description == null || description.trim().isEmpty
            ? null
            : description.trim(),
        'location': location == null || location.trim().isEmpty
            ? null
            : location.trim(),
        'event_status': status ?? 'published',
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt?.toUtc().toIso8601String(),
        'registration_required': registrationRequired,
        'capacity': capacity,
        if (eventId == null && _currentUserId != null)
          'created_by': _currentUserId,
      };

      final row = eventId == null
          ? await _client.from('events').insert(legacyPayload).select('''
                id,
                church_id,
                title,
                event_type,
                description,
                location,
                status:event_status,
                starts_at,
                ends_at,
                registration_required,
                capacity,
                created_at
              ''').single()
          : await _client
              .from('events')
              .update(legacyPayload)
              .eq('id', eventId)
              .select('''
                id,
                church_id,
                title,
                event_type,
                description,
                location,
                status:event_status,
                starts_at,
                ends_at,
                registration_required,
                capacity,
                created_at
              ''').single();

      return ManagedEvent.fromMap(row);
    }
  }

  @override
  Future<void> deleteChurchEvent(String eventId) async {
    await _client.from('events').delete().eq('id', eventId);
  }

  @override
  Future<List<ManagedPrayerRequest>> fetchChurchPrayerRequests(
    String churchId, {
    int limit = 10,
  }) async {
    final rows = await _client
        .from('prayer_requests')
        .select('''
          id,
          church_id,
          profile_id,
          title,
          description,
          is_private,
          visibility,
          anonymous_request,
          allow_responses,
          status,
          created_at,
          profile:profiles (
            full_name,
            phone
          )
        ''')
        .eq('church_id', churchId)
        .order('created_at', ascending: false)
        .limit(limit);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ManagedPrayerRequest.fromMap)
        .toList();
  }

  @override
  Future<List<ManagedPrayerResponse>> fetchPrayerRequestResponses(
    String prayerRequestId,
  ) async {
    final rows = await _client.from('prayer_request_responses').select('''
          id,
          prayer_request_id,
          church_id,
          responder_profile_id,
          body,
          created_at,
          responder:profiles (
            full_name
          )
        ''').eq('prayer_request_id', prayerRequestId).order('created_at');

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ManagedPrayerResponse.fromMap)
        .toList();
  }

  @override
  Future<ManagedPrayerResponse> respondToPrayerRequest({
    required String prayerRequestId,
    required String body,
  }) async {
    final responderId = _currentUserId;
    if (responderId == null) {
      throw StateError('Sessao expirada. Entra novamente para responder.');
    }

    final row = await _client.from('prayer_request_responses').insert({
      'prayer_request_id': prayerRequestId,
      'responder_profile_id': responderId,
      'body': body.trim(),
    }).select('''
          id,
          prayer_request_id,
          church_id,
          responder_profile_id,
          body,
          created_at,
          responder:profiles (
            full_name
          )
        ''').single();

    await _client
        .from('prayer_requests')
        .update({'status': 'answered'}).eq('id', prayerRequestId);

    return ManagedPrayerResponse.fromMap(row);
  }

  @override
  Future<List<ChurchMinistry>> fetchChurchMinistries(String churchId) async {
    final rows = await _client.from('church_ministries').select('''
          id,
          church_id,
          name,
          description,
          active,
          leader_membership_id,
          created_at,
          leader:memberships (
            id,
            profile:profiles (
              full_name
            )
          ),
          ministry_members (
            membership_id
          )
        ''').eq('church_id', churchId).order('name');

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ChurchMinistry.fromMap)
        .toList();
  }

  @override
  Future<ChurchMinistry> saveChurchMinistry({
    String? ministryId,
    required String churchId,
    required String name,
    String? description,
    String? leaderMembershipId,
    required bool active,
    required List<String> memberMembershipIds,
  }) async {
    final payload = <String, dynamic>{
      'church_id': churchId,
      'name': name.trim(),
      'description': description == null || description.trim().isEmpty
          ? null
          : description.trim(),
      'leader_membership_id': leaderMembershipId,
      'active': active,
    };

    final row = ministryId == null
        ? await _client
            .from('church_ministries')
            .insert(payload)
            .select('id')
            .single()
        : await _client
            .from('church_ministries')
            .update(payload)
            .eq('id', ministryId)
            .select('id')
            .single();

    final resolvedId = (row['id'] as String?) ?? ministryId;
    if (resolvedId == null) {
      throw StateError('Ministerio nao encontrado depois de guardar.');
    }

    await _client
        .from('ministry_members')
        .delete()
        .eq('ministry_id', resolvedId);

    final normalizedIds = <String>{
      ...memberMembershipIds.where((id) => id.trim().isNotEmpty),
      if (leaderMembershipId != null && leaderMembershipId.trim().isNotEmpty)
        leaderMembershipId.trim(),
    }.toList(growable: false);

    if (normalizedIds.isNotEmpty) {
      await _client.from('ministry_members').insert(
            normalizedIds
                .map(
                  (membershipId) => {
                    'ministry_id': resolvedId,
                    'membership_id': membershipId,
                    'role': membershipId == leaderMembershipId
                        ? 'leader'
                        : 'member',
                  },
                )
                .toList(),
          );
    }

    final ministry = await _fetchChurchMinistryById(resolvedId);
    if (ministry == null) {
      throw StateError('Ministerio nao encontrado depois de guardar.');
    }
    return ministry;
  }

  @override
  Future<void> deleteChurchMinistry(String ministryId) async {
    await _client.from('church_ministries').delete().eq('id', ministryId);
  }

  @override
  Future<List<ChurchAsset>> fetchChurchAssets(String churchId) async {
    final rows = await _client.from('church_assets').select('''
          id,
          church_id,
          category,
          name,
          quantity,
          item_condition,
          location,
          notes,
          created_at
        ''').eq('church_id', churchId).order('created_at', ascending: false);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ChurchAsset.fromMap)
        .toList();
  }

  @override
  Future<ChurchAsset> saveChurchAsset({
    String? assetId,
    required String churchId,
    required String category,
    required String name,
    required int quantity,
    required String itemCondition,
    String? location,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'church_id': churchId,
      'category': category,
      'name': name.trim(),
      'quantity': quantity,
      'item_condition': itemCondition,
      'location':
          location == null || location.trim().isEmpty ? null : location.trim(),
      'notes': notes == null || notes.trim().isEmpty ? null : notes.trim(),
      if (assetId == null && _currentUserId != null)
        'created_by': _currentUserId,
    };

    final row = assetId == null
        ? await _client
            .from('church_assets')
            .insert(payload)
            .select('id')
            .single()
        : await _client
            .from('church_assets')
            .update(payload)
            .eq('id', assetId)
            .select('id')
            .single();

    final resolvedId = (row['id'] as String?) ?? assetId;
    if (resolvedId == null) {
      throw StateError('Patrimonio nao encontrado depois de guardar.');
    }

    final asset = await _fetchChurchAssetById(resolvedId);
    if (asset == null) {
      throw StateError('Patrimonio nao encontrado depois de guardar.');
    }
    return asset;
  }

  @override
  Future<void> deleteChurchAsset(String assetId) async {
    await _client.from('church_assets').delete().eq('id', assetId);
  }

  @override
  Future<List<ChurchVisitor>> fetchChurchVisitors(String churchId) async {
    final rows = await _client
        .from('church_visitors')
        .select('''
          id,
          church_id,
          full_name,
          phone,
          status,
          first_visit_at,
          notes,
          created_at
        ''')
        .eq('church_id', churchId)
        .order('first_visit_at', ascending: false);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ChurchVisitor.fromMap)
        .toList();
  }

  @override
  Future<ChurchVisitor> saveChurchVisitor({
    String? visitorId,
    required String churchId,
    required String fullName,
    String? phone,
    required String status,
    required DateTime firstVisitAt,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'church_id': churchId,
      'full_name': fullName.trim(),
      'phone': phone == null || phone.trim().isEmpty ? null : phone.trim(),
      'status': status,
      'first_visit_at': firstVisitAt.toUtc().toIso8601String(),
      'notes': notes == null || notes.trim().isEmpty ? null : notes.trim(),
      if (visitorId == null && _currentUserId != null)
        'created_by': _currentUserId,
    };

    final row = visitorId == null
        ? await _client
            .from('church_visitors')
            .insert(payload)
            .select('id')
            .single()
        : await _client
            .from('church_visitors')
            .update(payload)
            .eq('id', visitorId)
            .select('id')
            .single();

    final resolvedId = (row['id'] as String?) ?? visitorId;
    if (resolvedId == null) {
      throw StateError('Visitante nao encontrado depois de guardar.');
    }

    final visitor = await _fetchChurchVisitorById(resolvedId);
    if (visitor == null) {
      throw StateError('Visitante nao encontrado depois de guardar.');
    }
    return visitor;
  }

  @override
  Future<void> deleteChurchVisitor(String visitorId) async {
    await _client.from('church_visitors').delete().eq('id', visitorId);
  }

  @override
  Future<List<ChurchExpense>> fetchChurchExpenses(String churchId) async {
    final rows = await _client.from('church_expenses').select('''
          id,
          church_id,
          category,
          title,
          amount,
          currency,
          spent_at,
          notes,
          vendor_name,
          payment_method,
          payment_reference,
          proof_url,
          cost_center,
          status,
          approved_at,
          paid_at,
          rejection_reason,
          is_demo,
          created_at
        ''').eq('church_id', churchId).order('spent_at', ascending: false);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ChurchExpense.fromMap)
        .toList();
  }

  @override
  Future<ChurchExpense> saveChurchExpense({
    String? expenseId,
    required String churchId,
    required String category,
    required String title,
    required num amount,
    required DateTime spentAt,
    String? notes,
    String? vendorName,
    String? paymentMethod,
    String? paymentReference,
    String? proofUrl,
    String? costCenter,
    String status = 'paid',
  }) async {
    final payload = <String, dynamic>{
      'church_id': churchId,
      'category': category,
      'title': title.trim(),
      'amount': amount,
      'spent_at': spentAt.toUtc().toIso8601String(),
      'notes': notes == null || notes.trim().isEmpty ? null : notes.trim(),
      'vendor_name': vendorName == null || vendorName.trim().isEmpty
          ? null
          : vendorName.trim(),
      'payment_method': paymentMethod == null || paymentMethod.trim().isEmpty
          ? null
          : paymentMethod.trim(),
      'payment_reference':
          paymentReference == null || paymentReference.trim().isEmpty
              ? null
              : paymentReference.trim(),
      'proof_url':
          proofUrl == null || proofUrl.trim().isEmpty ? null : proofUrl.trim(),
      'cost_center': costCenter == null || costCenter.trim().isEmpty
          ? null
          : costCenter.trim(),
      'status': status,
      if (expenseId == null && _currentUserId != null)
        'created_by': _currentUserId,
      if (expenseId == null && _currentUserId != null)
        'requested_by': _currentUserId,
      if (status == 'paid') 'paid_at': spentAt.toUtc().toIso8601String(),
    };

    final row = expenseId == null
        ? await _client
            .from('church_expenses')
            .insert(payload)
            .select('id')
            .single()
        : await _client
            .from('church_expenses')
            .update(payload)
            .eq('id', expenseId)
            .select('id')
            .single();

    final resolvedId = (row['id'] as String?) ?? expenseId;
    if (resolvedId == null) {
      throw StateError('Despesa nao encontrada depois de guardar.');
    }

    final expense = await _fetchChurchExpenseById(resolvedId);
    if (expense == null) {
      throw StateError('Despesa nao encontrada depois de guardar.');
    }
    return expense;
  }

  @override
  Future<void> deleteChurchExpense(String expenseId) async {
    await _client.from('church_expenses').delete().eq('id', expenseId);
  }

  @override
  Future<List<ChurchCommunication>> fetchChurchCommunications(
    String churchId,
  ) async {
    final rows = await _client.from('church_communications').select('''
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
        ''').eq('church_id', churchId).order('created_at', ascending: false);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ChurchCommunication.fromMap)
        .toList();
  }

  @override
  Future<ChurchCommunication> saveChurchCommunication({
    String? communicationId,
    required String churchId,
    required String channel,
    required String audienceType,
    String? targetRole,
    String? ministryId,
    String? membershipId,
    required String title,
    required String body,
    required String status,
    DateTime? scheduledAt,
  }) async {
    final payload = <String, dynamic>{
      'church_id': churchId,
      'channel': channel,
      'audience_type': audienceType,
      'target_role':
          audienceType == 'group' && targetRole != null && targetRole.isNotEmpty
              ? targetRole
              : null,
      'ministry_id': audienceType == 'ministry' ? ministryId : null,
      'membership_id': audienceType == 'person' ? membershipId : null,
      'title': title.trim(),
      'body': body.trim(),
      'status': status,
      'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
      if (communicationId == null && _currentUserId != null)
        'created_by': _currentUserId,
    };

    final row = communicationId == null
        ? await _client
            .from('church_communications')
            .insert(payload)
            .select('id')
            .single()
        : await _client
            .from('church_communications')
            .update(payload)
            .eq('id', communicationId)
            .select('id')
            .single();

    final resolvedId = (row['id'] as String?) ?? communicationId;
    if (resolvedId == null) {
      throw StateError(
        'Comunicacao nao encontrada depois de guardar.',
      );
    }

    final communication = await _fetchChurchCommunicationById(resolvedId);
    if (communication == null) {
      throw StateError(
        'Comunicacao nao encontrada depois de guardar.',
      );
    }
    return communication;
  }

  @override
  Future<void> deleteChurchCommunication(String communicationId) async {
    await _client
        .from('church_communications')
        .delete()
        .eq('id', communicationId);
  }

  @override
  Future<ChurchSubscription?> fetchChurchSubscription(String churchId) async {
    final row = await _client.from('church_subscriptions').select('''
          church_id,
          plan_code,
          status,
          trial_ends_at,
          current_period_ends_at,
          grace_period_ends_at,
          admin_notes
        ''').eq('church_id', churchId).maybeSingle();

    if (row == null) {
      return null;
    }

    return ChurchSubscription.fromMap(row);
  }

  @override
  Future<List<SubscriptionPlan>> fetchSubscriptionPlans() async {
    final rows = await _client
        .from('subscription_plans')
        .select(
            'code, name, description, price_mzn, member_limit, admin_limit, billing_cycle_days, features, is_paid')
        .eq('is_public', true)
        .order('sort_order');

    return rows
        .whereType<Map<String, dynamic>>()
        .map(SubscriptionPlan.fromMap)
        .toList();
  }

  @override
  Future<List<ChurchSubscriptionRequest>> fetchChurchSubscriptionRequests(
    String churchId,
  ) async {
    final rows = await _client.from('church_subscription_requests').select('''
          id,
          church_id,
          requested_plan_code,
          status,
          requested_at,
          reviewed_at,
          review_notes,
          payment_provider,
          payer_phone,
          payment_reference,
          payment_notes,
          expected_amount_mzn,
          payment_submitted_at,
          requested_by
        ''').eq('church_id', churchId).order('requested_at', ascending: false);

    return _hydrateSubscriptionRequestRows(rows);
  }

  @override
  Future<ChurchSubscriptionRequest> requestSubscriptionPlan({
    required String churchId,
    required String planCode,
    String? paymentProvider,
    String? payerPhone,
    String? paymentReference,
    String? paymentNotes,
  }) async {
    final row = await _client.rpc(
      'submit_subscription_plan_request',
      params: {
        'p_church_id': churchId,
        'p_plan_code': planCode,
        'p_payment_provider': paymentProvider,
        'p_payer_phone': payerPhone,
        'p_payment_reference': paymentReference,
        'p_payment_notes': paymentNotes,
      },
    );

    return ChurchSubscriptionRequest.fromMap(
      Map<String, dynamic>.from(row as Map),
    );
  }

  @override
  Future<Map<String, dynamic>> createPaysuiteCheckout({
    required num amountMzn,
    required String provider,
    required String phone,
    required String description,
  }) async {
    final response = await _client.functions.invoke(
      'comunhao-create-paysuite-checkout',
      body: {
        'amount': amountMzn,
        'provider': provider,
        'phone_number': phone,
        'description': description,
      },
    );
    final data = response.data;
    if (data is! Map) throw StateError('Resposta inválida da PaySuite.');
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<List<ChurchApplication>> fetchApplicationsForReview() async {
    final rows = await _client.from('church_applications').select('''
          id,
          pastor_profile_id,
          church_name,
          city,
          province,
          country,
          phone,
          email,
          applicant_role,
          logo_url,
          primary_color,
          secondary_color,
          tagline,
          mpesa,
          emola,
          bank_name,
          bank_account_name,
          bank_account_number,
          status,
          submitted_at,
          reviewed_at,
          review_notes,
          approved_church_id
        ''').order('submitted_at', ascending: true);

    final applicationRows = rows
        .whereType<Map<String, dynamic>>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);

    final pastorIds = applicationRows
        .map((row) => row['pastor_profile_id'])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (pastorIds.isNotEmpty) {
      final profileRows = await _client
          .from('profiles')
          .select('id, full_name, phone')
          .inFilter('id', pastorIds);
      final profilesById = {
        for (final profile in profileRows.whereType<Map<String, dynamic>>())
          if (profile['id'] is String) profile['id'] as String: profile,
      };
      for (final application in applicationRows) {
        final pastorId = application['pastor_profile_id'];
        final profile = pastorId is String ? profilesById[pastorId] : null;
        if (profile != null) {
          application['pastor'] = profile;
        }
      }
    }

    return applicationRows.map(ChurchApplication.fromMap).toList();
  }

  @override
  Future<List<ChurchOverview>> fetchChurchOverviews() async {
    List<dynamic> rows;
    try {
      rows = await _client
          .from('churches')
          .select(_churchOverviewSelect)
          .order('created_at', ascending: false);
    } catch (_) {
      rows = await _client
          .from('churches')
          .select(_legacyChurchOverviewSelect)
          .order('created_at', ascending: false);
    }

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ChurchOverview.fromMap)
        .toList();
  }

  @override
  Future<ChurchOverview> setChurchActiveState({
    required String churchId,
    required bool active,
    String? notes,
  }) async {
    try {
      await _client.rpc(
        'admin_set_church_active_state',
        params: {
          'p_church_id': churchId,
          'p_active': active,
          'p_notes': notes,
        },
      );
    } catch (_) {
      await _client
          .from('churches')
          .update({'active': active}).eq('id', churchId);
    }

    final overview = await _fetchChurchOverviewById(churchId);
    if (overview == null) {
      throw StateError('Igreja nao encontrada depois da atualizacao.');
    }

    await _tryCreatePlatformAuditLog(
      action: 'church.active_state.updated',
      targetType: 'church',
      targetId: churchId,
      churchId: churchId,
      summary:
          'Igreja ${overview.name} foi ${active ? 'reativada' : 'desativada'}.',
      details: {
        'church_id': churchId,
        'church_name': overview.name,
        'active': active,
        'notes': notes,
      },
    );

    return overview;
  }

  @override
  Future<ChurchOverview> transferChurchOwnership({
    required String churchId,
    required String newOwnerProfileId,
    String newRole = 'pastor',
    String? notes,
  }) async {
    await _client.rpc(
      'transfer_church_owner',
      params: {
        'p_church_id': churchId,
        'p_new_owner_profile_id': newOwnerProfileId,
        'p_new_role': newRole,
      },
    );

    final overview = await _fetchChurchOverviewById(churchId);
    if (overview == null) {
      throw StateError('Igreja nao encontrada depois da transferencia.');
    }

    await _tryCreatePlatformAuditLog(
      action: 'church.owner.transferred',
      targetType: 'church',
      targetId: churchId,
      churchId: churchId,
      summary:
          'A propriedade administrativa da igreja ${overview.name} foi transferida.',
      details: {
        'church_id': churchId,
        'church_name': overview.name,
        'new_owner_profile_id': newOwnerProfileId,
        'new_owner_name': overview.ownerName,
        'new_role': newRole,
        'notes': notes,
      },
    );

    return overview;
  }

  @override
  Future<Map<String, dynamic>> resetChurchWorkspace({
    required String churchId,
    String? notes,
  }) async {
    final result = await _client.rpc(
      'reset_church_workspace',
      params: {'p_church_id': churchId},
    );

    final overview = await _fetchChurchOverviewById(churchId);
    final payload = Map<String, dynamic>.from(result as Map);

    await _tryCreatePlatformAuditLog(
      action: 'church.workspace.reset',
      targetType: 'church',
      targetId: churchId,
      churchId: churchId,
      summary:
          'Foi executado um reset operacional na igreja ${overview?.name ?? 'Igreja'}.',
      details: {
        ...payload,
        'church_id': churchId,
        'church_name': overview?.name,
        'notes': notes,
      },
    );

    return payload;
  }

  @override
  Future<String?> reviewChurchApplication({
    required String applicationId,
    required String decision,
    String? notes,
  }) async {
    final result = await _client.rpc(
      'review_church_application',
      params: {
        'p_application_id': applicationId,
        'p_decision': decision,
        'p_review_notes': notes,
      },
    );
    final approvedChurchId = result as String?;

    await _tryCreatePlatformAuditLog(
      action: 'church_application.reviewed',
      targetType: 'church_application',
      targetId: applicationId,
      churchId: approvedChurchId,
      summary: 'Pedido de igreja processado com decisao $decision.',
      details: {
        'application_id': applicationId,
        'decision': decision,
        'notes': notes,
        'approved_church_id': approvedChurchId,
      },
    );

    return approvedChurchId;
  }

  @override
  Future<List<ChurchSubscriptionRequest>>
      fetchPendingSubscriptionRequests() async {
    final rows = await _client.from('church_subscription_requests').select('''
          id,
          church_id,
          requested_plan_code,
          status,
          requested_at,
          reviewed_at,
          review_notes,
          payment_provider,
          payer_phone,
          payment_reference,
          payment_notes,
          expected_amount_mzn,
          payment_submitted_at,
          requested_by
        ''').order('requested_at');

    return _hydrateSubscriptionRequestRows(rows);
  }

  @override
  Future<ChurchSubscription?> reviewSubscriptionRequest({
    required String requestId,
    required String decision,
    int? periodDays,
    String? notes,
  }) async {
    final result = await _client.rpc(
      'review_subscription_request',
      params: {
        'p_request_id': requestId,
        'p_decision': decision,
        'p_period_days': periodDays,
        'p_review_notes': notes,
      },
    );

    if (result == null) {
      await _tryCreatePlatformAuditLog(
        action: 'church.subscription_request.reviewed',
        targetType: 'subscription_request',
        targetId: requestId,
        summary: 'Pedido de plano rejeitado pela equipa da plataforma.',
        details: {
          'request_id': requestId,
          'decision': decision,
          'period_days': periodDays,
          'notes': notes,
        },
      );
      return null;
    }

    final subscription =
        ChurchSubscription.fromMap(Map<String, dynamic>.from(result as Map));
    await _tryCreatePlatformAuditLog(
      action: 'church.subscription_request.reviewed',
      targetType: 'subscription_request',
      targetId: requestId,
      churchId: subscription.churchId,
      summary:
          'Pedido de plano aprovado para a igreja ${subscription.churchId}.',
      details: {
        'request_id': requestId,
        'decision': decision,
        'period_days': periodDays,
        'notes': notes,
        'church_id': subscription.churchId,
        'plan_code': subscription.planCode,
        'status': subscription.status,
      },
    );
    return subscription;
  }

  @override
  Future<ChurchSubscription> adminUpdateChurchSubscription({
    required String churchId,
    required String status,
    String? planCode,
    int? periodDays,
    int? graceDays,
    String? notes,
  }) async {
    final result = await _client.rpc(
      'admin_update_church_subscription',
      params: {
        'p_church_id': churchId,
        'p_status': status,
        'p_plan_code': planCode,
        'p_period_days': periodDays,
        'p_grace_days': graceDays,
        'p_notes': notes,
      },
    );

    final subscription =
        ChurchSubscription.fromMap(Map<String, dynamic>.from(result as Map));
    await _tryCreatePlatformAuditLog(
      action: 'church.subscription.updated',
      targetType: 'church',
      targetId: churchId,
      churchId: churchId,
      summary:
          'Subscricao da igreja atualizada para ${subscription.planLabel} (${subscription.statusLabel}).',
      details: {
        'church_id': churchId,
        'status': status,
        'plan_code': subscription.planCode,
        'period_days': periodDays,
        'grace_days': graceDays,
        'notes': notes,
      },
    );
    return subscription;
  }
}
