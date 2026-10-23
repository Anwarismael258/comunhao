do $$
declare
  vida_id uuid;
begin
  select c.id
  into vida_id
  from public.churches c
  where (
      lower(trim(c.slug)) = 'vida-nova'
      or upper(trim(coalesce(c.join_code, ''))) = 'VIDA123'
      or lower(trim(c.name)) = 'igreja vida nova'
      or regexp_replace(coalesce(c.phone, ''), '\D', '', 'g') in ('877688695', '258877688695')
    )
    and coalesce(c.is_demo, false) = false
  order by
    case when lower(trim(c.slug)) = 'vida-nova' then 0 else 1 end,
    c.created_at nulls last
  limit 1;

  if vida_id is null then
    return;
  end if;

  delete from public.announcements
  where church_id = vida_id
    and title ilike 'QA Feed - %';

  delete from public.events
  where church_id = vida_id
    and (
      title ilike 'QA Feed - %'
      or coalesce(metadata->>'qa', 'false') = 'true'
      or coalesce(is_demo, false) = true
    );

  delete from public.pastoral_publications
  where church_id = vida_id
    and (
      title ilike 'QA Feed - %'
      or coalesce(metadata->>'qa', 'false') = 'true'
      or coalesce(is_demo, false) = true
    );

  update public.donation_campaigns
  set
    active = false,
    campaign_status = 'closed',
    is_demo = true
  where church_id = vida_id
    and (
      title ilike 'QA Feed - %'
      or title in ('Som')
      or coalesce(is_demo, false) = true
    );
end $$;
