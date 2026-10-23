do $$
declare
  admin_id uuid := 'c9c739d6-82ff-415e-af7d-581cae0fd453'::uuid;
begin
  insert into public.profiles (id, full_name, phone)
  values (admin_id, 'Admin Comunhao', '+258841130015')
  on conflict (id) do update
    set phone = coalesce(public.profiles.phone, excluded.phone),
        full_name = coalesce(nullif(public.profiles.full_name, ''), excluded.full_name);

  insert into public.platform_roles (profile_id, role, status)
  values (admin_id, 'super_admin', 'active')
  on conflict (profile_id, role) do update
    set status = 'active';
end $$;
