with ranked_memberships as (
  select
    id,
    row_number() over (
      partition by church_id, profile_id
      order by
        case status
          when 'active' then 0
          when 'blocked' then 1
          when 'transferred' then 2
          else 3
        end,
        case role
          when 'pastor' then 0
          when 'church_admin' then 1
          when 'leader' then 2
          else 3
        end,
        created_at desc nulls last,
        id
    ) as duplicate_rank
  from public.memberships
  where church_id is not null
    and profile_id is not null
)
delete from public.memberships membership
using ranked_memberships ranked
where membership.id = ranked.id
  and ranked.duplicate_rank > 1;

create unique index if not exists idx_memberships_church_profile_unique
  on public.memberships (church_id, profile_id);
