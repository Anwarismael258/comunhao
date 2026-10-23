insert into public.churches (
  name,
  slug,
  join_code,
  app_name,
  tagline,
  hero_title,
  hero_subtitle,
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
  'Igreja Vida Nova App',
  'Powered by Comunhao',
  'Uma casa digital para a Igreja Vida Nova.',
  'Doacoes, eventos e comunicacao num unico lugar para a tua comunidade.',
  '#1F6F54',
  '#2E7D61',
  '+258 84 000 0000',
  'contato@vidanova.co.mz',
  'Maputo',
  'Mozambique',
  'MZN',
  true
)
on conflict (slug) do update
set
  join_code = excluded.join_code,
  app_name = excluded.app_name,
  tagline = excluded.tagline,
  hero_title = excluded.hero_title,
  hero_subtitle = excluded.hero_subtitle,
  primary_color = excluded.primary_color,
  secondary_color = excluded.secondary_color,
  phone = excluded.phone,
  email = excluded.email,
  city = excluded.city,
  country = excluded.country,
  default_currency = excluded.default_currency,
  active = excluded.active;
