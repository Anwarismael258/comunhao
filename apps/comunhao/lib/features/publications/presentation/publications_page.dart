import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../church/models/church_branding.dart';

class PublicationsPage extends StatefulWidget {
  const PublicationsPage({
    required this.church,
    this.repository,
    super.key,
  });

  final ChurchBranding church;
  final PublicationRepository? repository;

  @override
  State<PublicationsPage> createState() => _PublicationsPageState();
}

class _PublicationsPageState extends State<PublicationsPage> {
  late final PublicationRepository _repository;
  late Future<List<PastoralPublication>> _future;
  String _type = 'all';
  bool _savedOnly = false;
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PublicationRepository();
    _future = _load();
  }

  Future<List<PastoralPublication>> _load() {
    return _repository.fetchMemberFeed(
      widget.church.id,
      type: _type == 'all' ? null : _type,
      savedOnly: _savedOnly,
      unreadOnly: _unreadOnly,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _open(PastoralPublication publication) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicationDetailPage(
          publicationId: publication.id,
          initialPublication: publication,
          repository: _repository,
          churchName: widget.church.name,
          churchLogoUrl: widget.church.logoUrl,
        ),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PastoralPublication>>(
      future: _future,
      builder: (context, snapshot) {
        final publications = snapshot.data ?? const <PastoralPublication>[];
        final featuredItems = publications.where((item) => item.isFeatured);
        final featured = featuredItems.isEmpty ? null : featuredItems.first;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (featured != null) ...[
                _FeaturedPublicationCard(
                  publication: featured,
                  onTap: () => _open(featured),
                ),
                const SizedBox(height: 16),
              ],
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Todas')),
                        DropdownMenuItem(
                            value: 'sermon', child: Text('Pregacoes')),
                        DropdownMenuItem(
                            value: 'devotional', child: Text('Devocionais')),
                        DropdownMenuItem(
                            value: 'bible_study',
                            child: Text('Estudos biblicos')),
                        DropdownMenuItem(
                            value: 'pastoral_message',
                            child: Text('Palavra pastoral')),
                        DropdownMenuItem(value: 'video', child: Text('Videos')),
                        DropdownMenuItem(value: 'audio', child: Text('Audios')),
                        DropdownMenuItem(
                            value: 'document', child: Text('Documentos')),
                        DropdownMenuItem(
                            value: 'live_stream', child: Text('Transmissoes')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _type = value ?? 'all';
                          _future = _load();
                        });
                      },
                    ),
                  ),
                  FilterChip(
                    label: const Text('Guardados'),
                    selected: _savedOnly,
                    onSelected: (value) {
                      setState(() {
                        _savedOnly = value;
                        _future = _load();
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('Nao lidos'),
                    selected: _unreadOnly,
                    onSelected: (value) {
                      setState(() {
                        _unreadOnly = value;
                        _future = _load();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (snapshot.hasError)
                _MessagePanel(
                  title: 'Nao foi possivel carregar',
                  message: snapshot.error.toString(),
                )
              else if (publications.isEmpty)
                const _MessagePanel(
                  title: 'Sem publicacoes',
                  message:
                      'Quando a igreja publicar mensagens, pregacoes e estudos, aparecem aqui.',
                )
              else
                ...publications.map(
                  (publication) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PublicationCard(
                      publication: publication,
                      onTap: () => _open(publication),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class PublicationDetailPage extends StatefulWidget {
  const PublicationDetailPage({
    required this.publicationId,
    required this.initialPublication,
    required this.repository,
    required this.churchName,
    this.churchLogoUrl,
    this.openComments = false,
    super.key,
  });

  final String publicationId;
  final PastoralPublication initialPublication;
  final PublicationRepository repository;
  final String churchName;
  final String? churchLogoUrl;
  final bool openComments;

  @override
  State<PublicationDetailPage> createState() => _PublicationDetailPageState();
}

class _PublicationReactionOption {
  const _PublicationReactionOption({
    required this.key,
    required this.label,
  });

  final String key;
  final String label;
}

const _publicationReactionOptions = <_PublicationReactionOption>[
  _PublicationReactionOption(key: 'amen', label: '🙏 Amém'),
  _PublicationReactionOption(key: 'praying', label: 'Estou orando'),
  _PublicationReactionOption(key: 'glory', label: 'Glória a Deus'),
  _PublicationReactionOption(key: 'built', label: 'Fui edificado'),
  _PublicationReactionOption(key: 'faithful', label: 'Deus é fiel'),
];

String _publicationReactionLabel(String reaction) {
  return _publicationReactionOptions
      .firstWhere(
        (option) => option.key == reaction,
        orElse: () => _publicationReactionOptions.first,
      )
      .label;
}

class _PublicationDetailPageState extends State<PublicationDetailPage> {
  late PastoralPublication _publication;
  late Future<List<PastoralPublicationComment>> _commentsFuture;
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  final _commentsKey = GlobalKey();
  bool _busy = false;
  bool _readRecorded = false;

  @override
  void initState() {
    super.initState();
    _publication = widget.initialPublication;
    _commentsFuture = widget.repository.fetchComments(widget.publicationId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordRead();
      if (widget.openComments) {
        _scrollToComments();
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToComments() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    final context = _commentsKey.currentContext;
    if (context != null) {
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _recordRead() async {
    if (_readRecorded) {
      return;
    }
    _readRecorded = true;
    try {
      await widget.repository.recordRead(widget.publicationId);
      if (mounted) {
        setState(() {
          _publication = _publication.copyWith(isRead: true);
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleSaved() async {
    setState(() => _busy = true);
    try {
      final next = !_publication.isSaved;
      await widget.repository.setSaved(widget.publicationId, next);
      if (mounted) {
        setState(() {
          _publication = _publication.copyWith(isSaved: next);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _react([String reaction = 'amen']) async {
    setState(() => _busy = true);
    try {
      await widget.repository.react(widget.publicationId, reaction);
      await HapticFeedback.selectionClick();
      if (mounted) {
        setState(() {
          _publication = _publication.copyWith(myReaction: reaction);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_publicationReactionLabel(reaction))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _comment() async {
    final body = _commentController.text.trim();
    if (body.length < 2) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repository.comment(
        publicationId: widget.publicationId,
        body: body,
      );
      _commentController.clear();
      await HapticFeedback.lightImpact();
      if (mounted) {
        setState(() {
          _commentsFuture =
              widget.repository.fetchComments(widget.publicationId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comentario publicado.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_publication.typeLabel),
        actions: [
          IconButton(
            tooltip: _publication.isSaved ? 'Remover dos guardados' : 'Guardar',
            onPressed: _busy ? null : _toggleSaved,
            icon: Icon(
              _publication.isSaved ? Icons.bookmark : Icons.bookmark_border,
            ),
          ),
          if (_publication.allowSharing)
            IconButton(
              tooltip: 'Partilhar',
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: _publication.title),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Referencia copiada.')),
                  );
                }
              },
              icon: const Icon(Icons.share_outlined),
            ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          if (_publication.coverImageUrl != null &&
              _publication.coverImageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _publication.coverImageUrl!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            _publication.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(_publication.typeLabel)),
              if (!_publication.isRead) const Chip(label: Text('Nao lida')),
              if (_publication.hasMedia) const Chip(label: Text('Multimedia')),
            ],
          ),
          if (_publication.summary != null &&
              _publication.summary!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _publication.summary!,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
          const SizedBox(height: 16),
          Text(_publication.content),
          if (_publication.hasMedia) ...[
            const SizedBox(height: 20),
            _MediaLinks(publication: _publication),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (_publication.allowReactions)
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _react,
                  icon: const Text('🙏', style: TextStyle(fontSize: 18)),
                  label: Text(
                    _publication.myReaction == null ? 'Amen' : 'Amen marcado',
                  ),
                ),
            ],
          ),
          if (_publication.allowReactions) ...[
            const SizedBox(height: 8),
            PopupMenuButton<String>(
              enabled: !_busy,
              onSelected: _react,
              itemBuilder: (context) => _publicationReactionOptions
                  .where((option) => option.key != 'amen')
                  .map(
                    (option) => PopupMenuItem(
                      value: option.key,
                      child: Text(option.label),
                    ),
                  )
                  .toList(),
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.add_reaction_outlined),
                label: const Text('Mais reações'),
              ),
            ),
          ],
          if (_publication.allowComments) ...[
            const SizedBox(height: 24),
            Text(
              key: _commentsKey,
              'Comentarios',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              minLines: 2,
              maxLines: 4,
              decoration:
                  const InputDecoration(labelText: 'Escrever comentario'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _busy ? null : _comment,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Comentar'),
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<PastoralPublicationComment>>(
              future: _commentsFuture,
              builder: (context, snapshot) {
                final comments =
                    snapshot.data ?? const <PastoralPublicationComment>[];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (comments.isEmpty) {
                  return const Text('Ainda sem comentarios.');
                }
                return Column(
                  children: comments.map(
                    (comment) {
                      final isChurchComment =
                          comment.profileId == _publication.authorUserId;
                      return _PublicationCommentTile(
                        authorName: isChurchComment
                            ? widget.churchName
                            : comment.authorName ?? 'Membro',
                        avatarUrl: isChurchComment
                            ? widget.churchLogoUrl ?? comment.authorAvatarUrl
                            : comment.authorAvatarUrl,
                        body: comment.body,
                        createdAt: comment.createdAt,
                      );
                    },
                  ).toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _PublicationCommentTile extends StatelessWidget {
  const _PublicationCommentTile({
    required this.authorName,
    required this.body,
    required this.createdAt,
    this.avatarUrl,
  });

  final String authorName;
  final String body;
  final DateTime createdAt;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = avatarUrl?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExpandableProfileAvatar(
            avatarUrl: imageUrl,
            label: authorName,
            radius: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            authorName,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        Text(
                          DateFormat('dd/MM HH:mm').format(createdAt.toLocal()),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(body),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedPublicationCard extends StatelessWidget {
  const _FeaturedPublicationCard({
    required this.publication,
    required this.onTap,
  });

  final PastoralPublication publication;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.star_outline),
              const SizedBox(height: 8),
              Text(
                publication.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (publication.summary != null) ...[
                const SizedBox(height: 8),
                Text(publication.summary!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicationCard extends StatelessWidget {
  const _PublicationCard({
    required this.publication,
    required this.onTap,
  });

  final PastoralPublication publication;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final authorAvatarUrl = publication.authorAvatarUrl?.trim();
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: ExpandableProfileAvatar(
          avatarUrl: authorAvatarUrl,
          label: publication.authorName ?? 'Igreja',
          fallbackIcon: _iconFor(publication.publicationType),
        ),
        title: Text(publication.title),
        subtitle: Text(
          '${publication.typeLabel}${publication.summary == null ? '' : '\n${publication.summary}'}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!publication.isRead)
              const Icon(Icons.markunread_outlined, size: 18),
            if (publication.isSaved) const Icon(Icons.bookmark, size: 18),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    return switch (type) {
      'sermon' => Icons.record_voice_over_outlined,
      'devotional' => Icons.wb_sunny_outlined,
      'bible_study' => Icons.menu_book_outlined,
      'video' => Icons.play_circle_outline,
      'audio' => Icons.headphones_outlined,
      'document' => Icons.description_outlined,
      'live_stream' => Icons.live_tv_outlined,
      'urgent_notice' => Icons.priority_high_outlined,
      _ => Icons.article_outlined,
    };
  }
}

class _MediaLinks extends StatelessWidget {
  const _MediaLinks({required this.publication});

  final PastoralPublication publication;

  Future<void> _open(BuildContext context, String? rawUrl) async {
    final url = rawUrl?.trim();
    if (url == null || url.isEmpty) return;
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nao foi possivel abrir esta midia.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actions = <Widget>[
      if (publication.videoUrl != null && publication.videoUrl!.isNotEmpty)
        _MediaActionButton(
          icon: Icons.play_circle_fill,
          title: 'Assistir video',
          subtitle: 'Abrir o video publicado pela igreja',
          onTap: () => _open(context, publication.videoUrl),
        ),
      if (publication.audioUrl != null && publication.audioUrl!.isNotEmpty)
        _MediaActionButton(
          icon: Icons.headphones,
          title: 'Ouvir audio',
          subtitle: 'Abrir o louvor ou mensagem em audio',
          onTap: () => _open(context, publication.audioUrl),
        ),
      if (publication.documentUrl != null &&
          publication.documentUrl!.isNotEmpty)
        _MediaActionButton(
          icon: Icons.description_outlined,
          title: 'Abrir documento',
          subtitle: 'Consultar o anexo da publicacao',
          onTap: () => _open(context, publication.documentUrl),
        ),
      if (publication.liveStreamUrl != null &&
          publication.liveStreamUrl!.isNotEmpty)
        _MediaActionButton(
          icon: Icons.live_tv_outlined,
          title: 'Assistir transmissao',
          subtitle: 'Abrir a transmissao ao vivo',
          onTap: () => _open(context, publication.liveStreamUrl),
        ),
      if (publication.externalUrl != null &&
          publication.externalUrl!.isNotEmpty)
        _MediaActionButton(
          icon: Icons.link_outlined,
          title: 'Abrir link',
          subtitle: 'Abrir conteudo externo',
          onTap: () => _open(context, publication.externalUrl),
        ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Midia da publicacao', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _MediaActionButton extends StatelessWidget {
  const _MediaActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.open_in_new),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
      ),
    );
  }
}
