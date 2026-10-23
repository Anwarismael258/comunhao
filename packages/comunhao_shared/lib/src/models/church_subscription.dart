import '../utils/subscription_utils.dart';

class ChurchSubscription {
  const ChurchSubscription({
    required this.churchId,
    required this.planCode,
    required this.status,
    this.trialEndsAt,
    this.currentPeriodEndsAt,
    this.gracePeriodEndsAt,
    this.adminNotes,
  });

  final String churchId;
  final String planCode;
  final String status;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEndsAt;
  final DateTime? gracePeriodEndsAt;
  final String? adminNotes;

  String get effectiveStatus => resolveEffectiveSubscriptionStatus(
        status: status,
        planCode: planCode,
        trialEndsAt: trialEndsAt,
        currentPeriodEndsAt: currentPeriodEndsAt,
        gracePeriodEndsAt: gracePeriodEndsAt,
      );

  DateTime? get effectiveDeadline => resolveSubscriptionDeadline(
        status: status,
        planCode: planCode,
        trialEndsAt: trialEndsAt,
        currentPeriodEndsAt: currentPeriodEndsAt,
        gracePeriodEndsAt: gracePeriodEndsAt,
      );

  bool get allowsMemberAccess =>
      const {'trial', 'active'}.contains(effectiveStatus);

  bool get isReadOnlyForChurchAdmin =>
      const {'overdue', 'suspended', 'cancelled'}.contains(effectiveStatus);

  bool get requiresPaymentForChurchAdmin =>
      const {'overdue', 'grace_period', 'suspended', 'cancelled'}
          .contains(effectiveStatus);

  String get statusLabel => subscriptionStatusLabel(effectiveStatus);

  String get planLabel => switch (planCode) {
        'starter' => 'Starter',
        'essential' => 'Essencial',
        'premium' => 'Plus',
        _ => planCode,
      };

  factory ChurchSubscription.fromMap(Map<String, dynamic> map) {
    return ChurchSubscription(
      churchId: (map['church_id'] as String?) ?? '',
      planCode: (map['plan_code'] as String?) ?? 'starter',
      status: (map['status'] as String?) ?? 'trial',
      trialEndsAt: DateTime.tryParse((map['trial_ends_at'] as String?) ?? ''),
      currentPeriodEndsAt:
          DateTime.tryParse((map['current_period_ends_at'] as String?) ?? ''),
      gracePeriodEndsAt:
          DateTime.tryParse((map['grace_period_ends_at'] as String?) ?? ''),
      adminNotes: map['admin_notes'] as String?,
    );
  }
}
