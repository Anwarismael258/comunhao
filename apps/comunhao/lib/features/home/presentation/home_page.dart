import 'dart:async';
import 'dart:convert';

import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../core/utils/formatting.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/widgets/section_card.dart';
import '../../church/data/church_repository.dart';
import '../../church/models/church_announcement.dart';
import '../../church/models/church_birthday.dart';
import '../../church/models/church_branding.dart';
import '../../church/models/church_event.dart';
import '../../church/models/church_member.dart';
import '../../church/models/donation_campaign.dart';
import '../../church/models/member_prayer_request.dart';
import '../../publications/presentation/publications_page.dart';
import 'native_auto_media.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.church,
    required this.currentMember,
    required this.repository,
    this.onNavigate,
    super.key,
  });

  final ChurchBranding church;
  final ChurchMember currentMember;
  final ChurchRepository repository;
  final ValueChanged<int>? onNavigate;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<_HomeData> _future;

  String get _cacheKey => 'member_home_snapshot_${widget.church.id}';

  @override
  void initState() {
    super.initState();
    _future = _loadCachedOrRemote();
  }

  Future<_HomeData> _loadCachedOrRemote() async {
    final cached = await _readCachedHomeData();
    if (cached != null) {
      unawaited(_refreshFromNetwork());
      return cached;
    }
    return _loadFromNetwork();
  }

  Future<void> _refreshFromNetwork() async {
    try {
      final fresh = await _loadFromNetwork();
      if (!mounted) return;
      setState(() => _future = Future.value(fresh));
    } catch (_) {
      // Mantem o cache visivel se a rede falhar.
    }
  }

  Future<_HomeData?> _readCachedHomeData() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return _homeDataFromSnapshot(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheSnapshot(Map<String, dynamic> snapshot) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_cacheKey, jsonEncode(snapshot));
  }

  Future<_HomeData> _loadFromNetwork() async {
    try {
      final snapshot = await Supabase.instance.client.rpc(
        'get_member_home_snapshot',
        params: {'p_church_id': widget.church.id, 'p_limit': 24},
      );
      if (snapshot is Map) {
        final cleanSnapshot = Map<String, dynamic>.from(snapshot);
        await _cacheSnapshot(cleanSnapshot);
        return _homeDataFromSnapshot(cleanSnapshot);
      }
    } catch (_) {
      // Compatibilidade: se a RPC falhar, usa as consultas antigas.
    }

    final results = await Future.wait<dynamic>([
      widget.repository.fetchAnnouncements(widget.church.id),
      widget.repository.fetchUpcomingEvents(widget.church.id),
      widget.repository.fetchActiveCampaigns(widget.church.id),
      widget.repository.fetchChurchCommunications(widget.church.id),
      widget.repository.fetchUpcomingBirthdays(widget.church.id, limit: 6),
      widget.repository.fetchPrayerFeed(widget.church.id),
      PublicationRepository().fetchMemberFeed(widget.church.id, limit: 24),
    ]);

    return _HomeData(
      announcements: results[0] as List<ChurchAnnouncement>,
      events: results[1] as List<ChurchEvent>,
      campaigns: results[2] as List<DonationCampaign>,
      communications: results[3] as List<ChurchCommunication>,
      birthdays: results[4] as List<ChurchBirthday>,
      prayerFeed: results[5] as List<MemberPrayerRequest>,
      publications: results[6] as List<PastoralPublication>,
    );
  }

  _HomeData _homeDataFromSnapshot(Map<String, dynamic> snapshot) {
    List<Map<String, dynamic>> readRows(String key) {
      final value = snapshot[key];
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }

    return _HomeData(
      announcements:
          readRows('announcements').map(ChurchAnnouncement.fromMap).toList(),
      events: readRows('events').map(ChurchEvent.fromMap).toList(),
      campaigns: readRows('campaigns').map(DonationCampaign.fromMap).toList(),
      communications:
          readRows('communications').map(ChurchCommunication.fromMap).toList(),
      birthdays: readRows('birthdays').map(ChurchBirthday.fromMap).toList(),
      prayerFeed:
          readRows('prayer_feed').map(MemberPrayerRequest.fromMap).toList(),
      publications:
          readRows('publications').map(PastoralPublication.fromMap).toList(),
    );
  }

  Future<void> _openPublication(PastoralPublication publication) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicationDetailPage(
          publicationId: publication.id,
          initialPublication: publication,
          repository: PublicationRepository(),
          churchName: widget.church.name,
          churchLogoUrl: widget.church.logoUrl,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _future = _loadFromNetwork();
    });
  }

  List<_RecentHomeItem> _buildRecentItems(_HomeData data) {
    final churchLogoUrl = widget.church.logoUrl;
    final publicationsById = {
      for (final publication in data.publications) publication.id: publication,
    };
    final mirroredPublicationIds = <String>{
      ...data.announcements
          .map((item) => item.pastoralPublicationId)
          .whereType<String>(),
      ...data.events
          .map((item) => item.pastoralPublicationId)
          .whereType<String>(),
      ...data.campaigns
          .map((item) => item.pastoralPublicationId)
          .whereType<String>(),
    };
    final items = <_RecentHomeItem>[
      ...data.publications.where((publication) {
        return !mirroredPublicationIds.contains(publication.id);
      }).map(
        (publication) => _RecentHomeItem(
          id: publication.id,
          title: publication.title,
          body: publication.summary?.trim().isNotEmpty == true
              ? publication.summary!.trim()
              : publication.content,
          label: publication.typeLabel,
          icon: _PublicationHomeTileState.iconFor(publication.publicationType),
          publishedAt: publication.createdAt.toLocal(),
          imageUrl: publication.coverImageUrl,
          authorAvatarUrl: publication.authorAvatarUrl ?? churchLogoUrl,
          publication: publication,
        ),
      ),
      ...data.announcements.map(
        (announcement) => _RecentHomeItem(
          id: announcement.id,
          title: announcement.title,
          body: announcement.body,
          label: announcement.pinned ? 'Anuncio fixado' : 'Anuncio',
          icon: announcement.pinned
              ? Icons.push_pin_outlined
              : Icons.campaign_outlined,
          publishedAt:
              (announcement.publishedAt ?? announcement.createdAt).toLocal(),
          imageUrl: announcement.imageUrl,
          authorAvatarUrl: churchLogoUrl,
          publication: publicationsById[announcement.pastoralPublicationId],
        ),
      ),
      ...data.events.map(
        (event) => _RecentHomeItem(
          id: event.id,
          title: event.title,
          body: [
            event.eventTypeLabel,
            'Evento em ${formatDateTimeShort(event.startsAt)}',
            if (event.location?.trim().isNotEmpty == true) event.location!,
            if (event.description?.trim().isNotEmpty == true)
              event.description!,
          ].join('\n'),
          label: event.eventTypeLabel,
          icon: Icons.event_available_outlined,
          publishedAt: event.createdAt.toLocal(),
          imageUrl: event.coverImageUrl,
          authorAvatarUrl: churchLogoUrl,
          publication: publicationsById[event.pastoralPublicationId],
          eventStartsAt: event.startsAt,
          eventEndsAt: event.endsAt,
        ),
      ),
      ...data.campaigns.map(
        (campaign) => _RecentHomeItem(
          id: campaign.id,
          title: campaign.title,
          body: [
            if (campaign.description?.trim().isNotEmpty == true)
              campaign.description!,
            '${campaign.progressPercent}% - ${formatMoney(campaign.raisedAmount, widget.church.defaultCurrency)} arrecadado',
          ].join('\n'),
          label: 'Campanha',
          icon: Icons.volunteer_activism_outlined,
          publishedAt: campaign.createdAt.toLocal(),
          imageUrl: campaign.imageUrl,
          authorAvatarUrl: churchLogoUrl,
          publication: publicationsById[campaign.pastoralPublicationId],
        ),
      ),
    ];
    items.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _ErrorState(message: '${snapshot.error ?? 'Sem dados.'}');
        }

        final data = snapshot.data!;
        final recentItems = _buildRecentItems(data);
        final publicPrayerFeed = data.prayerFeed
            .where((item) => item.visibility != 'private')
            .take(3)
            .toList(growable: false);

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _future = _loadFromNetwork();
            });
            await _future;
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ChurchIdentityBanner(
                churchName: widget.church.name,
                logoUrl: widget.church.logoUrl,
                primaryColor: parseHexColor(widget.church.primaryColor),
                secondaryColor: widget.church.secondaryColor == null ||
                        widget.church.secondaryColor!.trim().isEmpty
                    ? null
                    : parseHexColor(widget.church.secondaryColor),
                subtitle: 'A paz de Cristo, ${widget.currentMember.fullName}.',
              ),
              const SizedBox(height: 16),
              DailyScriptureSplashCard(
                churchId: widget.church.id,
                personName: widget.currentMember.fullName,
                logoAssetPath: 'assets/branding/comunhao.png',
              ),
              const SizedBox(height: 16),
              _SocialWelcomeCard(
                church: widget.church,
                member: widget.currentMember,
                onOpenFeed: () => widget.onNavigate?.call(3),
                onOpenPrayer: () => widget.onNavigate?.call(6),
                onOpenAgenda: () => widget.onNavigate?.call(4),
                onOpenGiving: () => widget.onNavigate?.call(1),
              ),
              const SizedBox(height: 20),
              SectionCard(
                title: 'Da igreja para si',
                subtitle:
                    'Anúncios, cultos, campanhas, devocionais, vídeos e mensagens em tempo real.',
                child: recentItems.isEmpty
                    ? const Text('Ainda não existem publicações recentes.')
                    : Column(
                        children: recentItems.take(6).map((item) {
                          if (item.publication != null) {
                            return _PublicationHomeTile(
                              publication: item.publication!,
                              publishedAt: item.publishedAt,
                              authorAvatarUrl: item.authorAvatarUrl,
                              churchName: widget.church.name,
                              churchLogoUrl: widget.church.logoUrl,
                              currentMember: widget.currentMember,
                              onOpen: () => _openPublication(
                                item.publication!,
                              ),
                            );
                          }
                          return _RecentHomeTile(item: item);
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 20),
              SectionCard(
                title: 'Próximos encontros',
                subtitle: 'Cultos, vigílias, reuniões e eventos da comunidade.',
                child: data.events.isEmpty
                    ? const Text('Ainda não existem eventos marcados.')
                    : Column(
                        children: data.events.take(4).map((event) {
                          return Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundImage:
                                      event.coverImageUrl?.trim().isNotEmpty ==
                                              true
                                          ? NetworkImage(
                                              event.coverImageUrl!.trim(),
                                            )
                                          : null,
                                  child:
                                      event.coverImageUrl?.trim().isNotEmpty ==
                                              true
                                          ? null
                                          : const Icon(
                                              Icons.event_available_outlined,
                                            ),
                                ),
                                title: Text(event.title),
                                subtitle: Text(
                                  '${event.eventTypeLabel} • ${formatDateTimeShort(event.startsAt)}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => widget.onNavigate?.call(4),
                              ),
                              const Divider(),
                            ],
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 20),
              SectionCard(
                title: 'Oração em comunidade',
                subtitle:
                    'Pedidos públicos e anônimos onde a igreja pode responder e apoiar.',
                child: publicPrayerFeed.isEmpty
                    ? const Text('Ainda não existem pedidos comunitários.')
                    : Column(
                        children: publicPrayerFeed.map((request) {
                          return Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  child: Icon(
                                    request.visibility == 'anonymous'
                                        ? Icons.visibility_off_outlined
                                        : Icons.volunteer_activism_outlined,
                                  ),
                                ),
                                title: Text(request.title),
                                subtitle: Text(
                                  '${request.visibilityLabel} - ${request.statusLabel}\n${request.description}',
                                ),
                                trailing: request.allowResponses
                                    ? const Chip(label: Text('Responder'))
                                    : const Chip(label: Text('Sem respostas')),
                                onTap: () => widget.onNavigate?.call(6),
                              ),
                              const Divider(),
                            ],
                          );
                        }).toList(),
                      ),
              ),
              if (data.birthdays.isNotEmpty) ...[
                const SizedBox(height: 20),
                SectionCard(
                  title: 'Celebrar hoje',
                  subtitle: 'Aniversários e pessoas para cumprimentar.',
                  child: Column(
                    children: data.birthdays.take(3).map((birthday) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.cake_outlined),
                        ),
                        title: Text(birthday.fullName),
                        subtitle: Text(
                          '${birthday.roleLabel} • ${formatDateShort(birthday.nextBirthday)}',
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PublicationHomeTile extends StatefulWidget {
  const _PublicationHomeTile({
    required this.publication,
    required this.publishedAt,
    required this.churchName,
    required this.currentMember,
    this.authorAvatarUrl,
    this.churchLogoUrl,
    required this.onOpen,
  });

  final PastoralPublication publication;
  final DateTime publishedAt;
  final String churchName;
  final ChurchMember currentMember;
  final String? authorAvatarUrl;
  final String? churchLogoUrl;
  final VoidCallback onOpen;

  @override
  State<_PublicationHomeTile> createState() => _PublicationHomeTileState();
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

class _SocialWelcomeCard extends StatelessWidget {
  const _SocialWelcomeCard({
    required this.church,
    required this.member,
    required this.onOpenFeed,
    required this.onOpenPrayer,
    required this.onOpenAgenda,
    required this.onOpenGiving,
  });

  final ChurchBranding church;
  final ChurchMember member;
  final VoidCallback onOpenFeed;
  final VoidCallback onOpenPrayer;
  final VoidCallback onOpenAgenda;
  final VoidCallback onOpenGiving;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final firstName = member.fullName.trim().split(' ').first;
    final logoUrl = church.logoUrl?.trim();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [
            colors.primary,
            colors.secondary,
            const Color(0xFF111827),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                backgroundImage: logoUrl != null && logoUrl.isNotEmpty
                    ? NetworkImage(logoUrl)
                    : null,
                child: logoUrl != null && logoUrl.isNotEmpty
                    ? null
                    : const Icon(Icons.church_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A paz de Cristo, $firstName',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      church.name,
                      style: const TextStyle(
                        color: Color(0xFFE0F2FE),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Veja o que a igreja partilhou hoje, ore com a comunidade e participe nos próximos encontros.',
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SocialQuickAction(
                icon: Icons.diversity_3_outlined,
                label: 'Abrir Comunhão',
                onTap: onOpenFeed,
              ),
              _SocialQuickAction(
                icon: Icons.volunteer_activism_outlined,
                label: 'Pedir oração',
                onTap: onOpenPrayer,
              ),
              _SocialQuickAction(
                icon: Icons.event_available_outlined,
                label: 'Agenda',
                onTap: onOpenAgenda,
              ),
              _SocialQuickAction(
                icon: Icons.favorite_border,
                label: 'Contribuir',
                onTap: onOpenGiving,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SocialQuickAction extends StatelessWidget {
  const _SocialQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        foregroundColor: const Color(0xFF111827),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

const _publicationReactionOptions = <_PublicationReactionOption>[
  _PublicationReactionOption(
    key: 'amen',
    label: '🙏 Amém',
    confirmation: '🙏 Amém.',
  ),
  _PublicationReactionOption(
    key: 'praying',
    label: 'Estou orando',
    confirmation: 'Marcado como orando.',
  ),
  _PublicationReactionOption(
    key: 'glory',
    label: 'Glória a Deus',
    confirmation: 'Glória a Deus.',
  ),
  _PublicationReactionOption(
    key: 'built',
    label: 'Fui edificado',
    confirmation: 'Edificação marcada.',
  ),
  _PublicationReactionOption(
    key: 'faithful',
    label: 'Deus é fiel',
    confirmation: 'Deus é fiel.',
  ),
];

String _publicationReactionText(String reaction) {
  return _publicationReactionOptions
      .firstWhere(
        (option) => option.key == reaction,
        orElse: () => _publicationReactionOptions.first,
      )
      .confirmation;
}

String _publicationReactionLabel(String reaction) {
  return _publicationReactionOptions
      .firstWhere(
        (option) => option.key == reaction,
        orElse: () => _publicationReactionOptions.first,
      )
      .label;
}

class _PublicationHomeTileState extends State<_PublicationHomeTile> {
  late int _reactionCount;
  late int _commentCount;
  late String? _reaction;
  List<PastoralPublicationComment>? _comments;
  bool _busy = false;

  PastoralPublication get publication => widget.publication;
  bool get _amenMarked => _reaction == 'amen';

  @override
  void initState() {
    super.initState();
    _reactionCount = publication.reactionCount;
    _commentCount = publication.commentCount;
    _reaction = publication.myReaction;
  }

  Future<void> _react(BuildContext context, [String reaction = 'amen']) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await PublicationRepository().react(publication.id, reaction);
      if (!context.mounted) return;
      setState(() {
        if (_reaction == null) {
          _reactionCount += 1;
        }
        _reaction = reaction;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_publicationReactionText(reaction))),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _share(BuildContext context) async {
    final params = Map<String, String>.from(Uri.base.queryParameters);
    params['publication'] = publication.slug;
    params['type'] = publication.publicationType;
    final url = Uri.base.replace(queryParameters: params).toString();
    await Clipboard.setData(
      ClipboardData(text: '${publication.title}\n\n$url'),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link da publicacao copiado.')),
    );
  }

  Future<void> _openReactions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return FutureBuilder<List<PastoralPublicationReaction>>(
          future: PublicationRepository().fetchReactions(publication.id),
          builder: (context, snapshot) {
            final reactions =
                snapshot.data ?? const <PastoralPublicationReaction>[];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (reactions.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Ainda sem reacoes.'),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  'Pessoas que reagiram',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (final reaction in reactions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ExpandableProfileAvatar(
                      avatarUrl: reaction.profileId == publication.authorUserId
                          ? widget.churchLogoUrl ?? reaction.authorAvatarUrl
                          : reaction.authorAvatarUrl,
                      label: reaction.profileId == publication.authorUserId
                          ? widget.churchName
                          : reaction.authorName ?? 'Membro',
                    ),
                    title: Text(
                      reaction.profileId == publication.authorUserId
                          ? widget.churchName
                          : reaction.authorName ?? 'Membro',
                    ),
                    subtitle: Text(
                      _publicationReactionLabel(reaction.reactionType),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openVideoFullscreen(BuildContext context, String videoUrl) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullscreenVideoPage(
          title: publication.title,
          videoUrl: videoUrl,
          publicationId: publication.id,
        ),
      ),
    );
  }

  Future<void> _openCommentComposer(BuildContext context) async {
    final controller = TextEditingController();
    _comments ??= await PublicationRepository().fetchComments(publication.id);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comentarios',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final comments =
                          _comments ?? const <PastoralPublicationComment>[];
                      if (comments.isEmpty) {
                        return const Text('Ainda sem comentarios.');
                      }
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 260),
                        child: ListView(
                          shrinkWrap: true,
                          children: comments.map(
                            (comment) {
                              final isChurchComment = _isChurchComment(comment);
                              final isMe =
                                  comment.profileId == widget.currentMember.id;
                              final authorName = isChurchComment
                                  ? widget.churchName
                                  : isMe
                                      ? widget.currentMember.fullName
                                      : comment.authorName ?? 'Membro';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: ExpandableProfileAvatar(
                                  avatarUrl: isChurchComment
                                      ? widget.churchLogoUrl ??
                                          comment.authorAvatarUrl
                                      : isMe
                                          ? widget.currentMember.avatarUrl ??
                                              comment.authorAvatarUrl
                                          : comment.authorAvatarUrl,
                                  label: authorName,
                                ),
                                title: Text(authorName),
                                subtitle: Text(
                                  '${formatDateTimeShort(comment.createdAt)}\n${comment.body}',
                                ),
                              );
                            },
                          ).toList(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Escrever comentario',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.length < 2) return;
                        await PublicationRepository().comment(
                          publicationId: publication.id,
                          body: text,
                        );
                        final now = DateTime.now();
                        final optimistic = PastoralPublicationComment(
                          id: 'local-${now.microsecondsSinceEpoch}',
                          publicationId: publication.id,
                          profileId: widget.currentMember.id,
                          authorName: widget.currentMember.fullName,
                          authorAvatarUrl: widget.currentMember.avatarUrl,
                          body: text,
                          status: 'active',
                          createdAt: now,
                        );
                        controller.clear();
                        _comments = [...?_comments, optimistic];
                        setSheetState(() {});
                        if (mounted) setState(() => _commentCount += 1);
                        try {
                          final fresh = await PublicationRepository()
                              .fetchComments(publication.id);
                          if (fresh.isNotEmpty) {
                            _comments = fresh;
                            if (fresh.length > _commentCount && mounted) {
                              setState(() => _commentCount = fresh.length);
                            }
                          }
                          if (context.mounted) setSheetState(() {});
                        } catch (_) {
                          // Mantem o comentario otimista visivel.
                        }
                      },
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Enviar'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    controller.dispose();
    if (saved == true && mounted) {
      setState(() => _commentCount += 1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comentario publicado.')),
      );
    }
  }

  bool _isChurchComment(PastoralPublicationComment comment) {
    if (comment.profileId == publication.authorUserId) return true;
    final name = (comment.authorName ?? '').trim().toLowerCase();
    return name == widget.churchName.trim().toLowerCase() ||
        name.contains('pastor') ||
        name.contains('igreja');
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = publication.coverImageUrl?.trim();
    final videoUrl = publication.videoUrl?.trim();
    final audioUrl = publication.audioUrl?.trim();
    final authorAvatarUrl = widget.authorAvatarUrl?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: widget.onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (videoUrl != null && videoUrl.isNotEmpty) ...[
              Stack(
                children: [
                  NativeAutoMedia(
                    url: videoUrl,
                    kind: NativeAutoMediaKind.video,
                    height: 320,
                    viewKey: 'home-video-${publication.id}',
                  ),
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openVideoFullscreen(context, videoUrl),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton.filled(
                      tooltip: 'Tela cheia',
                      onPressed: () => _openVideoFullscreen(context, videoUrl),
                      icon: const Icon(Icons.fullscreen),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ] else if (audioUrl != null && audioUrl.isNotEmpty) ...[
              NativeAutoMedia(
                url: audioUrl,
                kind: NativeAutoMediaKind.audio,
                height: 120,
                viewKey: 'home-audio-${publication.id}',
              ),
              const SizedBox(height: 10),
            ] else if (imageUrl != null && imageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 220,
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExpandableProfileAvatar(
                  avatarUrl: authorAvatarUrl,
                  label: publication.authorName ?? 'Igreja',
                  fallbackIcon: iconFor(publication.publicationType),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        publication.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      _RecentTypeBadge(
                        label: publication.typeLabel,
                        icon: iconFor(publication.publicationType),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _relativeTime(widget.publishedAt),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      if (publication.summary != null &&
                          publication.summary!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(publication.summary!),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (videoUrl != null && videoUrl.isNotEmpty)
                            const Chip(label: Text('Video')),
                          if (audioUrl != null && audioUrl.isNotEmpty)
                            const Chip(label: Text('Audio')),
                          if (publication.documentUrl != null)
                            const Chip(label: Text('Documento')),
                          if (publication.externalUrl != null)
                            const Chip(label: Text('Link')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _busy ? null : () => _react(context),
                  icon: Text(
                    '🙏',
                    style: TextStyle(
                      fontSize: _amenMarked ? 20 : 18,
                    ),
                  ),
                  label: Text(
                    _reactionCount == 0 ? 'Amen' : 'Amen ($_reactionCount)',
                  ),
                ),
                if (_reactionCount > 0)
                  TextButton.icon(
                    onPressed: () => _openReactions(context),
                    icon: const Icon(Icons.people_alt_outlined),
                    label: Text('Ver reacoes ($_reactionCount)'),
                  ),
                PopupMenuButton<String>(
                  enabled: !_busy && publication.allowReactions,
                  onSelected: (value) => _react(context, value),
                  itemBuilder: (context) => _publicationReactionOptions
                      .where((option) => option.key != 'amen')
                      .map(
                        (option) => PopupMenuItem(
                          value: option.key,
                          child: Text(option.label),
                        ),
                      )
                      .toList(),
                  child: TextButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.add_reaction_outlined),
                    label: const Text('Mais reações'),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _share(context),
                  icon: const Icon(Icons.ios_share_outlined),
                  label: const Text('Partilhar'),
                ),
                TextButton.icon(
                  onPressed: () => _openCommentComposer(context),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(
                    _commentCount == 0
                        ? 'Comentar'
                        : 'Comentar ($_commentCount)',
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
          ],
        ),
      ),
    );
  }

  static IconData iconFor(String type) => switch (type) {
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

class _RecentHomeTile extends StatelessWidget {
  const _RecentHomeTile({required this.item});

  final _RecentHomeItem item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl?.trim();
    final authorAvatarUrl = item.authorAvatarUrl?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 180,
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExpandableProfileAvatar(
                avatarUrl: authorAvatarUrl,
                label: item.title,
                fallbackIcon: item.icon,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    _RecentTypeBadge(label: item.label, icon: item.icon),
                    if (item.eventStartsAt != null) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _RecentEventBadge(item: item),
                          Text(
                            _eventTimingText(
                              item.eventStartsAt!,
                              item.eventEndsAt,
                            ),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      'Publicado ${_relativeTime(item.publishedAt)}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (item.body.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.body,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }
}

String _eventTimingText(DateTime startsAt, DateTime? endsAt) {
  final now = DateTime.now();
  final start = startsAt.toLocal();
  final end = endsAt?.toLocal();
  final time = DateFormat('HH:mm').format(start);
  final dayStart = DateTime(start.year, start.month, start.day);
  final today = DateTime(now.year, now.month, now.day);
  final dayDiff = dayStart.difference(today).inDays;
  final finished = (end ?? start).isBefore(now);

  if (finished) {
    if (dayDiff == 0) return 'Realizado hoje às $time';
    if (dayDiff == -1) return 'Realizado ontem às $time';
    return 'Realizado em ${DateFormat('dd MMM').format(start)} às $time';
  }
  if (dayDiff == 0) return 'Hoje às $time';
  if (dayDiff == 1) return 'Amanhã às $time';
  if (dayDiff > 1 && dayDiff <= 6) return 'Daqui a $dayDiff dias';
  return '${DateFormat('dd MMM').format(start)} às $time';
}

String _eventBadgeLabel(_RecentHomeItem item) {
  final now = DateTime.now();
  final start = item.eventStartsAt!.toLocal();
  final end = item.eventEndsAt?.toLocal();
  if (!start.isAfter(now) && (end == null || end.isAfter(now))) {
    return 'A DECORRER';
  }
  if ((end ?? start).isBefore(now)) return 'REALIZADO';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(start.year, start.month, start.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'HOJE';
  if (diff == 1) return 'AMANHÃ';
  if (diff > 1 && diff <= 6) return 'EM $diff DIAS';
  return DateFormat('dd MMM').format(start).toUpperCase();
}

Color _eventBadgeColor(_RecentHomeItem item) {
  final label = _eventBadgeLabel(item);
  if (label == 'A DECORRER') return Colors.red.shade700;
  if (label == 'HOJE') return Colors.green.shade700;
  if (label == 'AMANHÃ') return Colors.amber.shade800;
  if (label == 'REALIZADO') return Colors.grey.shade700;
  return Colors.blue.shade700;
}

class _RecentTypeBadge extends StatelessWidget {
  const _RecentTypeBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = recentTypeBadgeColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

Color recentTypeBadgeColor(String label) => feedTypeBadgeColor(label);

Color feedTypeBadgeColor(String label) {
  final normalized = label.toLowerCase();
  if (normalized.contains('culto')) return Colors.indigo.shade700;
  if (normalized.contains('congresso')) return Colors.deepPurple.shade700;
  if (normalized.contains('vigilia') || normalized.contains('vigília')) {
    return Colors.blueGrey.shade700;
  }
  if (normalized.contains('batismo')) return Colors.cyan.shade800;
  if (normalized.contains('casamento')) return Colors.pink.shade700;
  if (normalized.contains('conferencia') ||
      normalized.contains('conferência')) {
    return Colors.orange.shade800;
  }
  if (normalized.contains('ensaio')) return Colors.teal.shade700;
  if (normalized.contains('reuniao') || normalized.contains('reunião')) {
    return Colors.brown.shade700;
  }
  if (normalized.contains('campanha')) return Colors.green.shade700;
  if (normalized.contains('pregacao') || normalized.contains('pregação')) {
    return Colors.red.shade700;
  }
  if (normalized.contains('devocional')) return Colors.amber.shade800;
  if (normalized.contains('estudo')) return Colors.lightBlue.shade800;
  if (normalized.contains('palavra pastoral')) return Colors.purple.shade700;
  if (normalized.contains('aviso urgente')) return Colors.deepOrange.shade800;
  if (normalized.contains('video') || normalized.contains('vídeo')) {
    return Colors.redAccent.shade700;
  }
  if (normalized.contains('audio') || normalized.contains('áudio')) {
    return Colors.green.shade800;
  }
  if (normalized.contains('documento')) return Colors.blue.shade800;
  if (normalized.contains('transmissao') ||
      normalized.contains('transmissão') ||
      normalized.contains('live')) {
    return Colors.red.shade900;
  }
  if (normalized.contains('comunicado')) return Colors.blueGrey.shade800;
  if (normalized.contains('lideranca') || normalized.contains('liderança')) {
    return Colors.deepPurple.shade600;
  }
  if (normalized.contains('testemunho')) return Colors.lime.shade900;
  if (normalized.contains('oracao') || normalized.contains('oração')) {
    return Colors.blue.shade700;
  }
  return Colors.blueGrey.shade700;
}

class _RecentEventBadge extends StatelessWidget {
  const _RecentEventBadge({required this.item});

  final _RecentHomeItem item;

  @override
  Widget build(BuildContext context) {
    final color = _eventBadgeColor(item);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        _eventBadgeLabel(item),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _RecentHomeItem {
  const _RecentHomeItem({
    required this.id,
    required this.title,
    required this.body,
    required this.label,
    required this.icon,
    required this.publishedAt,
    this.imageUrl,
    this.authorAvatarUrl,
    this.publication,
    this.eventStartsAt,
    this.eventEndsAt,
  });

  final String id;
  final String title;
  final String body;
  final String label;
  final IconData icon;
  final DateTime publishedAt;
  final String? imageUrl;
  final String? authorAvatarUrl;
  final PastoralPublication? publication;
  final DateTime? eventStartsAt;
  final DateTime? eventEndsAt;
}

class _FullscreenVideoPage extends StatelessWidget {
  const _FullscreenVideoPage({
    required this.title,
    required this.videoUrl,
    required this.publicationId,
  });

  final String title;
  final String videoUrl;
  final String publicationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: NativeAutoMedia(
          url: videoUrl,
          kind: NativeAutoMediaKind.video,
          height: MediaQuery.of(context).size.height * 0.78,
          viewKey: 'fullscreen-video-$publicationId',
        ),
      ),
    );
  }
}

class _MediaPoster extends StatelessWidget {
  const _MediaPoster({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 260,
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _InlineVideoPlayer extends StatefulWidget {
  const _InlineVideoPlayer({
    required this.videoUrl,
    required this.visibilityKey,
  });

  final String videoUrl;
  final String visibilityKey;

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..setLooping(true)
      ..setVolume(0);
    _controller.initialize().then((_) async {
      if (!mounted) return;
      setState(() => _ready = true);
      await _controller.play();
      if (mounted) setState(() {});
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    if (!_ready) return;
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _toggleSound() {
    if (!_ready) return;
    setState(() {
      _controller.setVolume(_controller.value.volume == 0 ? 1 : 0);
    });
  }

  void _handleVisibility(double fraction) {
    final shouldPlay = fraction > 0.58;
    if (!_ready) return;
    if (shouldPlay && !_controller.value.isPlaying) {
      _controller.play().then((_) {
        if (mounted) setState(() {});
      });
    } else if (!shouldPlay && _controller.value.isPlaying) {
      _controller.pause();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return _MediaPoster(
        icon: Icons.play_circle_fill,
        label: 'Video indisponivel',
        onTap: () {},
      );
    }

    return VisibilityDetector(
      key: ValueKey(widget.visibilityKey),
      onVisibilityChanged: (info) {
        _handleVisibility(info.visibleFraction);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 320,
          width: double.infinity,
          color: Colors.black,
          child: !_ready
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTap: _togglePlayback,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: _controller.value.aspectRatio == 0
                              ? 9 / 16
                              : _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                    ),
                    if (!_controller.value.isPlaying)
                      IconButton.filled(
                        onPressed: _togglePlayback,
                        iconSize: 44,
                        icon: const Icon(Icons.play_arrow),
                      ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Row(
                        children: [
                          IconButton.filledTonal(
                            tooltip: _controller.value.isPlaying
                                ? 'Pausar'
                                : 'Reproduzir',
                            onPressed: _togglePlayback,
                            icon: Icon(
                              _controller.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: _controller.value.volume == 0
                                ? 'Ativar som'
                                : 'Silenciar',
                            onPressed: _toggleSound,
                            icon: Icon(
                              _controller.value.volume == 0
                                  ? Icons.volume_off
                                  : Icons.volume_up,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _InlineAudioPlayer extends StatefulWidget {
  const _InlineAudioPlayer({
    required this.audioUrl,
    required this.visibilityKey,
    required this.title,
  });

  final String audioUrl;
  final String visibilityKey;
  final String title;

  @override
  State<_InlineAudioPlayer> createState() => _InlineAudioPlayerState();
}

class _InlineAudioPlayerState extends State<_InlineAudioPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.audioUrl))
      ..setLooping(true)
      ..setVolume(1);
    _controller.initialize().then((_) async {
      if (!mounted) return;
      setState(() => _ready = true);
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleVisibility(double fraction) {
    final shouldPause = fraction < 0.18;
    if (!_ready) return;
    if (shouldPause && _controller.value.isPlaying) {
      _controller.pause();
      if (mounted) setState(() {});
    }
  }

  void _togglePlayback() {
    if (!_ready) return;
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play().catchError((_) {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_failed) {
      return _MediaPoster(
        icon: Icons.headphones,
        label: 'Audio indisponivel',
        onTap: () {},
      );
    }

    return VisibilityDetector(
      key: ValueKey(widget.visibilityKey),
      onVisibilityChanged: (info) {
        _handleVisibility(info.visibleFraction);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              child: IconButton(
                onPressed: _ready ? _togglePlayback : null,
                icon: Icon(
                  _ready && _controller.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    _ready
                        ? (_controller.value.isPlaying
                            ? 'A tocar no app'
                            : 'Pausado')
                        : 'A carregar audio...',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.announcements,
    required this.events,
    required this.campaigns,
    required this.communications,
    required this.birthdays,
    required this.prayerFeed,
    required this.publications,
  });

  final List<ChurchAnnouncement> announcements;
  final List<ChurchEvent> events;
  final List<DonationCampaign> campaigns;
  final List<ChurchCommunication> communications;
  final List<ChurchBirthday> birthdays;
  final List<MemberPrayerRequest> prayerFeed;
  final List<PastoralPublication> publications;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Não foi possível carregar a home.\n\n$message',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

String _relativeTime(DateTime value) {
  final local = value.toLocal();
  final difference = DateTime.now().difference(local);
  if (difference.inSeconds < 60) return 'agora';
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return 'há $minutes min';
  }
  if (difference.inHours < 24) {
    final hours = difference.inHours;
    return 'há $hours h';
  }
  if (difference.inDays == 1) return 'ontem';
  if (difference.inDays < 7) return 'há ${difference.inDays} dias';
  if (difference.inDays < 30) {
    final weeks = (difference.inDays / 7).floor();
    return weeks == 1 ? 'há 1 semana' : 'há $weeks semanas';
  }
  final months = (difference.inDays / 30).floor();
  return months == 1 ? 'há 1 mês' : 'há $months meses';
}
