import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/church_contribution.dart';
import '../models/church_finance_snapshot.dart';
import '../models/wallet_ledger_entry.dart';
import '../models/wallet_provider_summary.dart';
import '../models/wallet_withdrawal_request.dart';

abstract class FinanceRepository {
  Future<List<WalletProviderSummary>> fetchWalletDashboard({
    required String ownerType,
    String? churchId,
  });

  Future<List<WalletLedgerEntry>> fetchWalletLedger({
    required String ownerType,
    String? churchId,
    int limit,
  });

  Future<List<WalletWithdrawalRequest>> fetchWithdrawalRequests({
    String? ownerType,
    String? churchId,
    int limit,
  });

  Future<ChurchFinanceSnapshot> fetchChurchFinanceSnapshot({
    required String churchId,
    bool includeDemo,
  });

  Future<List<ChurchContribution>> fetchChurchContributions({
    required String churchId,
    int limit,
    String? status,
  });

  Future<ChurchContribution> createChurchContribution({
    required String churchId,
    required String contributionType,
    required num amount,
    required String method,
    String? provider,
    String? campaignId,
    String? memberProfileId,
    String? payerPhone,
    String? reference,
    String? proofUrl,
    String? notes,
    bool confirmImmediately,
    String? idempotencyKey,
  });

  Future<ChurchContribution> confirmChurchContribution({
    required String donationId,
    String? internalNote,
    String? idempotencyKey,
  });

  Future<ChurchContribution> rejectChurchContribution({
    required String donationId,
    required String reason,
  });

  Future<String> recordMemberDonation({
    required String churchId,
    required String donationType,
    required num amount,
    required String provider,
    String? campaignId,
  });

  Future<WalletLedgerEntry> recordPlatformRevenue({
    required String provider,
    required num amount,
    String entryType,
    String? description,
  });

  Future<WalletWithdrawalRequest> createWithdrawalRequest({
    required String ownerType,
    required String provider,
    required num amount,
    required String destinationNumber,
    String? churchId,
    String? notes,
  });

  Future<WalletWithdrawalRequest> reviewWithdrawalRequest({
    required String requestId,
    required String status,
    String? notes,
  });
}

class SupabaseFinanceRepository implements FinanceRepository {
  SupabaseFinanceRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

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
      // Best effort while audit migrations are being rolled out.
    }
  }

  @override
  Future<List<WalletProviderSummary>> fetchWalletDashboard({
    required String ownerType,
    String? churchId,
  }) async {
    final rows = await _client.rpc(
      'get_wallet_dashboard',
      params: {
        'p_owner_type': ownerType,
        'p_church_id': churchId,
      },
    );

    return (rows as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(WalletProviderSummary.fromMap)
        .toList();
  }

  @override
  Future<List<WalletLedgerEntry>> fetchWalletLedger({
    required String ownerType,
    String? churchId,
    int limit = 50,
  }) async {
    final rows = await _client.rpc(
      'get_wallet_ledger',
      params: {
        'p_owner_type': ownerType,
        'p_church_id': churchId,
        'p_limit': limit,
      },
    );

    return (rows as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(WalletLedgerEntry.fromMap)
        .toList();
  }

  @override
  Future<List<WalletWithdrawalRequest>> fetchWithdrawalRequests({
    String? ownerType,
    String? churchId,
    int limit = 50,
  }) async {
    final rows = await _client.rpc(
      'get_wallet_withdrawal_requests',
      params: {
        'p_owner_type': ownerType,
        'p_church_id': churchId,
        'p_limit': limit,
      },
    );

    return (rows as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(WalletWithdrawalRequest.fromMap)
        .toList();
  }

  @override
  Future<ChurchFinanceSnapshot> fetchChurchFinanceSnapshot({
    required String churchId,
    bool includeDemo = false,
  }) async {
    final row = await _client.rpc(
      'get_church_finance_snapshot',
      params: {
        'p_church_id': churchId,
        'p_include_demo': includeDemo,
      },
    );

    return ChurchFinanceSnapshot.fromMap(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<List<ChurchContribution>> fetchChurchContributions({
    required String churchId,
    int limit = 100,
    String? status,
  }) async {
    final rows = await _client.rpc(
      'get_church_contributions',
      params: {
        'p_church_id': churchId,
        'p_limit': limit,
        'p_status': status,
      },
    );

    return (rows as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(ChurchContribution.fromMap)
        .toList();
  }

  @override
  Future<ChurchContribution> createChurchContribution({
    required String churchId,
    required String contributionType,
    required num amount,
    required String method,
    String? provider,
    String? campaignId,
    String? memberProfileId,
    String? payerPhone,
    String? reference,
    String? proofUrl,
    String? notes,
    bool confirmImmediately = false,
    String? idempotencyKey,
  }) async {
    final result = await _client.rpc(
      'create_church_contribution',
      params: {
        'p_church_id': churchId,
        'p_contribution_type': contributionType,
        'p_amount': amount,
        'p_method': method,
        'p_provider': provider,
        'p_campaign_id': campaignId,
        'p_member_profile_id': memberProfileId,
        'p_payer_phone': payerPhone,
        'p_reference': reference,
        'p_proof_url': proofUrl,
        'p_notes': notes,
        'p_confirm_immediately': confirmImmediately,
        'p_idempotency_key': idempotencyKey,
      },
    );

    return ChurchContribution.fromMap(Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<ChurchContribution> confirmChurchContribution({
    required String donationId,
    String? internalNote,
    String? idempotencyKey,
  }) async {
    final result = await _client.rpc(
      'confirm_church_contribution',
      params: {
        'p_donation_id': donationId,
        'p_internal_note': internalNote,
        'p_idempotency_key': idempotencyKey,
      },
    );

    return ChurchContribution.fromMap(Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<ChurchContribution> rejectChurchContribution({
    required String donationId,
    required String reason,
  }) async {
    final result = await _client.rpc(
      'reject_church_contribution',
      params: {
        'p_donation_id': donationId,
        'p_reason': reason,
      },
    );

    return ChurchContribution.fromMap(Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<String> recordMemberDonation({
    required String churchId,
    required String donationType,
    required num amount,
    required String provider,
    String? campaignId,
  }) async {
    final result = await _client.rpc(
      'record_member_donation',
      params: {
        'p_church_id': churchId,
        'p_donation_type': donationType,
        'p_amount': amount,
        'p_provider': provider,
        'p_campaign_id': campaignId,
      },
    );

    return '$result';
  }

  @override
  Future<WalletLedgerEntry> recordPlatformRevenue({
    required String provider,
    required num amount,
    String entryType = 'subscription_payment',
    String? description,
  }) async {
    final result = await _client.rpc(
      'record_platform_wallet_revenue',
      params: {
        'p_provider': provider,
        'p_amount': amount,
        'p_entry_type': entryType,
        'p_description': description,
      },
    );

    final entry =
        WalletLedgerEntry.fromMap(Map<String, dynamic>.from(result as Map));
    await _tryCreatePlatformAuditLog(
      action: 'wallet.platform_revenue.recorded',
      targetType: 'wallet_ledger_entry',
      targetId: entry.id,
      summary: 'Receita da plataforma registada em ${entry.provider}.',
      details: {
        'provider': provider,
        'amount': amount,
        'entry_type': entryType,
        'description': description,
      },
    );
    return entry;
  }

  @override
  Future<WalletWithdrawalRequest> createWithdrawalRequest({
    required String ownerType,
    required String provider,
    required num amount,
    required String destinationNumber,
    String? churchId,
    String? notes,
  }) async {
    final result = await _client.rpc(
      'create_wallet_withdrawal_request',
      params: {
        'p_owner_type': ownerType,
        'p_provider': provider,
        'p_amount': amount,
        'p_destination_number': destinationNumber,
        'p_church_id': churchId,
        'p_notes': notes,
      },
    );

    final request = WalletWithdrawalRequest.fromMap(
      Map<String, dynamic>.from(result as Map),
    );
    if (ownerType == 'platform') {
      await _tryCreatePlatformAuditLog(
        action: 'wallet.withdrawal.requested',
        targetType: 'wallet_withdrawal_request',
        targetId: request.id,
        summary: 'Novo pedido de levantamento da carteira Comunhao.',
        details: {
          'provider': provider,
          'amount': amount,
          'destination_number': destinationNumber,
          'notes': notes,
        },
      );
    }
    return request;
  }

  @override
  Future<WalletWithdrawalRequest> reviewWithdrawalRequest({
    required String requestId,
    required String status,
    String? notes,
  }) async {
    final result = await _client.rpc(
      'review_wallet_withdrawal_request',
      params: {
        'p_request_id': requestId,
        'p_status': status,
        'p_notes': notes,
      },
    );

    final request = WalletWithdrawalRequest.fromMap(
      Map<String, dynamic>.from(result as Map),
    );
    await _tryCreatePlatformAuditLog(
      action: 'wallet.withdrawal.updated',
      targetType: 'wallet_withdrawal_request',
      targetId: request.id,
      churchId: request.churchId,
      summary: 'Levantamento atualizado para ${request.statusLabel}.',
      details: {
        'request_id': requestId,
        'status': status,
        'notes': notes,
        'owner_type': request.ownerType,
        'church_id': request.churchId,
        'amount': request.amount,
        'provider': request.provider,
      },
    );
    return request;
  }
}
