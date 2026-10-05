-- Snapshot de bootstrap do backend utilizado pelo RPG Sheet V1.3.5.
-- Projetado para ambiente novo; migrations continuam sendo a trilha de evolução.

create extension if not exists pgcrypto;

create table if not exists public.rpg_cloud_backups (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.rpg_shared_characters (
  owner_id uuid not null references auth.users(id) on delete cascade,
  character_id text not null,
  share_code text not null unique,
  snapshot jsonb not null default '{}'::jsonb,
  master_patch jsonb not null default '{}'::jsonb,
  master_patch_updated_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key(owner_id, character_id)
);

create table if not exists public.rpg_character_link_requests (
  id uuid primary key default gen_random_uuid(),
  share_code text not null,
  character_owner_id uuid not null references auth.users(id) on delete cascade,
  requester_id uuid not null references auth.users(id) on delete cascade,
  campaign_id text not null,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(character_owner_id, requester_id, campaign_id, share_code)
);

create table if not exists public.rpg_campaign_session_state (
  campaign_id text primary key,
  master_id uuid not null references auth.users(id) on delete cascade,
  round integer not null default 1,
  active boolean not null default false,
  current_index integer not null default 0,
  initiative jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

-- Estruturas legadas mantidas para compatibilidade com históricos antigos.
create table if not exists public.rpg_campaign_sessions (
  master_id uuid not null references auth.users(id) on delete cascade,
  campaign_id text not null,
  state jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key(master_id, campaign_id)
);

create table if not exists public.rpg_character_live_state (
  owner_id uuid not null references auth.users(id) on delete cascade,
  character_id text not null,
  share_code text not null,
  resources jsonb not null default '{}'::jsonb,
  resource_max jsonb not null default '{}'::jsonb,
  conditions jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  primary key(owner_id, character_id)
);

create table if not exists public.rpg_app_access (
  user_id uuid primary key references auth.users(id) on delete cascade,
  granted_at timestamptz not null default now(),
  source text not null default 'invite'
);

create table if not exists public.rpg_invites (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  label text not null default '',
  max_uses integer not null default 1 check(max_uses > 0),
  uses integer not null default 0 check(uses >= 0),
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.rpg_app_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.rpg_cloud_backups enable row level security;
alter table public.rpg_shared_characters enable row level security;
alter table public.rpg_character_link_requests enable row level security;
alter table public.rpg_campaign_session_state enable row level security;
alter table public.rpg_campaign_sessions enable row level security;
alter table public.rpg_character_live_state enable row level security;
alter table public.rpg_app_access enable row level security;
alter table public.rpg_invites enable row level security;
alter table public.rpg_app_admins enable row level security;

create index if not exists rpg_link_requests_campaign_status_owner_idx
  on public.rpg_character_link_requests(campaign_id,status,character_owner_id,requester_id);
create index if not exists rpg_link_requests_player_campaign_idx
  on public.rpg_character_link_requests(character_owner_id,campaign_id,status);
create index if not exists rpg_link_requests_requester_id_idx
  on public.rpg_character_link_requests(requester_id);
create index if not exists rpg_campaign_session_state_master_id_idx
  on public.rpg_campaign_session_state(master_id);

-- Realtime: adiciona somente quando ainda não está publicado.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime'
      and schemaname='public'
      and tablename='rpg_campaign_session_state'
  ) then
    alter publication supabase_realtime add table public.rpg_campaign_session_state;
  end if;
end $$;

-- Aplique em seguida as migrations versionadas deste repositório para funções,
-- grants e políticas RLS atuais.
