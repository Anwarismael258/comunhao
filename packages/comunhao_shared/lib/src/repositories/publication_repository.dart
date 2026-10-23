import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pastoral_publication.dart';

class PublicationDraft {
  const PublicationDraft({
    this.id,
    required this.churchId,
    required this.title,
    required this.summary,
    required this.content,
    required this.publicationType,
    required this.category,
    this.coverImageUrl,
    this.audioUrl,
    this.videoUrl,
    this.documentUrl,
    this.liveStreamUrl,
    this.externalUrl,
    required this.status,
    required this.visibility,
    required this.priority,
    this.publishedAt,
    this.scheduledAt,
    this.expiresAt,
    required this.allowComments,
    required this.allowReactions,
    required this.allowSharing,
    required this.sendNotification,
    required this.isFeatured,
    required this.isPinned,
  });

  final String? id;
  final String churchId;
  final String title;
  final String summary;
  final String content;
  final String publicationType;
  final String category;
  final String? coverImageUrl;
  final String? audioUrl;
  final String? videoUrl;
  final String? documentUrl;
  final String? liveStreamUrl;
  final String? externalUrl;
  final String status;
  final String visibility;
  final String priority;
  final DateTime? publishedAt;
  final DateTime? scheduledAt;
  final DateTime? expiresAt;
  final bool allowComments;
  final bool allowReactions;
  final bool allowSharing;
  final bool sendNotification;
  final bool isFeatured;
  final bool isPinned;
}

class PublicationRepository {
  PublicationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _currentUserId => _client.auth.currentUser?.id;

  static const _select = '''
    id,
    church_id,
    author_user_id,
    author:profiles!pastoral_publications_author_user_id_fkey (
      full_name,
      avatar_url,
      avatar_storage_path
    ),
    title,
    slug,
    summary,
    content,
    publication_type,
    category,
    cover_image_url,
    audio_url,
    video_url,
    document_url,
    live_stream_url,
    external_url,
    status,
    visibility,
    priority,
    published_at,
    scheduled_at,
    expires_at,
    allow_comments,
    allow_reactions,
    allow_sharing,
    send_notification,
    is_featured,
    is_pinned,
    is_demo,
    created_at,
    updated_at
  ''';

  Future<List<PastoralPublication>> fetchManagedPublications(
    String churchId,
  ) async {
    try {
      final rows = await _client.rpc(
        'get_manageable_pastoral_publications',
        params: {'p_church_id': churchId},
      );

      final publications = (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(PastoralPublication.fromMap)
          .toList(growable: false);
      return _hydrateAuthors(publications);
    } catch (_) {
      final rows = await _client
          .from('pastoral_publications')
          .select(_select)
          .eq('church_id', churchId)
          .order('created_at', ascending: false);

      final publications = rows
          .whereType<Map<String, dynamic>>()
          .map(PastoralPublication.fromMap)
          .toList(growable: false);
      return _hydrateAuthors(publications);
    }
  }

  Future<List<PastoralPublication>> fetchPlatformPublications({
    int limit = 100,
  }) async {
    final rows = await _client
        .from('pastoral_publications')
        .select(_select)
        .order('created_at', ascending: false)
        .limit(limit);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(PastoralPublication.fromMap)
        .toList(growable: false);
  }

  Future<List<PastoralPublication>> fetchMemberFeed(
    String churchId, {
    String? type,
    bool savedOnly = false,
    bool unreadOnly = false,
    int limit = 80,
  }) async {
    final rows = await _client
        .from('pastoral_publications')
        .select(_select)
        .eq('church_id', churchId)
        .eq('status', 'published')
        .lte('published_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(limit);

    final publications = rows
        .whereType<Map<String, dynamic>>()
        .where((row) => type == null || row['publication_type'] == type)
        .map(PastoralPublication.fromMap)
        .toList(growable: false);

    final hydrated = await _hydrateAuthors(publications);
    return _hydrateMemberFlags(
      hydrated,
      savedOnly: savedOnly,
      unreadOnly: unreadOnly,
    );
  }

  Future<PastoralPublication?> fetchPublication(String publicationId) async {
    final row = await _client
        .from('pastoral_publications')
        .select(_select)
        .eq('id', publicationId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    final hydratedAuthors = await _hydrateAuthors([
      PastoralPublication.fromMap(row),
    ]);
    final publications = await _hydrateMemberFlags(hydratedAuthors);
    return publications.isEmpty ? null : publications.first;
  }

  Future<List<PastoralPublication>> _hydrateAuthors(
    List<PastoralPublication> publications,
  ) async {
    final missingAuthorIds = publications
        .where((publication) =>
            publication.authorUserId != null &&
            publication.authorUserId!.isNotEmpty &&
            ((publication.authorName?.trim().isEmpty ?? true) ||
                (publication.authorAvatarUrl?.trim().isEmpty ?? true)))
        .map((publication) => publication.authorUserId!)
        .toSet()
        .toList(growable: false);

    if (missingAuthorIds.isEmpty) {
      return _hydratePublicationAvatars(publications);
    }

    final rows = await _client
        .from('profiles')
        .select('id, full_name, avatar_url, avatar_storage_path')
        .inFilter('id', missingAuthorIds);
    final profiles = {
      for (final row in rows.whereType<Map<String, dynamic>>())
        row['id'] as String: row,
    };

    final hydrated = publications.map((publication) {
      final profile = profiles[publication.authorUserId];
      if (profile == null) {
        return publication;
      }
      final storagePath = profile['avatar_storage_path'] as String?;
      return publication.copyWith(
        authorName: profile['full_name'] as String?,
        authorAvatarUrl: profile['avatar_url'] as String?,
        authorAvatarStoragePath: storagePath,
      );
    }).toList(growable: false);
    return _hydratePublicationAvatars(hydrated);
  }

  Future<String?> _signedProfileMediaUrl(String? storagePath) async {
    final path = storagePath?.trim();
    if (path == null || path.isEmpty) return null;
    try {
      return _client.storage.from('profile-media').createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  Future<List<PastoralPublication>> _hydratePublicationAvatars(
    List<PastoralPublication> publications,
  ) async {
    if (publications.isEmpty) return publications;
    return Future.wait(
      publications.map((publication) async {
        if (publication.authorAvatarUrl?.trim().isNotEmpty == true) {
          return publication;
        }
        final signedUrl =
            await _signedProfileMediaUrl(publication.authorAvatarStoragePath);
        if (signedUrl == null) return publication;
        return publication.copyWith(authorAvatarUrl: signedUrl);
      }),
    );
  }

  Future<PastoralPublication> savePublication(PublicationDraft draft) async {
    final now = DateTime.now().toUtc();
    final effectivePublishedAt = draft.status == 'published'
        ? draft.publishedAt ?? now
        : draft.publishedAt;
    final slug = _slugify(draft.title);
    final payload = <String, dynamic>{
      'church_id': draft.churchId,
      'title': draft.title.trim(),
      'slug': draft.id == null ? '$slug-${now.millisecondsSinceEpoch}' : slug,
      'summary': _nullIfBlank(draft.summary),
      'content': draft.content.trim(),
      'publication_type': draft.publicationType,
      'category':
          draft.category.trim().isEmpty ? 'geral' : draft.category.trim(),
      'cover_image_url': _nullIfBlank(draft.coverImageUrl),
      'audio_url': _nullIfBlank(draft.audioUrl),
      'video_url': _nullIfBlank(draft.videoUrl),
      'document_url': _nullIfBlank(draft.documentUrl),
      'live_stream_url': _nullIfBlank(draft.liveStreamUrl),
      'external_url': _nullIfBlank(draft.externalUrl),
      'status': draft.status,
      'visibility': draft.visibility,
      'priority': draft.priority,
      'published_at': effectivePublishedAt?.toIso8601String(),
      'scheduled_at': draft.scheduledAt?.toUtc().toIso8601String(),
      'expires_at': draft.expiresAt?.toUtc().toIso8601String(),
      'allow_comments': draft.allowComments,
      'allow_reactions': draft.allowReactions,
      'allow_sharing': draft.allowSharing,
      'send_notification': draft.sendNotification,
      'is_featured': draft.isFeatured,
      'is_pinned': draft.isPinned,
      if (draft.id == null && _currentUserId != null)
        'author_user_id': _currentUserId,
    };

    final row = draft.id == null
        ? await _client
            .from('pastoral_publications')
            .insert(payload)
            .select(_select)
            .single()
        : await _client
            .from('pastoral_publications')
            .update(payload)
            .eq('id', draft.id!)
            .select(_select)
            .single();

    return PastoralPublication.fromMap(row);
  }

  Future<PastoralPublication> duplicatePublication(
    PastoralPublication publication,
  ) {
    return savePublication(
      PublicationDraft(
        churchId: publication.churchId,
        title: '${publication.title} (copia)',
        summary: publication.summary ?? '',
        content: publication.content,
        publicationType: publication.publicationType,
        category: publication.category,
        coverImageUrl: publication.coverImageUrl,
        audioUrl: publication.audioUrl,
        videoUrl: publication.videoUrl,
        documentUrl: publication.documentUrl,
        liveStreamUrl: publication.liveStreamUrl,
        externalUrl: publication.externalUrl,
        status: 'draft',
        visibility: publication.visibility,
        priority: publication.priority,
        allowComments: publication.allowComments,
        allowReactions: publication.allowReactions,
        allowSharing: publication.allowSharing,
        sendNotification: false,
        isFeatured: false,
        isPinned: false,
      ),
    );
  }

  Future<void> archivePublication(String publicationId) async {
    await _client
        .from('pastoral_publications')
        .update({'status': 'archived'}).eq('id', publicationId);
  }

  Future<void> cancelPublication(String publicationId) async {
    await _client
        .from('pastoral_publications')
        .update({'status': 'cancelled'}).eq('id', publicationId);
  }

  Future<void> recordRead(String publicationId, {int readPercent = 100}) async {
    await _client.rpc(
      'record_pastoral_publication_read',
      params: {
        'p_publication_id': publicationId,
        'p_read_percent': readPercent,
      },
    );
  }

  Future<void> setSaved(String publicationId, bool saved) async {
    await _client.rpc(
      'toggle_pastoral_publication_saved',
      params: {
        'p_publication_id': publicationId,
        'p_saved': saved,
      },
    );
  }

  Future<void> react(String publicationId, String reactionType) async {
    await _client.rpc(
      'react_to_pastoral_publication',
      params: {
        'p_publication_id': publicationId,
        'p_reaction_type': reactionType,
      },
    );
  }

  Future<void> comment({
    required String publicationId,
    required String body,
    String? parentCommentId,
  }) async {
    await _client.rpc(
      'comment_on_pastoral_publication',
      params: {
        'p_publication_id': publicationId,
        'p_body': body,
        'p_parent_comment_id': parentCommentId,
      },
    );
  }

  Future<List<PastoralPublicationComment>> fetchComments(
    String publicationId,
  ) async {
    List<dynamic> rows;
    try {
      rows = await _client.rpc(
        'get_pastoral_publication_comments',
        params: {'p_publication_id': publicationId},
      );
    } catch (_) {
      rows = await _client
          .from('pastoral_publication_comments')
          .select('''
            id,
            publication_id,
            profile_id,
            parent_comment_id,
            body,
            status,
            created_at,
            profile:profiles (
              full_name,
              avatar_url,
              avatar_storage_path
            )
          ''')
          .eq('publication_id', publicationId)
          .eq('status', 'active')
          .order('created_at');
    }

    final comments = rows
        .whereType<Map<String, dynamic>>()
        .map(PastoralPublicationComment.fromMap)
        .toList(growable: false);
    return _hydrateCommentAvatars(await _hydrateCommentAuthors(comments));
  }

  Future<List<PastoralPublicationReaction>> fetchReactions(
    String publicationId,
  ) async {
    final rows = await _client
        .from('pastoral_publication_reactions')
        .select('''
          id,
          publication_id,
          profile_id,
          reaction_type,
          created_at,
          profile:profiles (
            full_name,
            avatar_url,
            avatar_storage_path
          )
        ''')
        .eq('publication_id', publicationId)
        .order('created_at', ascending: false);

    final reactions = rows
        .whereType<Map<String, dynamic>>()
        .map(PastoralPublicationReaction.fromMap)
        .toList(growable: false);
    return _hydrateReactionAvatars(await _hydrateReactionAuthors(reactions));
  }

  Future<List<PastoralPublicationComment>> _hydrateCommentAvatars(
    List<PastoralPublicationComment> comments,
  ) async {
    if (comments.isEmpty) return comments;
    return Future.wait(
      comments.map((comment) async {
        if (comment.authorAvatarUrl?.trim().isNotEmpty == true) {
          return comment;
        }
        final signedUrl =
            await _signedProfileMediaUrl(comment.authorAvatarStoragePath);
        if (signedUrl == null) return comment;
        return PastoralPublicationComment(
          id: comment.id,
          publicationId: comment.publicationId,
          profileId: comment.profileId,
          authorName: comment.authorName,
          authorAvatarUrl: signedUrl,
          authorAvatarStoragePath: comment.authorAvatarStoragePath,
          parentCommentId: comment.parentCommentId,
          body: comment.body,
          status: comment.status,
          createdAt: comment.createdAt,
        );
      }),
    );
  }

  Future<List<PastoralPublicationComment>> _hydrateCommentAuthors(
    List<PastoralPublicationComment> comments,
  ) async {
    final missingIds = comments
        .where((comment) => (comment.authorName ?? '').trim().isEmpty)
        .map((comment) => comment.profileId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (missingIds.isEmpty) return comments;
    try {
      final rows = await _client
          .from('profiles')
          .select('id, full_name, avatar_url, avatar_storage_path')
          .inFilter('id', missingIds);
      final profiles = {
        for (final row in rows.whereType<Map<String, dynamic>>())
          row['id'] as String: row,
      };
      return comments.map((comment) {
        final profile = profiles[comment.profileId];
        if (profile == null) return comment;
        return PastoralPublicationComment(
          id: comment.id,
          publicationId: comment.publicationId,
          profileId: comment.profileId,
          authorName: profile['full_name'] as String? ?? comment.authorName,
          authorAvatarUrl:
              profile['avatar_url'] as String? ?? comment.authorAvatarUrl,
          authorAvatarStoragePath: profile['avatar_storage_path'] as String? ??
              comment.authorAvatarStoragePath,
          parentCommentId: comment.parentCommentId,
          body: comment.body,
          status: comment.status,
          createdAt: comment.createdAt,
        );
      }).toList(growable: false);
    } catch (_) {
      return comments;
    }
  }

  Future<List<PastoralPublicationReaction>> _hydrateReactionAvatars(
    List<PastoralPublicationReaction> reactions,
  ) async {
    if (reactions.isEmpty) return reactions;
    return Future.wait(
      reactions.map((reaction) async {
        if (reaction.authorAvatarUrl?.trim().isNotEmpty == true) {
          return reaction;
        }
        final signedUrl =
            await _signedProfileMediaUrl(reaction.authorAvatarStoragePath);
        if (signedUrl == null) return reaction;
        return PastoralPublicationReaction(
          id: reaction.id,
          publicationId: reaction.publicationId,
          profileId: reaction.profileId,
          authorName: reaction.authorName,
          authorAvatarUrl: signedUrl,
          authorAvatarStoragePath: reaction.authorAvatarStoragePath,
          reactionType: reaction.reactionType,
          createdAt: reaction.createdAt,
        );
      }),
    );
  }

  Future<List<PastoralPublicationReaction>> _hydrateReactionAuthors(
    List<PastoralPublicationReaction> reactions,
  ) async {
    final missingIds = reactions
        .where((reaction) => (reaction.authorName ?? '').trim().isEmpty)
        .map((reaction) => reaction.profileId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (missingIds.isEmpty) return reactions;
    try {
      final rows = await _client
          .from('profiles')
          .select('id, full_name, avatar_url, avatar_storage_path')
          .inFilter('id', missingIds);
      final profiles = {
        for (final row in rows.whereType<Map<String, dynamic>>())
          row['id'] as String: row,
      };
      return reactions.map((reaction) {
        final profile = profiles[reaction.profileId];
        if (profile == null) return reaction;
        return PastoralPublicationReaction(
          id: reaction.id,
          publicationId: reaction.publicationId,
          profileId: reaction.profileId,
          authorName: profile['full_name'] as String? ?? reaction.authorName,
          authorAvatarUrl:
              profile['avatar_url'] as String? ?? reaction.authorAvatarUrl,
          authorAvatarStoragePath: profile['avatar_storage_path'] as String? ??
              reaction.authorAvatarStoragePath,
          reactionType: reaction.reactionType,
          createdAt: reaction.createdAt,
        );
      }).toList(growable: false);
    } catch (_) {
      return reactions;
    }
  }

  Future<void> moderateComment({
    required String commentId,
    String status = 'hidden',
  }) async {
    await _client
        .from('pastoral_publication_comments')
        .update({'status': status}).eq('id', commentId);
  }

  Future<List<PastoralPublication>> _hydrateMemberFlags(
    List<PastoralPublication> publications, {
    bool savedOnly = false,
    bool unreadOnly = false,
  }) async {
    final userId = _currentUserId;
    if (userId == null || publications.isEmpty) {
      return publications;
    }

    final ids = publications.map((item) => item.id).toList(growable: false);
    final savedRows = await _client
        .from('pastoral_publication_saved')
        .select('publication_id')
        .eq('profile_id', userId)
        .inFilter('publication_id', ids);
    final readRows = await _client
        .from('pastoral_publication_reads')
        .select('publication_id')
        .eq('profile_id', userId)
        .inFilter('publication_id', ids);
    final reactionRows = await _client
        .from('pastoral_publication_reactions')
        .select('publication_id, reaction_type')
        .eq('profile_id', userId)
        .inFilter('publication_id', ids);

    final savedIds = savedRows
        .whereType<Map<String, dynamic>>()
        .map((row) => row['publication_id'] as String?)
        .whereType<String>()
        .toSet();
    final readIds = readRows
        .whereType<Map<String, dynamic>>()
        .map((row) => row['publication_id'] as String?)
        .whereType<String>()
        .toSet();
    final reactions = <String, String>{};
    for (final row in reactionRows.whereType<Map<String, dynamic>>()) {
      final publicationId = row['publication_id'] as String?;
      final reactionType = row['reaction_type'] as String?;
      if (publicationId != null && reactionType != null) {
        reactions[publicationId] = reactionType;
      }
    }

    return publications
        .map(
          (item) => item.copyWith(
            isSaved: savedIds.contains(item.id),
            isRead: readIds.contains(item.id),
            myReaction: reactions[item.id],
          ),
        )
        .where((item) => !savedOnly || item.isSaved)
        .where((item) => !unreadOnly || !item.isRead)
        .toList(growable: false);
  }

  static String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static String _slugify(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return normalized.isEmpty ? 'publicacao' : normalized;
  }
}
