insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'pastoral-publications',
  'pastoral-publications',
  true,
  104857600,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'audio/mpeg',
    'audio/mp4',
    'audio/x-m4a',
    'video/mp4',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]
)
on conflict (id) do update
set
  public = true,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can read pastoral publication files" on storage.objects;
create policy "Public can read pastoral publication files"
  on storage.objects
  for select
  using (bucket_id = 'pastoral-publications');

drop policy if exists "Church managers can upload pastoral publication files" on storage.objects;
create policy "Church managers can upload pastoral publication files"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'pastoral-publications'
    and exists (
      select 1
      from public.memberships m
      where m.profile_id = auth.uid()
        and m.status = 'active'
        and m.role in ('pastor', 'church_admin', 'leader', 'secretary')
        and split_part(storage.objects.name, '/', 1) = m.church_id::text
    )
  );

drop policy if exists "Church managers can update pastoral publication files" on storage.objects;
create policy "Church managers can update pastoral publication files"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'pastoral-publications'
    and exists (
      select 1
      from public.memberships m
      where m.profile_id = auth.uid()
        and m.status = 'active'
        and m.role in ('pastor', 'church_admin', 'leader', 'secretary')
        and split_part(storage.objects.name, '/', 1) = m.church_id::text
    )
  )
  with check (
    bucket_id = 'pastoral-publications'
    and exists (
      select 1
      from public.memberships m
      where m.profile_id = auth.uid()
        and m.status = 'active'
        and m.role in ('pastor', 'church_admin', 'leader', 'secretary')
        and split_part(storage.objects.name, '/', 1) = m.church_id::text
    )
  );

drop policy if exists "Church managers can remove pastoral publication files" on storage.objects;
create policy "Church managers can remove pastoral publication files"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'pastoral-publications'
    and exists (
      select 1
      from public.memberships m
      where m.profile_id = auth.uid()
        and m.status = 'active'
        and m.role in ('pastor', 'church_admin', 'leader', 'secretary')
        and split_part(storage.objects.name, '/', 1) = m.church_id::text
    )
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-media',
  'profile-media',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Users can upload own profile photo" on storage.objects;
create policy "Users can upload own profile photo"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'profile-media'
    and split_part(storage.objects.name, '/', 2) = 'profiles'
    and split_part(storage.objects.name, '/', 3) = auth.uid()::text
    and exists (
      select 1
      from public.memberships m
      where m.profile_id = auth.uid()
        and m.status = 'active'
        and split_part(storage.objects.name, '/', 1) = m.church_id::text
    )
  );

drop policy if exists "Users can update own profile photo" on storage.objects;
create policy "Users can update own profile photo"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'profile-media'
    and split_part(storage.objects.name, '/', 2) = 'profiles'
    and split_part(storage.objects.name, '/', 3) = auth.uid()::text
  )
  with check (
    bucket_id = 'profile-media'
    and split_part(storage.objects.name, '/', 2) = 'profiles'
    and split_part(storage.objects.name, '/', 3) = auth.uid()::text
  );

drop policy if exists "Users can read own profile photo" on storage.objects;
create policy "Users can read own profile photo"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'profile-media'
    and (
      split_part(storage.objects.name, '/', 3) = auth.uid()::text
      or exists (
        select 1
        from public.memberships m
        where m.profile_id = auth.uid()
          and m.status = 'active'
          and split_part(storage.objects.name, '/', 1) = m.church_id::text
      )
    )
  );
