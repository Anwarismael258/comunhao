import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/legal_document.dart';
import '../repositories/legal_repository.dart';

class LegalDocumentsPage extends StatefulWidget {
  const LegalDocumentsPage({
    super.key,
    LegalRepository? repository,
  }) : _repository = repository;

  final LegalRepository? _repository;

  @override
  State<LegalDocumentsPage> createState() => _LegalDocumentsPageState();
}

class _LegalDocumentsPageState extends State<LegalDocumentsPage> {
  late final LegalRepository _repository;
  late Future<List<LegalDocument>> _documentsFuture;
  String? _busyDocumentKey;

  @override
  void initState() {
    super.initState();
    _repository = widget._repository ?? LegalRepository();
    _documentsFuture = _repository.fetchCurrentDocuments();
  }

  Future<void> _accept(LegalDocument document) async {
    setState(() => _busyDocumentKey = document.key);
    try {
      await _repository.acceptDocument(document);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${document.title} aceite com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _busyDocumentKey = null);
      }
    }
  }

  String _friendlyError(Object error) {
    final lower = error.toString().toLowerCase();
    if (lower.contains('authentication_required') ||
        Supabase.instance.client.auth.currentUser == null) {
      return 'Entra na conta para registar o aceite.';
    }
    if (lower.contains('legal_document_not_found')) {
      return 'Este documento ja nao esta disponivel nesta versao.';
    }
    return 'Nao foi possivel registar o aceite agora.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Termos e privacidade')),
      body: FutureBuilder<List<LegalDocument>>(
        future: _documentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _LegalStateMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Nao foi possivel carregar',
              body:
                  'Atualiza a pagina depois de aplicar a migration de termos e privacidade.',
              actionLabel: 'Tentar novamente',
              onAction: () {
                setState(() {
                  _documentsFuture = _repository.fetchCurrentDocuments();
                });
              },
            );
          }

          final documents = snapshot.data ?? const <LegalDocument>[];
          if (documents.isEmpty) {
            return const _LegalStateMessage(
              icon: Icons.description_outlined,
              title: 'Sem documentos publicados',
              body: 'Termos e privacidade ainda nao foram publicados.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: documents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final document = documents[index];
              return _LegalDocumentCard(
                document: document,
                busy: _busyDocumentKey == document.key,
                onAccept: Supabase.instance.client.auth.currentUser == null
                    ? null
                    : () => _accept(document),
              );
            },
          );
        },
      ),
    );
  }
}

class _LegalDocumentCard extends StatelessWidget {
  const _LegalDocumentCard({
    required this.document,
    required this.busy,
    required this.onAccept,
  });

  final LegalDocument document;
  final bool busy;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final effectiveDate = document.effectiveAt;
    final effectiveLabel = effectiveDate == null
        ? null
        : '${effectiveDate.year}-${effectiveDate.month.toString().padLeft(2, '0')}-${effectiveDate.day.toString().padLeft(2, '0')}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  document.key == 'privacy'
                      ? Icons.privacy_tip_outlined
                      : Icons.gavel_outlined,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (document.version.isNotEmpty)
                            'Versao ${document.version}',
                          if (effectiveLabel != null)
                            'Em vigor desde $effectiveLabel',
                        ].join(' - '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (document.summary != null && document.summary!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                document.summary!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            SelectableText(document.body),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: busy ? null : onAccept,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Li e aceito'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalStateMessage extends StatelessWidget {
  const _LegalStateMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(body, textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
