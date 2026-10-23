class DailyScriptureContent {
  const DailyScriptureContent({
    required this.contentDate,
    required this.referenceLabel,
    required this.scriptureText,
    required this.theme,
    required this.devotionalTitle,
    required this.devotionalSummary,
    required this.devotionalReflection,
    required this.practicalApplication,
    required this.prayer,
    required this.meditationQuestion,
    required this.readingPlan,
    required this.sourceStatus,
    this.provider,
    this.bibleName,
    this.bibleAbbreviation,
    this.copyright,
  });

  final DateTime contentDate;
  final String? provider;
  final String? bibleName;
  final String? bibleAbbreviation;
  final String referenceLabel;
  final String scriptureText;
  final String? copyright;
  final String theme;
  final String devotionalTitle;
  final String devotionalSummary;
  final String devotionalReflection;
  final String practicalApplication;
  final String prayer;
  final String meditationQuestion;
  final String readingPlan;
  final String sourceStatus;

  String get translationLabel {
    final abbreviation = bibleAbbreviation?.trim();
    if (abbreviation != null && abbreviation.isNotEmpty) {
      return abbreviation;
    }
    final name = bibleName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'Comunhao';
  }

  bool get isFallback =>
      sourceStatus == 'cache_latest' || sourceStatus == 'local_fallback';

  bool get isCampaignOverride => sourceStatus == 'campaign_override';

  factory DailyScriptureContent.fromMap(Map<String, dynamic> map) {
    return DailyScriptureContent(
      contentDate: DateTime.tryParse((map['content_date'] as String?) ?? '') ??
          DateTime.now(),
      provider: map['provider'] as String?,
      bibleName: map['bible_name'] as String?,
      bibleAbbreviation: map['bible_abbreviation'] as String?,
      referenceLabel: _cleanText((map['reference_label'] as String?) ?? ''),
      scriptureText: _cleanText((map['scripture_text'] as String?) ?? ''),
      copyright: _cleanNullableText(map['copyright'] as String?),
      theme: _cleanText((map['theme'] as String?) ?? 'comunhao'),
      devotionalTitle:
          _cleanText((map['devotional_title'] as String?) ?? 'Palavra do dia'),
      devotionalSummary:
          _cleanText((map['devotional_summary'] as String?) ?? ''),
      devotionalReflection:
          _cleanText((map['devotional_reflection'] as String?) ?? ''),
      practicalApplication:
          _cleanText((map['practical_application'] as String?) ?? ''),
      prayer: _cleanText((map['prayer'] as String?) ?? ''),
      meditationQuestion:
          _cleanText((map['meditation_question'] as String?) ?? ''),
      readingPlan: _cleanText((map['reading_plan'] as String?) ?? ''),
      sourceStatus: (map['source_status'] as String?) ?? 'cache_today',
    );
  }
}

String? _cleanNullableText(String? value) {
  if (value == null) return null;
  return _cleanText(value);
}

String _cleanText(String value) {
  return value
      .replaceAll('Ã¡', 'á')
      .replaceAll('Ã ', 'à')
      .replaceAll('Ã¢', 'â')
      .replaceAll('Ã£', 'ã')
      .replaceAll('Ã©', 'é')
      .replaceAll('Ãª', 'ê')
      .replaceAll('Ã­', 'í')
      .replaceAll('Ã³', 'ó')
      .replaceAll('Ã´', 'ô')
      .replaceAll('Ãµ', 'õ')
      .replaceAll('Ãº', 'ú')
      .replaceAll('Ã§', 'ç')
      .replaceAll('Ã', 'Á')
      .replaceAll('Ã‰', 'É')
      .replaceAll('Ã“', 'Ó')
      .replaceAll('Â', '');
}
