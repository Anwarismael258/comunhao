class PaymentChannel {
  const PaymentChannel({
    required this.provider,
    this.accountName,
    this.accountNumber,
    this.instructions,
    this.isPrimary = false,
  });

  final String provider;
  final String? accountName;
  final String? accountNumber;
  final String? instructions;
  final bool isPrimary;

  String get label {
    switch (provider.toLowerCase()) {
      case 'mpesa':
        return 'M-Pesa';
      case 'emola':
        return 'e-Mola';
      case 'bank':
        return 'Banco';
      default:
        return provider;
    }
  }

  factory PaymentChannel.fromMap(Map<String, dynamic> map) {
    return PaymentChannel(
      provider: (map['provider'] as String?) ?? 'Pagamento',
      accountName: map['account_name'] as String?,
      accountNumber: map['account_number'] as String?,
      instructions: map['instructions'] as String?,
      isPrimary: map['is_primary'] as bool? ?? false,
    );
  }
}
