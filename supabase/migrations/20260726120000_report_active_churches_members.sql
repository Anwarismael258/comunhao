do $$
declare
  active_count integer;
  church_record record;
begin
  select count(*)
    into active_count
  from public.churches
  where active = true;

  raise notice 'ACTIVE_CHURCH_COUNT=%', active_count;

  for church_record in
    select
      c.id,
      c.name,
      c.slug,
      c.join_code,
      c.city,
      count(m.id) filter (where m.status = 'active') as active_membership_count,
      count(m.id) filter (
        where m.status = 'active'
          and m.role = 'pastor'
      ) as pastor_count,
      count(m.id) filter (
        where m.status = 'active'
          and m.role <> 'pastor'
      ) as member_count,
      coalesce(
        string_agg(
          distinct concat(
            coalesce(nullif(trim(p.full_name), ''), 'Sem nome'),
            ' (',
            coalesce(nullif(trim(p.phone), ''), 'sem telefone'),
            ')'
          ),
          '; '
        ) filter (
          where m.status = 'active'
            and m.role = 'pastor'
        ),
        'Sem pastor ativo'
      ) as pastors,
      coalesce(
        string_agg(
          distinct concat(
            coalesce(nullif(trim(p.full_name), ''), 'Sem nome'),
            ' - ',
            m.role,
            ' (',
            coalesce(nullif(trim(p.phone), ''), 'sem telefone'),
            ')'
          ),
          '; '
        ) filter (
          where m.status = 'active'
            and m.role <> 'pastor'
        ),
        'Sem membros ativos'
      ) as members
    from public.churches c
    left join public.memberships m
      on m.church_id = c.id
    left join public.profiles p
      on p.id = m.profile_id
    where c.active = true
    group by c.id, c.name, c.slug, c.join_code, c.city, c.created_at
    order by c.created_at desc nulls last, c.name
  loop
    raise notice 'CHURCH|name=%|slug=%|code=%|city=%|active_memberships=%|pastors=%|members=%|pastor_list=%|member_list=%',
      church_record.name,
      church_record.slug,
      coalesce(church_record.join_code, ''),
      coalesce(church_record.city, ''),
      church_record.active_membership_count,
      church_record.pastor_count,
      church_record.member_count,
      church_record.pastors,
      church_record.members;
  end loop;
end $$;
