class ManagedPrayerResponse {
  const ManagedPrayerResponse({
    required this.id,
    required this.prayerRequestId,
    required this.churchId,
    required this.responderProfileId,
    required this.body,
    required this.createdAt,
    this.responderName,
  });

  final String id;
  final String prayerRequestId;
  final String churchId;
  final String responderProfileId;
  final String body;
  final DateTime createdAt;
  final String? responderName;

  String get responderLabel {
    final name = responderName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'Lideranca';
  }

  factory ManagedPrayerResponse.fromMap(Map<String, dynamic> map) {
    final rawProfile = map['responder'];
    final profile = switch (rawProfile) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => const <String, dynamic>{},
    };

    return ManagedPrayerResponse(
      id: (map['id'] as String?) ?? '',
      prayerRequestId: (map['prayer_request_id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      responderProfileId: (map['responder_profile_id'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      responderName: profile['full_name'] as String?,
    );
  }
}
