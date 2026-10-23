do $$
declare
  vida_id uuid;
  member_id uuid;
  member_phone text;
  wallet_id uuid;
  current_available numeric(12,2);
  target_available numeric(12,2) := 5000.00;
  adjustment numeric(12,2);
begin
  select c.id
  into vida_id
  from public.churches c
  where (
      lower(trim(c.slug)) = 'vida-nova'
      or upper(trim(coalesce(c.join_code, ''))) = 'VIDA123'
      or lower(trim(c.name)) = 'igreja vida nova'
      or regexp_replace(coalesce(c.phone, ''), '\D', '', 'g') in ('877688695', '258877688695')
    )
    and coalesce(c.is_demo, false) = false
  order by
    case when lower(trim(c.slug)) = 'vida-nova' then 0 else 1 end,
    c.created_at nulls last
  limit 1;

  if vida_id is null then
    raise notice 'Igreja Vida Nova nao encontrada para limpar partilhas.';
    return;
  end if;

  delete from public.community_post_reports r
  using public.community_posts p
  where r.post_id = p.id
    and p.church_id = vida_id;

  delete from public.community_post_saved s
  using public.community_posts p
  where s.post_id = p.id
    and p.church_id = vida_id;

  delete from public.community_post_reactions react
  using public.community_posts p
  where react.post_id = p.id
    and p.church_id = vida_id;

  delete from public.community_post_comments comment
  using public.community_posts p
  where comment.post_id = p.id
    and p.church_id = vida_id;

  delete from public.community_posts
  where church_id = vida_id;

  member_id := public.profile_id_by_phone('827688695');
  if member_id is null then
    raise notice 'Membro 827688695 nao encontrado para credito de carteira.';
    return;
  end if;

  select phone
  into member_phone
  from public.profiles
  where id = member_id;

  wallet_id := public.ensure_member_wallet(member_id, coalesce(member_phone, '+258827688695'));

  select available_balance
  into current_available
  from public.member_wallet_accounts
  where id = wallet_id
  for update;

  adjustment := target_available - coalesce(current_available, 0);

  if adjustment <> 0 then
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
      wallet_id,
      member_id,
      vida_id,
      case when adjustment > 0 then 'credit' else 'debit' end,
      'deposit',
      abs(adjustment),
      'MZN',
      'posted',
      'Ajuste interno para testes: saldo definido em 5.000 MZN no membro 827688695.',
      'member_wallet_accounts',
      wallet_id,
      now()
    );
  end if;

  update public.member_wallet_accounts
  set
    available_balance = target_available,
    pending_balance = 0,
    total_received = case
      when adjustment > 0 then total_received + adjustment
      else total_received
    end,
    phone = coalesce(member_phone, phone, '+258827688695'),
    status = 'active',
    updated_at = now()
  where id = wallet_id;
end $$;
