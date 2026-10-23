insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'church-application-branding',
  'church-application-branding',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = true,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Pastors can upload own church application branding" on storage.objects;
create policy "Pastors can upload own church application branding"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'church-application-branding'
    and split_part(storage.objects.name, '/', 1) = auth.uid()::text
  );

drop policy if exists "Pastors can update own church application branding" on storage.objects;
create policy "Pastors can update own church application branding"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'church-application-branding'
    and split_part(storage.objects.name, '/', 1) = auth.uid()::text
  )
  with check (
    bucket_id = 'church-application-branding'
    and split_part(storage.objects.name, '/', 1) = auth.uid()::text
  );

drop policy if exists "Public can read church application branding" on storage.objects;
create policy "Public can read church application branding"
  on storage.objects
  for select
  using (bucket_id = 'church-application-branding');
