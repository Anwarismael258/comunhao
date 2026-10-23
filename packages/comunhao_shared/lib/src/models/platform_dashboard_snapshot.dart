class PlatformDashboardSnapshot {
  const PlatformDashboardSnapshot({
    this.totalChurches = 0,
    this.activeChurches = 0,
    this.inactiveChurches = 0,
    this.totalMembers = 0,
    this.totalPastors = 0,
    this.pendingApplications = 0,
    this.pendingPlanRequests = 0,
    this.pendingWithdrawals = 0,
    this.monthRevenue = 0,
    this.yearRevenue = 0,
    this.trialChurches = 0,
    this.graceChurches = 0,
    this.suspendedChurches = 0,
    this.expiringSoonSubscriptions = 0,
    this.starterRevenue = 0,
    this.essentialRevenue = 0,
    this.premiumRevenue = 0,
  });

  final int totalChurches;
  final int activeChurches;
  final int inactiveChurches;
  final int totalMembers;
  final int totalPastors;
  final int pendingApplications;
  final int pendingPlanRequests;
  final int pendingWithdrawals;
  final num monthRevenue;
  final num yearRevenue;
  final int trialChurches;
  final int graceChurches;
  final int suspendedChurches;
  final int expiringSoonSubscriptions;
  final num starterRevenue;
  final num essentialRevenue;
  final num premiumRevenue;

  factory PlatformDashboardSnapshot.fromMap(Map<String, dynamic> map) {
    return PlatformDashboardSnapshot(
      totalChurches: (map['total_churches'] as num?)?.toInt() ?? 0,
      activeChurches: (map['active_churches'] as num?)?.toInt() ?? 0,
      inactiveChurches: (map['inactive_churches'] as num?)?.toInt() ?? 0,
      totalMembers: (map['total_members'] as num?)?.toInt() ?? 0,
      totalPastors: (map['total_pastors'] as num?)?.toInt() ?? 0,
      pendingApplications: (map['pending_applications'] as num?)?.toInt() ?? 0,
      pendingPlanRequests: (map['pending_plan_requests'] as num?)?.toInt() ?? 0,
      pendingWithdrawals: (map['pending_withdrawals'] as num?)?.toInt() ?? 0,
      monthRevenue: (map['month_revenue'] as num?) ?? 0,
      yearRevenue: (map['year_revenue'] as num?) ?? 0,
      trialChurches: (map['trial_churches'] as num?)?.toInt() ?? 0,
      graceChurches: (map['grace_churches'] as num?)?.toInt() ?? 0,
      suspendedChurches: (map['suspended_churches'] as num?)?.toInt() ?? 0,
      expiringSoonSubscriptions:
          (map['expiring_soon_subscriptions'] as num?)?.toInt() ?? 0,
      starterRevenue: (map['starter_revenue'] as num?) ?? 0,
      essentialRevenue: (map['essential_revenue'] as num?) ?? 0,
      premiumRevenue: (map['premium_revenue'] as num?) ?? 0,
    );
  }
}
