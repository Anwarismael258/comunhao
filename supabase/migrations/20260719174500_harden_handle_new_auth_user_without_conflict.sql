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

  update public.profiles
  set
    full_name = coalesce(new.raw_user_meta_data ->> 'full_name', 'Membro'),
    phone = new.phone,
    birth_date = coalesce(metadata_birth_date, public.profiles.birth_date)
  where id = new.id;

  if not found then
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
    );
  end if;

  if metadata_church_id is not null then
    update public.memberships
    set
      status = 'active',
      role = public.memberships.role
    where church_id = metadata_church_id
      and profile_id = new.id;

    if not found then
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
      );
    end if;
  end if;

  return new;
end;
$$;
