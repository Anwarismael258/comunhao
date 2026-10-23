alter table public.community_posts
  drop constraint if exists community_posts_media_type_check;

alter table public.community_posts
  add constraint community_posts_media_type_check
  check (
    media_type is null
    or media_type in (
      'image',
      'video',
      'audio',
      'document',
      'external_link',
      'live_stream'
    )
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

  if normalized_media_type is not null
     and normalized_media_type not in (
       'image',
       'video',
       'audio',
       'document',
       'external_link',
       'live_stream'
     ) then
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

  if length(trim(coalesce(p_body, ''))) < 3 then
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

  if normalized_media_type is not null
     and normalized_media_type not in (
       'image',
       'video',
       'audio',
       'document',
       'external_link',
       'live_stream'
     ) then
    raise exception 'Unsupported community media type.';
  end if;

  update public.community_posts
  set
    title = trim(p_title),
    body = trim(p_body),
    image_url = nullif(trim(coalesce(p_image_url, '')), ''),
    community_space = coalesce(normalized_space, community_space, 'general'),
    media_url = nullif(trim(coalesce(p_media_url, '')), ''),
    media_type = normalized_media_type,
    media_mime_type = nullif(trim(coalesce(p_media_mime_type, '')), ''),
    updated_at = now()
  where id = p_post_id
    and author_profile_id = auth.uid()
    and status = 'approved'
  returning * into post_row;

  if not found then
    raise exception 'Post not found or cannot be edited.';
  end if;

  return post_row;
end;
$$;

grant execute on function public.create_community_post(
  uuid, text, text, text, text, text, text, text, text
) to authenticated;

grant execute on function public.update_own_community_post(
  uuid, text, text, text, text, text, text, text
) to authenticated;
