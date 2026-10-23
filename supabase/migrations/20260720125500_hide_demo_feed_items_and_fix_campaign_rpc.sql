drop function if exists public.get_active_campaigns_with_progress(uuid);

create or replace function public.get_active_campaigns_with_progress(
  p_church_id uuid
)
returns table (
  id uuid,
  title text,
  description text,
  image_url text,
  target_amount numeric,
  start_at timestamptz,
  end_at timestamptz,
  active boolean,
  created_at timestamptz,
  is_demo boolean,
  raised_amount numeric,
  contributor_count integer
)
language sql
security definer
stable
set search_path = public
as $$
  select
    campaign.id,
    campaign.title,
    campaign.description,
    campaign.image_url,
    campaign.target_amount,
    campaign.start_at,
    campaign.end_at,
    campaign.active,
    campaign.created_at,
    coalesce(campaign.is_demo, false) as is_demo,
    coalesce(
      sum(donation.amount) filter (
        where donation.status in ('confirmed', 'recorded')
          and coalesce(donation.is_demo, false) = false
      ),
      0
    ) as raised_amount,
    count(distinct donation.profile_id) filter (
      where donation.status in ('confirmed', 'recorded')
        and coalesce(donation.is_demo, false) = false
    )::integer as contributor_count
  from public.donation_campaigns campaign
  left join public.donations donation
    on donation.campaign_id = campaign.id
  where campaign.church_id = p_church_id
    and campaign.active = true
    and coalesce(campaign.is_demo, false) = false
  group by campaign.id
  order by campaign.created_at desc
  limit 20;
$$;

grant execute on function public.get_active_campaigns_with_progress(uuid) to anon, authenticated;
