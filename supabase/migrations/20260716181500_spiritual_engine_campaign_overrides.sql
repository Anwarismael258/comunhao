alter table public.daily_devotional_library
  add column if not exists meditation_question text not null default '',
  add column if not exists reading_plan text not null default '';

alter table public.daily_scripture_contents
  add column if not exists meditation_question text not null default '',
  add column if not exists reading_plan text not null default '',
  add column if not exists church_id uuid references public.churches(id) on delete cascade,
  add column if not exists spiritual_campaign_id uuid,
  drop constraint if exists daily_scripture_contents_source_status_check,
  add constraint daily_scripture_contents_source_status_check
    check (source_status in ('api_bible', 'cache_today', 'cache_latest', 'local_fallback', 'campaign_override'));

create table if not exists public.spiritual_campaign_contents (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  campaign_name text not null,
  campaign_day integer,
  content_date date,
  starts_on date not null,
  ends_on date not null,
  title text not null,
  theme text not null,
  reference_label text not null,
  scripture_text text not null,
  bible_name text,
  bible_abbreviation text,
  copyright text,
  devotional_summary text not null,
  devotional_reflection text not null,
  practical_application text not null,
  prayer text not null,
  meditation_question text not null,
  reading_plan text,
  active boolean not null default true,
  priority integer not null default 100,
  created_at timestamptz not null default now(),
  check (ends_on >= starts_on)
);

create index if not exists idx_spiritual_campaign_contents_lookup
  on public.spiritual_campaign_contents(church_id, active, content_date, starts_on, ends_on, priority desc);

alter table public.spiritual_campaign_contents enable row level security;

grant select on public.spiritual_campaign_contents to authenticated;

drop policy if exists "Church members can read own spiritual campaigns"
  on public.spiritual_campaign_contents;
create policy "Church members can read own spiritual campaigns"
  on public.spiritual_campaign_contents
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.memberships m
      where m.church_id = spiritual_campaign_contents.church_id
        and m.profile_id = auth.uid()
        and m.status = 'active'
    )
    or public.has_platform_role(array['super_admin', 'support_agent', 'developer', 'auditor']::text[], auth.uid())
  );

update public.daily_devotional_library
set
  meditation_question = case theme
    when 'salvacao' then 'Como posso responder hoje ao amor de Deus de forma visivel?'
    when 'testemunho' then 'Que area da minha vida precisa refletir mais luz e integridade?'
    when 'esperanca' then 'Onde preciso perseverar em vez de desistir cedo demais?'
    when 'oracao' then 'Que preocupacao concreta devo entregar a Deus hoje?'
    when 'proteccao' then 'Quem precisa sentir cuidado e seguranca atraves de mim?'
    when 'renovo' then 'Que peso preciso entregar para voltar a respirar com Deus?'
    when 'coragem' then 'Qual passo obediente estou a adiar por medo?'
    else meditation_question
  end,
  reading_plan = case theme
    when 'salvacao' then 'Joao 3; Romanos 5; Efesios 2'
    when 'testemunho' then 'Mateus 5; Filipenses 2; 1 Pedro 2'
    when 'esperanca' then 'Romanos 12; Salmos 27; Tiago 1'
    when 'oracao' then 'Filipenses 4; Mateus 6; Salmos 91'
    when 'proteccao' then 'Salmos 121; Salmos 46; Joao 10'
    when 'renovo' then 'Isaias 40; Mateus 11; Salmos 23'
    when 'coragem' then 'Josue 1; Efesios 6; Salmos 31'
    else reading_plan
  end
where meditation_question = '' or reading_plan = '';

update public.daily_scripture_contents d
set
  meditation_question = lib.meditation_question,
  reading_plan = lib.reading_plan
from public.daily_devotional_library lib
where lib.theme = d.theme
  and lib.active = true
  and (d.meditation_question = '' or d.reading_plan = '');

insert into public.spiritual_campaign_contents (
  church_id,
  campaign_name,
  campaign_day,
  starts_on,
  ends_on,
  title,
  theme,
  reference_label,
  scripture_text,
  bible_name,
  bible_abbreviation,
  copyright,
  devotional_summary,
  devotional_reflection,
  practical_application,
  prayer,
  meditation_question,
  reading_plan,
  active,
  priority
)
select
  c.id,
  '21 Dias de Oracao',
  1,
  current_date,
  current_date + 20,
  'Dia 1 - Entrega o caminho',
  'oracao',
  'Salmos 37:5',
  'Entrega o teu caminho ao Senhor; confia nele, e ele agira.',
  'Conteudo pastoral da Igreja Vida Nova',
  'VIDA',
  'Conteudo devocional preparado pela Igreja Vida Nova para campanha local.',
  'A campanha da igreja chama cada membro a comecar o dia entregando decisoes, familia e servico a Deus.',
  'Deus continua no controlo mesmo quando nao entendemos o caminho. Entregar nao e desistir; e confiar que a obediencia de hoje abre espaco para a direcao de Deus.',
  'Hoje faca uma oracao antes de tomar uma decisao importante e envie uma mensagem de apoio a alguem que precisa de encorajamento.',
  'Senhor, guia os meus passos e fortalece a minha confianca em Ti. Ensina-nos a caminhar como igreja que ora antes de agir.',
  'Que decisao eu preciso entregar a Deus antes de tentar controlar tudo sozinho?',
  'Salmos 37; Proverbios 3; Filipenses 4',
  true,
  200
from public.churches c
where c.slug = 'vida-nova'
on conflict do nothing;
