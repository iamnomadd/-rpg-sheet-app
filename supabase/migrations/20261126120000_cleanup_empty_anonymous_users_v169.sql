-- 1.3.69: limpeza de contas anônimas vazias.
--
-- Apaga (e devolve quantos) usuários de auth.users que sejam TODOS estes:
--   * anônimos (is_anonymous = true);
--   * criados e sem entrar (last_sign_in_at, ou created_at se nulo) há mais
--     que p_min_age (padrão: 30 dias);
--   * sem backup na nuvem, ou com backup sem fichas e sem campanhas;
--   * sem ficha compartilhada, sem pedido de vínculo (como dono ou como
--     solicitante), sem sessão de campanha (antiga ou atual), sem estado ao
--     vivo de ficha, sem acesso liberado ao app e sem ser administrador.
-- Antes de apagar cada usuário, apaga a linha dele em rpg_cloud_backups.
--
-- Só o service role/administrador roda (EXECUTE revogado de public, anon e
-- authenticated). NÃO há agendamento (pg_cron não está instalado):
--   select public.cleanup_empty_anonymous_users();
--   select public.cleanup_empty_anonymous_users(interval '60 days');

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
     and not exists (select 1 from public.rpg_app_access a where a.user_id = u.id)
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
