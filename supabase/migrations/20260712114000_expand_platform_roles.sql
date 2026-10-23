alter table public.platform_roles
  drop constraint if exists platform_roles_role_check;

alter table public.platform_roles
  add constraint platform_roles_role_check
  check (
    role in (
      'super_admin',
      'finance',
      'support_agent',
      'marketing',
      'developer',
      'auditor'
    )
  );
