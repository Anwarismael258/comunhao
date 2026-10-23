alter table public.church_join_requests
  add column if not exists request_kind text not null default 'ministry';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'church_join_requests_kind_check'
  ) then
    alter table public.church_join_requests
      add constraint church_join_requests_kind_check
      check (request_kind in (
        'ministry',
        'group',
        'volunteer',
        'baptism',
        'transfer',
        'other'
      ));
  end if;
end $$;

alter table public.church_join_requests
  drop constraint if exists church_join_requests_church_id_profile_id_key;

create unique index if not exists idx_church_join_requests_church_profile_kind
  on public.church_join_requests(church_id, profile_id, request_kind);

create or replace function public.create_church_join_request(
  p_church_id uuid,
  p_request_kind text default 'ministry',
  p_full_name text default null,
  p_phone text default null,
  p_birth_date date default null,
  p_gender text default null,
  p_neighborhood text default null,
  p_previous_church text default null,
  p_reason text default null,
  p_ministry_interest text default null,
  p_observation text default null,
  p_consent_data_processing boolean default false
)
returns public.church_join_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  request_row public.church_join_requests%rowtype;
  normalized_kind text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if p_consent_data_processing is not true then
    raise exception 'Consent is required.';
  end if;

  normalized_kind := lower(trim(coalesce(p_request_kind, 'ministry')));
  if normalized_kind not in (
    'ministry',
    'group',
    'volunteer',
    'baptism',
    'transfer',
    'other'
  ) then
    normalized_kind := 'other';
  end if;

  perform public.ensure_member_wallet(auth.uid(), coalesce(p_phone, ''));

  insert into public.church_join_requests (
    church_id,
    profile_id,
    request_kind,
    full_name,
    phone,
    birth_date,
    gender,
    neighborhood,
    previous_church,
    reason,
    ministry_interest,
    observation,
    consent_data_processing,
    message,
    status
  )
  values (
    p_church_id,
    auth.uid(),
    normalized_kind,
    trim(coalesce(p_full_name, '')),
    trim(coalesce(p_phone, '')),
    p_birth_date,
    nullif(trim(coalesce(p_gender, '')), ''),
    nullif(trim(coalesce(p_neighborhood, '')), ''),
    nullif(trim(coalesce(p_previous_church, '')), ''),
    nullif(trim(coalesce(p_reason, '')), ''),
    nullif(trim(coalesce(p_ministry_interest, '')), ''),
    nullif(trim(coalesce(p_observation, '')), ''),
    p_consent_data_processing,
    nullif(trim(coalesce(p_reason, '')), ''),
    'pending'
  )
  on conflict (church_id, profile_id, request_kind) do update
  set
    full_name = excluded.full_name,
    phone = excluded.phone,
    birth_date = excluded.birth_date,
    gender = excluded.gender,
    neighborhood = excluded.neighborhood,
    previous_church = excluded.previous_church,
    reason = excluded.reason,
    ministry_interest = excluded.ministry_interest,
    observation = excluded.observation,
    consent_data_processing = excluded.consent_data_processing,
    status = case
      when public.church_join_requests.status in ('approved', 'under_review', 'more_information_required') then public.church_join_requests.status
      else 'pending'
    end,
    member_response = null,
    updated_at = now()
  where public.church_join_requests.status not in ('approved')
  returning * into request_row;

  if request_row.id is null then
    select * into request_row
    from public.church_join_requests
    where church_id = p_church_id
      and profile_id = auth.uid()
      and request_kind = normalized_kind;
  end if;

  insert into public.church_request_timeline (
    church_id,
    request_table,
    request_id,
    actor_profile_id,
    action,
    public_message
  )
  values (
    p_church_id,
    'church_join_requests',
    request_row.id,
    auth.uid(),
    'created_or_updated',
    'Pedido enviado pelo membro.'
  );

  return request_row;
end;
$$;

do $$
declare
  vida_id uuid;
  member_id uuid;
begin
  select c.id
  into vida_id
  from public.churches c
  where c.name = 'Igreja Vida Nova'
     or c.phone in ('877688695', '+258877688695')
     or regexp_replace(coalesce(c.phone, ''), '\D', '', 'g') in ('877688695', '258877688695')
  order by c.created_at
  limit 1;

  member_id := public.profile_id_by_phone('827688695');

  if vida_id is null or member_id is null then
    return;
  end if;

  delete from public.church_join_requests
  where church_id = vida_id
    and profile_id = member_id
    and request_kind in ('ministry', 'group', 'volunteer', 'baptism', 'transfer');

  insert into public.church_join_requests (
    church_id,
    profile_id,
    request_kind,
    full_name,
    phone,
    neighborhood,
    previous_church,
    reason,
    ministry_interest,
    observation,
    consent_data_processing,
    status,
    is_demo,
    created_at,
    updated_at
  )
  values
    (
      vida_id,
      member_id,
      'ministry',
      'Membro Vida Nova',
      '+258827688695',
      'Maputo',
      null,
      'Desejo servir no ministerio de louvor e participar nos ensaios semanais.',
      'Louvor - vocal e apoio no ensaio',
      'Disponivel aos sabados a tarde e domingos antes do culto.',
      true,
      'pending',
      false,
      now() - interval '50 minutes',
      now() - interval '50 minutes'
    ),
    (
      vida_id,
      member_id,
      'group',
      'Membro Vida Nova',
      '+258827688695',
      'Maputo',
      null,
      'Quero integrar uma celula perto de casa para crescer em comunhao durante a semana.',
      'Celulas - Grupo de Oracao ou jovens adultos',
      'Preferencia por encontros depois das 18h.',
      true,
      'pending',
      false,
      now() - interval '45 minutes',
      now() - interval '45 minutes'
    ),
    (
      vida_id,
      member_id,
      'volunteer',
      'Membro Vida Nova',
      '+258827688695',
      'Maputo',
      null,
      'Quero servir como voluntario na recepcao e apoio aos visitantes.',
      'Recepcao - apoio em cultos e eventos',
      'Pode ajudar dois domingos por mes.',
      true,
      'pending',
      false,
      now() - interval '40 minutes',
      now() - interval '40 minutes'
    ),
    (
      vida_id,
      member_id,
      'baptism',
      'Membro Vida Nova',
      '+258827688695',
      'Maputo',
      null,
      'Desejo participar na preparacao para batismo e receber orientacao pastoral.',
      'Batismo - classe de preparacao',
      'Ainda nao foi batizado e deseja entender os proximos passos.',
      true,
      'pending',
      false,
      now() - interval '35 minutes',
      now() - interval '35 minutes'
    ),
    (
      vida_id,
      member_id,
      'transfer',
      'Membro Vida Nova',
      '+258827688695',
      'Maputo',
      'Igreja Vida Nova - sede Maputo',
      'Solicito transferencia para a congregacao Vida Nova Matola, mantendo acompanhamento do mesmo pastor.',
      'Transferencia - Vida Nova Matola',
      'Mudanca de residencia para Matola; deseja continuar ligado a mesma cobertura pastoral.',
      true,
      'pending',
      false,
      now() - interval '30 minutes',
      now() - interval '30 minutes'
    );

  delete from public.pastoral_requests
  where church_id = vida_id
    and profile_id = member_id
    and title in (
      'Pedido de oracao familiar',
      'Aconselhamento sobre ansiedade',
      'Pedido de visita pastoral',
      'Apoio social temporario',
      'Orientacao para batismo',
      'Preparacao para casamento',
      'Apoio por funeral na familia'
    );

  insert into public.pastoral_requests (
    church_id,
    profile_id,
    request_area,
    category,
    title,
    subject,
    message,
    urgency,
    confidentiality,
    privacy_level,
    preferred_contact,
    contact_availability,
    consent_forwarding,
    status,
    is_demo,
    created_at,
    updated_at
  )
  values
    (vida_id, member_id, 'pastoral', 'prayer', 'Pedido de oracao familiar', 'Pedido de oracao familiar', 'Peco oracao pela saude da minha mae e pela paz dentro da nossa casa.', 'normal', 'pastoral_team', 'pastoral_team', 'phone', 'Hoje depois das 18h', true, 'new', false, now() - interval '28 minutes', now() - interval '28 minutes'),
    (vida_id, member_id, 'pastoral', 'counseling', 'Aconselhamento sobre ansiedade', 'Aconselhamento sobre ansiedade', 'Tenho estado ansioso com trabalho e familia. Gostaria de conversar com a pastora Sara.', 'high', 'pastor_only', 'pastor_only', 'phone', 'Amanha a tarde', false, 'new', false, now() - interval '26 minutes', now() - interval '26 minutes'),
    (vida_id, member_id, 'pastoral', 'visit', 'Pedido de visita pastoral', 'Pedido de visita pastoral', 'Gostaria de receber uma visita pastoral em casa para oracao e acompanhamento.', 'normal', 'assigned_leader', 'assigned_leader', 'phone', 'Sabado de manha', true, 'new', false, now() - interval '24 minutes', now() - interval '24 minutes'),
    (vida_id, member_id, 'pastoral', 'social_support', 'Apoio social temporario', 'Apoio social temporario', 'A familia precisa de apoio alimentar temporario ate o fim do mes.', 'urgent', 'pastor_only', 'pastor_only', 'phone', 'Manha', true, 'new', false, now() - interval '22 minutes', now() - interval '22 minutes'),
    (vida_id, member_id, 'pastoral', 'baptism', 'Orientacao para batismo', 'Orientacao para batismo', 'Quero saber datas, preparacao e requisitos para o proximo batismo.', 'normal', 'pastoral_team', 'pastoral_team', 'phone', 'Domingo apos o culto', true, 'new', false, now() - interval '20 minutes', now() - interval '20 minutes'),
    (vida_id, member_id, 'pastoral', 'marriage', 'Preparacao para casamento', 'Preparacao para casamento', 'Gostariamos de conversar sobre aconselhamento pre-matrimonial e agenda de casamento.', 'normal', 'pastor_only', 'pastor_only', 'phone', 'Durante a semana a noite', false, 'new', false, now() - interval '18 minutes', now() - interval '18 minutes'),
    (vida_id, member_id, 'pastoral', 'funeral', 'Apoio por funeral na familia', 'Apoio por funeral na familia', 'Perdemos um familiar e precisamos de apoio pastoral para a familia e orientacao sobre o funeral.', 'urgent', 'pastor_only', 'pastor_only', 'phone', 'Assim que possivel', true, 'new', false, now() - interval '16 minutes', now() - interval '16 minutes');

  delete from public.prayer_requests
  where church_id = vida_id
    and profile_id = member_id
    and title = 'Oracao pela familia e direcao';

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
  values (
    vida_id,
    member_id,
    'Oracao pela familia e direcao',
    'Peco que a pastora e a equipa intercedam pela minha familia, pela saude da minha mae e por direcao nas proximas decisoes.',
    true,
    'private',
    false,
    true,
    'new',
    now() - interval '10 minutes'
  );
end $$;

notify pgrst, 'reload schema';
