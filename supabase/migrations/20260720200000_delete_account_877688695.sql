do $$
declare
  target_phone text := '258877688695';
  target_profile_id uuid;
  target_auth_id uuid;
  deleted_phone text;
  wallet_row public.member_wallet_accounts%rowtype;
  transfer_amount numeric(12,2) := 0;
  wallet_provider text := 'mpesa';
  platform_wallet_id uuid;
begin
  select p.id
    into target_profile_id
  from public.profiles p
  where public.normalize_phone_auth_number(p.phone) = target_phone
  limit 1;

  select u.id, u.phone
    into target_auth_id, deleted_phone
  from auth.users u
  where public.normalize_phone_auth_number(u.phone) = target_phone
     or public.normalize_phone_auth_number(u.raw_user_meta_data ->> 'phone') = target_phone
     or u.id = target_profile_id
  order by u.created_at desc nulls last
  limit 1;

  target_profile_id := coalesce(target_profile_id, target_auth_id);

  if target_profile_id is null then
    raise notice 'Conta 877688695 nao encontrada.';
    return;
  end if;

  perform public.ensure_wallet_accounts('platform', null, 'Comunhao');

  select *
    into wallet_row
  from public.member_wallet_accounts
  where profile_id = target_profile_id
  for update;

  if found then
    transfer_amount := greatest(coalesce(wallet_row.available_balance, 0), 0);
    wallet_provider := public.member_wallet_provider(coalesce(wallet_row.phone, deleted_phone, target_phone));

    if transfer_amount > 0 then
      select id
        into platform_wallet_id
      from public.wallet_accounts
      where owner_type = 'platform'
        and church_id is null
        and provider = wallet_provider
      limit 1;

      if platform_wallet_id is not null then
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
          platform_wallet_id,
          null,
          target_profile_id,
          'credit',
          'adjustment',
          transfer_amount,
          wallet_row.currency,
          'posted',
          'Saldo transferido para admin ao apagar a conta 877688695.',
          'member_wallet_accounts',
          wallet_row.id,
          jsonb_build_object(
            'source', 'admin_account_deletion',
            'deleted_profile_id', target_profile_id,
            'deleted_phone', target_phone,
            'provider', wallet_provider
          ),
          now(),
          now()
        );
      end if;
    end if;

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
    select
      wallet_row.id,
      target_profile_id,
      null,
      'debit',
      'account_closure_transfer',
      transfer_amount,
      wallet_row.currency,
      'posted',
      'Saldo transferido para admin ao apagar a conta.',
      'member_wallet_accounts',
      now()
    where transfer_amount > 0;

    update public.member_wallet_accounts
    set
      available_balance = 0,
      total_withdrawn = total_withdrawn + transfer_amount,
      status = 'closed',
      updated_at = now()
    where id = wallet_row.id;
  end if;

  delete from public.internal_notifications
  where recipient_profile_id = target_profile_id;

  update public.internal_notifications
  set actor_profile_id = null
  where actor_profile_id = target_profile_id;

  update public.platform_audit_logs
  set actor_profile_id = null
  where actor_profile_id = target_profile_id;

  delete from public.push_tokens
  where profile_id = target_profile_id;

  delete from public.phone_auth_otps
  where auth_user_id = target_profile_id
     or public.normalize_phone_auth_number(phone) = target_phone;

  update public.memberships
  set status = 'removed'
  where profile_id = target_profile_id
    and status <> 'removed';

  update public.profiles
  set
    full_name = 'Conta apagada',
    phone = null,
    email = null,
    avatar_url = null,
    avatar_storage_path = null
  where id = target_profile_id;

  update auth.identities
  set
    provider_id = target_profile_id::text || '-deleted-' || substr(id::text, 1, 8),
    identity_data = jsonb_build_object(
      'sub', target_profile_id::text,
      'deleted', true,
      'deleted_at', now()
    ),
    updated_at = now()
  where user_id = target_profile_id;

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
  where id = target_profile_id;

  raise notice 'Conta 877688695 apagada. profile_id=%, transferido_para_admin=% %',
    target_profile_id,
    transfer_amount,
    coalesce(wallet_row.currency, 'MZN');
end $$;
