class OrganizationDashboard {
  const OrganizationDashboard({
    required this.organizationId,
    required this.metrics,
    required this.units,
    required this.goals,
    required this.alerts,
    required this.reports,
  });

  final String organizationId;
  final Map<String, num> metrics;
  final List<ChurchBranchUnit> units;
  final List<ExecutiveGoal> goals;
  final List<ExecutiveAlert> alerts;
  final List<ExecutiveReport> reports;

  factory OrganizationDashboard.fromMap(Map<String, dynamic> map) {
    final rawMetrics = switch (map['metrics']) {
      Map<String, dynamic> value => value,
      Map value => Map<String, dynamic>.from(value),
      _ => const <String, dynamic>{},
    };

    return OrganizationDashboard(
      organizationId: (map['organization_id'] as String?) ?? '',
      metrics: rawMetrics.map(
        (key, value) => MapEntry(key, value is num ? value : 0),
      ),
      units: _list(map['units']).map(ChurchBranchUnit.fromMap).toList(),
      goals: _list(map['goals']).map(ExecutiveGoal.fromMap).toList(),
      alerts: _list(map['alerts']).map(ExecutiveAlert.fromMap).toList(),
      reports: _list(map['reports']).map(ExecutiveReport.fromMap).toList(),
    );
  }

  num metric(String key) => metrics[key] ?? 0;
}

class ChurchBranchUnit {
  const ChurchBranchUnit({
    required this.id,
    required this.name,
    required this.slug,
    required this.unitType,
    this.unitCode,
    this.parentChurchId,
    this.city,
    this.province,
    required this.unitStatus,
    required this.active,
    required this.isDemo,
    required this.memberCount,
    this.pastorName,
  });

  final String id;
  final String name;
  final String slug;
  final String unitType;
  final String? unitCode;
  final String? parentChurchId;
  final String? city;
  final String? province;
  final String unitStatus;
  final bool active;
  final bool isDemo;
  final int memberCount;
  final String? pastorName;

  String get typeLabel => switch (unitType) {
        'headquarters' => 'Sede',
        'congregation' => 'Congregacao',
        'branch' => 'Filial',
        'preaching_point' => 'Ponto de pregacao',
        'mission' => 'Missao',
        _ => unitType,
      };

  factory ChurchBranchUnit.fromMap(Map<String, dynamic> map) {
    return ChurchBranchUnit(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Congregacao',
      slug: (map['slug'] as String?) ?? '',
      unitType: (map['unit_type'] as String?) ?? 'congregation',
      unitCode: map['unit_code'] as String?,
      parentChurchId: map['parent_church_id'] as String?,
      city: map['city'] as String?,
      province: map['province'] as String?,
      unitStatus: (map['unit_status'] as String?) ?? 'active',
      active: (map['active'] as bool?) ?? true,
      isDemo: (map['is_demo'] as bool?) ?? false,
      memberCount: (map['member_count'] as num?)?.toInt() ?? 0,
      pastorName: map['pastor_name'] as String?,
    );
  }
}

class ExecutiveGoal {
  const ExecutiveGoal({
    required this.id,
    required this.name,
    required this.goalType,
    required this.currentValue,
    required this.targetValue,
    required this.unit,
    required this.status,
    required this.isDemo,
  });

  final String id;
  final String name;
  final String goalType;
  final num currentValue;
  final num targetValue;
  final String unit;
  final String status;
  final bool isDemo;

  double get progress {
    if (targetValue <= 0) {
      return 0;
    }
    return (currentValue / targetValue).clamp(0, 1).toDouble();
  }

  factory ExecutiveGoal.fromMap(Map<String, dynamic> map) {
    return ExecutiveGoal(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Meta',
      goalType: (map['goal_type'] as String?) ?? 'manual',
      currentValue: (map['current_value'] as num?) ?? 0,
      targetValue: (map['target_value'] as num?) ?? 0,
      unit: (map['unit'] as String?) ?? 'count',
      status: (map['status'] as String?) ?? 'planned',
      isDemo: (map['is_demo'] as bool?) ?? false,
    );
  }
}

class ExecutiveAlert {
  const ExecutiveAlert({
    required this.id,
    required this.severity,
    required this.alertType,
    required this.title,
    required this.description,
    required this.status,
    required this.isDemo,
  });

  final String id;
  final String severity;
  final String alertType;
  final String title;
  final String description;
  final String status;
  final bool isDemo;

  factory ExecutiveAlert.fromMap(Map<String, dynamic> map) {
    return ExecutiveAlert(
      id: (map['id'] as String?) ?? '',
      severity: (map['severity'] as String?) ?? 'medium',
      alertType: (map['alert_type'] as String?) ?? 'general',
      title: (map['title'] as String?) ?? 'Alerta',
      description: (map['description'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'open',
      isDemo: (map['is_demo'] as bool?) ?? false,
    );
  }
}

class ExecutiveReport {
  const ExecutiveReport({
    required this.id,
    required this.reportType,
    required this.title,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    required this.sensitive,
    required this.isDemo,
  });

  final String id;
  final String reportType;
  final String title;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String status;
  final bool sensitive;
  final bool isDemo;

  factory ExecutiveReport.fromMap(Map<String, dynamic> map) {
    return ExecutiveReport(
      id: (map['id'] as String?) ?? '',
      reportType: (map['report_type'] as String?) ?? 'monthly_summary',
      title: (map['title'] as String?) ?? 'Relatorio',
      periodStart: DateTime.tryParse((map['period_start'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      periodEnd: DateTime.tryParse((map['period_end'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: (map['status'] as String?) ?? 'ready',
      sensitive: (map['sensitive'] as bool?) ?? false,
      isDemo: (map['is_demo'] as bool?) ?? false,
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
