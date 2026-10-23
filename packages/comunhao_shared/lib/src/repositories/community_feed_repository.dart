import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/community_feed_models.dart';

class CommunityFeedRepository {
  CommunityFeedRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _currentUserId => _client.auth.currentUser?.id;

  static const _select = '''
    id,
    church_id,
    author_profile_id,
    author:profiles!community_posts_author_profile_id_fkey (
      full_name,
      phone,
      avatar_url,
      avatar_storage_path
    ),
    post_type,
    title,
    body,
    image_url,
    media_url,
    media_type,
    media_mime_type,
    community_space,
    status,
    moderation_note,
    answered_at,
    pinned_at,
    comments_enabled,
    created_at,
    updated_at
  ''';

  static const _legacySelect = '''
    id,
    church_id,
    author_profile_id,
    author:profiles!community_posts_author_profile_id_fkey (
      full_name,
      phone,
      avatar_url,
      avatar_storage_path
    ),
    post_type,
    title,
    body,
    image_url,
    media_url,
    media_type,
    media_mime_type,
    community_space,
    status,
    moderation_note,
    answered_at,
    created_at,
    updated_at
  ''';

  Future<List<CommunityPost>> fetchFeed(String churchId) async {
    final posts = await _fetchPosts(churchId, statuses: const ['approved']);
    return _hydrateCounts(posts);
  }

  Future<List<CommunityPost>> fetchOwnPosts(String churchId) async {
    final userId = _currentUserId;
    if (userId == null) return const [];
    List<dynamic> rows;
    try {
      rows = await _client
          .from('community_posts')
          .select(_select)
          .eq('church_id', churchId)
          .eq('author_profile_id', userId)
          .neq('status', 'archived')
          .neq('status', 'rejected')
          .order('pinned_at', ascending: false, nullsFirst: false)
          .order('created_at', ascending: false)
          .limit(40);
    } catch (_) {
      rows = await _client
          .from('community_posts')
          .select(_legacySelect)
          .eq('church_id', churchId)
          .eq('author_profile_id', userId)
          .neq('status', 'archived')
          .neq('status', 'rejected')
          .order('created_at', ascending: false)
          .limit(40);
    }
    final posts = rows
        .whereType<Map<String, dynamic>>()
        .map(CommunityPost.fromMap)
        .toList(growable: false);
    return _hydrateCounts(await _hydratePostAvatars(posts));
  }

  Future<List<CommunityPost>> fetchModerationQueue(String churchId) async {
    final posts = await _fetchPosts(
      churchId,
      statuses: const ['pending', 'approved', 'rejected'],
      limit: 120,
    );
    return _hydrateCounts(posts);
  }

  Future<List<CommunityPost>> _fetchPosts(
    String churchId, {
    required List<String> statuses,
    int limit = 80,
  }) async {
    var query = _client
        .from('community_posts')
        .select(_select)
        .eq('church_id', churchId);
    if (statuses.length == 1) {
      query = query.eq('status', statuses.first);
    } else {
      query = query.inFilter('status', statuses);
    }
    List<dynamic> rows;
    try {
      rows = await query
          .order('pinned_at', ascending: false, nullsFirst: false)
          .order('created_at', ascending: false)
          .limit(limit);
    } catch (_) {
      var legacyQuery = _client
          .from('community_posts')
          .select(_legacySelect)
          .eq('church_id', churchId);
      if (statuses.length == 1) {
        legacyQuery = legacyQuery.eq('status', statuses.first);
      } else {
        legacyQuery = legacyQuery.inFilter('status', statuses);
      }
      rows =
          await legacyQuery.order('created_at', ascending: false).limit(limit);
    }
    final posts = rows
        .whereType<Map<String, dynamic>>()
        .map(CommunityPost.fromMap)
        .toList(growable: false);
    return _hydratePostAvatars(posts);
  }

  Future<CommunityPost> createPost({
    required String churchId,
    required String postType,
    required String title,
    required String body,
    String? imageUrl,
    String? mediaUrl,
    String? mediaType,
    String? mediaMimeType,
    String? communitySpace,
  }) async {
    final row = await _client.rpc(
      'create_community_post',
      params: {
        'p_church_id': churchId,
        'p_post_type': postType,
        'p_title': title,
        'p_body': body,
        'p_image_url': imageUrl,
        'p_community_space': communitySpace,
        'p_media_url': mediaUrl,
        'p_media_type': mediaType,
        'p_media_mime_type': mediaMimeType,
      },
    );
    final posts = await _hydrateCounts(
      await _hydratePostAvatars([
        CommunityPost.fromMap(Map<String, dynamic>.from(row as Map)),
      ]),
    );
    return posts.first;
  }

  Future<void> updateOwnPost({
    required String postId,
    required String title,
    required String body,
    String? imageUrl,
    String? mediaUrl,
    String? mediaType,
    String? mediaMimeType,
    String? communitySpace,
  }) async {
    await _client.rpc(
      'update_own_community_post',
      params: {
        'p_post_id': postId,
        'p_title': title,
        'p_body': body,
        'p_image_url': imageUrl,
        'p_community_space': communitySpace,
        'p_media_url': mediaUrl,
        'p_media_type': mediaType,
        'p_media_mime_type': mediaMimeType,
      },
    );
  }

  Future<void> deleteOwnPost(String postId) async {
    await _client.rpc(
      'delete_own_community_post',
      params: {'p_post_id': postId},
    );
  }

  Future<void> moderatePost({
    required String postId,
    required String status,
    String? note,
  }) async {
    await _client.rpc(
      'moderate_community_post',
      params: {
        'p_post_id': postId,
        'p_status': status,
        'p_note': note,
      },
    );
  }

  Future<void> markPrayerAnswered(String postId) async {
    await _client.rpc(
      'mark_community_prayer_answered',
      params: {'p_post_id': postId},
    );
  }

  Future<void> react({
    required String postId,
    required String reactionType,
  }) async {
    await _client.rpc(
      'react_to_community_post',
      params: {
        'p_post_id': postId,
        'p_reaction_type': reactionType,
      },
    );
  }

  Future<void> comment({
    required String postId,
    required String body,
    String? parentCommentId,
  }) async {
    try {
      await _client.rpc(
        'comment_on_community_post',
        params: {
          'p_post_id': postId,
          'p_body': body,
          'p_parent_comment_id': parentCommentId,
        },
      );
    } catch (_) {
      if (parentCommentId != null) rethrow;
      await _client.rpc(
        'comment_on_community_post',
        params: {
          'p_post_id': postId,
          'p_body': body,
        },
      );
    }
  }

  Future<void> recordShare({
    required String postId,
    String shareTarget = 'link',
  }) async {
    try {
      await _client.rpc(
        'record_community_post_share',
        params: {
          'p_post_id': postId,
          'p_share_target': shareTarget,
        },
      );
    } catch (_) {
      // Compatibility with environments where the share-tracking migration
      // has not been applied yet. Sharing the link should still work.
    }
  }

  Future<void> reactToComment({
    required String commentId,
    String reactionType = 'amen',
  }) async {
    await _client.rpc(
      'react_to_community_comment',
      params: {
        'p_comment_id': commentId,
        'p_reaction_type': reactionType,
      },
    );
  }

  Future<void> setSaved({
    required String postId,
    required bool saved,
  }) async {
    await _client.rpc(
      'set_community_post_saved',
      params: {
        'p_post_id': postId,
        'p_saved': saved,
      },
    );
  }

  Future<void> report({
    required String postId,
    required String reason,
    String? details,
  }) async {
    await _client.rpc(
      'report_community_post',
      params: {
        'p_post_id': postId,
        'p_reason': reason,
        'p_details': details,
      },
    );
  }

  Future<void> setPinned({
    required String postId,
    required bool pinned,
  }) async {
    await _client.rpc(
      'set_community_post_pinned',
      params: {
        'p_post_id': postId,
        'p_pinned': pinned,
      },
    );
  }

  Future<void> setCommentsEnabled({
    required String postId,
    required bool enabled,
  }) async {
    await _client.rpc(
      'set_community_post_comments_enabled',
      params: {
        'p_post_id': postId,
        'p_enabled': enabled,
      },
    );
  }

  Future<void> warnAuthor({
    required String postId,
    String? note,
    bool suspend = false,
  }) async {
    await _client.rpc(
      'warn_community_post_author',
      params: {
        'p_post_id': postId,
        'p_note': note,
        'p_suspend': suspend,
      },
    );
  }

  Future<List<CommunityComment>> fetchComments(String postId) async {
    List<dynamic> rows;
    try {
      rows = await _client.rpc(
        'get_community_post_comments',
        params: {'p_post_id': postId},
      );
    } catch (_) {
      try {
        rows = await _client
            .from('community_post_comments')
            .select('''
              id,
              post_id,
              profile_id,
              parent_comment_id,
              profile:profiles(full_name, avatar_url, avatar_storage_path),
              body,
              created_at
            ''')
            .eq('post_id', postId)
            .eq('status', 'visible')
            .order('created_at');
      } catch (_) {
        rows = await _client
            .from('community_post_comments')
            .select('''
              id,
              post_id,
              profile_id,
              profile:profiles(full_name, avatar_url, avatar_storage_path),
              body,
              created_at
            ''')
            .eq('post_id', postId)
            .eq('status', 'visible')
            .order('created_at');
      }
    }
    final comments = rows
        .whereType<Map<String, dynamic>>()
        .map(CommunityComment.fromMap)
        .toList(growable: false);
    return _hydrateCommentAvatars(await _hydrateCommentAuthors(comments));
  }

  Future<List<CommunityReaction>> fetchReactions(String postId) async {
    final rows = await _client.from('community_post_reactions').select('''
          id,
          post_id,
          profile_id,
          reaction_type,
          created_at,
          profile:profiles(full_name, avatar_url, avatar_storage_path)
        ''').eq('post_id', postId).order('created_at', ascending: false);

    final reactions = rows
        .whereType<Map<String, dynamic>>()
        .map(CommunityReaction.fromMap)
        .toList(growable: false);
    return _hydrateReactionAvatars(await _hydrateReactionAuthors(reactions));
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

  Future<List<CommunityPost>> _hydratePostAvatars(
    List<CommunityPost> posts,
  ) async {
    if (posts.isEmpty) return posts;
    return Future.wait(
      posts.map((post) async {
        if (post.authorAvatarUrl?.trim().isNotEmpty == true) return post;
        final signedUrl =
            await _signedProfileMediaUrl(post.authorAvatarStoragePath);
        if (signedUrl == null) return post;
        return CommunityPost(
          id: post.id,
          churchId: post.churchId,
          authorProfileId: post.authorProfileId,
          authorName: post.authorName,
          authorAvatarUrl: signedUrl,
          authorAvatarStoragePath: post.authorAvatarStoragePath,
          postType: post.postType,
          title: post.title,
          body: post.body,
          imageUrl: post.imageUrl,
          mediaUrl: post.mediaUrl,
          mediaType: post.mediaType,
          mediaMimeType: post.mediaMimeType,
          communitySpace: post.communitySpace,
          status: post.status,
          moderationNote: post.moderationNote,
          answeredAt: post.answeredAt,
          pinnedAt: post.pinnedAt,
          commentsEnabled: post.commentsEnabled,
          createdAt: post.createdAt,
          updatedAt: post.updatedAt,
          reactionCount: post.reactionCount,
          prayingCount: post.prayingCount,
          commentCount: post.commentCount,
          shareCount: post.shareCount,
          reportCount: post.reportCount,
          isSaved: post.isSaved,
          myReaction: post.myReaction,
        );
      }),
    );
  }

  Future<List<CommunityComment>> _hydrateCommentAvatars(
    List<CommunityComment> comments,
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
        return CommunityComment(
          id: comment.id,
          postId: comment.postId,
          profileId: comment.profileId,
          authorName: comment.authorName,
          authorAvatarUrl: signedUrl,
          authorAvatarStoragePath: comment.authorAvatarStoragePath,
          parentCommentId: comment.parentCommentId,
          body: comment.body,
          createdAt: comment.createdAt,
        );
      }),
    );
  }

  Future<List<CommunityComment>> _hydrateCommentAuthors(
    List<CommunityComment> comments,
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
        return CommunityComment(
          id: comment.id,
          postId: comment.postId,
          profileId: comment.profileId,
          authorName: profile['full_name'] as String? ?? comment.authorName,
          authorAvatarUrl:
              profile['avatar_url'] as String? ?? comment.authorAvatarUrl,
          authorAvatarStoragePath: profile['avatar_storage_path'] as String? ??
              comment.authorAvatarStoragePath,
          parentCommentId: comment.parentCommentId,
          body: comment.body,
          createdAt: comment.createdAt,
        );
      }).toList(growable: false);
    } catch (_) {
      return comments;
    }
  }

  Future<List<CommunityReaction>> _hydrateReactionAvatars(
    List<CommunityReaction> reactions,
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
        return CommunityReaction(
          id: reaction.id,
          postId: reaction.postId,
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

  Future<List<CommunityReaction>> _hydrateReactionAuthors(
    List<CommunityReaction> reactions,
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
        return CommunityReaction(
          id: reaction.id,
          postId: reaction.postId,
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

  Future<List<CommunityPost>> _hydrateCounts(List<CommunityPost> posts) async {
    if (posts.isEmpty) return posts;
    final ids = posts.map((post) => post.id).toList(growable: false);
    final results = await Future.wait<dynamic>([
      _client
          .from('community_post_reactions')
          .select('post_id, reaction_type')
          .inFilter(
            'post_id',
            ids,
          ),
      _client
          .from('community_post_comments')
          .select('post_id')
          .inFilter('post_id', ids)
          .eq('status', 'visible'),
      _currentUserId == null
          ? Future.value(<dynamic>[])
          : _client
              .from('community_post_reactions')
              .select('post_id, reaction_type')
              .inFilter('post_id', ids)
              .eq('profile_id', _currentUserId!),
      _fetchSavedRows(ids),
      _fetchReportRows(ids),
      _fetchShareRows(ids),
    ]);

    final reactionCounts = _countByPost(results[0] as List<dynamic>);
    final prayingCounts =
        _countByPost(results[0] as List<dynamic>, reactionType: 'praying');
    final commentCounts = _countByPost(results[1] as List<dynamic>);
    final reportCounts = _countByPost(results[4] as List<dynamic>);
    final shareCounts = _countByPost(results[5] as List<dynamic>);
    final myReactions = <String, String>{};
    for (final row in (results[2] as List<dynamic>).whereType<Map>()) {
      final postId = row['post_id'] as String?;
      final reaction = row['reaction_type'] as String?;
      if (postId != null && reaction != null) {
        myReactions[postId] = reaction;
      }
    }
    final savedIds = (results[3] as List<dynamic>)
        .whereType<Map>()
        .map((row) => row['post_id'] as String?)
        .whereType<String>()
        .toSet();

    return posts
        .map(
          (post) => CommunityPost(
            id: post.id,
            churchId: post.churchId,
            authorProfileId: post.authorProfileId,
            authorName: post.authorName,
            authorAvatarUrl: post.authorAvatarUrl,
            authorAvatarStoragePath: post.authorAvatarStoragePath,
            postType: post.postType,
            title: post.title,
            body: post.body,
            imageUrl: post.imageUrl,
            mediaUrl: post.mediaUrl,
            mediaType: post.mediaType,
            mediaMimeType: post.mediaMimeType,
            communitySpace: post.communitySpace,
            status: post.status,
            moderationNote: post.moderationNote,
            answeredAt: post.answeredAt,
            pinnedAt: post.pinnedAt,
            commentsEnabled: post.commentsEnabled,
            createdAt: post.createdAt,
            updatedAt: post.updatedAt,
            reactionCount: reactionCounts[post.id] ?? 0,
            prayingCount: prayingCounts[post.id] ?? 0,
            commentCount: commentCounts[post.id] ?? 0,
            shareCount: shareCounts[post.id] ?? 0,
            reportCount: reportCounts[post.id] ?? 0,
            isSaved: savedIds.contains(post.id),
            myReaction: myReactions[post.id],
          ),
        )
        .toList(growable: false);
  }

  Map<String, int> _countByPost(
    List<dynamic> rows, {
    String? reactionType,
  }) {
    final counts = <String, int>{};
    for (final row in rows.whereType<Map>()) {
      if (reactionType != null && row['reaction_type'] != reactionType) {
        continue;
      }
      final postId = row['post_id'] as String?;
      if (postId == null) continue;
      counts[postId] = (counts[postId] ?? 0) + 1;
    }
    return counts;
  }

  Future<List<dynamic>> _fetchSavedRows(List<String> ids) async {
    final userId = _currentUserId;
    if (userId == null) return <dynamic>[];
    try {
      return await _client
          .from('community_post_saved')
          .select('post_id')
          .inFilter('post_id', ids)
          .eq('profile_id', userId);
    } catch (_) {
      return <dynamic>[];
    }
  }

  Future<List<dynamic>> _fetchReportRows(List<String> ids) async {
    try {
      return await _client
          .from('community_post_reports')
          .select('post_id')
          .inFilter('post_id', ids)
          .neq('status', 'dismissed');
    } catch (_) {
      return <dynamic>[];
    }
  }

  Future<List<dynamic>> _fetchShareRows(List<String> ids) async {
    try {
      return await _client
          .from('community_post_shares')
          .select('post_id')
          .inFilter('post_id', ids);
    } catch (_) {
      return <dynamic>[];
    }
  }
}
