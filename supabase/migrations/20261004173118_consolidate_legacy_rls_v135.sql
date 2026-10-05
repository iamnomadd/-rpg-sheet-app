-- V1.3.5: consolida políticas legadas sem alterar o modelo de autorização.
drop policy if exists "approved players read campaign session" on public.rpg_campaign_sessions;
drop policy if exists "master manages campaign session" on public.rpg_campaign_sessions;
create policy "campaign session participants read" on public.rpg_campaign_sessions
for select to authenticated using (
  (select auth.uid()) = master_id or exists (
    select 1 from public.rpg_character_link_requests r
    where r.requester_id = rpg_campaign_sessions.master_id
      and r.campaign_id = rpg_campaign_sessions.campaign_id
      and r.character_owner_id = (select auth.uid())
      and r.status = 'approved'
  )
);
create policy "master inserts campaign session" on public.rpg_campaign_sessions
for insert to authenticated with check ((select auth.uid()) = master_id);
create policy "master updates campaign session" on public.rpg_campaign_sessions
for update to authenticated using ((select auth.uid()) = master_id)
with check ((select auth.uid()) = master_id);
create policy "master deletes campaign session" on public.rpg_campaign_sessions
for delete to authenticated using ((select auth.uid()) = master_id);

drop policy if exists "approved master reads character live state" on public.rpg_character_live_state;
drop policy if exists "owner manages character live state" on public.rpg_character_live_state;
create policy "character live state participants read" on public.rpg_character_live_state
for select to authenticated using (
  (select auth.uid()) = owner_id or exists (
    select 1 from public.rpg_character_link_requests l
    where l.character_owner_id = rpg_character_live_state.owner_id
      and l.share_code = rpg_character_live_state.share_code
      and l.requester_id = (select auth.uid())
      and l.status = 'approved'
  )
);
create policy "owner inserts character live state" on public.rpg_character_live_state
for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy "owner updates character live state" on public.rpg_character_live_state
for update to authenticated using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);
create policy "owner deletes character live state" on public.rpg_character_live_state
for delete to authenticated using ((select auth.uid()) = owner_id);

drop policy if exists "approved masters read shared characters" on public.rpg_shared_characters;
drop policy if exists "authorized master reads shared characters" on public.rpg_shared_characters;
drop policy if exists "owner manages shared characters" on public.rpg_shared_characters;
drop policy if exists "shared character authorized read" on public.rpg_shared_characters;
create policy "shared character participants read" on public.rpg_shared_characters
for select to authenticated using (
  (select auth.uid()) = owner_id or exists (
    select 1 from public.rpg_character_link_requests r
    where r.character_owner_id = rpg_shared_characters.owner_id
      and r.share_code = rpg_shared_characters.share_code
      and r.requester_id = (select auth.uid())
      and r.status = 'approved'
  )
);
create policy "owner inserts shared character" on public.rpg_shared_characters
for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy "owner updates shared character" on public.rpg_shared_characters
for update to authenticated using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);
create policy "owner deletes shared character" on public.rpg_shared_characters
for delete to authenticated using ((select auth.uid()) = owner_id);
