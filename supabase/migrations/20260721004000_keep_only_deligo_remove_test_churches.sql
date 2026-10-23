do $$
declare
  keep_church_id uuid;
  keep_count integer;
  church_row record;
  wallet_row record;
  platform_wallet_id uuid;
  wallet_balance numeric(12, 2);
  fk_row record;
  changed_count integer;
  deleted_churches integer := 0;
  disabled_wallet_guard boolean := false;
  disabled_donation_guard boolean := false;
  disabled_expense_guard boolean := false;
begin
  select count(*)
  into keep_count
  from public.churches
  where lower(trim(name)) = 'deligo'
     or lower(trim(slug)) = 'deligo';

  if keep_count <> 1 then
    raise exception 'Limpeza cancelada: esperado exatamente 1 igreja Deligo, encontradas %.', keep_count;
  end if;

  select id
  into keep_church_id
  from public.churches
  where lower(trim(name)) = 'deligo'
     or lower(trim(slug)) = 'deligo'
  order by created_at desc nulls last, name
  limit 1;

  perform public.ensure_wallet_accounts('platform', null, 'Comunhao');

  begin
    if exists (
      select 1 from pg_trigger
      where tgrelid = 'public.wallet_ledger_entries'::regclass
        and tgname = 'guard_wallet_ledger_immutability'
    ) then
      alter table public.wallet_ledger_entries
        disable trigger guard_wallet_ledger_immutability;
      disabled_wallet_guard := true;
    end if;

    if exists (
      select 1 from pg_trigger
      where tgrelid = 'public.donations'::regclass
        and tgname = 'guard_donation_finance_immutability'
    ) then
      alter table public.donations
        disable trigger guard_donation_finance_immutability;
      disabled_donation_guard := true;
    end if;

    if exists (
      select 1 from pg_trigger
      where tgrelid = 'public.church_expenses'::regclass
        and tgname = 'guard_church_expense_immutability'
    ) then
      alter table public.church_expenses
        disable trigger guard_church_expense_immutability;
      disabled_expense_guard := true;
    end if;

    for church_row in
      select id, name
      from public.churches
      where id <> keep_church_id
      order by created_at nulls first, name
    loop
      for wallet_row in
        select id, provider, currency
        from public.wallet_accounts
        where owner_type = 'church'
          and church_id = church_row.id
      loop
        select coalesce(sum(
          case
            when direction = 'credit' then amount
            when direction = 'debit' then -amount
            else 0
          end
        ), 0)
        into wallet_balance
        from public.wallet_ledger_entries
        where wallet_account_id = wallet_row.id
          and status = 'posted';

        if wallet_balance > 0 then
          select id
          into platform_wallet_id
          from public.wallet_accounts
          where owner_type = 'platform'
            and church_id is null
            and provider = wallet_row.provider
          limit 1;

          if platform_wallet_id is not null then
            insert into public.wallet_ledger_entries (
              wallet_account_id,
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
              'credit',
              'adjustment',
              wallet_balance,
              coalesce(wallet_row.currency, 'MZN'),
              'posted',
              'Saldo transferido para a conta admin ao remover igreja de teste.',
              'churches',
              church_row.id,
              jsonb_build_object(
                'source', 'keep_only_deligo_cleanup',
                'deleted_church_id', church_row.id,
                'deleted_church_name', church_row.name,
                'provider', wallet_row.provider
              ),
              now(),
              now()
            );
          end if;
        end if;
      end loop;

      update public.churches
      set parent_church_id = null
      where parent_church_id = church_row.id;

      if to_regclass('public.donations') is not null then
        delete from public.donations
        where church_id = church_row.id
           or campaign_id in (
             select id
             from public.donation_campaigns
             where church_id = church_row.id
           );
      end if;

      for fk_row in
        select
          n.nspname as schema_name,
          c.relname as table_name,
          a.attname as column_name
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
        order by c.relname
      loop
        execute format(
          'delete from %I.%I where %I = $1',
          fk_row.schema_name,
          fk_row.table_name,
          fk_row.column_name
        )
        using church_row.id;
        get diagnostics changed_count = row_count;
      end loop;

      delete from public.churches
      where id = church_row.id;

      deleted_churches := deleted_churches + 1;
    end loop;

    if disabled_expense_guard then
      alter table public.church_expenses
        enable trigger guard_church_expense_immutability;
    end if;

    if disabled_donation_guard then
      alter table public.donations
        enable trigger guard_donation_finance_immutability;
    end if;

    if disabled_wallet_guard then
      alter table public.wallet_ledger_entries
        enable trigger guard_wallet_ledger_immutability;
    end if;
  exception
    when others then
      if disabled_expense_guard then
        alter table public.church_expenses
          enable trigger guard_church_expense_immutability;
      end if;

      if disabled_donation_guard then
        alter table public.donations
          enable trigger guard_donation_finance_immutability;
      end if;

      if disabled_wallet_guard then
        alter table public.wallet_ledger_entries
          enable trigger guard_wallet_ledger_immutability;
      end if;

      raise;
  end;

  raise notice 'Limpeza concluida. Igreja preservada: %, igrejas removidas: %',
    keep_church_id,
    deleted_churches;
end $$;
