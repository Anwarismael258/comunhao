alter table public.events
  drop constraint if exists events_event_type_check;

alter table public.events
  add constraint events_event_type_check
  check (
    event_type in (
      'service',
      'event',
      'internal_meeting',
      'personal_agenda',
      'culto',
      'congresso',
      'vigilia',
      'batismo',
      'casamento',
      'conferencia',
      'ensaio',
      'reuniao',
      'seminario',
      'retiro',
      'acao_social',
      'formacao',
      'concerto',
      'visita',
      'outro'
    )
  );
