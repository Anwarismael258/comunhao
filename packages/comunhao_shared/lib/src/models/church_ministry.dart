class ChurchMinistry {
  const ChurchMinistry({
    required this.id,
    required this.churchId,
    required this.name,
    this.description,
    required this.active,
    this.leaderMembershipId,
    this.leaderName,
    required this.memberMembershipIds,
    required this.createdAt,
  });

  final String id;
  final String churchId;
  final String name;
  final String? description;
  final bool active;
  final String? leaderMembershipId;
  final String? leaderName;
  final List<String> memberMembershipIds;
  final DateTime createdAt;

  int get memberCount => memberMembershipIds.length;

  factory ChurchMinistry.fromMap(Map<String, dynamic> map) {
    final rawLeader = map['leader'];
    final leader = switch (rawLeader) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => const <String, dynamic>{},
    };

    final rawLeaderProfile = leader['profile'];
    final leaderProfile = switch (rawLeaderProfile) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => const <String, dynamic>{},
    };

    final rawMembers = map['ministry_members'];
    final members = switch (rawMembers) {
      List<dynamic> value => value.whereType<Map<String, dynamic>>().toList(),
      Map<String, dynamic> value => [value],
      _ => const <Map<String, dynamic>>[],
    };

    return ChurchMinistry(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Ministerio',
      description: map['description'] as String?,
      active: (map['active'] as bool?) ?? true,
      leaderMembershipId: map['leader_membership_id'] as String?,
      leaderName: leaderProfile['full_name'] as String?,
      memberMembershipIds: members
          .map((member) => member['membership_id'] as String?)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList(growable: false),
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
