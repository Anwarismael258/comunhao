class PastoralPublication {
  const PastoralPublication({
    required this.id,
    required this.churchId,
    this.authorUserId,
    this.authorName,
    this.authorAvatarUrl,
    this.authorAvatarStoragePath,
    required this.title,
    required this.slug,
    this.summary,
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
    required this.isDemo,
    required this.createdAt,
    required this.updatedAt,
    this.readCount = 0,
    this.openCount = 0,
    this.savedCount = 0,
    this.reactionCount = 0,
    this.commentCount = 0,
    this.isSaved = false,
    this.isRead = false,
    this.myReaction,
  });

  final String id;
  final String churchId;
  final String? authorUserId;
  final String? authorName;
  final String? authorAvatarUrl;
  final String? authorAvatarStoragePath;
  final String title;
  final String slug;
  final String? summary;
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
  final bool isDemo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int readCount;
  final int openCount;
  final int savedCount;
  final int reactionCount;
  final int commentCount;
  final bool isSaved;
  final bool isRead;
  final String? myReaction;

  String get typeLabel => publicationTypeLabel(publicationType);

  String get statusLabel => switch (status) {
        'draft' => 'Rascunho',
        'scheduled' => 'Agendada',
        'published' => 'Publicada',
        'archived' => 'Arquivada',
        'cancelled' => 'Cancelada',
        _ => status,
      };

  String get visibilityLabel => visibilityLabelFor(visibility);

  DateTime get displayDate => publishedAt ?? scheduledAt ?? createdAt;

  bool get hasMedia =>
      (audioUrl?.isNotEmpty ?? false) ||
      (videoUrl?.isNotEmpty ?? false) ||
      (documentUrl?.isNotEmpty ?? false) ||
      (liveStreamUrl?.isNotEmpty ?? false) ||
      (externalUrl?.isNotEmpty ?? false);

  PastoralPublication copyWith({
    String? authorName,
    String? authorAvatarUrl,
    String? authorAvatarStoragePath,
    bool? isSaved,
    bool? isRead,
    String? myReaction,
    int? readCount,
    int? openCount,
    int? savedCount,
    int? reactionCount,
    int? commentCount,
  }) {
    return PastoralPublication(
      id: id,
      churchId: churchId,
      authorUserId: authorUserId,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      authorAvatarStoragePath:
          authorAvatarStoragePath ?? this.authorAvatarStoragePath,
      title: title,
      slug: slug,
      summary: summary,
      content: content,
      publicationType: publicationType,
      category: category,
      coverImageUrl: coverImageUrl,
      audioUrl: audioUrl,
      videoUrl: videoUrl,
      documentUrl: documentUrl,
      liveStreamUrl: liveStreamUrl,
      externalUrl: externalUrl,
      status: status,
      visibility: visibility,
      priority: priority,
      publishedAt: publishedAt,
      scheduledAt: scheduledAt,
      expiresAt: expiresAt,
      allowComments: allowComments,
      allowReactions: allowReactions,
      allowSharing: allowSharing,
      sendNotification: sendNotification,
      isFeatured: isFeatured,
      isPinned: isPinned,
      isDemo: isDemo,
      createdAt: createdAt,
      updatedAt: updatedAt,
      readCount: readCount ?? this.readCount,
      openCount: openCount ?? this.openCount,
      savedCount: savedCount ?? this.savedCount,
      reactionCount: reactionCount ?? this.reactionCount,
      commentCount: commentCount ?? this.commentCount,
      isSaved: isSaved ?? this.isSaved,
      isRead: isRead ?? this.isRead,
      myReaction: myReaction ?? this.myReaction,
    );
  }

  factory PastoralPublication.fromMap(Map<String, dynamic> map) {
    final author = switch (map['author']) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => const <String, dynamic>{},
    };
    return PastoralPublication(
      id: (map['id'] as String?) ?? '',
      churchId: (map['church_id'] as String?) ?? '',
      authorUserId: map['author_user_id'] as String?,
      authorName: author['full_name'] as String?,
      authorAvatarUrl: author['avatar_url'] as String?,
      authorAvatarStoragePath: author['avatar_storage_path'] as String?,
      title: ((map['title'] as String?) ?? '').trim(),
      slug: ((map['slug'] as String?) ?? '').trim(),
      summary: map['summary'] as String?,
      content: ((map['content'] as String?) ?? '').trim(),
      publicationType:
          (map['publication_type'] as String?) ?? 'pastoral_message',
      category: (map['category'] as String?) ?? 'geral',
      coverImageUrl: map['cover_image_url'] as String?,
      audioUrl: map['audio_url'] as String?,
      videoUrl: map['video_url'] as String?,
      documentUrl: map['document_url'] as String?,
      liveStreamUrl: map['live_stream_url'] as String?,
      externalUrl: map['external_url'] as String?,
      status: (map['status'] as String?) ?? 'draft',
      visibility: (map['visibility'] as String?) ?? 'members',
      priority: (map['priority'] as String?) ?? 'normal',
      publishedAt: DateTime.tryParse((map['published_at'] as String?) ?? ''),
      scheduledAt: DateTime.tryParse((map['scheduled_at'] as String?) ?? ''),
      expiresAt: DateTime.tryParse((map['expires_at'] as String?) ?? ''),
      allowComments: (map['allow_comments'] as bool?) ?? false,
      allowReactions: (map['allow_reactions'] as bool?) ?? true,
      allowSharing: (map['allow_sharing'] as bool?) ?? true,
      sendNotification: (map['send_notification'] as bool?) ?? false,
      isFeatured: (map['is_featured'] as bool?) ?? false,
      isPinned: (map['is_pinned'] as bool?) ?? false,
      isDemo: (map['is_demo'] as bool?) ?? false,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      readCount: _readInt(map['read_count']),
      openCount: _readInt(map['open_count']),
      savedCount: _readInt(map['saved_count']),
      reactionCount: _readInt(map['reaction_count']),
      commentCount: _readInt(map['comment_count']),
      isSaved: (map['is_saved'] as bool?) ?? false,
      isRead: (map['is_read'] as bool?) ?? false,
      myReaction: map['my_reaction'] as String?,
    );
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }
}

class PastoralPublicationComment {
  const PastoralPublicationComment({
    required this.id,
    required this.publicationId,
    required this.profileId,
    this.authorName,
    this.authorAvatarUrl,
    this.authorAvatarStoragePath,
    this.parentCommentId,
    required this.body,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String publicationId;
  final String profileId;
  final String? authorName;
  final String? authorAvatarUrl;
  final String? authorAvatarStoragePath;
  final String? parentCommentId;
  final String body;
  final String status;
  final DateTime createdAt;

  factory PastoralPublicationComment.fromMap(Map<String, dynamic> map) {
    final profile = switch (map['profile']) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => const <String, dynamic>{},
    };
    return PastoralPublicationComment(
      id: (map['id'] as String?) ?? '',
      publicationId: (map['publication_id'] as String?) ?? '',
      profileId: (map['profile_id'] as String?) ?? '',
      authorName: profile['full_name'] as String?,
      authorAvatarUrl: profile['avatar_url'] as String?,
      authorAvatarStoragePath: profile['avatar_storage_path'] as String?,
      parentCommentId: map['parent_comment_id'] as String?,
      body: (map['body'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'active',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class PastoralPublicationReaction {
  const PastoralPublicationReaction({
    required this.id,
    required this.publicationId,
    required this.profileId,
    this.authorName,
    this.authorAvatarUrl,
    this.authorAvatarStoragePath,
    required this.reactionType,
    required this.createdAt,
  });

  final String id;
  final String publicationId;
  final String profileId;
  final String? authorName;
  final String? authorAvatarUrl;
  final String? authorAvatarStoragePath;
  final String reactionType;
  final DateTime createdAt;

  factory PastoralPublicationReaction.fromMap(Map<String, dynamic> map) {
    final profile = switch (map['profile']) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => const <String, dynamic>{},
    };
    return PastoralPublicationReaction(
      id: (map['id'] as String?) ?? '',
      publicationId: (map['publication_id'] as String?) ?? '',
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

String publicationTypeLabel(String type) => switch (type) {
      'announcement' => 'Comunicado',
      'sermon' => 'Pregacao',
      'devotional' => 'Devocional',
      'bible_study' => 'Estudo biblico',
      'pastoral_message' => 'Palavra pastoral',
      'leadership_message' => 'Mensagem da lideranca',
      'testimony' => 'Testemunho',
      'urgent_notice' => 'Aviso urgente',
      'video' => 'Video',
      'audio' => 'Audio',
      'document' => 'Documento',
      'live_stream' => 'Transmissao ao vivo',
      _ => type,
    };

String visibilityLabelFor(String visibility) => switch (visibility) {
      'all' => 'Toda a igreja',
      'members' => 'Membros',
      'visitors' => 'Visitantes',
      'pastors' => 'Pastores',
      'leaders' => 'Lideres',
      'youth' => 'Jovens',
      'men' => 'Homens',
      'women' => 'Senhoras',
      'children' => 'Criancas',
      'ministry' => 'Ministerio',
      'group' => 'Grupo',
      'selected_users' => 'Selecionados',
      _ => visibility,
    };
