class PrayerResponse {
  const PrayerResponse({
    required this.id,
    required this.prayerRequestId,
    required this.churchId,
    required this.responderProfileId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String prayerRequestId;
  final String churchId;
  final String responderProfileId;
  final String body;
  final DateTime createdAt;

  factory PrayerResponse.fromMap(Map<String, dynamic> map) {
    return PrayerResponse(
      id: (map['id'] as String?) ?? '',
      prayerRequestId: (map['prayer_request_id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      responderProfileId: (map['responder_profile_id'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
