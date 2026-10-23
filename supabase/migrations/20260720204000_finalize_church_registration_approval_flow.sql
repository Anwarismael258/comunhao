create or replace function public.review_church_application(
  p_application_id uuid,
  p_decision text,
  p_review_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  application_row public.church_applications%rowtype;
  new_church_id uuid;
  new_slug text;
  new_join_code text;
begin
  if not public.is_super_admin(auth.uid()) then
    raise exception 'Only super admins can review church applications.';
  end if;

  if p_decision not in ('approved', 'changes_requested', 'rejected') then
    raise exception 'Invalid review decision: %', p_decision;
  end if;

  select *
  into application_row
  from public.church_applications
  where id = p_application_id
  for update;

  if not found then
    raise exception 'Church application not found.';
  end if;

  if application_row.status <> 'submitted' then
    raise exception 'Only submitted applications can be reviewed. Current status: %', application_row.status;
  end if;

  if p_decision = 'approved' then
    new_slug := public.generate_unique_church_slug(application_row.church_name);
    new_join_code := public.generate_unique_join_code(application_row.church_name);

    insert into public.churches (
      name,
      slug,
      join_code,
      app_name,
      tagline,
      hero_title,
      hero_subtitle,
      logo_url,
      primary_color,
      secondary_color,
      phone,
      email,
      city,
      country,
      active,
      subscription_status
    )
    values (
      application_row.church_name,
      new_slug,
      new_join_code,
      application_row.church_name,
      coalesce(application_row.tagline, 'Powered by Comunhao'),
      application_row.church_name,
      'Comunidade ativa, organizada e ligada em um so lugar.',
      application_row.logo_url,
      application_row.primary_color,
      application_row.secondary_color,
      application_row.phone,
      application_row.email,
      application_row.city,
      application_row.country,
      true,
      'trial'
    )
    returning id
    into new_church_id;

    insert into public.church_settings (
      church_id,
      source_application_id,
      owner_profile_id,
      member_join_mode,
      join_link,
      require_member_approval
    )
    values (
      new_church_id,
      application_row.id,
      application_row.pastor_profile_id,
      'open',
      'https://comunhao.app/join/' || new_join_code,
      false
    )
    on conflict (church_id) do update
      set
        source_application_id = excluded.source_application_id,
        owner_profile_id = excluded.owner_profile_id,
        join_link = excluded.join_link,
        require_member_approval = excluded.require_member_approval;

    if nullif(trim(coalesce(application_row.mpesa, '')), '') is not null then
      insert into public.church_payment_settings (
        church_id,
        provider,
        account_name,
        account_number,
        instructions,
        is_primary
      )
      values (
        new_church_id,
        'mpesa',
        application_row.church_name,
        application_row.mpesa,
        'Recebe dizimos e ofertas por M-Pesa.',
        true
      )
      on conflict (church_id, provider) do update
        set
          account_name = excluded.account_name,
          account_number = excluded.account_number,
          instructions = excluded.instructions,
          is_primary = excluded.is_primary;
    end if;

    if nullif(trim(coalesce(application_row.emola, '')), '') is not null then
      insert into public.church_payment_settings (
        church_id,
        provider,
        account_name,
        account_number,
        instructions,
        is_primary
      )
      values (
        new_church_id,
        'emola',
        application_row.church_name,
        application_row.emola,
        'Recebe dizimos e ofertas por e-Mola.',
        false
      )
      on conflict (church_id, provider) do update
        set
          account_name = excluded.account_name,
          account_number = excluded.account_number,
          instructions = excluded.instructions,
          is_primary = excluded.is_primary;
    end if;

    insert into public.memberships (
      church_id,
      profile_id,
      role,
      status
    )
    values (
      new_church_id,
      application_row.pastor_profile_id,
      'pastor',
      'active'
    )
    on conflict (church_id, profile_id) do update
      set
        role = excluded.role,
        status = 'active';

    perform public.provision_church_trial_subscription(new_church_id, 30);
    perform public.sync_church_subscription_state(new_church_id);
    perform public.ensure_wallet_accounts(
      'church',
      new_church_id,
      application_row.church_name
    );

    update public.church_applications
    set
      status = 'approved',
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      review_notes = p_review_notes,
      approved_church_id = new_church_id,
      updated_at = now()
    where id = p_application_id;

    perform public.create_internal_notification(
      application_row.pastor_profile_id,
      'Igreja aprovada',
      'A sua igreja foi aprovada. O trial Plus de 30 dias ja esta ativo.',
      'church_approved',
      new_church_id,
      auth.uid(),
      'high',
      'churches',
      new_church_id,
      '/dashboard',
      jsonb_build_object(
        'church_id', new_church_id,
        'church_name', application_row.church_name,
        'trial_days', 30
      )
    );

    return new_church_id;
  end if;

  update public.church_applications
  set
    status = p_decision,
    reviewed_at = now(),
    reviewed_by = auth.uid(),
    review_notes = p_review_notes,
    updated_at = now()
  where id = p_application_id;

  perform public.create_internal_notification(
    application_row.pastor_profile_id,
    case
      when p_decision = 'changes_requested' then 'Correcoes solicitadas'
      else 'Pedido da igreja rejeitado'
    end,
    case
      when p_decision = 'changes_requested'
        then 'A equipa Comunhao pediu correcoes no perfil da igreja. Abre o pedido para ajustar e reenviar.'
      else 'O pedido da igreja foi rejeitado. Abre o pedido para ver a observacao da equipa Comunhao.'
    end,
    case
      when p_decision = 'changes_requested'
        then 'church_corrections_requested'
      else 'church_rejected'
    end,
    null,
    auth.uid(),
    case when p_decision = 'changes_requested' then 'high' else 'normal' end,
    'church_applications',
    p_application_id,
    '/application-status',
    jsonb_build_object(
      'application_id', p_application_id,
      'decision', p_decision,
      'notes', p_review_notes
    )
  );

  return null;
end;
$$;

grant execute on function public.review_church_application(uuid, text, text)
  to authenticated;
