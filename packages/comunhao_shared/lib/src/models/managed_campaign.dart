class ManagedCampaign {
  const ManagedCampaign({
    required this.id,
    required this.churchId,
    required this.title,
    this.description,
    this.imageUrl,
    this.pastoralPublicationId,
    this.targetAmount,
    this.startAt,
    this.endAt,
    required this.active,
    required this.status,
    required this.raisedAmount,
    required this.contributorCount,
    required this.createdAt,
  });

  final String id;
  final String churchId;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? pastoralPublicationId;
  final num? targetAmount;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool active;
  final String status;
  final num raisedAmount;
  final int contributorCount;
  final DateTime createdAt;

  double get progress {
    final target = targetAmount ?? 0;
    if (target <= 0) {
      return 0;
    }
    final value = raisedAmount / target;
    return value > 1 ? 1 : value.toDouble();
  }

  int get progressPercent => (progress * 100).round();

  String get statusLabel {
    if (!active) {
      return 'Inativa';
    }
    return switch (status) {
      'active' => 'Ativa',
      'published' => 'Publicada',
      'draft' => 'Rascunho',
      'closed' => 'Encerrada',
      _ => status,
    };
  }

  factory ManagedCampaign.fromMap(Map<String, dynamic> map) {
    return ManagedCampaign(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      title: ((map['title'] as String?) ?? '').trim(),
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      pastoralPublicationId: map['pastoral_publication_id'] as String?,
      targetAmount: map['target_amount'] as num?,
      startAt: DateTime.tryParse((map['start_at'] as String?) ?? ''),
      endAt: DateTime.tryParse((map['end_at'] as String?) ?? ''),
      active: (map['active'] as bool?) ?? false,
      status: (map['campaign_status'] as String?) ?? 'active',
      raisedAmount: (map['raised_amount'] as num?) ?? 0,
      contributorCount: (map['contributor_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
