-- V1.2.1: access gate + invitation redemption. Existing users are grandfathered.
create table if not exists public.rpg_app_access (
 user_id uuid primary key references auth.users(id) on delete cascade,
 granted_at timestamptz not null default now(), source text not null default 'invite');
alter table public.rpg_app_access enable row level security;
revoke all on public.rpg_app_access from anon;
grant select on public.rpg_app_access to authenticated;
drop policy if exists "users read own app access" on public.rpg_app_access;
create policy "users read own app access" on public.rpg_app_access for select to authenticated using(auth.uid()=user_id);
insert into public.rpg_app_access(user_id,source) select id,'legacy' from auth.users on conflict(user_id) do nothing;
create table if not exists public.rpg_invites (
 id uuid primary key default gen_random_uuid(), code text not null unique,label text not null default '',
 max_uses integer not null default 1 check(max_uses>0),uses integer not null default 0 check(uses>=0),
 expires_at timestamptz,revoked_at timestamptz,created_at timestamptz not null default now());
alter table public.rpg_invites enable row level security;
revoke all on public.rpg_invites from anon,authenticated;
create or replace function public.redeem_rpg_invite(p_code text) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.rpg_invites%rowtype;
begin
 if auth.uid() is null then raise exception 'authentication required'; end if;
 if exists(select 1 from public.rpg_app_access where user_id=auth.uid()) then return true; end if;
 select * into v from public.rpg_invites where upper(code)=upper(trim(p_code)) and revoked_at is null and (expires_at is null or expires_at>now()) and uses<max_uses for update;
 if not found then return false; end if;
 update public.rpg_invites set uses=uses+1 where id=v.id;
 insert into public.rpg_app_access(user_id,source) values(auth.uid(),'invite') on conflict(user_id) do nothing;
 return true;
end $$;
revoke all on function public.redeem_rpg_invite(text) from public,anon;
grant execute on function public.redeem_rpg_invite(text) to authenticated;
create or replace function public.has_rpg_app_access() returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select auth.uid() is not null and exists(select 1 from public.rpg_app_access where user_id=auth.uid()) $$;
revoke all on function public.has_rpg_app_access() from public,anon;
grant execute on function public.has_rpg_app_access() to authenticated;
