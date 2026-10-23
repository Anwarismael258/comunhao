insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'pastoral-publications',
  'pastoral-publications',
  true,
  26214400,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'audio/mpeg',
    'audio/mp4',
    'video/mp4',
    'application/pdf'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
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
        and m.role in ('pastor', 'church_admin', 'leader')
        and split_part(name, '/', 1) = m.church_id::text
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
        and m.role in ('pastor', 'church_admin', 'leader')
        and split_part(name, '/', 1) = m.church_id::text
    )
  )
  with check (
    bucket_id = 'pastoral-publications'
    and exists (
      select 1
      from public.memberships m
      where m.profile_id = auth.uid()
        and m.status = 'active'
        and m.role in ('pastor', 'church_admin', 'leader')
        and split_part(name, '/', 1) = m.church_id::text
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
        and m.role in ('pastor', 'church_admin', 'leader')
        and split_part(name, '/', 1) = m.church_id::text
    )
  );
