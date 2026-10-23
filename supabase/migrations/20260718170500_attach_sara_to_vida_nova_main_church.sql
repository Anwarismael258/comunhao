do $$
declare
  sara_id uuid;
  church_record record;
begin
  sara_id := public.profile_id_by_phone('877688695');

  if sara_id is null then
    select p.id
      into sara_id
    from public.profiles p
    where public.normalize_phone_auth_number(p.phone) = '258877688695'
    limit 1;
  end if;

  if sara_id is null then
    return;
  end if;

  for church_record in
    select c.id
    from public.churches c
    where lower(trim(c.name)) in ('igreja vida nova', 'vida nova')
       or lower(trim(c.slug)) in ('vida-nova', 'igreja-vida-nova')
       or upper(trim(coalesce(c.join_code, ''))) = 'VIDA123'
  loop
    update public.churches
       set active = true,
           updated_at = now()
     where id = church_record.id;

    insert into public.memberships (church_id, profile_id, role, status)
    values (church_record.id, sara_id, 'pastor', 'active')
    on conflict (church_id, profile_id) do update
      set role = 'pastor',
          status = 'active';

    insert into public.church_settings (church_id, owner_profile_id)
    values (church_record.id, sara_id)
    on conflict (church_id) do update
      set owner_profile_id = sara_id;

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
      church_record.id,
      'premium',
      'trial',
      now(),
      now() + interval '90 days',
      now(),
      now() + interval '90 days',
      now(),
      'Trial Vida Nova sede reativado para QA operacional.'
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
          admin_notes = 'Trial Vida Nova sede reativado para QA operacional.';
  end loop;
end $$;
