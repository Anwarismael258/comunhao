do $$
declare
  vida_id uuid;
  sara_id uuid;
begin
  select c.id
  into vida_id
  from public.churches c
  where (
      lower(trim(c.slug)) = 'vida-nova'
      or upper(trim(coalesce(c.join_code, ''))) = 'VIDA123'
      or lower(trim(c.name)) = 'igreja vida nova'
      or regexp_replace(coalesce(c.phone, ''), '\D', '', 'g') in ('877688695', '258877688695')
    )
    and coalesce(c.is_demo, false) = false
  order by
    case when lower(trim(c.slug)) = 'vida-nova' then 0 else 1 end,
    c.created_at nulls last
  limit 1;

  if vida_id is null then
    raise notice 'Igreja Vida Nova nao encontrada para QA do feed.';
    return;
  end if;

  select p.id
  into sara_id
  from public.profiles p
  where regexp_replace(coalesce(p.phone, ''), '\D', '', 'g') in ('877688695', '258877688695')
  limit 1;

  delete from public.announcements
  where church_id = vida_id
    and title = 'QA Feed - Aviso do pastor';

  insert into public.announcements (
    church_id,
    title,
    body,
    image_url,
    pinned,
    published_at,
    created_by
  )
  values (
    vida_id,
    'QA Feed - Aviso do pastor',
    'Aviso criado no app dos pastores para validar que entra no Feed da Comunhao dos membros.',
    'https://images.unsplash.com/photo-1507692049790-de58290a4334?auto=format&fit=crop&w=1200&q=80',
    true,
    now(),
    sara_id
  );

  delete from public.events
  where church_id = vida_id
    and title = 'QA Feed - Culto de celebracao';

  insert into public.events (
    church_id,
    title,
    event_type,
    category,
    status,
    visibility,
    description,
    location,
    location_name,
    cover_image_url,
    starts_at,
    ends_at,
    registration_required,
    capacity,
    attendance_required,
    is_public,
    created_by,
    responsible_user_id,
    organizer_name,
    is_demo
  )
  values (
    vida_id,
    'QA Feed - Culto de celebracao',
    'culto',
    'culto',
    'published',
    'members',
    'Culto criado no app dos pastores para confirmar sincronizacao com agenda e feed dos membros.',
    'Templo Vida Nova, Maputo',
    'Templo Vida Nova',
    'https://images.unsplash.com/photo-1504052434569-70ad5836ab65?auto=format&fit=crop&w=1200&q=80',
    now() + interval '3 days',
    now() + interval '3 days 2 hours',
    true,
    180,
    true,
    true,
    sara_id,
    sara_id,
    'Sara',
    false
  );

  delete from public.donation_campaigns
  where church_id = vida_id
    and title = 'QA Feed - Campanha de som';

  insert into public.donation_campaigns (
    church_id,
    title,
    description,
    image_url,
    target_amount,
    start_at,
    end_at,
    active,
    campaign_status,
    created_by
  )
  values (
    vida_id,
    'QA Feed - Campanha de som',
    'Campanha ativa criada pela igreja para validar que aparece no feed dos membros com botao de contribuicao.',
    'https://images.unsplash.com/photo-1516280440614-37939bbacd81?auto=format&fit=crop&w=1200&q=80',
    75000,
    now() - interval '1 day',
    now() + interval '45 days',
    true,
    'active',
    sara_id
  );

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
    'QA Feed - Palavra pastoral',
    'qa-feed-palavra-pastoral',
    'Publicacao pastoral criada para validar sincronizacao com o Feed da Comunhao.',
    'Esta palavra pastoral foi publicada pela Igreja Vida Nova para confirmar que os membros veem no feed a mensagem criada no app dos pastores.',
    'pastoral_message',
    'geral',
    'https://images.unsplash.com/photo-1490730141103-6cac27aaab94?auto=format&fit=crop&w=1200&q=80',
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
    jsonb_build_object('qa', true, 'source', 'pastor_feed_sync')
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
end $$;
