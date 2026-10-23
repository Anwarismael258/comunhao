class WalletProviderSummary {
  const WalletProviderSummary({
    required this.provider,
    required this.balance,
    required this.totalCredits,
    required this.totalDebits,
    required this.incomingToday,
    required this.incomingMonth,
    this.pendingBalance = 0,
    this.reservedBalance = 0,
  });

  final String provider;
  final num balance;
  final num totalCredits;
  final num totalDebits;
  final num incomingToday;
  final num incomingMonth;
  final num pendingBalance;
  final num reservedBalance;

  String get label => switch (provider) {
        'mpesa' => 'M-Pesa (Vodacom)',
        'emola' => 'E-Mola (Movitel)',
        _ => provider,
      };

  factory WalletProviderSummary.fromMap(Map<String, dynamic> map) {
    return WalletProviderSummary(
      provider: (map['provider'] as String?) ?? '',
      balance: (map['balance'] as num?) ?? 0,
      totalCredits: (map['total_credits'] as num?) ?? 0,
      totalDebits: (map['total_debits'] as num?) ?? 0,
      incomingToday: (map['incoming_today'] as num?) ?? 0,
      incomingMonth: (map['incoming_month'] as num?) ?? 0,
      pendingBalance: (map['pending_balance'] as num?) ?? 0,
      reservedBalance: (map['reserved_balance'] as num?) ?? 0,
    );
  }
}
