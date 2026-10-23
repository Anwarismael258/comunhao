create table if not exists public.community_posts (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  author_profile_id uuid not null references public.profiles(id) on delete cascade,
  post_type text not null default 'testimony',
  title text not null,
  body text not null,
  image_url text,
  status text not null default 'pending',
  moderation_note text,
  moderated_by uuid references public.profiles(id) on delete set null,
  moderated_at timestamptz,
  answered_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint community_posts_type_check check (post_type in (
    'testimony',
    'verse',
    'reflection',
    'photo',
    'prayer',
    'gratitude',
    'evangelism',
    'invitation'
  )),
  constraint community_posts_status_check check (status in (
    'pending',
    'approved',
    'rejected',
    'archived'
  ))
);

create table if not exists public.community_post_reactions (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  reaction_type text not null default 'amen',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (post_id, profile_id),
  constraint community_reaction_type_check check (reaction_type in (
    'amen',
    'praying',
    'glory',
    'built',
    'faithful'
  ))
);

create table if not exists public.community_post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  status text not null default 'visible',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint community_comment_status_check check (status in (
    'visible',
    'hidden',
    'removed'
  ))
);

drop trigger if exists touch_community_posts_updated_at on public.community_posts;
create trigger touch_community_posts_updated_at
  before update on public.community_posts
  for each row execute function public.touch_updated_at();

drop trigger if exists touch_community_post_reactions_updated_at on public.community_post_reactions;
create trigger touch_community_post_reactions_updated_at
  before update on public.community_post_reactions
  for each row execute function public.touch_updated_at();

drop trigger if exists touch_community_post_comments_updated_at on public.community_post_comments;
create trigger touch_community_post_comments_updated_at
  before update on public.community_post_comments
  for each row execute function public.touch_updated_at();

create index if not exists idx_community_posts_church_status
  on public.community_posts(church_id, status, created_at desc);

create index if not exists idx_community_reactions_post
  on public.community_post_reactions(post_id);

create index if not exists idx_community_comments_post
  on public.community_post_comments(post_id, status, created_at);

create or replace function public.can_manage_community_feed(
  p_church_id uuid,
  check_user uuid default auth.uid()
)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select public.has_church_role(
    p_church_id,
    array['pastor', 'church_admin', 'leader']::text[],
    coalesce(check_user, auth.uid())
  );
$$;

create or replace function public.create_community_post(
  p_church_id uuid,
  p_post_type text,
  p_title text,
  p_body text,
  p_image_url text default null
)
returns public.community_posts
language plpgsql
security definer
set search_path = public
as $$
declare
  post_row public.community_posts%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
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
    status
  )
  values (
    p_church_id,
    auth.uid(),
    coalesce(nullif(trim(p_post_type), ''), 'testimony'),
    trim(p_title),
    trim(p_body),
    nullif(trim(coalesce(p_image_url, '')), ''),
    case
      when public.can_manage_community_feed(p_church_id, auth.uid()) then 'approved'
      else 'pending'
    end
  )
  returning * into post_row;

  return post_row;
end;
$$;

create or replace function public.moderate_community_post(
  p_post_id uuid,
  p_status text,
  p_note text default null
)
returns public.community_posts
language plpgsql
security definer
set search_path = public
as $$
declare
  post_row public.community_posts%rowtype;
begin
  select *
  into post_row
  from public.community_posts
  where id = p_post_id;

  if not found then
    raise exception 'Community post not found.';
  end if;

  if not public.can_manage_community_feed(post_row.church_id, auth.uid()) then
    raise exception 'Permission denied.';
  end if;

  update public.community_posts
  set
    status = p_status,
    moderation_note = nullif(trim(coalesce(p_note, '')), ''),
    moderated_by = auth.uid(),
    moderated_at = now()
  where id = p_post_id
  returning * into post_row;

  return post_row;
end;
$$;

create or replace function public.mark_community_prayer_answered(
  p_post_id uuid
)
returns public.community_posts
language plpgsql
security definer
set search_path = public
as $$
declare
  post_row public.community_posts%rowtype;
begin
  update public.community_posts
  set answered_at = now()
  where id = p_post_id
    and author_profile_id = auth.uid()
    and post_type = 'prayer'
  returning * into post_row;

  if not found then
    raise exception 'Prayer post not found.';
  end if;

  return post_row;
end;
$$;

create or replace function public.react_to_community_post(
  p_post_id uuid,
  p_reaction_type text
)
returns public.community_post_reactions
language plpgsql
security definer
set search_path = public
as $$
declare
  reaction_row public.community_post_reactions%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if not exists (
    select 1
    from public.community_posts p
    join public.memberships m on m.church_id = p.church_id
    where p.id = p_post_id
      and p.status = 'approved'
      and m.profile_id = auth.uid()
      and m.status = 'active'
  ) then
    raise exception 'Community post not available.';
  end if;

  insert into public.community_post_reactions (
    post_id,
    profile_id,
    reaction_type
  )
  values (
    p_post_id,
    auth.uid(),
    coalesce(nullif(trim(p_reaction_type), ''), 'amen')
  )
  on conflict (post_id, profile_id) do update
  set reaction_type = excluded.reaction_type
  returning * into reaction_row;

  return reaction_row;
end;
$$;

create or replace function public.comment_on_community_post(
  p_post_id uuid,
  p_body text
)
returns public.community_post_comments
language plpgsql
security definer
set search_path = public
as $$
declare
  comment_row public.community_post_comments%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if length(trim(coalesce(p_body, ''))) < 2 then
    raise exception 'Comment is too short.';
  end if;

  if not exists (
    select 1
    from public.community_posts p
    join public.memberships m on m.church_id = p.church_id
    where p.id = p_post_id
      and p.status = 'approved'
      and m.profile_id = auth.uid()
      and m.status = 'active'
  ) then
    raise exception 'Community post not available.';
  end if;

  insert into public.community_post_comments (
    post_id,
    profile_id,
    body
  )
  values (p_post_id, auth.uid(), trim(p_body))
  returning * into comment_row;

  return comment_row;
end;
$$;

alter table public.community_posts enable row level security;
alter table public.community_post_reactions enable row level security;
alter table public.community_post_comments enable row level security;

drop policy if exists "Members can read approved community posts" on public.community_posts;
create policy "Members can read approved community posts"
  on public.community_posts
  for select
  to authenticated
  using (
    status = 'approved'
    and exists (
      select 1
      from public.memberships m
      where m.church_id = community_posts.church_id
        and m.profile_id = auth.uid()
        and m.status = 'active'
    )
  );

drop policy if exists "Authors can read own community posts" on public.community_posts;
create policy "Authors can read own community posts"
  on public.community_posts
  for select
  to authenticated
  using (author_profile_id = auth.uid());

drop policy if exists "Managers can read community posts" on public.community_posts;
create policy "Managers can read community posts"
  on public.community_posts
  for select
  to authenticated
  using (public.can_manage_community_feed(church_id, auth.uid()));

drop policy if exists "Members can read community reactions" on public.community_post_reactions;
create policy "Members can read community reactions"
  on public.community_post_reactions
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.community_posts p
      join public.memberships m on m.church_id = p.church_id
      where p.id = community_post_reactions.post_id
        and m.profile_id = auth.uid()
        and m.status = 'active'
    )
  );

drop policy if exists "Members can read community comments" on public.community_post_comments;
create policy "Members can read community comments"
  on public.community_post_comments
  for select
  to authenticated
  using (
    status = 'visible'
    and exists (
      select 1
      from public.community_posts p
      join public.memberships m on m.church_id = p.church_id
      where p.id = community_post_comments.post_id
        and m.profile_id = auth.uid()
        and m.status = 'active'
    )
  );
