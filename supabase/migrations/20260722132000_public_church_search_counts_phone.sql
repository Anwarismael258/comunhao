create or replace function public.list_public_churches_with_member_counts(
  p_query text default null,
  p_limit integer default 50
)
returns table (
  id uuid,
  name text,
  slug text,
  join_code text,
  app_name text,
  logo_url text,
  primary_color text,
  secondary_color text,
  phone text,
  email text,
  city text,
  country text,
  tagline text,
  hero_title text,
  hero_subtitle text,
  default_currency text,
  subscription_status text,
  trial_ends_at timestamptz,
  subscription_ends_at timestamptz,
  active_member_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with search_input as (
    select
      nullif(trim(coalesce(p_query, '')), '') as text_query,
      nullif(regexp_replace(coalesce(p_query, ''), '\D', '', 'g'), '') as digit_query
  )
  select
    c.id,
    c.name,
    c.slug,
    c.join_code,
    c.app_name,
    c.logo_url,
    c.primary_color,
    c.secondary_color,
    c.phone,
    c.email,
    c.city,
    c.country,
    c.tagline,
    c.hero_title,
    c.hero_subtitle,
    c.default_currency,
    c.subscription_status,
    c.trial_ends_at,
    c.subscription_ends_at,
    count(m.id) filter (where m.status = 'active') as active_member_count
  from public.churches c
  cross join search_input s
  left join public.memberships m on m.church_id = c.id
  where c.active = true
    and (
      s.text_query is null
      or c.name ilike '%' || s.text_query || '%'
      or c.slug ilike '%' || s.text_query || '%'
      or c.join_code ilike '%' || s.text_query || '%'
      or c.phone ilike '%' || s.text_query || '%'
      or (
        s.digit_query is not null
        and regexp_replace(coalesce(c.phone, ''), '\D', '', 'g')
          ilike '%' || s.digit_query || '%'
      )
    )
  group by c.id
  order by c.name
  limit greatest(1, least(coalesce(p_limit, 50), 100));
$$;

grant execute on function public.list_public_churches_with_member_counts(text, integer)
  to anon, authenticated;
