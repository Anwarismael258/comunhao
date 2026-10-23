create or replace function public.seed_vida_nova_calendar_demo()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  vida_id uuid;
  sara_id uuid;
  member_id uuid;
  sunday_event_id uuid;
begin
  select id
    into vida_id
  from public.churches
  where slug in ('vida-nova', 'igreja-vida-nova')
     or regexp_replace(coalesce(phone, ''), '\D', '', 'g') in ('877688695', '258877688695')
     or lower(trim(name)) in ('vida nova', 'igreja vida nova')
  order by
    case when lower(trim(name)) = 'igreja vida nova' then 0 else 1 end,
    created_at desc
  limit 1;

  sara_id := public.profile_id_by_phone('877688695');
  member_id := public.profile_id_by_phone('827688695');

  if vida_id is null then
    return jsonb_build_object('seeded', false, 'reason', 'Vida Nova not found');
  end if;

  delete from public.event_attendance where church_id = vida_id and is_demo = true;
  delete from public.event_occurrences where church_id = vida_id and is_demo = true;
  delete from public.events where church_id = vida_id and is_demo = true;

  insert into public.events (
    church_id,
    title,
    event_type,
    category,
    description,
    location,
    location_name,
    starts_at,
    ends_at,
    registration_required,
    attendance_required,
    capacity,
    status,
    visibility,
    is_public,
    recurrence_rule,
    speaker_name,
    responsible_user_id,
    is_featured,
    is_demo,
    created_by
  )
  values
    (vida_id, 'Culto Dominical', 'service', 'culto_dominical', 'Culto principal da Igreja Vida Nova.', 'Templo Vida Nova', 'Templo Vida Nova', date_trunc('week', now()) + interval '6 days 9 hours', date_trunc('week', now()) + interval '6 days 11 hours', false, true, 250, 'published', 'members', true, 'weekly', 'Sara', sara_id, true, true, sara_id),
    (vida_id, 'Culto de Oracao', 'service', 'culto_oracao', 'Momento semanal de intercessao e comunhao.', 'Templo Vida Nova', 'Templo Vida Nova', date_trunc('week', now()) + interval '3 days 18 hours', date_trunc('week', now()) + interval '3 days 20 hours', false, true, 180, 'published', 'members', true, 'weekly', 'Sara', sara_id, false, true, sara_id),
    (vida_id, 'Vigilia de Louvor', 'service', 'vigilia', 'Vigilia mensal com louvor, palavra e oracao.', 'Templo Vida Nova', 'Templo Vida Nova', date_trunc('month', now()) + interval '19 days 22 hours', date_trunc('month', now()) + interval '20 days 4 hours', true, true, 220, 'published', 'members', true, 'monthly', 'Sara', sara_id, true, true, sara_id),
    (vida_id, 'Conferencia de Familias', 'event', 'conferencia', 'Conferencia especial para casais, pais e filhos.', 'Auditorio Vida Nova', 'Auditorio Vida Nova', now() + interval '12 days', now() + interval '12 days 4 hours', true, true, 300, 'published', 'all', true, null, 'Sara', sara_id, true, true, sara_id),
    (vida_id, 'Acao Social Escolar', 'event', 'acao_social', 'Campanha de apoio escolar para familias acompanhadas pela igreja.', 'Maputo', 'Maputo', now() + interval '18 days 8 hours', now() + interval '18 days 12 hours', true, true, 80, 'published', 'all', true, null, 'Equipa de Accao Social', sara_id, false, true, sara_id),
    (vida_id, 'Reuniao de Lideres', 'internal_meeting', 'lideranca', 'Planeamento semanal com lideres e ministerios.', 'Sala Pastoral', 'Sala Pastoral', date_trunc('week', now()) + interval '1 day 18 hours', date_trunc('week', now()) + interval '1 day 20 hours', false, true, 35, 'published', 'leaders', false, 'weekly', 'Sara', sara_id, false, true, sara_id),
    (vida_id, 'Ensaio do Coral', 'internal_meeting', 'ensaio', 'Ensaio do grupo de louvor e coral.', 'Sala de Musica', 'Sala de Musica', date_trunc('week', now()) + interval '5 days 17 hours', date_trunc('week', now()) + interval '5 days 19 hours', false, true, 40, 'published', 'members', false, 'weekly', 'Ministerio de Louvor', sara_id, false, true, sara_id),
    (vida_id, 'Transmissao Online do Culto', 'event', 'transmissao', 'Transmissao ao vivo do culto dominical.', 'Online', 'Online', date_trunc('week', now()) + interval '6 days 9 hours', date_trunc('week', now()) + interval '6 days 11 hours', false, false, null, 'published', 'all', true, 'weekly', 'Sara', sara_id, false, true, sara_id);

  perform public.generate_event_occurrences(id, now() + interval '60 days')
  from public.events
  where church_id = vida_id and is_demo = true;

  select id into sunday_event_id
  from public.events
  where church_id = vida_id and title = 'Culto Dominical' and is_demo = true
  limit 1;

  if member_id is not null and sunday_event_id is not null then
    insert into public.event_registrations (
      event_id,
      profile_id,
      status,
      checked_in_at
    )
    values (
      sunday_event_id,
      member_id,
      'checked_in',
      now()
    )
    on conflict (event_id, profile_id) do update
      set status = 'checked_in',
          checked_in_at = coalesce(public.event_registrations.checked_in_at, now());

    insert into public.event_attendance (
      event_id,
      church_id,
      profile_id,
      participant_type,
      status,
      check_in_method,
      notes,
      is_demo
    )
    values (
      sunday_event_id,
      vida_id,
      member_id,
      'member',
      'checked_in',
      'manual',
      'Seed demo Vida Nova',
      true
    )
    on conflict do nothing;
  end if;

  return jsonb_build_object('seeded', true, 'church_id', vida_id);
end;
$$;

select public.seed_vida_nova_calendar_demo();

revoke execute on function public.seed_vida_nova_calendar_demo() from anon, authenticated, public;
