do $$
declare
  v_church_id uuid;
  v_profile_id uuid;
begin
  select id
    into v_church_id
  from public.churches
  where lower(trim(name)) = 'deligo'
     or lower(trim(slug)) = 'deligo'
     or regexp_replace(coalesce(phone, ''), '\D', '', 'g') in (
       '877688695',
       '258877688695'
     )
  order by
    case
      when lower(trim(slug)) = 'deligo' then 0
      when lower(trim(name)) = 'deligo' then 1
      else 2
    end,
    created_at desc nulls last
  limit 1;

  if v_church_id is null then
    raise notice 'Igreja Deligo / 877688695 nao encontrada.';
    return;
  end if;

  update public.churches
  set active = true
  where id = v_church_id;

  select id
    into v_profile_id
  from public.profiles
  where regexp_replace(coalesce(phone, ''), '\D', '', 'g') in (
    '858853156',
    '258858853156'
  )
  order by created_at desc nulls last
  limit 1;

  if v_profile_id is null then
    raise notice 'Perfil do membro 858853156 ainda nao encontrado.';
    return;
  end if;

  insert into public.memberships (
    church_id,
    profile_id,
    role,
    status,
    member_code,
    created_at
  )
  values (
    v_church_id,
    v_profile_id,
    'member',
    'active',
    'DEL-858853156',
    now()
  )
  on conflict (church_id, profile_id) do update
  set role = coalesce(public.memberships.role, 'member'),
      status = 'active',
      member_code = coalesce(public.memberships.member_code, excluded.member_code);

  raise notice 'Membro 858853156 ligado a igreja Deligo. church_id=%, profile_id=%',
    v_church_id,
    v_profile_id;
end $$;
