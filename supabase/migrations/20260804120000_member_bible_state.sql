create table if not exists public.member_bible_state (
  member_id uuid primary key references public.profiles(id) on delete cascade,
  church_id uuid not null references public.churches(id) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.member_bible_state enable row level security;

drop policy if exists "Members can read own bible state" on public.member_bible_state;
create policy "Members can read own bible state"
  on public.member_bible_state for select to authenticated
  using (member_id = auth.uid());

drop policy if exists "Members can write own bible state" on public.member_bible_state;
create policy "Members can write own bible state"
  on public.member_bible_state for insert to authenticated
  with check (member_id = auth.uid());

drop policy if exists "Members can update own bible state" on public.member_bible_state;
create policy "Members can update own bible state"
  on public.member_bible_state for update to authenticated
  using (member_id = auth.uid())
  with check (member_id = auth.uid());

create or replace function public.touch_member_bible_state_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists member_bible_state_updated_at on public.member_bible_state;
create trigger member_bible_state_updated_at
before update on public.member_bible_state
for each row execute function public.touch_member_bible_state_updated_at();
