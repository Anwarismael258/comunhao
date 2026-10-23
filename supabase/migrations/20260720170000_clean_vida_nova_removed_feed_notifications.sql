do $$
declare
  vida_nova_id uuid;
begin
  select id
    into vida_nova_id
  from public.churches
  where slug = 'vida-nova'
     or lower(name) like '%vida nova%'
  order by created_at nulls last
  limit 1;

  if vida_nova_id is null then
    return;
  end if;

  delete from public.internal_notifications notification
  where
    (
      notification.reference_table = 'community_posts'
      and not exists (
        select 1
        from public.community_posts post
        where post.id = notification.reference_id
      )
    )
    or (
      notification.reference_table in (
        'announcements',
        'church_announcements'
      )
      and (
        not exists (
          select 1
          from public.announcements announcement
          where announcement.id = notification.reference_id
        )
        or exists (
          select 1
          from public.announcements announcement
          where announcement.id = notification.reference_id
            and announcement.church_id = vida_nova_id
            and announcement.published_at is null
        )
      )
    )
    or (
      notification.reference_table in ('events', 'church_events')
      and (
        not exists (
          select 1
          from public.events event
          where event.id = notification.reference_id
        )
        or exists (
          select 1
          from public.events event
          where event.id = notification.reference_id
            and event.church_id = vida_nova_id
            and (
              coalesce(event.is_demo, false)
              or lower(coalesce(event.status, '')) in ('archived', 'cancelled', 'draft')
            )
        )
      )
    )
    or (
      notification.reference_table in (
        'donation_campaigns',
        'campaigns',
        'church_campaigns'
      )
      and (
        not exists (
          select 1
          from public.donation_campaigns campaign
          where campaign.id = notification.reference_id
        )
        or exists (
          select 1
          from public.donation_campaigns campaign
          where campaign.id = notification.reference_id
            and campaign.church_id = vida_nova_id
            and (
              coalesce(campaign.is_demo, false)
              or coalesce(campaign.active, false) = false
              or lower(coalesce(campaign.campaign_status, '')) in ('closed', 'archived', 'cancelled', 'draft')
            )
        )
      )
    )
    or (
      notification.reference_table = 'pastoral_publications'
      and (
        not exists (
          select 1
          from public.pastoral_publications publication
          where publication.id = notification.reference_id
        )
        or exists (
          select 1
          from public.pastoral_publications publication
          where publication.id = notification.reference_id
            and publication.church_id = vida_nova_id
            and (
              coalesce((publication.metadata ->> 'is_demo')::boolean, false)
              or coalesce((publication.metadata ->> 'qa')::boolean, false)
              or lower(coalesce(publication.status, '')) in ('archived', 'draft', 'cancelled')
            )
        )
      )
    );
end $$;
