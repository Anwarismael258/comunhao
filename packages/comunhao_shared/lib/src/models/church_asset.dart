class ChurchAsset {
  const ChurchAsset({
    required this.id,
    required this.churchId,
    required this.category,
    required this.name,
    required this.quantity,
    required this.itemCondition,
    this.location,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String churchId;
  final String category;
  final String name;
  final int quantity;
  final String itemCondition;
  final String? location;
  final String? notes;
  final DateTime createdAt;

  String get categoryLabel => switch (category) {
        'instrumento' => 'Instrumento',
        'computador' => 'Computador',
        'projetor' => 'Projetor',
        'veiculo' => 'Veiculo',
        'cadeira' => 'Cadeira',
        'mesa' => 'Mesa',
        'som' => 'Som',
        'mobilia' => 'Mobilia',
        _ => 'Outro',
      };

  String get conditionLabel => switch (itemCondition) {
        'new' => 'Novo',
        'good' => 'Bom',
        'fair' => 'Regular',
        'needs_repair' => 'Precisa reparacao',
        'retired' => 'Inativo',
        _ => itemCondition,
      };

  factory ChurchAsset.fromMap(Map<String, dynamic> map) {
    return ChurchAsset(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'outro',
      name: (map['name'] as String?) ?? 'Item',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      itemCondition: (map['item_condition'] as String?) ?? 'good',
      location: map['location'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
