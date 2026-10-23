class ChurchExpense {
  const ChurchExpense({
    required this.id,
    required this.churchId,
    required this.category,
    required this.title,
    required this.amount,
    required this.currency,
    required this.spentAt,
    this.notes,
    this.vendorName,
    this.paymentMethod,
    this.paymentReference,
    this.proofUrl,
    this.costCenter,
    this.status = 'paid',
    this.approvedAt,
    this.paidAt,
    this.rejectionReason,
    this.isDemo = false,
    required this.createdAt,
  });

  final String id;
  final String churchId;
  final String category;
  final String title;
  final num amount;
  final String currency;
  final DateTime spentAt;
  final String? notes;
  final String? vendorName;
  final String? paymentMethod;
  final String? paymentReference;
  final String? proofUrl;
  final String? costCenter;
  final String status;
  final DateTime? approvedAt;
  final DateTime? paidAt;
  final String? rejectionReason;
  final bool isDemo;
  final DateTime createdAt;

  String get categoryLabel => switch (category) {
        'agua' => 'Agua',
        'energia' => 'Energia',
        'renda' => 'Renda',
        'construcao' => 'Construcao',
        'missoes' => 'Missoes',
        'acao_social' => 'Acao social',
        'salario' => 'Salario',
        'transporte' => 'Transporte',
        'equipamentos' => 'Equipamentos',
        'comunicacao' => 'Comunicacao',
        'alimentacao' => 'Alimentacao',
        'seguranca' => 'Seguranca',
        'manutencao' => 'Manutencao',
        'evento' => 'Evento',
        _ => 'Operacional',
      };

  String get statusLabel => switch (status) {
        'draft' => 'Rascunho',
        'pending_approval' => 'Aguardando aprovacao',
        'approved' => 'Aprovada',
        'paid' => 'Paga',
        'rejected' => 'Rejeitada',
        'cancelled' => 'Cancelada',
        _ => status,
      };

  bool get affectsBalance => status == 'paid';

  factory ChurchExpense.fromMap(Map<String, dynamic> map) {
    return ChurchExpense(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'operacional',
      title: (map['title'] as String?) ?? 'Despesa',
      amount: (map['amount'] as num?) ?? 0,
      currency: (map['currency'] as String?) ?? 'MZN',
      spentAt: DateTime.tryParse((map['spent_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      notes: map['notes'] as String?,
      vendorName: map['vendor_name'] as String?,
      paymentMethod: map['payment_method'] as String?,
      paymentReference: map['payment_reference'] as String?,
      proofUrl: map['proof_url'] as String?,
      costCenter: map['cost_center'] as String?,
      status: (map['status'] as String?) ?? 'paid',
      approvedAt: DateTime.tryParse((map['approved_at'] as String?) ?? ''),
      paidAt: DateTime.tryParse((map['paid_at'] as String?) ?? ''),
      rejectionReason: map['rejection_reason'] as String?,
      isDemo: (map['is_demo'] as bool?) ?? false,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
