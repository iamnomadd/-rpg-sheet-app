-- V1.3.5: índices e RLS do estado de sessão.
create index if not exists rpg_campaign_session_state_master_id_idx
  on public.rpg_campaign_session_state(master_id);

create index if not exists rpg_link_requests_requester_id_idx
  on public.rpg_character_link_requests(requester_id);

drop policy if exists "approved players read session" on public.rpg_campaign_session_state;
drop policy if exists "approved players read session state" on public.rpg_campaign_session_state;
drop policy if exists "linked players read session state" on public.rpg_campaign_session_state;
drop policy if exists "master manages session" on public.rpg_campaign_session_state;
drop policy if exists "master manages session state" on public.rpg_campaign_session_state;

create policy "session participants read state"
on public.rpg_campaign_session_state
for select to authenticated
using (
  (select auth.uid()) = master_id
  or exists (
    select 1 from public.rpg_character_link_requests l
    where l.campaign_id = rpg_campaign_session_state.campaign_id
      and l.character_owner_id = (select auth.uid())
      and l.status = 'approved'
  )
);
create policy "master inserts session state" on public.rpg_campaign_session_state
for insert to authenticated with check ((select auth.uid()) = master_id);
create policy "master updates session state" on public.rpg_campaign_session_state
for update to authenticated using ((select auth.uid()) = master_id)
with check ((select auth.uid()) = master_id);
create policy "master deletes session state" on public.rpg_campaign_session_state
for delete to authenticated using ((select auth.uid()) = master_id);

drop policy if exists "participants read link requests" on public.rpg_character_link_requests;
create policy "participants read link requests" on public.rpg_character_link_requests
for select to authenticated
using ((select auth.uid()) = character_owner_id or (select auth.uid()) = requester_id);

drop policy if exists "requester creates link request" on public.rpg_character_link_requests;
create policy "requester creates link request" on public.rpg_character_link_requests
for insert to authenticated with check ((select auth.uid()) = requester_id);

drop policy if exists "users read own app access" on public.rpg_app_access;
create policy "users read own app access" on public.rpg_app_access
for select to authenticated using ((select auth.uid()) = user_id);
