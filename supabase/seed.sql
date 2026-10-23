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
  active = excluded.active;

with church as (
  select id, join_code
  from public.churches
  where slug = 'vida-nova'
)
insert into public.church_settings (
  church_id,
  member_join_mode,
  join_link,
  require_member_approval
)
select
  church.id,
  'open',
  'https://comunhao.app/join/' || upper(church.join_code),
  true
from church
on conflict (church_id) do update
set
  member_join_mode = excluded.member_join_mode,
  join_link = excluded.join_link,
  require_member_approval = excluded.require_member_approval;

with church as (
  select id
  from public.churches
  where slug = 'vida-nova'
)
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
select
  church.id,
  'premium',
  'trial',
  now(),
  now() + interval '30 days',
  now(),
  now() + interval '30 days',
  'Seed demo com trial Premium ativo.'
from church
on conflict (church_id) do update
set
  plan_code = excluded.plan_code,
  status = excluded.status,
  trial_started_at = excluded.trial_started_at,
  trial_ends_at = excluded.trial_ends_at,
  current_period_started_at = excluded.current_period_started_at,
  current_period_ends_at = excluded.current_period_ends_at,
  admin_notes = excluded.admin_notes;

with church as (
  select id
  from public.churches
  where slug = 'vida-nova'
)
insert into public.church_payment_settings (
  church_id,
  provider,
  account_name,
  account_number,
  instructions,
  is_primary
)
select
  church.id,
  data.provider,
  data.account_name,
  data.account_number,
  data.instructions,
  data.is_primary
from church
cross join (
  values
    ('mpesa', 'Igreja Vida Nova - Sara', '+258877688695', 'Envia por M-Pesa para Sara e confirma o codigo da transacao no checkout.', true),
    ('emola', 'Igreja Vida Nova - Sara', '+258877688695', 'Envia por E-Mola para Sara e confirma o codigo da transacao no checkout.', false)
) as data(provider, account_name, account_number, instructions, is_primary)
on conflict (church_id, provider) do update
set
  account_name = excluded.account_name,
  account_number = excluded.account_number,
  instructions = excluded.instructions,
  is_primary = excluded.is_primary;

with church as (
  select id
  from public.churches
  where slug = 'vida-nova'
)
delete from public.announcements
where church_id = (select id from church)
  and title in (
    'Campanha de construcao',
    'Conferencia da juventude',
    'Escala de voluntarios'
  );

with church as (
  select id
  from public.churches
  where slug = 'vida-nova'
)
insert into public.announcements (
  church_id,
  title,
  body,
  pinned,
  published_at
)
select
  church.id,
  data.title,
  data.body,
  data.pinned,
  now()
from church
cross join (
  values
    ('Campanha de construcao', 'Meta do mes: 150.000 MZN para a fase final da obra.', true),
    ('Conferencia da juventude', 'Inscricoes abertas ate sexta-feira no aplicativo.', false),
    ('Escala de voluntarios', 'Os lideres de equipa ja podem confirmar presenca para domingo.', false)
) as data(title, body, pinned);

with church as (
  select id
  from public.churches
  where slug = 'vida-nova'
)
delete from public.events
where church_id = (select id from church)
  and title in (
    'Culto de domingo',
    'Encontro de lideres',
    'Conferencia da juventude'
  );

with church as (
  select id
  from public.churches
  where slug = 'vida-nova'
)
insert into public.events (
  church_id,
  title,
  description,
  location,
  starts_at,
  registration_required,
  capacity
)
select
  church.id,
  data.title,
  data.description,
  data.location,
  data.starts_at,
  data.registration_required,
  data.capacity
from church
cross join (
  values
    (
      'Culto de domingo',
      'Culto principal da semana com toda a comunidade.',
      'Templo central',
      now() + interval '1 day',
      false,
      null
    ),
    (
      'Encontro de lideres',
      'Alinhamento semanal com coordenadores de departamentos.',
      'Sala 2',
      now() + interval '3 days',
      true,
      40
    ),
    (
      'Conferencia da juventude',
      'Programa especial para jovens com louvor e palavra.',
      'Auditorio',
      now() + interval '7 days',
      true,
      250
    )
) as data(title, description, location, starts_at, registration_required, capacity);

with church as (
  select id
  from public.churches
  where slug = 'vida-nova'
)
delete from public.donation_campaigns
where church_id = (select id from church)
  and title in (
    'Construcao do templo',
    'Acao solidaria'
  );

with church as (
  select id
  from public.churches
  where slug = 'vida-nova'
)
insert into public.donation_campaigns (
  church_id,
  title,
  description,
  target_amount,
  start_at,
  end_at,
  active
)
select
  church.id,
  data.title,
  data.description,
  data.target_amount,
  data.start_at,
  data.end_at,
  data.active
from church
cross join (
  values
    (
      'Construcao do templo',
      'Contribuicoes para concluir cobertura e sonorizacao.',
      150000.00,
      now(),
      now() + interval '30 days',
      true
    ),
    (
      'Acao solidaria',
      'Apoio a familias vulneraveis da comunidade.',
      25000.00,
      now(),
      now() + interval '21 days',
      true
    )
) as data(title, description, target_amount, start_at, end_at, active);

select public.ensure_wallet_accounts('platform', null, 'Comunhao');

with church as (
  select id, name
  from public.churches
  where slug = 'vida-nova'
)
select public.ensure_wallet_accounts('church', church.id, church.name)
from church;

delete from public.wallet_ledger_entries
where description in (
  'Seed receita de plano M-Pesa',
  'Seed receita extra E-Mola',
  'Seed ajuste manual Comunhao',
  'Seed dizimo M-Pesa',
  'Seed oferta M-Pesa',
  'Seed campanha E-Mola'
);

delete from public.wallet_withdrawal_requests
where notes in (
  'Seed levantamento Comunhao',
  'Seed levantamento igreja'
);

with platform_wallets as (
  select id, provider
  from public.wallet_accounts
  where owner_type = 'platform'
    and church_id is null
)
insert into public.wallet_ledger_entries (
  wallet_account_id,
  direction,
  entry_type,
  amount,
  currency,
  status,
  description,
  posted_at
)
select
  wallet.id,
  'credit',
  data.entry_type,
  data.amount,
  'MZN',
  'posted',
  data.description,
  now()
from platform_wallets wallet
join (
  values
    ('mpesa', 'subscription_payment', 4500.00, 'Seed receita de plano M-Pesa'),
    ('emola', 'other_revenue', 2800.00, 'Seed receita extra E-Mola'),
    ('mpesa', 'adjustment', 900.00, 'Seed ajuste manual Comunhao')
) as data(provider, entry_type, amount, description)
  on data.provider = wallet.provider;

with church as (
  select id
  from public.churches
  where slug = 'vida-nova'
),
church_wallets as (
  select wallet.id, wallet.provider, church.id as church_id
  from public.wallet_accounts wallet
  join church
    on church.id = wallet.church_id
  where wallet.owner_type = 'church'
)
insert into public.wallet_ledger_entries (
  wallet_account_id,
  church_id,
  direction,
  entry_type,
  amount,
  currency,
  status,
  description,
  posted_at
)
select
  wallet.id,
  wallet.church_id,
  'credit',
  data.entry_type,
  data.amount,
  'MZN',
  'posted',
  data.description,
  now()
from church_wallets wallet
join (
  values
    ('mpesa', 'tithe', 12000.00, 'Seed dizimo M-Pesa'),
    ('mpesa', 'offering', 6500.00, 'Seed oferta M-Pesa'),
    ('emola', 'campaign', 3200.00, 'Seed campanha E-Mola')
) as data(provider, entry_type, amount, description)
  on data.provider = wallet.provider;

with platform_wallet as (
  select id
  from public.wallet_accounts
  where owner_type = 'platform'
    and church_id is null
    and provider = 'mpesa'
  limit 1
),
platform_actor as (
  select profile_id
  from public.platform_roles
  order by created_at
  limit 1
)
insert into public.wallet_withdrawal_requests (
  wallet_account_id,
  owner_type,
  requested_by,
  provider,
  amount,
  currency,
  destination_number,
  status,
  notes
)
select
  platform_wallet.id,
  'platform',
  platform_actor.profile_id,
  'mpesa',
  1000.00,
  'MZN',
  '+258840000111',
  'pending',
  'Seed levantamento Comunhao'
from platform_wallet
cross join platform_actor;

with church as (
  select id
  from public.churches
  where slug = 'vida-nova'
),
church_wallet as (
  select wallet.id, church.id as church_id
  from public.wallet_accounts wallet
  join church
    on church.id = wallet.church_id
  where wallet.owner_type = 'church'
    and wallet.provider = 'emola'
  limit 1
),
church_actor as (
  select memberships.profile_id
  from public.memberships
  join church
    on church.id = memberships.church_id
  where memberships.status = 'active'
  order by memberships.created_at
  limit 1
)
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
select
  church_wallet.id,
  'church',
  church_wallet.church_id,
  church_actor.profile_id,
  'emola',
  1500.00,
  'MZN',
  '+258860000222',
  'processing',
  'Seed levantamento igreja'
from church_wallet
cross join church_actor;
