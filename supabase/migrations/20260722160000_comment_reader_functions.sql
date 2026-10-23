create or replace function public.get_pastoral_publication_comments(
  p_publication_id uuid
)
returns table (
  id uuid,
  publication_id uuid,
  profile_id uuid,
  parent_comment_id uuid,
  body text,
  status text,
  created_at timestamptz,
  profile jsonb
)
language sql
security definer
set search_path = public
as $$
  select
    c.id,
    c.publication_id,
    c.profile_id,
    c.parent_comment_id,
    c.body,
    c.status,
    c.created_at,
    jsonb_build_object(
      'full_name', p.full_name,
      'avatar_url', p.avatar_url,
      'avatar_storage_path', p.avatar_storage_path
    ) as profile
  from public.pastoral_publication_comments c
  left join public.profiles p on p.id = c.profile_id
  where c.publication_id = p_publication_id
    and c.status = 'active'
    and public.can_view_pastoral_publication(c.publication_id, auth.uid())
  order by c.created_at;
$$;

grant execute on function public.get_pastoral_publication_comments(uuid)
  to authenticated;

create or replace function public.get_community_post_comments(
  p_post_id uuid
)
returns table (
  id uuid,
  post_id uuid,
  profile_id uuid,
  parent_comment_id uuid,
  body text,
  created_at timestamptz,
  profile jsonb
)
language sql
security definer
set search_path = public
as $$
  select
    c.id,
    c.post_id,
    c.profile_id,
    c.parent_comment_id,
    c.body,
    c.created_at,
    jsonb_build_object(
      'full_name', p.full_name,
      'avatar_url', p.avatar_url,
      'avatar_storage_path', p.avatar_storage_path
    ) as profile
  from public.community_post_comments c
  join public.community_posts post on post.id = c.post_id
  left join public.profiles p on p.id = c.profile_id
  where c.post_id = p_post_id
    and c.status = 'visible'
    and (
      public.is_super_admin(auth.uid())
      or exists (
        select 1
        from public.memberships m
        where m.church_id = post.church_id
          and m.profile_id = auth.uid()
          and m.status = 'active'
      )
    )
  order by c.created_at;
$$;

grant execute on function public.get_community_post_comments(uuid)
  to authenticated;
