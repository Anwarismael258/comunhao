class WalletLedgerEntry {
  const WalletLedgerEntry({
    required this.id,
    required this.walletAccountId,
    required this.provider,
    required this.direction,
    required this.entryType,
    required this.amount,
    required this.currency,
    required this.status,
    this.description,
    this.referenceTable,
    this.referenceId,
    this.senderName,
    this.senderPhone,
    required this.createdAt,
    this.postedAt,
  });

  final String id;
  final String walletAccountId;
  final String provider;
  final String direction;
  final String entryType;
  final num amount;
  final String currency;
  final String status;
  final String? description;
  final String? referenceTable;
  final String? referenceId;
  final String? senderName;
  final String? senderPhone;
  final DateTime createdAt;
  final DateTime? postedAt;

  bool get isCredit => direction == 'credit';

  String get entryTypeLabel => switch (entryType) {
        'subscription_payment' => 'Pagamento de Plano',
        'other_revenue' => 'Outra Receita',
        'tithe' => 'Dizimo',
        'offering' => 'Oferta',
        'campaign' => 'Campanha',
        'withdrawal' => 'Levantamento',
        'expense' => 'Despesa',
        'refund' => 'Reembolso',
        'commission' => 'Comissao',
        'adjustment' => 'Ajuste',
        _ => entryType,
      };

  String get senderLabel {
    final name = senderName?.trim();
    final phone = senderPhone?.trim();
    if (name != null && name.isNotEmpty && phone != null && phone.isNotEmpty) {
      return '$name - $phone';
    }
    if (name != null && name.isNotEmpty) {
      return name;
    }
    if (phone != null && phone.isNotEmpty) {
      return phone;
    }
    return isCredit ? 'Remetente por confirmar' : 'Operacao da igreja';
  }

  factory WalletLedgerEntry.fromMap(Map<String, dynamic> map) {
    return WalletLedgerEntry(
      id: (map['id'] as String?) ?? '',
      walletAccountId: (map['wallet_account_id'] as String?) ?? '',
      provider: (map['provider'] as String?) ?? '',
      direction: (map['direction'] as String?) ?? 'credit',
      entryType: (map['entry_type'] as String?) ?? '',
      amount: (map['amount'] as num?) ?? 0,
      currency: (map['currency'] as String?) ?? 'MZN',
      status: (map['status'] as String?) ?? 'posted',
      description: map['description'] as String?,
      referenceTable: map['reference_table'] as String?,
      referenceId: map['reference_id'] as String?,
      senderName: map['sender_name'] as String?,
      senderPhone: map['sender_phone'] as String?,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      postedAt: DateTime.tryParse((map['posted_at'] as String?) ?? ''),
    );
  }
}
