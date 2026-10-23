-- Conta Triunfal / Comunhao central.  This migration intentionally targets
-- the central `core` and `comunhao` schemas; it never recreates auth users or
-- profiles and does not alter roles from any other platform.
begin;

alter table comunhao.memberships
  drop constraint if exists memberships_status_check;

alter table comunhao.memberships
  add constraint memberships_status_check check (
    status in (
      'visitor', 'in_follow_up', 'candidate', 'invited', 'pending', 'active',
      'inactive', 'blocked', 'suspended', 'removed', 'transferred', 'deceased', 'archived'
    )
  );

create table if not exists comunhao.church_invites (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references comunhao.churches(id) on delete cascade,
  invited_user_id uuid references auth.users(id) on delete set null,
  invited_phone text,
  role text not null default 'member',
  token_hash text not null unique,
  status text not null default 'pending',
  expires_at timestamptz not null,
  accepted_at timestamptz,
  accepted_by uuid references auth.users(id) on delete set null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  check (role in ('member', 'leader', 'pastor', 'church_admin')),
  check (status in ('pending', 'accepted', 'revoked', 'expired'))
);

create index if not exists church_invites_user_pending_idx
  on comunhao.church_invites(invited_user_id, expires_at)
  where status = 'pending';

alter table comunhao.church_invites enable row level security;

create or replace function comunhao.ensure_comunhao_member_role()
returns void
language plpgsql
security definer
set search_path = core, comunhao, auth, public
as $$
declare
  member_role_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select r.id into member_role_id
  from core.roles r
  join core.apps a on a.id = r.app_id
  where a.slug = 'comunhao'
    and r.slug = 'comunhao_member'
    and a.is_active = true
  limit 1;

  if member_role_id is null then
    raise exception 'Comunhao member role is not configured in the central account.';
  end if;

  insert into core.user_roles(user_id, role_id, assigned_by, assignment_reason, metadata)
  values (auth.uid(), member_role_id, auth.uid(), 'Comunhao first access', '{}'::jsonb)
  on conflict (user_id, role_id) do nothing;
end;
$$;

create or replace function comunhao.request_comunhao_membership(p_church_id uuid)
returns comunhao.memberships
language plpgsql
security definer
set search_path = core, comunhao, auth, public
as $$
declare
  result comunhao.memberships;
  join_mode text;
  approval_required boolean;
  requested_status text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  perform comunhao.ensure_comunhao_member_role();

  select member_join_mode, coalesce(require_member_approval, false)
    into join_mode, approval_required
  from comunhao.church_settings
  where church_id = p_church_id;

  if not found then
    raise exception 'Church is not available for membership.';
  end if;
  if coalesce(join_mode, 'open') = 'invite_only' then
    raise exception 'Esta igreja aceita membros apenas por convite.';
  end if;

  requested_status := case when approval_required then 'pending' else 'active' end;
  insert into comunhao.memberships(
    church_id, user_id, profile_id, role, status, joined_at, approved_at, updated_at
  )
  values (
    p_church_id, auth.uid(), auth.uid(), 'member', requested_status, now(),
    case when requested_status = 'active' then now() else null end, now()
  )
  on conflict (church_id, user_id) do update set
    status = case
      when comunhao.memberships.status in ('blocked', 'suspended', 'removed') then comunhao.memberships.status
      else excluded.status
    end,
    updated_at = now()
  returning * into result;

  return result;
end;
$$;

create or replace function comunhao.accept_comunhao_invite(p_token text)
returns comunhao.memberships
language plpgsql
security definer
set search_path = core, comunhao, auth, public, extensions
as $$
declare
  invite_row comunhao.church_invites%rowtype;
  result comunhao.memberships;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into invite_row
  from comunhao.church_invites
  where token_hash = encode(extensions.digest(trim(p_token), 'sha256'), 'hex')
  for update;

  if not found or invite_row.status <> 'pending' or invite_row.expires_at <= now() then
    raise exception 'Convite invalido ou expirado.';
  end if;
  if invite_row.invited_user_id is not null and invite_row.invited_user_id <> auth.uid() then
    raise exception 'Este convite pertence a outra Conta Triunfal.';
  end if;

  perform comunhao.ensure_comunhao_member_role();
  insert into comunhao.memberships(
    church_id, user_id, profile_id, role, status, joined_at, approved_at, updated_at
  )
  values (invite_row.church_id, auth.uid(), auth.uid(), invite_row.role, 'active', now(), now(), now())
  on conflict (church_id, user_id) do update set
    role = excluded.role, status = 'active', approved_at = now(), updated_at = now()
  returning * into result;

  update comunhao.church_invites
  set status = 'accepted', accepted_at = now(), accepted_by = auth.uid()
  where id = invite_row.id;

  return result;
end;
$$;

drop policy if exists "Users can read own church invites" on comunhao.church_invites;
create policy "Users can read own church invites"
  on comunhao.church_invites for select to authenticated
  using (
    invited_user_id = auth.uid()
    or comunhao.has_church_role(church_id, auth.uid(), array['owner', 'church_admin', 'pastor'])
  );

drop policy if exists "Church admins create church invites" on comunhao.church_invites;
create policy "Church admins create church invites"
  on comunhao.church_invites for insert to authenticated
  with check (
    created_by = auth.uid()
    and comunhao.has_church_role(church_id, auth.uid(), array['owner', 'church_admin', 'pastor'])
  );

insert into comunhao.subscription_plans(
  code, name, description, price_minor, price_mzn, currency_code,
  member_limit, admin_limit, billing_cycle_days, features,
  is_public, is_paid, is_active, sort_order
)
values (
  'comunhao_monthly', 'Comunhao mensal', 'Assinatura mensal por igreja.',
  30000, 300, 'MZN', null, null, 30,
  jsonb_build_array('Acesso Comunhao por 30 dias', 'Gestao de membros', 'Suporte padrao'),
  true, true, true, 0
)
on conflict (code) do update set
  name = excluded.name, description = excluded.description, price_minor = excluded.price_minor,
  price_mzn = excluded.price_mzn, currency_code = excluded.currency_code,
  billing_cycle_days = 30, features = excluded.features, is_public = true,
  is_paid = true, is_active = true;

grant execute on function comunhao.ensure_comunhao_member_role() to authenticated;
grant execute on function comunhao.request_comunhao_membership(uuid) to authenticated;
grant execute on function comunhao.accept_comunhao_invite(text) to authenticated;

commit;
