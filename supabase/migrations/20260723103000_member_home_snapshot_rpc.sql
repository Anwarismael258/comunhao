create or replace function public.get_member_home_snapshot(
  p_church_id uuid,
  p_limit integer default 24
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  with allowed as (
    select exists (
      select 1
      from public.memberships m
      where m.church_id = p_church_id
        and m.profile_id = auth.uid()
        and m.status = 'active'
    ) or public.is_super_admin(auth.uid()) as ok
  ),
  limited as (
    select greatest(1, least(coalesce(p_limit, 24), 40)) as value
  )
  select jsonb_build_object(
    'announcements', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.pinned desc, x.created_at desc)
      from (
        select id, title, body, image_url, pastoral_publication_id, pinned,
               published_at, created_at
        from public.announcements, allowed, limited
        where allowed.ok
          and church_id = p_church_id
          and published_at is not null
        order by pinned desc, created_at desc
        limit (select value from limited)
      ) x
    ), '[]'::jsonb),
    'events', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at desc)
      from (
        select id, title, event_type, description, location, cover_image_url,
               pastoral_publication_id, starts_at, ends_at,
               registration_required, capacity, registration_fee_mzn,
               created_at
        from public.events, allowed, limited
        where allowed.ok
          and church_id = p_church_id
          and coalesce(status, event_status, 'published') = 'published'
          and coalesce(is_demo, false) = false
          and starts_at >= now() - interval '12 hours'
        order by created_at desc
        limit (select value from limited)
      ) x
    ), '[]'::jsonb),
    'campaigns', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at desc)
      from (
        select c.id, c.title, c.description, c.image_url,
               c.pastoral_publication_id, c.target_amount, c.start_at,
               c.end_at, c.active, c.created_at,
               coalesce(sum(d.amount), 0) as raised_amount,
               count(distinct d.profile_id) as contributor_count
        from public.donation_campaigns c
        cross join allowed
        cross join limited
        left join public.donations d
          on d.campaign_id = c.id
         and d.status in ('confirmed', 'completed', 'paid')
        where allowed.ok
          and c.church_id = p_church_id
          and c.active = true
        group by c.id
        order by c.created_at desc
        limit (select value from limited)
      ) x
    ), '[]'::jsonb),
    'communications', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at desc)
      from (
        select cc.id, cc.church_id, cc.channel, cc.audience_type,
               cc.target_role, cc.ministry_id, cc.membership_id,
               cc.title, cc.body, cc.status, cc.scheduled_at, cc.sent_at,
               cc.created_at,
               jsonb_build_object('name', cm.name) as ministry,
               jsonb_build_object(
                 'profile',
                 jsonb_build_object('full_name', p.full_name)
               ) as membership
        from public.church_communications cc
        cross join allowed
        left join public.church_ministries cm on cm.id = cc.ministry_id
        left join public.memberships m on m.id = cc.membership_id
        left join public.profiles p on p.id = m.profile_id
        where allowed.ok
          and cc.church_id = p_church_id
          and cc.status in ('queued', 'sent')
        order by cc.created_at desc
        limit 12
      ) x
    ), '[]'::jsonb),
    'birthdays', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.next_birthday)
      from (
        select m.profile_id, p.full_name, m.role, p.birth_date,
               make_date(
                 extract(year from now())::int +
                   case
                     when make_date(extract(year from now())::int,
                                    extract(month from p.birth_date)::int,
                                    least(extract(day from p.birth_date)::int, 28))
                          < current_date
                     then 1 else 0
                   end,
                 extract(month from p.birth_date)::int,
                 least(extract(day from p.birth_date)::int, 28)
               ) as next_birthday
        from public.memberships m
        join public.profiles p on p.id = m.profile_id
        cross join allowed
        where allowed.ok
          and m.church_id = p_church_id
          and m.status = 'active'
          and p.birth_date is not null
        order by next_birthday
        limit 6
      ) x
    ), '[]'::jsonb),
    'prayer_feed', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at desc)
      from (
        select pr.id, pr.church_id, pr.title, pr.description,
               pr.is_private, pr.visibility, pr.status, pr.profile_id,
               pr.anonymous_request, pr.allow_responses, pr.created_at,
               (select count(*) from public.prayer_request_responses r
                 where r.prayer_request_id = pr.id) as responses
        from public.prayer_requests pr, allowed
        where allowed.ok
          and pr.church_id = p_church_id
          and coalesce(pr.visibility, case when pr.is_private then 'private' else 'public' end)
              in ('public', 'anonymous')
        order by pr.created_at desc
        limit 12
      ) x
    ), '[]'::jsonb),
    'publications', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at desc)
      from (
        select p.id, p.church_id, p.author_user_id,
               jsonb_build_object(
                 'full_name', author.full_name,
                 'avatar_url', author.avatar_url,
                 'avatar_storage_path', author.avatar_storage_path
               ) as author,
               p.title, p.slug, p.summary, p.content, p.publication_type,
               p.category, p.cover_image_url, p.audio_url, p.video_url,
               p.document_url, p.live_stream_url, p.external_url, p.status,
               p.visibility, p.priority, p.published_at, p.scheduled_at,
               p.expires_at, p.allow_comments, p.allow_reactions,
               p.allow_sharing, p.send_notification, p.is_featured,
               p.is_pinned, p.is_demo, p.created_at, p.updated_at,
               coalesce((select sum(r.open_count) from public.pastoral_publication_reads r
                         where r.publication_id = p.id), 0) as open_count,
               coalesce((select count(*) from public.pastoral_publication_reads r
                         where r.publication_id = p.id), 0) as read_count,
               coalesce((select count(*) from public.pastoral_publication_saved s
                         where s.publication_id = p.id), 0) as saved_count,
               coalesce((select count(*) from public.pastoral_publication_reactions re
                         where re.publication_id = p.id), 0) as reaction_count,
               coalesce((select count(*) from public.pastoral_publication_comments c
                         where c.publication_id = p.id and c.status = 'active'), 0) as comment_count,
               exists(select 1 from public.pastoral_publication_saved s
                      where s.publication_id = p.id and s.profile_id = auth.uid()) as is_saved,
               exists(select 1 from public.pastoral_publication_reads r
                      where r.publication_id = p.id and r.profile_id = auth.uid()) as is_read,
               (select re.reaction_type from public.pastoral_publication_reactions re
                where re.publication_id = p.id and re.profile_id = auth.uid()
                limit 1) as my_reaction
        from public.pastoral_publications p
        cross join allowed
        cross join limited
        left join public.profiles author on author.id = p.author_user_id
        where allowed.ok
          and p.church_id = p_church_id
          and p.status = 'published'
          and p.published_at <= now()
          and public.can_view_pastoral_publication(p.id, auth.uid())
        order by p.created_at desc
        limit (select value from limited)
      ) x
    ), '[]'::jsonb)
  );
$$;

grant execute on function public.get_member_home_snapshot(uuid, integer)
  to authenticated;

