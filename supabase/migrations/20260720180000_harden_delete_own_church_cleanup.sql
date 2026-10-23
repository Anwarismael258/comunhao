create or replace function public.delete_own_church(
  p_church_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  church_row public.churches%rowtype;
  notified_count integer := 0;
begin
  if not public.has_church_role(
    p_church_id,
    array['pastor', 'church_admin']::text[]
  ) then
    raise exception 'Sem permissao para apagar esta igreja.';
  end if;

  select *
    into church_row
  from public.churches
  where id = p_church_id;

  if church_row.id is null then
    raise exception 'Igreja nao encontrada.';
  end if;

  insert into public.internal_notifications (
    recipient_profile_id,
    church_id,
    actor_profile_id,
    title,
    message,
    notification_type,
    priority,
    reference_table,
    reference_id,
    action_route,
    metadata
  )
  select
    membership.profile_id,
    null,
    auth.uid(),
    'Igreja removida',
    'A igreja "' || church_row.name || '" foi removida do Comunhao. O teu acesso a esta igreja foi encerrado.',
    'church_deleted',
    'high',
    null,
    null,
    'church_deleted',
    jsonb_build_object(
      'church_id', church_row.id,
      'church_name', church_row.name,
      'deleted_at', now()
    )
  from public.memberships membership
  where membership.church_id = p_church_id
    and membership.status = 'active';

  get diagnostics notified_count = row_count;

  update public.church_applications
  set
    approved_church_id = null,
    status = case when status = 'approved' then 'draft' else status end,
    review_notes = concat_ws(
      E'\n',
      nullif(review_notes, ''),
      'Igreja apagada pelo pastor em ' || now()::text || '. Pode cadastrar uma nova igreja.'
    )
  where approved_church_id = p_church_id;

  update public.platform_audit_logs
  set church_id = null
  where church_id = p_church_id;

  update public.member_wallet_ledger_entries
  set church_id = null
  where church_id = p_church_id;

  update public.church_unit_organizations
  set headquarters_church_id = null
  where headquarters_church_id = p_church_id;

  update public.churches
  set parent_church_id = null
  where parent_church_id = p_church_id;

  update public.branch_report_submissions
  set church_id = null
  where church_id = p_church_id;

  update public.pilot_feedback
  set church_id = null
  where church_id = p_church_id;

  update public.pilot_issue_reports
  set church_id = null
  where church_id = p_church_id;

  update public.contract_amendments
  set church_id = null
  where church_id = p_church_id;

  update public.care_request_timeline
  set church_id = null
  where church_id = p_church_id;

  update public.internal_notifications
  set church_id = null
  where church_id = p_church_id;

  delete from public.churches
  where id = p_church_id;

  return jsonb_build_object(
    'church_id', p_church_id,
    'church_name', church_row.name,
    'notified_members', notified_count,
    'deleted', true
  );
end;
$$;

grant execute on function public.delete_own_church(uuid) to authenticated;
