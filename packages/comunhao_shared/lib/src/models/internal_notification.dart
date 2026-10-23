class InternalNotification {
  const InternalNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    this.churchId,
    this.churchName,
    this.referenceTable,
    this.referenceId,
    this.actionRoute,
    this.deliveryStatus,
    this.readAt,
    this.archivedAt,
    required this.createdAt,
    required this.metadata,
  });

  final String id;
  final String title;
  final String message;
  final String type;
  final String priority;
  final String? churchId;
  final String? churchName;
  final String? referenceTable;
  final String? referenceId;
  final String? actionRoute;
  final String? deliveryStatus;
  final DateTime? readAt;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  bool get isRead => readAt != null;

  String get priorityLabel => switch (priority) {
        'urgent' => 'Urgente',
        'high' => 'Alta',
        'normal' => 'Normal',
        'low' => 'Baixa',
        _ => priority,
      };

  String get typeLabel => switch (type) {
        'join_request' => 'Pedido de membro',
        'donation_pending' => 'Contribuicao',
        'donation_confirmed' => 'Contribuicao confirmada',
        'donation_rejected' => 'Contribuicao rejeitada',
        'contribution_confirmed' => 'Contribuicao confirmada',
        'contribution_rejected' => 'Contribuicao rejeitada',
        'expense_pending_approval' => 'Despesa para aprovar',
        'withdrawal_requested' => 'Levantamento solicitado',
        'withdrawal_paid' => 'Levantamento pago',
        'subscription_payment_confirmed' => 'Plano confirmado',
        'pastoral_request' => 'Pedido pastoral',
        'pastoral_request_assigned' => 'Pedido atribuido',
        'administrative_request' => 'Pedido administrativo',
        'event' => 'Evento',
        'campaign' => 'Campanha',
        'announcement' => 'Mensagem',
        'pastoral_publication' => 'Publicacao',
        'urgent_notice' => 'Aviso urgente',
        'church_application_submitted' => 'Pedido de igreja',
        'church_approved' => 'Igreja aprovada',
        'church_corrections_requested' => 'Correcoes solicitadas',
        'church_rejected' => 'Igreja rejeitada',
        _ => type,
      };

  factory InternalNotification.fromMap(Map<String, dynamic> map) {
    final church = map['churches'];
    final metadata = map['metadata'];

    return InternalNotification(
      id: (map['id'] as String?) ?? '',
      title: ((map['title'] as String?) ?? 'Notificacao').trim(),
      message: ((map['message'] as String?) ?? '').trim(),
      type: (map['notification_type'] as String?) ?? 'general',
      priority: (map['priority'] as String?) ?? 'normal',
      churchId: map['church_id'] as String?,
      churchName:
          church is Map<String, dynamic> ? church['name'] as String? : null,
      referenceTable: map['reference_table'] as String?,
      referenceId: map['reference_id'] as String?,
      actionRoute: map['action_route'] as String?,
      deliveryStatus: map['delivery_status'] as String?,
      readAt: DateTime.tryParse((map['read_at'] as String?) ?? ''),
      archivedAt: DateTime.tryParse((map['archived_at'] as String?) ?? ''),
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      metadata: metadata is Map<String, dynamic>
          ? Map<String, dynamic>.from(metadata)
          : const <String, dynamic>{},
    );
  }
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.profileId,
    required this.allowInApp,
    required this.allowSms,
    required this.allowEmail,
    required this.mutedTypes,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    required this.updatedAt,
  });

  final String profileId;
  final bool allowInApp;
  final bool allowSms;
  final bool allowEmail;
  final List<String> mutedTypes;
  final String? quietHoursStart;
  final String? quietHoursEnd;
  final DateTime updatedAt;

  NotificationPreferences copyWith({
    bool? allowInApp,
    bool? allowSms,
    bool? allowEmail,
    List<String>? mutedTypes,
    String? quietHoursStart,
    String? quietHoursEnd,
  }) {
    return NotificationPreferences(
      profileId: profileId,
      allowInApp: allowInApp ?? this.allowInApp,
      allowSms: allowSms ?? this.allowSms,
      allowEmail: allowEmail ?? this.allowEmail,
      mutedTypes: mutedTypes ?? this.mutedTypes,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'allow_in_app': allowInApp,
      'allow_sms': allowSms,
      'allow_email': allowEmail,
      'muted_types': mutedTypes,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    final mutedTypes = map['muted_types'];
    return NotificationPreferences(
      profileId: (map['profile_id'] as String?) ?? '',
      allowInApp: (map['allow_in_app'] as bool?) ?? true,
      allowSms: (map['allow_sms'] as bool?) ?? true,
      allowEmail: (map['allow_email'] as bool?) ?? false,
      mutedTypes: mutedTypes is List<dynamic>
          ? mutedTypes.whereType<String>().toList(growable: false)
          : const <String>[],
      quietHoursStart: map['quiet_hours_start'] as String?,
      quietHoursEnd: map['quiet_hours_end'] as String?,
      updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
