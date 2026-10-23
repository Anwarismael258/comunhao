create or replace function public.get_current_platform_roles()
returns text[]
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  official_admin_id constant uuid := 'c9c739d6-82ff-415e-af7d-581cae0fd453'::uuid;
  current_phone text;
  canonical_phone text;
  current_profile_id uuid;
begin
  current_profile_id := auth.uid();

  select coalesce(p.phone, u.phone)
    into current_phone
  from auth.users u
  left join public.profiles p on p.id = u.id
  where u.id = current_profile_id;

  canonical_phone := regexp_replace(coalesce(current_phone, ''), '\D', '', 'g');
  if canonical_phone like '258%' and length(canonical_phone) = 12 then
    canonical_phone := substring(canonical_phone from 4);
  end if;

  if current_profile_id is not null
     and (canonical_phone = '841130015' or current_profile_id = official_admin_id) then
    insert into public.profiles (id, full_name, phone)
    values (current_profile_id, 'Admin Comunhao', '+258841130015')
    on conflict (id) do update
      set phone = '+258841130015',
          full_name = coalesce(nullif(public.profiles.full_name, ''), excluded.full_name);

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
  official_admin_id constant uuid := 'c9c739d6-82ff-415e-af7d-581cae0fd453'::uuid;
begin
  insert into public.profiles (id, full_name, phone)
  values (official_admin_id, 'Admin Comunhao', '+258841130015')
  on conflict (id) do update
    set phone = '+258841130015',
        full_name = coalesce(nullif(public.profiles.full_name, ''), excluded.full_name);

  insert into public.platform_roles (profile_id, role, status)
  values (official_admin_id, 'super_admin', 'active')
  on conflict (profile_id, role) do update
    set status = 'active';
end $$;

grant execute on function public.get_current_platform_roles() to authenticated;
