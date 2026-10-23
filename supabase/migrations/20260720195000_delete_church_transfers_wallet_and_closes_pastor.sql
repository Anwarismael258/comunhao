create or replace function public.delete_own_church(
  p_church_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  current_profile_id uuid := auth.uid();
  church_row public.churches%rowtype;
  notified_count integer := 0;
  fk_row record;
  wallet_row public.wallet_accounts%rowtype;
  platform_wallet_id uuid;
  wallet_balance numeric(12,2) := 0;
  total_transferred numeric(12,2) := 0;
  changed_count integer := 0;
  total_nullified integer := 0;
  total_deleted integer := 0;
  deleted_phone text;
begin
  if current_profile_id is null then
    raise exception 'Sessao invalida.';
  end if;

  if not public.has_church_role(
    p_church_id,
    array['pastor', 'church_admin']::text[],
    current_profile_id
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

  select phone
    into deleted_phone
  from auth.users
  where id = current_profile_id
  limit 1;

  perform public.ensure_wallet_accounts('platform', null, 'Comunhao');

  for wallet_row in
    select *
    from public.wallet_accounts
    where owner_type = 'church'
      and church_id = p_church_id
      and status = 'active'
  loop
    wallet_balance := public.wallet_account_balance(wallet_row.id);
    if wallet_balance <= 0 then
      continue;
    end if;

    select id
      into platform_wallet_id
    from public.wallet_accounts
    where owner_type = 'platform'
      and church_id is null
      and provider = wallet_row.provider
    limit 1;

    if platform_wallet_id is null then
      continue;
    end if;

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
      current_profile_id,
      'credit',
      'adjustment',
      wallet_balance,
      wallet_row.currency,
      'posted',
      'Saldo transferido para a conta admin ao apagar igreja.',
      'wallet_accounts',
      wallet_row.id,
      jsonb_build_object(
        'source', 'church_deletion_transfer',
        'deleted_church_id', p_church_id,
        'deleted_church_name', church_row.name,
        'provider', wallet_row.provider
      ),
      now(),
      now()
    );

    total_transferred := total_transferred + wallet_balance;
  end loop;

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
    current_profile_id,
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

  update public.church_applications
  set
    approved_church_id = null,
    status = case when status = 'approved' then 'draft' else status end,
    review_notes = concat_ws(
      E'\n',
      nullif(review_notes, ''),
      'Igreja apagada pelo pastor em ' || now()::text || '. Pode cadastrar uma nova igreja.'
    )
  where approved_church_id = p_church_id;

  update public.churches
  set parent_church_id = null
  where parent_church_id = p_church_id;

  for fk_row in
    select
      n.nspname as schema_name,
      c.relname as table_name,
      a.attname as column_name,
      a.attnotnull as column_not_null,
      con.confdeltype as delete_action
    from pg_constraint con
    join pg_class c on c.oid = con.conrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_attribute a
      on a.attrelid = con.conrelid
     and a.attnum = con.conkey[1]
    where con.contype = 'f'
      and con.confrelid = 'public.churches'::regclass
      and array_length(con.conkey, 1) = 1
      and n.nspname = 'public'
      and not (n.nspname = 'public' and c.relname = 'churches')
  loop
    if fk_row.delete_action = 'c' then
      continue;
    end if;

    if not fk_row.column_not_null then
      execute format(
        'update %I.%I set %I = null where %I = $1',
        fk_row.schema_name,
        fk_row.table_name,
        fk_row.column_name,
        fk_row.column_name
      )
      using p_church_id;
      get diagnostics changed_count = row_count;
      total_nullified := total_nullified + changed_count;
    else
      execute format(
        'delete from %I.%I where %I = $1',
        fk_row.schema_name,
        fk_row.table_name,
        fk_row.column_name,
        fk_row.column_name
      )
      using p_church_id;
      get diagnostics changed_count = row_count;
      total_deleted := total_deleted + changed_count;
    end if;
  end loop;

  delete from public.churches
  where id = p_church_id;

  if not found then
    raise exception 'Igreja nao encontrada ou ja removida.';
  end if;

  delete from public.push_tokens
  where profile_id = current_profile_id;

  delete from public.phone_auth_otps
  where auth_user_id = current_profile_id;

  update public.memberships
  set status = 'removed'
  where profile_id = current_profile_id
    and status <> 'removed';

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
    'church_id', p_church_id,
    'church_name', church_row.name,
    'notified_members', notified_count,
    'transferred_to_admin', total_transferred,
    'pastor_account_deleted', true,
    'pastor_phone', deleted_phone,
    'references_nullified', total_nullified,
    'references_deleted', total_deleted,
    'deleted', true
  );
end;
$$;

grant execute on function public.delete_own_church(uuid) to authenticated;
