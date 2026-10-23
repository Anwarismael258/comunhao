do $$
declare
  v_church_id uuid;
  v_profile_id uuid;
  v_request_id uuid;
begin
  select id
    into v_profile_id
  from public.profiles
  where regexp_replace(coalesce(phone, ''), '\D', '', 'g') in (
    '845199379',
    '258845199379'
  )
  order by created_at desc nulls last
  limit 1;

  if v_profile_id is null then
    raise notice 'Perfil do numero 845199379 ainda nao encontrado.';
    return;
  end if;

  select id, church_id
    into v_request_id, v_church_id
  from public.church_join_requests
  where profile_id = v_profile_id
    and status in (
      'pending',
      'under_review',
      'more_information_required',
      'rejected',
      'cancelled'
    )
  order by
    case status
      when 'pending' then 0
      when 'under_review' then 1
      when 'more_information_required' then 2
      else 3
    end,
    created_at desc nulls last
  limit 1;

  if v_church_id is null then
    select id
      into v_church_id
    from public.churches
    where lower(trim(name)) = 'deligo'
       or lower(trim(slug)) = 'deligo'
    order by
      case
        when lower(trim(slug)) = 'deligo' then 0
        when lower(trim(name)) = 'deligo' then 1
        else 2
      end,
      created_at desc nulls last
    limit 1;
  end if;

  if v_church_id is null then
    raise notice 'Igreja para aceitar 845199379 nao encontrada.';
    return;
  end if;

  insert into public.memberships (
    church_id,
    profile_id,
    role,
    status,
    approved_at,
    entry_date,
    created_at
  )
  values (
    v_church_id,
    v_profile_id,
    'member',
    'active',
    now(),
    current_date,
    now()
  )
  on conflict (church_id, profile_id) do update
  set
    status = 'active',
    approved_at = coalesce(public.memberships.approved_at, now()),
    entry_date = coalesce(public.memberships.entry_date, current_date),
    role = case
      when public.memberships.role in ('pastor', 'church_admin', 'leader') then public.memberships.role
      else 'member'
    end;

  update public.church_join_requests
  set
    status = 'approved',
    reviewed_at = coalesce(reviewed_at, now()),
    review_notes = coalesce(review_notes, 'Aprovado administrativamente pelo Super Admin.')
  where profile_id = v_profile_id
    and church_id = v_church_id
    and status <> 'approved';

  insert into public.church_request_timeline (
    church_id,
    request_table,
    request_id,
    actor_profile_id,
    action,
    public_message,
    internal_note
  )
  select
    v_church_id,
    'church_join_requests',
    request.id,
    null,
    'approved',
    'Pedido aprovado.',
    'Aprovado administrativamente pelo Super Admin para o numero 845199379.'
  from public.church_join_requests request
  where request.profile_id = v_profile_id
    and request.church_id = v_church_id
    and request.status = 'approved'
    and not exists (
      select 1
      from public.church_request_timeline timeline
      where timeline.request_table = 'church_join_requests'
        and timeline.request_id = request.id
        and timeline.action = 'approved'
    );

  raise notice 'Numero 845199379 aceite. church_id=%, profile_id=%, request_id=%',
    v_church_id,
    v_profile_id,
    v_request_id;
end $$;
