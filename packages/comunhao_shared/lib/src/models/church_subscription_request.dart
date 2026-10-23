class ChurchSubscriptionRequest {
  const ChurchSubscriptionRequest({
    required this.id,
    required this.churchId,
    required this.requestedPlanCode,
    required this.status,
    required this.requestedAt,
    this.reviewedAt,
    this.reviewNotes,
    this.churchName,
    this.city,
    this.requestedByName,
    this.paymentProvider,
    this.payerPhone,
    this.paymentReference,
    this.paymentNotes,
    this.expectedAmountMzn,
    this.paymentSubmittedAt,
  });

  final String id;
  final String churchId;
  final String requestedPlanCode;
  final String status;
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final String? reviewNotes;
  final String? churchName;
  final String? city;
  final String? requestedByName;
  final String? paymentProvider;
  final String? payerPhone;
  final String? paymentReference;
  final String? paymentNotes;
  final num? expectedAmountMzn;
  final DateTime? paymentSubmittedAt;

  bool get isPending => status == 'pending';

  String get planLabel => switch (requestedPlanCode) {
        'starter' => 'Starter',
        'essential' => 'Essencial',
        'premium' => 'Premium',
        _ => requestedPlanCode,
      };

  String get statusLabel => switch (status) {
        'approved' => 'Aprovado',
        'rejected' => 'Rejeitado',
        'cancelled' => 'Cancelado',
        _ => 'Pendente',
      };

  String get paymentProviderLabel => switch (paymentProvider) {
        'mpesa' => 'M-Pesa',
        'emola' => 'E-Mola',
        _ => 'Nao informado',
      };

  factory ChurchSubscriptionRequest.fromMap(Map<String, dynamic> map) {
    final rawChurch = map['church'];
    final church = switch (rawChurch) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => const <String, dynamic>{},
    };

    final rawRequester = map['requester'];
    final requester = switch (rawRequester) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => const <String, dynamic>{},
    };

    return ChurchSubscriptionRequest(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      requestedPlanCode: (map['requested_plan_code'] as String?) ?? 'starter',
      status: (map['status'] as String?) ?? 'pending',
      requestedAt: DateTime.tryParse((map['requested_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      reviewedAt: DateTime.tryParse((map['reviewed_at'] as String?) ?? ''),
      reviewNotes: map['review_notes'] as String?,
      churchName: church['name'] as String?,
      city: church['city'] as String?,
      requestedByName: requester['full_name'] as String?,
      paymentProvider: map['payment_provider'] as String?,
      payerPhone: map['payer_phone'] as String?,
      paymentReference: map['payment_reference'] as String?,
      paymentNotes: map['payment_notes'] as String?,
      expectedAmountMzn: map['expected_amount_mzn'] as num?,
      paymentSubmittedAt:
          DateTime.tryParse((map['payment_submitted_at'] as String?) ?? ''),
    );
  }
}
