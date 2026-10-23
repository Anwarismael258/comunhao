create table if not exists public.pastoral_publications (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  author_user_id uuid references public.profiles(id) on delete set null,
  title text not null,
  slug text not null,
  summary text,
  content text not null,
  publication_type text not null default 'pastoral_message',
  category text not null default 'geral',
  cover_image_url text,
  audio_url text,
  video_url text,
  document_url text,
  live_stream_url text,
  external_url text,
  status text not null default 'draft',
  visibility text not null default 'members',
  priority text not null default 'normal',
  published_at timestamptz,
  scheduled_at timestamptz,
  expires_at timestamptz,
  allow_comments boolean not null default false,
  allow_reactions boolean not null default true,
  allow_sharing boolean not null default true,
  send_notification boolean not null default false,
  is_featured boolean not null default false,
  is_pinned boolean not null default false,
  is_demo boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (church_id, slug)
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'pastoral_publications_type_check'
  ) then
    alter table public.pastoral_publications
      add constraint pastoral_publications_type_check
      check (publication_type in (
        'announcement',
        'sermon',
        'devotional',
        'bible_study',
        'pastoral_message',
        'leadership_message',
        'testimony',
        'urgent_notice',
        'video',
        'audio',
        'document',
        'live_stream'
      ));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'pastoral_publications_status_check'
  ) then
    alter table public.pastoral_publications
      add constraint pastoral_publications_status_check
      check (status in ('draft', 'scheduled', 'published', 'archived', 'cancelled'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'pastoral_publications_visibility_check'
  ) then
    alter table public.pastoral_publications
      add constraint pastoral_publications_visibility_check
      check (visibility in (
        'all',
        'members',
        'visitors',
        'pastors',
        'leaders',
        'youth',
        'men',
        'women',
        'children',
        'ministry',
        'group',
        'selected_users'
      ));
  end if;
end $$;

create table if not exists public.pastoral_publication_segments (
  id uuid primary key default gen_random_uuid(),
  publication_id uuid not null references public.pastoral_publications(id) on delete cascade,
  segment_type text not null,
  segment_value text,
  ministry_id uuid references public.church_ministries(id) on delete cascade,
  membership_id uuid references public.memberships(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.pastoral_publication_reads (
  id uuid primary key default gen_random_uuid(),
  publication_id uuid not null references public.pastoral_publications(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  first_viewed_at timestamptz not null default now(),
  last_viewed_at timestamptz not null default now(),
  open_count integer not null default 1,
  read_percent integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (publication_id, profile_id)
);

create table if not exists public.pastoral_publication_saved (
  id uuid primary key default gen_random_uuid(),
  publication_id uuid not null references public.pastoral_publications(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (publication_id, profile_id)
);

create table if not exists public.pastoral_publication_reactions (
  id uuid primary key default gen_random_uuid(),
  publication_id uuid not null references public.pastoral_publications(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  reaction_type text not null default 'amen',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (publication_id, profile_id)
);

create table if not exists public.pastoral_publication_comments (
  id uuid primary key default gen_random_uuid(),
  publication_id uuid not null references public.pastoral_publications(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  parent_comment_id uuid references public.pastoral_publication_comments(id) on delete cascade,
  body text not null,
  status text not null default 'active',
  moderation_notes text,
  moderated_by uuid references public.profiles(id) on delete set null,
  moderated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.pastoral_publication_state_history (
  id uuid primary key default gen_random_uuid(),
  publication_id uuid not null references public.pastoral_publications(id) on delete cascade,
  changed_by uuid references public.profiles(id) on delete set null,
  previous_status text,
  new_status text not null,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.pastoral_publication_audit_logs (
  id uuid primary key default gen_random_uuid(),
  publication_id uuid references public.pastoral_publications(id) on delete set null,
  actor_profile_id uuid references public.profiles(id) on delete set null,
  church_id uuid references public.churches(id) on delete cascade,
  action text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_pastoral_publications_church_status
  on public.pastoral_publications(church_id, status, published_at desc);

create index if not exists idx_pastoral_publications_type
  on public.pastoral_publications(church_id, publication_type);

create index if not exists idx_pastoral_publications_featured
  on public.pastoral_publications(church_id, is_featured, is_pinned);

create index if not exists idx_pastoral_segments_publication
  on public.pastoral_publication_segments(publication_id);

create index if not exists idx_pastoral_reads_publication
  on public.pastoral_publication_reads(publication_id);

create index if not exists idx_pastoral_comments_publication
  on public.pastoral_publication_comments(publication_id, status, created_at);

drop trigger if exists touch_pastoral_publications_updated_at on public.pastoral_publications;
create trigger touch_pastoral_publications_updated_at
  before update on public.pastoral_publications
  for each row execute function public.touch_updated_at();

drop trigger if exists touch_pastoral_publication_reads_updated_at on public.pastoral_publication_reads;
create trigger touch_pastoral_publication_reads_updated_at
  before update on public.pastoral_publication_reads
  for each row execute function public.touch_updated_at();

drop trigger if exists touch_pastoral_publication_reactions_updated_at on public.pastoral_publication_reactions;
create trigger touch_pastoral_publication_reactions_updated_at
  before update on public.pastoral_publication_reactions
  for each row execute function public.touch_updated_at();

drop trigger if exists touch_pastoral_publication_comments_updated_at on public.pastoral_publication_comments;
create trigger touch_pastoral_publication_comments_updated_at
  before update on public.pastoral_publication_comments
  for each row execute function public.touch_updated_at();

create or replace function public.slugify_publication_title(value text)
returns text
language sql
immutable
as $$
  select trim(both '-' from regexp_replace(lower(coalesce(value, '')), '[^a-z0-9]+', '-', 'g'));
$$;

create or replace function public.can_view_pastoral_publication(
  p_publication_id uuid,
  check_user uuid default auth.uid()
)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  with publication as (
    select *
    from public.pastoral_publications
    where id = p_publication_id
  ),
  viewer_membership as (
    select m.*
    from public.memberships m
    join publication p on p.church_id = m.church_id
    where m.profile_id = coalesce(check_user, auth.uid())
      and m.status = 'active'
    limit 1
  )
  select exists (
    select 1
    from publication p
    where (
      public.has_church_role(
        p.church_id,
        array['pastor', 'church_admin', 'leader']::text[],
        coalesce(check_user, auth.uid())
      )
      or (
        p.status = 'published'
        and (p.published_at is null or p.published_at <= now())
        and (p.expires_at is null or p.expires_at > now())
        and exists (select 1 from viewer_membership)
        and (
          p.visibility in ('all', 'members', 'visitors', 'youth', 'men', 'women', 'children')
          or (p.visibility = 'pastors' and exists (
            select 1 from viewer_membership vm
            where vm.role in ('pastor', 'church_admin')
          ))
          or (p.visibility = 'leaders' and exists (
            select 1 from viewer_membership vm
            where vm.role in ('pastor', 'church_admin', 'leader')
          ))
          or exists (
            select 1
            from public.pastoral_publication_segments s
            left join viewer_membership vm on true
            where s.publication_id = p.id
              and (
                (s.segment_type = 'role' and s.segment_value = vm.role)
                or (s.segment_type = 'membership' and s.membership_id = vm.id)
                or (s.segment_type = 'ministry' and exists (
                  select 1
                  from public.ministry_members mm
                  where mm.ministry_id = s.ministry_id
                    and mm.membership_id = vm.id
                ))
              )
          )
        )
      )
    )
  );
$$;

create or replace function public.record_pastoral_publication_read(
  p_publication_id uuid,
  p_read_percent integer default 100
)
returns public.pastoral_publication_reads
language plpgsql
security definer
set search_path = public
as $$
declare
  read_row public.pastoral_publication_reads%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if not public.can_view_pastoral_publication(p_publication_id, auth.uid()) then
    raise exception 'Publication not available.';
  end if;

  insert into public.pastoral_publication_reads (
    publication_id,
    profile_id,
    read_percent
  )
  values (
    p_publication_id,
    auth.uid(),
    greatest(0, least(coalesce(p_read_percent, 100), 100))
  )
  on conflict (publication_id, profile_id) do update
  set
    last_viewed_at = now(),
    open_count = public.pastoral_publication_reads.open_count + 1,
    read_percent = greatest(
      public.pastoral_publication_reads.read_percent,
      greatest(0, least(coalesce(p_read_percent, 100), 100))
    )
  returning * into read_row;

  return read_row;
end;
$$;

create or replace function public.toggle_pastoral_publication_saved(
  p_publication_id uuid,
  p_saved boolean
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if not public.can_view_pastoral_publication(p_publication_id, auth.uid()) then
    raise exception 'Publication not available.';
  end if;

  if p_saved then
    insert into public.pastoral_publication_saved (publication_id, profile_id)
    values (p_publication_id, auth.uid())
    on conflict (publication_id, profile_id) do nothing;
  else
    delete from public.pastoral_publication_saved
    where publication_id = p_publication_id
      and profile_id = auth.uid();
  end if;

  return p_saved;
end;
$$;

create or replace function public.react_to_pastoral_publication(
  p_publication_id uuid,
  p_reaction_type text default 'amen'
)
returns public.pastoral_publication_reactions
language plpgsql
security definer
set search_path = public
as $$
declare
  reaction_row public.pastoral_publication_reactions%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if not exists (
    select 1
    from public.pastoral_publications
    where id = p_publication_id
      and allow_reactions = true
  ) then
    raise exception 'Reactions are not enabled.';
  end if;

  if not public.can_view_pastoral_publication(p_publication_id, auth.uid()) then
    raise exception 'Publication not available.';
  end if;

  insert into public.pastoral_publication_reactions (
    publication_id,
    profile_id,
    reaction_type
  )
  values (p_publication_id, auth.uid(), coalesce(nullif(trim(p_reaction_type), ''), 'amen'))
  on conflict (publication_id, profile_id) do update
  set reaction_type = excluded.reaction_type
  returning * into reaction_row;

  return reaction_row;
end;
$$;

create or replace function public.comment_on_pastoral_publication(
  p_publication_id uuid,
  p_body text,
  p_parent_comment_id uuid default null
)
returns public.pastoral_publication_comments
language plpgsql
security definer
set search_path = public
as $$
declare
  comment_row public.pastoral_publication_comments%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if length(trim(coalesce(p_body, ''))) < 2 then
    raise exception 'Comment is too short.';
  end if;

  if not exists (
    select 1
    from public.pastoral_publications
    where id = p_publication_id
      and allow_comments = true
  ) then
    raise exception 'Comments are not enabled.';
  end if;

  if not public.can_view_pastoral_publication(p_publication_id, auth.uid()) then
    raise exception 'Publication not available.';
  end if;

  insert into public.pastoral_publication_comments (
    publication_id,
    profile_id,
    parent_comment_id,
    body
  )
  values (
    p_publication_id,
    auth.uid(),
    p_parent_comment_id,
    trim(p_body)
  )
  returning * into comment_row;

  return comment_row;
end;
$$;

create or replace function public.publish_scheduled_pastoral_publications()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  published_count integer := 0;
begin
  update public.pastoral_publications
  set
    status = 'published',
    published_at = coalesce(published_at, now())
  where status = 'scheduled'
    and scheduled_at is not null
    and scheduled_at <= now();

  get diagnostics published_count = row_count;
  return published_count;
end;
$$;

create or replace function public.get_manageable_pastoral_publications(
  p_church_id uuid
)
returns table (
  id uuid,
  church_id uuid,
  author_user_id uuid,
  title text,
  slug text,
  summary text,
  content text,
  publication_type text,
  category text,
  cover_image_url text,
  audio_url text,
  video_url text,
  document_url text,
  live_stream_url text,
  external_url text,
  status text,
  visibility text,
  priority text,
  published_at timestamptz,
  scheduled_at timestamptz,
  expires_at timestamptz,
  allow_comments boolean,
  allow_reactions boolean,
  allow_sharing boolean,
  send_notification boolean,
  is_featured boolean,
  is_pinned boolean,
  is_demo boolean,
  created_at timestamptz,
  updated_at timestamptz,
  read_count bigint,
  open_count bigint,
  saved_count bigint,
  reaction_count bigint,
  comment_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.church_id,
    p.author_user_id,
    p.title,
    p.slug,
    p.summary,
    p.content,
    p.publication_type,
    p.category,
    p.cover_image_url,
    p.audio_url,
    p.video_url,
    p.document_url,
    p.live_stream_url,
    p.external_url,
    p.status,
    p.visibility,
    p.priority,
    p.published_at,
    p.scheduled_at,
    p.expires_at,
    p.allow_comments,
    p.allow_reactions,
    p.allow_sharing,
    p.send_notification,
    p.is_featured,
    p.is_pinned,
    p.is_demo,
    p.created_at,
    p.updated_at,
    count(distinct r.profile_id) as read_count,
    coalesce(sum(r.open_count), 0)::bigint as open_count,
    count(distinct s.profile_id) as saved_count,
    count(distinct re.profile_id) as reaction_count,
    count(distinct c.id) filter (where c.status = 'active') as comment_count
  from public.pastoral_publications p
  left join public.pastoral_publication_reads r on r.publication_id = p.id
  left join public.pastoral_publication_saved s on s.publication_id = p.id
  left join public.pastoral_publication_reactions re on re.publication_id = p.id
  left join public.pastoral_publication_comments c on c.publication_id = p.id
  where p.church_id = p_church_id
    and public.has_church_role(
      p.church_id,
      array['pastor', 'church_admin', 'leader']::text[],
      auth.uid()
    )
  group by p.id
  order by p.is_pinned desc, p.created_at desc;
$$;

create or replace function public.notify_publication_published()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  membership_row record;
begin
  if new.status <> 'published'
     or coalesce(new.send_notification, false) is false
     or (tg_op = 'UPDATE' and old.status = 'published') then
    return new;
  end if;

  for membership_row in
    select m.profile_id
    from public.memberships m
    where m.church_id = new.church_id
      and m.status = 'active'
      and public.can_view_pastoral_publication(new.id, m.profile_id)
  loop
    perform public.create_internal_notification(
      membership_row.profile_id,
      new.title,
      coalesce(new.summary, 'Nova publicacao da igreja.'),
      case
        when new.publication_type = 'urgent_notice' then 'urgent_notice'
        else 'pastoral_publication'
      end,
      new.church_id,
      new.author_user_id,
      case
        when new.publication_type = 'urgent_notice' then 'urgent'
        else 'normal'
      end,
      'pastoral_publications',
      new.id,
      '/publications/' || new.id::text,
      jsonb_build_object(
        'publication_type', new.publication_type,
        'visibility', new.visibility
      )
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists notify_pastoral_publication_inserted on public.pastoral_publications;
create trigger notify_pastoral_publication_inserted
  after insert on public.pastoral_publications
  for each row execute function public.notify_publication_published();

drop trigger if exists notify_pastoral_publication_published on public.pastoral_publications;
create trigger notify_pastoral_publication_published
  after update of status on public.pastoral_publications
  for each row execute function public.notify_publication_published();

alter table public.pastoral_publications enable row level security;
alter table public.pastoral_publication_segments enable row level security;
alter table public.pastoral_publication_reads enable row level security;
alter table public.pastoral_publication_saved enable row level security;
alter table public.pastoral_publication_reactions enable row level security;
alter table public.pastoral_publication_comments enable row level security;
alter table public.pastoral_publication_state_history enable row level security;
alter table public.pastoral_publication_audit_logs enable row level security;

drop policy if exists "Members can read available pastoral publications" on public.pastoral_publications;
create policy "Members can read available pastoral publications"
  on public.pastoral_publications
  for select
  to authenticated
  using (public.can_view_pastoral_publication(id, auth.uid()));

drop policy if exists "Church admins can manage pastoral publications" on public.pastoral_publications;
create policy "Church admins can manage pastoral publications"
  on public.pastoral_publications
  for all
  to authenticated
  using (public.has_church_role(church_id, array['pastor', 'church_admin', 'leader']::text[]))
  with check (public.has_church_role(church_id, array['pastor', 'church_admin', 'leader']::text[]));

drop policy if exists "Church admins can manage publication segments" on public.pastoral_publication_segments;
create policy "Church admins can manage publication segments"
  on public.pastoral_publication_segments
  for all
  to authenticated
  using (exists (
    select 1 from public.pastoral_publications p
    where p.id = publication_id
      and public.has_church_role(p.church_id, array['pastor', 'church_admin', 'leader']::text[])
  ))
  with check (exists (
    select 1 from public.pastoral_publications p
    where p.id = publication_id
      and public.has_church_role(p.church_id, array['pastor', 'church_admin', 'leader']::text[])
  ));

drop policy if exists "Users can read own publication reads" on public.pastoral_publication_reads;
create policy "Users can read own publication reads"
  on public.pastoral_publication_reads
  for select
  to authenticated
  using (
    profile_id = auth.uid()
    or exists (
      select 1 from public.pastoral_publications p
      where p.id = publication_id
        and public.has_church_role(p.church_id, array['pastor', 'church_admin', 'leader']::text[])
    )
  );

drop policy if exists "Users can read own saved publications" on public.pastoral_publication_saved;
create policy "Users can read own saved publications"
  on public.pastoral_publication_saved
  for select
  to authenticated
  using (profile_id = auth.uid());

drop policy if exists "Users can read own reactions and aggregate allowed" on public.pastoral_publication_reactions;
create policy "Users can read own reactions and aggregate allowed"
  on public.pastoral_publication_reactions
  for select
  to authenticated
  using (
    profile_id = auth.uid()
    or exists (
      select 1 from public.pastoral_publications p
      where p.id = publication_id
        and public.has_church_role(p.church_id, array['pastor', 'church_admin', 'leader']::text[])
    )
  );

drop policy if exists "Members can read active publication comments" on public.pastoral_publication_comments;
create policy "Members can read active publication comments"
  on public.pastoral_publication_comments
  for select
  to authenticated
  using (
    status = 'active'
    and public.can_view_pastoral_publication(publication_id, auth.uid())
  );

drop policy if exists "Users can update own fresh comments" on public.pastoral_publication_comments;
create policy "Users can update own fresh comments"
  on public.pastoral_publication_comments
  for update
  to authenticated
  using (
    profile_id = auth.uid()
    and status = 'active'
    and created_at > now() - interval '30 minutes'
  )
  with check (profile_id = auth.uid());

drop policy if exists "Church admins can moderate comments" on public.pastoral_publication_comments;
create policy "Church admins can moderate comments"
  on public.pastoral_publication_comments
  for update
  to authenticated
  using (exists (
    select 1 from public.pastoral_publications p
    where p.id = publication_id
      and public.has_church_role(p.church_id, array['pastor', 'church_admin', 'leader']::text[])
  ))
  with check (exists (
    select 1 from public.pastoral_publications p
    where p.id = publication_id
      and public.has_church_role(p.church_id, array['pastor', 'church_admin', 'leader']::text[])
  ));

drop policy if exists "Church admins can read publication history" on public.pastoral_publication_state_history;
create policy "Church admins can read publication history"
  on public.pastoral_publication_state_history
  for select
  to authenticated
  using (exists (
    select 1 from public.pastoral_publications p
    where p.id = publication_id
      and public.has_church_role(p.church_id, array['pastor', 'church_admin', 'leader']::text[])
  ));

drop policy if exists "Super admins can read publication audit logs" on public.pastoral_publication_audit_logs;
create policy "Super admins can read publication audit logs"
  on public.pastoral_publication_audit_logs
  for select
  to authenticated
  using (public.is_super_admin());

grant select, insert, update, delete on public.pastoral_publications to authenticated;
grant select, insert, update, delete on public.pastoral_publication_segments to authenticated;
grant select on public.pastoral_publication_reads to authenticated;
grant select on public.pastoral_publication_saved to authenticated;
grant select on public.pastoral_publication_reactions to authenticated;
grant select, update on public.pastoral_publication_comments to authenticated;
grant select on public.pastoral_publication_state_history to authenticated;
grant select on public.pastoral_publication_audit_logs to authenticated;

grant execute on function public.can_view_pastoral_publication(uuid, uuid) to authenticated;
grant execute on function public.record_pastoral_publication_read(uuid, integer) to authenticated;
grant execute on function public.toggle_pastoral_publication_saved(uuid, boolean) to authenticated;
grant execute on function public.react_to_pastoral_publication(uuid, text) to authenticated;
grant execute on function public.comment_on_pastoral_publication(uuid, text, uuid) to authenticated;
grant execute on function public.publish_scheduled_pastoral_publications() to authenticated;
grant execute on function public.get_manageable_pastoral_publications(uuid) to authenticated;
