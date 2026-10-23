begin;

alter table public.church_documents
  add column if not exists storage_bucket text,
  add column if not exists storage_path text;

alter table public.church_documents
  drop constraint if exists church_documents_storage_reference_check;

alter table public.church_documents
  add constraint church_documents_storage_reference_check
  check (
    (storage_bucket is null and storage_path is null)
    or (storage_bucket = 'church-documents' and storage_path is not null and storage_path <> '')
  );

create index if not exists idx_church_documents_storage_reference
  on public.church_documents(storage_bucket, storage_path)
  where storage_path is not null;

comment on column public.church_documents.storage_bucket is
  'Bucket privado do documento institucional. Nao guardar URL assinada.';
comment on column public.church_documents.storage_path is
  'Caminho privado do objecto; a Central usa esta referencia para auditoria e URL assinada temporaria.';

commit;
