do $$
declare
  vida_id uuid;
  member_id uuid;
  sara_id uuid;
  target_event_id uuid;
  feed_post_id uuid;
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

  if vida_id is null or member_id is null then
    return;
  end if;

  delete from public.community_post_comments
  using public.community_posts post
  where community_post_comments.post_id = post.id
    and post.church_id = vida_id
    and post.author_profile_id = member_id
    and post.title in (
      'Testemunho de cuidado de Deus',
      'Meu versiculo favorito',
      'Reflexao sobre confiar',
      'Fotografia do culto da familia',
      'Gratidao pela Igreja Vida Nova',
      'Pedido de oracao pela semana',
      'Evangelismo no bairro'
    );

  delete from public.community_post_reactions
  using public.community_posts post
  where community_post_reactions.post_id = post.id
    and post.church_id = vida_id
    and post.author_profile_id = member_id
    and post.title in (
      'Testemunho de cuidado de Deus',
      'Meu versiculo favorito',
      'Reflexao sobre confiar',
      'Fotografia do culto da familia',
      'Gratidao pela Igreja Vida Nova',
      'Pedido de oracao pela semana',
      'Evangelismo no bairro'
    );

  delete from public.community_posts
  where church_id = vida_id
    and author_profile_id = member_id
    and title in (
      'Testemunho de cuidado de Deus',
      'Meu versiculo favorito',
      'Reflexao sobre confiar',
      'Fotografia do culto da familia',
      'Gratidao pela Igreja Vida Nova',
      'Pedido de oracao pela semana',
      'Evangelismo no bairro'
    );

  insert into public.community_posts (
    church_id,
    author_profile_id,
    post_type,
    title,
    body,
    image_url,
    community_space,
    status,
    moderated_by,
    moderated_at,
    created_at,
    updated_at
  )
  values
    (
      vida_id,
      member_id,
      'testimony',
      'Testemunho de cuidado de Deus',
      'Quero testemunhar que Deus abriu uma porta de trabalho depois de muitas semanas de oracao. A igreja orou comigo e fui muito fortalecido.',
      null,
      'general',
      'approved',
      sara_id,
      now(),
      now() - interval '48 minutes',
      now() - interval '48 minutes'
    ),
    (
      vida_id,
      member_id,
      'verse',
      'Meu versiculo favorito',
      'Salmos 37:5 tem falado muito comigo: entregar o caminho ao Senhor e confiar que Ele cuida de tudo.',
      null,
      'general',
      'approved',
      sara_id,
      now(),
      now() - interval '42 minutes',
      now() - interval '42 minutes'
    ),
    (
      vida_id,
      member_id,
      'reflection',
      'Reflexao sobre confiar',
      'Nem sempre entendemos o processo, mas podemos continuar fieis. A confianca em Deus tambem se revela nos pequenos passos de obediencia.',
      null,
      'cells',
      'approved',
      sara_id,
      now(),
      now() - interval '36 minutes',
      now() - interval '36 minutes'
    ),
    (
      vida_id,
      member_id,
      'photo',
      'Fotografia do culto da familia',
      'Momento bonito do ultimo culto da familia na Igreja Vida Nova. Foi um tempo de palavra, comunhao e oracao.',
      'https://images.unsplash.com/photo-1507692049790-de58290a4334?auto=format&fit=crop&w=1200&q=80',
      'general',
      'approved',
      sara_id,
      now(),
      now() - interval '30 minutes',
      now() - interval '30 minutes'
    ),
    (
      vida_id,
      member_id,
      'gratitude',
      'Gratidao pela Igreja Vida Nova',
      'Sou grato pela forma como fui recebido nesta igreja. Tenho sentido apoio, palavra e comunhao verdadeira.',
      null,
      'general',
      'approved',
      sara_id,
      now(),
      now() - interval '24 minutes',
      now() - interval '24 minutes'
    ),
    (
      vida_id,
      member_id,
      'prayer',
      'Pedido de oracao pela semana',
      'Peco oracao pela minha familia, pela saude da minha mae e por sabedoria nas decisoes desta semana.',
      null,
      'intercession',
      'approved',
      sara_id,
      now(),
      now() - interval '18 minutes',
      now() - interval '18 minutes'
    ),
    (
      vida_id,
      member_id,
      'evangelism',
      'Evangelismo no bairro',
      'No sabado vamos convidar vizinhos para o culto e partilhar uma palavra de esperanca. Quem puder apoiar, fale com a equipa de evangelismo.',
      null,
      'evangelism',
      'approved',
      sara_id,
      now(),
      now() - interval '12 minutes',
      now() - interval '12 minutes'
    );

  for feed_post_id in
    select id
    from public.community_posts
    where church_id = vida_id
      and author_profile_id = member_id
      and title in (
        'Testemunho de cuidado de Deus',
        'Meu versiculo favorito',
        'Reflexao sobre confiar',
        'Fotografia do culto da familia',
        'Gratidao pela Igreja Vida Nova',
        'Evangelismo no bairro'
      )
  loop
    insert into public.community_post_reactions (
      post_id,
      profile_id,
      reaction_type
    )
    values (
      feed_post_id,
      coalesce(sara_id, member_id),
      'amen'
    )
    on conflict (post_id, profile_id) do update
      set reaction_type = excluded.reaction_type;

    insert into public.community_post_comments (
      post_id,
      profile_id,
      body,
      status,
      created_at
    )
    values (
      feed_post_id,
      coalesce(sara_id, member_id),
      'Que Deus continue a fortalecer a tua caminhada. Obrigado por partilhares com a igreja.',
      'visible',
      now()
    );
  end loop;

  select id
  into feed_post_id
  from public.community_posts
  where church_id = vida_id
    and author_profile_id = member_id
    and title = 'Pedido de oracao pela semana'
  limit 1;

  if feed_post_id is not null then
    insert into public.community_post_reactions (
      post_id,
      profile_id,
      reaction_type
    )
    values (
      feed_post_id,
      coalesce(sara_id, member_id),
      'praying'
    )
    on conflict (post_id, profile_id) do update
      set reaction_type = 'praying';

    insert into public.community_post_comments (
      post_id,
      profile_id,
      body,
      status,
      created_at
    )
    values (
      feed_post_id,
      coalesce(sara_id, member_id),
      'Estamos orando por voce. Que Deus fortaleça a tua familia e guie cada decisao.',
      'visible',
      now()
    );
  end if;

  select e.id
  into target_event_id
  from public.events e
  where e.church_id = vida_id
    and e.status = 'published'
    and e.starts_at > now()
  order by e.starts_at
  limit 1;

  if target_event_id is not null then
    insert into public.event_registrations (
      event_id,
      profile_id,
      status,
      created_at
    )
    values (
      target_event_id,
      member_id,
      'confirmed',
      now()
    )
    on conflict (event_id, profile_id) do update
      set status = 'confirmed',
          cancelled_at = null;
  end if;
end $$;

notify pgrst, 'reload schema';
