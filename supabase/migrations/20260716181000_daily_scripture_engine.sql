create table if not exists public.scripture_translation_reports (
  bible_id text primary key,
  provider text not null default 'api_bible',
  name text not null,
  abbreviation text,
  language_code text not null default 'por',
  copyright text,
  license_summary text,
  commercial_use_status text not null
    check (commercial_use_status in ('allowed', 'not_confirmed', 'restricted')),
  attribution_required boolean not null default true,
  attribution_notes text,
  last_checked_at timestamptz not null default now(),
  raw_metadata jsonb not null default '{}'::jsonb
);

create table if not exists public.scripture_reference_library (
  id uuid primary key default gen_random_uuid(),
  reference_key text not null unique,
  human_reference text not null,
  book_id text not null,
  chapter integer not null,
  verse_start integer not null,
  verse_end integer,
  theme text not null,
  weight integer not null default 10,
  active boolean not null default true,
  last_used_at date,
  fallback_text text,
  fallback_translation text,
  fallback_copyright text,
  created_at timestamptz not null default now()
);

create table if not exists public.daily_devotional_library (
  id uuid primary key default gen_random_uuid(),
  theme text not null,
  title text not null,
  summary text not null,
  reflection text not null,
  practical_application text not null,
  prayer text not null,
  active boolean not null default true,
  last_used_at date,
  created_at timestamptz not null default now()
);

create table if not exists public.daily_scripture_contents (
  id uuid primary key default gen_random_uuid(),
  content_date date not null unique,
  provider text not null,
  bible_id text,
  bible_name text,
  bible_abbreviation text,
  reference_key text not null,
  reference_label text not null,
  book_id text,
  chapter integer,
  verse_start integer,
  verse_end integer,
  scripture_text text not null,
  copyright text,
  theme text not null,
  devotional_title text not null,
  devotional_summary text not null,
  devotional_reflection text not null,
  practical_application text not null,
  prayer text not null,
  source_status text not null
    check (source_status in ('api_bible', 'cache_today', 'cache_latest', 'local_fallback')),
  generated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists idx_scripture_reference_theme
  on public.scripture_reference_library(theme, active, last_used_at);

create index if not exists idx_daily_devotional_theme
  on public.daily_devotional_library(theme, active, last_used_at);

alter table public.scripture_translation_reports enable row level security;
alter table public.scripture_reference_library enable row level security;
alter table public.daily_devotional_library enable row level security;
alter table public.daily_scripture_contents enable row level security;

grant select on public.scripture_translation_reports to authenticated;
grant select on public.daily_scripture_contents to anon, authenticated;

drop policy if exists "Published daily scripture visible to apps"
  on public.daily_scripture_contents;
create policy "Published daily scripture visible to apps"
  on public.daily_scripture_contents
  for select
  to anon, authenticated
  using (true);

drop policy if exists "Translation report visible to platform users"
  on public.scripture_translation_reports;
create policy "Translation report visible to platform users"
  on public.scripture_translation_reports
  for select
  to authenticated
  using (public.has_platform_role(array['super_admin', 'support_agent', 'developer', 'auditor']::text[], auth.uid()));

insert into public.scripture_translation_reports (
  bible_id,
  name,
  abbreviation,
  copyright,
  license_summary,
  commercial_use_status,
  attribution_required,
  attribution_notes,
  raw_metadata
)
values
  (
    'd63894c8d9a7a503-01',
    'Biblia Livre Para Todos',
    'BLT',
    'Released under Creative Commons Attribution-ShareAlike 4.0 Unported License.',
    'Creative Commons Attribution-ShareAlike 4.0 conforme metadados API.Bible.',
    'allowed',
    true,
    'Manter atribuicao e observar ShareAlike para redistribuicao.',
    jsonb_build_object('source', 'api_bible', 'checked_at', now())
  ),
  (
    '41a6caa722a21d88-01',
    'Biblia Sagrada, Nova Versao Transformadora',
    'NVT',
    'Biblia Sagrada, Nova Versao Transformadora © 2016 por Editora Mundo Cristao. Copyright atribuido a Tyndale House Foundation, 2021. Todos os direitos reservados.',
    'A API.Bible expõe copyright com todos os direitos reservados; uso comercial deve ser confirmado com o titular/licenca da conta.',
    'not_confirmed',
    true,
    'Nao marcar como uso comercial permitido sem contrato ou autorizacao explicita.',
    jsonb_build_object('source', 'api_bible', 'checked_at', now())
  ),
  (
    'a47cbe7792801aa8-01',
    'Nova Versao Internacional (Mozambique) 2024',
    'mzNVI',
    'Copyright © 1993, 2000, 2011, 2024 by Biblica, Inc. Used with permission. All rights reserved worldwide.',
    'Todos os direitos reservados; uso comercial nao confirmado pelo endpoint.',
    'not_confirmed',
    true,
    'Confirmar permissao direta antes de uso comercial.',
    jsonb_build_object('source', 'api_bible', 'checked_at', now())
  ),
  (
    '35b94e98b2e3a01a-01',
    'Nova Versao Internacional (Portuguese)',
    'PtNVI',
    'Copyright © 1993, 2000 by Biblica, Inc. All rights reserved worldwide.',
    'Todos os direitos reservados; uso comercial nao confirmado pelo endpoint.',
    'not_confirmed',
    true,
    'Confirmar permissao direta antes de uso comercial.',
    jsonb_build_object('source', 'api_bible', 'checked_at', now())
  ),
  (
    'aee9474b4a88eefb-01',
    'O Livro',
    'OL',
    'Used by permission of Biblica, Inc. All rights reserved worldwide.',
    'Todos os direitos reservados; uso comercial nao confirmado pelo endpoint.',
    'not_confirmed',
    true,
    'Confirmar permissao direta antes de uso comercial.',
    jsonb_build_object('source', 'api_bible', 'checked_at', now())
  ),
  (
    '90799bb5b996fddc-01',
    'Translation for Translators in Brasilian Portuguese',
    'TfTP',
    'Released under a CC-BY-SA 4.0 license.',
    'Creative Commons Attribution-ShareAlike 4.0 conforme metadados API.Bible.',
    'allowed',
    true,
    'Manter atribuicao e observar ShareAlike para redistribuicao.',
    jsonb_build_object('source', 'api_bible', 'checked_at', now())
  )
on conflict (bible_id) do update
set
  name = excluded.name,
  abbreviation = excluded.abbreviation,
  copyright = excluded.copyright,
  license_summary = excluded.license_summary,
  commercial_use_status = excluded.commercial_use_status,
  attribution_required = excluded.attribution_required,
  attribution_notes = excluded.attribution_notes,
  last_checked_at = now(),
  raw_metadata = excluded.raw_metadata;

insert into public.scripture_reference_library (
  reference_key,
  human_reference,
  book_id,
  chapter,
  verse_start,
  verse_end,
  theme,
  weight,
  fallback_text,
  fallback_translation,
  fallback_copyright
)
values
  ('JHN.3.16', 'Joao 3:16', 'JHN', 3, 16, null, 'salvacao', 20, 'Pois Deus amou tanto o mundo, que deu o seu unico Filho, para que todos os que acreditam nele nao morram, mas tenham a vida eterna.', 'BLT', 'Creative Commons Attribution-ShareAlike 4.0'),
  ('MAT.5.14', 'Mateus 5:14', 'MAT', 5, 14, null, 'testemunho', 18, 'Voces sao a luz do mundo. Nao se pode esconder uma cidade construida sobre uma colina.', 'BLT', 'Creative Commons Attribution-ShareAlike 4.0'),
  ('ROM.12.12', 'Romanos 12:12', 'ROM', 12, 12, null, 'esperanca', 18, 'Que a sua esperanca sempre os mantenha bem dispostos. Suportem com paciencia os sofrimentos e sempre orem.', 'BLT', 'Creative Commons Attribution-ShareAlike 4.0'),
  ('PHP.4.6', 'Filipenses 4:6', 'PHP', 4, 6, null, 'oracao', 18, 'Nao se preocupem com nada, mas levem tudo a Deus em suas oracoes, fazendo os seus pedidos a ele e agradecendo.', 'BLT', 'Creative Commons Attribution-ShareAlike 4.0'),
  ('PSA.121.2', 'Salmos 121:2', 'PSA', 121, 2, null, 'proteccao', 15, 'O meu socorro vem do Senhor, que fez os ceus e a terra.', 'BLT', 'Creative Commons Attribution-ShareAlike 4.0'),
  ('ISA.40.31', 'Isaias 40:31', 'ISA', 40, 31, null, 'renovo', 15, 'Os que esperam no Senhor renovam as suas forcas.', 'BLT', 'Creative Commons Attribution-ShareAlike 4.0'),
  ('JOS.1.9', 'Josue 1:9', 'JOS', 1, 9, null, 'coragem', 15, 'Seja forte e corajoso; o Senhor esta contigo onde quer que fores.', 'BLT', 'Creative Commons Attribution-ShareAlike 4.0')
on conflict (reference_key) do update
set
  human_reference = excluded.human_reference,
  book_id = excluded.book_id,
  chapter = excluded.chapter,
  verse_start = excluded.verse_start,
  verse_end = excluded.verse_end,
  theme = excluded.theme,
  weight = excluded.weight,
  active = true,
  fallback_text = excluded.fallback_text,
  fallback_translation = excluded.fallback_translation,
  fallback_copyright = excluded.fallback_copyright;

insert into public.daily_devotional_library (
  theme,
  title,
  summary,
  reflection,
  practical_application,
  prayer
)
values
  ('salvacao', 'Amor que nos encontra', 'Deus toma a iniciativa e chama a comunidade a responder com fe.', 'O evangelho comeca no amor de Deus, nao na capacidade humana de merecer alguma coisa. Quando a igreja lembra isso, deixa de viver por medo e passa a servir por gratidao.', 'Hoje, identifica uma pessoa que precisa ouvir uma palavra simples de esperanca e aproxima-te com gentileza.', 'Senhor, ajuda-nos a viver a partir do teu amor e a repartir essa graca com coragem.'),
  ('testemunho', 'Luz visivel', 'A fe amadurece quando ilumina a vida diaria.', 'Jesus chama a sua igreja para uma presenca visivel, humilde e pratica. Ser luz nao e chamar atencao para si, mas apontar para Deus com obras, palavras e cuidado.', 'Escolhe uma acao concreta de servico hoje: visitar, ligar, encorajar ou ajudar alguem.', 'Deus, faz da nossa comunhao uma luz limpa, util e cheia de compaixao.'),
  ('esperanca', 'Esperanca perseverante', 'Esperanca, paciencia e oracao mantem a igreja firme.', 'A vida espiritual nao ignora dificuldades. Ela aprende a atravessa-las com uma esperanca que ora, espera e permanece fiel mesmo quando a resposta ainda nao chegou.', 'Antes de resolver tudo sozinho, separa alguns minutos para orar e escrever um passo obediente para hoje.', 'Pai, sustenta-nos na tribulacao e ensina-nos a permanecer em oracao.'),
  ('oracao', 'Ansiedade entregue', 'A oracao transforma preocupacao em dependencia.', 'A ansiedade tenta ocupar o lugar da confianca. A oracao devolve o coracao ao centro certo: Deus ouve, cuida e acompanha cada pedido feito com gratidao.', 'Transforma uma preocupacao especifica em pedido de oracao e partilha com alguem maduro na fe.', 'Senhor, recebe as nossas preocupacoes e guarda a nossa mente em paz.'),
  ('proteccao', 'Socorro que vem do Senhor', 'O cuidado de Deus acompanha a caminhada da igreja.', 'Nem sempre controlamos o terreno que pisamos, mas podemos lembrar de onde vem o socorro. A comunidade caminha melhor quando reconhece a dependencia de Deus.', 'Ora por proteccao para a tua familia, igreja e cidade, e oferece apoio a alguem que se sente inseguro.', 'Guarda-nos, Senhor, e torna-nos instrumentos de cuidado para outros.'),
  ('renovo', 'Forcas renovadas', 'Esperar em Deus tambem e receber novo folego.', 'O cansaco nao e sinal de fracasso. Muitas vezes e convite para voltar a fonte. Deus renova pessoas e comunidades que aprendem a esperar nele com fidelidade.', 'Revê a tua agenda e remove uma carga desnecessaria para criar espaco de descanso e obediencia.', 'Renova as nossas forcas, Senhor, e guia-nos sem pressa nem orgulho.'),
  ('coragem', 'Coragem acompanhada', 'A obediencia fica possivel quando lembramos que Deus esta presente.', 'Coragem biblica nao e ausencia de medo. E a decisao de obedecer porque Deus permanece junto no caminho, nas decisoes e nos desafios da missao.', 'Da um passo que tens adiado: pedir perdao, iniciar conversa, servir ou concluir uma tarefa importante.', 'Senhor, da-nos coragem obediente e consciencia da tua presenca.')
on conflict do nothing;
