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
  fk_row record;
  changed_count integer := 0;
  total_nullified integer := 0;
  total_deleted integer := 0;
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

  update public.churches
  set parent_church_id = null
  where parent_church_id = p_church_id;

  for fk_row in
    select
      n.nspname as schema_name,
      c.relname as table_name,
      a.attname as column_name,
      a.attnotnull as column_not_null,
      con.confdeltype as delete_action
    from pg_constraint con
    join pg_class c on c.oid = con.conrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_attribute a
      on a.attrelid = con.conrelid
     and a.attnum = con.conkey[1]
    where con.contype = 'f'
      and con.confrelid = 'public.churches'::regclass
      and array_length(con.conkey, 1) = 1
      and n.nspname = 'public'
      and not (n.nspname = 'public' and c.relname = 'churches')
  loop
    if fk_row.delete_action = 'c' then
      continue;
    end if;

    if not fk_row.column_not_null or fk_row.delete_action = 'n' then
      execute format(
        'update %I.%I set %I = null where %I = $1',
        fk_row.schema_name,
        fk_row.table_name,
        fk_row.column_name,
        fk_row.column_name
      )
      using p_church_id;
      get diagnostics changed_count = row_count;
      total_nullified := total_nullified + changed_count;
    else
      execute format(
        'delete from %I.%I where %I = $1',
        fk_row.schema_name,
        fk_row.table_name,
        fk_row.column_name
      )
      using p_church_id;
      get diagnostics changed_count = row_count;
      total_deleted := total_deleted + changed_count;
    end if;
  end loop;

  delete from public.churches
  where id = p_church_id;

  if not found then
    raise exception 'Igreja nao encontrada ou ja removida.';
  end if;

  return jsonb_build_object(
    'church_id', p_church_id,
    'church_name', church_row.name,
    'notified_members', notified_count,
    'references_nullified', total_nullified,
    'references_deleted', total_deleted,
    'deleted', true
  );
end;
$$;

grant execute on function public.delete_own_church(uuid) to authenticated;
