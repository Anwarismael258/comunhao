do $$
declare
  vida_id uuid;
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
    raise notice 'Igreja Vida Nova nao encontrada para limpar feed.';
    return;
  end if;

  update public.community_posts
  set
    status = 'archived',
    moderation_note = coalesce(moderation_note, 'Arquivado para reinicio dos testes reais.'),
    moderated_at = now(),
    updated_at = now()
  where church_id = vida_id
    and status <> 'archived';

  update public.community_post_comments c
  set
    status = 'hidden',
    updated_at = now()
  where status = 'visible'
    and exists (
      select 1
      from public.community_posts p
      where p.id = c.post_id
        and p.church_id = vida_id
    );

  update public.announcements
  set
    published_at = null,
    pinned = false,
    is_demo = true
  where church_id = vida_id;

  update public.events
  set
    status = 'archived',
    is_demo = true,
    updated_at = now()
  where church_id = vida_id
    and status <> 'archived';

  update public.donation_campaigns
  set
    active = false,
    campaign_status = 'closed',
    is_demo = true
  where church_id = vida_id;

  update public.pastoral_publications
  set
    status = 'archived',
    is_pinned = false,
    is_featured = false,
    is_demo = true,
    updated_at = now()
  where church_id = vida_id
    and status <> 'archived';
end $$;
