create table if not exists public.rpg_cloud_backups (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.rpg_cloud_backups enable row level security;

drop policy if exists "users read own backup" on public.rpg_cloud_backups;
create policy "users read own backup"
on public.rpg_cloud_backups for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "users insert own backup" on public.rpg_cloud_backups;
create policy "users insert own backup"
on public.rpg_cloud_backups for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "users update own backup" on public.rpg_cloud_backups;
create policy "users update own backup"
on public.rpg_cloud_backups for update
to authenticated
using (auth.uid() = user_id)
with check ((select auth.uid()) = user_id);


drop policy if exists "users delete own backup" on public.rpg_cloud_backups;
create policy "users delete own backup"
on public.rpg_cloud_backups for delete
to authenticated
using ((select auth.uid()) = user_id);


-- V1.1.1: compartilhamento de fichas com Mestre
create table if not exists public.rpg_shared_characters (owner_id uuid not null references auth.users(id) on delete cascade, character_id text not null, share_code text not null unique, snapshot jsonb not null default '{}'::jsonb, updated_at timestamptz not null default now(), primary key(owner_id, character_id));
create table if not exists public.rpg_character_link_requests (id uuid primary key default gen_random_uuid(), share_code text not null, character_owner_id uuid not null references auth.users(id) on delete cascade, requester_id uuid not null references auth.users(id) on delete cascade, campaign_id text not null, status text not null default 'pending', created_at timestamptz not null default now(), updated_at timestamptz not null default now());
