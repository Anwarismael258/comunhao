do $$
declare
  vida_id uuid;
  member_id uuid;
  sara_id uuid;
  request_record record;
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
  sara_id := public.profile_id_by_phone('877688695');

  if vida_id is null or member_id is null or sara_id is null then
    return;
  end if;

  update public.church_join_requests
  set
    status = 'under_review',
    reviewed_by = sara_id,
    reviewed_at = now(),
    review_notes = case request_kind
      when 'ministry' then 'Recebemos o teu pedido para o ministerio de louvor. A lideranca vai falar contigo no proximo culto e orientar a integracao nos ensaios.'
      when 'group' then 'Recebemos o teu pedido para entrar numa celula. Vamos indicar uma celula proxima da tua zona e confirmar o horario contigo.'
      when 'volunteer' then 'Recebemos a tua disponibilidade para servir como voluntario. A equipa de recepcao vai contactar-te para alinhar escala e orientacoes.'
      when 'baptism' then 'Recebemos o teu interesse no batismo. Vamos incluir o teu nome na proxima classe de preparacao e enviar as datas.'
      when 'transfer' then 'Recebemos o pedido de transferencia para a congregacao Vida Nova Matola. A pastora Sara vai validar a congregacao e orientar a transicao.'
      else 'Recebemos o teu pedido. A igreja vai acompanhar e responder com os proximos passos.'
    end,
    internal_notes = case request_kind
      when 'transfer' then 'Confirmar residencia atual, congregacao pretendida e responsavel local antes de aprovar.'
      else 'Resposta inicial criada para acompanhamento real do piloto Vida Nova.'
    end,
    updated_at = now()
  where church_id = vida_id
    and profile_id = member_id
    and request_kind in ('ministry', 'group', 'volunteer', 'baptism', 'transfer');

  delete from public.church_request_timeline
  where church_id = vida_id
    and actor_profile_id = sara_id
    and action = 'pastor_response_seed'
    and request_table = 'church_join_requests';

  for request_record in
    select *
    from public.church_join_requests
    where church_id = vida_id
      and profile_id = member_id
      and request_kind in ('ministry', 'group', 'volunteer', 'baptism', 'transfer')
  loop
    insert into public.church_request_timeline (
      church_id,
      request_table,
      request_id,
      actor_profile_id,
      action,
      public_message,
      internal_note
    )
    values (
      vida_id,
      'church_join_requests',
      request_record.id,
      sara_id,
      'pastor_response_seed',
      request_record.review_notes,
      request_record.internal_notes
    );

    perform public.create_internal_notification(
      member_id,
      'Resposta da Igreja Vida Nova',
      request_record.review_notes,
      'church_request_answered',
      vida_id,
      sara_id,
      'normal',
      'church_join_requests',
      request_record.id,
      'member_requests',
      jsonb_build_object('request_kind', request_record.request_kind)
    );
  end loop;

  delete from public.pastoral_request_responses
  using public.pastoral_requests request
  where pastoral_request_responses.pastoral_request_id = request.id
    and request.church_id = vida_id
    and request.profile_id = member_id
    and request.title in (
      'Pedido de oracao familiar',
      'Aconselhamento sobre ansiedade',
      'Pedido de visita pastoral',
      'Apoio social temporario',
      'Orientacao para batismo',
      'Preparacao para casamento',
      'Apoio por funeral na familia'
    )
    and pastoral_request_responses.responder_profile_id = sara_id
    and pastoral_request_responses.internal_only = false;

  for request_record in
    select *
    from public.pastoral_requests
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
      )
  loop
    update public.pastoral_requests
    set
      status = case
        when request_record.urgency = 'urgent' then 'in_contact'
        else 'in_follow_up'
      end,
      first_opened_at = coalesce(first_opened_at, now()),
      updated_at = now()
    where id = request_record.id;

    insert into public.pastoral_request_responses (
      pastoral_request_id,
      responder_profile_id,
      body,
      internal_only,
      created_at
    )
    values (
      request_record.id,
      sara_id,
      case request_record.category
        when 'prayer' then 'Estamos contigo em oracao. A equipa pastoral vai interceder pela tua familia hoje e a pastora Sara fara acompanhamento por telefone.'
        when 'counseling' then 'Recebemos o teu pedido de aconselhamento. A pastora Sara vai contactar-te para marcar uma conversa reservada e tranquila.'
        when 'visit' then 'Recebemos o pedido de visita. Vamos confirmar disponibilidade para sabado de manha e preparar a equipa de acompanhamento.'
        when 'social_support' then 'Recebemos o pedido de apoio social. A igreja vai avaliar a necessidade com discricao e organizar resposta inicial ainda esta semana.'
        when 'baptism' then 'Recebemos o pedido sobre batismo. Vamos incluir-te na lista da proxima classe e enviar orientacoes sobre preparacao.'
        when 'marriage' then 'Recebemos o pedido sobre casamento. A pastora Sara vai marcar uma conversa de aconselhamento pre-matrimonial convosco.'
        when 'funeral' then 'Recebemos o pedido de apoio por funeral. A pastora Sara vai contactar a familia com prioridade para oracao e orientacao pastoral.'
        else 'Recebemos o teu pedido pastoral. A lideranca vai acompanhar e responder com os proximos passos.'
      end,
      false,
      now()
    );

    insert into public.church_request_timeline (
      church_id,
      request_table,
      request_id,
      actor_profile_id,
      action,
      public_message
    )
    values (
      vida_id,
      'pastoral_requests',
      request_record.id,
      sara_id,
      'pastor_response_seed',
      case request_record.category
        when 'prayer' then 'A equipa pastoral recebeu o teu pedido de oracao e vai interceder hoje.'
        when 'counseling' then 'A pastora Sara vai contactar-te para marcar aconselhamento.'
        when 'visit' then 'A igreja vai confirmar uma visita pastoral para sabado de manha.'
        when 'social_support' then 'A igreja vai avaliar o apoio social com discricao.'
        when 'baptism' then 'A igreja vai incluir-te na proxima classe de batismo.'
        when 'marriage' then 'A pastora Sara vai marcar conversa pre-matrimonial.'
        when 'funeral' then 'A pastora Sara vai contactar a familia com prioridade.'
        else 'A lideranca recebeu o pedido e vai acompanhar.'
      end
    );

    perform public.create_internal_notification(
      member_id,
      'Resposta pastoral',
      'A Igreja Vida Nova respondeu ao teu pedido: ' || request_record.title,
      'pastoral_request_answered',
      vida_id,
      sara_id,
      request_record.urgency,
      'pastoral_requests',
      request_record.id,
      'member_requests',
      jsonb_build_object('category', request_record.category)
    );
  end loop;

  delete from public.prayer_request_responses
  using public.prayer_requests request
  where prayer_request_responses.prayer_request_id = request.id
    and request.church_id = vida_id
    and request.profile_id = member_id
    and request.title = 'Oracao pela familia e direcao'
    and prayer_request_responses.responder_profile_id = sara_id;

  insert into public.prayer_request_responses (
    prayer_request_id,
    responder_profile_id,
    body,
    created_at
  )
  select
    request.id,
    sara_id,
    'Estamos a orar pela tua familia, pela saude da tua mae e pela direcao de Deus nas proximas decisoes. A pastora Sara vai acompanhar este pedido.',
    now()
  from public.prayer_requests request
  where request.church_id = vida_id
    and request.profile_id = member_id
    and request.title = 'Oracao pela familia e direcao';

  update public.prayer_requests
  set status = 'answered'
  where church_id = vida_id
    and profile_id = member_id
    and title = 'Oracao pela familia e direcao';
end $$;

notify pgrst, 'reload schema';
