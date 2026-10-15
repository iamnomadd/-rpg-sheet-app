-- Desvincular ficha: o Mestre (requester) ou o jogador (dono da ficha) podem
-- apagar o pedido de vínculo. Apaga a linha em vez de só mudar o status porque
-- o UNIQUE (character_owner_id, requester_id, campaign_id, share_code)
-- impediria um novo pedido para revincular. Aditiva: não muda outras
-- políticas nem funções.
drop policy if exists "participants delete link request" on public.rpg_character_link_requests;
create policy "participants delete link request" on public.rpg_character_link_requests
for delete to authenticated
using ((select auth.uid()) = character_owner_id or (select auth.uid()) = requester_id);

-- Reversão:
-- drop policy if exists "participants delete link request" on public.rpg_character_link_requests;
