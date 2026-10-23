class OperationalMetrics {
  const OperationalMetrics({
    required this.ministriesActive,
    required this.groupsActive,
    required this.tasksPending,
    required this.tasksOverdue,
    required this.rostersPending,
    required this.assetsMaintenance,
    required this.maintenancePending,
    required this.documentsExpiring,
    required this.reservationsPending,
    required this.purchasesPending,
    required this.stockLow,
  });

  final int ministriesActive;
  final int groupsActive;
  final int tasksPending;
  final int tasksOverdue;
  final int rostersPending;
  final int assetsMaintenance;
  final int maintenancePending;
  final int documentsExpiring;
  final int reservationsPending;
  final int purchasesPending;
  final int stockLow;

  factory OperationalMetrics.fromMap(Map<String, dynamic> map) {
    int value(String key) => (map[key] as num?)?.toInt() ?? 0;
    return OperationalMetrics(
      ministriesActive: value('ministries_active'),
      groupsActive: value('groups_active'),
      tasksPending: value('tasks_pending'),
      tasksOverdue: value('tasks_overdue'),
      rostersPending: value('rosters_pending'),
      assetsMaintenance: value('assets_maintenance'),
      maintenancePending: value('maintenance_pending'),
      documentsExpiring: value('documents_expiring'),
      reservationsPending: value('reservations_pending'),
      purchasesPending: value('purchases_pending'),
      stockLow: value('stock_low'),
    );
  }
}

class PlatformOperationalMetrics {
  const PlatformOperationalMetrics({
    required this.ministries,
    required this.groups,
    required this.tasksOpen,
    required this.tasksOverdue,
    required this.rostersPending,
    required this.assets,
    required this.assetsMaintenance,
    required this.purchaseRequestsPending,
    required this.volunteerOpportunitiesOpen,
    required this.joinRequestsPending,
  });

  final int ministries;
  final int groups;
  final int tasksOpen;
  final int tasksOverdue;
  final int rostersPending;
  final int assets;
  final int assetsMaintenance;
  final int purchaseRequestsPending;
  final int volunteerOpportunitiesOpen;
  final int joinRequestsPending;

  factory PlatformOperationalMetrics.fromMap(Map<String, dynamic> map) {
    int value(String key) => (map[key] as num?)?.toInt() ?? 0;
    return PlatformOperationalMetrics(
      ministries: value('ministries'),
      groups: value('groups'),
      tasksOpen: value('tasks_open'),
      tasksOverdue: value('tasks_overdue'),
      rostersPending: value('rosters_pending'),
      assets: value('assets'),
      assetsMaintenance: value('assets_maintenance'),
      purchaseRequestsPending: value('purchase_requests_pending'),
      volunteerOpportunitiesOpen: value('volunteer_opportunities_open'),
      joinRequestsPending: value('join_requests_pending'),
    );
  }
}

class ChurchGroup {
  const ChurchGroup({
    required this.id,
    required this.churchId,
    required this.name,
    required this.groupType,
    this.description,
    this.location,
    this.usualDay,
    this.usualTime,
    this.status = 'active',
    required this.createdAt,
  });

  final String id;
  final String churchId;
  final String name;
  final String groupType;
  final String? description;
  final String? location;
  final String? usualDay;
  final String? usualTime;
  final String status;
  final DateTime createdAt;

  String get groupTypeLabel => switch (groupType) {
        'cell' => 'Celula',
        'prayer_group' => 'Grupo de oracao',
        'youth_group' => 'Grupo de jovens',
        'class' => 'Turma',
        'choir' => 'Coral',
        'band' => 'Banda',
        'team' => 'Equipa',
        _ => 'Grupo',
      };

  factory ChurchGroup.fromMap(Map<String, dynamic> map) {
    return ChurchGroup(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Grupo',
      groupType: (map['group_type'] as String?) ?? 'cell',
      description: map['description'] as String?,
      location: map['location'] as String?,
      usualDay: map['usual_day'] as String?,
      usualTime: map['usual_time'] as String?,
      status: (map['status'] as String?) ?? 'active',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class OperationalTask {
  const OperationalTask({
    required this.id,
    required this.churchId,
    required this.title,
    this.description,
    this.priority = 'normal',
    this.status = 'todo',
    this.dueAt,
    this.progressPercent = 0,
  });

  final String id;
  final String churchId;
  final String title;
  final String? description;
  final String priority;
  final String status;
  final DateTime? dueAt;
  final int progressPercent;

  String get statusLabel => switch (status) {
        'in_progress' => 'Em andamento',
        'blocked' => 'Bloqueada',
        'review' => 'Em revisao',
        'done' => 'Concluida',
        'cancelled' => 'Cancelada',
        _ => 'Por fazer',
      };

  factory OperationalTask.fromMap(Map<String, dynamic> map) {
    return OperationalTask(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      title: (map['title'] as String?) ?? 'Tarefa',
      description: map['description'] as String?,
      priority: (map['priority'] as String?) ?? 'normal',
      status: (map['status'] as String?) ?? 'todo',
      dueAt: DateTime.tryParse((map['due_at'] as String?) ?? ''),
      progressPercent: (map['progress_percent'] as num?)?.toInt() ?? 0,
    );
  }
}

class ServiceRoster {
  const ServiceRoster({
    required this.id,
    required this.churchId,
    required this.roleTitle,
    required this.startsAt,
    this.location,
    this.status = 'pending_confirmation',
    this.assignedName,
  });

  final String id;
  final String churchId;
  final String roleTitle;
  final DateTime startsAt;
  final String? location;
  final String status;
  final String? assignedName;

  String get statusLabel => switch (status) {
        'confirmed' => 'Confirmada',
        'declined' => 'Recusada',
        'completed' => 'Concluida',
        'cancelled' => 'Cancelada',
        _ => 'A confirmar',
      };

  factory ServiceRoster.fromMap(Map<String, dynamic> map) {
    final membership = switch (map['assigned']) {
      Map<String, dynamic> value => value,
      _ => const <String, dynamic>{},
    };
    final profile = switch (membership['profile']) {
      Map<String, dynamic> value => value,
      _ => const <String, dynamic>{},
    };
    return ServiceRoster(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      roleTitle: (map['role_title'] as String?) ?? 'Escala',
      startsAt: DateTime.tryParse((map['starts_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      location: map['location'] as String?,
      status: (map['status'] as String?) ?? 'pending_confirmation',
      assignedName: profile['full_name'] as String?,
    );
  }
}

class MinistryJoinRequest {
  const MinistryJoinRequest({
    required this.id,
    required this.churchId,
    this.ministryName,
    this.groupName,
    this.interest,
    this.experience,
    this.status = 'pending',
    required this.createdAt,
  });

  final String id;
  final String churchId;
  final String? ministryName;
  final String? groupName;
  final String? interest;
  final String? experience;
  final String status;
  final DateTime createdAt;

  String get statusLabel => switch (status) {
        'approved' => 'Aprovada',
        'rejected' => 'Rejeitada',
        'reviewing' => 'Em analise',
        'interview_required' => 'Entrevista necessaria',
        _ => 'Pendente',
      };

  factory MinistryJoinRequest.fromMap(Map<String, dynamic> map) {
    final ministry = switch (map['ministry']) {
      Map<String, dynamic> value => value,
      _ => const <String, dynamic>{},
    };
    final group = switch (map['group']) {
      Map<String, dynamic> value => value,
      _ => const <String, dynamic>{},
    };
    return MinistryJoinRequest(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      ministryName: ministry['name'] as String?,
      groupName: group['name'] as String?,
      interest: map['interest'] as String?,
      experience: map['experience'] as String?,
      status: (map['status'] as String?) ?? 'pending',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class VolunteerOpportunity {
  const VolunteerOpportunity({
    required this.id,
    required this.churchId,
    required this.title,
    this.description,
    this.ministryName,
    this.startsAt,
    this.location,
    this.slots,
    this.requirements,
    this.status = 'open',
  });

  final String id;
  final String churchId;
  final String title;
  final String? description;
  final String? ministryName;
  final DateTime? startsAt;
  final String? location;
  final int? slots;
  final String? requirements;
  final String status;

  factory VolunteerOpportunity.fromMap(Map<String, dynamic> map) {
    final ministry = switch (map['ministry']) {
      Map<String, dynamic> value => value,
      _ => const <String, dynamic>{},
    };
    return VolunteerOpportunity(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      title: (map['title'] as String?) ?? 'Oportunidade',
      description: map['description'] as String?,
      ministryName: ministry['name'] as String?,
      startsAt: DateTime.tryParse((map['starts_at'] as String?) ?? ''),
      location: map['location'] as String?,
      slots: (map['slots'] as num?)?.toInt(),
      requirements: map['requirements'] as String?,
      status: (map['status'] as String?) ?? 'open',
    );
  }
}

class VolunteerApplication {
  const VolunteerApplication({
    required this.id,
    required this.opportunityId,
    this.opportunityTitle,
    this.status = 'pending',
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String opportunityId;
  final String? opportunityTitle;
  final String status;
  final String? notes;
  final DateTime createdAt;

  String get statusLabel => switch (status) {
        'approved' => 'Aprovada',
        'rejected' => 'Rejeitada',
        'checked_in' => 'Presente',
        _ => 'Pendente',
      };

  factory VolunteerApplication.fromMap(Map<String, dynamic> map) {
    final opportunity = switch (map['opportunity']) {
      Map<String, dynamic> value => value,
      _ => const <String, dynamic>{},
    };
    return VolunteerApplication(
      id: (map['id'] as String?) ?? '',
      opportunityId: (map['opportunity_id'] as String?) ?? '',
      opportunityTitle: opportunity['title'] as String?,
      status: (map['status'] as String?) ?? 'pending',
      notes: map['notes'] as String?,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class MaintenanceRequest {
  const MaintenanceRequest({
    required this.id,
    required this.churchId,
    required this.problem,
    this.priority = 'normal',
    this.status = 'requested',
    this.expectedAt,
  });

  final String id;
  final String churchId;
  final String problem;
  final String priority;
  final String status;
  final DateTime? expectedAt;

  factory MaintenanceRequest.fromMap(Map<String, dynamic> map) {
    return MaintenanceRequest(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      problem: (map['problem'] as String?) ?? 'Manutencao',
      priority: (map['priority'] as String?) ?? 'normal',
      status: (map['status'] as String?) ?? 'requested',
      expectedAt: DateTime.tryParse((map['expected_at'] as String?) ?? ''),
    );
  }
}

class ChurchDocument {
  const ChurchDocument({
    required this.id,
    required this.title,
    required this.documentType,
    this.validUntil,
    this.confidentiality = 'internal',
    this.storageBucket,
    this.storagePath,
  });

  final String id;
  final String title;
  final String documentType;
  final DateTime? validUntil;
  final String confidentiality;
  final String? storageBucket;
  final String? storagePath;

  factory ChurchDocument.fromMap(Map<String, dynamic> map) {
    return ChurchDocument(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? 'Documento',
      documentType: (map['document_type'] as String?) ?? 'document',
      validUntil: DateTime.tryParse((map['valid_until'] as String?) ?? ''),
      confidentiality: (map['confidentiality'] as String?) ?? 'internal',
      storageBucket: map['storage_bucket'] as String?,
      storagePath: map['storage_path'] as String?,
    );
  }
}

class PurchaseRequest {
  const PurchaseRequest({
    required this.id,
    required this.itemName,
    required this.quantity,
    this.estimatedAmount,
    this.status = 'submitted',
  });

  final String id;
  final String itemName;
  final int quantity;
  final num? estimatedAmount;
  final String status;

  factory PurchaseRequest.fromMap(Map<String, dynamic> map) {
    return PurchaseRequest(
      id: (map['id'] as String?) ?? '',
      itemName: (map['item_name'] as String?) ?? 'Pedido',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      estimatedAmount: map['estimated_amount'] as num?,
      status: (map['status'] as String?) ?? 'submitted',
    );
  }
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.quantityCurrent,
    required this.quantityMinimum,
  });

  final String id;
  final String name;
  final String unit;
  final num quantityCurrent;
  final num quantityMinimum;

  bool get lowStock => quantityCurrent <= quantityMinimum;

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Item',
      unit: (map['unit'] as String?) ?? 'un',
      quantityCurrent: (map['quantity_current'] as num?) ?? 0,
      quantityMinimum: (map['quantity_minimum'] as num?) ?? 0,
    );
  }
}
