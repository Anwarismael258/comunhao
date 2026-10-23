create or replace function public.notify_prayer_request_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_name text;
  requester_label text;
begin
  select full_name
  into requester_name
  from public.profiles
  where id = new.profile_id;

  requester_label := case
    when coalesce(new.anonymous_request, false) or new.visibility = 'anonymous' then
      'Um membro'
    else
      coalesce(requester_name, 'Um membro')
  end;

  perform public.notify_church_managers(
    new.church_id,
    'Novo pedido de oracao',
    requester_label || ' enviou um pedido de oracao: ' || new.title,
    'prayer_request_created',
    new.profile_id,
    'normal',
    'prayer_requests',
    new.id,
    'prayer_requests',
    jsonb_build_object(
      'visibility', new.visibility,
      'anonymous', coalesce(new.anonymous_request, false),
      'allow_responses', coalesce(new.allow_responses, true),
      'status', new.status
    )
  );

  return new;
end;
$$;

drop trigger if exists notify_prayer_request_created on public.prayer_requests;
create trigger notify_prayer_request_created
  after insert on public.prayer_requests
  for each row
  execute function public.notify_prayer_request_created();

create or replace function public.notify_prayer_response_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  request_row public.prayer_requests%rowtype;
  responder_name text;
begin
  select *
  into request_row
  from public.prayer_requests
  where id = new.prayer_request_id;

  if request_row.id is null or request_row.profile_id is null then
    return new;
  end if;

  if request_row.profile_id = new.responder_profile_id then
    return new;
  end if;

  select full_name
  into responder_name
  from public.profiles
  where id = new.responder_profile_id;

  perform public.create_internal_notification(
    request_row.profile_id,
    'Resposta ao teu pedido de oracao',
    coalesce(responder_name, 'A lideranca') || ' respondeu ao teu pedido: ' || request_row.title,
    'prayer_request_answered',
    request_row.church_id,
    new.responder_profile_id,
    'normal',
    'prayer_request_responses',
    new.id,
    'member_prayers',
    jsonb_build_object(
      'prayer_request_id', request_row.id,
      'prayer_request_title', request_row.title
    )
  );

  return new;
end;
$$;

drop trigger if exists notify_prayer_response_created on public.prayer_request_responses;
create trigger notify_prayer_response_created
  after insert on public.prayer_request_responses
  for each row
  execute function public.notify_prayer_response_created();

notify pgrst, 'reload schema';
