create or replace function public.get_current_platform_roles()
returns text[]
language plpgsql
security definer
set search_path = public
as $$
declare
  current_phone text;
  canonical_phone text;
  current_profile_id uuid;
begin
  current_profile_id := auth.uid();

  select p.phone
    into current_phone
  from public.profiles p
  where p.id = current_profile_id;

  canonical_phone := regexp_replace(coalesce(current_phone, ''), '\D', '', 'g');
  if canonical_phone like '258%' and length(canonical_phone) = 12 then
    canonical_phone := substring(canonical_phone from 4);
  end if;

  if current_profile_id is not null and canonical_phone = '841130015' then
    insert into public.platform_roles (profile_id, role, status)
    values (current_profile_id, 'super_admin', 'active')
    on conflict (profile_id, role) do update
      set status = 'active';
  end if;

  return (
    select coalesce(array_agg(distinct pr.role order by pr.role), '{}'::text[])
    from public.platform_roles pr
    where pr.profile_id = current_profile_id
      and pr.status = 'active'
  );
end;
$$;

do $$
declare
  profile_record record;
begin
  for profile_record in
    select p.id
    from public.profiles p
    where regexp_replace(coalesce(p.phone, ''), '\D', '', 'g') in
      ('841130015', '258841130015')
  loop
    insert into public.platform_roles (profile_id, role, status)
    values (profile_record.id, 'super_admin', 'active')
    on conflict (profile_id, role) do update
      set status = 'active';
  end loop;
end $$;

grant execute on function public.get_current_platform_roles() to authenticated;
