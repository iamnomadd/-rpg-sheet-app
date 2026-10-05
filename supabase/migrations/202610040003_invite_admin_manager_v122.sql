-- Applied to production in V1.2.2. Admin-only invitation management.
create table if not exists public.rpg_app_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.rpg_app_admins enable row level security;
revoke all on table public.rpg_app_admins from anon, authenticated;
-- Admin seed is intentionally omitted from distributable source.
-- Production admin assignment is managed directly in the database.
