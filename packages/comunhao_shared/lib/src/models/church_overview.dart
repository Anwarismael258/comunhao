import 'church_subscription.dart';

class ChurchOverview {
  const ChurchOverview({
    required this.id,
    required this.name,
    required this.slug,
    this.joinCode,
    this.city,
    required this.active,
    required this.createdAt,
    this.ownerProfileId,
    this.ownerName,
    this.ownerPhone,
    this.subscription,
  });

  final String id;
  final String name;
  final String slug;
  final String? joinCode;
  final String? city;
  final bool active;
  final DateTime createdAt;
  final String? ownerProfileId;
  final String? ownerName;
  final String? ownerPhone;
  final ChurchSubscription? subscription;

  factory ChurchOverview.fromMap(Map<String, dynamic> map) {
    final rawSubscription = map['church_subscriptions'];
    final rawSettings = map['church_settings'];
    final subscriptionMap = switch (rawSubscription) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => null,
    };
    final settingsMap = switch (rawSettings) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => null,
    };
    final rawOwner = settingsMap?['owner'];
    final ownerMap = switch (rawOwner) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => null,
    };

    return ChurchOverview(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Igreja',
      slug: (map['slug'] as String?) ?? '',
      joinCode: map['join_code'] as String?,
      city: map['city'] as String?,
      active: (map['active'] as bool?) ?? true,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      ownerProfileId: settingsMap?['owner_profile_id'] as String?,
      ownerName: ownerMap?['full_name'] as String?,
      ownerPhone: ownerMap?['phone'] as String?,
      subscription: subscriptionMap == null
          ? null
          : ChurchSubscription.fromMap({
              ...subscriptionMap,
              if (!subscriptionMap.containsKey('church_id'))
                'church_id': map['id'],
            }),
    );
  }
}
