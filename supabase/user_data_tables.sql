-- User-owned foods table
create table if not exists public.foods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  brand text,
  unit text,
  serving_size numeric,
  kcal numeric,
  fat numeric,
  carbs numeric,
  protein numeric,
  category text,
  created_at timestamptz not null default now()
);

-- User-owned daily log entries table
create table if not exists public.entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null,
  food_id uuid not null references public.foods(id) on delete cascade,
  qty numeric not null,
  meal text not null,
  created_at timestamptz not null default now()
);

-- Enable RLS so table access is policy-driven.
alter table public.foods enable row level security;
alter table public.entries enable row level security;

-- =========================
-- RLS policies: public.foods
-- =========================

-- Read only own foods
create policy if not exists "foods_select_own"
  on public.foods
  for select
  to authenticated
  using (user_id = auth.uid());

-- Insert only rows owned by current user (prevents user_id spoofing)
create policy if not exists "foods_insert_own"
  on public.foods
  for insert
  to authenticated
  with check (user_id = auth.uid());

-- Update only own foods; updated row must remain owned by current user
create policy if not exists "foods_update_own"
  on public.foods
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Delete only own foods
create policy if not exists "foods_delete_own"
  on public.foods
  for delete
  to authenticated
  using (user_id = auth.uid());

-- ==========================
-- RLS policies: public.entries
-- ==========================

-- Read only own entries
create policy if not exists "entries_select_own"
  on public.entries
  for select
  to authenticated
  using (user_id = auth.uid());

-- Insert only rows owned by current user (prevents user_id spoofing)
create policy if not exists "entries_insert_own"
  on public.entries
  for insert
  to authenticated
  with check (user_id = auth.uid());

-- Update only own entries; updated row must remain owned by current user
create policy if not exists "entries_update_own"
  on public.entries
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Delete only own entries
create policy if not exists "entries_delete_own"
  on public.entries
  for delete
  to authenticated
  using (user_id = auth.uid());

-- Explicit grants for API roles. RLS still enforces row-level safety.
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.foods to authenticated;
grant select, insert, update, delete on public.entries to authenticated;
