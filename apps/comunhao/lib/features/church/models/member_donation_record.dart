class MemberDonationRecord {
  const MemberDonationRecord({
    required this.id,
    required this.amount,
    required this.currency,
    required this.donationType,
    this.provider,
    required this.status,
    required this.createdAt,
    this.campaignTitle,
  });

  final String id;
  final num amount;
  final String currency;
  final String donationType;
  final String? provider;
  final String status;
  final DateTime createdAt;
  final String? campaignTitle;

  String get receiptCode {
    final raw = id.replaceAll('-', '').toUpperCase();
    if (raw.length >= 10) {
      return 'RCB-${raw.substring(0, 10)}';
    }
    return 'RCB-$raw';
  }

  String get donationTypeLabel => switch (donationType) {
        'tithe' => 'Dizimo',
        'campaign' => 'Campanha',
        _ => 'Oferta',
      };

  String get providerLabel => switch ((provider ?? '').toLowerCase()) {
        'mpesa' => 'M-Pesa',
        'emola' => 'E-Mola',
        _ => 'Manual',
      };

  String get statusLabel => switch (status) {
        'pending' => 'Aguardando confirmacao',
        'processing' => 'Em processamento',
        'provider_not_configured' => 'Aguardando configuracao do provedor',
        'pending_manual_confirmation' => 'Aguardando confirmacao manual',
        'confirmed' => 'Confirmado',
        'recorded' => 'Confirmado',
        'rejected' => 'Rejeitado',
        'cancelled' => 'Cancelado',
        'refunded' => 'Reembolsado',
        'failed' => 'Falhou',
        _ => 'Registado',
      };

  factory MemberDonationRecord.fromMap(Map<String, dynamic> map) {
    final rawCampaign = map['campaign'];
    final campaign = switch (rawCampaign) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => const <String, dynamic>{},
    };

    return MemberDonationRecord(
      id: (map['id'] as String?) ?? '',
      amount: (map['amount'] as num?) ?? 0,
      currency: (map['currency'] as String?) ?? 'MZN',
      donationType: (map['donation_type'] as String?) ?? 'offering',
      provider: map['provider'] as String?,
      status: (map['status'] as String?) ?? 'recorded',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      campaignTitle: campaign['title'] as String?,
    );
  }
}
