alter table public.profiles
  add column if not exists avatar_storage_path text;

create table if not exists public.legal_documents (
  id uuid primary key default gen_random_uuid(),
  document_key text not null,
  title text not null,
  version text not null,
  summary text,
  body text not null,
  effective_at timestamptz not null default now(),
  published boolean not null default true,
  created_at timestamptz not null default now(),
  unique (document_key, version)
);

create table if not exists public.legal_acceptances (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  document_key text not null,
  version text not null,
  accepted_at timestamptz not null default now(),
  unique (profile_id, document_key, version)
);

alter table public.legal_documents enable row level security;
alter table public.legal_acceptances enable row level security;

grant select on public.legal_documents to anon, authenticated;
grant select, insert on public.legal_acceptances to authenticated;

drop policy if exists "Anyone can read published legal documents"
  on public.legal_documents;
create policy "Anyone can read published legal documents"
  on public.legal_documents
  for select
  to anon, authenticated
  using (published = true);

drop policy if exists "Users can read own legal acceptances"
  on public.legal_acceptances;
create policy "Users can read own legal acceptances"
  on public.legal_acceptances
  for select
  to authenticated
  using (profile_id = auth.uid());

drop policy if exists "Users can accept legal documents"
  on public.legal_acceptances;
create policy "Users can accept legal documents"
  on public.legal_acceptances
  for insert
  to authenticated
  with check (profile_id = auth.uid());

insert into public.legal_documents (
  document_key,
  title,
  version,
  summary,
  body,
  effective_at,
  published
)
values
  (
    'terms',
    'Termos de Uso',
    '2026.07.16',
    'Regras principais de acesso, contas, contribuicoes, conteudos e responsabilidades dentro da plataforma Comunhao.',
    '1. Aceitacao dos termos
Ao criar conta, entrar ou usar a plataforma Comunhao, o utilizador confirma que leu e concorda com estes Termos de Uso.

2. Finalidade da plataforma
A Comunhao apoia igrejas, pastores, lideres e membros na gestao de comunidades, membros, eventos, campanhas, publicacoes, pedidos pastorais, contribuicoes, carteiras e relatorios.

3. Conta do utilizador
Cada utilizador deve usar dados verdadeiros, manter a palavra-passe protegida e comunicar qualquer uso indevido. O numero de telefone pode ser usado para autenticacao, notificacoes e identificacao operacional.

4. Igrejas, pastores e administradores
Pastores, lideres e administradores sao responsaveis por validar membros, publicar conteudos, gerir pedidos, acompanhar contribuicoes, aprovar operacoes e manter os dados da igreja corretos.

5. Contribuicoes e pagamentos
Contribuicoes, ofertas, dizimos, campanhas e subscricoes devem ser registados com valores corretos. Pagamentos via M-Pesa, E-Mola, cartao ou outros provedores dependem de integracoes ativas e confirmacoes do provedor.

6. Conteudos e comunicacoes
Mensagens, pregacoes, estudos, devocionais, avisos, videos, audios e documentos devem respeitar a lei, a dignidade das pessoas e a finalidade pastoral da igreja.

7. Uso aceitavel
E proibido usar a plataforma para fraude, abuso, acesso indevido, recolha nao autorizada de dados, conteudo ofensivo, spam ou qualquer atividade ilegal.

8. Disponibilidade
A plataforma pode passar por manutencoes, falhas temporarias de rede, indisponibilidade de provedores externos ou atualizacoes tecnicas.

9. Limitacao de responsabilidade
A Comunhao fornece ferramentas digitais. A responsabilidade por decisoes pastorais, financeiras e administrativas tomadas dentro da igreja permanece com os responsaveis autorizados.

10. Alteracoes
Estes termos podem ser atualizados. Quando houver uma nova versao relevante, o utilizador podera ser solicitado a ler e aceitar novamente.',
    now(),
    true
  ),
  (
    'privacy',
    'Politica de Privacidade',
    '2026.07.16',
    'Explica quais dados sao tratados, porque sao tratados e como cada utilizador pode proteger a sua informacao.',
    '1. Dados recolhidos
A Comunhao pode tratar nome, telefone, igreja, funcao, estado de membro, data de nascimento, foto de perfil, pedidos pastorais, presencas, contribuicoes, campanhas, publicacoes lidas e dados tecnicos de acesso.

2. Finalidade do tratamento
Os dados sao usados para autenticar contas, gerir membros, organizar cultos e eventos, processar contribuicoes, apresentar relatorios, enviar notificacoes internas e apoiar a administracao pastoral.

3. Foto de perfil
O membro pode carregar uma foto de perfil a partir da galeria. A foto fica associada ao perfil e pode ser vista por pessoas autorizadas dentro da igreja e da plataforma conforme as permissoes.

4. Pagamentos
Dados de pagamentos podem incluir metodo, valor, referencia, estado e comprovativos. Dados sensiveis de cartao nao devem ser guardados diretamente na Comunhao; devem ser processados por provedores certificados.

5. Partilha de dados
Dados podem ser vistos por membros, lideres, pastores, administradores da igreja ou super administradores somente conforme a funcao e a necessidade operacional.

6. Provedores externos
SMS, email, push, WhatsApp, M-Pesa, E-Mola, cartao, armazenamento e monitorizacao podem depender de provedores externos. Cada provedor pode ter politicas proprias.

7. Segurança
A plataforma usa autenticacao, permissoes, RLS, auditoria e separacao por igreja. Nenhum sistema e totalmente imune a risco, por isso as credenciais devem ser protegidas.

8. Retencao
Os dados podem ser mantidos enquanto a conta, a igreja, obrigacoes legais, auditoria financeira ou necessidades pastorais existirem.

9. Direitos do utilizador
O utilizador pode solicitar correcao, atualizacao ou remocao de dados, respeitando requisitos legais, financeiros e administrativos.

10. Contacto
Duvidas sobre privacidade devem ser encaminhadas ao responsavel da igreja ou ao suporte autorizado da plataforma Comunhao.',
    now(),
    true
  )
on conflict (document_key, version) do update
set
  title = excluded.title,
  summary = excluded.summary,
  body = excluded.body,
  effective_at = excluded.effective_at,
  published = excluded.published;

create or replace function public.get_current_legal_documents()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'document_key', document_key,
        'title', title,
        'version', version,
        'summary', summary,
        'body', body,
        'effective_at', effective_at
      )
      order by document_key
    ),
    '[]'::jsonb
  )
  from (
    select distinct on (document_key)
      document_key,
      title,
      version,
      summary,
      body,
      effective_at
    from public.legal_documents
    where published = true
    order by document_key, effective_at desc, created_at desc
  ) latest;
$$;

create or replace function public.accept_legal_document(
  p_document_key text,
  p_version text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  document_exists boolean;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  select exists (
    select 1
    from public.legal_documents
    where document_key = p_document_key
      and version = p_version
      and published = true
  )
  into document_exists;

  if not document_exists then
    raise exception 'legal_document_not_found';
  end if;

  insert into public.legal_acceptances (profile_id, document_key, version)
  values (auth.uid(), p_document_key, p_version)
  on conflict (profile_id, document_key, version) do update
  set accepted_at = now();

  return jsonb_build_object(
    'document_key', p_document_key,
    'version', p_version,
    'accepted', true,
    'accepted_at', now()
  );
end;
$$;

create or replace function public.update_my_profile_avatar(
  p_avatar_storage_path text,
  p_avatar_url text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_profile public.profiles;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  update public.profiles
  set
    avatar_storage_path = nullif(trim(p_avatar_storage_path), ''),
    avatar_url = nullif(trim(coalesce(p_avatar_url, '')), '')
  where id = auth.uid()
  returning *
  into updated_profile;

  if updated_profile.id is null then
    raise exception 'profile_not_found';
  end if;

  return to_jsonb(updated_profile);
end;
$$;

grant execute on function public.get_current_legal_documents() to anon, authenticated;
grant execute on function public.accept_legal_document(text, text) to authenticated;
grant execute on function public.update_my_profile_avatar(text, text) to authenticated;

drop policy if exists "Members can upload own profile photo"
  on storage.objects;
create policy "Members can upload own profile photo"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'profile-media'
    and split_part(storage.objects.name, '/', 2) = 'profiles'
    and split_part(storage.objects.name, '/', 3) = auth.uid()::text
    and exists (
      select 1
      from public.memberships m
      where m.profile_id = auth.uid()
        and m.status = 'active'
        and split_part(storage.objects.name, '/', 1) = m.church_id::text
    )
  );

drop policy if exists "Members can update own profile photo"
  on storage.objects;
create policy "Members can update own profile photo"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'profile-media'
    and split_part(storage.objects.name, '/', 2) = 'profiles'
    and split_part(storage.objects.name, '/', 3) = auth.uid()::text
  )
  with check (
    bucket_id = 'profile-media'
    and split_part(storage.objects.name, '/', 2) = 'profiles'
    and split_part(storage.objects.name, '/', 3) = auth.uid()::text
  );

drop policy if exists "Members can delete own profile photo"
  on storage.objects;
create policy "Members can delete own profile photo"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'profile-media'
    and split_part(storage.objects.name, '/', 2) = 'profiles'
    and split_part(storage.objects.name, '/', 3) = auth.uid()::text
  );
