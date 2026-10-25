class ChurchApplication {
  const ChurchApplication({
    this.id,
    this.pastorProfileId,
    required this.churchName,
    required this.city,
    this.province,
    this.country = 'Mozambique',
    required this.phone,
    this.email,
    this.applicantRole = 'pastor',
    this.logoUrl,
    this.primaryColor,
    this.secondaryColor,
    this.tagline,
    this.mpesa,
    this.emola,
    this.bankName,
    this.bankAccountName,
    this.bankAccountNumber,
    this.status = 'draft',
    this.submittedAt,
    this.reviewedAt,
    this.reviewNotes,
    this.approvedChurchId,
    this.pastorName,
    this.pastorPhone,
  });

  final String? id;
  final String? pastorProfileId;
  final String churchName;
  final String city;
  final String? province;
  final String country;
  final String phone;
  final String? email;
  final String applicantRole;
  final String? logoUrl;
  final String? primaryColor;
  final String? secondaryColor;
  final String? tagline;
  final String? mpesa;
  final String? emola;
  final String? bankName;
  final String? bankAccountName;
  final String? bankAccountNumber;
  final String status;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewNotes;
  final String? approvedChurchId;
  final String? pastorName;
  final String? pastorPhone;

  bool get canEdit => status == 'draft' || status == 'changes_requested';

  bool get canSubmit => status == 'draft' || status == 'changes_requested';

  String get statusLabel => switch (status) {
        'submitted' => 'Pendente',
        'changes_requested' => 'Precisa de correcoes',
        'approved' => 'Aprovada',
        'rejected' => 'Rejeitada',
        _ => 'Rascunho',
      };

  ChurchApplication copyWith({
    String? id,
    String? pastorProfileId,
    String? churchName,
    String? city,
    String? province,
    String? country,
    String? phone,
    String? email,
    String? applicantRole,
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
    String? tagline,
    String? mpesa,
    String? emola,
    String? bankName,
    String? bankAccountName,
    String? bankAccountNumber,
    String? status,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewNotes,
    String? approvedChurchId,
    String? pastorName,
    String? pastorPhone,
  }) {
    return ChurchApplication(
      id: id ?? this.id,
      pastorProfileId: pastorProfileId ?? this.pastorProfileId,
      churchName: churchName ?? this.churchName,
      city: city ?? this.city,
      province: province ?? this.province,
      country: country ?? this.country,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      applicantRole: applicantRole ?? this.applicantRole,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      tagline: tagline ?? this.tagline,
      mpesa: mpesa ?? this.mpesa,
      emola: emola ?? this.emola,
      bankName: bankName ?? this.bankName,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      approvedChurchId: approvedChurchId ?? this.approvedChurchId,
      pastorName: pastorName ?? this.pastorName,
      pastorPhone: pastorPhone ?? this.pastorPhone,
    );
  }

  Map<String, dynamic> toWriteMap() {
    return {
      'church_name': churchName.trim(),
      'pastor_profile_id': pastorProfileId,
      'city': city.trim(),
      'province': _nullableText(province),
      'country': country.trim().isEmpty ? 'Mozambique' : country.trim(),
      'phone': phone.trim(),
      'email': _nullableText(email),
      'applicant_role': applicantRole,
      'logo_url': _nullableText(logoUrl),
      'primary_color': _nullableText(primaryColor),
      'secondary_color': _nullableText(secondaryColor),
      'tagline': _nullableText(tagline),
      'mpesa': _nullableText(mpesa),
      'emola': _nullableText(emola),
      'bank_name': _nullableText(bankName),
      'bank_account_name': _nullableText(bankAccountName),
      'bank_account_number': _nullableText(bankAccountNumber),
      'status': status,
    };
  }

  factory ChurchApplication.fromMap(Map<String, dynamic> map) {
    final rawPastor = map['pastor'];
    final pastor = switch (rawPastor) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => const <String, dynamic>{},
    };

    return ChurchApplication(
      id: map['id'] as String?,
      pastorProfileId: map['pastor_profile_id'] as String?,
      churchName: (map['church_name'] as String?) ?? 'Igreja',
      city: (map['city'] as String?) ?? '',
      province: map['province'] as String?,
      country: (map['country'] as String?) ?? 'Mozambique',
      phone: (map['phone'] as String?) ?? '',
      email: map['email'] as String?,
      applicantRole: (map['applicant_role'] as String?) ?? 'pastor',
      logoUrl: map['logo_url'] as String?,
      primaryColor: map['primary_color'] as String?,
      secondaryColor: map['secondary_color'] as String?,
      tagline: map['tagline'] as String?,
      mpesa: map['mpesa'] as String?,
      emola: map['emola'] as String?,
      bankName: map['bank_name'] as String?,
      bankAccountName: map['bank_account_name'] as String?,
      bankAccountNumber: map['bank_account_number'] as String?,
      status: (map['status'] as String?) ?? 'draft',
      submittedAt: DateTime.tryParse((map['submitted_at'] as String?) ?? ''),
      reviewedAt: DateTime.tryParse((map['reviewed_at'] as String?) ?? ''),
      reviewNotes: map['review_notes'] as String?,
      approvedChurchId: map['approved_church_id'] as String?,
      pastorName: pastor['full_name'] as String?,
      pastorPhone: pastor['phone'] as String?,
    );
  }
}

String? _nullableText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
