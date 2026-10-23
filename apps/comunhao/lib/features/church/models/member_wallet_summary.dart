class MemberWalletSummary {
  const MemberWalletSummary({
    required this.id,
    this.phone,
    required this.currency,
    required this.availableBalance,
    required this.pendingBalance,
    required this.totalReceived,
    required this.totalContributed,
    required this.provider,
  });

  final String id;
  final String? phone;
  final String currency;
  final num availableBalance;
  final num pendingBalance;
  final num totalReceived;
  final num totalContributed;
  final String provider;

  String get providerLabel => provider == 'emola' ? 'E-Mola' : 'M-Pesa';

  factory MemberWalletSummary.fromMap(Map<String, dynamic> map) {
    return MemberWalletSummary(
      id: (map['id'] as String?) ?? '',
      phone: map['phone'] as String?,
      currency: (map['currency'] as String?) ?? 'MZN',
      availableBalance: (map['available_balance'] as num?) ?? 0,
      pendingBalance: (map['pending_balance'] as num?) ?? 0,
      totalReceived: (map['total_received'] as num?) ?? 0,
      totalContributed: (map['total_contributed'] as num?) ?? 0,
      provider: (map['provider'] as String?) ?? 'mpesa',
    );
  }
}
