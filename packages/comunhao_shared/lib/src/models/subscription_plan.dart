class SubscriptionPlan {
  const SubscriptionPlan({
    required this.code,
    required this.name,
    this.description,
    this.priceMzn = 0,
    this.memberLimit,
    this.adminLimit,
    this.features = const [],
    this.isPaid = false,
    this.billingCycleDays = 30,
  });

  final String code;
  final String name;
  final String? description;
  final num priceMzn;
  final int? memberLimit;
  final int? adminLimit;
  final List<String> features;
  final bool isPaid;
  final int billingCycleDays;

  bool get isStarter => code == 'starter';

  String get priceLabel => '${priceMzn.toStringAsFixed(0)} MT / mes';

  String get adminLimitLabel => adminLimit == null
      ? 'Administradores ilimitados'
      : 'Ate $adminLimit administradores';

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map) {
    final rawFeatures = map['features'];
    final features = switch (rawFeatures) {
      List<dynamic> value => value.map((item) => '$item').toList(),
      _ => const <String>[],
    };

    return SubscriptionPlan(
      code: (map['code'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      description: map['description'] as String?,
      priceMzn: (map['price_mzn'] as num?) ?? 0,
      memberLimit: map['member_limit'] as int?,
      adminLimit: map['admin_limit'] as int?,
      features: features,
      isPaid: (map['is_paid'] as bool?) ?? false,
      billingCycleDays: (map['billing_cycle_days'] as int?) ?? 30,
    );
  }
}
