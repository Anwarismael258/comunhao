create or replace function public.notify_administrative_request_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.notify_church_managers(
    new.church_id,
    'Novo pedido administrativo',
    coalesce(new.subject, 'Pedido administrativo recebido.'),
    'administrative_request',
    new.profile_id,
    'normal',
    'administrative_requests',
    new.id,
    '/requests/admin/' || new.id::text,
    jsonb_build_object('status', new.status, 'request_type', new.request_type)
  );
  return new;
end;
$$;

drop trigger if exists notify_administrative_request_created on public.administrative_requests;
create trigger notify_administrative_request_created
  after insert on public.administrative_requests
  for each row execute function public.notify_administrative_request_created();

do $$
declare
  vida_church_id uuid;
  sara_profile_id uuid;
  member_profile_id uuid;
begin
  select id into vida_church_id
  from public.churches
  where slug = 'vida-nova'
     or phone in ('+258877688695', '877688695')
  order by created_at
  limit 1;

  if vida_church_id is null then
    return;
  end if;

  select id into sara_profile_id
  from public.profiles
  where phone in ('+258877688695', '877688695')
  limit 1;

  select id into member_profile_id
  from public.profiles
  where phone in ('+258827688695', '827688695')
  limit 1;

  delete from public.church_join_requests
  where church_id = vida_church_id
    and is_demo = true;

  delete from public.pastoral_requests
  where church_id = vida_church_id
    and is_demo = true;

  delete from public.administrative_requests
  where church_id = vida_church_id
    and is_demo = true;

  insert into public.church_join_requests (
    church_id,
    profile_id,
    full_name,
    phone,
    neighborhood,
    previous_church,
    reason,
    ministry_interest,
    consent_data_processing,
    status,
    is_demo
  )
  values
    (
      vida_church_id,
      coalesce(member_profile_id, sara_profile_id),
      'Marta Zita',
      '+258821110001',
      'Malhangalene',
      'Igreja do Bairro',
      'Quero congregar com a minha familia na Vida Nova.',
      'Louvor',
      true,
      'pending',
      true
    ),
    (
      vida_church_id,
      coalesce(member_profile_id, sara_profile_id),
      'Carlos Mate',
      '+258821110002',
      'Polana',
      null,
      'Fui convidado por um membro e desejo conhecer melhor a igreja.',
      'Jovens',
      true,
      'under_review',
      true
    )
  on conflict (church_id, profile_id) do nothing;

  insert into public.pastoral_requests (
    church_id,
    profile_id,
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
    is_demo
  )
  values
    (vida_church_id, member_profile_id, 'prayer', 'Pedido de oracao pela familia', 'Pedido de oracao pela familia', 'Solicito oracao pela saude da minha mae.', 'normal', 'pastoral_team', 'pastoral_team', 'phone', 'Noite', true, 'new', true),
    (vida_church_id, member_profile_id, 'counseling', 'Aconselhamento confidencial', 'Aconselhamento confidencial', 'Preciso conversar com a pastora sobre uma situacao familiar sensivel.', 'high', 'pastor_only', 'pastor_only', 'phone', 'Tarde', false, 'new', true),
    (vida_church_id, member_profile_id, 'visit', 'Pedido de visita', 'Pedido de visita', 'Gostaria de receber uma visita pastoral esta semana.', 'normal', 'assigned_leader', 'assigned_leader', 'phone', 'Sabado', true, 'assigned', true),
    (vida_church_id, member_profile_id, 'social_support', 'Apoio social', 'Apoio social', 'A familia precisa de apoio alimentar temporario.', 'urgent', 'pastor_only', 'pastor_only', 'phone', 'Manha', true, 'triaged', true);

  insert into public.administrative_requests (
    church_id,
    profile_id,
    request_type,
    subject,
    description,
    status,
    is_demo
  )
  values (
    vida_church_id,
    member_profile_id,
    'member_statement',
    'Declaracao de membro',
    'Preciso de uma declaracao de membro para entregar no servico.',
    'new',
    true
  );
end $$;
