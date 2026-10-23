drop policy if exists "Church admins can read profiles in own church"
  on public.profiles;

create policy "Church admins can read profiles in own church"
  on public.profiles
  for select
  to authenticated
  using (
    public.is_super_admin()
    or exists (
      select 1
      from public.memberships manager
      join public.memberships target
        on target.profile_id = profiles.id
       and target.church_id = manager.church_id
      where manager.profile_id = auth.uid()
        and manager.status = 'active'
        and manager.role in ('pastor', 'church_admin')
    )
  );
