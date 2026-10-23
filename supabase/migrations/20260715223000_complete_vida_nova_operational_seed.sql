do $$
declare
  vida_church_id uuid;
  sara_profile_id uuid;
  member_profile_id uuid;
  admin_profile_id uuid;
  sara_membership_id uuid;
  member_membership_id uuid;
  louvor_ministry_id uuid;
  jovens_ministry_id uuid;
  construcao_campaign_id uuid;
  solidariedade_campaign_id uuid;
  mpesa_wallet_id uuid;
  emola_wallet_id uuid;
begin
  alter table public.church_applications
    disable trigger guard_church_application_mutations;

  select p.id
    into sara_profile_id
  from public.profiles p
  where regexp_replace(coalesce(p.phone, ''), '\D', '', 'g') in ('877688695', '258877688695')
  limit 1;

  if sara_profile_id is null then
    select u.id
      into sara_profile_id
    from auth.users u
    where regexp_replace(coalesce(u.phone, ''), '\D', '', 'g') in ('877688695', '258877688695')
    limit 1;
  end if;

  sara_profile_id := coalesce(sara_profile_id, '00000000-0000-0000-0000-258877688695'::uuid);

  insert into public.profiles (id, full_name, phone, birth_date)
  values (sara_profile_id, 'Sara', '+258877688695', date '1988-09-12')
  on conflict (id) do update
  set
    full_name = excluded.full_name,
    phone = excluded.phone,
    birth_date = excluded.birth_date;

  select p.id
    into member_profile_id
  from public.profiles p
  where regexp_replace(coalesce(p.phone, ''), '\D', '', 'g') in ('827688695', '258827688695')
  limit 1;

  if member_profile_id is null then
    select u.id
      into member_profile_id
    from auth.users u
    where regexp_replace(coalesce(u.phone, ''), '\D', '', 'g') in ('827688695', '258827688695')
    limit 1;
  end if;

  member_profile_id := coalesce(member_profile_id, '00000000-0000-0000-0000-258827688695'::uuid);

  insert into public.profiles (id, full_name, phone, birth_date)
  values (member_profile_id, 'Membro Vida Nova', '+258827688695', date '1994-07-20')
  on conflict (id) do update
  set
    full_name = excluded.full_name,
    phone = excluded.phone,
    birth_date = excluded.birth_date;

  select p.id
    into admin_profile_id
  from public.profiles p
  where regexp_replace(coalesce(p.phone, ''), '\D', '', 'g') in ('841130015', '258841130015')
  limit 1;

  if admin_profile_id is null then
    select u.id
      into admin_profile_id
    from auth.users u
    where regexp_replace(coalesce(u.phone, ''), '\D', '', 'g') in ('841130015', '258841130015')
    limit 1;
  end if;

  admin_profile_id := coalesce(admin_profile_id, '00000000-0000-0000-0000-258841130015'::uuid);

  insert into public.profiles (id, full_name, phone)
  values (admin_profile_id, 'Admin Comunhao', '+258841130015')
  on conflict (id) do update
  set
    full_name = excluded.full_name,
    phone = excluded.phone;

  insert into public.platform_roles (profile_id, role, status)
  values (admin_profile_id, 'super_admin', 'active')
  on conflict (profile_id, role) do update
  set status = 'active';

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
    default_currency,
    active
  )
  values (
    'Igreja Vida Nova',
    'vida-nova',
    'VIDA123',
    'Igreja Vida Nova',
    'Uma familia em Cristo no coracao de Maputo',
    'Bem-vindo a Igreja Vida Nova.',
    'Cultos, eventos, mensagens, contribuicoes e acompanhamento pastoral em um unico lugar.',
    'assets/branding/comunhao.png',
    '#8B5CF6',
    '#C084FC',
    '+258877688695',
    'vida.nova@comunhao.app',
    'Maputo',
    'Mozambique',
    'MZN',
    true
  )
  on conflict (slug) do update
  set
    name = excluded.name,
    join_code = excluded.join_code,
    app_name = excluded.app_name,
    tagline = excluded.tagline,
    hero_title = excluded.hero_title,
    hero_subtitle = excluded.hero_subtitle,
    logo_url = excluded.logo_url,
    primary_color = excluded.primary_color,
    secondary_color = excluded.secondary_color,
    phone = excluded.phone,
    email = excluded.email,
    city = excluded.city,
    country = excluded.country,
    default_currency = excluded.default_currency,
    active = excluded.active
  returning id into vida_church_id;

  insert into public.church_settings (
    church_id,
    member_join_mode,
    join_link,
    require_member_approval,
    allow_public_events,
    allow_public_announcements
  )
  values (
    vida_church_id,
    'open',
    'https://comunhao.app/join/VIDA123',
    false,
    true,
    true
  )
  on conflict (church_id) do update
  set
    member_join_mode = excluded.member_join_mode,
    join_link = excluded.join_link,
    require_member_approval = excluded.require_member_approval,
    allow_public_events = excluded.allow_public_events,
    allow_public_announcements = excluded.allow_public_announcements;

  insert into public.church_subscriptions (
    church_id,
    plan_code,
    status,
    trial_started_at,
    trial_ends_at,
    current_period_started_at,
    current_period_ends_at,
    admin_notes
  )
  values (
    vida_church_id,
    'premium',
    'active',
    now() - interval '10 days',
    now() + interval '20 days',
    now(),
    now() + interval '30 days',
    'Vida Nova ativa para demonstracao operacional completa.'
  )
  on conflict (church_id) do update
  set
    plan_code = excluded.plan_code,
    status = excluded.status,
    trial_started_at = excluded.trial_started_at,
    trial_ends_at = excluded.trial_ends_at,
    current_period_started_at = excluded.current_period_started_at,
    current_period_ends_at = excluded.current_period_ends_at,
    admin_notes = excluded.admin_notes;

  perform public.ensure_wallet_accounts('church', vida_church_id, 'Igreja Vida Nova');
  perform public.ensure_wallet_accounts('platform', null, 'Comunhao');

  insert into public.church_payment_settings (
    church_id,
    provider,
    account_name,
    account_number,
    instructions,
    is_primary
  )
  values
    (
      vida_church_id,
      'mpesa',
      'Igreja Vida Nova - Sara',
      '+258877688695',
      'Envia o valor por M-Pesa para Sara e confirma o codigo da transacao no checkout.',
      true
    ),
    (
      vida_church_id,
      'emola',
      'Igreja Vida Nova - Sara',
      '+258877688695',
      'Envia o valor por E-Mola para Sara e confirma o codigo da transacao no checkout.',
      false
    )
  on conflict (church_id, provider) do update
  set
    account_name = excluded.account_name,
    account_number = excluded.account_number,
    instructions = excluded.instructions,
    is_primary = excluded.is_primary;

  insert into public.memberships (church_id, profile_id, role, status, member_code)
  values (vida_church_id, sara_profile_id, 'pastor', 'active', 'VIDA-PASTOR')
  on conflict (church_id, profile_id) do update
  set role = 'pastor', status = 'active', member_code = excluded.member_code
  returning id into sara_membership_id;

  insert into public.memberships (church_id, profile_id, role, status, member_code)
  values (vida_church_id, member_profile_id, 'member', 'active', 'VIDA-0001')
  on conflict (church_id, profile_id) do update
  set role = 'member', status = 'active', member_code = excluded.member_code
  returning id into member_membership_id;

  delete from public.church_applications
  where pastor_profile_id = sara_profile_id
    and church_name = 'Igreja Vida Nova';

  insert into public.church_applications (
    pastor_profile_id,
    church_name,
    city,
    province,
    country,
    phone,
    email,
    applicant_role,
    logo_url,
    primary_color,
    secondary_color,
    tagline,
    mpesa,
    emola,
    status,
    submitted_at,
    reviewed_at,
    reviewed_by,
    approved_church_id,
    review_notes
  )
  values (
    sara_profile_id,
    'Igreja Vida Nova',
    'Maputo',
    'Maputo',
    'Mozambique',
    '+258877688695',
    'vida.nova@comunhao.app',
    'pastor',
    'assets/branding/comunhao.png',
    '#8B5CF6',
    '#C084FC',
    'Uma familia em Cristo no coracao de Maputo',
    '+258877688695',
    '+258877688695',
    'approved',
    now() - interval '12 days',
    now() - interval '11 days',
    admin_profile_id,
    vida_church_id,
    'Igreja aprovada e ativa.'
  );

  delete from public.announcements
  where church_id = vida_church_id
    and title in (
      'Mensagem da Semana',
      'Escala do Culto de Domingo',
      'Encontro de Jovens',
      'Pedido de Oracao da Comunidade'
    );

  insert into public.announcements (church_id, title, body, pinned, published_at, created_by)
  values
    (
      vida_church_id,
      'Mensagem da Semana',
      'A paz do Senhor. Esta semana vamos caminhar em unidade, visitacao e oracao pelas familias.',
      true,
      now() - interval '2 days',
      sara_profile_id
    ),
    (
      vida_church_id,
      'Escala do Culto de Domingo',
      'Louvor as 07:30, intercessao as 08:00 e culto principal as 09:00.',
      false,
      now() - interval '1 day',
      sara_profile_id
    ),
    (
      vida_church_id,
      'Encontro de Jovens',
      'Sexta-feira teremos encontro de jovens com louvor, palavra e partilha.',
      false,
      now(),
      sara_profile_id
    ),
    (
      vida_church_id,
      'Pedido de Oracao da Comunidade',
      'A lideranca pede oracao pelas familias, estudantes e novos membros.',
      false,
      now(),
      sara_profile_id
    );

  delete from public.events
  where church_id = vida_church_id
    and title in (
      'Culto de Domingo - Celebracao',
      'Culto de Ensino Biblico',
      'Vigilia de Oracao',
      'Reuniao de Lideres',
      'Encontro de Jovens Vida Nova'
    );

  insert into public.events (
    church_id,
    title,
    event_type,
    description,
    location,
    starts_at,
    ends_at,
    registration_required,
    capacity,
    created_by
  )
  values
    (
      vida_church_id,
      'Culto de Domingo - Celebracao',
      'culto',
      'Culto principal com louvor, palavra e acompanhamento pastoral.',
      'Templo Vida Nova, Maputo',
      date_trunc('day', now()) + interval '4 days' + interval '9 hours',
      date_trunc('day', now()) + interval '4 days' + interval '11 hours',
      false,
      300,
      sara_profile_id
    ),
    (
      vida_church_id,
      'Culto de Ensino Biblico',
      'culto',
      'Estudo biblico para membros e novos convertidos.',
      'Sala de ensino',
      date_trunc('day', now()) + interval '2 days' + interval '18 hours',
      date_trunc('day', now()) + interval '2 days' + interval '19 hours 30 minutes',
      false,
      80,
      sara_profile_id
    ),
    (
      vida_church_id,
      'Vigilia de Oracao',
      'vigilia',
      'Noite de intercessao pela igreja, cidade e familias.',
      'Templo Vida Nova',
      date_trunc('day', now()) + interval '9 days' + interval '21 hours',
      date_trunc('day', now()) + interval '10 days' + interval '1 hour',
      true,
      180,
      sara_profile_id
    ),
    (
      vida_church_id,
      'Reuniao de Lideres',
      'reuniao',
      'Alinhamento mensal com pastores, lideres e coordenadores.',
      'Gabinete pastoral',
      date_trunc('day', now()) + interval '6 days' + interval '17 hours',
      date_trunc('day', now()) + interval '6 days' + interval '18 hours',
      true,
      25,
      sara_profile_id
    ),
    (
      vida_church_id,
      'Encontro de Jovens Vida Nova',
      'conferencia',
      'Programa especial para jovens com louvor, dinamicas e palavra.',
      'Auditorio Vida Nova',
      date_trunc('day', now()) + interval '12 days' + interval '15 hours',
      date_trunc('day', now()) + interval '12 days' + interval '18 hours',
      true,
      120,
      sara_profile_id
    );

  delete from public.donation_campaigns
  where church_id = vida_church_id
    and title in (
      'Construcao e Som do Templo',
      'Cestas Basicas para Familias',
      'Jovens em Missao'
    );

  insert into public.donation_campaigns (
    church_id,
    title,
    description,
    target_amount,
    start_at,
    end_at,
    active,
    created_by
  )
  values
    (
      vida_church_id,
      'Construcao e Som do Templo',
      'Contribuicoes para melhorar cobertura, som e iluminacao do templo.',
      180000.00,
      now() - interval '5 days',
      now() + interval '45 days',
      true,
      sara_profile_id
    ),
    (
      vida_church_id,
      'Cestas Basicas para Familias',
      'Apoio mensal a familias acompanhadas pela igreja.',
      45000.00,
      now() - interval '3 days',
      now() + interval '28 days',
      true,
      sara_profile_id
    ),
    (
      vida_church_id,
      'Jovens em Missao',
      'Transporte e material para evangelismo dos jovens.',
      30000.00,
      now(),
      now() + interval '35 days',
      true,
      sara_profile_id
    );

  select id into construcao_campaign_id
  from public.donation_campaigns
  where church_id = vida_church_id
    and title = 'Construcao e Som do Templo'
  limit 1;

  select id into solidariedade_campaign_id
  from public.donation_campaigns
  where church_id = vida_church_id
    and title = 'Cestas Basicas para Familias'
  limit 1;

  delete from public.prayer_requests
  where church_id = vida_church_id
    and title in ('Saude da familia', 'Direcao para a juventude');

  insert into public.prayer_requests (
    church_id,
    profile_id,
    title,
    description,
    is_private,
    visibility,
    anonymous_request,
    allow_responses,
    status,
    created_at
  )
  values
    (
      vida_church_id,
      member_profile_id,
      'Saude da familia',
      'Pedido de oracao por saude e fortalecimento familiar.',
      true,
      'private',
      false,
      true,
      'new',
      now() - interval '1 day'
    ),
    (
      vida_church_id,
      sara_profile_id,
      'Direcao para a juventude',
      'Oracao pelo encontro de jovens e pela lideranca da nova geracao.',
      false,
      'public',
      false,
      true,
      'new',
      now()
    );

  insert into public.church_ministries (church_id, name, description, leader_membership_id, active)
  values
    (vida_church_id, 'Louvor', 'Equipe responsavel por louvor, ensaio e som.', sara_membership_id, true),
    (vida_church_id, 'Jovens', 'Discipulado, encontros e evangelismo jovem.', member_membership_id, true)
  on conflict (church_id, name) do update
  set
    description = excluded.description,
    leader_membership_id = excluded.leader_membership_id,
    active = excluded.active;

  select id into louvor_ministry_id
  from public.church_ministries
  where church_id = vida_church_id
    and name = 'Louvor';

  select id into jovens_ministry_id
  from public.church_ministries
  where church_id = vida_church_id
    and name = 'Jovens';

  insert into public.ministry_members (ministry_id, membership_id, role)
  values
    (louvor_ministry_id, sara_membership_id, 'leader'),
    (jovens_ministry_id, member_membership_id, 'member')
  on conflict (ministry_id, membership_id) do update
  set role = excluded.role;

  delete from public.church_communications
  where church_id = vida_church_id
    and title in (
      'Lembrete do culto',
      'Mensagem aos lideres',
      'Campanha de solidariedade'
    );

  insert into public.church_communications (
    church_id,
    channel,
    audience_type,
    target_role,
    ministry_id,
    title,
    body,
    status,
    scheduled_at,
    sent_at,
    created_by
  )
  values
    (
      vida_church_id,
      'push',
      'all',
      null,
      null,
      'Lembrete do culto',
      'Domingo as 09:00 teremos culto de celebracao. Chegue cedo e traga a familia.',
      'queued',
      now() + interval '12 hours',
      null,
      sara_profile_id
    ),
    (
      vida_church_id,
      'sms',
      'group',
      'leader',
      null,
      'Mensagem aos lideres',
      'Por favor confirmar escala, visitas e presencas ate sexta-feira.',
      'queued',
      now() + interval '6 hours',
      null,
      sara_profile_id
    ),
    (
      vida_church_id,
      'whatsapp',
      'ministry',
      null,
      jovens_ministry_id,
      'Campanha de solidariedade',
      'Jovens: vamos preparar cestas basicas no sabado as 14:00.',
      'sent',
      now() - interval '1 day',
      now() - interval '1 day',
      sara_profile_id
    );

  delete from public.church_assets
  where church_id = vida_church_id
    and name in ('Mesa de som Yamaha', 'Projetor principal', 'Cadeiras plasticas');

  insert into public.church_assets (
    church_id,
    category,
    name,
    quantity,
    item_condition,
    location,
    notes,
    created_by
  )
  values
    (vida_church_id, 'som', 'Mesa de som Yamaha', 1, 'good', 'Som - templo', 'Usada nos cultos principais.', sara_profile_id),
    (vida_church_id, 'projetor', 'Projetor principal', 1, 'good', 'Auditorio', 'Para letras e apresentacoes.', sara_profile_id),
    (vida_church_id, 'cadeira', 'Cadeiras plasticas', 120, 'good', 'Deposito', 'Uso nos encontros e eventos.', sara_profile_id);

  delete from public.church_visitors
  where church_id = vida_church_id
    and full_name in ('Helena Mateus', 'Carlos Nhantumbo');

  insert into public.church_visitors (
    church_id,
    full_name,
    phone,
    status,
    first_visit_at,
    notes,
    created_by
  )
  values
    (vida_church_id, 'Helena Mateus', '+258845551010', 'returning', now() - interval '8 days', 'Visitou dois cultos e pediu acompanhamento.', sara_profile_id),
    (vida_church_id, 'Carlos Nhantumbo', '+258826661212', 'new', now() - interval '2 days', 'Convidado por membro da juventude.', sara_profile_id);

  delete from public.church_expenses
  where church_id = vida_church_id
    and title in ('Transporte para visitas', 'Manutencao do som');

  insert into public.church_expenses (
    church_id,
    category,
    title,
    amount,
    currency,
    spent_at,
    notes,
    created_by
  )
  values
    (vida_church_id, 'missoes', 'Transporte para visitas', 2200.00, 'MZN', now() - interval '4 days', 'Visitas pastorais em Maputo.', sara_profile_id),
    (vida_church_id, 'manutencao', 'Manutencao do som', 3500.00, 'MZN', now() - interval '9 days', 'Cabos e reparacao de microfone.', sara_profile_id);

  select id into mpesa_wallet_id
  from public.wallet_accounts
  where owner_type = 'church'
    and church_id = vida_church_id
    and provider = 'mpesa'
  limit 1;

  select id into emola_wallet_id
  from public.wallet_accounts
  where owner_type = 'church'
    and church_id = vida_church_id
    and provider = 'emola'
  limit 1;

  delete from public.donations
  where church_id = vida_church_id
    and provider_reference in ('VIDA-MPESA-001', 'VIDA-EMOLA-002', 'VIDA-MPESA-003');

  insert into public.donations (
    church_id,
    profile_id,
    campaign_id,
    amount,
    currency,
    payment_method,
    provider,
    provider_reference,
    status,
    donation_type,
    metadata,
    created_at
  )
  values
    (vida_church_id, member_profile_id, null, 2500.00, 'MZN', 'mobile_money', 'mpesa', 'VIDA-MPESA-001', 'recorded', 'tithe', '{"seed":"vida_nova"}'::jsonb, now() - interval '6 days'),
    (vida_church_id, member_profile_id, construcao_campaign_id, 1500.00, 'MZN', 'mobile_money', 'emola', 'VIDA-EMOLA-002', 'recorded', 'campaign', '{"seed":"vida_nova"}'::jsonb, now() - interval '3 days'),
    (vida_church_id, sara_profile_id, solidariedade_campaign_id, 3000.00, 'MZN', 'mobile_money', 'mpesa', 'VIDA-MPESA-003', 'recorded', 'campaign', '{"seed":"vida_nova"}'::jsonb, now() - interval '1 day');

  delete from public.wallet_ledger_entries
  where church_id = vida_church_id
    and description in (
      'Vida Nova dizimo M-Pesa - membro 827688695',
      'Vida Nova campanha E-Mola - membro 827688695',
      'Vida Nova campanha M-Pesa - Sara',
      'Vida Nova despesa - transporte',
      'Vida Nova despesa - manutencao'
    );

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
    posted_at,
    created_at
  )
  values
    (mpesa_wallet_id, vida_church_id, member_profile_id, 'credit', 'tithe', 2500.00, 'MZN', 'posted', 'Vida Nova dizimo M-Pesa - membro 827688695', 'donations', null, now() - interval '6 days', now() - interval '6 days'),
    (emola_wallet_id, vida_church_id, member_profile_id, 'credit', 'campaign', 1500.00, 'MZN', 'posted', 'Vida Nova campanha E-Mola - membro 827688695', 'donations', null, now() - interval '3 days', now() - interval '3 days'),
    (mpesa_wallet_id, vida_church_id, sara_profile_id, 'credit', 'campaign', 3000.00, 'MZN', 'posted', 'Vida Nova campanha M-Pesa - Sara', 'donations', null, now() - interval '1 day', now() - interval '1 day'),
    (mpesa_wallet_id, vida_church_id, sara_profile_id, 'debit', 'withdrawal', 2200.00, 'MZN', 'posted', 'Vida Nova despesa - transporte', 'church_expenses', null, now() - interval '4 days', now() - interval '4 days'),
    (mpesa_wallet_id, vida_church_id, sara_profile_id, 'debit', 'withdrawal', 3500.00, 'MZN', 'posted', 'Vida Nova despesa - manutencao', 'church_expenses', null, now() - interval '9 days', now() - interval '9 days');

  delete from public.wallet_withdrawal_requests
  where church_id = vida_church_id
    and notes = 'Levantamento Vida Nova para despesas de culto.';

  insert into public.wallet_withdrawal_requests (
    wallet_account_id,
    owner_type,
    church_id,
    requested_by,
    provider,
    amount,
    currency,
    destination_number,
    status,
    notes
  )
  values (
    mpesa_wallet_id,
    'church',
    vida_church_id,
    sara_profile_id,
    'mpesa',
    5000.00,
    'MZN',
    '+258877688695',
    'pending',
    'Levantamento Vida Nova para despesas de culto.'
  );

  alter table public.church_applications
    enable trigger guard_church_application_mutations;
end $$;
