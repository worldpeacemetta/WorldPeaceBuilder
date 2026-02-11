-- Profiles table for username-based login
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Users can read their own profile once authenticated.
create policy if not exists "Users can read own profile"
  on public.profiles
  for select
  using (auth.uid() = id);

-- Users can update their own username if needed.
create policy if not exists "Users can update own profile"
  on public.profiles
  for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- RPC to resolve email by username for login.
create or replace function public.get_email_by_username(p_username text)
returns text
language sql
security definer
set search_path = public, auth
as $$
  select u.email
  from public.profiles p
  join auth.users u on u.id = p.id
  where lower(p.username) = lower(p_username)
  limit 1;
$$;

grant execute on function public.get_email_by_username(text) to anon, authenticated;

-- RPC to insert profile row after sign up.
create or replace function public.create_profile(p_user_id uuid, p_username text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (p_user_id, lower(trim(p_username)));
end;
$$;

grant execute on function public.create_profile(uuid, text) to anon, authenticated;
