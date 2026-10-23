create or replace function public.is_super_admin(check_user uuid default auth.uid())
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select
    coalesce(auth.role(), '') = 'service_role'
    or coalesce(check_user, auth.uid()) = 'c9c739d6-82ff-415e-af7d-581cae0fd453'::uuid
    or exists (
      select 1
      from public.profiles profile
      where profile.id = coalesce(check_user, auth.uid())
        and regexp_replace(coalesce(profile.phone, ''), '\D', '', 'g')
          in ('841130015', '258841130015')
    )
    or exists (
      select 1
      from public.platform_roles pr
      where pr.profile_id = coalesce(check_user, auth.uid())
        and pr.role = 'super_admin'
        and pr.status = 'active'
    );
$$;

create or replace function public.notify_super_admins_church_application()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient record;
begin
  if new.status = 'submitted'
    and (
      tg_op = 'INSERT'
      or old.status is distinct from new.status
    ) then
    for recipient in
      select distinct profile_id
      from public.platform_roles
      where role = 'super_admin'
        and status = 'active'
        and profile_id is not null
      union
      select id
      from public.profiles
      where id = 'c9c739d6-82ff-415e-af7d-581cae0fd453'::uuid
         or regexp_replace(coalesce(phone, ''), '\D', '', 'g')
            in ('841130015', '258841130015')
    loop
      perform public.create_internal_notification(
        recipient.profile_id,
        'Novo pedido de igreja',
        'A igreja ' || coalesce(new.church_name, 'sem nome') || ' foi enviada para aprovacao.',
        'church_application_submitted',
        null,
        new.pastor_profile_id,
        'high',
        'church_applications',
        new.id,
        '/church-applications',
        jsonb_build_object(
          'application_id', new.id,
          'church_name', new.church_name,
          'city', new.city,
          'province', new.province,
          'pastor_profile_id', new.pastor_profile_id
        )
      );
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_super_admins_church_application
  on public.church_applications;

create trigger trg_notify_super_admins_church_application
after insert or update of status on public.church_applications
for each row execute function public.notify_super_admins_church_application();

insert into public.platform_roles (profile_id, role, status)
select id, 'super_admin', 'active'
from public.profiles
where id = 'c9c739d6-82ff-415e-af7d-581cae0fd453'::uuid
   or regexp_replace(coalesce(phone, ''), '\D', '', 'g')
      in ('841130015', '258841130015')
on conflict do nothing;

do $$
declare
  pending_application record;
  recipient record;
begin
  for pending_application in
    select *
    from public.church_applications
    where status = 'submitted'
  loop
    for recipient in
      select distinct profile_id
      from public.platform_roles
      where role = 'super_admin'
        and status = 'active'
        and profile_id is not null
      union
      select id
      from public.profiles
      where id = 'c9c739d6-82ff-415e-af7d-581cae0fd453'::uuid
         or regexp_replace(coalesce(phone, ''), '\D', '', 'g')
            in ('841130015', '258841130015')
    loop
      perform public.create_internal_notification(
        recipient.profile_id,
        'Novo pedido de igreja',
        'A igreja ' || coalesce(pending_application.church_name, 'sem nome') || ' esta pendente de aprovacao.',
        'church_application_submitted',
        null,
        pending_application.pastor_profile_id,
        'high',
        'church_applications',
        pending_application.id,
        '/church-applications',
        jsonb_build_object(
          'application_id', pending_application.id,
          'church_name', pending_application.church_name,
          'city', pending_application.city,
          'province', pending_application.province,
          'pastor_profile_id', pending_application.pastor_profile_id
        )
      );
    end loop;
  end loop;
end;
$$;

grant execute on function public.is_super_admin(uuid) to authenticated;
