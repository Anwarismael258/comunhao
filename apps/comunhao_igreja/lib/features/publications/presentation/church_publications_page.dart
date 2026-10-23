import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/web_upload_picker.dart';
import 'native_auto_media_stub.dart'
    if (dart.library.html) 'native_auto_media_web.dart';

class ChurchPublicationsPage extends StatefulWidget {
  const ChurchPublicationsPage({
    required this.church,
    required this.readOnly,
    this.openCreateRequest = 0,
    this.repository,
    super.key,
  });

  final ManagedChurch church;
  final bool readOnly;
  final int openCreateRequest;
  final PublicationRepository? repository;

  @override
  State<ChurchPublicationsPage> createState() => _ChurchPublicationsPageState();
}

class _ChurchPublicationsPageState extends State<ChurchPublicationsPage> {
  late final PublicationRepository _repository;
  late Future<List<PastoralPublication>> _future;
  String _typeFilter = 'all';
  String _statusFilter = 'all';
  String _scopeFilter = 'all';

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PublicationRepository();
    _future = _load();
    if (widget.openCreateRequest > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openEditor();
      });
    }
  }

  @override
  void didUpdateWidget(covariant ChurchPublicationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openCreateRequest != oldWidget.openCreateRequest &&
        widget.openCreateRequest > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openEditor();
      });
    }
  }

  Future<List<PastoralPublication>> _load() {
    return _repository.fetchManagedPublications(widget.church.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  List<PastoralPublication> _filtered(List<PastoralPublication> items) {
    final currentUserId = _currentUserId;
    final filtered = items
        .where((item) =>
            _scopeFilter == 'all' ||
            (currentUserId != null && item.authorUserId == currentUserId))
        .where((item) =>
            _typeFilter == 'all' || item.publicationType == _typeFilter)
        .where((item) => _statusFilter == 'all' || item.status == _statusFilter)
        .toList(growable: false);
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  Future<void> _openEditor([PastoralPublication? publication]) async {
    if (widget.readOnly) {
      return;
    }
    try {
      final result = await showDialog<PublicationDraft>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PublicationEditorDialog(
          churchId: widget.church.id,
          publication: publication,
        ),
      );

      if (result == null) {
        return;
      }

      await _repository.savePublication(result);
      if (!mounted) {
        return;
      }
      await _refresh();
      _message(
        result.status == 'published'
            ? 'Publicacao publicada.'
            : result.status == 'scheduled'
                ? 'Publicacao agendada.'
                : 'Publicacao guardada como rascunho.',
      );
    } catch (error) {
      if (mounted) {
        _message(_friendlyError(error));
      }
    }
  }

  Future<void> _duplicate(PastoralPublication publication) async {
    if (widget.readOnly) {
      return;
    }
    try {
      await _repository.duplicatePublication(publication);
      if (!mounted) {
        return;
      }
      await _refresh();
      _message('Copia criada como rascunho.');
    } catch (error) {
      if (mounted) {
        _message(_friendlyError(error));
      }
    }
  }

  Future<void> _archive(PastoralPublication publication) async {
    if (widget.readOnly) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arquivar publicacao'),
        content: Text('Pretendes arquivar "${publication.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Arquivar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _repository.archivePublication(publication.id);
      if (!mounted) {
        return;
      }
      await _refresh();
      _message('Publicacao arquivada.');
    } catch (error) {
      if (mounted) {
        _message(_friendlyError(error));
      }
    }
  }

  Future<void> _preview(PastoralPublication publication) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(publication.title),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: _PublicationPreview(publication: publication),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('lateinitializationerror') ||
        lower.contains('assertion failed')) {
      return 'A tela de publicacao ainda estava a inicializar. Atualiza a pagina uma vez e tenta novamente.';
    }
    if (lower.contains('row-level security') ||
        lower.contains('permission') ||
        lower.contains('unauthorized')) {
      return 'Sem permissao para publicar nesta igreja.';
    }
    if (lower.contains('violates check constraint') ||
        lower.contains('not-null') ||
        lower.contains('null value')) {
      return 'A publicacao tem campos incompletos. Confirma titulo, tipo, publico e conteudo/midia.';
    }
    if (lower.contains('duplicate key') || lower.contains('unique')) {
      return 'Ja existe uma publicacao com referencia semelhante. Altera um pouco o titulo e tenta novamente.';
    }
    return 'Nao foi possivel guardar a publicacao agora.';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PastoralPublication>>(
      future: _future,
      builder: (context, snapshot) {
        final publications = snapshot.data ?? const <PastoralPublication>[];
        final filtered = _filtered(publications);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              WorkspaceSectionCard(
                title: 'Publicacoes pastorais',
                subtitle:
                    'Conteudos permanentes: pregacoes, devocionais, estudos, videos, audios, documentos e avisos.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: widget.readOnly
                              ? () => _message(
                                    'A igreja esta em modo leitura. Regulariza a subscricao para publicar.',
                                  )
                              : () => _openEditor(),
                          icon: const Icon(Icons.add),
                          label: const Text('Nova publicacao'),
                        ),
                        if (widget.readOnly)
                          const Chip(
                            avatar: Icon(Icons.lock_outline, size: 18),
                            label: Text('Modo leitura'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _PublicationMetrics(publications: publications),
                    const SizedBox(height: 16),
                    _PublicationTypeSummary(publications: publications),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              WorkspaceSectionCard(
                title: 'Filtros',
                subtitle:
                    'Publicacoes sao conteudos; comunicacoes sao envios; notificacoes sao alertas.',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<String>(
                        initialValue: _typeFilter,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: [
                          const DropdownMenuItem(
                              value: 'all', child: Text('Todos')),
                          ..._publicationTypes.map(
                            (type) => DropdownMenuItem(
                              value: type.value,
                              child: Text(type.pluralLabel),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() {
                          _typeFilter = value ?? 'all';
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue: _statusFilter,
                        decoration: const InputDecoration(labelText: 'Estado'),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Todos')),
                          DropdownMenuItem(
                              value: 'draft', child: Text('Rascunhos')),
                          DropdownMenuItem(
                              value: 'scheduled', child: Text('Agendadas')),
                          DropdownMenuItem(
                              value: 'published', child: Text('Publicadas')),
                          DropdownMenuItem(
                              value: 'archived', child: Text('Arquivadas')),
                          DropdownMenuItem(
                              value: 'cancelled', child: Text('Canceladas')),
                        ],
                        onChanged: (value) => setState(() {
                          _statusFilter = value ?? 'all';
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue: _scopeFilter,
                        decoration: const InputDecoration(labelText: 'Autor'),
                        items: const [
                          DropdownMenuItem(
                              value: 'all', child: Text('Toda a igreja')),
                          DropdownMenuItem(
                              value: 'mine', child: Text('Minhas')),
                        ],
                        onChanged: (value) => setState(() {
                          _scopeFilter = value ?? 'all';
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (snapshot.hasError)
                _ErrorPanel(message: snapshot.error.toString())
              else if (filtered.isEmpty)
                const WorkspaceSectionCard(
                  title: 'Sem publicacoes',
                  subtitle: 'Cria a primeira mensagem, pregacao ou estudo.',
                  child: Text(
                      'Rascunhos ficam ocultos aos membros ate serem publicados.'),
                )
              else
                _PublicationTypeSections(
                  publications: filtered,
                  repository: _repository,
                  church: widget.church,
                  readOnly: widget.readOnly,
                  onEdit: _openEditor,
                  onDuplicate: _duplicate,
                  onArchive: _archive,
                  onPreview: _preview,
                  onChanged: _refresh,
                  onMessage: _message,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PublicationMetrics extends StatelessWidget {
  const _PublicationMetrics({required this.publications});

  final List<PastoralPublication> publications;

  @override
  Widget build(BuildContext context) {
    final published =
        publications.where((item) => item.status == 'published').length;
    final drafts = publications.where((item) => item.status == 'draft').length;
    final scheduled =
        publications.where((item) => item.status == 'scheduled').length;
    final archived =
        publications.where((item) => item.status == 'archived').length;
    final reads =
        publications.fold<int>(0, (sum, item) => sum + item.readCount);
    final mostRead = publications.toList()
      ..sort((a, b) => b.openCount.compareTo(a.openCount));

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        WorkspaceMetricCard(
          label: 'Publicacoes',
          value: publications.length.toString().padLeft(2, '0'),
          icon: Icons.library_books_outlined,
        ),
        WorkspaceMetricCard(
          label: 'Publicadas',
          value: published.toString().padLeft(2, '0'),
          icon: Icons.published_with_changes_outlined,
        ),
        WorkspaceMetricCard(
          label: 'Rascunhos',
          value: drafts.toString().padLeft(2, '0'),
          icon: Icons.edit_note_outlined,
        ),
        WorkspaceMetricCard(
          label: 'Agendadas',
          value: scheduled.toString().padLeft(2, '0'),
          icon: Icons.schedule_outlined,
        ),
        WorkspaceMetricCard(
          label: 'Arquivadas',
          value: archived.toString().padLeft(2, '0'),
          icon: Icons.archive_outlined,
        ),
        WorkspaceMetricCard(
          label: mostRead.isEmpty ? 'Leituras' : 'Top: ${mostRead.first.title}',
          value: reads.toString(),
          icon: Icons.visibility_outlined,
        ),
      ],
    );
  }
}

class _PublicationManagerCard extends StatelessWidget {
  const _PublicationManagerCard({
    required this.publication,
    required this.repository,
    required this.church,
    required this.readOnly,
    required this.onPreview,
    required this.onChanged,
    required this.onMessage,
    this.onEdit,
    this.onDuplicate,
    this.onArchive,
  });

  final PastoralPublication publication;
  final PublicationRepository repository;
  final ManagedChurch church;
  final bool readOnly;
  final VoidCallback onPreview;
  final Future<void> Function() onChanged;
  final ValueChanged<String> onMessage;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    final authorAvatarUrl = publication.authorAvatarUrl?.trim();
    return WorkspaceSectionCard(
      title: publication.title,
      subtitle: '${publication.statusLabel} - ${publication.visibilityLabel}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExpandableProfileAvatar(
                avatarUrl: authorAvatarUrl,
                label: publication.authorName ?? 'Igreja',
                radius: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  publication.authorName?.trim().isNotEmpty == true
                      ? publication.authorName!.trim()
                      : 'Pastor',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (publication.summary != null && publication.summary!.isNotEmpty)
            Text(publication.summary!),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PublicationTypeBadge(
                label: publication.typeLabel,
                icon: _iconForPublicationType(publication.publicationType),
              ),
              _PublicationTypeBadge(
                label: publication.statusLabel,
                icon: Icons.info_outline,
                muted: true,
              ),
              _PublicationTypeBadge(
                label: publication.visibilityLabel,
                icon: Icons.groups_outlined,
                muted: true,
              ),
              Chip(label: Text('${publication.readCount} leitura(s)')),
              Chip(label: Text('${publication.openCount} abertura(s)')),
              Chip(label: Text('${publication.savedCount} guardado(s)')),
              Chip(label: Text('${publication.reactionCount} reacao(oes)')),
              Chip(label: Text('${publication.commentCount} comentario(s)')),
              if (publication.isPinned) const Chip(label: Text('Fixada')),
              if (publication.isFeatured) const Chip(label: Text('Destaque')),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Preview'),
              ),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
              OutlinedButton.icon(
                onPressed: onDuplicate,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Duplicar'),
              ),
              OutlinedButton.icon(
                onPressed: publication.status == 'archived' ? null : onArchive,
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Arquivar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PastoralPublicationSocialPanel(
            publication: publication,
            repository: repository,
            churchName: church.name,
            churchLogoUrl: church.logoUrl,
            readOnly: readOnly,
            onChanged: onChanged,
            onMessage: onMessage,
          ),
        ],
      ),
    );
  }
}

class _PublicationTypeBadge extends StatelessWidget {
  const _PublicationTypeBadge({
    required this.label,
    required this.icon,
    this.muted = false,
  });

  final String label;
  final IconData icon;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = muted
        ? theme.colorScheme.onSurfaceVariant
        : _publicationBadgeColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconForPublicationType(String type) => switch (type) {
      'sermon' => Icons.record_voice_over_outlined,
      'devotional' => Icons.wb_sunny_outlined,
      'bible_study' => Icons.menu_book_outlined,
      'pastoral_message' => Icons.volunteer_activism_outlined,
      'urgent_notice' => Icons.priority_high_outlined,
      'video' => Icons.play_circle_outline,
      'audio' => Icons.headphones_outlined,
      'document' => Icons.description_outlined,
      'live_stream' => Icons.live_tv_outlined,
      'announcement' => Icons.campaign_outlined,
      'leadership_message' => Icons.groups_2_outlined,
      'testimony' => Icons.favorite_border,
      _ => Icons.article_outlined,
    };

Color _publicationBadgeColor(String label) {
  return switch (label.toLowerCase()) {
    'pregacao' => const Color(0xFF7C3AED),
    'devocional' => const Color(0xFF0F766E),
    'estudo biblico' => const Color(0xFF2563EB),
    'palavra pastoral' => const Color(0xFFBE123C),
    'aviso urgente' => const Color(0xFFDC2626),
    'video' => const Color(0xFF9333EA),
    'audio' => const Color(0xFF0891B2),
    'documento' => const Color(0xFF475569),
    'transmissao ao vivo' => const Color(0xFFEA580C),
    'comunicado' => const Color(0xFFCA8A04),
    'mensagem da lideranca' => const Color(0xFF4F46E5),
    'testemunho' => const Color(0xFF16A34A),
    _ => const Color(0xFF0F766E),
  };
}

class _PublicationTypeSummary extends StatelessWidget {
  const _PublicationTypeSummary({required this.publications});

  final List<PastoralPublication> publications;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in _publicationTypes)
          Chip(
            avatar: Icon(type.icon, size: 18),
            label: Text(
              '${type.pluralLabel}: ${_countType(type.value).toString().padLeft(2, '0')}',
            ),
          ),
      ],
    );
  }

  int _countType(String type) {
    return publications.where((item) => item.publicationType == type).length;
  }
}

class _PublicationTypeSections extends StatelessWidget {
  const _PublicationTypeSections({
    required this.publications,
    required this.repository,
    required this.church,
    required this.readOnly,
    required this.onEdit,
    required this.onDuplicate,
    required this.onArchive,
    required this.onPreview,
    required this.onChanged,
    required this.onMessage,
  });

  final List<PastoralPublication> publications;
  final PublicationRepository repository;
  final ManagedChurch church;
  final bool readOnly;
  final void Function(PastoralPublication publication) onEdit;
  final void Function(PastoralPublication publication) onDuplicate;
  final void Function(PastoralPublication publication) onArchive;
  final void Function(PastoralPublication publication) onPreview;
  final Future<void> Function() onChanged;
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) {
    final recent = [...publications]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Column(
      children: recent
          .map(
            (publication) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PublicationManagerCard(
                publication: publication,
                repository: repository,
                church: church,
                readOnly: readOnly,
                onEdit: readOnly ? null : () => onEdit(publication),
                onDuplicate: readOnly ? null : () => onDuplicate(publication),
                onArchive: readOnly ? null : () => onArchive(publication),
                onPreview: () => onPreview(publication),
                onChanged: onChanged,
                onMessage: onMessage,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PublicationReactionOption {
  const _PublicationReactionOption({
    required this.key,
    required this.label,
    required this.confirmation,
  });

  final String key;
  final String label;
  final String confirmation;
}

const _publicationReactionOptions = <_PublicationReactionOption>[
  _PublicationReactionOption(
    key: 'amen',
    label: '\u{1F64F} Am\u00e9m',
    confirmation: '\u{1F64F} Am\u00e9m registado.',
  ),
  _PublicationReactionOption(
    key: 'praying',
    label: 'Estou orando',
    confirmation: 'Marcado como estou orando.',
  ),
  _PublicationReactionOption(
    key: 'glory',
    label: 'Gl\u00f3ria a Deus',
    confirmation: 'Gl\u00f3ria a Deus registado.',
  ),
  _PublicationReactionOption(
    key: 'built',
    label: 'Fui edificado',
    confirmation: 'Fui edificado registado.',
  ),
  _PublicationReactionOption(
    key: 'faithful',
    label: 'Deus \u00e9 fiel',
    confirmation: 'Deus \u00e9 fiel registado.',
  ),
];

String _reactionConfirmation(String reaction) {
  return _publicationReactionOptions
      .firstWhere(
        (option) => option.key == reaction,
        orElse: () => _publicationReactionOptions.first,
      )
      .confirmation;
}

String _reactionLabel(String reaction) {
  return _publicationReactionOptions
      .firstWhere(
        (option) => option.key == reaction,
        orElse: () => _publicationReactionOptions.first,
      )
      .label;
}

class PastoralPublicationSocialPanel extends StatefulWidget {
  const PastoralPublicationSocialPanel({
    required this.publication,
    required this.repository,
    required this.churchName,
    this.churchLogoUrl,
    required this.readOnly,
    required this.onChanged,
    required this.onMessage,
    super.key,
  });

  final PastoralPublication publication;
  final PublicationRepository repository;
  final String churchName;
  final String? churchLogoUrl;
  final bool readOnly;
  final Future<void> Function() onChanged;
  final ValueChanged<String> onMessage;

  @override
  State<PastoralPublicationSocialPanel> createState() =>
      _PastoralPublicationSocialPanelState();
}

class _PastoralPublicationSocialPanelState
    extends State<PastoralPublicationSocialPanel> {
  late Future<List<PastoralPublicationComment>> _commentsFuture;
  late Future<List<PastoralPublicationReaction>> _reactionsFuture;
  final _commentController = TextEditingController();
  List<PastoralPublicationComment>? _comments;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _commentsFuture = _fetchAndStoreComments();
    _reactionsFuture = widget.repository.fetchReactions(widget.publication.id);
  }

  @override
  void didUpdateWidget(covariant PastoralPublicationSocialPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.publication.id != widget.publication.id) {
      _comments = null;
      _commentsFuture = _fetchAndStoreComments();
      _reactionsFuture =
          widget.repository.fetchReactions(widget.publication.id);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _reloadComments() async {
    setState(() {
      _commentsFuture = _fetchAndStoreComments();
      _reactionsFuture =
          widget.repository.fetchReactions(widget.publication.id);
    });
    await _commentsFuture;
  }

  Future<List<PastoralPublicationComment>> _fetchAndStoreComments() async {
    final comments =
        await widget.repository.fetchComments(widget.publication.id);
    if (mounted) _comments = comments;
    return comments;
  }

  Future<void> _react(String reaction) async {
    if (widget.readOnly || !widget.publication.allowReactions) return;
    setState(() => _busy = true);
    try {
      await widget.repository.react(widget.publication.id, reaction);
      await HapticFeedback.selectionClick();
      widget.onMessage(_reactionConfirmation(reaction));
      setState(() {
        _reactionsFuture =
            widget.repository.fetchReactions(widget.publication.id);
      });
      await widget.onChanged();
    } catch (_) {
      widget.onMessage('N\u00e3o foi poss\u00edvel reagir agora.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _comment({String? parentCommentId, String? body}) async {
    if (widget.readOnly || !widget.publication.allowComments) return;
    final text = (body ?? _commentController.text).trim();
    if (text.length < 2) return;
    setState(() => _busy = true);
    try {
      await widget.repository.comment(
        publicationId: widget.publication.id,
        body: text,
        parentCommentId: parentCommentId,
      );
      if (parentCommentId == null) _commentController.clear();
      final now = DateTime.now();
      final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final optimistic = PastoralPublicationComment(
        id: 'local-${now.microsecondsSinceEpoch}',
        publicationId: widget.publication.id,
        profileId: currentUserId,
        authorName: widget.churchName,
        authorAvatarUrl: widget.churchLogoUrl,
        parentCommentId: parentCommentId,
        body: text,
        status: 'active',
        createdAt: now,
      );
      setState(() {
        _comments = [...?_comments, optimistic];
        _commentsFuture =
            Future<List<PastoralPublicationComment>>.value(_comments);
      });
      await HapticFeedback.lightImpact();
      try {
        final fresh =
            await widget.repository.fetchComments(widget.publication.id);
        if (fresh.isNotEmpty) {
          setState(() {
            _comments = fresh;
            _commentsFuture =
                Future<List<PastoralPublicationComment>>.value(fresh);
          });
        }
      } catch (_) {
        // Mantem o comentario otimista visivel.
      }
      await widget.onChanged();
      widget.onMessage('Coment\u00e1rio publicado.');
    } catch (_) {
      widget.onMessage('N\u00e3o foi poss\u00edvel comentar agora.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reply(PastoralPublicationComment comment) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Responder a ${comment.authorName ?? 'comentario'}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Resposta'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(controller.text),
            icon: const Icon(Icons.reply_outlined),
            label: const Text('Responder'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null) return;
    await _comment(parentCommentId: comment.id, body: text);
  }

  Future<void> _hideComment(PastoralPublicationComment comment) async {
    if (widget.readOnly) return;
    setState(() => _busy = true);
    try {
      await widget.repository.moderateComment(commentId: comment.id);
      await _reloadComments();
      await widget.onChanged();
      widget.onMessage('Comentario ocultado.');
    } catch (_) {
      widget.onMessage('Nao foi possivel moderar o comentario.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    await Clipboard.setData(
      ClipboardData(text: widget.publication.title),
    );
    widget.onMessage('Referencia copiada para partilhar.');
  }

  @override
  Widget build(BuildContext context) {
    final publication = widget.publication;
    final commentsDisabled = !publication.allowComments;
    final reactionsDisabled = !publication.allowReactions;
    final visibleCommentCount = [
      publication.commentCount,
      _comments?.length ?? 0,
    ].reduce((a, b) => a > b ? a : b);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Intera\u00e7\u00f5es'),
      subtitle: Text(
        '${publication.reactionCount} rea\u00e7\u00e3o(\u00f5es) - $visibleCommentCount coment\u00e1rio(s)',
      ),
      childrenPadding: const EdgeInsets.only(top: 4, bottom: 6),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ..._publicationReactionOptions.map(
              (option) => ChoiceChip(
                selected: publication.myReaction == option.key,
                label: Text(option.label),
                onSelected: widget.readOnly || reactionsDisabled || _busy
                    ? null
                    : (_) => _react(option.key),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.ios_share_outlined),
              label: const Text('Partilhar'),
            ),
          ],
        ),
        if (commentsDisabled) ...[
          const SizedBox(height: 8),
          const Chip(label: Text('Coment\u00e1rios desativados')),
        ] else ...[
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              filled: true,
              labelText: 'Comentar como pastor',
              prefixIcon: Icon(Icons.chat_bubble_outline),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: widget.readOnly || _busy ? null : _comment,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Comentar'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        FutureBuilder<List<PastoralPublicationReaction>>(
          future: _reactionsFuture,
          builder: (context, snapshot) {
            final reactions =
                snapshot.data ?? const <PastoralPublicationReaction>[];
            if (reactions.isEmpty) return const SizedBox.shrink();
            return Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: reactions.take(8).map((reaction) {
                  final isChurch = _isChurchActor(
                    reaction.profileId,
                    reaction.authorName,
                  );
                  final avatarUrl = isChurch
                      ? widget.churchLogoUrl ?? reaction.authorAvatarUrl
                      : reaction.authorAvatarUrl;
                  final authorName = isChurch
                      ? widget.churchName
                      : reaction.authorName ?? 'Membro';
                  return ActionChip(
                    avatar: CircleAvatar(
                      backgroundImage: avatarUrl?.trim().isNotEmpty == true
                          ? NetworkImage(avatarUrl!.trim())
                          : null,
                      child: avatarUrl?.trim().isNotEmpty == true
                          ? null
                          : const Icon(Icons.person_outline, size: 16),
                    ),
                    label: Text(
                      '${_reactionLabel(reaction.reactionType)} $authorName',
                    ),
                    onPressed: () {},
                  );
                }).toList(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<PastoralPublicationComment>>(
          future: _commentsFuture,
          builder: (context, snapshot) {
            final comments = _comments ??
                snapshot.data ??
                const <PastoralPublicationComment>[];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            }
            if (comments.isEmpty) {
              return const Align(
                alignment: Alignment.centerLeft,
                child: Text('Ainda sem coment\u00e1rios.'),
              );
            }
            final roots =
                comments.where((comment) => comment.parentCommentId == null);
            return Column(
              children: [
                for (final comment in roots)
                  _PastoralCommentTile(
                    comment: comment,
                    replies: comments
                        .where((reply) => reply.parentCommentId == comment.id)
                        .toList(growable: false),
                    publicationAuthorUserId: widget.publication.authorUserId,
                    churchName: widget.churchName,
                    churchLogoUrl: widget.churchLogoUrl,
                    isChurchActor: _isChurchActor,
                    busy: _busy,
                    readOnly: widget.readOnly,
                    onReply: () => _reply(comment),
                    onHide: () => _hideComment(comment),
                    onHideReply: _hideComment,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  bool _isChurchActor(String profileId, String? authorName) {
    if (profileId == widget.publication.authorUserId) return true;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId != null && profileId == currentUserId) return true;
    final name = (authorName ?? '').trim().toLowerCase();
    return name == widget.churchName.trim().toLowerCase() ||
        name.contains('pastor') ||
        name.contains('igreja');
  }
}

class _PastoralCommentTile extends StatelessWidget {
  const _PastoralCommentTile({
    required this.comment,
    required this.replies,
    required this.publicationAuthorUserId,
    required this.churchName,
    required this.isChurchActor,
    this.churchLogoUrl,
    required this.busy,
    required this.readOnly,
    required this.onReply,
    required this.onHide,
    required this.onHideReply,
  });

  final PastoralPublicationComment comment;
  final List<PastoralPublicationComment> replies;
  final String? publicationAuthorUserId;
  final String churchName;
  final bool Function(String profileId, String? authorName) isChurchActor;
  final String? churchLogoUrl;
  final bool busy;
  final bool readOnly;
  final VoidCallback onReply;
  final VoidCallback onHide;
  final ValueChanged<PastoralPublicationComment> onHideReply;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PastoralCommentRow(
          comment: comment,
          displayAuthorName:
              isChurchActor(comment.profileId, comment.authorName)
                  ? churchName
                  : comment.authorName ?? 'Membro',
          displayAvatarUrl: isChurchActor(comment.profileId, comment.authorName)
              ? churchLogoUrl ?? comment.authorAvatarUrl
              : comment.authorAvatarUrl,
          busy: busy,
          readOnly: readOnly,
          onReply: onReply,
          onHide: onHide,
        ),
        for (final reply in replies)
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: _PastoralCommentRow(
              comment: reply,
              displayAuthorName:
                  isChurchActor(reply.profileId, reply.authorName)
                      ? churchName
                      : reply.authorName ?? 'Membro',
              displayAvatarUrl: isChurchActor(reply.profileId, reply.authorName)
                  ? churchLogoUrl ?? reply.authorAvatarUrl
                  : reply.authorAvatarUrl,
              busy: busy,
              readOnly: readOnly,
              onHide: () => onHideReply(reply),
            ),
          ),
      ],
    );
  }
}

class _PastoralCommentRow extends StatelessWidget {
  const _PastoralCommentRow({
    required this.comment,
    required this.displayAuthorName,
    required this.displayAvatarUrl,
    required this.busy,
    required this.readOnly,
    required this.onHide,
    this.onReply,
  });

  final PastoralPublicationComment comment;
  final String displayAuthorName;
  final String? displayAvatarUrl;
  final bool busy;
  final bool readOnly;
  final VoidCallback onHide;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarUrl = displayAvatarUrl?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExpandableProfileAvatar(
            avatarUrl: avatarUrl,
            label: displayAuthorName,
            radius: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayAuthorName,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          comment.body,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _dateLabel(comment.createdAt),
                      style: theme.textTheme.labelSmall,
                    ),
                    if (onReply != null)
                      TextButton(
                        onPressed: busy || readOnly ? null : onReply,
                        child: const Text('Responder'),
                      ),
                    IconButton(
                      tooltip: 'Ocultar coment\u00e1rio',
                      onPressed: busy || readOnly ? null : onHide,
                      icon: const Icon(Icons.visibility_off_outlined, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PublicationEditorDialog extends StatefulWidget {
  const PublicationEditorDialog({
    required this.churchId,
    this.publication,
    super.key,
  });

  final String churchId;
  final PastoralPublication? publication;

  @override
  State<PublicationEditorDialog> createState() =>
      _PublicationEditorDialogState();
}

class _PublicationEditorDialogState extends State<PublicationEditorDialog> {
  static const _mediaBucket = 'pastoral-publications';

  late final TextEditingController _title;
  late final TextEditingController _summary;
  late final TextEditingController _content;
  late final TextEditingController _category;
  late final TextEditingController _cover;
  late final TextEditingController _audio;
  late final TextEditingController _video;
  late final TextEditingController _document;
  late final TextEditingController _live;
  late final TextEditingController _external;

  String _type = 'pastoral_message';
  String _visibility = 'all';
  String _priority = 'normal';
  bool _allowComments = true;
  bool _allowReactions = true;
  bool _allowSharing = true;
  bool _sendNotification = false;
  bool _featured = false;
  bool _pinned = false;
  DateTime? _scheduledAt;
  DateTime? _expiresAt;
  String? _uploadingField;
  String _mainMediaType = 'text';

  @override
  void initState() {
    super.initState();
    final current = widget.publication;
    _title = TextEditingController(text: current?.title ?? '');
    _summary = TextEditingController(text: current?.summary ?? '');
    _content = TextEditingController(text: current?.content ?? '');
    _category = TextEditingController(text: current?.category ?? 'geral');
    _cover = TextEditingController(text: current?.coverImageUrl ?? '');
    _audio = TextEditingController(text: current?.audioUrl ?? '');
    _video = TextEditingController(text: current?.videoUrl ?? '');
    _document = TextEditingController(text: current?.documentUrl ?? '');
    _live = TextEditingController(text: current?.liveStreamUrl ?? '');
    _external = TextEditingController(text: current?.externalUrl ?? '');
    _type = current?.publicationType ?? 'pastoral_message';
    _visibility = current?.visibility ?? 'all';
    _priority = current?.priority ?? 'normal';
    _allowComments = current?.allowComments ?? true;
    _allowReactions = current?.allowReactions ?? true;
    _allowSharing = current?.allowSharing ?? true;
    _sendNotification = current?.sendNotification ?? false;
    _featured = current?.isFeatured ?? false;
    _pinned = current?.isPinned ?? false;
    _scheduledAt = current?.scheduledAt;
    _expiresAt = current?.expiresAt;
    _mainMediaType = _inferMainMediaType(current);
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _content.dispose();
    _category.dispose();
    _cover.dispose();
    _audio.dispose();
    _video.dispose();
    _document.dispose();
    _live.dispose();
    _external.dispose();
    super.dispose();
  }

  Future<void> _pickScheduledAt() async {
    final picked = await _pickDate(context, _scheduledAt ?? DateTime.now());
    if (picked != null) {
      setState(() => _scheduledAt = picked);
    }
  }

  Future<void> _pickExpiresAt() async {
    final picked = await _pickDate(
      context,
      _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null) {
      setState(() => _expiresAt = picked);
    }
  }

  Future<void> _uploadImage() async {
    _selectMainMedia('photo');
    await _runUpload('cover', () async {
      final nativeFile = await pickUploadFile(
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        accept: 'image/jpeg,image/png,image/webp',
      );
      if (nativeFile != null) {
        return _uploadBytes(
          folder: 'publications/images',
          name: nativeFile.name,
          bytes: nativeFile.bytes,
        );
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      final file = result?.files.single;
      if (file == null) return null;
      final bytes = file.bytes;
      if (bytes == null) return null;
      return _uploadBytes(
        folder: 'publications/images',
        name: file.name,
        bytes: bytes,
      );
    }, _cover);
  }

  Future<void> _uploadVideo() async {
    _selectMainMedia('video');
    await _uploadFile(
      field: 'video',
      folder: 'publications/videos',
      controller: _video,
      type: FileType.custom,
      allowedExtensions: const ['mp4', 'mov', 'm4v', 'webm'],
    );
  }

  Future<void> _uploadFile({
    required String field,
    required String folder,
    required TextEditingController controller,
    required FileType type,
    List<String>? allowedExtensions,
  }) async {
    if (field == 'audio') {
      _selectMainMedia('audio');
    } else if (field == 'document') {
      _selectMainMedia('document');
    }
    await _runUpload(field, () async {
      final nativeFile = await pickUploadFile(
        allowedExtensions: allowedExtensions ?? const [],
        accept: _acceptFor(allowedExtensions),
      );
      if (nativeFile != null) {
        return _uploadBytes(
          folder: folder,
          name: nativeFile.name,
          bytes: nativeFile.bytes,
        );
      }

      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return null;
      return _uploadBytes(folder: folder, name: file.name, bytes: bytes);
    }, controller);
  }

  Future<void> _runUpload(
    String field,
    Future<String?> Function() upload,
    TextEditingController controller,
  ) async {
    setState(() => _uploadingField = field);
    try {
      final url = await upload();
      if (url != null && mounted) {
        setState(() => controller.text = url);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyUploadError(error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingField = null);
      }
    }
  }

  String _friendlyUploadError(Object error) {
    final lower = error.toString().toLowerCase();
    if (error is MissingPluginException ||
        lower.contains('missingpluginexception')) {
      return 'O seletor de ficheiros ainda nao carregou nesta sessao. Atualiza a pagina e tenta novamente.';
    }
    if (lower.contains('payload too large') ||
        lower.contains('exceeded') ||
        lower.contains('file size') ||
        lower.contains('too large')) {
      return 'O ficheiro e muito grande. Usa ate 100 MB para video/audio/documento e ate 5 MB para imagens.';
    }
    if (lower.contains('mime') ||
        lower.contains('content type') ||
        lower.contains('not allowed') ||
        lower.contains('unsupported')) {
      return 'Tipo de ficheiro nao permitido. Usa JPG, PNG, WEBP, MP3, M4A, MP4, PDF, DOC ou DOCX.';
    }
    if (lower.contains('jwt') ||
        lower.contains('expired') ||
        lower.contains('not authenticated')) {
      return 'Sessao expirada. Sai e entra novamente para fazer upload.';
    }
    if (lower.contains('row-level security') ||
        lower.contains('unauthorized') ||
        lower.contains('permission')) {
      return 'Sem permissao para guardar o ficheiro no Storage.';
    }
    return 'Nao foi possivel carregar o ficheiro agora.';
  }

  Future<String> _uploadBytes({
    required String folder,
    required String name,
    required Uint8List bytes,
  }) async {
    final extension = _extensionFor(name);
    final path =
        '${widget.churchId}/$folder/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final client = Supabase.instance.client;
    await client.storage.from(_mediaBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _contentTypeFor(extension)),
        );
    return client.storage.from(_mediaBucket).getPublicUrl(path);
  }

  String _extensionFor(String fileName) {
    final clean = fileName.split('?').first.toLowerCase();
    final index = clean.lastIndexOf('.');
    if (index == -1 || index == clean.length - 1) return 'jpg';
    return clean.substring(index + 1);
  }

  String _contentTypeFor(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'mp4' => 'video/mp4',
      'm4v' => 'video/x-m4v',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'image/jpeg',
    };
  }

  String? _acceptFor(List<String>? extensions) {
    if (extensions == null || extensions.isEmpty) return null;
    return extensions.map((extension) => '.$extension').join(',');
  }

  Widget _uploadButton({
    required String field,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final uploading = _uploadingField == field;
    return OutlinedButton.icon(
      onPressed: _uploadingField == null ? onPressed : null,
      icon: uploading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
    );
  }

  String? _mediaRequirementMessage() {
    final used = [
      if (_cover.text.trim().isNotEmpty) 'Foto',
      if (_video.text.trim().isNotEmpty) 'Video',
      if (_audio.text.trim().isNotEmpty) 'Audio',
      if (_document.text.trim().isNotEmpty) 'Documento',
    ];
    if (used.length > 1) {
      return 'Escolhe apenas uma midia principal: foto, video, audio ou documento.';
    }
    return null;
  }

  String _inferMainMediaType(PastoralPublication? publication) {
    if (publication == null) return 'text';
    if (publication.coverImageUrl?.trim().isNotEmpty == true) return 'photo';
    if (publication.videoUrl?.trim().isNotEmpty == true) return 'video';
    if (publication.audioUrl?.trim().isNotEmpty == true) return 'audio';
    if (publication.documentUrl?.trim().isNotEmpty == true) return 'document';
    return 'text';
  }

  void _selectMainMedia(String value) {
    setState(() {
      _mainMediaType = value;
      if (value != 'photo') _cover.clear();
      if (value != 'video') _video.clear();
      if (value != 'audio') _audio.clear();
      if (value != 'document') _document.clear();
    });
  }

  String _cleanMediaValue(String type, TextEditingController controller) {
    return _mainMediaType == type ? controller.text.trim() : '';
  }

  String _typeHelperText() {
    return switch (_type) {
      'sermon' => 'Pregacao: usa texto, audio ou video da mensagem.',
      'devotional' => 'Devocional: conteudo curto para leitura espiritual.',
      'bible_study' => 'Estudo biblico: texto, documento ou midia de apoio.',
      'pastoral_message' => 'Palavra pastoral: mensagem direta da lideranca.',
      'urgent_notice' => 'Aviso urgente: fica marcado como urgente e fixado.',
      'video' => 'Video: anexa um ficheiro MP4 ou informa a URL do video.',
      'audio' => 'Audio: anexa MP3/M4A ou informa a URL do audio.',
      'document' => 'Documento: anexa PDF/DOC/DOCX ou informa a URL.',
      'live_stream' => 'Transmissao: informa a URL da live.',
      _ => 'Mantem o conteudo alinhado ao tipo escolhido.',
    };
  }

  void _save(String status) {
    final title = _title.text.trim();
    final content = _content.text.trim();
    final hasMedia = [
      _cover.text,
      _audio.text,
      _video.text,
      _document.text,
      _live.text,
      _external.text,
    ].any((value) => value.trim().isNotEmpty);
    if (title.length < 3 || (content.length < 3 && !hasMedia)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preenche titulo e conteudo ou adiciona uma midia.'),
        ),
      );
      return;
    }
    final mediaRequirement = _mediaRequirementMessage();
    if (mediaRequirement != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mediaRequirement)),
      );
      return;
    }
    if (status == 'scheduled' && _scheduledAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolhe a data de agendamento.')),
      );
      return;
    }
    Navigator.of(context).pop(
      PublicationDraft(
        id: widget.publication?.id,
        churchId: widget.churchId,
        title: title,
        summary: _summary.text,
        content: content.isEmpty
            ? (_summary.text.trim().isEmpty ? title : _summary.text.trim())
            : content,
        publicationType: _type,
        category: _category.text,
        coverImageUrl: _cleanMediaValue('photo', _cover),
        audioUrl: _cleanMediaValue('audio', _audio),
        videoUrl: _cleanMediaValue('video', _video),
        documentUrl: _cleanMediaValue('document', _document),
        liveStreamUrl: _live.text,
        externalUrl: _external.text,
        status: status,
        visibility: _visibility,
        priority: _priority,
        scheduledAt: _scheduledAt,
        expiresAt: _expiresAt,
        allowComments: _allowComments,
        allowReactions: _allowReactions,
        allowSharing: _allowSharing,
        sendNotification: _sendNotification,
        isFeatured: _featured,
        isPinned: _pinned,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.publication == null ? 'Nova publicacao' : 'Editar publicacao'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Titulo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _summary,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Resumo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _content,
                minLines: 6,
                maxLines: 12,
                decoration: const InputDecoration(labelText: 'Conteudo'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: _publicationTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type.value,
                              child: Text(type.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) => setState(() {
                        _type = value ?? 'pastoral_message';
                        if (_type == 'urgent_notice') {
                          _priority = 'urgent';
                          _pinned = true;
                        }
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _category,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _visibility,
                      decoration: const InputDecoration(labelText: 'Publico'),
                      items: const [
                        DropdownMenuItem(
                            value: 'all', child: Text('Toda a igreja')),
                        DropdownMenuItem(
                            value: 'members', child: Text('Membros')),
                        DropdownMenuItem(
                            value: 'pastors', child: Text('Pastores')),
                        DropdownMenuItem(
                            value: 'leaders', child: Text('Lideres')),
                        DropdownMenuItem(value: 'youth', child: Text('Jovens')),
                        DropdownMenuItem(value: 'men', child: Text('Homens')),
                        DropdownMenuItem(
                            value: 'women', child: Text('Senhoras')),
                        DropdownMenuItem(
                            value: 'children', child: Text('Criancas')),
                      ],
                      onChanged: (value) => setState(() {
                        _visibility = value ?? 'all';
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _typeHelperText(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.notes_outlined, size: 18),
                    label: const Text('Apenas texto'),
                    selected: _mainMediaType == 'text',
                    onSelected: (_) => _selectMainMedia('text'),
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Foto'),
                    selected: _mainMediaType == 'photo',
                    onSelected: (_) => _selectMainMedia('photo'),
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.video_library_outlined, size: 18),
                    label: const Text('Video'),
                    selected: _mainMediaType == 'video',
                    onSelected: (_) => _selectMainMedia('video'),
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.audio_file_outlined, size: 18),
                    label: const Text('Audio'),
                    selected: _mainMediaType == 'audio',
                    onSelected: (_) => _selectMainMedia('audio'),
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('Documento'),
                    selected: _mainMediaType == 'document',
                    onSelected: (_) => _selectMainMedia('document'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_mainMediaType == 'photo') ...[
                TextField(
                  controller: _cover,
                  decoration:
                      const InputDecoration(labelText: 'Imagem de capa URL'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _uploadButton(
                    field: 'cover',
                    icon: Icons.photo_library_outlined,
                    label: 'Imagem da galeria',
                    onPressed: _uploadImage,
                  ),
                ),
                if (_cover.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Image.network(
                        _cover.text.trim(),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text('Imagem sera carregada pela URL.'),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
              if (_mainMediaType == 'audio') ...[
                TextField(
                  controller: _audio,
                  decoration: const InputDecoration(labelText: 'Audio URL'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _uploadButton(
                    field: 'audio',
                    icon: Icons.audio_file_outlined,
                    label: 'Upload audio',
                    onPressed: () => _uploadFile(
                      field: 'audio',
                      folder: 'publications/audio',
                      controller: _audio,
                      type: FileType.custom,
                      allowedExtensions: ['mp3', 'm4a', 'aac', 'wav', 'ogg'],
                    ),
                  ),
                ),
              ],
              if (_mainMediaType == 'video') ...[
                TextField(
                  controller: _video,
                  decoration: const InputDecoration(labelText: 'Video URL'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _uploadButton(
                    field: 'video',
                    icon: Icons.video_library_outlined,
                    label: 'Upload video',
                    onPressed: _uploadVideo,
                  ),
                ),
              ],
              if (_mainMediaType == 'document') ...[
                TextField(
                  controller: _document,
                  decoration: const InputDecoration(labelText: 'Documento URL'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _uploadButton(
                    field: 'document',
                    icon: Icons.description_outlined,
                    label: 'Upload documento',
                    onPressed: () => _uploadFile(
                      field: 'document',
                      folder: 'publications/documents',
                      controller: _document,
                      type: FileType.custom,
                      allowedExtensions: [
                        'pdf',
                        'doc',
                        'docx',
                        'ppt',
                        'pptx',
                        'xls',
                        'xlsx',
                        'txt',
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _live,
                      decoration: const InputDecoration(labelText: 'Live URL'),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _external,
                      decoration:
                          const InputDecoration(labelText: 'Link externo'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ChoiceChip(
                    label: Text(_scheduledAt == null
                        ? 'Sem agendamento'
                        : 'Agendada: ${_dateLabel(_scheduledAt!)}'),
                    selected: _scheduledAt != null,
                    onSelected: (_) => _pickScheduledAt(),
                  ),
                  ChoiceChip(
                    label: Text(_expiresAt == null
                        ? 'Sem validade'
                        : 'Expira: ${_dateLabel(_expiresAt!)}'),
                    selected: _expiresAt != null,
                    onSelected: (_) => _pickExpiresAt(),
                  ),
                  ChoiceChip(
                    label: const Text('Destaque'),
                    selected: _featured,
                    onSelected: (value) => setState(() => _featured = value),
                  ),
                  ChoiceChip(
                    label: const Text('Fixar'),
                    selected: _pinned,
                    onSelected: (value) => setState(() => _pinned = value),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _sendNotification,
                title: const Text('Notificar membros no sino interno'),
                onChanged: (value) => setState(() => _sendNotification = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _allowComments,
                title: const Text('Permitir comentarios'),
                onChanged: (value) => setState(() => _allowComments = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _allowReactions,
                title: const Text('Permitir reacoes'),
                onChanged: (value) => setState(() => _allowReactions = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _allowSharing,
                title: const Text('Permitir partilha'),
                onChanged: (value) => setState(() => _allowSharing = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => _save('draft'),
          child: const Text('Guardar rascunho'),
        ),
        TextButton(
          onPressed: () => _save('scheduled'),
          child: const Text('Agendar'),
        ),
        FilledButton(
          onPressed: () => _save('published'),
          child: const Text('Publicar'),
        ),
      ],
    );
  }
}

class _PublicationPreview extends StatelessWidget {
  const _PublicationPreview({required this.publication});

  final PastoralPublication publication;

  @override
  Widget build(BuildContext context) {
    final videoUrl = publication.videoUrl?.trim();
    final audioUrl = publication.audioUrl?.trim();
    final documentUrl = publication.documentUrl?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (videoUrl != null && videoUrl.isNotEmpty) ...[
          NativeAutoMedia(
            url: videoUrl,
            kind: NativeAutoMediaKind.video,
            height: 280,
            viewKey: 'publication-preview-video-${publication.id}',
          ),
          const SizedBox(height: 12),
        ] else if (audioUrl != null && audioUrl.isNotEmpty) ...[
          NativeAutoMedia(
            url: audioUrl,
            kind: NativeAutoMediaKind.audio,
            height: 120,
            viewKey: 'publication-preview-audio-${publication.id}',
          ),
          const SizedBox(height: 12),
        ] else if (publication.coverImageUrl != null &&
            publication.coverImageUrl!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 240,
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Image.network(
                publication.coverImageUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        const SizedBox(height: 12),
        _PublicationTypeBadge(
          label: publication.typeLabel,
          icon: _iconForPublicationType(publication.publicationType),
        ),
        if (publication.summary != null) ...[
          const SizedBox(height: 8),
          Text(publication.summary!),
        ],
        const SizedBox(height: 12),
        Text(publication.content),
        if (publication.hasMedia) ...[
          const SizedBox(height: 16),
          const Text('Multimedia e anexos'),
          if (documentUrl != null && documentUrl.isNotEmpty)
            TextButton.icon(
              onPressed: null,
              icon: const Icon(Icons.description_outlined),
              label: Text(documentUrl),
            ),
          if (publication.liveStreamUrl != null)
            Text('Live: ${publication.liveStreamUrl}'),
          if (publication.externalUrl != null)
            Text('Link: ${publication.externalUrl}'),
        ],
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return WorkspaceSectionCard(
      title: 'Nao foi possivel carregar',
      subtitle: 'Confirma se as migrations de publicacoes foram aplicadas.',
      child: Text(message),
    );
  }
}

Future<DateTime?> _pickDate(BuildContext context, DateTime initial) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.now().subtract(const Duration(days: 1)),
    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
  );
  if (date == null || !context.mounted) {
    return null;
  }
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) {
    return date;
  }
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

String _dateLabel(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/${value.year} $hour:$minute';
}

class _PublicationTypeOption {
  const _PublicationTypeOption({
    required this.value,
    required this.label,
    required this.pluralLabel,
    required this.icon,
  });

  final String value;
  final String label;
  final String pluralLabel;
  final IconData icon;
}

const _publicationTypes = <_PublicationTypeOption>[
  _PublicationTypeOption(
    value: 'sermon',
    label: 'Pregacao',
    pluralLabel: 'Pregacoes',
    icon: Icons.record_voice_over_outlined,
  ),
  _PublicationTypeOption(
    value: 'devotional',
    label: 'Devocional',
    pluralLabel: 'Devocionais',
    icon: Icons.wb_sunny_outlined,
  ),
  _PublicationTypeOption(
    value: 'bible_study',
    label: 'Estudo biblico',
    pluralLabel: 'Estudos biblicos',
    icon: Icons.menu_book_outlined,
  ),
  _PublicationTypeOption(
    value: 'pastoral_message',
    label: 'Palavra pastoral',
    pluralLabel: 'Palavras pastorais',
    icon: Icons.volunteer_activism_outlined,
  ),
  _PublicationTypeOption(
    value: 'urgent_notice',
    label: 'Aviso urgente',
    pluralLabel: 'Avisos urgentes',
    icon: Icons.priority_high_outlined,
  ),
  _PublicationTypeOption(
    value: 'video',
    label: 'Video',
    pluralLabel: 'Videos',
    icon: Icons.play_circle_outline,
  ),
  _PublicationTypeOption(
    value: 'audio',
    label: 'Audio',
    pluralLabel: 'Audios',
    icon: Icons.headphones_outlined,
  ),
  _PublicationTypeOption(
    value: 'document',
    label: 'Documento',
    pluralLabel: 'Documentos',
    icon: Icons.description_outlined,
  ),
  _PublicationTypeOption(
    value: 'live_stream',
    label: 'Transmissao ao vivo',
    pluralLabel: 'Transmissoes ao vivo',
    icon: Icons.live_tv_outlined,
  ),
  _PublicationTypeOption(
    value: 'announcement',
    label: 'Comunicado',
    pluralLabel: 'Comunicados',
    icon: Icons.campaign_outlined,
  ),
  _PublicationTypeOption(
    value: 'leadership_message',
    label: 'Mensagem da lideranca',
    pluralLabel: 'Mensagens da lideranca',
    icon: Icons.groups_2_outlined,
  ),
  _PublicationTypeOption(
    value: 'testimony',
    label: 'Testemunho',
    pluralLabel: 'Testemunhos',
    icon: Icons.favorite_border,
  ),
];
