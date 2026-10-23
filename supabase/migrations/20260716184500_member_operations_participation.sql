create or replace function public.respond_own_service_roster(
  p_roster_id uuid,
  p_status text,
  p_notes text default null
)
returns public.service_rosters
language plpgsql
security definer
set search_path = public
as $$
declare
  roster_row public.service_rosters%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;

  if p_status not in ('confirmed', 'declined') then
    raise exception 'Invalid roster response.';
  end if;

  update public.service_rosters sr
  set
    status = p_status,
    confirmation_notes = nullif(trim(coalesce(p_notes, '')), ''),
    updated_at = now()
  where sr.id = p_roster_id
    and exists (
      select 1
      from public.memberships m
      where m.id = sr.assigned_membership_id
        and m.profile_id = auth.uid()
        and m.status = 'active'
    )
  returning *
  into roster_row;

  if roster_row.id is null then
    raise exception 'Roster not found for this member.';
  end if;

  insert into public.operational_audit_logs (
    church_id,
    actor_profile_id,
    action,
    entity_type,
    entity_id,
    after_data
  )
  values (
    roster_row.church_id,
    auth.uid(),
    'service_roster_member_response',
    'service_roster',
    roster_row.id,
    jsonb_build_object('status', p_status)
  );

  insert into public.internal_notifications (
    recipient_profile_id,
    church_id,
    actor_profile_id,
    notification_type,
    title,
    message,
    action_route,
    reference_table,
    reference_id,
    metadata
  )
  select
    m.profile_id,
    roster_row.church_id,
    auth.uid(),
    'service_roster_response',
    'Resposta de escala',
    'Um membro respondeu a uma escala de servico.',
    '/operations/rosters',
    'service_rosters',
    roster_row.id,
    jsonb_build_object('roster_id', roster_row.id, 'status', p_status)
  from public.memberships m
  where m.church_id = roster_row.church_id
    and m.status = 'active'
    and m.role in ('pastor', 'church_admin', 'leader');

  return roster_row;
end;
$$;

grant execute on function public.respond_own_service_roster(uuid, text, text) to authenticated;
