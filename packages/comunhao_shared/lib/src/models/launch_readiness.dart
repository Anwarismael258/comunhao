class LaunchReadinessSnapshot {
  const LaunchReadinessSnapshot({
    required this.classification,
    required this.blockers,
    required this.criticalOpen,
    required this.checklist,
    required this.integrations,
    required this.storage,
    required this.vidaNova,
    required this.demoSummary,
  });

  final String classification;
  final int blockers;
  final int criticalOpen;
  final List<LaunchChecklistItem> checklist;
  final List<ProductionIntegrationStatus> integrations;
  final List<LaunchStorageBucket> storage;
  final Map<String, dynamic> vidaNova;
  final Map<String, dynamic> demoSummary;

  String get classificationLabel => switch (classification) {
        'ready_for_production' => 'Pronto para producao',
        'ready_for_pilot' => 'Pronto para piloto',
        'ready_for_staging' => 'Pronto para staging',
        _ => 'Nao pronto',
      };

  factory LaunchReadinessSnapshot.fromMap(Map<String, dynamic> map) {
    return LaunchReadinessSnapshot(
      classification: (map['classification'] as String?) ?? 'not_ready',
      blockers: (map['blockers'] as num?)?.toInt() ?? 0,
      criticalOpen: (map['critical_open'] as num?)?.toInt() ?? 0,
      checklist:
          _list(map['checklist']).map(LaunchChecklistItem.fromMap).toList(),
      integrations: _list(map['integrations'])
          .map(ProductionIntegrationStatus.fromMap)
          .toList(),
      storage: _list(map['storage']).map(LaunchStorageBucket.fromMap).toList(),
      vidaNova: _map(map['vida_nova']),
      demoSummary: _map(map['demo_summary']),
    );
  }
}

class LaunchChecklistItem {
  const LaunchChecklistItem({
    required this.itemKey,
    required this.title,
    required this.category,
    required this.status,
    this.responsible,
    this.notes,
    required this.isCritical,
  });

  final String itemKey;
  final String title;
  final String category;
  final String status;
  final String? responsible;
  final String? notes;
  final bool isCritical;

  String get statusLabel => switch (status) {
        'done' => 'Concluido',
        'blocked' => 'Bloqueado',
        'in_progress' => 'Em progresso',
        _ => 'Nao iniciado',
      };

  factory LaunchChecklistItem.fromMap(Map<String, dynamic> map) {
    return LaunchChecklistItem(
      itemKey: (map['item_key'] as String?) ?? '',
      title: (map['title'] as String?) ?? 'Item',
      category: (map['category'] as String?) ?? 'Geral',
      status: (map['status'] as String?) ?? 'not_started',
      responsible: map['responsible'] as String?,
      notes: map['notes'] as String?,
      isCritical: (map['is_critical'] as bool?) ?? true,
    );
  }
}

class ProductionIntegrationStatus {
  const ProductionIntegrationStatus({
    required this.integrationKey,
    required this.title,
    required this.category,
    required this.status,
    required this.environment,
    this.provider,
    this.notes,
  });

  final String integrationKey;
  final String title;
  final String category;
  final String status;
  final String environment;
  final String? provider;
  final String? notes;

  String get statusLabel => switch (status) {
        'configured' => 'Configurado',
        'sandbox' => 'Sandbox',
        'pending_credentials' => 'Aguarda credenciais',
        'blocked' => 'Bloqueado',
        _ => 'Nao configurado',
      };

  factory ProductionIntegrationStatus.fromMap(Map<String, dynamic> map) {
    return ProductionIntegrationStatus(
      integrationKey: (map['integration_key'] as String?) ?? '',
      title: (map['title'] as String?) ?? 'Integracao',
      category: (map['category'] as String?) ?? 'Geral',
      status: (map['status'] as String?) ?? 'not_configured',
      environment: (map['environment'] as String?) ?? 'production',
      provider: map['provider'] as String?,
      notes: map['notes'] as String?,
    );
  }
}

class LaunchStorageBucket {
  const LaunchStorageBucket({
    required this.id,
    required this.public,
    this.fileSizeLimit,
    required this.allowedMimeTypes,
  });

  final String id;
  final bool public;
  final int? fileSizeLimit;
  final List<String> allowedMimeTypes;

  factory LaunchStorageBucket.fromMap(Map<String, dynamic> map) {
    final rawTypes = map['allowed_mime_types'];
    return LaunchStorageBucket(
      id: (map['id'] as String?) ?? '',
      public: (map['public'] as bool?) ?? false,
      fileSizeLimit: (map['file_size_limit'] as num?)?.toInt(),
      allowedMimeTypes: rawTypes is List
          ? rawTypes.map((item) => '$item').toList(growable: false)
          : const [],
    );
  }
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  return const [];
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const {};
}
