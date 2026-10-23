import 'dart:async';
import 'dart:convert';

import 'package:comunhao_shared/comunhao_shared.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/formatting.dart';
import '../../../core/widgets/section_card.dart';
import '../../church/data/church_repository.dart';
import '../../church/models/church_announcement.dart';
import '../../church/models/church_birthday.dart';
import '../../church/models/church_branding.dart';
import '../../church/models/church_event.dart';
import '../../church/models/church_member.dart';
import '../../church/models/donation_campaign.dart';
import '../../church/models/member_prayer_request.dart';
import '../../home/presentation/native_auto_media_stub.dart'
    if (dart.library.html) '../../home/presentation/native_auto_media_web.dart';

class CommunityFeedPage extends StatefulWidget {
  const CommunityFeedPage({
    required this.church,
    required this.member,
    required this.repository,
    super.key,
  });

  final ChurchBranding church;
  final ChurchMember member;
  final ChurchRepository repository;

  @override
  State<CommunityFeedPage> createState() => _CommunityFeedPageState();
}

class _CommunityFeedPageState extends State<CommunityFeedPage> {
  static const _localResetVersion = '20260720_clean_feed_and_wallet_test';
  final _feedRepository = CommunityFeedRepository();
  final _imagePicker = ImagePicker();
  late Future<_CommunityFeedData> _future;
  List<_MemberFeedPost> _localPosts = const [];
  Map<String, List<String>> _localComments = const {};
  Map<String, List<dynamic>> _commentCache = const {};
  Map<String, ChurchMember> _knownMembersById = const {};
  Set<String> _churchActorProfileIds = const {};
  String _filter = 'all';
  RealtimeChannel? _channel;
  Timer? _refreshTimer;

  String get _storagePrefix =>
      'community_feed_${widget.church.id}_${widget.member.id}';

  @override
  void initState() {
    super.initState();
    _future = _load();
    _configureRealtime();
  }

  @override
  void didUpdateWidget(covariant CommunityFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.church.id != widget.church.id ||
        oldWidget.member.id != widget.member.id) {
      _configureRealtime();
      _scheduleRefresh();
    }
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

  Future<_CommunityFeedData> _load() async {
    await _loadLocalState();
    final results = await Future.wait<dynamic>([
      widget.repository.fetchAnnouncements(widget.church.id),
      widget.repository.fetchUpcomingEvents(widget.church.id),
      widget.repository.fetchPrayerFeed(widget.church.id),
      widget.repository.fetchUpcomingBirthdays(widget.church.id, limit: 12),
      PublicationRepository().fetchMemberFeed(widget.church.id),
      _feedRepository.fetchFeed(widget.church.id),
      _feedRepository.fetchOwnPosts(widget.church.id),
      widget.repository.fetchActiveCampaigns(widget.church.id),
      _fetchKnownMembers(),
      _fetchChurchActorProfileIds(),
    ]);
    final knownMembers = results[8] as List<ChurchMember>;
    _knownMembersById = {
      for (final member in knownMembers) member.id: member,
      widget.member.id: widget.member,
    };
    _churchActorProfileIds = {
      ...results[9] as Set<String>,
      for (final member in knownMembers)
        if (_isChurchLeader(member)) member.id,
    };
    return _CommunityFeedData(
      announcements: results[0] as List<ChurchAnnouncement>,
      events: results[1] as List<ChurchEvent>,
      prayerFeed: results[2] as List<MemberPrayerRequest>,
      birthdays: results[3] as List<ChurchBirthday>,
      publications: results[4] as List<PastoralPublication>,
      communityPosts: results[5] as List<CommunityPost>,
      ownCommunityPosts: results[6] as List<CommunityPost>,
      campaigns: results[7] as List<DonationCampaign>,
      members: knownMembers,
    );
  }

  Future<List<ChurchMember>> _fetchKnownMembers() async {
    try {
      final rows = await Supabase.instance.client
          .from('memberships')
          .select('''
            id,
            church_id,
            profile_id,
            role,
            status,
            member_code,
            baptism_date,
            created_at,
            profile:profiles (
              id,
              full_name,
              phone,
              birth_date,
              avatar_url,
              avatar_storage_path
            )
          ''')
          .eq('church_id', widget.church.id)
          .eq('status', 'active')
          .limit(200);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(ChurchMember.fromMap)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<Set<String>> _fetchChurchActorProfileIds() async {
    try {
      final rows = await Supabase.instance.client
          .from('memberships')
          .select('profile_id, role, status')
          .eq('church_id', widget.church.id)
          .inFilter('role', const [
        'pastor',
        'church_admin',
        'leader',
        'admin',
        'owner',
      ]);
      return rows
          .whereType<Map<String, dynamic>>()
          .where((row) => (row['status'] as String?) != 'removed')
          .map((row) => row['profile_id'] as String?)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return const {};
    }
  }

  Future<void> _loadLocalState() async {
    final preferences = await SharedPreferences.getInstance();
    final resetKey = '$_storagePrefix.reset_version';
    if (preferences.getString(resetKey) != _localResetVersion) {
      await preferences.remove('$_storagePrefix.posts');
      await preferences.remove('$_storagePrefix.comments');
      await preferences.setString(resetKey, _localResetVersion);
    }
    final posts = preferences.getString('$_storagePrefix.posts');
    final comments = preferences.getString('$_storagePrefix.comments');
    if (!mounted) return;
    setState(() {
      _localPosts = _decodePosts(posts);
      _localComments = _decodeCommentMap(comments);
    });
  }

  Future<void> _saveLocalState() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$_storagePrefix.posts',
      jsonEncode(_localPosts.map((post) => post.toMap()).toList()),
    );
    await preferences.setString(
      '$_storagePrefix.comments',
      jsonEncode(_localComments),
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      _commentCache = const {};
      setState(() => _future = _load());
    });
  }

  void _configureRealtime() {
    final existing = _channel;
    if (existing != null) {
      Supabase.instance.client.removeChannel(existing);
    }
    final channel = Supabase.instance.client.channel(
        'member-community-feed-${widget.church.id}-${widget.member.id}')
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
        table: 'community_post_shares',
        callback: (_) => _scheduleRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'community_post_saved',
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
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'comunhao',
        table: 'announcements',
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
        table: 'events',
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
        table: 'donation_campaigns',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'church_id',
          value: widget.church.id,
        ),
        callback: (_) => _scheduleRefresh(),
      );
    channel.subscribe();
    _channel = channel;
  }

  Future<void> _createPost() async {
    final title = TextEditingController();
    final body = TextEditingController();
    final imageUrl = TextEditingController();
    final mediaUrl = TextEditingController();
    var type = 'testimony';
    var communitySpace = 'general';
    var mainMediaType = 'text';
    _PickedCommunityMedia? pickedMedia;
    String? urlMediaType;

    final draft = await showDialog<_MemberFeedPost>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Partilhar na Comunhao'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: _communityPostTypeOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option.$1,
                            child: Text(option.$2),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => type = value ?? type),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: communitySpace,
                    decoration: const InputDecoration(labelText: 'Comunidade'),
                    items: _communitySpaceOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option.$1,
                            child: Text(option.$2),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(
                      () => communitySpace = value ?? 'general',
                    ),
                  ),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Titulo'),
                  ),
                  TextField(
                    controller: body,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(labelText: 'Mensagem'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.notes_outlined, size: 18),
                        label: const Text('Apenas texto'),
                        selected: mainMediaType == 'text',
                        onSelected: (_) => setDialogState(() {
                          mainMediaType = 'text';
                          pickedMedia = null;
                          imageUrl.clear();
                          mediaUrl.clear();
                          urlMediaType = null;
                        }),
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.image_outlined, size: 18),
                        label: const Text('Foto'),
                        selected: mainMediaType == 'image',
                        onSelected: (_) => setDialogState(() {
                          mainMediaType = 'image';
                          pickedMedia = null;
                          mediaUrl.clear();
                          urlMediaType = null;
                        }),
                      ),
                      ChoiceChip(
                        avatar: const Icon(
                          Icons.video_library_outlined,
                          size: 18,
                        ),
                        label: const Text('Video'),
                        selected: mainMediaType == 'video',
                        onSelected: (_) => setDialogState(() {
                          mainMediaType = 'video';
                          pickedMedia = null;
                          imageUrl.clear();
                          mediaUrl.clear();
                          urlMediaType = null;
                        }),
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.audio_file_outlined, size: 18),
                        label: const Text('Audio'),
                        selected: mainMediaType == 'audio',
                        onSelected: (_) => setDialogState(() {
                          mainMediaType = 'audio';
                          pickedMedia = null;
                          imageUrl.clear();
                          mediaUrl.clear();
                          urlMediaType = null;
                        }),
                      ),
                      ChoiceChip(
                        avatar:
                            const Icon(Icons.description_outlined, size: 18),
                        label: const Text('Documento'),
                        selected: mainMediaType == 'document',
                        onSelected: (_) => setDialogState(() {
                          mainMediaType = 'document';
                          pickedMedia = null;
                          imageUrl.clear();
                          mediaUrl.clear();
                          urlMediaType = null;
                        }),
                      ),
                    ],
                  ),
                  if (mainMediaType == 'image') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: imageUrl,
                      decoration: const InputDecoration(
                        labelText: 'Imagem URL opcional',
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final file = await _imagePicker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 88,
                        );
                        if (file == null) return;
                        setDialogState(
                          () => pickedMedia = _PickedCommunityMedia(
                            file: file,
                            type: 'image',
                            mimeType: file.mimeType ?? 'image/jpeg',
                          ),
                        );
                      },
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Imagem'),
                    ),
                  ],
                  if (mainMediaType == 'video') ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final file = await _imagePicker.pickVideo(
                          source: ImageSource.gallery,
                        );
                        if (file == null) return;
                        setDialogState(
                          () => pickedMedia = _PickedCommunityMedia(
                            file: file,
                            type: 'video',
                            mimeType: file.mimeType ?? 'video/mp4',
                          ),
                        );
                      },
                      icon: const Icon(Icons.video_library_outlined),
                      label: const Text('Video'),
                    ),
                  ],
                  if (mainMediaType == 'audio') ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: const [
                            'mp3',
                            'm4a',
                            'aac',
                            'wav',
                            'ogg',
                          ],
                          withData: true,
                        );
                        final file = result?.files.single;
                        if (file == null) return;
                        setDialogState(
                          () => pickedMedia =
                              _PickedCommunityMedia.fromPlatformFile(
                            file,
                            type: 'audio',
                            fallbackMimeType: 'audio/mpeg',
                          ),
                        );
                      },
                      icon: const Icon(Icons.audio_file_outlined),
                      label: const Text('Audio'),
                    ),
                  ],
                  if (mainMediaType == 'document') ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: const [
                            'pdf',
                            'doc',
                            'docx',
                            'ppt',
                            'pptx',
                            'xls',
                            'xlsx',
                            'txt',
                          ],
                          withData: true,
                        );
                        final file = result?.files.single;
                        if (file == null) return;
                        setDialogState(
                          () => pickedMedia =
                              _PickedCommunityMedia.fromPlatformFile(
                            file,
                            type: 'document',
                            fallbackMimeType: 'application/octet-stream',
                          ),
                        );
                      },
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Documento'),
                    ),
                  ],
                  if (pickedMedia != null) ...[
                    const SizedBox(height: 8),
                    InputChip(
                      avatar: Icon(
                        pickedMedia!.type == 'video'
                            ? Icons.play_circle_outline
                            : pickedMedia!.type == 'audio'
                                ? Icons.audio_file_outlined
                                : pickedMedia!.type == 'document'
                                    ? Icons.description_outlined
                                    : Icons.image_outlined,
                      ),
                      label: Text(pickedMedia!.file.name),
                      onDeleted: () => setDialogState(() => pickedMedia = null),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'Membros ativos publicam diretamente no Feed da Comunhao. A lideranca pode ocultar conteudo inadequado.',
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
            FilledButton.icon(
              onPressed: () {
                final cleanTitle = title.text.trim();
                final cleanBody = body.text.trim();
                if (cleanBody.length < 3) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Escreve uma mensagem antes de publicar.',
                      ),
                    ),
                  );
                  return;
                }
                final effectiveTitle = cleanTitle.length < 3
                    ? _communityPostTypeLabel(type)
                    : cleanTitle;
                Navigator.of(context).pop(
                  _MemberFeedPost(
                    id: 'local-${DateTime.now().millisecondsSinceEpoch}',
                    type: type,
                    communitySpace: communitySpace,
                    authorName: widget.member.fullName,
                    title: effectiveTitle,
                    body: cleanBody,
                    imageUrl: imageUrl.text.trim().isEmpty
                        ? null
                        : imageUrl.text.trim(),
                    mediaUrl: mediaUrl.text.trim().isEmpty
                        ? null
                        : mediaUrl.text.trim(),
                    mediaType: urlMediaType,
                    pickedMedia: pickedMedia,
                    createdAt: DateTime.now(),
                  ),
                );
              },
              icon: const Icon(Icons.send_outlined),
              label: const Text('Publicar'),
            ),
          ],
        ),
      ),
    );

    title.dispose();
    body.dispose();
    imageUrl.dispose();
    mediaUrl.dispose();

    if (draft == null) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A publicar...')),
      );
    }
    String? uploadedMediaUrl;
    String? uploadedMediaType;
    String? uploadedMediaMimeType;
    String? finalImageUrl = draft.imageUrl;
    String? finalMediaUrl = draft.mediaUrl;
    String? finalMediaType = draft.mediaType;
    if (draft.pickedMedia != null) {
      try {
        final uploaded = await _uploadCommunityMedia(draft.pickedMedia!);
        uploadedMediaUrl = uploaded.url;
        uploadedMediaType = uploaded.type;
        uploadedMediaMimeType = uploaded.mimeType;
        finalMediaUrl = uploadedMediaUrl;
        finalMediaType = uploadedMediaType;
        if (uploaded.type == 'image') {
          finalImageUrl = uploaded.url;
        }
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'N\u00e3o foi poss\u00edvel carregar a m\u00eddia: $error',
            ),
          ),
        );
        return;
      }
    }
    CommunityPost post;
    try {
      post = await _feedRepository.createPost(
        churchId: widget.church.id,
        postType: draft.type,
        title: draft.title,
        body: draft.body,
        imageUrl: finalImageUrl,
        mediaUrl: finalMediaUrl,
        mediaType: finalMediaType,
        mediaMimeType: uploadedMediaMimeType,
        communitySpace: draft.communitySpace,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nao foi possivel publicar no feed da igreja. Confirma a ligacao e tenta novamente. Detalhe: $error',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('${_publishedSuccessMessage(post.postType)} Publicado.')),
    );
    try {
      await _refresh();
    } catch (_) {
      // O post ja foi publicado; uma falha de refresh nao deve virar erro falso.
    }
  }

  Future<void> _showShareSheet(_FeedItem item) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ShareSheet(
        item: item,
        onShare: (target) => _recordShare(item, target),
      ),
    );
  }

  Future<void> _sharePost(_FeedItem item) async {
    try {
      await _showShareSheet(item);
    } catch (_) {
      await _copyLink(item);
    }
  }

  Future<void> _recordShare(_FeedItem item, String target) async {
    final postId = item.communityPostId;
    if (postId == null) return;
    await _feedRepository.recordShare(postId: postId, shareTarget: target);
    if (mounted) {
      await _refresh();
    }
  }

  Future<_UploadedCommunityMedia> _uploadCommunityMedia(
    _PickedCommunityMedia picked,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Authentication required.');
    }
    final bytes = await picked.file.readAsBytes();
    final extension = _extensionForPickedMedia(picked);
    final path =
        '${widget.church.id}/$userId/${DateTime.now().microsecondsSinceEpoch}$extension';
    await Supabase.instance.client.storage.from('community-media').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: picked.mimeType,
            upsert: false,
          ),
        );
    final url =
        Supabase.instance.client.storage.from('community-media').getPublicUrl(
              path,
            );
    return _UploadedCommunityMedia(
      url: url,
      type: picked.type,
      mimeType: picked.mimeType,
    );
  }

  String _extensionForPickedMedia(_PickedCommunityMedia picked) {
    final name = picked.file.name.toLowerCase();
    final match = RegExp(r'\.[a-z0-9]+$').firstMatch(name);
    if (match != null) return match.group(0)!;
    return switch (picked.mimeType) {
      'image/png' => '.png',
      'image/webp' => '.webp',
      'video/quicktime' => '.mov',
      'video/webm' => '.webm',
      'audio/aac' => '.aac',
      'audio/mp4' => '.m4a',
      'audio/ogg' => '.ogg',
      'audio/wav' => '.wav',
      'application/pdf' => '.pdf',
      _ => switch (picked.type) {
          'video' => '.mp4',
          'audio' => '.mp3',
          'document' => '.pdf',
          _ => '.jpg',
        },
    };
  }

  String _commentAuthorName(CommunityComment comment, _FeedItem item) {
    if (comment.profileId == widget.member.id) {
      return widget.member.fullName;
    }
    if (_isChurchCommentActor(comment.profileId, item)) {
      return widget.church.name;
    }
    final knownMember = _knownMembersById[comment.profileId];
    if (knownMember != null) {
      if (_isChurchLeader(knownMember)) return widget.church.name;
      return knownMember.fullName;
    }
    final name = comment.authorName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'Membro da igreja';
  }

  String? _commentAvatarUrl(CommunityComment comment, _FeedItem item) {
    if (comment.profileId == widget.member.id) {
      return widget.member.avatarUrl;
    }
    if (_isChurchCommentActor(comment.profileId, item)) {
      return widget.church.logoUrl ?? comment.authorAvatarUrl;
    }
    final knownMember = _knownMembersById[comment.profileId];
    if (knownMember != null) {
      if (_isChurchLeader(knownMember)) return widget.church.logoUrl;
      return knownMember.avatarUrl;
    }
    final avatar = comment.authorAvatarUrl?.trim();
    if (avatar != null && avatar.isNotEmpty) {
      return avatar;
    }
    return null;
  }

  bool _isChurchCommentActor(String profileId, _FeedItem item) {
    if (profileId.isEmpty) return false;
    if (_churchActorProfileIds.contains(profileId)) return true;
    final knownMember = _knownMembersById[profileId];
    if (knownMember != null) return _isChurchLeader(knownMember);
    final authorProfileId = item.authorProfileId;
    final isDifferentFromPostAuthor = authorProfileId != null &&
        authorProfileId.isNotEmpty &&
        authorProfileId != profileId;
    return item.communityPostId != null && isDifferentFromPostAuthor;
  }

  bool _isChurchLeader(ChurchMember member) {
    return const {'pastor', 'church_admin', 'leader'}.contains(member.role);
  }

  Future<void> _react(_FeedItem item, String reaction) async {
    final postId = item.communityPostId;
    final publicationId = item.publicationId;
    if (postId != null) {
      await _feedRepository.react(postId: postId, reactionType: reaction);
    } else if (publicationId != null) {
      await PublicationRepository().react(publicationId, reaction);
    } else {
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_reactionConfirmation(reaction))),
    );
    await _refresh();
  }

  Future<void> _toggleSaved(_FeedItem item) async {
    final postId = item.communityPostId;
    if (postId == null) return;
    await _feedRepository.setSaved(postId: postId, saved: !item.isSaved);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item.isSaved
              ? 'Publicacao removida dos favoritos.'
              : 'Publicacao guardada nos favoritos.',
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _copyLink(_FeedItem item) async {
    final params = Map<String, String>.from(Uri.base.queryParameters);
    params['share'] = item.shareId;
    params['type'] = item.type;
    final url = Uri.base.replace(queryParameters: params).toString();
    await Clipboard.setData(ClipboardData(text: url));
    await _recordShare(item, 'copy');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copiado.')),
    );
  }

  Future<void> _reportPost(_FeedItem item) async {
    final postId = item.communityPostId;
    if (postId == null) return;
    final controller = TextEditingController();
    var reason = 'inappropriate';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Denunciar publicacao'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Motivo'),
                  items: const [
                    DropdownMenuItem(
                      value: 'inappropriate',
                      child: Text('Conteudo inadequado'),
                    ),
                    DropdownMenuItem(
                      value: 'spam',
                      child: Text('Spam ou publicidade'),
                    ),
                    DropdownMenuItem(
                      value: 'abuse',
                      child: Text('Ofensa ou abuso'),
                    ),
                    DropdownMenuItem(
                      value: 'false_teaching',
                      child: Text('Conteudo doutrinario sensivel'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => reason = value ?? reason),
                ),
                TextField(
                  controller: controller,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Detalhes opcionais',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Denunciar'),
            ),
          ],
        ),
      ),
    );
    final details = controller.text.trim();
    controller.dispose();
    if (confirmed != true) return;
    await _feedRepository.report(
      postId: postId,
      reason: reason,
      details: details.isEmpty ? null : details,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Denuncia enviada para a lideranca.')),
    );
  }

  Future<void> _editPost(_FeedItem item) async {
    final postId = item.communityPostId;
    if (postId == null || item.authorProfileId != widget.member.id) return;
    final title = TextEditingController(text: item.title);
    final body = TextEditingController(text: item.body);
    final imageUrl = TextEditingController(text: item.imageUrl ?? '');
    var communitySpace = item.communitySpace ?? 'general';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar publicacao'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: communitySpace,
                    decoration: const InputDecoration(labelText: 'Comunidade'),
                    items: _communitySpaceOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option.$1,
                            child: Text(option.$2),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(
                      () => communitySpace = value ?? 'general',
                    ),
                  ),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Titulo'),
                  ),
                  TextField(
                    controller: body,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(labelText: 'Mensagem'),
                  ),
                  TextField(
                    controller: imageUrl,
                    decoration:
                        const InputDecoration(labelText: 'Imagem URL opcional'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    final cleanTitle = title.text.trim();
    final cleanBody = body.text.trim();
    final cleanImage = imageUrl.text.trim();
    title.dispose();
    body.dispose();
    imageUrl.dispose();
    if (saved != true || cleanTitle.length < 3 || cleanBody.length < 5) return;
    await _feedRepository.updateOwnPost(
      postId: postId,
      title: cleanTitle,
      body: cleanBody,
      imageUrl: cleanImage.isEmpty ? null : cleanImage,
      mediaUrl: item.mediaUrl,
      mediaType: item.mediaType,
      communitySpace: communitySpace,
    );
    await _refresh();
  }

  Future<void> _deletePost(_FeedItem item) async {
    final postId = item.communityPostId;
    if (postId == null || item.authorProfileId != widget.member.id) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar publicacao'),
        content: Text('Pretendes eliminar "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _feedRepository.deleteOwnPost(postId);
    await _refresh();
  }

  Future<void> _markPrayerAnswered(_FeedItem item) async {
    final postId = item.communityPostId;
    if (postId == null) return;
    await _feedRepository.markPrayerAnswered(postId);
    if (!mounted) return;
    final share = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Oracao respondida'),
        content: const Text(
          'Queres transformar esta resposta em testemunho para edificar a igreja?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Agora nao'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Partilhar testemunho'),
          ),
        ],
      ),
    );
    if (share == true) {
      await _feedRepository.createPost(
        churchId: widget.church.id,
        postType: 'testimony',
        title: 'Oracao respondida: ${item.title}',
        body: 'Deus respondeu esta oracao: ${item.body}',
        imageUrl: item.imageUrl,
      );
    }
    await _refresh();
  }

  Future<void> _openComments(_FeedItem item) async {
    final controller = TextEditingController();
    String? parentCommentId;
    String? replyAuthorName;
    var sending = false;
    final cached = _commentCache[item.id];
    Future<List<dynamic>> commentsFuture;
    if (cached != null) {
      commentsFuture = Future.value(cached);
    } else if (item.communityPostId != null) {
      commentsFuture = _feedRepository.fetchComments(item.communityPostId!);
    } else if (item.publicationId != null) {
      commentsFuture = PublicationRepository().fetchComments(
        item.publicationId!,
      );
    } else {
      commentsFuture = Future.value(const <dynamic>[]);
    }

    Future<void> submit(StateSetter setDialogState) async {
      final text = controller.text.trim();
      if (text.length < 3 || sending) return;
      final postId = item.communityPostId;
      final publicationId = item.publicationId;
      final replyToCommentId = parentCommentId;
      if (postId == null && publicationId == null) {
        final localComments = _localComments[item.id] ?? const <String>[];
        final next = Map<String, List<String>>.from(_localComments);
        next[item.id] = [...localComments, text];
        setState(() => _localComments = next);
        setDialogState(() {});
        controller.clear();
        _saveLocalState();
        return;
      }
      final now = DateTime.now();
      final optimistic = postId != null
          ? CommunityComment(
              id: 'local-${now.microsecondsSinceEpoch}',
              postId: postId,
              profileId: widget.member.id,
              parentCommentId: replyToCommentId,
              authorName: widget.member.fullName,
              authorAvatarUrl: widget.member.avatarUrl,
              body: text,
              createdAt: now,
            )
          : PastoralPublicationComment(
              id: 'local-${now.microsecondsSinceEpoch}',
              publicationId: publicationId!,
              profileId: widget.member.id,
              parentCommentId: replyToCommentId,
              authorName: widget.member.fullName,
              authorAvatarUrl: widget.member.avatarUrl,
              body: text,
              status: 'active',
              createdAt: now,
            );
      final nextComments = [
        ...(_commentCache[item.id] ?? const <dynamic>[]),
        optimistic,
      ];
      _commentCache = {..._commentCache, item.id: nextComments};
      controller.clear();
      parentCommentId = null;
      replyAuthorName = null;
      sending = true;
      setDialogState(() {});
      setState(() {});
      try {
        if (postId != null) {
          await _feedRepository.comment(
            postId: postId,
            body: text,
            parentCommentId: replyToCommentId,
          );
          final fresh = await _feedRepository.fetchComments(postId);
          if (fresh.isNotEmpty) {
            _commentCache = {..._commentCache, item.id: fresh};
          }
        } else {
          await PublicationRepository().comment(
            publicationId: publicationId!,
            body: text,
            parentCommentId: replyToCommentId,
          );
          final fresh = await PublicationRepository().fetchComments(
            publicationId,
          );
          if (fresh.isNotEmpty) {
            _commentCache = {..._commentCache, item.id: fresh};
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Coment\u00e1rio publicado.')),
          );
          setState(() {});
        }
      } catch (_) {
        // Mantem o comentario otimista visivel.
      } finally {
        sending = false;
        setDialogState(() {});
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final localComments = _localComments[item.id] ?? const <String>[];
          return FractionallySizedBox(
            heightFactor: 0.88,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                  child: Row(
                    children: [
                      ExpandableProfileAvatar(
                        avatarUrl: item.authorAvatarUrl,
                        label: item.title,
                        fallbackIcon: item.icon,
                        radius: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            FutureBuilder<List<dynamic>>(
                              future: commentsFuture,
                              builder: (context, snapshot) {
                                final count = (_commentCache[item.id] ??
                                            snapshot.data ??
                                            const <dynamic>[])
                                        .length +
                                    localComments.length;
                                return Text(
                                  count == 1
                                      ? '1 coment\u00e1rio'
                                      : '$count coment\u00e1rios',
                                  style:
                                      Theme.of(context).textTheme.labelMedium,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: FutureBuilder<List<dynamic>>(
                    future: commentsFuture,
                    builder: (context, snapshot) {
                      final remoteComments = _commentCache[item.id] ??
                          snapshot.data ??
                          const <dynamic>[];
                      if (snapshot.hasData && _commentCache[item.id] == null) {
                        _commentCache = {
                          ..._commentCache,
                          item.id: remoteComments,
                        };
                      }
                      if (remoteComments.isEmpty && localComments.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Ainda n\u00e3o existem coment\u00e1rios.',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        );
                      }
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        children: [
                          ...remoteComments.map(
                            (comment) {
                              if (comment is CommunityComment) {
                                return _SocialCommentTile(
                                  authorName: _commentAuthorName(comment, item),
                                  avatarUrl: _commentAvatarUrl(comment, item),
                                  body: comment.body,
                                  createdAt: comment.createdAt,
                                  isReply: comment.parentCommentId != null,
                                  onAmen: () async {
                                    await _feedRepository.reactToComment(
                                      commentId: comment.id,
                                    );
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Am\u00e9m no coment\u00e1rio registado.',
                                        ),
                                      ),
                                    );
                                  },
                                  onReply: () {
                                    parentCommentId = comment.id;
                                    replyAuthorName =
                                        _commentAuthorName(comment, item);
                                    controller.text = '@$replyAuthorName ';
                                    controller.selection =
                                        TextSelection.fromPosition(
                                      TextPosition(
                                        offset: controller.text.length,
                                      ),
                                    );
                                    setDialogState(() {});
                                  },
                                );
                              }
                              final publicationComment =
                                  comment as PastoralPublicationComment;
                              return _SocialCommentTile(
                                authorName: _publicationCommentAuthorName(
                                  publicationComment,
                                  item,
                                ),
                                avatarUrl: _publicationCommentAvatarUrl(
                                  publicationComment,
                                  item,
                                ),
                                body: publicationComment.body,
                                createdAt: publicationComment.createdAt,
                                isReply:
                                    publicationComment.parentCommentId != null,
                              );
                            },
                          ),
                          ...localComments.map(
                            (comment) => _SocialCommentTile(
                              authorName: widget.member.fullName,
                              avatarUrl: widget.member.avatarUrl,
                              body: comment,
                              createdAt: DateTime.now(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (parentCommentId != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InputChip(
                        avatar: const Icon(Icons.reply_outlined, size: 18),
                        label: Text('A responder $replyAuthorName'),
                        onDeleted: () {
                          parentCommentId = null;
                          replyAuthorName = null;
                          setDialogState(() {});
                        },
                      ),
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      10,
                      14,
                      10 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ExpandableProfileAvatar(
                          avatarUrl: widget.member.avatarUrl,
                          label: widget.member.fullName,
                          radius: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => submit(setDialogState),
                            decoration: InputDecoration(
                              hintText: 'Escreva um coment\u00e1rio...',
                              filled: true,
                              fillColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Enviar',
                          onPressed:
                              sending ? null : () => submit(setDialogState),
                          icon: sending
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (mounted) {
      await _refresh();
    }
    controller.dispose();
  }

  Future<void> _openReactions(_FeedItem item) async {
    final postId = item.communityPostId;
    final publicationId = item.publicationId;
    if (postId == null && publicationId == null) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return FutureBuilder<List<dynamic>>(
          future: postId != null
              ? _feedRepository.fetchReactions(postId)
              : PublicationRepository().fetchReactions(publicationId!),
          builder: (context, snapshot) {
            final reactions = snapshot.data ?? const <dynamic>[];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (reactions.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Ainda sem rea\u00e7\u00f5es.'),
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
                  _ReactionPersonTile(
                    authorName: _reactionAuthorName(reaction, item),
                    avatarUrl: _reactionAvatarUrl(reaction, item),
                    reactionLabel: _reactionLabel(_reactionType(reaction)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  String _reactionAuthorName(dynamic reaction, _FeedItem item) {
    if (reaction is CommunityReaction) {
      if (reaction.profileId == widget.member.id) return widget.member.fullName;
      if (_isChurchCommentActor(reaction.profileId, item)) {
        return widget.church.name;
      }
      final name = reaction.authorName?.trim();
      if (name != null && name.isNotEmpty) return name;
    }
    if (reaction is PastoralPublicationReaction) {
      if (_isChurchActor(reaction.profileId, item)) {
        return widget.church.name;
      }
      final name = reaction.authorName?.trim();
      if (name != null && name.isNotEmpty) return name;
      if (reaction.profileId == widget.member.id) return widget.member.fullName;
      final knownMember = _knownMembersById[reaction.profileId];
      if (knownMember != null) return knownMember.fullName;
    }
    return 'Membro da igreja';
  }

  String _publicationCommentAuthorName(
    PastoralPublicationComment comment,
    _FeedItem item,
  ) {
    if (_isChurchActor(comment.profileId, item)) {
      return widget.church.name;
    }
    if (comment.profileId == widget.member.id) {
      return widget.member.fullName;
    }
    final name = comment.authorName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final knownMember = _knownMembersById[comment.profileId];
    if (knownMember != null) return knownMember.fullName;
    return 'Membro da igreja';
  }

  String? _publicationCommentAvatarUrl(
    PastoralPublicationComment comment,
    _FeedItem item,
  ) {
    if (_isChurchActor(comment.profileId, item)) {
      return widget.church.logoUrl ?? comment.authorAvatarUrl;
    }
    if (comment.profileId == widget.member.id) {
      return widget.member.avatarUrl ?? comment.authorAvatarUrl;
    }
    final avatar = comment.authorAvatarUrl?.trim();
    if (avatar != null && avatar.isNotEmpty) return avatar;
    return _knownMembersById[comment.profileId]?.avatarUrl;
  }

  bool _isChurchActor(String profileId, _FeedItem item) {
    if (profileId.isEmpty) return false;
    if (profileId == item.publicationAuthorUserId) return true;
    final knownMember = _knownMembersById[profileId];
    if (item.publicationId != null && knownMember == null) return true;
    return knownMember != null && _isChurchLeader(knownMember);
  }

  String? _reactionAvatarUrl(dynamic reaction, _FeedItem item) {
    if (reaction is CommunityReaction) {
      if (reaction.profileId == widget.member.id) {
        return widget.member.avatarUrl;
      }
      if (_isChurchCommentActor(reaction.profileId, item)) {
        return widget.church.logoUrl ?? reaction.authorAvatarUrl;
      }
      final avatar = reaction.authorAvatarUrl?.trim();
      if (avatar != null && avatar.isNotEmpty) return avatar;
    }
    if (reaction is PastoralPublicationReaction) {
      if (_isChurchActor(reaction.profileId, item)) {
        return widget.church.logoUrl ?? reaction.authorAvatarUrl;
      }
      final avatar = reaction.authorAvatarUrl?.trim();
      if (avatar != null && avatar.isNotEmpty) return avatar;
      if (reaction.profileId == widget.member.id) {
        return widget.member.avatarUrl;
      }
      return _knownMembersById[reaction.profileId]?.avatarUrl;
    }
    return null;
  }

  String _reactionType(dynamic reaction) {
    if (reaction is CommunityReaction) return reaction.reactionType;
    if (reaction is PastoralPublicationReaction) return reaction.reactionType;
    return 'amen';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CommunityFeedData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? _CommunityFeedData.empty;
        final allItems = _buildFeedItems(data);
        final items = _applyFilter(allItems);
        final visibleItems = items.take(30).toList(growable: false);

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SocialFeedComposerBar(
                memberName: widget.member.fullName,
                avatarUrl: widget.member.avatarUrl,
                onCreatePost: _createPost,
                onRefresh: _refresh,
              ),
              const SizedBox(height: 12),
              _FilterChips(
                selected: _filter,
                onSelected: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState != ConnectionState.done)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (items.isEmpty)
                const SectionCard(
                  title: 'Sem atividade ainda',
                  subtitle:
                      'Quando houver oracoes, eventos, publicacoes ou testemunhos, tudo aparece aqui.',
                  child:
                      Text('Comeca por partilhar um testemunho ou gratidao.'),
                )
              else
                ...visibleItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FeedCard(
                      item: item,
                      reaction: item.myReaction,
                      commentCount: [
                            item.commentCount,
                            _commentCache[item.id]?.length ?? 0,
                          ].reduce((a, b) => a > b ? a : b) +
                          (_localComments[item.id]?.length ?? 0),
                      reactionCount: item.reactionCount,
                      prayingCount: item.prayingCount,
                      canMarkAnswered: item.canMarkAnswered(widget.member.id),
                      canManageOwnPost:
                          item.authorProfileId == widget.member.id &&
                              item.communityPostId != null,
                      onReact: (reaction) => _react(item, reaction),
                      onComment: () => _openComments(item),
                      onViewReactions: () => _openReactions(item),
                      onMarkAnswered: () => _markPrayerAnswered(item),
                      onShare: () => _sharePost(item),
                      onCopyLink: () => _copyLink(item),
                      onToggleSaved: () => _toggleSaved(item),
                      onReport: () => _reportPost(item),
                      onEdit: () => _editPost(item),
                      onDelete: () => _deletePost(item),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<_FeedItem> _buildFeedItems(_CommunityFeedData data) {
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
    final items = <_FeedItem>[
      ..._localPosts.map(
        (post) => _FeedItem(
          id: post.id,
          icon: _iconForLocalType(post.type),
          title: post.title,
          body: post.body,
          meta: '${post.authorName} partilhou ${_localTypeLabel(post.type)}',
          date: post.createdAt,
          imageUrl: post.imageUrl,
          mediaUrl: post.mediaUrl,
          mediaType: post.mediaType,
          type: post.type,
          communitySpace: post.communitySpace,
          emphasis: 'Guardado neste dispositivo',
          authorProfileId: widget.member.id,
          authorAvatarUrl: widget.member.avatarUrl,
        ),
      ),
      ...data.ownCommunityPosts.where((post) => post.isPending).map(
            (post) => _FeedItem(
              id: 'own-community-${post.id}',
              communityPostId: post.id,
              icon: _iconForLocalType(post.postType),
              title: post.title,
              body: post.body,
              meta:
                  '${_communityPostTypeLabel(post.postType)} enviado por ${post.authorName ?? 'ti'}',
              date: post.createdAt,
              imageUrl: post.imageUrl,
              mediaUrl: post.mediaUrl,
              mediaType: post.mediaType,
              type: post.postType,
              communitySpace: post.communitySpace,
              emphasis: 'A aguardar moderacao',
              authorProfileId: post.authorProfileId,
              authorAvatarUrl: post.authorAvatarUrl,
              myReaction: post.myReaction,
              reactionCount: post.reactionCount,
              prayingCount: post.prayingCount,
              commentCount: post.commentCount,
              shareCount: post.shareCount,
            ),
          ),
      ...data.communityPosts.map(
        (post) => _FeedItem(
          id: 'community-${post.id}',
          communityPostId: post.id,
          icon: _iconForLocalType(post.postType),
          title: post.title,
          body: post.body,
          meta:
              '${_communityPostTypeLabel(post.postType)} de ${post.authorName ?? 'Membro'}',
          date: post.createdAt,
          imageUrl: post.imageUrl,
          mediaUrl: post.mediaUrl,
          mediaType: post.mediaType,
          type: post.postType,
          communitySpace: post.communitySpace,
          emphasis: post.answeredAt == null ? null : 'Oracao respondida',
          authorProfileId: post.authorProfileId,
          authorAvatarUrl: post.authorAvatarUrl,
          answered: post.answeredAt != null,
          commentsEnabled: post.commentsEnabled,
          isSaved: post.isSaved,
          myReaction: post.myReaction,
          reactionCount: post.reactionCount,
          prayingCount: post.prayingCount,
          commentCount: post.commentCount,
          shareCount: post.shareCount,
        ),
      ),
      ...data.prayerFeed.where((item) => item.visibility != 'private').map(
            (prayer) => _FeedItem(
              id: 'prayer-${prayer.id}',
              icon: Icons.volunteer_activism_outlined,
              title: prayer.title,
              body: prayer.description,
              meta: prayer.anonymousRequest
                  ? 'Pedido de oracao anonimo'
                  : 'Pedido de oracao da comunidade',
              date: prayer.createdAt,
              type: 'prayer',
              emphasis: prayer.status == 'answered'
                  ? 'Oracao respondida'
                  : 'Toque em "Estou orando" para apoiar',
            ),
          ),
      ...data.publications.where((publication) {
        return !mirroredPublicationIds.contains(publication.id);
      }).map(
        (publication) => _FeedItem(
          id: 'publication-${publication.id}',
          publicationId: publication.id,
          publicationAuthorUserId: publication.authorUserId,
          icon: _iconForPastoralPublication(publication.publicationType),
          title: publication.title,
          body: publication.summary ?? publication.content,
          meta: publication.typeLabel,
          date: publication.displayDate,
          imageUrl: publication.coverImageUrl,
          authorAvatarUrl: publication.authorAvatarUrl ?? churchLogoUrl,
          mediaUrl: _publicationMediaUrl(publication),
          mediaType: _publicationMediaType(publication),
          type: 'publication',
          myReaction: publication.myReaction,
          reactionCount: publication.reactionCount,
          commentCount: publication.commentCount,
          commentsEnabled: publication.allowComments,
        ),
      ),
      ...data.announcements.map(
        (announcement) => _FeedItem(
          id: 'announcement-${announcement.id}',
          icon: Icons.campaign_outlined,
          title: announcement.title,
          body: announcement.body,
          meta: announcement.pinned ? 'Anuncio fixado' : 'Anuncio da igreja',
          date: announcement.publishedAt ?? DateTime.now(),
          imageUrl: announcement.imageUrl,
          authorAvatarUrl: churchLogoUrl,
          publicationId: announcement.pastoralPublicationId,
          publicationAuthorUserId:
              publicationsById[announcement.pastoralPublicationId]
                  ?.authorUserId,
          myReaction:
              publicationsById[announcement.pastoralPublicationId]?.myReaction,
          reactionCount: publicationsById[announcement.pastoralPublicationId]
                  ?.reactionCount ??
              0,
          commentCount: publicationsById[announcement.pastoralPublicationId]
                  ?.commentCount ??
              0,
          commentsEnabled: publicationsById[announcement.pastoralPublicationId]
                  ?.allowComments ??
              true,
          type: 'announcement',
        ),
      ),
      ...data.events.map(
        (event) => _FeedItem(
          id: 'event-${event.id}',
          icon: Icons.event_available_outlined,
          title: event.title,
          body: [
            if ((event.description ?? '').trim().isNotEmpty)
              event.description!.trim(),
            if ((event.location ?? '').trim().isNotEmpty)
              'Local: ${event.location}',
            if (event.capacity != null) '${event.capacity} vaga(s)',
            if ((event.registrationFeeMzn ?? 0) > 0)
              'Inscricao: ${formatMoney(event.registrationFeeMzn!, widget.church.defaultCurrency)}',
          ].join('\n'),
          meta: event.eventTypeLabel,
          date: event.createdAt,
          imageUrl: event.coverImageUrl,
          authorAvatarUrl: churchLogoUrl,
          publicationId: event.pastoralPublicationId,
          publicationAuthorUserId:
              publicationsById[event.pastoralPublicationId]?.authorUserId,
          myReaction: publicationsById[event.pastoralPublicationId]?.myReaction,
          reactionCount:
              publicationsById[event.pastoralPublicationId]?.reactionCount ?? 0,
          commentCount:
              publicationsById[event.pastoralPublicationId]?.commentCount ?? 0,
          commentsEnabled:
              publicationsById[event.pastoralPublicationId]?.allowComments ??
                  true,
          type: 'event',
          eventStartsAt: event.startsAt,
          eventEndsAt: event.endsAt,
          emphasis: event.registrationRequired
              ? 'Confirma presenca na aba Eventos'
              : null,
        ),
      ),
      ...data.campaigns.map(
        (campaign) => _FeedItem(
          id: 'campaign-${campaign.id}',
          icon: Icons.campaign_outlined,
          title: campaign.title,
          body: [
            campaign.description ?? 'Campanha ativa da igreja.',
            '${campaign.progressPercent}% - ${formatMoney(campaign.raisedAmount, widget.church.defaultCurrency)} arrecadado',
            if (campaign.targetAmount != null)
              'Meta: ${formatMoney(campaign.targetAmount!, widget.church.defaultCurrency)}',
            '${campaign.contributorCount} contribuinte(s)',
          ].join('\n'),
          meta: 'Campanha da igreja',
          date: campaign.startAt ?? DateTime.now(),
          imageUrl: campaign.imageUrl,
          authorAvatarUrl: churchLogoUrl,
          publicationId: campaign.pastoralPublicationId,
          publicationAuthorUserId:
              publicationsById[campaign.pastoralPublicationId]?.authorUserId,
          myReaction:
              publicationsById[campaign.pastoralPublicationId]?.myReaction,
          reactionCount:
              publicationsById[campaign.pastoralPublicationId]?.reactionCount ??
                  0,
          commentCount:
              publicationsById[campaign.pastoralPublicationId]?.commentCount ??
                  0,
          commentsEnabled:
              publicationsById[campaign.pastoralPublicationId]?.allowComments ??
                  true,
          type: 'campaign',
          emphasis: 'Contribui na aba Contribuicoes',
        ),
      ),
    ];

    final today = DateTime.now();
    final todaysBirthdays = data.birthdays.where((birthday) {
      return birthday.nextBirthday.year == today.year &&
          birthday.nextBirthday.month == today.month &&
          birthday.nextBirthday.day == today.day;
    }).toList(growable: false);
    if (todaysBirthdays.isNotEmpty) {
      items.add(
        _FeedItem(
          id: 'birthdays-${today.toIso8601String().split('T').first}',
          icon: Icons.cake_outlined,
          title: 'Hoje e aniversario de ${todaysBirthdays.length} membro(s)',
          body: todaysBirthdays.map((birthday) => birthday.fullName).join(', '),
          meta: 'Celebra a familia da fe',
          date: today,
          type: 'birthday',
          emphasis: 'Envia uma palavra de carinho',
        ),
      );
    }

    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  List<_FeedItem> _applyFilter(List<_FeedItem> items) {
    return switch (_filter) {
      'prayer' => items.where((item) => item.type == 'prayer').toList(),
      'testimony' => items.where((item) => item.type == 'testimony').toList(),
      'events' => items.where((item) => item.type == 'event').toList(),
      'campaign' => items.where((item) => item.type == 'campaign').toList(),
      'birthdays' => items.where((item) => item.type == 'birthday').toList(),
      'word' => items
          .where((item) =>
              item.type == 'publication' ||
              item.type == 'verse' ||
              item.type == 'reflection')
          .toList(),
      'youth' ||
      'couples' ||
      'women' ||
      'men' ||
      'children' ||
      'worship' ||
      'intercession' ||
      'evangelism' ||
      'missions' ||
      'cells' ||
      'new_converts' =>
        items.where((item) => item.communitySpace == _filter).toList(),
      _ => items,
    };
  }

  IconData _iconForLocalType(String type) {
    return switch (type) {
      'verse' => Icons.menu_book_outlined,
      'reflection' => Icons.lightbulb_outline,
      'photo' => Icons.photo_library_outlined,
      'prayer' => Icons.volunteer_activism_outlined,
      'gratitude' => Icons.favorite_border,
      'evangelism' => Icons.public_outlined,
      'invitation' => Icons.mark_email_read_outlined,
      'video' => Icons.play_circle_outline,
      'audio' => Icons.headphones_outlined,
      'document' => Icons.description_outlined,
      'live_stream' => Icons.live_tv_outlined,
      'external_link' => Icons.link_outlined,
      'announcement' => Icons.campaign_outlined,
      'event' => Icons.event_available_outlined,
      'campaign' => Icons.volunteer_activism_outlined,
      'sermon' => Icons.record_voice_over_outlined,
      'devotional' => Icons.wb_sunny_outlined,
      'bible_study' => Icons.menu_book_outlined,
      'pastoral_message' => Icons.volunteer_activism_outlined,
      'urgent_notice' => Icons.priority_high_outlined,
      _ => Icons.auto_awesome_outlined,
    };
  }

  String _localTypeLabel(String type) {
    return switch (type) {
      'verse' => 'um versiculo',
      'reflection' => 'uma reflexao',
      'photo' => 'uma fotografia',
      'prayer' => 'um pedido de oracao',
      'gratitude' => 'um motivo de gratidao',
      'evangelism' => 'uma acao de evangelismo',
      'invitation' => 'um convite',
      'video' => 'um video',
      'audio' => 'um audio',
      'document' => 'um documento',
      'live_stream' => 'uma transmissao',
      'external_link' => 'um link',
      _ => 'um testemunho',
    };
  }
}

const _communityPostTypeOptions = <(String, String)>[
  ('testimony', 'Testemunho'),
  ('verse', 'Versiculo favorito'),
  ('reflection', 'Reflexao'),
  ('photo', 'Fotografia de evento'),
  ('prayer', 'Pedido de oracao'),
  ('gratitude', 'Gratidao'),
  ('evangelism', 'Evangelismo'),
  ('invitation', 'Convite'),
];

const _communitySpaceOptions = <(String, String)>[
  ('general', 'Geral'),
  ('youth', 'Jovens'),
  ('couples', 'Casais'),
  ('women', 'Mulheres'),
  ('men', 'Homens'),
  ('children', 'Criancas'),
  ('worship', 'Louvor'),
  ('intercession', 'Intercessao'),
  ('evangelism', 'Evangelismo'),
  ('missions', 'Missoes'),
  ('cells', 'Celulas'),
  ('new_converts', 'Novos convertidos'),
];

String _communityPostTypeLabel(String type) {
  return switch (type) {
    'verse' => 'Versiculo favorito',
    'reflection' => 'Reflexao',
    'photo' => 'Fotografia de evento',
    'prayer' => 'Pedido de oracao',
    'gratitude' => 'Gratidao',
    'evangelism' => 'Evangelismo',
    'invitation' => 'Convite',
    'video' => 'Video',
    'audio' => 'Audio',
    'document' => 'Documento',
    'live_stream' => 'Transmissao ao vivo',
    'external_link' => 'Link externo',
    'announcement' => 'Anuncio',
    'event' => 'Evento',
    'campaign' => 'Campanha',
    'sermon' => 'Pregacao',
    'devotional' => 'Devocional',
    'bible_study' => 'Estudo biblico',
    'pastoral_message' => 'Palavra pastoral',
    'urgent_notice' => 'Aviso urgente',
    _ => 'Testemunho',
  };
}

IconData _iconForPastoralPublication(String type) {
  return switch (type) {
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
    _ => Icons.article_outlined,
  };
}

String? _publicationMediaUrl(PastoralPublication publication) {
  final candidates = [
    publication.videoUrl,
    publication.audioUrl,
    publication.documentUrl,
    publication.liveStreamUrl,
    publication.externalUrl,
  ];
  for (final value in candidates) {
    final clean = value?.trim();
    if (clean != null && clean.isNotEmpty) return clean;
  }
  return null;
}

String? _publicationMediaType(PastoralPublication publication) {
  if (publication.videoUrl?.trim().isNotEmpty == true) return 'video';
  if (publication.audioUrl?.trim().isNotEmpty == true) return 'audio';
  if (publication.documentUrl?.trim().isNotEmpty == true) return 'document';
  if (publication.liveStreamUrl?.trim().isNotEmpty == true) {
    return 'live_stream';
  }
  if (publication.externalUrl?.trim().isNotEmpty == true) {
    return 'external_link';
  }
  return null;
}

String? _communitySpaceLabel(String? space) {
  if (space == null) return null;
  for (final option in _communitySpaceOptions) {
    if (option.$1 == space) return option.$2;
  }
  return null;
}

String _publishedSuccessMessage(String type) {
  return switch (type) {
    'verse' => 'Versiculo favorito publicado com sucesso.',
    'reflection' => 'Reflexao publicada com sucesso.',
    'photo' => 'Fotografia de evento publicada com sucesso.',
    'prayer' => 'Pedido de oracao publicado com sucesso.',
    'gratitude' => 'Gratidao publicada com sucesso.',
    'evangelism' => 'Evangelismo publicado com sucesso.',
    'invitation' => 'Convite publicado com sucesso.',
    _ => 'Testemunho publicado com sucesso.',
  };
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
    if (dayDiff == 0) return 'Realizado hoje \u00e0s $time';
    if (dayDiff == -1) return 'Realizado ontem \u00e0s $time';
    return 'Realizado em ${DateFormat('dd MMM').format(start)} \u00e0s $time';
  }
  if (dayDiff == 0) return 'Hoje \u00e0s $time';
  if (dayDiff == 1) return 'Amanh\u00e3 \u00e0s $time';
  if (dayDiff > 1 && dayDiff <= 6) return 'Daqui a $dayDiff dias';
  return '${DateFormat('dd MMM').format(start)} \u00e0s $time';
}

String _eventBadgeLabel(_FeedItem item) {
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
  if (diff == 1) return 'AMANH\u00c3';
  if (diff > 1 && diff <= 6) return 'EM $diff DIAS';
  return DateFormat('dd MMM').format(start).toUpperCase();
}

Color _eventBadgeColor(BuildContext context, _FeedItem item) {
  final label = _eventBadgeLabel(item);
  if (label == 'A DECORRER') return Colors.red.shade700;
  if (label == 'HOJE') return Colors.green.shade700;
  if (label == 'AMANH\u00c3') return Colors.amber.shade800;
  if (label == 'REALIZADO') return Colors.grey.shade700;
  return Colors.blue.shade700;
}

class _EventTimingBadge extends StatelessWidget {
  const _EventTimingBadge({required this.item});

  final _FeedItem item;

  @override
  Widget build(BuildContext context) {
    final color = _eventBadgeColor(context, item);
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

class _SocialFeedComposerBar extends StatelessWidget {
  const _SocialFeedComposerBar({
    required this.memberName,
    required this.onCreatePost,
    required this.onRefresh,
    this.avatarUrl,
  });

  final String memberName;
  final String? avatarUrl;
  final VoidCallback onCreatePost;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ExpandableProfileAvatar(
              avatarUrl: avatarUrl,
              label: memberName,
              radius: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onCreatePost,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Text(
                    'O que deseja partilhar?',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: 'Atualizar',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.item,
    required this.reaction,
    required this.commentCount,
    required this.reactionCount,
    required this.prayingCount,
    required this.canMarkAnswered,
    required this.onReact,
    required this.onComment,
    required this.onViewReactions,
    required this.onMarkAnswered,
    required this.onShare,
    required this.onCopyLink,
    required this.onToggleSaved,
    required this.onReport,
    required this.onEdit,
    required this.onDelete,
    required this.canManageOwnPost,
  });

  final _FeedItem item;
  final String? reaction;
  final int commentCount;
  final int reactionCount;
  final int prayingCount;
  final bool canMarkAnswered;
  final bool canManageOwnPost;
  final ValueChanged<String> onReact;
  final VoidCallback onComment;
  final VoidCallback onViewReactions;
  final VoidCallback onMarkAnswered;
  final VoidCallback onShare;
  final VoidCallback onCopyLink;
  final VoidCallback onToggleSaved;
  final VoidCallback onReport;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  IconData _attachmentIcon(String? mediaType) {
    return switch (mediaType) {
      'audio' => Icons.audio_file_outlined,
      'document' => Icons.description_outlined,
      'live_stream' => Icons.live_tv_outlined,
      _ => Icons.link_outlined,
    };
  }

  String _attachmentLabel(String? mediaType) {
    return switch (mediaType) {
      'audio' => 'Ouvir audio',
      'document' => 'Abrir documento',
      'live_stream' => 'Abrir live',
      _ => 'Abrir link',
    };
  }

  @override
  Widget build(BuildContext context) {
    final authorAvatarUrl = item.authorAvatarUrl?.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ExpandableProfileAvatar(
                avatarUrl: authorAvatarUrl,
                label: item.title,
                fallbackIcon: item.icon,
              ),
              title: Text(item.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.meta}${item.communitySpaceLabel == null ? '' : ' - ${item.communitySpaceLabel}'}',
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _FeedTypeBadge(
                        label: item.typeLabel,
                        icon: item.icon,
                      ),
                      if (item.communitySpaceLabel != null)
                        _FeedTypeBadge(
                          label: item.communitySpaceLabel!,
                          icon: Icons.diversity_3_outlined,
                          muted: true,
                        ),
                    ],
                  ),
                  if (item.eventStartsAt != null) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _EventTimingBadge(item: item),
                        Text(
                          _eventTimingText(
                              item.eventStartsAt!, item.eventEndsAt),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    'Publicado ${_relativeTime(item.date)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            if (item.displayImageUrl != null &&
                item.displayImageUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 190,
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Image.network(
                    item.displayImageUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
            if (item.mediaType == 'video' &&
                item.mediaUrl != null &&
                item.mediaUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              NativeAutoMedia(
                url: item.mediaUrl!,
                kind: NativeAutoMediaKind.video,
                height: 220,
                viewKey: 'community-video-${item.id}',
              ),
            ],
            if (item.mediaType == 'audio' &&
                item.mediaUrl != null &&
                item.mediaUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              NativeAutoMedia(
                url: item.mediaUrl!,
                kind: NativeAutoMediaKind.audio,
                height: 120,
                viewKey: 'community-audio-${item.id}',
              ),
            ],
            if (item.mediaType != null &&
                item.mediaType != 'image' &&
                item.mediaType != 'video' &&
                item.mediaType != 'audio' &&
                item.mediaUrl != null &&
                item.mediaUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => launchUrl(
                  Uri.parse(item.mediaUrl!),
                  mode: LaunchMode.externalApplication,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(_attachmentIcon(item.mediaType)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _attachmentLabel(item.mediaType),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const Icon(Icons.open_in_new_outlined),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              item.body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.28,
                  ),
            ),
            if (item.emphasis != null) ...[
              const SizedBox(height: 10),
              Chip(label: Text(item.emphasis!)),
            ],
            if (item.type == 'prayer') ...[
              const SizedBox(height: 10),
              Chip(
                avatar: const Icon(Icons.volunteer_activism_outlined, size: 18),
                label: Text(
                  prayingCount == 1
                      ? '1 irm\u00e3o est\u00e1 orando'
                      : '$prayingCount irm\u00e3os est\u00e3o orando',
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (reactionCount > 0 || commentCount > 0 || item.shareCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    if (reactionCount > 0)
                      InkWell(
                        onTap: onViewReactions,
                        child: Text(
                          reaction == null
                              ? '\u{1F64F} $reactionCount rea\u00e7\u00e3o(\u00f5es)'
                              : '${_reactionLabel(reaction!)} \u00b7 $reactionCount',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    if (commentCount > 0)
                      Text(
                        commentCount == 1
                            ? '1 coment\u00e1rio'
                            : '$commentCount coment\u00e1rios',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    if (item.shareCount > 0)
                      Text(
                        item.shareCount == 1
                            ? '1 partilha'
                            : '${item.shareCount} partilhas',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: PopupMenuButton<String>(
                    tooltip: 'Reagir',
                    onSelected: onReact,
                    itemBuilder: (context) => [
                      for (final option in _reactionOptions)
                        PopupMenuItem(
                          value: option.key,
                          child: Text(_reactionLabel(option.key)),
                        ),
                    ],
                    child: _FeedActionButton(
                      icon: Icons.volunteer_activism_outlined,
                      label: reaction == null
                          ? 'Am\u00e9m'
                          : _reactionLabel(reaction!)
                              .replaceFirst('\u{1F64F} ', ''),
                      selected: reaction != null,
                    ),
                  ),
                ),
                Expanded(
                  child: _FeedActionButton(
                    icon: Icons.chat_bubble_outline,
                    label: 'Comentar',
                    onTap: item.commentsEnabled ? onComment : null,
                  ),
                ),
                Expanded(
                  child: _FeedActionButton(
                    icon: Icons.ios_share_outlined,
                    label: 'Partilhar',
                    onTap: onShare,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Mais a\u00e7\u00f5es',
                  onSelected: (value) {
                    switch (value) {
                      case 'copy':
                        onCopyLink();
                        break;
                      case 'save':
                        onToggleSaved();
                        break;
                      case 'edit':
                        onEdit();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                      case 'report':
                        onReport();
                        break;
                      case 'answered':
                        onMarkAnswered();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'copy',
                      child: Text('Copiar link'),
                    ),
                    if (item.communityPostId != null)
                      PopupMenuItem(
                        value: 'save',
                        child: Text(item.isSaved
                            ? 'Remover dos favoritos'
                            : 'Guardar nos favoritos'),
                      ),
                    if (canMarkAnswered)
                      const PopupMenuItem(
                        value: 'answered',
                        child: Text('Ora\u00e7\u00e3o respondida'),
                      ),
                    if (canManageOwnPost)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Editar'),
                      ),
                    if (canManageOwnPost)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar'),
                      ),
                    if (item.communityPostId != null && !canManageOwnPost)
                      const PopupMenuItem(
                        value: 'report',
                        child: Text('Denunciar'),
                      ),
                  ],
                ),
              ],
            ),
            if (!item.commentsEnabled) ...[
              const SizedBox(height: 8),
              const Chip(label: Text('Coment\u00e1rios desativados')),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedActionButton extends StatelessWidget {
  const _FeedActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
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
      ),
    );
  }
}

class _SocialCommentTile extends StatelessWidget {
  const _SocialCommentTile({
    required this.authorName,
    required this.body,
    required this.createdAt,
    this.avatarUrl,
    this.isReply = false,
    this.onAmen,
    this.onReply,
  });

  final String authorName;
  final String body;
  final DateTime createdAt;
  final String? avatarUrl;
  final bool isReply;
  final Future<void> Function()? onAmen;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = avatarUrl?.trim();
    return Padding(
      padding: EdgeInsets.only(
        bottom: 10,
        left: isReply ? 38 : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isReply)
            Container(
              width: 2,
              height: 52,
              margin: const EdgeInsets.only(right: 10, top: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ExpandableProfileAvatar(
            avatarUrl: imageUrl,
            label: authorName,
            radius: isReply ? 16 : 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 560),
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
                        Text(
                          authorName,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          body,
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
                        _relativeTime(createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onAmen,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('Am\u00e9m'),
                    ),
                    if (onReply != null)
                      TextButton(
                        onPressed: onReply,
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

class _ReactionPersonTile extends StatelessWidget {
  const _ReactionPersonTile({
    required this.authorName,
    required this.reactionLabel,
    this.avatarUrl,
  });

  final String authorName;
  final String reactionLabel;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ExpandableProfileAvatar(
        avatarUrl: avatarUrl,
        label: authorName,
        radius: 22,
      ),
      title: Text(authorName),
      subtitle: Text(reactionLabel),
    );
  }
}

class _FeedTypeBadge extends StatelessWidget {
  const _FeedTypeBadge({
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
    final color =
        muted ? theme.colorScheme.onSurfaceVariant : feedTypeBadgeColor(label);
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

Color feedTypeBadgeColor(String label) {
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

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({required this.item, required this.onShare});

  final _FeedItem item;
  final Future<void> Function(String target) onShare;

  String get _shareUrl {
    final params = Map<String, String>.from(Uri.base.queryParameters);
    params['share'] = item.shareId;
    params['type'] = item.type;
    return Uri.base.replace(queryParameters: params).toString();
  }

  String get _shareMessage {
    final space = item.communitySpaceLabel;
    final lines = [
      item.title,
      if (space != null) 'Comunidade: $space',
      '',
      item.body,
      '',
      _shareUrl,
    ];
    return lines.join('\n');
  }

  Future<void> _copy(BuildContext context, {bool close = true}) async {
    await Clipboard.setData(ClipboardData(text: _shareMessage));
    await onShare('copy');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link da publicacao copiado.')),
    );
    if (close) Navigator.of(context).pop();
  }

  Future<void> _open(BuildContext context, Uri uri, String target) async {
    await onShare(target);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel abrir esta rede.')),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final encodedText = Uri.encodeComponent(_shareMessage);
    final encodedUrl = Uri.encodeComponent(_shareUrl);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Partilhar publicacao',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Cada publicacao tem um link unico para abrir e partilhar fora do Comunhao.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.link_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SelectableText(
                        _shareUrl,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.25,
              children: [
                _ShareTarget(
                  icon: Icons.link_outlined,
                  label: 'Copiar',
                  onTap: () => _copy(context),
                ),
                _ShareTarget(
                  icon: Icons.chat_outlined,
                  label: 'WhatsApp',
                  onTap: () => _open(
                    context,
                    Uri.parse('https://wa.me/?text=$encodedText'),
                    'whatsapp',
                  ),
                ),
                _ShareTarget(
                  icon: Icons.facebook_outlined,
                  label: 'Facebook',
                  onTap: () => _open(
                    context,
                    Uri.parse(
                      'https://www.facebook.com/sharer/sharer.php?u=$encodedUrl',
                    ),
                    'facebook',
                  ),
                ),
                _ShareTarget(
                  icon: Icons.alternate_email,
                  label: 'X',
                  onTap: () => _open(
                    context,
                    Uri.parse(
                        'https://twitter.com/intent/tweet?text=$encodedText'),
                    'x',
                  ),
                ),
                _ShareTarget(
                  icon: Icons.music_note_outlined,
                  label: 'TikTok',
                  onTap: () async {
                    await _copy(context, close: false);
                    if (!context.mounted) return;
                    await _open(
                      context,
                      Uri.parse('https://www.tiktok.com/'),
                      'tiktok',
                    );
                  },
                ),
                _ShareTarget(
                  icon: Icons.more_horiz,
                  label: 'Outras',
                  onTap: () => _copy(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareTarget extends StatelessWidget {
  const _ShareTarget({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _FeedMetric extends StatelessWidget {
  const _FeedMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const Spacer(),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('all', 'Tudo'),
      ('prayer', 'Ora\u00e7\u00f5es'),
      ('testimony', 'Testemunhos'),
      ('word', 'Palavra'),
      ('events', 'Eventos'),
      ('campaign', 'Campanhas'),
      ('birthdays', 'Anivers\u00e1rios'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters.map((filter) {
        return ChoiceChip(
          selected: selected == filter.$1,
          label: Text(filter.$2),
          onSelected: (_) => onSelected(filter.$1),
        );
      }).toList(),
    );
  }
}

// ignore: unused_element
class _CommunitySpaces extends StatelessWidget {
  const _CommunitySpaces({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const spaces = [
      ('youth', 'Jovens'),
      ('couples', 'Casais'),
      ('women', 'Mulheres'),
      ('men', 'Homens'),
      ('children', 'Crian\u00e7as'),
      ('worship', 'Louvor'),
      ('intercession', 'Intercess\u00e3o'),
      ('evangelism', 'Evangelismo'),
      ('missions', 'Miss\u00f5es'),
      ('cells', 'C\u00e9lulas'),
      ('new_converts', 'Novos convertidos'),
    ];
    return SectionCard(
      title: 'Comunidades',
      subtitle:
          'Espa\u00e7os da igreja para acompanhar grupos e minist\u00e9rios. A sincroniza\u00e7\u00e3o por comunidade entra no pr\u00f3ximo bloco.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: spaces.map((space) {
          return ActionChip(
            avatar: const Icon(Icons.groups_2_outlined, size: 18),
            label: Text(space.$2),
            onPressed: () => onSelected(space.$1),
          );
        }).toList(),
      ),
    );
  }
}

// ignore: unused_element
class _GrowthBadges extends StatelessWidget {
  const _GrowthBadges({required this.data});

  final _CommunityFeedData data;

  @override
  Widget build(BuildContext context) {
    final testimonyCount = data.communityPosts
        .where((post) => post.postType == 'testimony')
        .length;
    final prayerCount =
        data.communityPosts.where((post) => post.postType == 'prayer').length;
    final eventCount = data.events.length;
    final wordCount = data.publications.length;
    final badges = [
      if (wordCount > 0) ('Leitor fiel', Icons.menu_book_outlined),
      if (prayerCount > 0) ('Intercessor', Icons.volunteer_activism_outlined),
      if (eventCount > 0) ('Servo', Icons.handshake_outlined),
      if (testimonyCount > 0) ('Testemunha', Icons.auto_awesome_outlined),
      ('Disc\u00edpulo dedicado', Icons.workspace_premium_outlined),
    ];

    return SectionCard(
      title: 'Conquistas saud\u00e1veis',
      subtitle:
          'Reconhecimentos para incentivar h\u00e1bitos espirituais, sem compara\u00e7\u00e3o entre irm\u00e3os.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: badges.map((badge) {
          return Chip(
            avatar: Icon(badge.$2, size: 18),
            label: Text(badge.$1),
          );
        }).toList(),
      ),
    );
  }
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

const _reactionOptions = <_ReactionOption>[
  _ReactionOption(
    key: 'amen',
    label: '\u{1F64F} Am\u00e9m',
    confirmation: '\u{1F64F} Am\u00e9m.',
  ),
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

String _relativeTime(DateTime value) {
  final difference = DateTime.now().difference(value.toLocal());
  if (difference.inSeconds < 60) return 'agora';
  if (difference.inMinutes < 60) return 'h\u00e1 ${difference.inMinutes} min';
  if (difference.inHours < 24) return 'h\u00e1 ${difference.inHours} h';
  if (difference.inDays == 1) return 'ontem';
  if (difference.inDays < 7) return 'h\u00e1 ${difference.inDays} dias';
  if (difference.inDays < 30) {
    final weeks = (difference.inDays / 7).floor();
    return weeks == 1 ? 'h\u00e1 1 semana' : 'h\u00e1 $weeks semanas';
  }
  final months = (difference.inDays / 30).floor();
  return months == 1 ? 'h\u00e1 1 m\u00eas' : 'h\u00e1 $months meses';
}

class _FeedItem {
  const _FeedItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    required this.meta,
    required this.date,
    required this.type,
    this.publicationId,
    this.publicationAuthorUserId,
    this.authorProfileId,
    this.authorAvatarUrl,
    this.communitySpace,
    this.communityPostId,
    this.imageUrl,
    this.mediaUrl,
    this.mediaType,
    this.eventStartsAt,
    this.eventEndsAt,
    this.emphasis,
    this.myReaction,
    this.answered = false,
    this.commentsEnabled = true,
    this.isSaved = false,
    this.reactionCount = 0,
    this.prayingCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
  });

  final String id;
  final String? communityPostId;
  final String? publicationId;
  final String? publicationAuthorUserId;
  final IconData icon;
  final String title;
  final String body;
  final String meta;
  final DateTime date;
  final String type;
  final String? authorProfileId;
  final String? authorAvatarUrl;
  final String? communitySpace;
  final String? imageUrl;
  final String? mediaUrl;
  final String? mediaType;
  final DateTime? eventStartsAt;
  final DateTime? eventEndsAt;
  final String? emphasis;
  final String? myReaction;
  final bool answered;
  final bool commentsEnabled;
  final bool isSaved;
  final int reactionCount;
  final int prayingCount;
  final int commentCount;
  final int shareCount;

  String get shareId => communityPostId ?? publicationId ?? id;

  String get typeLabel {
    if (type == 'publication') return meta;
    if (type == 'event') return meta;
    if (type == 'campaign') return 'Campanha';
    if (type == 'announcement') return 'Anuncio';
    if (type == 'prayer') return 'Pedido de oracao';
    return _communityPostTypeLabel(type);
  }

  String? get communitySpaceLabel => _communitySpaceLabel(communitySpace);

  String? get displayImageUrl {
    if (mediaType == 'image' && mediaUrl != null && mediaUrl!.isNotEmpty) {
      return mediaUrl;
    }
    return imageUrl;
  }

  bool canMarkAnswered(String currentProfileId) =>
      communityPostId != null &&
      type == 'prayer' &&
      !answered &&
      authorProfileId == currentProfileId;
}

class _MemberFeedPost {
  const _MemberFeedPost({
    required this.id,
    required this.type,
    required this.communitySpace,
    required this.authorName,
    required this.title,
    required this.body,
    this.imageUrl,
    this.mediaUrl,
    this.mediaType,
    this.pickedMedia,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String communitySpace;
  final String authorName;
  final String title;
  final String body;
  final String? imageUrl;
  final String? mediaUrl;
  final String? mediaType;
  final _PickedCommunityMedia? pickedMedia;
  final DateTime createdAt;

  factory _MemberFeedPost.fromMap(Map<String, dynamic> map) {
    return _MemberFeedPost(
      id: (map['id'] as String?) ?? '',
      type: (map['type'] as String?) ?? 'testimony',
      communitySpace: (map['community_space'] as String?) ?? 'general',
      authorName: (map['author_name'] as String?) ?? 'Membro',
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      imageUrl: map['image_url'] as String?,
      mediaUrl: map['media_url'] as String?,
      mediaType: map['media_type'] as String?,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'community_space': communitySpace,
        'author_name': authorName,
        'title': title,
        'body': body,
        'image_url': imageUrl,
        'media_url': mediaUrl,
        'media_type': mediaType,
        'created_at': createdAt.toIso8601String(),
      };
}

class _PickedCommunityMedia {
  const _PickedCommunityMedia({
    required this.file,
    required this.type,
    required this.mimeType,
  });

  factory _PickedCommunityMedia.fromPlatformFile(
    PlatformFile file, {
    required String type,
    required String fallbackMimeType,
  }) {
    final mimeType = _mimeTypeForFile(file.name, fallbackMimeType);
    final bytes = file.bytes;
    final path = file.path;
    if (bytes == null && (path == null || path.isEmpty)) {
      throw StateError('Nao foi possivel ler o ficheiro selecionado.');
    }
    return _PickedCommunityMedia(
      file: bytes == null
          ? XFile(path!, name: file.name, mimeType: mimeType)
          : XFile.fromData(bytes, name: file.name, mimeType: mimeType),
      type: type,
      mimeType: mimeType,
    );
  }

  final XFile file;
  final String type;
  final String mimeType;
}

String _mimeTypeForFile(String name, String fallback) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.m4a')) return 'audio/mp4';
  if (lower.endsWith('.aac')) return 'audio/aac';
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.ogg')) return 'audio/ogg';
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.m4v')) return 'video/x-m4v';
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.webm')) return 'video/webm';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.doc')) return 'application/msword';
  if (lower.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
  if (lower.endsWith('.pptx')) {
    return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
  }
  if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
  if (lower.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  if (lower.endsWith('.txt')) return 'text/plain';
  return fallback;
}

class _UploadedCommunityMedia {
  const _UploadedCommunityMedia({
    required this.url,
    required this.type,
    required this.mimeType,
  });

  final String url;
  final String type;
  final String mimeType;
}

class _CommunityFeedData {
  const _CommunityFeedData({
    required this.announcements,
    required this.events,
    required this.prayerFeed,
    required this.birthdays,
    required this.publications,
    required this.communityPosts,
    required this.ownCommunityPosts,
    required this.campaigns,
    required this.members,
  });

  final List<ChurchAnnouncement> announcements;
  final List<ChurchEvent> events;
  final List<MemberPrayerRequest> prayerFeed;
  final List<ChurchBirthday> birthdays;
  final List<PastoralPublication> publications;
  final List<CommunityPost> communityPosts;
  final List<CommunityPost> ownCommunityPosts;
  final List<DonationCampaign> campaigns;
  final List<ChurchMember> members;

  static const empty = _CommunityFeedData(
    announcements: [],
    events: [],
    prayerFeed: [],
    birthdays: [],
    publications: [],
    communityPosts: [],
    ownCommunityPosts: [],
    campaigns: [],
    members: [],
  );
}

List<_MemberFeedPost> _decodePosts(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => _MemberFeedPost.fromMap(Map<String, dynamic>.from(item)))
        .where((post) => post.id.isNotEmpty && post.title.isNotEmpty)
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

Map<String, List<String>> _decodeCommentMap(String? raw) {
  if (raw == null || raw.isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    return decoded.map((key, value) {
      final comments = value is List
          ? value.map((item) => item.toString()).toList(growable: false)
          : <String>[];
      return MapEntry(key.toString(), comments);
    });
  } catch (_) {
    return const {};
  }
}
