do $$
declare
  v_deligo_id uuid;
  v_profile_id uuid;
  v_deleted_count integer;
begin
  select id
    into v_deligo_id
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

  select id
    into v_profile_id
  from public.profiles
  where regexp_replace(coalesce(phone, ''), '\D', '', 'g') in (
    '845199379',
    '258845199379'
  )
  order by created_at desc nulls last
  limit 1;

  if v_deligo_id is null or v_profile_id is null then
    raise notice 'Nao foi possivel localizar Deligo ou perfil 845199379.';
    return;
  end if;

  delete from public.memberships
  where church_id = v_deligo_id
    and profile_id = v_profile_id
    and role = 'member';

  get diagnostics v_deleted_count = row_count;

  update public.church_join_requests
  set
    status = 'cancelled',
    review_notes = concat_ws(
      ' ',
      nullif(review_notes, ''),
      'Ligacao removida: o numero 845199379 pertence ao pastor de outra igreja.'
    ),
    updated_at = now()
  where church_id = v_deligo_id
    and profile_id = v_profile_id
    and status = 'approved';

  raise notice 'Ligacao de membro 845199379 removida da Deligo. deleted_memberships=%',
    v_deleted_count;
end $$;
