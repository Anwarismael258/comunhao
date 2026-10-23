create or replace function public.delete_my_account()
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  current_profile_id uuid := auth.uid();
  deleted_phone text;
  target_church_id uuid;
  church_name text;
  member_wallet public.member_wallet_accounts%rowtype;
  transfer_amount numeric(12,2) := 0;
  wallet_provider text;
  church_wallet_id uuid;
begin
  if current_profile_id is null then
    raise exception 'Sessao invalida.';
  end if;

  select phone
  into deleted_phone
  from auth.users
  where id = current_profile_id
    and deleted_at is null
  limit 1;

  if not found then
    raise exception 'Conta nao encontrada ou ja apagada.';
  end if;

  select m.church_id, c.name
  into target_church_id, church_name
  from public.memberships m
  join public.churches c on c.id = m.church_id
  where m.profile_id = current_profile_id
  order by
    case m.status when 'active' then 0 else 1 end,
    m.created_at desc nulls last
  limit 1;

  select *
  into member_wallet
  from public.member_wallet_accounts
  where profile_id = current_profile_id
  for update;

  if found then
    transfer_amount := greatest(coalesce(member_wallet.available_balance, 0), 0);
    wallet_provider := public.member_wallet_provider(coalesce(member_wallet.phone, deleted_phone));
  end if;

  if transfer_amount > 0 and target_church_id is not null then
    perform public.ensure_wallet_accounts('church', target_church_id, church_name);

    select id
    into church_wallet_id
    from public.wallet_accounts
    where owner_type = 'church'
      and church_id = target_church_id
      and provider = wallet_provider
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
      posted_at
    )
    values (
      member_wallet.id,
      current_profile_id,
      target_church_id,
      'debit',
      'account_closure_transfer',
      transfer_amount,
      member_wallet.currency,
      'posted',
      'Saldo transferido para a conta da igreja ao apagar a conta do membro.',
      'wallet_accounts',
      now()
    );

    update public.member_wallet_accounts
    set
      available_balance = 0,
      total_withdrawn = total_withdrawn + transfer_amount,
      status = 'closed',
      updated_at = now()
    where id = member_wallet.id;

    if church_wallet_id is not null then
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
        posted_at
      )
      values (
        church_wallet_id,
        target_church_id,
        current_profile_id,
        'credit',
        'adjustment',
        transfer_amount,
        member_wallet.currency,
        'posted',
        'Saldo de membro transferido automaticamente ao apagar conta.',
        'member_wallet_accounts',
        member_wallet.id,
        jsonb_build_object(
          'source', 'member_account_deletion',
          'member_profile_id', current_profile_id,
          'member_phone', deleted_phone
        ),
        now()
      );
    end if;
  elsif found then
    update public.member_wallet_accounts
    set status = 'closed', updated_at = now()
    where id = member_wallet.id;
  end if;

  update public.memberships
  set status = 'removed'
  where profile_id = current_profile_id
    and status <> 'removed';

  delete from public.push_tokens
  where profile_id = current_profile_id;

  delete from public.phone_auth_otps
  where auth_user_id = current_profile_id;

  update public.profiles
  set
    full_name = 'Conta apagada',
    phone = null,
    email = null,
    avatar_url = null,
    avatar_storage_path = null
  where id = current_profile_id;

  update auth.identities
  set
    provider_id = current_profile_id::text,
    identity_data = jsonb_build_object(
      'sub', current_profile_id::text,
      'deleted', true,
      'deleted_at', now()
    ),
    updated_at = now()
  where user_id = current_profile_id;

  update auth.users
  set
    phone = null,
    encrypted_password = extensions.crypt(gen_random_uuid()::text, extensions.gen_salt('bf')),
    phone_confirmed_at = null,
    raw_user_meta_data = jsonb_build_object(
      'deleted', true,
      'deleted_at', now()
    ),
    raw_app_meta_data = jsonb_build_object(
      'provider', 'phone',
      'providers', jsonb_build_array('phone'),
      'deleted', true
    ),
    deleted_at = now(),
    updated_at = now()
  where id = current_profile_id;

  return jsonb_build_object(
    'deleted', true,
    'profile_id', current_profile_id,
    'phone', deleted_phone,
    'transferred_balance', transfer_amount,
    'transfer_church_id', target_church_id
  );
end;
$$;

grant execute on function public.delete_my_account() to authenticated;
