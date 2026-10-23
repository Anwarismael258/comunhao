class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.churchId,
    required this.authorProfileId,
    this.authorName,
    this.authorAvatarUrl,
    this.authorAvatarStoragePath,
    required this.postType,
    required this.title,
    required this.body,
    this.imageUrl,
    this.mediaUrl,
    this.mediaType,
    this.mediaMimeType,
    this.communitySpace,
    required this.status,
    this.moderationNote,
    this.answeredAt,
    this.pinnedAt,
    required this.commentsEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.reactionCount = 0,
    this.prayingCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.reportCount = 0,
    this.isSaved = false,
    this.myReaction,
  });

  final String id;
  final String churchId;
  final String authorProfileId;
  final String? authorName;
  final String? authorAvatarUrl;
  final String? authorAvatarStoragePath;
  final String postType;
  final String title;
  final String body;
  final String? imageUrl;
  final String? mediaUrl;
  final String? mediaType;
  final String? mediaMimeType;
  final String? communitySpace;
  final String status;
  final String? moderationNote;
  final DateTime? answeredAt;
  final DateTime? pinnedAt;
  final bool commentsEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int reactionCount;
  final int prayingCount;
  final int commentCount;
  final int shareCount;
  final int reportCount;
  final bool isSaved;
  final String? myReaction;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isPrayer => postType == 'prayer';

  String get typeLabel => switch (postType) {
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

  String get statusLabel => switch (status) {
        'approved' => 'Aprovado',
        'rejected' => 'Rejeitado',
        'archived' => 'Arquivado',
        _ => 'Pendente',
      };

  String get communitySpaceLabel => switch (communitySpace) {
        'youth' => 'Jovens',
        'couples' => 'Casais',
        'women' => 'Mulheres',
        'men' => 'Homens',
        'children' => 'Criancas',
        'worship' => 'Louvor',
        'intercession' => 'Intercessao',
        'evangelism' => 'Evangelismo',
        'missions' => 'Missoes',
        'cells' => 'Celulas',
        'new_converts' => 'Novos convertidos',
        _ => 'Geral',
      };

  factory CommunityPost.fromMap(Map<String, dynamic> map) {
    final profile = _readProfile(map['author']);
    return CommunityPost(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      authorProfileId: (map['author_profile_id'] as String?) ?? '',
      authorName: profile['full_name'] as String?,
      authorAvatarUrl: profile['avatar_url'] as String?,
      authorAvatarStoragePath: profile['avatar_storage_path'] as String?,
      postType: (map['post_type'] as String?) ?? 'testimony',
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      imageUrl: map['image_url'] as String?,
      mediaUrl: map['media_url'] as String?,
      mediaType: map['media_type'] as String?,
      mediaMimeType: map['media_mime_type'] as String?,
      communitySpace: map['community_space'] as String?,
      status: (map['status'] as String?) ?? 'pending',
      moderationNote: map['moderation_note'] as String?,
      answeredAt: DateTime.tryParse((map['answered_at'] as String?) ?? ''),
      pinnedAt: DateTime.tryParse((map['pinned_at'] as String?) ?? ''),
      commentsEnabled: (map['comments_enabled'] as bool?) ?? true,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      reactionCount: _readCount(map['reaction_count']),
      prayingCount: _readCount(map['praying_count']),
      commentCount: _readCount(map['comment_count']),
      shareCount: _readCount(map['share_count']),
      reportCount: _readCount(map['report_count']),
      isSaved: (map['is_saved'] as bool?) ?? false,
      myReaction: map['my_reaction'] as String?,
    );
  }
}

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.postId,
    required this.profileId,
    this.authorName,
    this.authorAvatarUrl,
    this.authorAvatarStoragePath,
    this.parentCommentId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String profileId;
  final String? authorName;
  final String? authorAvatarUrl;
  final String? authorAvatarStoragePath;
  final String? parentCommentId;
  final String body;
  final DateTime createdAt;

  factory CommunityComment.fromMap(Map<String, dynamic> map) {
    final profile = _readProfile(map['profile']);
    return CommunityComment(
      id: (map['id'] as String?) ?? '',
      postId: (map['post_id'] as String?) ?? '',
      profileId: (map['profile_id'] as String?) ?? '',
      authorName: profile['full_name'] as String?,
      authorAvatarUrl: profile['avatar_url'] as String?,
      authorAvatarStoragePath: profile['avatar_storage_path'] as String?,
      parentCommentId: map['parent_comment_id'] as String?,
      body: (map['body'] as String?) ?? '',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class CommunityReaction {
  const CommunityReaction({
    required this.id,
    required this.postId,
    required this.profileId,
    this.authorName,
    this.authorAvatarUrl,
    this.authorAvatarStoragePath,
    required this.reactionType,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String profileId;
  final String? authorName;
  final String? authorAvatarUrl;
  final String? authorAvatarStoragePath;
  final String reactionType;
  final DateTime createdAt;

  factory CommunityReaction.fromMap(Map<String, dynamic> map) {
    final profile = _readProfile(map['profile']);
    return CommunityReaction(
      id: (map['id'] as String?) ?? '',
      postId: (map['post_id'] as String?) ?? '',
      profileId: (map['profile_id'] as String?) ?? '',
      authorName: profile['full_name'] as String?,
      authorAvatarUrl: profile['avatar_url'] as String?,
      authorAvatarStoragePath: profile['avatar_storage_path'] as String?,
      reactionType: (map['reaction_type'] as String?) ?? 'amen',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

Map<String, dynamic> _readProfile(Object? raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  if (raw is List && raw.isNotEmpty) {
    final first = raw.first;
    if (first is Map<String, dynamic>) {
      return first;
    }
    if (first is Map) {
      return Map<String, dynamic>.from(first);
    }
  }
  return const {};
}

int _readCount(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}
