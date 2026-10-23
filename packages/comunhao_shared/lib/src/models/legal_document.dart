class LegalDocument {
  const LegalDocument({
    required this.key,
    required this.title,
    required this.version,
    required this.body,
    this.summary,
    this.effectiveAt,
  });

  final String key;
  final String title;
  final String version;
  final String body;
  final String? summary;
  final DateTime? effectiveAt;

  factory LegalDocument.fromMap(Map<String, dynamic> map) {
    return LegalDocument(
      key: (map['document_key'] as String?) ?? '',
      title: (map['title'] as String?) ?? 'Documento legal',
      version: (map['version'] as String?) ?? '',
      summary: map['summary'] as String?,
      body: (map['body'] as String?) ?? '',
      effectiveAt: DateTime.tryParse((map['effective_at'] as String?) ?? ''),
    );
  }
}
