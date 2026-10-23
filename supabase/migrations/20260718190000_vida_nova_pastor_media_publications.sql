do $$
declare
  vida_id uuid;
  sara_id uuid;
begin
  select id
    into vida_id
  from public.churches
  where slug = 'vida-nova'
     or join_code = 'VIDA123'
     or lower(name) = lower('Igreja Vida Nova')
  order by created_at
  limit 1;

  if vida_id is null then
    raise notice 'Igreja Vida Nova nao encontrada; seed de publicacoes media ignorado.';
    return;
  end if;

  select p.id
    into sara_id
  from public.profiles p
  where public.canonical_mz_phone(p.phone) = public.canonical_mz_phone('877688695')
  order by p.created_at
  limit 1;

  insert into public.pastoral_publications (
    church_id,
    author_user_id,
    title,
    slug,
    summary,
    content,
    publication_type,
    category,
    cover_image_url,
    status,
    visibility,
    priority,
    published_at,
    allow_comments,
    allow_reactions,
    allow_sharing,
    send_notification,
    is_featured,
    is_pinned,
    is_demo,
    metadata
  )
  values (
    vida_id,
    sara_id,
    'Foto do culto - 30 de Julho',
    'pastor-foto-do-culto-30-de-julho',
    'Registo visual partilhado pela pastora Sara para os membros da Igreja Vida Nova.',
    'A Igreja Vida Nova partilhou uma fotografia especial do culto para fortalecer a comunhao com todos os membros.',
    'announcement',
    'pastoral',
    'https://dxofxuajsrocbxdmekfx.supabase.co/storage/v1/object/public/pastoral-publications/4c56ae2b-1368-4b3e-833e-aa38afa1963e/publications/images/pastor-foto-do-culto-30-de-julho.png',
    'published',
    'members',
    'normal',
    now(),
    true,
    true,
    true,
    true,
    true,
    true,
    false,
    jsonb_build_object('source', 'desktop_upload', 'original_file', '30 DE JULHO.png', 'media_kind', 'image')
  )
  on conflict (church_id, slug) do update
  set
    author_user_id = excluded.author_user_id,
    title = excluded.title,
    summary = excluded.summary,
    content = excluded.content,
    publication_type = excluded.publication_type,
    category = excluded.category,
    cover_image_url = excluded.cover_image_url,
    audio_url = null,
    video_url = null,
    document_url = null,
    status = 'published',
    visibility = 'members',
    priority = excluded.priority,
    published_at = now(),
    allow_comments = true,
    allow_reactions = true,
    allow_sharing = true,
    send_notification = true,
    is_featured = true,
    is_pinned = true,
    is_demo = false,
    metadata = excluded.metadata,
    updated_at = now();

  insert into public.pastoral_publications (
    church_id,
    author_user_id,
    title,
    slug,
    summary,
    content,
    publication_type,
    category,
    audio_url,
    status,
    visibility,
    priority,
    published_at,
    allow_comments,
    allow_reactions,
    allow_sharing,
    send_notification,
    is_featured,
    is_pinned,
    is_demo,
    metadata
  )
  values (
    vida_id,
    sara_id,
    'Louvor - Porque Deus Amou o Mundo',
    'pastor-louvor-porque-deus-amou-o-mundo',
    'Louvor em audio partilhado pela pastora Sara para edificacao dos membros.',
    'Este louvor foi publicado pela Igreja Vida Nova para os membros ouvirem e partilharem durante a semana.',
    'audio',
    'louvor',
    'https://dxofxuajsrocbxdmekfx.supabase.co/storage/v1/object/public/pastoral-publications/4c56ae2b-1368-4b3e-833e-aa38afa1963e/publications/audio/pastor-louvor-porque-deus-amou-o-mundo.mp3',
    'published',
    'members',
    'normal',
    now(),
    true,
    true,
    true,
    true,
    true,
    false,
    false,
    jsonb_build_object('source', 'desktop_upload', 'original_file', 'Porque Deus Amou o Mundo (1).mp3', 'media_kind', 'audio')
  )
  on conflict (church_id, slug) do update
  set
    author_user_id = excluded.author_user_id,
    title = excluded.title,
    summary = excluded.summary,
    content = excluded.content,
    publication_type = excluded.publication_type,
    category = excluded.category,
    cover_image_url = null,
    audio_url = excluded.audio_url,
    video_url = null,
    document_url = null,
    status = 'published',
    visibility = 'members',
    priority = excluded.priority,
    published_at = now(),
    allow_comments = true,
    allow_reactions = true,
    allow_sharing = true,
    send_notification = true,
    is_featured = true,
    is_pinned = false,
    is_demo = false,
    metadata = excluded.metadata,
    updated_at = now();

  insert into public.pastoral_publications (
    church_id,
    author_user_id,
    title,
    slug,
    summary,
    content,
    publication_type,
    category,
    video_url,
    status,
    visibility,
    priority,
    published_at,
    allow_comments,
    allow_reactions,
    allow_sharing,
    send_notification,
    is_featured,
    is_pinned,
    is_demo,
    metadata
  )
  values (
    vida_id,
    sara_id,
    'Video pastoral para os membros',
    'pastor-video-pastoral-para-os-membros',
    'Video partilhado pela pastora Sara para acompanhar os membros da Igreja Vida Nova.',
    'A Igreja Vida Nova publicou este video pastoral para informar, edificar e manter os membros ligados a vida da igreja.',
    'video',
    'pastoral',
    'https://dxofxuajsrocbxdmekfx.supabase.co/storage/v1/object/public/pastoral-publications/4c56ae2b-1368-4b3e-833e-aa38afa1963e/publications/videos/pastor-video-pastoral-para-os-membros.mp4',
    'published',
    'members',
    'normal',
    now(),
    true,
    true,
    true,
    true,
    true,
    false,
    false,
    jsonb_build_object('source', 'desktop_upload', 'original_file', 'ssstik.io_1784388754502.mp4', 'media_kind', 'video')
  )
  on conflict (church_id, slug) do update
  set
    author_user_id = excluded.author_user_id,
    title = excluded.title,
    summary = excluded.summary,
    content = excluded.content,
    publication_type = excluded.publication_type,
    category = excluded.category,
    cover_image_url = null,
    audio_url = null,
    video_url = excluded.video_url,
    document_url = null,
    status = 'published',
    visibility = 'members',
    priority = excluded.priority,
    published_at = now(),
    allow_comments = true,
    allow_reactions = true,
    allow_sharing = true,
    send_notification = true,
    is_featured = true,
    is_pinned = false,
    is_demo = false,
    metadata = excluded.metadata,
    updated_at = now();
end $$;
