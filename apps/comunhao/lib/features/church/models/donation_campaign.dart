class DonationCampaign {
  const DonationCampaign({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.pastoralPublicationId,
    this.targetAmount,
    this.startAt,
    this.endAt,
    required this.active,
    this.raisedAmount = 0,
    this.contributorCount = 0,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? pastoralPublicationId;
  final num? targetAmount;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool active;
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

  factory DonationCampaign.fromMap(Map<String, dynamic> map) {
    return DonationCampaign(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      pastoralPublicationId: map['pastoral_publication_id'] as String?,
      targetAmount: map['target_amount'] as num?,
      startAt: map['start_at'] == null
          ? null
          : DateTime.parse(map['start_at'] as String),
      endAt: map['end_at'] == null
          ? null
          : DateTime.parse(map['end_at'] as String),
      active: map['active'] as bool? ?? false,
      raisedAmount: (map['raised_amount'] as num?) ?? 0,
      contributorCount: (map['contributor_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '')
              ?.toLocal() ??
          DateTime.tryParse((map['start_at'] as String?) ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
