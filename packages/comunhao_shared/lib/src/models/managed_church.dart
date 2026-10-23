import 'church_subscription.dart';

class ManagedChurch {
  const ManagedChurch({
    required this.id,
    required this.name,
    required this.slug,
    this.joinCode,
    this.city,
    this.phone,
    this.email,
    this.tagline,
    this.logoUrl,
    this.primaryColor,
    this.secondaryColor,
    required this.role,
    required this.status,
    this.subscription,
  });

  final String id;
  final String name;
  final String slug;
  final String? joinCode;
  final String? city;
  final String? phone;
  final String? email;
  final String? tagline;
  final String? logoUrl;
  final String? primaryColor;
  final String? secondaryColor;
  final String role;
  final String status;
  final ChurchSubscription? subscription;

  bool get canManage =>
      status == 'active' && const {'pastor', 'church_admin'}.contains(role);

  factory ManagedChurch.fromMembershipMap(Map<String, dynamic> map) {
    final rawChurch = map['church'];
    final church = switch (rawChurch) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => const <String, dynamic>{},
    };

    final rawSubscription = church['church_subscriptions'];
    final subscriptionMap = switch (rawSubscription) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => null,
    };

    return ManagedChurch(
      id: (church['id'] as String?) ?? '',
      name: (church['name'] as String?) ?? 'Igreja',
      slug: (church['slug'] as String?) ?? '',
      joinCode: church['join_code'] as String?,
      city: church['city'] as String?,
      phone: church['phone'] as String?,
      email: church['email'] as String?,
      tagline: church['tagline'] as String?,
      logoUrl: church['logo_url'] as String?,
      primaryColor: church['primary_color'] as String?,
      secondaryColor: church['secondary_color'] as String?,
      role: (map['role'] as String?) ?? 'member',
      status: (map['status'] as String?) ?? 'active',
      subscription: subscriptionMap == null
          ? null
          : ChurchSubscription.fromMap({
              ...subscriptionMap,
              if (!subscriptionMap.containsKey('church_id'))
                'church_id': church['id'],
            }),
    );
  }
}
