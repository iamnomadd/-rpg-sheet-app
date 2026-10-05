drop policy if exists "authenticated lookup share code" on public.rpg_shared_characters;
drop policy if exists "participants update link request" on public.rpg_character_link_requests;
create policy "owner updates link request"
on public.rpg_character_link_requests
for update to authenticated
using ((select auth.uid()) = character_owner_id)
with check ((select auth.uid()) = character_owner_id);
