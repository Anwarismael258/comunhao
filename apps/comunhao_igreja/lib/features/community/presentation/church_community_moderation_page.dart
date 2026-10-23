import 'dart:async';

import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../publications/presentation/church_publications_page.dart';
import '../../publications/presentation/native_auto_media_stub.dart'
    if (dart.library.html) '../../publications/presentation/native_auto_media_web.dart';

class ChurchCommunityModerationPage extends StatefulWidget {
  const ChurchCommunityModerationPage({
    required this.church,
    required this.readOnly,
    this.members = const [],
    this.announcements = const [],
    this.events = const [],
    this.campaigns = const [],
    this.publications = const [],
    this.prayerRequests = const [],
    this.repository,
    super.key,
  });

  final ManagedChurch church;
  final bool readOnly;
  final List<ManagedMember> members;
  final List<ManagedAnnouncement> announcements;
  final List<ManagedEvent> events;
  final List<ManagedCampaign> campaigns;
  final List<PastoralPublication> publications;
  final List<ManagedPrayerRequest> prayerRequests;
  final CommunityFeedRepository? repository;

  @override
  State<ChurchCommunityModerationPage> createState() =>
      _ChurchCommunityModerationPageState();
}

class _ChurchCommunityModerationPageState
    extends State<ChurchCommunityModerationPage> {
  late final CommunityFeedRepository _repository;
  late Future<List<CommunityPost>> _future;
  RealtimeChannel? _channel;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CommunityFeedRepository();
    _future = _load();
    _configureRealtime();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    final channel = _channel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChurchCommunityModerationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.church.id != widget.church.id) {
      _configureRealtime();
      _scheduleRefresh();
    }
  }

  Future<List<CommunityPost>> _load() {
    return _repository.fetchModerationQueue(widget.church.id);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _future = _load());
    });
  }

  void _configureRealtime() {
    final existing = _channel;
    if (existing != null) {
      Supabase.instance.client.removeChannel(existing);
    }
    final channel = Supabase.instance.client
        .channel('pastor-community-feed-${widget.church.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'community_posts',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'church_id',
          value: widget.church.id,
        ),
        callback: (_) => _scheduleRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'community_post_comments',
        callback: (_) => _scheduleRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'community_post_reactions',
        callback: (_) => _scheduleRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'community_comment_reactions',
        callback: (_) => _scheduleRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'community_post_reports',
        callback: (_) => _scheduleRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'community_post_shares',
        callback: (_) => _scheduleRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'pastoral_publications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'church_id',
          value: widget.church.id,
        ),
        callback: (_) => _scheduleRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'pastoral_publication_comments',
        callback: (_) => _scheduleRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'pastoral_publication_reactions',
        callback: (_) => _scheduleRefresh(),
      );
    channel.subscribe();
    _channel = channel;
  }

  Future<bool> _postMatches(
    String postId,
    bool Function(CommunityPost? post) matches,
  ) async {
    try {
      final posts = await _load();
      for (final post in posts) {
        if (post.id == postId) return matches(post);
      }
      return matches(null);
    } catch (_) {
      return false;
    }
  }

  Future<void> _archive(CommunityPost post) async {
    if (widget.readOnly) {
      _message('A igreja esta em modo leitura.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ocultar publicacao'),
        content: Text(
          'Pretendes ocultar "${post.title}" do Feed da Comunhao?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ocultar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.moderatePost(
        postId: post.id,
        status: 'archived',
        note: 'Ocultada pelo pastor no painel do Feed da Comunhao.',
      );
      _scheduleRefresh();
      _message('Publicacao ocultada do feed.');
    } catch (_) {
      final archived = await _postMatches(post.id, (saved) => saved == null);
      if (archived) {
        _scheduleRefresh();
        _message('Publicacao ocultada do feed.');
        return;
      }
      _message('Nao foi possivel ocultar agora.');
    }
  }

  Future<void> _togglePinned(CommunityPost post) async {
    if (widget.readOnly) {
      _message('A igreja esta em modo leitura.');
      return;
    }
    final shouldPin = post.pinnedAt == null;
    try {
      await _repository.setPinned(
        postId: post.id,
        pinned: shouldPin,
      );
      _scheduleRefresh();
      _message(shouldPin
          ? 'Publicacao fixada no topo.'
          : 'Publicacao removida do topo.');
    } catch (_) {
      final persisted = await _postMatches(
        post.id,
        (saved) => shouldPin
            ? saved?.pinnedAt != null
            : saved != null && saved.pinnedAt == null,
      );
      if (persisted) {
        _scheduleRefresh();
        _message(shouldPin
            ? 'Publicacao fixada no topo.'
            : 'Publicacao removida do topo.');
        return;
      }
      _message('Nao foi possivel atualizar o destaque.');
    }
  }

  Future<void> _toggleComments(CommunityPost post) async {
    if (widget.readOnly) {
      _message('A igreja esta em modo leitura.');
      return;
    }
    final shouldEnable = !post.commentsEnabled;
    try {
      await _repository.setCommentsEnabled(
        postId: post.id,
        enabled: shouldEnable,
      );
      _scheduleRefresh();
      _message(shouldEnable
          ? 'Comentarios reativados.'
          : 'Comentarios desativados.');
    } catch (_) {
      final persisted = await _postMatches(
        post.id,
        (saved) => saved?.commentsEnabled == shouldEnable,
      );
      if (persisted) {
        _scheduleRefresh();
        _message(shouldEnable
            ? 'Comentarios reativados.'
            : 'Comentarios desativados.');
        return;
      }
      _message('Nao foi possivel atualizar os comentarios.');
    }
  }

  Future<void> _warnAuthor(CommunityPost post, {required bool suspend}) async {
    if (widget.readOnly) {
      _message('A igreja esta em modo leitura.');
      return;
    }
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(suspend ? 'Suspender membro' : 'Advertir membro'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Nota pastoral'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(suspend ? 'Suspender' : 'Advertir'),
          ),
        ],
      ),
    );
    final note = controller.text.trim();
    controller.dispose();
    if (confirmed != true) return;
    try {
      await _repository.warnAuthor(
        postId: post.id,
        note: note.isEmpty ? null : note,
        suspend: suspend,
      );
      _scheduleRefresh();
      _message(suspend ? 'Membro suspenso.' : 'Advertencia registada.');
    } catch (_) {
      _message('Nao foi possivel registar esta acao.');
    }
  }

  Future<void> _react(CommunityPost post, String reaction) async {
    try {
      await _repository.react(postId: post.id, reactionType: reaction);
      _scheduleRefresh();
      _message(_reactionConfirmation(reaction));
    } catch (_) {
      _message('N\u00e3o foi poss\u00edvel reagir agora.');
    }
  }

  Future<void> _comment(CommunityPost post, String body) async {
    try {
      await _repository.comment(postId: post.id, body: body);
      _scheduleRefresh();
      _message('Coment\u00e1rio publicado.');
    } catch (_) {
      _message('N\u00e3o foi poss\u00edvel comentar agora.');
    }
  }

  Future<void> _replyToComment(
      CommunityPost post, CommunityComment comment) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Responder a ${comment.authorName ?? 'membro'}'),
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
    if (text == null || text.trim().length < 2) return;
    try {
      await _repository.comment(
        postId: post.id,
        body: text.trim(),
        parentCommentId: comment.id,
      );
      _scheduleRefresh();
      _message('Resposta publicada.');
    } catch (_) {
      _message('Nao foi possivel responder agora.');
    }
  }

  Future<void> _reactToComment(CommunityComment comment) async {
    try {
      await _repository.reactToComment(commentId: comment.id);
      _message('Am\u00e9m no coment\u00e1rio registado.');
    } catch (_) {
      _message('N\u00e3o foi poss\u00edvel reagir ao coment\u00e1rio agora.');
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  ManagedMember? _memberForProfile(String profileId) {
    for (final member in widget.members) {
      if (member.profileId == profileId) return member;
    }
    return null;
  }

  void _openMemberProfile(String profileId, {String? fallbackName}) {
    final member = _memberForProfile(profileId);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(member?.fullName ?? fallbackName ?? 'Membro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileLine(label: 'Funcao', value: member?.roleLabel ?? 'Membro'),
            _ProfileLine(
                label: 'Estado', value: member?.statusLabel ?? 'Ativo'),
            if (member?.phone?.trim().isNotEmpty == true)
              _ProfileLine(label: 'Telefone', value: member!.phone!),
            if (member?.neighborhood?.trim().isNotEmpty == true)
              _ProfileLine(label: 'Bairro', value: member!.neighborhood!),
            if (member?.entryDate != null)
              _ProfileLine(
                label: 'Entrada',
                value: _dateLabel(member!.entryDate!),
              ),
            if (member?.lastActivityAt != null)
              _ProfileLine(
                label: 'Ultima atividade',
                value: _dateLabel(member!.lastActivityAt!),
              ),
          ],
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CommunityPost>>(
      future: _future,
      builder: (context, snapshot) {
        final posts = [...(snapshot.data ?? const <CommunityPost>[])]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final churchItems = _buildChurchFeedItems();
        final feedEntries = <_PastorFeedEntry>[
          ...churchItems.map(
            (item) => _PastorFeedEntry(
              createdAt: item.createdAt,
              child: _ChurchFeedItemTile(
                item: item,
                church: widget.church,
                readOnly: widget.readOnly,
                onChanged: _refresh,
                onMessage: _message,
              ),
            ),
          ),
          ...posts.map(
            (post) => _PastorFeedEntry(
              createdAt: post.createdAt,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ModerationCard(
                  post: post,
                  repository: _repository,
                  readOnly: widget.readOnly,
                  onReact: (reaction) => _react(post, reaction),
                  onComment: (body) => _comment(post, body),
                  onReactToComment: _reactToComment,
                  onReplyToComment: (comment) => _replyToComment(post, comment),
                  onOpenProfile: _openMemberProfile,
                  onArchive: () => _archive(post),
                  onTogglePinned: () => _togglePinned(post),
                  onToggleComments: () => _toggleComments(post),
                  onWarn: () => _warnAuthor(post, suspend: false),
                  onSuspend: () => _warnAuthor(post, suspend: true),
                ),
              ),
            ),
          ),
        ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final visibleEntries = feedEntries.take(30).toList(growable: false);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.diversity_3_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Feed Comunh\u00e3o',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '${visibleEntries.length}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              if (snapshot.connectionState != ConnectionState.done)
                const Center(child: CircularProgressIndicator())
              else if (feedEntries.isEmpty)
                const WorkspaceSectionCard(
                  title: 'Sem publicacoes recentes',
                  subtitle:
                      'Quando a igreja ou um membro publicar algo, aparece aqui automaticamente.',
                  child: Text('Nada publicado neste momento.'),
                )
              else
                ...visibleEntries.map((entry) => entry.child),
            ],
          ),
        );
      },
    );
  }

  List<_ChurchFeedItem> _buildChurchFeedItems() {
    final churchLogoUrl = widget.church.logoUrl;
    final publicationsById = {
      for (final publication in widget.publications)
        publication.id: publication,
    };
    final mirroredPublicationIds = <String>{
      ...widget.announcements
          .map((item) => item.pastoralPublicationId)
          .whereType<String>(),
      ...widget.events
          .map((item) => item.pastoralPublicationId)
          .whereType<String>(),
      ...widget.campaigns
          .map((item) => item.pastoralPublicationId)
          .whereType<String>(),
    };
    final items = <_ChurchFeedItem>[
      ...widget.publications.where((publication) {
        return !mirroredPublicationIds.contains(publication.id);
      }).map(
        (publication) => _ChurchFeedItem(
          id: 'publication-${publication.id}',
          publication: publication,
          title: publication.title,
          body: publication.summary?.trim().isNotEmpty == true
              ? publication.summary!.trim()
              : publication.content,
          label: publication.typeLabel,
          status: publication.statusLabel,
          icon: _publicationIcon(publication.publicationType),
          createdAt: publication.createdAt,
          imageUrl: publication.coverImageUrl,
          authorAvatarUrl: publication.authorAvatarUrl ?? churchLogoUrl,
        ),
      ),
      ...widget.prayerRequests
          .where(
            (request) =>
                request.visibility == 'public' ||
                request.visibility == 'anonymous' ||
                !request.isPrivate,
          )
          .map(
            (request) => _ChurchFeedItem(
              id: 'prayer-${request.id}',
              title: request.title,
              body: [
                request.requesterLabel,
                request.visibilityLabel,
                request.description,
              ].where((line) => line.trim().isNotEmpty).join('\n'),
              label: 'Pedido de oracao',
              status: request.statusLabel,
              icon: Icons.volunteer_activism_outlined,
              createdAt: request.createdAt,
            ),
          ),
      ...widget.announcements.map(
        (announcement) => _ChurchFeedItem(
          id: 'announcement-${announcement.id}',
          publication: publicationsById[announcement.pastoralPublicationId],
          title: announcement.title,
          body: announcement.body,
          label: announcement.pinned ? 'Anuncio fixado' : 'Anuncio',
          status: announcement.isPublished ? 'Publicado' : 'Rascunho',
          icon: announcement.pinned
              ? Icons.push_pin_outlined
              : Icons.campaign_outlined,
          createdAt: announcement.createdAt,
          imageUrl: announcement.imageUrl,
          authorAvatarUrl: churchLogoUrl,
        ),
      ),
      ...widget.events.map(
        (event) => _ChurchFeedItem(
          id: 'event-${event.id}',
          publication: publicationsById[event.pastoralPublicationId],
          title: event.title,
          body: [
            event.eventTypeLabel,
            'Marcado para ${_dateLabel(event.startsAt)}',
            if (event.location?.trim().isNotEmpty == true) event.location!,
            if (event.description?.trim().isNotEmpty == true)
              event.description!,
          ].join('\n'),
          label: event.eventTypeLabel,
          status: event.statusLabel,
          icon: Icons.event_available_outlined,
          createdAt: event.createdAt,
          imageUrl: event.coverImageUrl,
          authorAvatarUrl: churchLogoUrl,
        ),
      ),
      ...widget.campaigns.map(
        (campaign) => _ChurchFeedItem(
          id: 'campaign-${campaign.id}',
          publication: publicationsById[campaign.pastoralPublicationId],
          title: campaign.title,
          body: [
            if (campaign.description?.trim().isNotEmpty == true)
              campaign.description!,
            '${campaign.progressPercent}% arrecadado',
            if (campaign.targetAmount != null) 'Meta: ${campaign.targetAmount}',
          ].join('\n'),
          label: 'Campanha',
          status: campaign.statusLabel,
          icon: Icons.volunteer_activism_outlined,
          createdAt: campaign.createdAt,
          imageUrl: campaign.imageUrl,
          authorAvatarUrl: churchLogoUrl,
        ),
      ),
    ];
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  static IconData _publicationIcon(String type) => switch (type) {
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

class _PastorFeedEntry {
  const _PastorFeedEntry({
    required this.createdAt,
    required this.child,
  });

  final DateTime createdAt;
  final Widget child;
}

class _ChurchFeedItem {
  const _ChurchFeedItem({
    required this.id,
    required this.title,
    required this.body,
    required this.label,
    required this.status,
    required this.icon,
    required this.createdAt,
    this.publication,
    this.imageUrl,
    this.authorAvatarUrl,
  });

  final String id;
  final String title;
  final String body;
  final String label;
  final String status;
  final IconData icon;
  final DateTime createdAt;
  final PastoralPublication? publication;
  final String? imageUrl;
  final String? authorAvatarUrl;
}

class _ChurchFeedItemTile extends StatelessWidget {
  const _ChurchFeedItemTile({
    required this.item,
    required this.church,
    required this.readOnly,
    required this.onChanged,
    required this.onMessage,
  });

  final _ChurchFeedItem item;
  final ManagedChurch church;
  final bool readOnly;
  final Future<void> Function() onChanged;
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl?.trim();
    final videoUrl = item.publication?.videoUrl?.trim();
    final audioUrl = item.publication?.audioUrl?.trim();
    final documentUrl = item.publication?.documentUrl?.trim();
    final authorAvatarUrl = item.authorAvatarUrl?.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (videoUrl != null && videoUrl.isNotEmpty) ...[
            NativeAutoMedia(
              url: videoUrl,
              kind: NativeAutoMediaKind.video,
              height: 220,
              viewKey: 'church-feed-video-${item.id}',
            ),
            const SizedBox(height: 8),
          ] else if (audioUrl != null && audioUrl.isNotEmpty) ...[
            NativeAutoMedia(
              url: audioUrl,
              kind: NativeAutoMediaKind.audio,
              height: 120,
              viewKey: 'church-feed-audio-${item.id}',
            ),
            const SizedBox(height: 8),
          ] else if (imageUrl != null && imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 170,
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (documentUrl != null && documentUrl.isNotEmpty) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: const Text('Documento anexado'),
              subtitle: Text(
                documentUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExpandableProfileAvatar(
                  avatarUrl: authorAvatarUrl,
                  label: item.title,
                  fallbackIcon: item.icon,
                  radius: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _PastorFeedTypeBadge(
                            label: item.label,
                            icon: item.icon,
                          ),
                          Text(
                            'Publicado ${_dateLabel(item.createdAt)}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.body,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.28,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (item.publication != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: PastoralPublicationSocialPanel(
                publication: item.publication!,
                repository: PublicationRepository(),
                churchName: church.name,
                churchLogoUrl: church.logoUrl,
                readOnly: readOnly,
                onChanged: onChanged,
                onMessage: onMessage,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModerationCard extends StatefulWidget {
  const _ModerationCard({
    required this.post,
    required this.repository,
    required this.readOnly,
    required this.onReact,
    required this.onComment,
    required this.onReactToComment,
    required this.onReplyToComment,
    required this.onOpenProfile,
    required this.onArchive,
    required this.onTogglePinned,
    required this.onToggleComments,
    required this.onWarn,
    required this.onSuspend,
  });

  final CommunityPost post;
  final CommunityFeedRepository repository;
  final bool readOnly;
  final ValueChanged<String> onReact;
  final ValueChanged<String> onComment;
  final ValueChanged<CommunityComment> onReactToComment;
  final ValueChanged<CommunityComment> onReplyToComment;
  final void Function(String profileId, {String? fallbackName}) onOpenProfile;
  final VoidCallback onArchive;
  final VoidCallback onTogglePinned;
  final VoidCallback onToggleComments;
  final VoidCallback onWarn;
  final VoidCallback onSuspend;

  @override
  State<_ModerationCard> createState() => _ModerationCardState();
}

class _PastorFeedTypeBadge extends StatelessWidget {
  const _PastorFeedTypeBadge({
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
        : pastorFeedTypeBadgeColor(label);
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

Color pastorFeedTypeBadgeColor(String label) {
  final normalized = label.toLowerCase();
  if (normalized.contains('culto')) return Colors.indigo.shade700;
  if (normalized.contains('congresso')) return Colors.deepPurple.shade700;
  if (normalized.contains('vigilia') || normalized.contains('vig\u00edlia')) {
    return Colors.blueGrey.shade700;
  }
  if (normalized.contains('batismo')) return Colors.cyan.shade800;
  if (normalized.contains('casamento')) return Colors.pink.shade700;
  if (normalized.contains('conferencia') ||
      normalized.contains('confer\u00eancia')) {
    return Colors.orange.shade800;
  }
  if (normalized.contains('ensaio')) return Colors.teal.shade700;
  if (normalized.contains('reuniao') || normalized.contains('reuni\u00e3o')) {
    return Colors.brown.shade700;
  }
  if (normalized.contains('campanha')) return Colors.green.shade700;
  if (normalized.contains('pregacao') ||
      normalized.contains('prega\u00e7\u00e3o')) {
    return Colors.red.shade700;
  }
  if (normalized.contains('devocional')) return Colors.amber.shade800;
  if (normalized.contains('estudo')) return Colors.lightBlue.shade800;
  if (normalized.contains('palavra pastoral')) return Colors.purple.shade700;
  if (normalized.contains('aviso urgente')) return Colors.deepOrange.shade800;
  if (normalized.contains('video') || normalized.contains('v\u00eddeo')) {
    return Colors.redAccent.shade700;
  }
  if (normalized.contains('audio') || normalized.contains('\u00e1udio')) {
    return Colors.green.shade800;
  }
  if (normalized.contains('documento')) return Colors.blue.shade800;
  if (normalized.contains('transmissao') ||
      normalized.contains('transmiss\u00e3o') ||
      normalized.contains('live')) {
    return Colors.red.shade900;
  }
  if (normalized.contains('comunicado')) return Colors.blueGrey.shade800;
  if (normalized.contains('lideranca') ||
      normalized.contains('lideran\u00e7a')) {
    return Colors.deepPurple.shade600;
  }
  if (normalized.contains('testemunho')) return Colors.lime.shade900;
  if (normalized.contains('oracao') ||
      normalized.contains('ora\u00e7\u00e3o')) {
    return Colors.blue.shade700;
  }
  return Colors.blueGrey.shade700;
}

class _ModerationCardState extends State<_ModerationCard> {
  late Future<List<CommunityComment>> _commentsFuture;
  late Future<List<CommunityReaction>> _reactionsFuture;
  final _commentController = TextEditingController();
  List<CommunityComment>? _comments;

  @override
  void initState() {
    super.initState();
    _commentsFuture = _fetchAndStoreComments();
    _reactionsFuture = widget.repository.fetchReactions(widget.post.id);
  }

  @override
  void didUpdateWidget(covariant _ModerationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.reactionCount != widget.post.reactionCount ||
        oldWidget.post.commentCount != widget.post.commentCount) {
      _comments = null;
      _commentsFuture = _fetchAndStoreComments();
      _reactionsFuture = widget.repository.fetchReactions(widget.post.id);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.length < 2) return;
    final now = DateTime.now();
    final optimistic = CommunityComment(
      id: 'local-${now.microsecondsSinceEpoch}',
      postId: widget.post.id,
      profileId: '',
      authorName: 'Igreja',
      body: text,
      createdAt: now,
    );
    setState(() {
      _comments = [...?_comments, optimistic];
      _commentsFuture = Future<List<CommunityComment>>.value(_comments);
    });
    widget.onComment(text);
    _commentController.clear();
    try {
      final fresh = await widget.repository.fetchComments(widget.post.id);
      if (fresh.isNotEmpty && mounted) {
        setState(() {
          _comments = fresh;
          _commentsFuture = Future<List<CommunityComment>>.value(fresh);
        });
      }
    } catch (_) {
      // Mantem o comentario otimista visivel.
    }
  }

  Future<List<CommunityComment>> _fetchAndStoreComments() async {
    final comments = await widget.repository.fetchComments(widget.post.id);
    if (mounted) _comments = comments;
    return comments;
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final authorAvatarUrl = post.authorAvatarUrl?.trim();
    final visibleCommentCount = [
      post.commentCount,
      _comments?.length ?? 0,
    ].reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ExpandableProfileAvatar(
                avatarUrl: authorAvatarUrl,
                label: post.authorName ?? 'Membro',
                fallbackIcon: _iconFor(post.postType),
              ),
              title: Text(post.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _PastorFeedTypeBadge(
                        label: post.typeLabel,
                        icon: _iconFor(post.postType),
                      ),
                      _PastorFeedTypeBadge(
                        label: post.communitySpaceLabel,
                        icon: Icons.diversity_3_outlined,
                        muted: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Publicado ${_dateLabel(post.createdAt)}'),
                  InkWell(
                    onTap: () => widget.onOpenProfile(
                      post.authorProfileId,
                      fallbackName: post.authorName,
                    ),
                    child: Text(
                      'Autor: ${post.authorName ?? 'Membro'}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.imageUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
            if (post.mediaType == 'video' &&
                post.mediaUrl != null &&
                post.mediaUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              NativeAutoMedia(
                url: post.mediaUrl!,
                kind: NativeAutoMediaKind.video,
                height: 220,
                viewKey: 'pastor-community-video-${post.id}',
              ),
            ],
            if (post.mediaType == 'audio' &&
                post.mediaUrl != null &&
                post.mediaUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              NativeAutoMedia(
                url: post.mediaUrl!,
                kind: NativeAutoMediaKind.audio,
                height: 120,
                viewKey: 'pastor-community-audio-${post.id}',
              ),
            ],
            const SizedBox(height: 8),
            Text(
              post.body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.28,
                  ),
            ),
            const SizedBox(height: 10),
            _PastorFeedStatsRow(
              reactionCount: post.reactionCount,
              commentCount: visibleCommentCount,
              shareCount: post.shareCount,
              reportCount: post.reportCount,
              prayingCount: post.isPrayer ? post.prayingCount : null,
              pinned: post.pinnedAt != null,
              commentsEnabled: post.commentsEnabled,
              onViewReactions: _showReactions,
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: PopupMenuButton<String>(
                    tooltip: 'Reagir',
                    enabled: !widget.readOnly,
                    onSelected: widget.onReact,
                    itemBuilder: (context) => [
                      for (final option in _reactionOptions)
                        PopupMenuItem(
                          value: option.key,
                          child: Text(_reactionLabel(option.key)),
                        ),
                    ],
                    child: _PastorFeedActionButton(
                      icon: Icons.volunteer_activism_outlined,
                      label: post.myReaction == null
                          ? 'Am\u00e9m'
                          : _reactionLabel(post.myReaction!)
                              .replaceFirst('\u{1F64F} ', ''),
                      selected: post.myReaction != null,
                    ),
                  ),
                ),
                const Expanded(
                  child: _PastorFeedActionButton(
                    icon: Icons.chat_bubble_outline,
                    label: 'Comentar',
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Modera\u00e7\u00e3o',
                  enabled: !widget.readOnly,
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (value) {
                    switch (value) {
                      case 'pin':
                        widget.onTogglePinned();
                        break;
                      case 'comments':
                        widget.onToggleComments();
                        break;
                      case 'archive':
                        widget.onArchive();
                        break;
                      case 'warn':
                        widget.onWarn();
                        break;
                      case 'suspend':
                        widget.onSuspend();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'pin',
                      child:
                          Text(post.pinnedAt == null ? 'Fixar' : 'Desafixar'),
                    ),
                    PopupMenuItem(
                      value: 'comments',
                      child: Text(
                        post.commentsEnabled
                            ? 'Desativar coment\u00e1rios'
                            : 'Ativar coment\u00e1rios',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'archive',
                      child: Text('Ocultar'),
                    ),
                    const PopupMenuItem(
                      value: 'warn',
                      child: Text('Advertir'),
                    ),
                    const PopupMenuItem(
                      value: 'suspend',
                      child: Text('Suspender membro'),
                    ),
                  ],
                ),
              ],
            ),
            if (post.commentsEnabled) ...[
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
                  onPressed: widget.readOnly ? null : _submitComment,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Comentar'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            FutureBuilder<List<CommunityReaction>>(
              future: _reactionsFuture,
              builder: (context, snapshot) {
                final reactions = snapshot.data ?? const <CommunityReaction>[];
                if (reactions.isEmpty) return const SizedBox.shrink();
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: reactions.take(6).map((reaction) {
                      return ActionChip(
                        avatar: _ReactionAvatar(reaction: reaction),
                        label: Text(
                          '${_reactionLabel(reaction.reactionType)} ${reaction.authorName ?? 'Membro'}',
                        ),
                        onPressed: () => widget.onOpenProfile(
                          reaction.profileId,
                          fallbackName: reaction.authorName,
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<CommunityComment>>(
              future: _commentsFuture,
              builder: (context, snapshot) {
                final comments =
                    _comments ?? snapshot.data ?? const <CommunityComment>[];
                final roots = comments
                    .where((comment) => comment.parentCommentId == null);
                if (comments.isEmpty) return const SizedBox.shrink();
                return Column(
                  children: [
                    for (final comment in roots)
                      _CommunityCommentThread(
                        comment: comment,
                        replies: comments
                            .where(
                                (reply) => reply.parentCommentId == comment.id)
                            .toList(growable: false),
                        readOnly: widget.readOnly,
                        onReact: widget.onReactToComment,
                        onReply: widget.onReplyToComment,
                        onOpenProfile: widget.onOpenProfile,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(String type) => switch (type) {
        'verse' => Icons.menu_book_outlined,
        'reflection' => Icons.lightbulb_outline,
        'photo' => Icons.photo_library_outlined,
        'prayer' => Icons.volunteer_activism_outlined,
        'gratitude' => Icons.favorite_border,
        'evangelism' => Icons.campaign_outlined,
        'invitation' => Icons.mark_email_unread_outlined,
        _ => Icons.diversity_3_outlined,
      };

  Future<void> _showReactions() async {
    final reactions = await widget.repository.fetchReactions(widget.post.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quem reagiu'),
        content: SizedBox(
          width: 420,
          child: reactions.isEmpty
              ? const Text('Ainda sem reacoes.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: reactions
                      .map(
                        (reaction) => ListTile(
                          leading: _ReactionAvatar(reaction: reaction),
                          title: Text(reaction.authorName ?? 'Membro'),
                          subtitle: Text(_reactionLabel(reaction.reactionType)),
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onOpenProfile(
                              reaction.profileId,
                              fallbackName: reaction.authorName,
                            );
                          },
                        ),
                      )
                      .toList(),
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
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} $hour:$minute';
}

class _ReactionOption {
  const _ReactionOption({
    required this.key,
    required this.label,
    required this.confirmation,
  });

  final String key;
  final String label;
  final String confirmation;
}

class _ReactionAvatar extends StatelessWidget {
  const _ReactionAvatar({required this.reaction});

  final CommunityReaction reaction;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = reaction.authorAvatarUrl?.trim();
    return ExpandableProfileAvatar(
      avatarUrl: avatarUrl,
      label: reaction.authorName ?? 'Membro',
      radius: 12,
      fallbackIcon: Icons.person_outline,
    );
  }
}

class _PastorFeedStatsRow extends StatelessWidget {
  const _PastorFeedStatsRow({
    required this.reactionCount,
    required this.commentCount,
    required this.shareCount,
    required this.reportCount,
    required this.pinned,
    required this.commentsEnabled,
    required this.onViewReactions,
    this.prayingCount,
  });

  final int reactionCount;
  final int commentCount;
  final int shareCount;
  final int reportCount;
  final int? prayingCount;
  final bool pinned;
  final bool commentsEnabled;
  final VoidCallback onViewReactions;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (reactionCount > 0)
          InkWell(
            onTap: onViewReactions,
            child: Text('\u{1F64F} $reactionCount', style: style),
          ),
        if (commentCount > 0)
          Text(
            commentCount == 1
                ? '1 coment\u00e1rio'
                : '$commentCount coment\u00e1rios',
            style: style,
          ),
        if (shareCount > 0)
          Text(
            shareCount == 1 ? '1 partilha' : '$shareCount partilhas',
            style: style,
          ),
        if (prayingCount != null && prayingCount! > 0)
          Text('$prayingCount em ora\u00e7\u00e3o', style: style),
        if (reportCount > 0)
          Text(
            reportCount == 1
                ? '1 den\u00fancia'
                : '$reportCount den\u00fancias',
            style: style?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        if (pinned) Text('Fixada', style: style),
        if (!commentsEnabled)
          Text('Coment\u00e1rios desativados', style: style),
      ],
    );
  }
}

class _PastorFeedActionButton extends StatelessWidget {
  const _PastorFeedActionButton({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityCommentThread extends StatelessWidget {
  const _CommunityCommentThread({
    required this.comment,
    required this.replies,
    required this.readOnly,
    required this.onReact,
    required this.onReply,
    required this.onOpenProfile,
  });

  final CommunityComment comment;
  final List<CommunityComment> replies;
  final bool readOnly;
  final ValueChanged<CommunityComment> onReact;
  final ValueChanged<CommunityComment> onReply;
  final void Function(String profileId, {String? fallbackName}) onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CommunityCommentRow(
          comment: comment,
          readOnly: readOnly,
          onReact: onReact,
          onReply: onReply,
          onOpenProfile: onOpenProfile,
        ),
        for (final reply in replies)
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: _CommunityCommentRow(
              comment: reply,
              readOnly: readOnly,
              onReact: onReact,
              onOpenProfile: onOpenProfile,
            ),
          ),
      ],
    );
  }
}

class _CommunityCommentRow extends StatelessWidget {
  const _CommunityCommentRow({
    required this.comment,
    required this.readOnly,
    required this.onReact,
    required this.onOpenProfile,
    this.onReply,
  });

  final CommunityComment comment;
  final bool readOnly;
  final ValueChanged<CommunityComment> onReact;
  final ValueChanged<CommunityComment>? onReply;
  final void Function(String profileId, {String? fallbackName}) onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarUrl = comment.authorAvatarUrl?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExpandableProfileAvatar(
            avatarUrl: avatarUrl,
            label: comment.authorName ?? 'Membro',
            radius: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.55),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () => onOpenProfile(
                            comment.profileId,
                            fallbackName: comment.authorName,
                          ),
                          child: Text(
                            comment.authorName ?? 'Membro',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          comment.body,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.28,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        _dateLabel(comment.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: readOnly ? null : () => onReact(comment),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('\u{1F64F} Am\u00e9m'),
                    ),
                    if (onReply != null)
                      TextButton(
                        onPressed: readOnly ? null : () => onReply!(comment),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Responder'),
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

class _ProfileLine extends StatelessWidget {
  const _ProfileLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('$label: $value'),
    );
  }
}

const _reactionOptions = <_ReactionOption>[
  _ReactionOption(
      key: 'amen',
      label: '\u{1F64F} Am\u00e9m',
      confirmation: '\u{1F64F} Am\u00e9m.'),
  _ReactionOption(
    key: 'praying',
    label: 'Estou orando',
    confirmation: 'Marcado como orando.',
  ),
  _ReactionOption(
    key: 'glory',
    label: 'Gl\u00f3ria a Deus',
    confirmation: 'Gl\u00f3ria a Deus.',
  ),
  _ReactionOption(
    key: 'built',
    label: 'Fui edificado',
    confirmation: 'Edifica\u00e7\u00e3o marcada.',
  ),
  _ReactionOption(
    key: 'faithful',
    label: 'Deus \u00e9 fiel',
    confirmation: 'Deus \u00e9 fiel.',
  ),
];

String _reactionConfirmation(String reaction) {
  return switch (reaction) {
    'amen' => '\u{1F64F} Am\u00e9m.',
    'praying' => 'Marcado como orando.',
    'glory' => 'Gl\u00f3ria a Deus.',
    'built' => 'Edifica\u00e7\u00e3o marcada.',
    'faithful' => 'Deus \u00e9 fiel.',
    _ => '\u{1F64F} Am\u00e9m.',
  };
}

String _reactionLabel(String reaction) {
  return switch (reaction) {
    'amen' => '\u{1F64F} Am\u00e9m',
    'praying' => 'Estou orando',
    'glory' => 'Gl\u00f3ria a Deus',
    'built' => 'Fui edificado',
    'faithful' => 'Deus \u00e9 fiel',
    _ => '\u{1F64F} Am\u00e9m',
  };
}

// ignore: unused_element
String _reactionEmoji(String reaction) {
  return switch (reaction) {
    'amen' => '\u{1F64F}',
    'praying' => '\u{1F64F}',
    'glory' => '\u{1F64C}',
    'built' => '\u{1F4D6}',
    'faithful' => '\u{1F64C}',
    _ => '\u{1F64F}',
  };
}
