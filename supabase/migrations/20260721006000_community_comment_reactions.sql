create table if not exists public.community_comment_reactions (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.community_post_comments(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  reaction_type text not null default 'amen',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (comment_id, profile_id),
  constraint community_comment_reaction_type_check check (
    reaction_type in ('amen', 'praying', 'glory', 'built', 'faithful')
  )
);

create index if not exists idx_community_comment_reactions_comment_id
  on public.community_comment_reactions(comment_id);

alter table public.community_comment_reactions enable row level security;

drop policy if exists "Community comment reactions readable by church members"
  on public.community_comment_reactions;

create policy "Community comment reactions readable by church members"
  on public.community_comment_reactions
  for select
  using (
    exists (
      select 1
      from public.community_post_comments c
      join public.community_posts p on p.id = c.post_id
      join public.memberships m on m.church_id = p.church_id
      where c.id = community_comment_reactions.comment_id
        and m.profile_id = auth.uid()
        and m.status = 'active'
    )
  );

create or replace function public.react_to_community_comment(
  p_comment_id uuid,
  p_reaction_type text default 'amen'
)
returns public.community_comment_reactions
language plpgsql
security definer
set search_path = public
as $$
declare
  reaction_row public.community_comment_reactions%rowtype;
  normalized_reaction text := coalesce(nullif(trim(p_reaction_type), ''), 'amen');
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if normalized_reaction not in ('amen', 'praying', 'glory', 'built', 'faithful') then
    raise exception 'Unsupported reaction type.';
  end if;

  if not exists (
    select 1
    from public.community_post_comments c
    join public.community_posts p on p.id = c.post_id
    join public.memberships m on m.church_id = p.church_id
    where c.id = p_comment_id
      and c.status = 'visible'
      and m.profile_id = auth.uid()
      and m.status = 'active'
  ) then
    raise exception 'Comment not available for this member.';
  end if;

  insert into public.community_comment_reactions (
    comment_id,
    profile_id,
    reaction_type
  )
  values (
    p_comment_id,
    auth.uid(),
    normalized_reaction
  )
  on conflict (comment_id, profile_id) do update
  set reaction_type = excluded.reaction_type,
      updated_at = now()
  returning * into reaction_row;

  return reaction_row;
end;
$$;

grant select on public.community_comment_reactions to authenticated;
grant execute on function public.react_to_community_comment(uuid, text)
  to authenticated;
