-- User badges table
create table if not exists public.user_badges (
  user_id  uuid not null references auth.users(id) on delete cascade,
  badge_id text not null,
  primary key (user_id, badge_id)
);

alter table public.user_badges enable row level security;

drop policy if exists "user_badges_select_own" on public.user_badges;
create policy "user_badges_select_own"
  on public.user_badges for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "user_badges_insert_own" on public.user_badges;
create policy "user_badges_insert_own"
  on public.user_badges for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "user_badges_delete_own" on public.user_badges;
create policy "user_badges_delete_own"
  on public.user_badges for delete
  to authenticated
  using (user_id = auth.uid());

grant select, insert, delete on public.user_badges to authenticated;
