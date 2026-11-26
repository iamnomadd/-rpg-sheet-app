-- V1.3.72: entrada liberada ("Criar conta" sem código de convite).
-- Libera o acesso ao Grimório para a conta autenticada que chamar a função.
-- Não altera rpg_invites, redeem_rpg_invite, has_rpg_app_access nem outras
-- funções/tabelas: os convites e os acessos já concedidos continuam valendo.
create or replace function public.claim_rpg_open_access() returns boolean
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'authentication required'; end if;
 insert into public.rpg_app_access(user_id,source) values(auth.uid(),'open') on conflict(user_id) do nothing;
 return true;
end $$;
revoke all on function public.claim_rpg_open_access() from public,anon;
grant execute on function public.claim_rpg_open_access() to authenticated;
