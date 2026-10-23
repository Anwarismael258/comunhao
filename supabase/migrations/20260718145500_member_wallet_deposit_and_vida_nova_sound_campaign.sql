create or replace function public.member_wallet_provider(p_phone text)
returns text
language sql
immutable
as $$
  select case
    when regexp_replace(coalesce(p_phone, ''), '\D', '', 'g') ~ '^(258)?8(6|7)' then 'emola'
    else 'mpesa'
  end;
$$;

create or replace function public.get_member_wallet_summary()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  wallet_row public.member_wallet_accounts%rowtype;
  profile_phone text;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;

  select phone into profile_phone
  from public.profiles
  where id = auth.uid();

  perform public.ensure_member_wallet(auth.uid(), profile_phone);

  select *
  into wallet_row
  from public.member_wallet_accounts
  where profile_id = auth.uid();

  return jsonb_build_object(
    'id', wallet_row.id,
    'phone', wallet_row.phone,
    'currency', wallet_row.currency,
    'available_balance', wallet_row.available_balance,
    'pending_balance', wallet_row.pending_balance,
    'total_received', wallet_row.total_received,
    'total_contributed', wallet_row.total_contributed,
    'provider', public.member_wallet_provider(wallet_row.phone)
  );
end;
$$;

create or replace function public.deposit_member_wallet(
  p_amount numeric,
  p_provider text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  wallet_id uuid;
  profile_phone text;
  provider text;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;

  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Amount must be greater than zero.';
  end if;

  select phone into profile_phone
  from public.profiles
  where id = auth.uid();

  wallet_id := public.ensure_member_wallet(auth.uid(), profile_phone);
  provider := coalesce(nullif(trim(coalesce(p_provider, '')), ''), public.member_wallet_provider(profile_phone));

  insert into public.member_wallet_ledger_entries (
    wallet_account_id,
    profile_id,
    direction,
    entry_type,
    amount,
    currency,
    status,
    description,
    reference_table,
    posted_at
  )
  values (
    wallet_id,
    auth.uid(),
    'credit',
    'deposit',
    p_amount,
    'MZN',
    'posted',
    'Deposito na conta Comunhao via ' || upper(provider) || ' usando o numero registado.',
    'member_wallet_accounts',
    now()
  );

  update public.member_wallet_accounts
  set
    available_balance = available_balance + p_amount,
    total_received = total_received + p_amount,
    phone = coalesce(profile_phone, phone),
    updated_at = now()
  where id = wallet_id;

  return public.get_member_wallet_summary();
end;
$$;

create or replace function public.record_member_donation(
  p_church_id uuid,
  p_donation_type text,
  p_amount numeric,
  p_provider text,
  p_campaign_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  wallet_row public.member_wallet_accounts%rowtype;
  result public.donations;
  provider text;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;

  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Amount must be greater than zero.';
  end if;

  perform public.ensure_member_wallet(
    auth.uid(),
    (select phone from public.profiles where id = auth.uid())
  );

  select *
  into wallet_row
  from public.member_wallet_accounts
  where profile_id = auth.uid()
  for update;

  provider := coalesce(nullif(trim(coalesce(p_provider, '')), ''), public.member_wallet_provider(wallet_row.phone));

  if wallet_row.available_balance < p_amount then
    raise exception 'Saldo insuficiente na conta Comunhao.';
  end if;

  result := public.create_church_contribution(
    p_church_id,
    p_donation_type,
    p_amount,
    'manual_transfer',
    provider,
    p_campaign_id,
    auth.uid(),
    wallet_row.phone,
    null,
    null,
    'Criado no app do membro a partir da carteira Comunhao. Enviar para confirmacao do pastor/financeiro.',
    false,
    'member-wallet:' || auth.uid()::text || ':' || p_church_id::text || ':' || p_donation_type || ':' || extract(epoch from clock_timestamp())::text
  );

  insert into public.member_wallet_ledger_entries (
    wallet_account_id,
    profile_id,
    church_id,
    direction,
    entry_type,
    amount,
    currency,
    status,
    description,
    reference_table,
    reference_id,
    posted_at
  )
  values (
    wallet_row.id,
    auth.uid(),
    p_church_id,
    'debit',
    p_donation_type,
    p_amount,
    'MZN',
    'pending',
    'Contribuicao enviada para confirmacao da igreja.',
    'donations',
    result.id,
    now()
  );

  update public.member_wallet_accounts
  set
    available_balance = available_balance - p_amount,
    pending_balance = pending_balance + p_amount,
    total_contributed = total_contributed + p_amount,
    updated_at = now()
  where id = wallet_row.id;

  return result.id;
end;
$$;

grant execute on function public.member_wallet_provider(text) to authenticated;
grant execute on function public.get_member_wallet_summary() to authenticated;
grant execute on function public.deposit_member_wallet(numeric, text) to authenticated;

do $$
declare
  vida_id uuid;
  member_id uuid;
  sara_id uuid;
  member_wallet_id uuid;
  som_campaign_id uuid;
  tithe_id uuid;
  offering_id uuid;
  campaign_donation_id uuid;
begin
  select c.id
  into vida_id
  from public.churches c
  where c.name = 'Igreja Vida Nova'
     or c.phone in ('877688695', '+258877688695')
     or regexp_replace(coalesce(c.phone, ''), '\D', '', 'g') in ('877688695', '258877688695')
  order by c.created_at
  limit 1;

  member_id := public.profile_id_by_phone('827688695');
  sara_id := public.profile_id_by_phone('877688695');

  if vida_id is null or member_id is null then
    return;
  end if;

  delete from public.member_wallet_ledger_entries;

  update public.member_wallet_accounts
  set
    available_balance = 0,
    pending_balance = 0,
    total_received = 0,
    total_contributed = 0,
    total_withdrawn = 0,
    updated_at = now();

  member_wallet_id := public.ensure_member_wallet(member_id, '+258827688695');

  update public.member_wallet_accounts
  set
    phone = '+258827688695',
    available_balance = 1050,
    pending_balance = 950,
    total_received = 2000,
    total_contributed = 950,
    total_withdrawn = 0,
    updated_at = now()
  where id = member_wallet_id;

  insert into public.member_wallet_ledger_entries (
    wallet_account_id,
    profile_id,
    direction,
    entry_type,
    amount,
    currency,
    status,
    description,
    reference_table,
    posted_at
  )
  values (
    member_wallet_id,
    member_id,
    'credit',
    'deposit',
    2000,
    'MZN',
    'posted',
    'Saldo ficticio inicial para testes da carteira Comunhao.',
    'member_wallet_accounts',
    now() - interval '20 minutes'
  );

  delete from public.donations
  where church_id = vida_id
    and profile_id = member_id
    and metadata->>'seed_key' in (
      'vida-nova-member-tithe-500',
      'vida-nova-member-offering-300',
      'vida-nova-member-som-150'
    );

  delete from public.donation_campaigns
  where church_id = vida_id
    and title = 'Som';

  insert into public.donation_campaigns (
    church_id,
    title,
    description,
    image_url,
    target_amount,
    start_at,
    end_at,
    active,
    created_by,
    campaign_status
  )
  values (
    vida_id,
    'Som',
    'Campanha para compra e melhoria do sistema de som da Igreja Vida Nova.',
    'https://images.unsplash.com/photo-1516280440614-37939bbacd81?auto=format&fit=crop&w=1200&q=80',
    75000,
    now() - interval '1 day',
    now() + interval '45 days',
    true,
    coalesce(sara_id, member_id),
    'active'
  )
  returning id into som_campaign_id;

  insert into public.donations (
    church_id,
    profile_id,
    campaign_id,
    amount,
    currency,
    payment_method,
    provider,
    payer_phone,
    status,
    donation_type,
    contribution_type,
    metadata,
    internal_notes,
    created_at
  )
  values
    (
      vida_id,
      member_id,
      null,
      500,
      'MZN',
      'manual_transfer',
      'mpesa',
      '+258827688695',
      'pending_manual_confirmation',
      'tithe',
      'tithe',
      jsonb_build_object('seed_key', 'vida-nova-member-tithe-500', 'destination_wallet_phone', '877688695'),
      'Dizimo criado a partir da carteira do membro. Pastor/financeiro confirma na wallet 877688695.',
      now() - interval '15 minutes'
    ),
    (
      vida_id,
      member_id,
      null,
      300,
      'MZN',
      'manual_transfer',
      'mpesa',
      '+258827688695',
      'pending_manual_confirmation',
      'offering',
      'offering',
      jsonb_build_object('seed_key', 'vida-nova-member-offering-300', 'destination_wallet_phone', '877688695'),
      'Oferta criada a partir da carteira do membro. Pastor/financeiro confirma na wallet 877688695.',
      now() - interval '12 minutes'
    ),
    (
      vida_id,
      member_id,
      som_campaign_id,
      150,
      'MZN',
      'manual_transfer',
      'mpesa',
      '+258827688695',
      'pending_manual_confirmation',
      'campaign',
      'campaign',
      jsonb_build_object('seed_key', 'vida-nova-member-som-150', 'destination_wallet_phone', '877688695'),
      'Contribuicao para campanha Som. Pastor/financeiro confirma na wallet 877688695.',
      now() - interval '9 minutes'
    );

  select id into tithe_id
  from public.donations
  where church_id = vida_id
    and profile_id = member_id
    and metadata->>'seed_key' = 'vida-nova-member-tithe-500'
  limit 1;

  select id into offering_id
  from public.donations
  where church_id = vida_id
    and profile_id = member_id
    and metadata->>'seed_key' = 'vida-nova-member-offering-300'
  limit 1;

  select id into campaign_donation_id
  from public.donations
  where church_id = vida_id
    and profile_id = member_id
    and metadata->>'seed_key' = 'vida-nova-member-som-150'
  limit 1;

  insert into public.member_wallet_ledger_entries (
    wallet_account_id,
    profile_id,
    church_id,
    direction,
    entry_type,
    amount,
    currency,
    status,
    description,
    reference_table,
    reference_id,
    posted_at
  )
  values
    (member_wallet_id, member_id, vida_id, 'debit', 'tithe', 500, 'MZN', 'pending', 'Dizimo 500 MZN enviado para confirmacao.', 'donations', tithe_id, now() - interval '15 minutes'),
    (member_wallet_id, member_id, vida_id, 'debit', 'offering', 300, 'MZN', 'pending', 'Oferta 300 MZN enviada para confirmacao.', 'donations', offering_id, now() - interval '12 minutes'),
    (member_wallet_id, member_id, vida_id, 'debit', 'campaign', 150, 'MZN', 'pending', 'Campanha Som 150 MZN enviada para confirmacao.', 'donations', campaign_donation_id, now() - interval '9 minutes');
end $$;

notify pgrst, 'reload schema';
