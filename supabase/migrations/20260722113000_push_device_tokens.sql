create table if not exists public.push_device_tokens (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  app_code text not null check (app_code in ('members', 'church', 'super_admin')),
  platform text not null default 'android',
  token text not null unique,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists push_device_tokens_profile_idx
  on public.push_device_tokens(profile_id);

create index if not exists push_device_tokens_app_idx
  on public.push_device_tokens(app_code);

alter table public.push_device_tokens enable row level security;

drop policy if exists "Users manage their own push tokens"
  on public.push_device_tokens;

create policy "Users manage their own push tokens"
  on public.push_device_tokens
  for all
  using (auth.uid() = profile_id)
  with check (auth.uid() = profile_id);

drop trigger if exists set_push_device_tokens_updated_at
  on public.push_device_tokens;

create trigger set_push_device_tokens_updated_at
before update on public.push_device_tokens
for each row execute function public.set_updated_at();
