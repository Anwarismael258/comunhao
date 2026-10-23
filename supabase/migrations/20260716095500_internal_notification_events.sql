create or replace function public.notify_join_request_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_name text;
begin
  select full_name
  into requester_name
  from public.profiles
  where id = new.profile_id;

  perform public.notify_church_managers(
    new.church_id,
    'Novo pedido de entrada',
    coalesce(requester_name, 'Um utilizador') || ' pediu entrada na igreja.',
    'church_join_request_created',
    new.profile_id,
    'normal',
    'church_join_requests',
    new.id,
    'join_requests',
    jsonb_build_object('status', new.status)
  );

  return new;
end;
$$;

drop trigger if exists notify_join_request_created on public.church_join_requests;
create trigger notify_join_request_created
  after insert on public.church_join_requests
  for each row
  execute function public.notify_join_request_created();

create or replace function public.notify_donation_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  donor_name text;
begin
  select full_name
  into donor_name
  from public.profiles
  where id = new.profile_id;

  if new.status = 'pending' then
    perform public.notify_church_managers(
      new.church_id,
      'Contribuicao aguardando confirmacao',
      coalesce(donor_name, 'Um membro') || ' enviou uma contribuicao para confirmacao.',
      'contribution_pending',
      new.profile_id,
      'normal',
      'donations',
      new.id,
      'finance_pending_contributions',
      jsonb_build_object(
        'amount', new.amount,
        'currency', new.currency,
        'provider', new.provider,
        'donation_type', new.donation_type
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists notify_donation_created on public.donations;
create trigger notify_donation_created
  after insert on public.donations
  for each row
  execute function public.notify_donation_created();

create or replace function public.notify_donation_status_changed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status is distinct from new.status
    and new.profile_id is not null
    and new.status in ('confirmed', 'rejected', 'failed') then
    perform public.create_internal_notification(
      new.profile_id,
      case
        when new.status = 'confirmed' then 'Contribuicao confirmada'
        when new.status = 'rejected' then 'Contribuicao rejeitada'
        else 'Contribuicao falhou'
      end,
      case
        when new.status = 'confirmed' then 'A igreja confirmou a tua contribuicao.'
        when new.status = 'rejected' then 'A igreja rejeitou a tua contribuicao. Verifica o motivo.'
        else 'Nao foi possivel confirmar a tua contribuicao.'
      end,
      case
        when new.status = 'confirmed' then 'contribution_confirmed'
        when new.status = 'rejected' then 'contribution_rejected'
        else 'contribution_failed'
      end,
      new.church_id,
      new.confirmed_by,
      'normal',
      'donations',
      new.id,
      'member_donations',
      jsonb_build_object(
        'amount', new.amount,
        'currency', new.currency,
        'provider', new.provider,
        'receipt_number', new.receipt_number
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists notify_donation_status_changed on public.donations;
create trigger notify_donation_status_changed
  after update of status on public.donations
  for each row
  execute function public.notify_donation_status_changed();

create or replace function public.notify_pastoral_request_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_name text;
  safe_message text;
begin
  select full_name
  into requester_name
  from public.profiles
  where id = new.profile_id;

  safe_message := case
    when new.hide_body_in_notifications then
      coalesce(requester_name, 'Um membro') || ' criou um pedido confidencial.'
    else
      coalesce(requester_name, 'Um membro') || ': ' || new.title
  end;

  perform public.notify_church_managers(
    new.church_id,
    'Novo pedido pastoral',
    safe_message,
    'pastoral_request_created',
    new.profile_id,
    case when new.urgency = 'urgent' then 'high' else 'normal' end,
    'pastoral_requests',
    new.id,
    'pastoral_requests',
    jsonb_build_object(
      'category', new.category,
      'urgency', new.urgency,
      'confidentiality', new.confidentiality,
      'hide_body', new.hide_body_in_notifications
    )
  );

  return new;
end;
$$;

drop trigger if exists notify_pastoral_request_created on public.pastoral_requests;
create trigger notify_pastoral_request_created
  after insert on public.pastoral_requests
  for each row
  execute function public.notify_pastoral_request_created();

create or replace function public.notify_public_content_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  member_row record;
  title_text text;
  message_text text;
  type_text text;
begin
  if tg_table_name = 'events' then
    if new.event_status <> 'published' then
      return new;
    end if;
    title_text := 'Novo evento publicado';
    message_text := new.title;
    type_text := 'event_published';
  elsif tg_table_name = 'donation_campaigns' then
    if new.active is not true or new.campaign_status not in ('active', 'published') then
      return new;
    end if;
    title_text := 'Nova campanha';
    message_text := new.title;
    type_text := 'campaign_published';
  else
    if new.publication_status <> 'published' or new.notify_members is not true then
      return new;
    end if;
    title_text := 'Nova publicacao';
    message_text := new.title;
    type_text := 'publication_published';
  end if;

  for member_row in
    select profile_id
    from public.memberships
    where church_id = new.church_id
      and status = 'active'
  loop
    perform public.create_internal_notification(
      member_row.profile_id,
      title_text,
      message_text,
      type_text,
      new.church_id,
      new.created_by,
      'normal',
      tg_table_name,
      new.id,
      tg_table_name,
      jsonb_build_object('source_table', tg_table_name)
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists notify_event_published on public.events;
create trigger notify_event_published
  after insert on public.events
  for each row
  execute function public.notify_public_content_created();

drop trigger if exists notify_campaign_published on public.donation_campaigns;
create trigger notify_campaign_published
  after insert on public.donation_campaigns
  for each row
  execute function public.notify_public_content_created();

drop trigger if exists notify_announcement_published on public.announcements;
create trigger notify_announcement_published
  after insert on public.announcements
  for each row
  execute function public.notify_public_content_created();
