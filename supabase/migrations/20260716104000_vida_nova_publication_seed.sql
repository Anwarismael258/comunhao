do $$
declare
  vida_church_id uuid;
  sara_profile_id uuid;
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

  delete from public.pastoral_publications
  where church_id = vida_church_id
    and is_demo = true;

  insert into public.pastoral_publications (
    church_id,
    author_user_id,
    title,
    slug,
    summary,
    content,
    publication_type,
    category,
    status,
    visibility,
    priority,
    published_at,
    scheduled_at,
    allow_comments,
    allow_reactions,
    allow_sharing,
    send_notification,
    is_featured,
    is_pinned,
    is_demo,
    created_at
  )
  values
    (
      vida_church_id,
      sara_profile_id,
      'Mensagem da lideranca',
      'mensagem-da-lideranca-vida-nova',
      'Uma palavra de encorajamento da pastora Sara para a familia Vida Nova.',
      'Amada igreja, seguimos firmes em unidade, servico e fe. Que cada familia viva esta semana com coragem e amor.',
      'leadership_message',
      'lideranca',
      'published',
      'members',
      'normal',
      now() - interval '5 days',
      null,
      true,
      true,
      true,
      false,
      true,
      true,
      true,
      now() - interval '5 days'
    ),
    (
      vida_church_id,
      sara_profile_id,
      'Pregacao: Uma casa firmada em Deus',
      'pregacao-casa-firmada-em-deus',
      'Pregacao dominical sobre fundamento, familia e perseveranca.',
      'Texto base: Mateus 7. A igreja permanece firme quando ouve e pratica a Palavra.',
      'sermon',
      'culto',
      'published',
      'members',
      'normal',
      now() - interval '4 days',
      null,
      true,
      true,
      true,
      false,
      false,
      false,
      true,
      now() - interval '4 days'
    ),
    (
      vida_church_id,
      sara_profile_id,
      'Devocional: Graca para hoje',
      'devocional-graca-para-hoje',
      'Uma leitura breve para comecar o dia em oracao.',
      'A graca de Deus renova o nosso coracao e orienta as nossas escolhas diarias.',
      'devotional',
      'devocional',
      'published',
      'members',
      'normal',
      now() - interval '3 days',
      null,
      false,
      true,
      true,
      false,
      false,
      false,
      true,
      now() - interval '3 days'
    ),
    (
      vida_church_id,
      sara_profile_id,
      'Estudo biblico: Comunhao e servico',
      'estudo-biblico-comunhao-e-servico',
      'Estudo para celulas e ministerios.',
      'A comunhao biblica gera cuidado, responsabilidade e servico pratico dentro da igreja.',
      'bible_study',
      'estudo',
      'published',
      'members',
      'normal',
      now() - interval '2 days',
      null,
      true,
      true,
      true,
      false,
      false,
      false,
      true,
      now() - interval '2 days'
    ),
    (
      vida_church_id,
      sara_profile_id,
      'Video: Boas-vindas Vida Nova',
      'video-boas-vindas-vida-nova',
      'Video curto de boas-vindas para novos membros.',
      'Assiste a mensagem de acolhimento e conhece os proximos passos da comunidade.',
      'video',
      'acolhimento',
      'published',
      'members',
      'normal',
      now() - interval '1 day',
      null,
      false,
      true,
      true,
      false,
      false,
      false,
      true,
      now() - interval '1 day'
    ),
    (
      vida_church_id,
      sara_profile_id,
      'Audio: Oracao da semana',
      'audio-oracao-da-semana',
      'Audio pastoral para oracao em familia.',
      'Separa alguns minutos para orar pela tua casa, pela cidade de Maputo e pela igreja.',
      'audio',
      'oracao',
      'published',
      'members',
      'normal',
      now() - interval '12 hours',
      null,
      false,
      true,
      true,
      false,
      false,
      false,
      true,
      now() - interval '12 hours'
    ),
    (
      vida_church_id,
      sara_profile_id,
      'Comunicado: Encontro de membros',
      'comunicado-encontro-de-membros',
      'Informacao sobre o encontro mensal de membros.',
      'O encontro de membros acontece este sabado em Maputo. Chega cedo para o momento de intercessao.',
      'announcement',
      'comunicado',
      'published',
      'members',
      'normal',
      now() - interval '6 hours',
      null,
      false,
      true,
      true,
      false,
      false,
      true,
      true,
      now() - interval '6 hours'
    ),
    (
      vida_church_id,
      sara_profile_id,
      'Transmissao: Culto de celebracao',
      'transmissao-culto-de-celebracao',
      'Transmissao agendada do culto de celebracao.',
      'A transmissao abre no horario do culto. Usa o link externo configurado pela igreja.',
      'live_stream',
      'culto',
      'scheduled',
      'members',
      'normal',
      null,
      now() + interval '2 days',
      false,
      true,
      true,
      false,
      false,
      false,
      true,
      now()
    );
end $$;
