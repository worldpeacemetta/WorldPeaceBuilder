-- Profiles table for username-based login
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  display_username text,
  avatar_url text,
  created_at timestamptz not null default now()
);

update public.profiles
set display_username = username
where display_username is null;

alter table public.profiles enable row level security;

-- Users can only read their own profile row.
create policy if not exists "Users can read own profile"
  on public.profiles
  for select
  to authenticated
  using (auth.uid() = id);

-- Users can only update their own profile row.
create policy if not exists "Users can update own profile"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Username lookup RPC for username-based sign in.
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

-- Auto-create profile row from auth.users metadata at registration time.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, display_username)
  values (
    new.id,
    lower(trim(new.raw_user_meta_data->>'username')),
    coalesce(nullif(trim(new.raw_user_meta_data->>'display_username'), ''), nullif(trim(new.raw_user_meta_data->>'username'), ''))
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();
