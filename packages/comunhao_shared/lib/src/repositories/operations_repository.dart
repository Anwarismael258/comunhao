import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/operations_models.dart';

class OperationsSnapshot {
  const OperationsSnapshot({
    required this.metrics,
    required this.groups,
    required this.tasks,
    required this.rosters,
    required this.maintenance,
    required this.documents,
    required this.purchases,
    required this.inventory,
  });

  final OperationalMetrics metrics;
  final List<ChurchGroup> groups;
  final List<OperationalTask> tasks;
  final List<ServiceRoster> rosters;
  final List<MaintenanceRequest> maintenance;
  final List<ChurchDocument> documents;
  final List<PurchaseRequest> purchases;
  final List<InventoryItem> inventory;
}

class MemberOperationsSnapshot {
  const MemberOperationsSnapshot({
    required this.metrics,
    required this.groups,
    required this.tasks,
    required this.rosters,
    required this.joinRequests,
    required this.opportunities,
    required this.applications,
  });

  final OperationalMetrics metrics;
  final List<ChurchGroup> groups;
  final List<OperationalTask> tasks;
  final List<ServiceRoster> rosters;
  final List<MinistryJoinRequest> joinRequests;
  final List<VolunteerOpportunity> opportunities;
  final List<VolunteerApplication> applications;
}

abstract class OperationsRepository {
  Future<PlatformOperationalMetrics> fetchPlatformOperationalMetrics();
  Future<OperationsSnapshot> fetchSnapshot(String churchId);
  Future<MemberOperationsSnapshot> fetchMemberOperations({
    required String churchId,
    required String membershipId,
  });
  Future<ChurchGroup> saveGroup({
    String? groupId,
    required String churchId,
    String? ministryId,
    required String name,
    required String groupType,
    String? description,
    String? location,
    String? usualDay,
    String? usualTime,
  });
  Future<OperationalTask> saveTask({
    String? taskId,
    required String churchId,
    String? ministryId,
    String? groupId,
    required String title,
    String? description,
    String? responsibleMembershipId,
    required String priority,
    required String status,
    DateTime? dueAt,
  });
  Future<ServiceRoster> saveRoster({
    String? rosterId,
    required String churchId,
    String? ministryId,
    required String roleTitle,
    required String assignedMembershipId,
    required DateTime startsAt,
    DateTime? endsAt,
    String? location,
    String? instructions,
  });
  Future<MaintenanceRequest> saveMaintenance({
    String? maintenanceId,
    required String churchId,
    String? assetId,
    required String problem,
    required String priority,
    String? supplier,
    num? estimatedCost,
    DateTime? expectedAt,
  });
  Future<ChurchDocument> saveDocument({
    String? documentId,
    required String churchId,
    required String title,
    required String documentType,
    String? description,
    DateTime? validUntil,
    required String confidentiality,
    String? storageBucket,
    String? storagePath,
  });
  Future<PurchaseRequest> savePurchaseRequest({
    String? requestId,
    required String churchId,
    String? ministryId,
    required String requestedByMembershipId,
    required String itemName,
    required int quantity,
    String? justification,
    num? estimatedAmount,
  });
  Future<InventoryItem> saveInventoryItem({
    String? itemId,
    required String churchId,
    String? ministryId,
    required String name,
    required String unit,
    required num quantityCurrent,
    required num quantityMinimum,
    String? location,
  });
  Future<MinistryJoinRequest> createMinistryJoinRequest({
    required String churchId,
    required String membershipId,
    String? ministryId,
    String? groupId,
    String? interest,
    String? experience,
  });
  Future<VolunteerApplication> applyToVolunteerOpportunity({
    required String opportunityId,
    required String membershipId,
    String? notes,
  });
  Future<ServiceRoster> respondToRoster({
    required String rosterId,
    required String status,
    String? notes,
  });
  Future<void> clearDemoData(String churchId);
}

class SupabaseOperationsRepository implements OperationsRepository {
  SupabaseOperationsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _currentUserId => _client.auth.currentUser?.id;

  @override
  Future<PlatformOperationalMetrics> fetchPlatformOperationalMetrics() async {
    final result = await _client.rpc('get_platform_operational_metrics');
    return PlatformOperationalMetrics.fromMap(
      Map<String, dynamic>.from(result as Map),
    );
  }

  @override
  Future<OperationsSnapshot> fetchSnapshot(String churchId) async {
    final results = await Future.wait<dynamic>([
      _client.rpc('get_operational_metrics', params: {'p_church_id': churchId}),
      _client
          .from('church_groups')
          .select(
              'id, church_id, name, group_type, description, location, usual_day, usual_time, status, created_at')
          .eq('church_id', churchId)
          .order('created_at', ascending: false)
          .limit(20),
      _client
          .from('operational_tasks')
          .select(
              'id, church_id, title, description, priority, status, due_at, progress_percent')
          .eq('church_id', churchId)
          .order('due_at')
          .limit(20),
      _client.from('service_rosters').select('''
            id,
            church_id,
            role_title,
            starts_at,
            location,
            status,
            assigned:memberships!service_rosters_assigned_membership_id_fkey (
              profile:profiles (
                full_name
              )
            )
          ''').eq('church_id', churchId).order('starts_at').limit(20),
      _client
          .from('maintenance_requests')
          .select('id, church_id, problem, priority, status, expected_at')
          .eq('church_id', churchId)
          .order('created_at', ascending: false)
          .limit(20),
      _client
          .from('church_documents')
          .select('id, title, document_type, valid_until, confidentiality')
          .eq('church_id', churchId)
          .order('valid_until')
          .limit(20),
      _client
          .from('purchase_requests')
          .select('id, item_name, quantity, estimated_amount, status')
          .eq('church_id', churchId)
          .order('created_at', ascending: false)
          .limit(20),
      _client
          .from('inventory_items')
          .select('id, name, unit, quantity_current, quantity_minimum')
          .eq('church_id', churchId)
          .order('name')
          .limit(20),
    ]);

    return OperationsSnapshot(
      metrics: OperationalMetrics.fromMap(
        Map<String, dynamic>.from(results[0] as Map),
      ),
      groups: (results[1] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ChurchGroup.fromMap)
          .toList(),
      tasks: (results[2] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(OperationalTask.fromMap)
          .toList(),
      rosters: (results[3] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ServiceRoster.fromMap)
          .toList(),
      maintenance: (results[4] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(MaintenanceRequest.fromMap)
          .toList(),
      documents: (results[5] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ChurchDocument.fromMap)
          .toList(),
      purchases: (results[6] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(PurchaseRequest.fromMap)
          .toList(),
      inventory: (results[7] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(InventoryItem.fromMap)
          .toList(),
    );
  }

  @override
  Future<MemberOperationsSnapshot> fetchMemberOperations({
    required String churchId,
    required String membershipId,
  }) async {
    final results = await Future.wait<dynamic>([
      _client.rpc('get_operational_metrics', params: {'p_church_id': churchId}),
      _client
          .from('church_groups')
          .select(
              'id, church_id, name, group_type, description, location, usual_day, usual_time, status, created_at')
          .eq('church_id', churchId)
          .order('created_at', ascending: false)
          .limit(20),
      _client
          .from('operational_tasks')
          .select(
              'id, church_id, title, description, priority, status, due_at, progress_percent')
          .eq('church_id', churchId)
          .order('due_at')
          .limit(20),
      _client.from('service_rosters').select('''
            id,
            church_id,
            role_title,
            starts_at,
            location,
            status,
            assigned:memberships!service_rosters_assigned_membership_id_fkey (
              profile:profiles (
                full_name
              )
            )
          ''').eq('church_id', churchId).order('starts_at').limit(20),
      _client.from('ministry_join_requests').select('''
            id,
            church_id,
            interest,
            experience,
            status,
            created_at,
            ministry:church_ministries (
              name
            ),
            group:church_groups (
              name
            )
          ''').eq('membership_id', membershipId).order(
            'created_at',
            ascending: false,
          ),
      _client.from('volunteer_opportunities').select('''
            id,
            church_id,
            title,
            description,
            starts_at,
            location,
            slots,
            requirements,
            status,
            ministry:church_ministries (
              name
            )
          ''').eq('church_id', churchId).eq('status', 'open').order(
            'starts_at',
            nullsFirst: false,
          ),
      _client.from('volunteer_applications').select('''
            id,
            opportunity_id,
            status,
            notes,
            created_at,
            opportunity:volunteer_opportunities (
              title
            )
          ''').eq('membership_id', membershipId).order(
            'created_at',
            ascending: false,
          ),
    ]);

    return MemberOperationsSnapshot(
      metrics: OperationalMetrics.fromMap(
        Map<String, dynamic>.from(results[0] as Map),
      ),
      groups: (results[1] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ChurchGroup.fromMap)
          .toList(),
      tasks: (results[2] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(OperationalTask.fromMap)
          .toList(),
      rosters: (results[3] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ServiceRoster.fromMap)
          .toList(),
      joinRequests: (results[4] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(MinistryJoinRequest.fromMap)
          .toList(),
      opportunities: (results[5] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(VolunteerOpportunity.fromMap)
          .toList(),
      applications: (results[6] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(VolunteerApplication.fromMap)
          .toList(),
    );
  }

  @override
  Future<ChurchGroup> saveGroup({
    String? groupId,
    required String churchId,
    String? ministryId,
    required String name,
    required String groupType,
    String? description,
    String? location,
    String? usualDay,
    String? usualTime,
  }) async {
    final payload = {
      'church_id': churchId,
      'ministry_id': ministryId,
      'name': name.trim(),
      'group_type': groupType,
      'description': _clean(description),
      'location': _clean(location),
      'usual_day': _clean(usualDay),
      'usual_time': _clean(usualTime),
      if (groupId == null && _currentUserId != null)
        'created_by': _currentUserId,
    };
    final row = await _upsert('church_groups', payload, groupId);
    return ChurchGroup.fromMap(row);
  }

  @override
  Future<OperationalTask> saveTask({
    String? taskId,
    required String churchId,
    String? ministryId,
    String? groupId,
    required String title,
    String? description,
    String? responsibleMembershipId,
    required String priority,
    required String status,
    DateTime? dueAt,
  }) async {
    final payload = {
      'church_id': churchId,
      'ministry_id': ministryId,
      'group_id': groupId,
      'title': title.trim(),
      'description': _clean(description),
      'responsible_membership_id': responsibleMembershipId,
      'priority': priority,
      'status': status,
      'due_at': dueAt?.toUtc().toIso8601String(),
      if (taskId == null && _currentUserId != null)
        'created_by': _currentUserId,
    };
    final row = await _upsert('operational_tasks', payload, taskId);
    return OperationalTask.fromMap(row);
  }

  @override
  Future<ServiceRoster> saveRoster({
    String? rosterId,
    required String churchId,
    String? ministryId,
    required String roleTitle,
    required String assignedMembershipId,
    required DateTime startsAt,
    DateTime? endsAt,
    String? location,
    String? instructions,
  }) async {
    final payload = {
      'church_id': churchId,
      'ministry_id': ministryId,
      'role_title': roleTitle.trim(),
      'assigned_membership_id': assignedMembershipId,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt?.toUtc().toIso8601String(),
      'location': _clean(location),
      'instructions': _clean(instructions),
      if (rosterId == null && _currentUserId != null)
        'created_by': _currentUserId,
    };
    final row = await _upsert('service_rosters', payload, rosterId);
    return ServiceRoster.fromMap(row);
  }

  @override
  Future<MaintenanceRequest> saveMaintenance({
    String? maintenanceId,
    required String churchId,
    String? assetId,
    required String problem,
    required String priority,
    String? supplier,
    num? estimatedCost,
    DateTime? expectedAt,
  }) async {
    final payload = {
      'church_id': churchId,
      'asset_id': assetId,
      'problem': problem.trim(),
      'priority': priority,
      'supplier': _clean(supplier),
      'estimated_cost': estimatedCost,
      'expected_at': expectedAt?.toUtc().toIso8601String(),
      if (maintenanceId == null && _currentUserId != null)
        'created_by': _currentUserId,
    };
    final row = await _upsert('maintenance_requests', payload, maintenanceId);
    return MaintenanceRequest.fromMap(row);
  }

  @override
  Future<ChurchDocument> saveDocument({
    String? documentId,
    required String churchId,
    required String title,
    required String documentType,
    String? description,
    DateTime? validUntil,
    required String confidentiality,
    String? storageBucket,
    String? storagePath,
  }) async {
    final payload = {
      'church_id': churchId,
      'title': title.trim(),
      'document_type': documentType,
      'description': _clean(description),
      'valid_until': validUntil?.toIso8601String().substring(0, 10),
      'confidentiality': confidentiality,
      'storage_bucket': _clean(storageBucket),
      'storage_path': _clean(storagePath),
      if (documentId == null && _currentUserId != null)
        'author_profile_id': _currentUserId,
    };
    final row = await _upsert('church_documents', payload, documentId);
    if (storageBucket == 'church-documents' && storagePath?.trim().isNotEmpty == true) {
      try {
        await _client.functions.invoke('register-central-file', body: {
          'church_id': churchId,
          'document_id': row['id'],
          'path': storagePath!.trim(),
        });
      } catch (_) {
        // The church document remains valid if the Central is temporarily unavailable.
      }
    }
    return ChurchDocument.fromMap(row);
  }

  @override
  Future<PurchaseRequest> savePurchaseRequest({
    String? requestId,
    required String churchId,
    String? ministryId,
    required String requestedByMembershipId,
    required String itemName,
    required int quantity,
    String? justification,
    num? estimatedAmount,
  }) async {
    final payload = {
      'church_id': churchId,
      'ministry_id': ministryId,
      'requested_by_membership_id': requestedByMembershipId,
      'item_name': itemName.trim(),
      'quantity': quantity,
      'justification': _clean(justification),
      'estimated_amount': estimatedAmount,
    };
    final row = await _upsert('purchase_requests', payload, requestId);
    return PurchaseRequest.fromMap(row);
  }

  @override
  Future<InventoryItem> saveInventoryItem({
    String? itemId,
    required String churchId,
    String? ministryId,
    required String name,
    required String unit,
    required num quantityCurrent,
    required num quantityMinimum,
    String? location,
  }) async {
    final payload = {
      'church_id': churchId,
      'ministry_id': ministryId,
      'name': name.trim(),
      'unit': unit.trim(),
      'quantity_current': quantityCurrent,
      'quantity_minimum': quantityMinimum,
      'location': _clean(location),
      if (itemId == null && _currentUserId != null)
        'created_by': _currentUserId,
    };
    final row = await _upsert('inventory_items', payload, itemId);
    return InventoryItem.fromMap(row);
  }

  @override
  Future<MinistryJoinRequest> createMinistryJoinRequest({
    required String churchId,
    required String membershipId,
    String? ministryId,
    String? groupId,
    String? interest,
    String? experience,
  }) async {
    final row = await _client.from('ministry_join_requests').insert({
      'church_id': churchId,
      'membership_id': membershipId,
      'ministry_id': ministryId,
      'group_id': groupId,
      'interest': _clean(interest),
      'experience': _clean(experience),
    }).select('''
          id,
          church_id,
          interest,
          experience,
          status,
          created_at,
          ministry:church_ministries (
            name
          ),
          group:church_groups (
            name
          )
        ''').single();
    return MinistryJoinRequest.fromMap(row);
  }

  @override
  Future<VolunteerApplication> applyToVolunteerOpportunity({
    required String opportunityId,
    required String membershipId,
    String? notes,
  }) async {
    final row = await _client.from('volunteer_applications').upsert({
      'opportunity_id': opportunityId,
      'membership_id': membershipId,
      'notes': _clean(notes),
    }, onConflict: 'opportunity_id,membership_id').select('''
          id,
          opportunity_id,
          status,
          notes,
          created_at,
          opportunity:volunteer_opportunities (
            title
          )
        ''').single();
    return VolunteerApplication.fromMap(row);
  }

  @override
  Future<ServiceRoster> respondToRoster({
    required String rosterId,
    required String status,
    String? notes,
  }) async {
    final row = await _client.rpc(
      'respond_own_service_roster',
      params: {
        'p_roster_id': rosterId,
        'p_status': status,
        'p_notes': notes,
      },
    );
    return ServiceRoster.fromMap(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<void> clearDemoData(String churchId) async {
    await _client
        .rpc('clear_church_demo_data', params: {'p_church_id': churchId});
  }

  Future<Map<String, dynamic>> _upsert(
    String table,
    Map<String, dynamic> payload,
    String? id,
  ) async {
    if (id == null) {
      return await _client.from(table).insert(payload).select().single();
    }
    return await _client
        .from(table)
        .update(payload)
        .eq('id', id)
        .select()
        .single();
  }

  String? _clean(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }
}
