class ChurchFinanceSnapshot {
  const ChurchFinanceSnapshot({
    required this.availableBalance,
    required this.pendingBalance,
    required this.receivedToday,
    required this.monthRevenue,
    required this.monthExpenses,
    required this.monthNet,
    required this.totalWithdrawn,
    required this.pendingContributions,
    required this.pendingWithdrawals,
  });

  final num availableBalance;
  final num pendingBalance;
  final num receivedToday;
  final num monthRevenue;
  final num monthExpenses;
  final num monthNet;
  final num totalWithdrawn;
  final int pendingContributions;
  final int pendingWithdrawals;

  factory ChurchFinanceSnapshot.empty() {
    return const ChurchFinanceSnapshot(
      availableBalance: 0,
      pendingBalance: 0,
      receivedToday: 0,
      monthRevenue: 0,
      monthExpenses: 0,
      monthNet: 0,
      totalWithdrawn: 0,
      pendingContributions: 0,
      pendingWithdrawals: 0,
    );
  }

  factory ChurchFinanceSnapshot.fromMap(Map<String, dynamic> map) {
    return ChurchFinanceSnapshot(
      availableBalance: (map['available_balance'] as num?) ?? 0,
      pendingBalance: (map['pending_balance'] as num?) ?? 0,
      receivedToday: (map['received_today'] as num?) ?? 0,
      monthRevenue: (map['month_revenue'] as num?) ?? 0,
      monthExpenses: (map['month_expenses'] as num?) ?? 0,
      monthNet: (map['month_net'] as num?) ?? 0,
      totalWithdrawn: (map['total_withdrawn'] as num?) ?? 0,
      pendingContributions:
          (map['pending_contributions'] as num?)?.toInt() ?? 0,
      pendingWithdrawals: (map['pending_withdrawals'] as num?)?.toInt() ?? 0,
    );
  }
}
