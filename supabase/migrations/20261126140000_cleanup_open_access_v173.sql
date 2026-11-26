-- 1.3.73: limpeza de contas anônimas vazias também com acesso 'open'.
--
-- Recria public.cleanup_empty_anonymous_users (1.3.69) com a MESMA
-- assinatura, as MESMAS permissões e as MESMAS regras de "conta vazia",
-- mudando SOMENTE a regra do rpg_app_access:
--   * antes: qualquer linha em rpg_app_access protegia a conta anônima;
--   * agora: só protege acesso com source diferente de 'open'. Uma conta
--     anônima vazia que só tem acesso 'open' (por exemplo, um "Criar conta"
--     que falhou depois do claim_rpg_open_access) passa a ser apagada; a
--     linha dela em rpg_app_access sai junto (on delete cascade).
-- Contas com e-mail (não anônimas) nunca são apagadas.
--
-- Só o service role/administrador roda (EXECUTE revogado de public, anon e
-- authenticated). NÃO há agendamento:
--   select public.cleanup_empty_anonymous_users();

create or replace function public.cleanup_empty_anonymous_users(p_min_age interval default interval '30 days')
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_ids uuid[];
  v_count integer := 0;
begin
  select coalesce(array_agg(u.id), '{}'::uuid[])
    into v_ids
    from auth.users u
   where u.is_anonymous = true
     and u.created_at < now() - p_min_age
     and coalesce(u.last_sign_in_at, u.created_at) < now() - p_min_age
     -- Sem backup, ou backup sem fichas e sem campanhas.
     and not exists (
       select 1
         from public.rpg_cloud_backups b
        where b.user_id = u.id
          and (
            (jsonb_typeof(b.payload -> 'characters') = 'array' and jsonb_array_length(b.payload -> 'characters') > 0)
            or (jsonb_typeof(b.payload -> 'campaigns') = 'array' and jsonb_array_length(b.payload -> 'campaigns') > 0)
          )
     )
     and not exists (select 1 from public.rpg_shared_characters s where s.owner_id = u.id)
     and not exists (select 1 from public.rpg_character_link_requests r where r.character_owner_id = u.id or r.requester_id = u.id)
     and not exists (select 1 from public.rpg_campaign_sessions cs where cs.master_id = u.id)
     and not exists (select 1 from public.rpg_campaign_session_state st where st.master_id = u.id)
     and not exists (select 1 from public.rpg_character_live_state ls where ls.owner_id = u.id)
     -- 1.3.73: acesso 'open' (Criar conta) sozinho não protege mais a conta
     -- anônima vazia; acesso de outra origem (convite, legado...) protege.
     and not exists (select 1 from public.rpg_app_access a where a.user_id = u.id and a.source <> 'open')
     and not exists (select 1 from public.rpg_app_admins ad where ad.user_id = u.id);

  if coalesce(array_length(v_ids, 1), 0) = 0 then
    return 0;
  end if;

  delete from public.rpg_cloud_backups where user_id = any(v_ids);
  delete from auth.users where id = any(v_ids);
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.cleanup_empty_anonymous_users(interval) from public, anon, authenticated;
