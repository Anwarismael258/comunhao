alter table public.community_posts
  add column if not exists pinned_at timestamptz,
  add column if not exists pinned_by uuid references public.profiles(id) on delete set null,
  add column if not exists comments_enabled boolean not null default true;

alter table public.community_post_comments
  add column if not exists parent_comment_id uuid references public.community_post_comments(id) on delete cascade;

create table if not exists public.community_post_saved (
  post_id uuid not null references public.community_posts(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, profile_id)
);

create table if not exists public.community_post_reports (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  reporter_profile_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null default 'inappropriate',
  details text,
  status text not null default 'open',
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (post_id, reporter_profile_id),
  constraint community_post_reports_status_check check (
    status in ('open', 'reviewed', 'dismissed')
  )
);

create table if not exists public.community_member_warnings (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid references public.community_posts(id) on delete set null,
  warning_type text not null default 'content',
  note text,
  issued_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists idx_community_posts_pinned_created
  on public.community_posts(church_id, status, pinned_at desc, created_at desc);

create index if not exists idx_community_comments_parent
  on public.community_post_comments(parent_comment_id);

create index if not exists idx_community_reports_post_status
  on public.community_post_reports(post_id, status, created_at desc);

alter table public.community_post_saved enable row level security;
alter table public.community_post_reports enable row level security;
alter table public.community_member_warnings enable row level security;

drop policy if exists "Users can read own saved community posts" on public.community_post_saved;
create policy "Users can read own saved community posts"
  on public.community_post_saved
  for select
  to authenticated
  using (profile_id = auth.uid());

drop policy if exists "Users can save community posts" on public.community_post_saved;
create policy "Users can save community posts"
  on public.community_post_saved
  for all
  to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

drop policy if exists "Users can read own community reports" on public.community_post_reports;
create policy "Users can read own community reports"
  on public.community_post_reports
  for select
  to authenticated
  using (
    reporter_profile_id = auth.uid()
    or exists (
      select 1
      from public.community_posts p
      where p.id = community_post_reports.post_id
        and public.can_manage_community_feed(p.church_id, auth.uid())
    )
  );

drop policy if exists "Managers can read member warnings" on public.community_member_warnings;
create policy "Managers can read member warnings"
  on public.community_member_warnings
  for select
  to authenticated
  using (public.can_manage_community_feed(church_id, auth.uid()));

create or replace function public.update_own_community_post(
  p_post_id uuid,
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
    community_space = coalesce(normalized_space, community_space, 'general')
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

create or replace function public.delete_own_community_post(
  p_post_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.community_posts
  set status = 'archived'
  where id = p_post_id
    and author_profile_id = auth.uid()
    and status = 'approved';

  if not found then
    raise exception 'Community post not removable.';
  end if;
end;
$$;

create or replace function public.set_community_post_saved(
  p_post_id uuid,
  p_saved boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
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

  if p_saved then
    insert into public.community_post_saved (post_id, profile_id)
    values (p_post_id, auth.uid())
    on conflict (post_id, profile_id) do nothing;
  else
    delete from public.community_post_saved
    where post_id = p_post_id
      and profile_id = auth.uid();
  end if;
end;
$$;

create or replace function public.report_community_post(
  p_post_id uuid,
  p_reason text,
  p_details text default null
)
returns public.community_post_reports
language plpgsql
security definer
set search_path = public
as $$
declare
  report_row public.community_post_reports%rowtype;
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

  insert into public.community_post_reports (
    post_id,
    reporter_profile_id,
    reason,
    details,
    status
  )
  values (
    p_post_id,
    auth.uid(),
    coalesce(nullif(trim(p_reason), ''), 'inappropriate'),
    nullif(trim(coalesce(p_details, '')), ''),
    'open'
  )
  on conflict (post_id, reporter_profile_id) do update
  set
    reason = excluded.reason,
    details = excluded.details,
    status = 'open',
    reviewed_by = null,
    reviewed_at = null
  returning * into report_row;

  return report_row;
end;
$$;

create or replace function public.set_community_post_pinned(
  p_post_id uuid,
  p_pinned boolean
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
    pinned_at = case when p_pinned then now() else null end,
    pinned_by = case when p_pinned then auth.uid() else null end
  where id = p_post_id
  returning * into post_row;

  return post_row;
end;
$$;

create or replace function public.set_community_post_comments_enabled(
  p_post_id uuid,
  p_enabled boolean
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
  set comments_enabled = p_enabled
  where id = p_post_id
  returning * into post_row;

  return post_row;
end;
$$;

create or replace function public.warn_community_post_author(
  p_post_id uuid,
  p_note text default null,
  p_suspend boolean default false
)
returns void
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

  insert into public.community_member_warnings (
    church_id,
    profile_id,
    post_id,
    warning_type,
    note,
    issued_by
  )
  values (
    post_row.church_id,
    post_row.author_profile_id,
    p_post_id,
    case when p_suspend then 'suspension' else 'warning' end,
    nullif(trim(coalesce(p_note, '')), ''),
    auth.uid()
  );

  if p_suspend then
    update public.memberships
    set status = 'blocked'
    where church_id = post_row.church_id
      and profile_id = post_row.author_profile_id;
  end if;
end;
$$;

create or replace function public.comment_on_community_post(
  p_post_id uuid,
  p_body text,
  p_parent_comment_id uuid default null
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
      and p.comments_enabled
      and m.profile_id = auth.uid()
      and m.status = 'active'
  ) then
    raise exception 'Community post not available for comments.';
  end if;

  if p_parent_comment_id is not null and not exists (
    select 1
    from public.community_post_comments c
    where c.id = p_parent_comment_id
      and c.post_id = p_post_id
      and c.status = 'visible'
  ) then
    raise exception 'Parent comment not found.';
  end if;

  insert into public.community_post_comments (
    post_id,
    profile_id,
    parent_comment_id,
    body
  )
  values (p_post_id, auth.uid(), p_parent_comment_id, trim(p_body))
  returning * into comment_row;

  return comment_row;
end;
$$;

grant select, insert, update, delete on public.community_post_saved to authenticated;
grant select, insert, update on public.community_post_reports to authenticated;
grant select on public.community_member_warnings to authenticated;
grant execute on function public.update_own_community_post(uuid, text, text, text, text) to authenticated;
grant execute on function public.delete_own_community_post(uuid) to authenticated;
grant execute on function public.set_community_post_saved(uuid, boolean) to authenticated;
grant execute on function public.report_community_post(uuid, text, text) to authenticated;
grant execute on function public.set_community_post_pinned(uuid, boolean) to authenticated;
grant execute on function public.set_community_post_comments_enabled(uuid, boolean) to authenticated;
grant execute on function public.warn_community_post_author(uuid, text, boolean) to authenticated;
