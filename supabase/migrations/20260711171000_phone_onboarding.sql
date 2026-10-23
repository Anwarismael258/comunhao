alter table public.churches add column if not exists join_code text;
alter table public.profiles add column if not exists birth_date date;

create unique index if not exists idx_churches_join_code_unique
  on public.churches ((upper(join_code)))
  where join_code is not null;

create unique index if not exists idx_profiles_phone_unique
  on public.profiles (phone)
  where phone is not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'memberships_role_check'
  ) then
    alter table public.memberships
      add constraint memberships_role_check
      check (role in ('super_admin', 'church_admin', 'pastor', 'leader', 'member'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'memberships_status_check'
  ) then
    alter table public.memberships
      add constraint memberships_status_check
      check (status in ('active', 'blocked', 'removed', 'transferred'));
  end if;
end $$;

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  metadata_church_id uuid;
  metadata_birth_date date;
begin
  begin
    if coalesce(new.raw_user_meta_data ->> 'church_id', '') <> '' then
      metadata_church_id := (new.raw_user_meta_data ->> 'church_id')::uuid;
    elsif coalesce(new.raw_user_meta_data ->> 'church_slug', '') <> '' then
      select id
      into metadata_church_id
      from public.churches
      where slug = new.raw_user_meta_data ->> 'church_slug'
      limit 1;
    end if;
  exception
    when others then
      metadata_church_id := null;
  end;

  begin
    if coalesce(new.raw_user_meta_data ->> 'birth_date', '') <> '' then
      metadata_birth_date := (new.raw_user_meta_data ->> 'birth_date')::date;
    end if;
  exception
    when others then
      metadata_birth_date := null;
  end;

  insert into public.profiles (
    id,
    full_name,
    phone,
    birth_date
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', 'Membro'),
    new.phone,
    metadata_birth_date
  )
  on conflict (id) do update
    set
      full_name = excluded.full_name,
      phone = excluded.phone,
      birth_date = coalesce(excluded.birth_date, public.profiles.birth_date);

  if metadata_church_id is not null then
    insert into public.memberships (
      church_id,
      profile_id,
      role,
      status
    )
    values (
      metadata_church_id,
      new.id,
      'member',
      'active'
    )
    on conflict (church_id, profile_id) do update
      set
        status = 'active',
        role = public.memberships.role;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_auth_user();

grant select, update on public.profiles to authenticated;
grant select on public.memberships to authenticated;
grant select, insert, update on public.prayer_requests to authenticated;
grant select, insert, update, delete on public.push_tokens to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'Users can read own profile'
  ) then
    create policy "Users can read own profile"
      on public.profiles
      for select
      to authenticated
      using (auth.uid() = id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'Users can update own profile'
  ) then
    create policy "Users can update own profile"
      on public.profiles
      for update
      to authenticated
      using (auth.uid() = id)
      with check (auth.uid() = id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'memberships'
      and policyname = 'Users can read own memberships'
  ) then
    create policy "Users can read own memberships"
      on public.memberships
      for select
      to authenticated
      using (auth.uid() = profile_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'prayer_requests'
      and policyname = 'Users can manage own prayer requests'
  ) then
    create policy "Users can manage own prayer requests"
      on public.prayer_requests
      for all
      to authenticated
      using (auth.uid() = profile_id)
      with check (auth.uid() = profile_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'push_tokens'
      and policyname = 'Users can manage own push tokens'
  ) then
    create policy "Users can manage own push tokens"
      on public.push_tokens
      for all
      to authenticated
      using (auth.uid() = profile_id)
      with check (auth.uid() = profile_id);
  end if;
end $$;
