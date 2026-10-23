create or replace function public.get_platform_operational_metrics()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.has_platform_role(
    array['super_admin', 'support_agent', 'developer', 'auditor']::text[],
    auth.uid()
  ) then
    raise exception 'Only platform staff can view operational metrics.';
  end if;

  return jsonb_build_object(
    'ministries', (select count(*) from public.church_ministries where is_demo = false),
    'groups', (select count(*) from public.church_groups where is_demo = false),
    'tasks_open', (select count(*) from public.operational_tasks where status not in ('done', 'cancelled') and is_demo = false),
    'tasks_overdue', (select count(*) from public.operational_tasks where due_at < now() and status not in ('done', 'cancelled') and is_demo = false),
    'rosters_pending', (select count(*) from public.service_rosters where status = 'pending_confirmation' and is_demo = false),
    'assets', (select count(*) from public.church_assets where is_demo = false),
    'assets_maintenance', (select count(*) from public.church_assets where status = 'maintenance' and is_demo = false),
    'purchase_requests_pending', (select count(*) from public.purchase_requests where status in ('submitted', 'reviewing', 'approved') and is_demo = false),
    'volunteer_opportunities_open', (select count(*) from public.volunteer_opportunities where status = 'open' and is_demo = false),
    'join_requests_pending', (select count(*) from public.ministry_join_requests where status in ('pending', 'reviewing', 'interview_required') and is_demo = false)
  );
end;
$$;

grant execute on function public.get_platform_operational_metrics() to authenticated;
