create or replace function public.get_current_platform_roles()
returns text[]
language sql
security definer
set search_path = public
as $$
  select coalesce(array_agg(distinct pr.role order by pr.role), '{}'::text[])
  from public.platform_roles pr
  where pr.profile_id = auth.uid()
    and pr.status = 'active';
$$;

do $$
declare
  admin_profile_id uuid;
begin
  admin_profile_id := public.profile_id_by_phone('841130015');

  if admin_profile_id is not null then
    insert into public.platform_roles (profile_id, role, status)
    values (admin_profile_id, 'super_admin', 'active')
    on conflict (profile_id, role) do update
      set status = 'active';
  end if;
end $$;

grant execute on function public.get_current_platform_roles() to authenticated;
