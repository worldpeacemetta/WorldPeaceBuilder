-- User profile / settings table
-- Stores per-user body stats, macro goals (including per-date schedule), and preferences.
-- This table is the authoritative cross-device store; localStorage is a fast-load cache only.
create table if not exists public.user_profile (
  id              uuid primary key references auth.users(id) on delete cascade,
  age             numeric,
  sex             text,
  height          numeric,
  weight          numeric,
  body_fat        numeric,
  activity_level  text,
  calories        numeric,
  protein         numeric,
  carbs           numeric,
  fat             numeric,
  daily_macro_goals jsonb,   -- full goals object incl. byDate per-day schedule
  profile_history   jsonb,   -- array of { date, weightKg, bodyFatPct, recordedAt }
  language        text,
  updated_at      timestamptz default now()
);

alter table public.user_profile enable row level security;

-- Users can only read their own row.
create policy if not exists "user_profile_select_own"
  on public.user_profile
  for select
  to authenticated
  using (auth.uid() = id);

-- Users can insert their own row (initial creation via upsert).
create policy if not exists "user_profile_insert_own"
  on public.user_profile
  for insert
  to authenticated
  with check (auth.uid() = id);

-- Users can update their own row.
create policy if not exists "user_profile_update_own"
  on public.user_profile
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

grant usage on schema public to authenticated;
grant select, insert, update on public.user_profile to authenticated;
