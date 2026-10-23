create or replace function public.get_church_campaigns_with_progress(
  p_church_id uuid
)
returns table (
  id uuid,
  church_id uuid,
  title text,
  description text,
  image_url text,
  target_amount numeric,
  start_at timestamptz,
  end_at timestamptz,
  active boolean,
  campaign_status text,
  created_at timestamptz,
  raised_amount numeric,
  contributor_count integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    campaign.id,
    campaign.church_id,
    campaign.title,
    campaign.description,
    campaign.image_url,
    campaign.target_amount,
    campaign.start_at,
    campaign.end_at,
    campaign.active,
    campaign.campaign_status,
    campaign.created_at,
    coalesce(
      sum(donation.amount) filter (
        where donation.status in ('confirmed', 'recorded')
      ),
      0
    ) as raised_amount,
    count(distinct donation.profile_id) filter (
      where donation.status in ('confirmed', 'recorded')
    )::integer as contributor_count
  from public.donation_campaigns campaign
  left join public.donations donation
    on donation.campaign_id = campaign.id
  where campaign.church_id = p_church_id
    and public.has_church_role(
      campaign.church_id,
      array['pastor', 'church_admin', 'leader']::text[],
      auth.uid()
    )
  group by campaign.id
  order by campaign.active desc, campaign.created_at desc;
$$;

grant execute on function public.get_church_campaigns_with_progress(uuid) to authenticated;
