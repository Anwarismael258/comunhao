class ChurchVisitor {
  const ChurchVisitor({
    required this.id,
    required this.churchId,
    required this.fullName,
    this.phone,
    required this.status,
    required this.firstVisitAt,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String churchId;
  final String fullName;
  final String? phone;
  final String status;
  final DateTime firstVisitAt;
  final String? notes;
  final DateTime createdAt;

  String get statusLabel => switch (status) {
        'returning' => 'Recorrente',
        'integrated' => 'Integrado',
        _ => 'Novo visitante',
      };

  factory ChurchVisitor.fromMap(Map<String, dynamic> map) {
    return ChurchVisitor(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      fullName: (map['full_name'] as String?) ?? 'Visitante',
      phone: map['phone'] as String?,
      status: (map['status'] as String?) ?? 'new',
      firstVisitAt:
          DateTime.tryParse((map['first_visit_at'] as String?) ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      notes: map['notes'] as String?,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
