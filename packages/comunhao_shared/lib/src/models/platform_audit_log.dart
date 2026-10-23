class PlatformAuditLog {
  const PlatformAuditLog({
    required this.id,
    required this.action,
    required this.targetType,
    this.targetId,
    this.churchId,
    this.churchName,
    this.actorProfileId,
    this.actorName,
    this.actorPhone,
    required this.summary,
    required this.details,
    required this.createdAt,
  });

  final String id;
  final String action;
  final String targetType;
  final String? targetId;
  final String? churchId;
  final String? churchName;
  final String? actorProfileId;
  final String? actorName;
  final String? actorPhone;
  final String summary;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  String get actionLabel => switch (action) {
        'platform_role.updated' => 'Papel da plataforma',
        'church_application.reviewed' => 'Pedido de igreja',
        'church.subscription.updated' => 'Subscricao da igreja',
        'church.subscription_request.reviewed' => 'Pedido de plano',
        'church.active_state.updated' => 'Estado operacional',
        'church.owner.transferred' => 'Transferencia de proprietario',
        'church.workspace.reset' => 'Reset da igreja',
        'wallet.platform_revenue.recorded' => 'Receita da plataforma',
        'wallet.withdrawal.updated' => 'Levantamento',
        'wallet.withdrawal.requested' => 'Pedido de levantamento',
        _ => action,
      };

  String get actorLabel {
    final trimmed = actorName?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'Equipa Comunhao';
    }
    return trimmed;
  }

  factory PlatformAuditLog.fromMap(Map<String, dynamic> map) {
    final rawDetails = map['details'];
    final details = switch (rawDetails) {
      Map<String, dynamic> value => value,
      Map value => Map<String, dynamic>.from(value),
      _ => const <String, dynamic>{},
    };

    return PlatformAuditLog(
      id: (map['id'] as String?) ?? '',
      action: (map['action'] as String?) ?? '',
      targetType: (map['target_type'] as String?) ?? '',
      targetId: map['target_id'] as String?,
      churchId: map['church_id'] as String?,
      churchName: map['church_name'] as String?,
      actorProfileId: map['actor_profile_id'] as String?,
      actorName: map['actor_name'] as String?,
      actorPhone: map['actor_phone'] as String?,
      summary: (map['summary'] as String?) ?? 'Evento da plataforma',
      details: details,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
