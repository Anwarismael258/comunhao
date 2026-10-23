create or replace function public.submit_subscription_plan_request(
  p_church_id uuid,
  p_plan_code text,
  p_payment_provider text default null,
  p_payer_phone text default null,
  p_payment_reference text default null,
  p_payment_notes text default null
)
returns public.church_subscription_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.church_subscription_requests;
  selected_plan public.subscription_plans%rowtype;
  normalized_reference text := nullif(trim(coalesce(p_payment_reference, '')), '');
  normalized_provider text := nullif(trim(coalesce(p_payment_provider, '')), '');
begin
  if not public.has_church_role(
    p_church_id,
    array['pastor', 'church_admin']::text[]
  ) then
    raise exception 'Only church admins can request a plan for this church.';
  end if;

  select *
  into selected_plan
  from public.subscription_plans
  where code = p_plan_code
    and is_public = true;

  if not found then
    raise exception 'Unknown subscription plan: %', p_plan_code;
  end if;

  if selected_plan.price_mzn > 0 and normalized_provider is null then
    raise exception 'Selecione M-Pesa ou E-Mola para confirmar o pagamento.';
  end if;

  if normalized_provider is not null
    and normalized_provider not in ('mpesa', 'emola') then
    raise exception 'Invalid payment provider: %', normalized_provider;
  end if;

  update public.church_subscription_requests
  set
    status = 'cancelled',
    reviewed_at = now(),
    reviewed_by = auth.uid(),
    review_notes = 'Substituido por um pedido mais recente.'
  where church_id = p_church_id
    and status = 'pending';

  insert into public.church_subscription_requests (
    church_id,
    requested_plan_code,
    requested_by,
    status,
    payment_provider,
    payer_phone,
    payment_reference,
    payment_notes,
    expected_amount_mzn,
    payment_submitted_at
  )
  values (
    p_church_id,
    p_plan_code,
    auth.uid(),
    'pending',
    normalized_provider,
    nullif(trim(coalesce(p_payer_phone, '')), ''),
    normalized_reference,
    nullif(trim(coalesce(p_payment_notes, '')), ''),
    selected_plan.price_mzn,
    case
      when normalized_provider is null then null
      else now()
    end
  )
  returning *
  into result;

  return result;
end;
$$;

grant execute on function public.submit_subscription_plan_request(uuid, text, text, text, text, text) to authenticated;

create or replace function public.delete_own_church(
  p_church_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  church_row public.churches%rowtype;
  notified_count integer := 0;
begin
  if not public.has_church_role(
    p_church_id,
    array['pastor', 'church_admin']::text[]
  ) then
    raise exception 'Sem permissao para apagar esta igreja.';
  end if;

  select *
    into church_row
  from public.churches
  where id = p_church_id;

  if church_row.id is null then
    raise exception 'Igreja nao encontrada.';
  end if;

  insert into public.internal_notifications (
    recipient_profile_id,
    church_id,
    actor_profile_id,
    title,
    message,
    notification_type,
    priority,
    reference_table,
    reference_id,
    action_route,
    metadata
  )
  select
    membership.profile_id,
    null,
    auth.uid(),
    'Igreja removida',
    'A igreja "' || church_row.name || '" foi removida do Comunhao. O teu acesso a esta igreja foi encerrado.',
    'church_deleted',
    'high',
    null,
    null,
    'church_deleted',
    jsonb_build_object(
      'church_id', church_row.id,
      'church_name', church_row.name,
      'deleted_at', now()
    )
  from public.memberships membership
  where membership.church_id = p_church_id
    and membership.status = 'active';

  get diagnostics notified_count = row_count;

  delete from public.churches
  where id = p_church_id;

  return jsonb_build_object(
    'church_id', p_church_id,
    'church_name', church_row.name,
    'notified_members', notified_count,
    'deleted', true
  );
end;
$$;

grant execute on function public.delete_own_church(uuid) to authenticated;

do $$
declare
  vida_nova_id uuid;
  wallet_id uuid;
  current_balance numeric;
  adjustment numeric;
begin
  select id
    into vida_nova_id
  from public.churches
  where slug = 'vida-nova'
     or lower(name) like '%vida nova%'
  order by created_at nulls last
  limit 1;

  if vida_nova_id is null then
    return;
  end if;

  perform public.ensure_wallet_accounts('church', vida_nova_id, 'Igreja Vida Nova');

  select id
    into wallet_id
  from public.wallet_accounts
  where owner_type = 'church'
    and church_id = vida_nova_id
    and provider = 'mpesa'
  limit 1;

  if wallet_id is null then
    return;
  end if;

  current_balance := public.wallet_account_balance(wallet_id);
  adjustment := 1000.00 - coalesce(current_balance, 0);

  if adjustment <> 0 then
    insert into public.wallet_ledger_entries (
      wallet_account_id,
      church_id,
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
      posted_at,
      created_at
    )
    values (
      wallet_id,
      vida_nova_id,
      null,
      case when adjustment > 0 then 'credit' else 'debit' end,
      'adjustment',
      abs(adjustment),
      'MZN',
      'posted',
      'Ajuste de saldo de teste da carteira da igreja para 1000 MZN.',
      'wallet_accounts',
      wallet_id,
      jsonb_build_object(
        'seed_key', 'vida-nova-church-wallet-1000',
        'target_available_balance', 1000.00,
        'previous_balance', current_balance
      ),
      now(),
      now()
    );
  end if;
end $$;
