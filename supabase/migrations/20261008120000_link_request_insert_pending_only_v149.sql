-- Segurança: quem cria um pedido de vínculo não pode gravá-lo já como
-- 'approved'. A leitura de rpg_shared_characters e set_rpg_master_patch
-- confiam em status = 'approved'; sem esta restrição, o solicitante se
-- auto-aprovava e lia/alterava a ficha de outra pessoa. A aprovação continua
-- sendo feita só pelo dono da ficha (política "owner updates link request").
drop policy if exists "requester creates link request" on public.rpg_character_link_requests;
create policy "requester creates link request" on public.rpg_character_link_requests
for insert to authenticated
with check ((select auth.uid()) = requester_id and status = 'pending');

-- Reversão (recria a política antiga, sem a restrição de status):
-- drop policy if exists "requester creates link request" on public.rpg_character_link_requests;
-- create policy "requester creates link request" on public.rpg_character_link_requests
-- for insert to authenticated with check ((select auth.uid()) = requester_id);
