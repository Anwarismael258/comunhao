class ChurchContribution {
  const ChurchContribution({
    required this.id,
    required this.churchId,
    this.profileId,
    this.memberName,
    this.memberPhone,
    this.campaignId,
    this.campaignTitle,
    required this.amount,
    required this.currency,
    required this.donationType,
    required this.paymentMethod,
    this.provider,
    this.providerReference,
    this.proofUrl,
    required this.status,
    this.confirmedBy,
    this.confirmedAt,
    this.rejectionReason,
    this.receiptNumber,
    this.validationCode,
    required this.isDemo,
    required this.createdAt,
  });

  final String id;
  final String churchId;
  final String? profileId;
  final String? memberName;
  final String? memberPhone;
  final String? campaignId;
  final String? campaignTitle;
  final num amount;
  final String currency;
  final String donationType;
  final String paymentMethod;
  final String? provider;
  final String? providerReference;
  final String? proofUrl;
  final String status;
  final String? confirmedBy;
  final DateTime? confirmedAt;
  final String? rejectionReason;
  final String? receiptNumber;
  final String? validationCode;
  final bool isDemo;
  final DateTime createdAt;

  bool get isPending => const {
        'pending',
        'processing',
        'provider_not_configured',
        'pending_manual_confirmation',
      }.contains(status);

  bool get isConfirmed => status == 'confirmed';

  String get contributorLabel {
    final name = memberName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'Contribuinte anonimo';
  }

  String get typeLabel => switch (donationType) {
        'tithe' => 'Dizimo',
        'campaign' => 'Campanha',
        'missions' => 'Missoes',
        'construction' => 'Construcao',
        'social_support' => 'Apoio social',
        'event' => 'Evento',
        'special' => 'Contribuicao especial',
        'other' => 'Outro',
        _ => 'Oferta',
      };

  String get methodLabel => switch ((provider ?? paymentMethod).toLowerCase()) {
        'mpesa' => 'M-Pesa',
        'emola' => 'E-Mola',
        'visa' => 'Visa',
        'mastercard' => 'Mastercard',
        'bank' => 'Conta bancaria',
        'manual_transfer' => 'Transferencia manual',
        'cash' => 'Numerario',
        'pos' => 'POS',
        _ => paymentMethod,
      };

  String get statusLabel => switch (status) {
        'draft' => 'Rascunho',
        'pending' => 'Pendente',
        'processing' => 'Em processamento',
        'provider_not_configured' => 'Provedor nao configurado',
        'pending_manual_confirmation' => 'Aguardando confirmacao manual',
        'confirmed' => 'Confirmada',
        'rejected' => 'Rejeitada',
        'cancelled' => 'Cancelada',
        'refunded' => 'Reembolsada',
        'failed' => 'Falhou',
        _ => status,
      };

  factory ChurchContribution.fromMap(Map<String, dynamic> map) {
    return ChurchContribution(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      profileId: map['profile_id'] as String?,
      memberName: map['member_name'] as String?,
      memberPhone: map['member_phone'] as String?,
      campaignId: map['campaign_id'] as String?,
      campaignTitle: map['campaign_title'] as String?,
      amount: (map['amount'] as num?) ?? 0,
      currency: (map['currency'] as String?) ?? 'MZN',
      donationType: (map['donation_type'] as String?) ??
          (map['contribution_type'] as String?) ??
          'offering',
      paymentMethod: (map['payment_method'] as String?) ?? '',
      provider: map['provider'] as String?,
      providerReference: map['provider_reference'] as String?,
      proofUrl: map['proof_url'] as String?,
      status: (map['status'] as String?) ?? 'pending',
      confirmedBy: map['confirmed_by'] as String?,
      confirmedAt: DateTime.tryParse((map['confirmed_at'] as String?) ?? ''),
      rejectionReason: map['rejection_reason'] as String?,
      receiptNumber: map['receipt_number'] as String?,
      validationCode: map['validation_code'] as String?,
      isDemo: (map['is_demo'] as bool?) ?? false,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
