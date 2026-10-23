class ManagedMember {
  const ManagedMember({
    required this.membershipId,
    required this.profileId,
    required this.churchId,
    required this.fullName,
    required this.role,
    required this.status,
    this.phone,
    this.birthDate,
    this.neighborhood,
    this.gender,
    this.entryDate,
    this.approvedAt,
    this.lastActivityAt,
    this.totalContributed = 0,
    this.pendingContributions = 0,
  });

  final String membershipId;
  final String profileId;
  final String churchId;
  final String fullName;
  final String role;
  final String status;
  final String? phone;
  final DateTime? birthDate;
  final String? neighborhood;
  final String? gender;
  final DateTime? entryDate;
  final DateTime? approvedAt;
  final DateTime? lastActivityAt;
  final num totalContributed;
  final num pendingContributions;

  bool get isActive => status == 'active';

  String get roleLabel => switch (role) {
        'church_admin' => 'Administrador da Igreja',
        'pastor' => 'Pastor',
        'leader' => 'Lider',
        _ => 'Membro',
      };

  String get statusLabel => switch (status) {
        'blocked' => 'Bloqueado',
        'removed' => 'Removido',
        'transferred' => 'Transferido',
        _ => 'Ativo',
      };

  factory ManagedMember.fromMap(Map<String, dynamic> map) {
    final rawProfile = map['profile'];
    final profile = switch (rawProfile) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => const <String, dynamic>{},
    };

    final rawName = profile['full_name'] as String?;

    return ManagedMember(
      membershipId: (map['id'] as String?) ?? '',
      profileId:
          (profile['id'] as String?) ?? (map['profile_id'] as String? ?? ''),
      churchId: (map['church_id'] as String?) ?? '',
      fullName:
          rawName == null || rawName.trim().isEmpty ? 'Membro' : rawName.trim(),
      role: (map['role'] as String?) ?? 'member',
      status: (map['status'] as String?) ?? 'active',
      phone: profile['phone'] as String?,
      birthDate: DateTime.tryParse((profile['birth_date'] as String?) ?? ''),
      neighborhood: map['neighborhood'] as String?,
      gender: map['gender'] as String?,
      entryDate: DateTime.tryParse((map['entry_date'] as String?) ?? ''),
      approvedAt: DateTime.tryParse((map['approved_at'] as String?) ?? ''),
      lastActivityAt:
          DateTime.tryParse((map['last_activity_at'] as String?) ?? ''),
      totalContributed: (map['total_contributed'] as num?) ?? 0,
      pendingContributions: (map['pending_contributions'] as num?) ?? 0,
    );
  }
}
