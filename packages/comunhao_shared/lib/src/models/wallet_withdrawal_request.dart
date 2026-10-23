class WalletWithdrawalRequest {
  const WalletWithdrawalRequest({
    required this.id,
    required this.ownerType,
    this.churchId,
    this.churchName,
    required this.provider,
    required this.amount,
    required this.currency,
    required this.destinationNumber,
    this.destinationHolder,
    this.estimatedFee = 0,
    this.netAmount,
    this.reason,
    required this.status,
    this.notes,
    required this.createdAt,
    this.processedAt,
    this.completedAt,
  });

  final String id;
  final String ownerType;
  final String? churchId;
  final String? churchName;
  final String provider;
  final num amount;
  final String currency;
  final String destinationNumber;
  final String? destinationHolder;
  final num estimatedFee;
  final num? netAmount;
  final String? reason;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime? processedAt;
  final DateTime? completedAt;

  bool get isPending => status == 'pending';
  bool get isProcessing => status == 'processing';

  String get ownerLabel =>
      ownerType == 'platform' ? 'Comunhao' : (churchName ?? 'Igreja');

  String get providerLabel => switch (provider) {
        'mpesa' => 'M-Pesa',
        'emola' => 'E-Mola',
        _ => provider,
      };

  String get statusLabel => switch (status) {
        'processing' => 'Processado',
        'approved' => 'Aprovado',
        'pending_second_approval' => 'Aguarda segunda aprovacao',
        'paid' => 'Pago',
        'completed' => 'Concluido',
        'rejected' => 'Rejeitado',
        'failed' => 'Falhou',
        'cancelled' => 'Cancelado',
        _ => 'Pendente',
      };

  factory WalletWithdrawalRequest.fromMap(Map<String, dynamic> map) {
    return WalletWithdrawalRequest(
      id: (map['id'] as String?) ?? '',
      ownerType: (map['owner_type'] as String?) ?? 'church',
      churchId: map['church_id'] as String?,
      churchName: map['church_name'] as String?,
      provider: (map['provider'] as String?) ?? '',
      amount: (map['amount'] as num?) ?? 0,
      currency: (map['currency'] as String?) ?? 'MZN',
      destinationNumber: (map['destination_number'] as String?) ?? '',
      destinationHolder: map['destination_holder'] as String?,
      estimatedFee: (map['estimated_fee'] as num?) ?? 0,
      netAmount: map['net_amount'] as num?,
      reason: map['reason'] as String?,
      status: (map['status'] as String?) ?? 'pending',
      notes: map['notes'] as String?,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      processedAt: DateTime.tryParse((map['processed_at'] as String?) ?? ''),
      completedAt: DateTime.tryParse((map['completed_at'] as String?) ?? ''),
    );
  }
}
