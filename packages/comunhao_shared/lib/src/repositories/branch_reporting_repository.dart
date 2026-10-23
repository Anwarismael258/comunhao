import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/branch_reporting_models.dart';

abstract class BranchReportingRepository {
  Future<OrganizationDashboard> fetchDashboard({
    required String churchId,
    required bool includeDemo,
  });

  Future<String> createBranch({
    required String parentChurchId,
    required String name,
    required String unitType,
    String? city,
    String? province,
    String? pastorPhone,
    String? leaderPhone,
    required String unitStatus,
    required bool isDemo,
  });

  Future<String> createTransferRequest({
    required String memberPhone,
    required String originChurchId,
    required String destinationChurchId,
    String? reason,
    String? notes,
    required bool isDemo,
  });

  Future<String> registerReportExport({
    required String reportId,
    required String format,
    required bool containsSensitiveData,
  });

  Future<void> resolveAlert({
    required String alertId,
    required String resolution,
  });
}

class SupabaseBranchReportingRepository implements BranchReportingRepository {
  SupabaseBranchReportingRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<OrganizationDashboard> fetchDashboard({
    required String churchId,
    required bool includeDemo,
  }) async {
    final response = await _client.rpc(
      'get_organization_dashboard',
      params: {
        'p_church_id': churchId,
        'p_include_demo': includeDemo,
      },
    );
    return OrganizationDashboard.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }

  @override
  Future<String> createBranch({
    required String parentChurchId,
    required String name,
    required String unitType,
    String? city,
    String? province,
    String? pastorPhone,
    String? leaderPhone,
    required String unitStatus,
    required bool isDemo,
  }) async {
    final response = await _client.rpc(
      'create_branch_unit',
      params: {
        'p_parent_church_id': parentChurchId,
        'p_name': name,
        'p_unit_type': unitType,
        'p_city': city,
        'p_province': province,
        'p_pastor_phone': pastorPhone,
        'p_leader_phone': leaderPhone,
        'p_unit_status': unitStatus,
        'p_is_demo': isDemo,
      },
    );
    return response as String;
  }

  @override
  Future<String> createTransferRequest({
    required String memberPhone,
    required String originChurchId,
    required String destinationChurchId,
    String? reason,
    String? notes,
    required bool isDemo,
  }) async {
    final response = await _client.rpc(
      'create_member_transfer_request',
      params: {
        'p_member_phone': memberPhone,
        'p_origin_church_id': originChurchId,
        'p_destination_church_id': destinationChurchId,
        'p_reason': reason,
        'p_notes': notes,
        'p_is_demo': isDemo,
      },
    );
    return response as String;
  }

  @override
  Future<String> registerReportExport({
    required String reportId,
    required String format,
    required bool containsSensitiveData,
  }) async {
    final response = await _client.rpc(
      'register_executive_report_export',
      params: {
        'p_report_id': reportId,
        'p_format': format,
        'p_filters': <String, dynamic>{},
        'p_contains_sensitive_data': containsSensitiveData,
      },
    );
    return response as String;
  }

  @override
  Future<void> resolveAlert({
    required String alertId,
    required String resolution,
  }) async {
    await _client.rpc(
      'resolve_executive_alert',
      params: {
        'p_alert_id': alertId,
        'p_resolution': resolution,
      },
    );
  }
}
