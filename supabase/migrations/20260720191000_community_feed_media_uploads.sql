alter table public.community_posts
  add column if not exists media_url text,
  add column if not exists media_type text,
  add column if not exists media_mime_type text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'community_posts_media_type_check'
  ) then
    alter table public.community_posts
      add constraint community_posts_media_type_check
      check (media_type is null or media_type in ('image', 'video'));
  end if;
end $$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'community-media',
  'community-media',
  true,
  104857600,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'video/mp4',
    'video/quicktime',
    'video/webm'
  ]
)
on conflict (id) do update
set
  public = true,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can read community media files" on storage.objects;
create policy "Public can read community media files"
  on storage.objects
  for select
  using (bucket_id = 'community-media');

drop policy if exists "Active members can upload community media files" on storage.objects;
create policy "Active members can upload community media files"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'community-media'
    and exists (
      select 1
      from public.memberships m
      where m.profile_id = auth.uid()
        and m.status = 'active'
        and split_part(storage.objects.name, '/', 1) = m.church_id::text
    )
  );

drop policy if exists "Active members can update own community media files" on storage.objects;
create policy "Active members can update own community media files"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'community-media'
    and split_part(storage.objects.name, '/', 2) = auth.uid()::text
  )
  with check (
    bucket_id = 'community-media'
    and split_part(storage.objects.name, '/', 2) = auth.uid()::text
  );

drop policy if exists "Active members can remove own community media files" on storage.objects;
create policy "Active members can remove own community media files"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'community-media'
    and split_part(storage.objects.name, '/', 2) = auth.uid()::text
  );

create or replace function public.create_community_post(
  p_church_id uuid,
  p_post_type text,
  p_title text,
  p_body text,
  p_image_url text default null,
  p_community_space text default null,
  p_media_url text default null,
  p_media_type text default null,
  p_media_mime_type text default null
)
returns public.community_posts
language plpgsql
security definer
set search_path = public
as $$
declare
  post_row public.community_posts%rowtype;
  normalized_space text := nullif(trim(coalesce(p_community_space, '')), '');
  normalized_media_type text := nullif(trim(coalesce(p_media_type, '')), '');
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if normalized_space is null then
    normalized_space := 'general';
  end if;

  if normalized_media_type is not null and normalized_media_type not in ('image', 'video') then
    raise exception 'Unsupported community media type.';
  end if;

  if not exists (
    select 1
    from public.memberships m
    where m.church_id = p_church_id
      and m.profile_id = auth.uid()
      and m.status = 'active'
  ) then
    raise exception 'Member is not active in this church.';
  end if;

  if length(trim(coalesce(p_title, ''))) < 3 then
    raise exception 'Title is too short.';
  end if;

  if length(trim(coalesce(p_body, ''))) < 5 then
    raise exception 'Body is too short.';
  end if;

  insert into public.community_posts (
    church_id,
    author_profile_id,
    post_type,
    title,
    body,
    image_url,
    community_space,
    media_url,
    media_type,
    media_mime_type,
    status
  )
  values (
    p_church_id,
    auth.uid(),
    coalesce(nullif(trim(p_post_type), ''), 'testimony'),
    trim(p_title),
    trim(p_body),
    nullif(trim(coalesce(p_image_url, '')), ''),
    normalized_space,
    nullif(trim(coalesce(p_media_url, '')), ''),
    normalized_media_type,
    nullif(trim(coalesce(p_media_mime_type, '')), ''),
    'approved'
  )
  returning * into post_row;

  return post_row;
end;
$$;

create or replace function public.update_own_community_post(
  p_post_id uuid,
  p_title text,
  p_body text,
  p_image_url text default null,
  p_community_space text default null,
  p_media_url text default null,
  p_media_type text default null,
  p_media_mime_type text default null
)
returns public.community_posts
language plpgsql
security definer
set search_path = public
as $$
declare
  post_row public.community_posts%rowtype;
  normalized_space text := nullif(trim(coalesce(p_community_space, '')), '');
  normalized_media_type text := nullif(trim(coalesce(p_media_type, '')), '');
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if normalized_media_type is not null and normalized_media_type not in ('image', 'video') then
    raise exception 'Unsupported community media type.';
  end if;

  if length(trim(coalesce(p_title, ''))) < 3 then
    raise exception 'Title is too short.';
  end if;

  if length(trim(coalesce(p_body, ''))) < 5 then
    raise exception 'Body is too short.';
  end if;

  update public.community_posts
  set
    title = trim(p_title),
    body = trim(p_body),
    image_url = nullif(trim(coalesce(p_image_url, '')), ''),
    community_space = coalesce(normalized_space, community_space, 'general'),
    media_url = nullif(trim(coalesce(p_media_url, '')), ''),
    media_type = normalized_media_type,
    media_mime_type = nullif(trim(coalesce(p_media_mime_type, '')), '')
  where id = p_post_id
    and author_profile_id = auth.uid()
    and status = 'approved'
  returning * into post_row;

  if not found then
    raise exception 'Community post not editable.';
  end if;

  return post_row;
end;
$$;
