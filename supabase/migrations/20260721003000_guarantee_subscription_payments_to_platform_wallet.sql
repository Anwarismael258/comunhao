create or replace function public.record_subscription_payment_to_platform(
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  request_row public.church_subscription_requests%rowtype;
  platform_wallet_id uuid;
  revenue_entry_id uuid;
  church_name text;
  effective_amount numeric(12,2);
  effective_provider text;
begin
  if not public.is_super_admin(auth.uid()) and coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'Only super admins can record subscription payments.';
  end if;

  select *
  into request_row
  from public.church_subscription_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Subscription request not found.';
  end if;

  if request_row.status <> 'approved' then
    raise exception 'Only approved subscription payments can be recorded.';
  end if;

  effective_amount := coalesce(
    request_row.expected_amount_mzn,
    (
      select price_mzn
      from public.subscription_plans
      where code = request_row.requested_plan_code
      limit 1
    ),
    0
  );

  if effective_amount <= 0 then
    return null;
  end if;

  effective_provider := coalesce(nullif(trim(request_row.payment_provider), ''), 'mpesa');

  perform public.ensure_wallet_accounts('platform', null, 'Comunhao');

  select id
  into platform_wallet_id
  from public.wallet_accounts
  where owner_type = 'platform'
    and church_id is null
    and provider = effective_provider
  limit 1;

  if platform_wallet_id is null then
    raise exception 'Platform wallet account not found for provider: %', effective_provider;
  end if;

  select name
  into church_name
  from public.churches
  where id = request_row.church_id
  limit 1;

  revenue_entry_id := request_row.recorded_revenue_entry_id;

  if revenue_entry_id is null then
    select id
    into revenue_entry_id
    from public.wallet_ledger_entries
    where reference_table = 'church_subscription_requests'
      and reference_id = request_row.id
      and entry_type = 'subscription_payment'
    limit 1;
  end if;

  if revenue_entry_id is null then
    insert into public.wallet_ledger_entries (
      wallet_account_id,
      created_by,
      direction,
      entry_type,
      amount,
      currency,
      status,
      description,
      reference_table,
      reference_id,
      metadata,
      posted_at
    )
    values (
      platform_wallet_id,
      coalesce(auth.uid(), request_row.reviewed_by, request_row.requested_by),
      'credit',
      'subscription_payment',
      effective_amount,
      'MZN',
      'posted',
      format(
        'Pagamento do plano %s - %s',
        request_row.requested_plan_code,
        coalesce(church_name, 'Igreja')
      ),
      'church_subscription_requests',
      request_row.id,
      jsonb_build_object(
        'church_id', request_row.church_id,
        'church_name', church_name,
        'plan_code', request_row.requested_plan_code,
        'payment_provider', effective_provider,
        'payment_reference', request_row.payment_reference,
        'payer_phone', request_row.payer_phone,
        'requested_by', request_row.requested_by,
        'reviewed_by', request_row.reviewed_by,
        'source', 'subscription_payment_confirmation'
      ),
      now()
    )
    returning id into revenue_entry_id;
  end if;

  update public.church_subscription_requests
  set recorded_revenue_entry_id = revenue_entry_id
  where id = request_row.id;

  perform public.create_platform_audit_log(
    'wallet.subscription_payment.recorded',
    'subscription_request',
    request_row.id,
    request_row.church_id,
    'Pagamento de subscricao registado na carteira da plataforma.',
    jsonb_build_object(
      'request_id', request_row.id,
      'church_id', request_row.church_id,
      'church_name', church_name,
      'amount', effective_amount,
      'provider', effective_provider,
      'ledger_entry_id', revenue_entry_id
    )
  );

  return revenue_entry_id;
end;
$$;

create or replace function public.review_subscription_request(
  p_request_id uuid,
  p_decision text,
  p_period_days integer default 30,
  p_review_notes text default null
)
returns public.church_subscriptions
language plpgsql
security definer
set search_path = public
as $$
declare
  request_row public.church_subscription_requests%rowtype;
  result public.church_subscriptions;
begin
  if not public.is_super_admin(auth.uid()) then
    raise exception 'Only super admins can review subscription requests.';
  end if;

  if p_decision not in ('approved', 'rejected') then
    raise exception 'Invalid subscription review decision: %', p_decision;
  end if;

  select *
  into request_row
  from public.church_subscription_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Subscription request not found.';
  end if;

  if request_row.status <> 'pending' then
    raise exception 'Only pending subscription requests can be reviewed.';
  end if;

  update public.church_subscription_requests
  set
    status = case when p_decision = 'approved' then 'approved' else 'rejected' end,
    reviewed_at = now(),
    reviewed_by = auth.uid(),
    review_notes = p_review_notes
  where id = p_request_id;

  if p_decision = 'rejected' then
    return null;
  end if;

  result := public.admin_update_church_subscription(
    request_row.church_id,
    'active',
    request_row.requested_plan_code,
    p_period_days,
    7,
    coalesce(
      p_review_notes,
      'Subscricao ativada apos confirmacao de pagamento.'
    )
  );

  perform public.record_subscription_payment_to_platform(p_request_id);

  return result;
end;
$$;

do $$
declare
  approved_request record;
begin
  for approved_request in
    select id
    from public.church_subscription_requests
    where status = 'approved'
      and expected_amount_mzn > 0
      and recorded_revenue_entry_id is null
  loop
    perform public.record_subscription_payment_to_platform(approved_request.id);
  end loop;
end;
$$;

grant execute on function public.record_subscription_payment_to_platform(uuid)
  to authenticated;
grant execute on function public.review_subscription_request(uuid, text, integer, text)
  to authenticated;
