String resolveEffectiveSubscriptionStatus({
  required String? status,
  required String? planCode,
  DateTime? trialEndsAt,
  DateTime? currentPeriodEndsAt,
  DateTime? gracePeriodEndsAt,
  DateTime? now,
  int graceDays = 0,
}) {
  final effectiveNow = now ?? DateTime.now();
  final normalizedStatus = (status ?? '').trim();

  if (normalizedStatus.isEmpty) {
    return 'active';
  }

  if (normalizedStatus == 'cancelled' || normalizedStatus == 'suspended') {
    return normalizedStatus;
  }

  if (normalizedStatus == 'overdue') {
    return 'suspended';
  }

  if (normalizedStatus == 'trial') {
    if (trialEndsAt == null || !trialEndsAt.isBefore(effectiveNow)) {
      return 'trial';
    }

    final graceEnd = resolveGracePeriodEndsAt(
      status: normalizedStatus,
      planCode: planCode,
      trialEndsAt: trialEndsAt,
      currentPeriodEndsAt: currentPeriodEndsAt,
      gracePeriodEndsAt: gracePeriodEndsAt,
      graceDays: graceDays,
    );

    if (graceEnd == null || !graceEnd.isBefore(effectiveNow)) {
      return 'grace_period';
    }

    return 'suspended';
  }

  if (normalizedStatus == 'grace_period') {
    final graceEnd = resolveGracePeriodEndsAt(
      status: normalizedStatus,
      planCode: planCode,
      trialEndsAt: trialEndsAt,
      currentPeriodEndsAt: currentPeriodEndsAt,
      gracePeriodEndsAt: gracePeriodEndsAt,
      graceDays: graceDays,
    );

    if (graceEnd == null || !graceEnd.isBefore(effectiveNow)) {
      return 'grace_period';
    }

    return 'suspended';
  }

  if (normalizedStatus == 'active') {
    if (currentPeriodEndsAt == null ||
        !currentPeriodEndsAt.isBefore(effectiveNow)) {
      return 'active';
    }

    final graceEnd = resolveGracePeriodEndsAt(
      status: normalizedStatus,
      planCode: planCode,
      trialEndsAt: trialEndsAt,
      currentPeriodEndsAt: currentPeriodEndsAt,
      gracePeriodEndsAt: gracePeriodEndsAt,
      graceDays: graceDays,
    );

    if (graceEnd == null || !graceEnd.isBefore(effectiveNow)) {
      return 'grace_period';
    }

    return 'suspended';
  }

  return normalizedStatus;
}

DateTime? resolveGracePeriodEndsAt({
  required String? status,
  required String? planCode,
  DateTime? trialEndsAt,
  DateTime? currentPeriodEndsAt,
  DateTime? gracePeriodEndsAt,
  int graceDays = 0,
}) {
  if (gracePeriodEndsAt != null) {
    return gracePeriodEndsAt;
  }

  final normalizedStatus = (status ?? '').trim();
  final baseDate = switch (normalizedStatus) {
    'trial' => trialEndsAt,
    'grace_period' => currentPeriodEndsAt ?? trialEndsAt,
    'active' => currentPeriodEndsAt,
    _ => currentPeriodEndsAt ?? trialEndsAt,
  };

  if (baseDate == null) {
    return null;
  }

  return baseDate.add(Duration(days: graceDays));
}

DateTime? resolveSubscriptionDeadline({
  required String? status,
  required String? planCode,
  DateTime? trialEndsAt,
  DateTime? currentPeriodEndsAt,
  DateTime? gracePeriodEndsAt,
  DateTime? now,
  int graceDays = 0,
}) {
  final effectiveStatus = resolveEffectiveSubscriptionStatus(
    status: status,
    planCode: planCode,
    trialEndsAt: trialEndsAt,
    currentPeriodEndsAt: currentPeriodEndsAt,
    gracePeriodEndsAt: gracePeriodEndsAt,
    now: now,
    graceDays: graceDays,
  );

  return switch (effectiveStatus) {
    'trial' => trialEndsAt,
    'active' => currentPeriodEndsAt,
    'grace_period' => resolveGracePeriodEndsAt(
        status: status,
        planCode: planCode,
        trialEndsAt: trialEndsAt,
        currentPeriodEndsAt: currentPeriodEndsAt,
        gracePeriodEndsAt: gracePeriodEndsAt,
        graceDays: graceDays,
      ),
    _ => resolveGracePeriodEndsAt(
        status: status,
        planCode: planCode,
        trialEndsAt: trialEndsAt,
        currentPeriodEndsAt: currentPeriodEndsAt,
        gracePeriodEndsAt: gracePeriodEndsAt,
        graceDays: graceDays,
      ),
  };
}

String subscriptionStatusLabel(String status) {
  return switch (status) {
    'trial' => 'Experimental',
    'active' => 'Ativa',
    'overdue' => 'Vencida',
    'grace_period' => 'Periodo de tolerancia',
    'suspended' => 'Suspensa',
    'cancelled' => 'Cancelada',
    _ => status,
  };
}
