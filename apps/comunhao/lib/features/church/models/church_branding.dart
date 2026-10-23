import 'package:comunhao_shared/comunhao_shared.dart';

import 'payment_channel.dart';

class ChurchBranding {
  const ChurchBranding({
    required this.id,
    required this.name,
    required this.slug,
    required this.appName,
    this.joinCode,
    this.logoUrl,
    this.primaryColor,
    this.secondaryColor,
    this.phone,
    this.email,
    this.city,
    this.country,
    this.tagline,
    this.heroTitle,
    this.heroSubtitle,
    this.defaultCurrency = 'MZN',
    this.paymentChannels = const [],
    this.subscriptionPlanCode,
    this.subscriptionStatus,
    this.trialEndsAt,
    this.subscriptionEndsAt,
    this.currentPeriodEndsAt,
    this.gracePeriodEndsAt,
    this.activeMemberCount = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String appName;
  final String? joinCode;
  final String? logoUrl;
  final String? primaryColor;
  final String? secondaryColor;
  final String? phone;
  final String? email;
  final String? city;
  final String? country;
  final String? tagline;
  final String? heroTitle;
  final String? heroSubtitle;
  final String defaultCurrency;
  final List<PaymentChannel> paymentChannels;
  final String? subscriptionPlanCode;
  final String? subscriptionStatus;
  final DateTime? trialEndsAt;
  final DateTime? subscriptionEndsAt;
  final DateTime? currentPeriodEndsAt;
  final DateTime? gracePeriodEndsAt;
  final int activeMemberCount;

  String get headline => heroTitle ?? 'Comunhao para a tua igreja.';

  String get supportingText =>
      heroSubtitle ??
      'Uma plataforma white-label para doacoes, avisos, eventos e comunidade.';

  String get locationLabel {
    final parts =
        [city, country].whereType<String>().where((e) => e.isNotEmpty);
    return parts.join(', ');
  }

  String get codeLabel => joinCode ?? slug.toUpperCase();

  bool get allowsMemberAccess {
    final status = effectiveSubscriptionStatus;
    if (status.isEmpty) {
      return true;
    }
    return const {'trial', 'active'}.contains(status);
  }

  bool get isSubscriptionSuspended => const {
        'overdue',
        'grace_period',
        'suspended',
        'cancelled'
      }.contains(effectiveSubscriptionStatus);

  String get effectiveSubscriptionStatus => resolveEffectiveSubscriptionStatus(
        status: subscriptionStatus,
        planCode: subscriptionPlanCode,
        trialEndsAt: trialEndsAt,
        currentPeriodEndsAt: currentPeriodEndsAt,
        gracePeriodEndsAt: gracePeriodEndsAt,
      );

  String get subscriptionStatusLabel {
    if (subscriptionStatus == null || subscriptionStatus!.trim().isEmpty) {
      return 'Sem subscricao';
    }
    return subscriptionStatusLabelFromCode(effectiveSubscriptionStatus);
  }

  factory ChurchBranding.fromMap(Map<String, dynamic> map) {
    final settings =
        (map['church_payment_settings'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PaymentChannel.fromMap)
            .toList();
    final rawSubscription = map['church_subscriptions'];
    final subscription = switch (rawSubscription) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => const <String, dynamic>{},
    };

    final name = (map['name'] as String?) ?? 'Igreja';
    final appName = (map['app_name'] as String?)?.trim();

    return ChurchBranding(
      id: map['id'] as String,
      name: name,
      slug: map['slug'] as String,
      appName: appName == null || appName.isEmpty ? '$name App' : appName,
      joinCode: map['join_code'] as String?,
      logoUrl: map['logo_url'] as String?,
      primaryColor: map['primary_color'] as String?,
      secondaryColor: map['secondary_color'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      city: map['city'] as String?,
      country: map['country'] as String?,
      tagline: map['tagline'] as String?,
      heroTitle: map['hero_title'] as String?,
      heroSubtitle: map['hero_subtitle'] as String?,
      defaultCurrency: (map['default_currency'] as String?) ?? 'MZN',
      paymentChannels: settings,
      subscriptionPlanCode: subscription['plan_code'] as String?,
      subscriptionStatus: (map['subscription_status'] as String?) ??
          subscription['status'] as String?,
      trialEndsAt: DateTime.tryParse(
        ((map['trial_ends_at'] as String?) ??
                subscription['trial_ends_at'] as String?) ??
            '',
      ),
      subscriptionEndsAt: DateTime.tryParse(
        (map['subscription_ends_at'] as String?) ?? '',
      ),
      currentPeriodEndsAt: DateTime.tryParse(
        ((map['subscription_ends_at'] as String?) ??
                subscription['current_period_ends_at'] as String?) ??
            '',
      ),
      gracePeriodEndsAt: DateTime.tryParse(
        (subscription['grace_period_ends_at'] as String?) ?? '',
      ),
      activeMemberCount: _parseInt(
        map['active_member_count'] ?? map['member_count'],
      ),
    );
  }

  ChurchBranding copyWith({int? activeMemberCount}) {
    return ChurchBranding(
      id: id,
      name: name,
      slug: slug,
      appName: appName,
      joinCode: joinCode,
      logoUrl: logoUrl,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      phone: phone,
      email: email,
      city: city,
      country: country,
      tagline: tagline,
      heroTitle: heroTitle,
      heroSubtitle: heroSubtitle,
      defaultCurrency: defaultCurrency,
      paymentChannels: paymentChannels,
      subscriptionPlanCode: subscriptionPlanCode,
      subscriptionStatus: subscriptionStatus,
      trialEndsAt: trialEndsAt,
      subscriptionEndsAt: subscriptionEndsAt,
      currentPeriodEndsAt: currentPeriodEndsAt,
      gracePeriodEndsAt: gracePeriodEndsAt,
      activeMemberCount: activeMemberCount ?? this.activeMemberCount,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  factory ChurchBranding.demo() {
    return const ChurchBranding(
      id: 'demo-church',
      name: 'Igreja Vida Nova',
      slug: 'vida-nova',
      appName: 'Igreja Vida Nova',
      joinCode: 'VIDA123',
      logoUrl: 'assets/branding/comunhao.png',
      primaryColor: '#8B5CF6',
      secondaryColor: '#C084FC',
      phone: '+258877688695',
      email: 'vida.nova@comunhao.app',
      city: 'Maputo',
      country: 'Mozambique',
      tagline: 'Uma familia em Cristo no coracao de Maputo',
      heroTitle: 'Bem-vindo a Igreja Vida Nova.',
      heroSubtitle:
          'Cultos, eventos, mensagens, contribuicoes e acompanhamento pastoral em um unico lugar.',
      subscriptionPlanCode: 'premium',
      subscriptionStatus: 'active',
      activeMemberCount: 128,
      paymentChannels: [
        PaymentChannel(
          provider: 'mpesa',
          accountName: 'Igreja Vida Nova - Sara',
          accountNumber: '+258877688695',
          instructions:
              'Envia por M-Pesa para Sara e confirma o codigo da transacao no checkout.',
          isPrimary: true,
        ),
        PaymentChannel(
          provider: 'emola',
          accountName: 'Igreja Vida Nova - Sara',
          accountNumber: '+258877688695',
          instructions:
              'Envia por E-Mola para Sara e confirma o codigo da transacao no checkout.',
          isPrimary: false,
        ),
      ],
    );
  }
}

String subscriptionStatusLabelFromCode(String status) {
  return subscriptionStatusLabel(status);
}
