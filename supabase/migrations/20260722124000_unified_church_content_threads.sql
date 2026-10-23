alter table public.announcements
  add column if not exists pastoral_publication_id uuid
    references public.pastoral_publications(id) on delete set null;

alter table public.events
  add column if not exists pastoral_publication_id uuid
    references public.pastoral_publications(id) on delete set null;

alter table public.events
  add column if not exists status text not null default 'published';

alter table public.donation_campaigns
  add column if not exists pastoral_publication_id uuid
    references public.pastoral_publications(id) on delete set null;

alter table public.pastoral_publications
  add column if not exists source_table text,
  add column if not exists source_id uuid;

create unique index if not exists pastoral_publications_source_unique
  on public.pastoral_publications(source_table, source_id)
  where source_table is not null and source_id is not null;

create or replace function public.sync_church_content_publication()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  publication_id uuid;
  publication_type text;
  publication_title text;
  publication_summary text;
  publication_content text;
  publication_image text;
  publication_status text;
  publication_priority text := 'normal';
  actor_id uuid;
  existing_publication_id uuid;
begin
  if TG_TABLE_NAME = 'announcements' then
    publication_type := case when coalesce(new.pinned, false) then 'urgent_notice' else 'announcement' end;
    publication_title := new.title;
    publication_summary := left(coalesce(new.body, ''), 220);
    publication_content := coalesce(new.body, '');
    publication_image := new.image_url;
    publication_status := case when new.published_at is null then 'draft' else 'published' end;
    actor_id := coalesce(new.created_by, auth.uid());
  elsif TG_TABLE_NAME = 'events' then
    publication_type := 'announcement';
    publication_title := new.title;
    publication_summary := concat_ws(' - ', new.event_type, new.location);
    publication_content := concat_ws(E'\n', coalesce(new.description, ''), 'Marcado para ' || new.starts_at::text);
    publication_image := new.cover_image_url;
    publication_status := case
      when coalesce(new.status, 'draft') in (
        'published',
        'confirmed',
        'scheduled',
        'ongoing',
        'completed'
      ) then 'published'
      else 'draft'
    end;
    actor_id := coalesce(new.created_by, auth.uid());
  elsif TG_TABLE_NAME = 'donation_campaigns' then
    publication_type := 'announcement';
    publication_title := new.title;
    publication_summary := left(coalesce(new.description, ''), 220);
    publication_content := coalesce(new.description, '');
    publication_image := new.image_url;
    publication_status := case when coalesce(new.active, false) then 'published' else 'draft' end;
    actor_id := coalesce(new.created_by, auth.uid());
  else
    return new;
  end if;

  if publication_status = 'published' then
    select publication.id
      into existing_publication_id
    from public.pastoral_publications publication
    where publication.source_table = TG_TABLE_NAME
      and publication.source_id = new.id
    limit 1;

    publication_id := coalesce(
      new.pastoral_publication_id,
      existing_publication_id,
      gen_random_uuid()
    );

    insert into public.pastoral_publications (
      id,
      church_id,
      author_user_id,
      title,
      slug,
      summary,
      content,
      publication_type,
      category,
      cover_image_url,
      status,
      visibility,
      priority,
      published_at,
      allow_comments,
      allow_reactions,
      allow_sharing,
      send_notification,
      is_featured,
      is_pinned,
      source_table,
      source_id
    )
    values (
      publication_id,
      new.church_id,
      actor_id,
      publication_title,
      left(
        lower(regexp_replace(coalesce(publication_title, 'publicacao'), '[^a-zA-Z0-9]+', '-', 'g')),
        72
      ) || '-' || left(new.id::text, 8),
      publication_summary,
      publication_content,
      publication_type,
      'geral',
      publication_image,
      publication_status,
      'all',
      publication_priority,
      now(),
      true,
      true,
      true,
      false,
      false,
      false,
      TG_TABLE_NAME,
      new.id
    )
    on conflict (id) do update set
      title = excluded.title,
      slug = excluded.slug,
      summary = excluded.summary,
      content = excluded.content,
      publication_type = excluded.publication_type,
      category = excluded.category,
      cover_image_url = excluded.cover_image_url,
      status = excluded.status,
      source_table = excluded.source_table,
      source_id = excluded.source_id,
      updated_at = now();
    new.pastoral_publication_id := publication_id;
  end if;

  return new;
end;
$$;

drop trigger if exists sync_announcement_publication on public.announcements;
create trigger sync_announcement_publication
before insert or update on public.announcements
for each row execute function public.sync_church_content_publication();

drop trigger if exists sync_event_publication on public.events;
create trigger sync_event_publication
before insert or update on public.events
for each row execute function public.sync_church_content_publication();

drop trigger if exists sync_campaign_publication on public.donation_campaigns;
create trigger sync_campaign_publication
before insert or update on public.donation_campaigns
for each row execute function public.sync_church_content_publication();

update public.announcements set title = title
where published_at is not null and pastoral_publication_id is null;

update public.events set title = title
where status in ('published', 'confirmed', 'scheduled', 'ongoing', 'completed')
  and pastoral_publication_id is null;

update public.donation_campaigns set title = title
where active = true and pastoral_publication_id is null;

drop function if exists public.get_active_campaigns_with_progress(uuid);

create or replace function public.get_active_campaigns_with_progress(
  p_church_id uuid
)
returns table (
  id uuid,
  title text,
  description text,
  image_url text,
  pastoral_publication_id uuid,
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
    campaign.pastoral_publication_id,
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
