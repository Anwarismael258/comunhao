class ChurchBirthday {
  const ChurchBirthday({
    required this.profileId,
    required this.fullName,
    required this.role,
    required this.birthDate,
    required this.nextBirthday,
  });

  final String profileId;
  final String fullName;
  final String role;
  final DateTime birthDate;
  final DateTime nextBirthday;

  String get roleLabel => switch (role) {
        'church_admin' => 'Administrador',
        'pastor' => 'Pastor',
        'leader' => 'Lider',
        _ => 'Membro',
      };

  factory ChurchBirthday.fromMap(Map<String, dynamic> map) {
    return ChurchBirthday(
      profileId: (map['profile_id'] as String?) ?? '',
      fullName: (map['full_name'] as String?) ?? 'Membro',
      role: (map['role'] as String?) ?? 'member',
      birthDate: DateTime.tryParse((map['birth_date'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      nextBirthday:
          DateTime.tryParse((map['next_birthday'] as String?) ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
