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
    raise notice 'Igreja Vida Nova nao encontrada para evento QA.';
    return;
  end if;

  select p.id
  into sara_id
  from public.profiles p
  where regexp_replace(coalesce(p.phone, ''), '\D', '', 'g') in ('877688695', '258877688695')
  limit 1;

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
    is_demo,
    metadata
  )
  values (
    vida_id,
    'QA Feed - Culto de celebracao',
    'culto',
    'culto',
    'published',
    'all',
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
    false,
    jsonb_build_object('qa', true, 'source', 'pastor_feed_sync')
  );
end $$;
