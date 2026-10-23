import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/legal_document.dart';

class LegalRepository {
  LegalRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<LegalDocument>> fetchCurrentDocuments() async {
    final result = await _client.rpc('get_current_legal_documents');
    final rows = switch (result) {
      List<dynamic> value => value,
      _ => const <dynamic>[],
    };

    return rows
        .whereType<Map<String, dynamic>>()
        .map(LegalDocument.fromMap)
        .toList(growable: false);
  }

  Future<void> acceptDocument(LegalDocument document) async {
    await _client.rpc(
      'accept_legal_document',
      params: {
        'p_document_key': document.key,
        'p_version': document.version,
      },
    );
  }
}
