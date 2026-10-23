class ChurchMember {
  const ChurchMember({
    required this.membershipId,
    required this.id,
    required this.churchId,
    required this.fullName,
    required this.role,
    required this.status,
    this.memberCode,
    this.phone,
    this.birthDate,
    this.baptismDate,
    this.avatarUrl,
    this.avatarStoragePath,
    this.ministryRole,
    this.ministries = const [],
  });

  final String membershipId;
  final String id;
  final String churchId;
  final String fullName;
  final String role;
  final String status;
  final String? memberCode;
  final String? phone;
  final DateTime? birthDate;
  final DateTime? baptismDate;
  final String? avatarUrl;
  final String? avatarStoragePath;
  final String? ministryRole;
  final List<String> ministries;

  String get roleLabel => switch (role) {
        'super_admin' => 'Super Admin',
        'church_admin' => 'Administrador da Igreja',
        'pastor' => 'Pastor',
        'leader' => 'Lider',
        'secretary' => 'Secretario',
        'finance_manager' => 'Responsavel financeiro',
        'communications_manager' => 'Comunicacao',
        'owner' => 'Responsavel principal',
        _ => 'Membro',
      };

  String get statusLabel => switch (status) {
        'blocked' => 'Bloqueado',
        'removed' => 'Removido',
        'transferred' => 'Transferido',
        'pending' => 'Pendente',
        'invited' => 'Convite pendente',
        'suspended' => 'Suspenso',
        _ => 'Ativo',
      };

  bool get canAccessAdmin =>
      status == 'active' &&
      const {'super_admin', 'church_admin', 'pastor', 'leader'}.contains(role);

  String get codeLabel {
    final code = memberCode?.trim();
    if (code != null && code.isNotEmpty) {
      return code.toUpperCase();
    }
    return id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  }

  String? get birthDateLabel {
    final value = birthDate;
    if (value == null) {
      return null;
    }

    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String? get baptismDateLabel {
    final value = baptismDate;
    if (value == null) {
      return null;
    }

    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String get ministriesLabel {
    if (ministries.isEmpty) {
      return 'Sem ministerio';
    }
    return ministries.join(', ');
  }

  String get ministryRoleLabel => switch (ministryRole) {
        'leader' => 'Lider de ministerio',
        'assistant' => 'Assistente de ministerio',
        'member' => 'Membro de ministerio',
        _ => roleLabel,
      };

  factory ChurchMember.fromMap(
    Map<String, dynamic> map, {
    String? fallbackFullName,
  }) {
    final rawProfile = map['profile'];
    final profile = switch (rawProfile) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => const <String, dynamic>{},
    };

    final rawMinistryMemberships = map['ministry_members'];
    final ministryMemberships = switch (rawMinistryMemberships) {
      List<dynamic> value => value.whereType<Map<String, dynamic>>().toList(),
      Map<String, dynamic> value => [value],
      _ => const <Map<String, dynamic>>[],
    };

    final ministries = <String>[];
    String? ministryRole;
    for (final ministryMembership in ministryMemberships) {
      ministryRole ??= ministryMembership['role'] as String?;
      final rawMinistry = ministryMembership['ministry'];
      final ministry = switch (rawMinistry) {
        Map<String, dynamic> value => value,
        List<dynamic> value
            when value.isNotEmpty && value.first is Map<String, dynamic> =>
          value.first as Map<String, dynamic>,
        _ => const <String, dynamic>{},
      };
      final name = (ministry['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) {
        ministries.add(name);
      }
    }

    final rawName = profile['full_name'] as String?;
    final cleanName = rawName == null || rawName.trim().isEmpty
        ? fallbackFullName?.trim()
        : rawName.trim();

    return ChurchMember(
      membershipId: (map['id'] as String?) ?? '',
      id: (profile['id'] as String?) ?? (map['profile_id'] as String? ?? ''),
      churchId: (map['church_id'] as String?) ?? '',
      fullName: cleanName == null || cleanName.isEmpty ? 'Membro' : cleanName,
      role: (map['role'] as String?) ?? 'member',
      status: (map['status'] as String?) ?? 'active',
      memberCode: map['member_code'] as String?,
      phone: profile['phone'] as String?,
      birthDate: DateTime.tryParse((profile['birth_date'] as String?) ?? ''),
      baptismDate: DateTime.tryParse((map['baptism_date'] as String?) ?? ''),
      avatarUrl: profile['avatar_url'] as String?,
      avatarStoragePath: profile['avatar_storage_path'] as String?,
      ministryRole: ministryRole,
      ministries: ministries,
    );
  }

  ChurchMember copyWith({
    String? avatarUrl,
    String? avatarStoragePath,
  }) {
    return ChurchMember(
      membershipId: membershipId,
      id: id,
      churchId: churchId,
      fullName: fullName,
      role: role,
      status: status,
      memberCode: memberCode,
      phone: phone,
      birthDate: birthDate,
      baptismDate: baptismDate,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarStoragePath: avatarStoragePath ?? this.avatarStoragePath,
      ministryRole: ministryRole,
      ministries: ministries,
    );
  }
}
