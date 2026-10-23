do $$
declare
  vida_nova_id uuid;
begin
  select c.id
    into vida_nova_id
  from public.churches c
  where lower(c.name) like '%vida nova%'
  order by c.created_at desc nulls last
  limit 1;

  if vida_nova_id is null then
    select ca.approved_church_id
      into vida_nova_id
    from public.church_applications ca
    where regexp_replace(coalesce(ca.phone, ''), '\D', '', 'g') in
      ('877688695', '258877688695')
      and ca.approved_church_id is not null
    order by ca.reviewed_at desc nulls last, ca.submitted_at desc nulls last
    limit 1;
  end if;

  if vida_nova_id is not null then
    update public.churches
       set active = true,
           updated_at = now()
     where id = vida_nova_id;

    insert into public.church_subscriptions (
      church_id,
      plan_code,
      status,
      trial_started_at,
      trial_ends_at,
      current_period_started_at,
      current_period_ends_at,
      activated_at,
      admin_notes
    )
    values (
      vida_nova_id,
      'premium',
      'trial',
      now(),
      now() + interval '90 days',
      now(),
      now() + interval '90 days',
      now(),
      'Trial reativado para testes do piloto Vida Nova: publicacoes, anuncios, agenda e campanhas.'
    )
    on conflict (church_id) do update
      set plan_code = 'premium',
          status = 'trial',
          trial_ends_at = greatest(
            coalesce(public.church_subscriptions.trial_ends_at, now()),
            now() + interval '90 days'
          ),
          current_period_ends_at = greatest(
            coalesce(public.church_subscriptions.current_period_ends_at, now()),
            now() + interval '90 days'
          ),
          suspended_at = null,
          cancelled_at = null,
          activated_at = coalesce(public.church_subscriptions.activated_at, now()),
          updated_at = now(),
          admin_notes = 'Trial reativado para testes do piloto Vida Nova: publicacoes, anuncios, agenda e campanhas.';
  end if;
end $$;
