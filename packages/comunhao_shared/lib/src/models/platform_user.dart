class PlatformUser {
  const PlatformUser({
    required this.id,
    required this.fullName,
    this.phone,
    this.birthDate,
    required this.createdAt,
    required this.platformRoles,
    required this.churchMemberships,
  });

  final String id;
  final String fullName;
  final String? phone;
  final DateTime? birthDate;
  final DateTime createdAt;
  final List<PlatformRoleAssignment> platformRoles;
  final List<PlatformChurchMembership> churchMemberships;

  List<PlatformRoleAssignment> get activePlatformRoles => platformRoles
      .where((role) => role.status == 'active')
      .toList(growable: false);

  List<PlatformChurchMembership> get activeChurchMemberships =>
      churchMemberships
          .where((membership) => membership.status == 'active')
          .toList(growable: false);

  String get rolesLabel {
    final roles = activePlatformRoles.map((role) => role.label).toList();
    if (roles.isEmpty) {
      return 'Sem papel da plataforma';
    }
    return roles.join(', ');
  }

  String get churchSummary {
    final memberships = activeChurchMemberships;
    if (memberships.isEmpty) {
      return 'Sem igreja ativa';
    }
    return memberships
        .map((membership) =>
            '${membership.roleLabel} - ${membership.churchName}')
        .join(', ');
  }

  factory PlatformUser.fromMap(Map<String, dynamic> map) {
    final rawRoles = map['platform_roles'];
    final rawMemberships = map['memberships'];

    final roles = switch (rawRoles) {
      List<dynamic> value => value
          .whereType<Map<String, dynamic>>()
          .map(PlatformRoleAssignment.fromMap)
          .toList(),
      Map<String, dynamic> value => [PlatformRoleAssignment.fromMap(value)],
      _ => const <PlatformRoleAssignment>[],
    };

    final memberships = switch (rawMemberships) {
      List<dynamic> value => value
          .whereType<Map<String, dynamic>>()
          .map(PlatformChurchMembership.fromMap)
          .toList(),
      Map<String, dynamic> value => [PlatformChurchMembership.fromMap(value)],
      _ => const <PlatformChurchMembership>[],
    };

    return PlatformUser(
      id: (map['id'] as String?) ?? '',
      fullName: ((map['full_name'] as String?) ?? 'Utilizador').trim(),
      phone: map['phone'] as String?,
      birthDate: DateTime.tryParse((map['birth_date'] as String?) ?? ''),
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      platformRoles: roles,
      churchMemberships: memberships,
    );
  }
}

class PlatformRoleAssignment {
  const PlatformRoleAssignment({
    required this.id,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String role;
  final String status;
  final DateTime createdAt;

  String get label => switch (role) {
        'super_admin' => 'Super Admin',
        'finance' => 'Financeiro',
        'support' => 'Suporte',
        'support_agent' => 'Suporte',
        'marketing' => 'Marketing',
        'developer' => 'Developer',
        'auditor' => 'Auditor',
        _ => role,
      };

  factory PlatformRoleAssignment.fromMap(Map<String, dynamic> map) {
    return PlatformRoleAssignment(
      id: (map['id'] as String?) ?? '',
      role: (map['role'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'active',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class PlatformChurchMembership {
  const PlatformChurchMembership({
    required this.role,
    required this.status,
    required this.churchName,
    this.churchSlug,
  });

  final String role;
  final String status;
  final String churchName;
  final String? churchSlug;

  String get roleLabel => switch (role) {
        'church_admin' => 'Administrador da Igreja',
        'pastor' => 'Pastor',
        'leader' => 'Lider',
        _ => 'Membro',
      };

  factory PlatformChurchMembership.fromMap(Map<String, dynamic> map) {
    final rawChurch = map['church'];
    final church = switch (rawChurch) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => const <String, dynamic>{},
    };

    return PlatformChurchMembership(
      role: (map['role'] as String?) ?? 'member',
      status: (map['status'] as String?) ?? 'active',
      churchName: (church['name'] as String?) ?? 'Igreja',
      churchSlug: church['slug'] as String?,
    );
  }
}
