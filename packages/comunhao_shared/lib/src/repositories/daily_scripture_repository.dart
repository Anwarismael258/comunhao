import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/daily_scripture_content.dart';

class DailyScriptureRepository {
  DailyScriptureRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<DailyScriptureContent> fetchToday({String? churchId}) async {
    try {
      final response = await _client.functions.invoke(
        'daily-scripture-engine',
        body: {
          if (churchId != null && churchId.isNotEmpty) 'church_id': churchId,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return DailyScriptureContent.fromMap(data);
      }
      throw const FormatException('daily_scripture_invalid_response');
    } catch (_) {
      final rows = await _client
          .from('daily_scripture_contents')
          .select()
          .order('content_date', ascending: false)
          .limit(1);
      final items = rows.whereType<Map<String, dynamic>>().toList();
      if (items.isEmpty) {
        return _localFallback;
      }
      return DailyScriptureContent.fromMap({
        ...items.first,
        'source_status': 'cache_latest',
      });
    }
  }
}

final _localFallback = DailyScriptureContent(
  contentDate: DateTime.now(),
  provider: 'local_fallback',
  bibleName: 'Bíblia Livre Para Todos',
  bibleAbbreviation: 'BLT',
  referenceLabel: 'João 3:16',
  scriptureText:
      'Pois Deus amou tanto o mundo, que deu o seu único Filho, para que todos os que acreditam nele não morram, mas tenham a vida eterna.',
  copyright: 'Creative Commons Attribution-ShareAlike 4.0',
  theme: 'salvação',
  devotionalTitle: 'Amor que nos encontra',
  devotionalSummary:
      'Deus toma a iniciativa e chama a comunidade a responder com fé.',
  devotionalReflection:
      'O evangelho começa no amor de Deus, não na capacidade humana de merecer alguma coisa.',
  practicalApplication:
      'Hoje, aproxima-te de alguém que precisa de uma palavra simples de esperança.',
  prayer: 'Senhor, ajuda-nos a viver a partir do teu amor.',
  meditationQuestion:
      'Como posso responder hoje ao amor de Deus de forma visível?',
  readingPlan: 'João 3; Romanos 5; Efésios 2',
  sourceStatus: 'local_fallback',
);
