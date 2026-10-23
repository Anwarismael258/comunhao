create table if not exists public.community_post_shares (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  share_target text not null default 'link',
  created_at timestamptz not null default now(),
  constraint community_post_share_target_check check (
    share_target in ('sheet', 'copy', 'whatsapp', 'facebook', 'x', 'tiktok', 'other', 'link')
  )
);

create index if not exists idx_community_post_shares_post_id
  on public.community_post_shares(post_id);

create index if not exists idx_community_post_shares_profile_id
  on public.community_post_shares(profile_id);

alter table public.community_post_shares enable row level security;

drop policy if exists "Community post shares readable by church members"
  on public.community_post_shares;

create policy "Community post shares readable by church members"
  on public.community_post_shares
  for select
  using (
    exists (
      select 1
      from public.community_posts p
      join public.memberships m on m.church_id = p.church_id
      where p.id = community_post_shares.post_id
        and m.profile_id = auth.uid()
        and m.status = 'active'
    )
  );

create or replace function public.record_community_post_share(
  p_post_id uuid,
  p_share_target text default 'link'
)
returns public.community_post_shares
language plpgsql
security definer
set search_path = public
as $$
declare
  share_row public.community_post_shares%rowtype;
  normalized_target text := lower(coalesce(nullif(trim(p_share_target), ''), 'link'));
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if normalized_target not in ('sheet', 'copy', 'whatsapp', 'facebook', 'x', 'tiktok', 'other', 'link') then
    normalized_target := 'link';
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
    raise exception 'Post not available for this member.';
  end if;

  insert into public.community_post_shares (
    post_id,
    profile_id,
    share_target
  )
  values (
    p_post_id,
    auth.uid(),
    normalized_target
  )
  returning * into share_row;

  return share_row;
end;
$$;

grant select on public.community_post_shares to authenticated;
grant execute on function public.record_community_post_share(uuid, text)
  to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter table public.community_post_shares replica identity full;
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'community_post_shares'
    ) then
      alter publication supabase_realtime add table public.community_post_shares;
    end if;
  end if;
end $$;
