alter table public.community_posts
  add column if not exists community_space text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'community_posts_space_check'
  ) then
    alter table public.community_posts
      add constraint community_posts_space_check
      check (
        community_space is null
        or community_space in (
          'general',
          'youth',
          'couples',
          'women',
          'men',
          'children',
          'worship',
          'intercession',
          'evangelism',
          'missions',
          'cells',
          'new_converts'
        )
      );
  end if;
end $$;

create index if not exists idx_community_posts_church_space
  on public.community_posts(church_id, community_space, status, created_at desc);

create or replace function public.create_community_post(
  p_church_id uuid,
  p_post_type text,
  p_title text,
  p_body text,
  p_image_url text default null,
  p_community_space text default null
)
returns public.community_posts
language plpgsql
security definer
set search_path = public
as $$
declare
  post_row public.community_posts%rowtype;
  normalized_space text := nullif(trim(coalesce(p_community_space, '')), '');
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if normalized_space is null then
    normalized_space := 'general';
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
    case
      when public.can_manage_community_feed(p_church_id, auth.uid()) then 'approved'
      else 'pending'
    end
  )
  returning * into post_row;

  return post_row;
end;
$$;
