# Supabase — RPG Sheet

O backend de produção usa Supabase Auth, PostgREST e Realtime.

## Estado da V1.3.5

As migrations `20261004173033_stability_indexes_and_rls_v135.sql` e
`20261004173118_consolidate_legacy_rls_v135.sql` foram aplicadas ao projeto de
produção. Elas adicionam índices para o fluxo de sessão/turno e consolidam RLS
redundante sem alterar o modelo de autorização.

`rpg_campaign_session_state` deve permanecer na publication
`supabase_realtime`, pois o aviso **Seu Turno** depende dessa tabela.

## Fonte de verdade

- `setup.sql`: bootstrap das tabelas principais.
- `migrations/`: mudanças versionadas mantidas no repositório.
- Nunca exponha `service_role` no Flutter Web/PWA.
- RPCs `SECURITY DEFINER` devem validar `auth.uid()`/papel internamente e ter
  `EXECUTE` concedido apenas aos papéis realmente necessários.

As tabelas legadas `rpg_campaign_sessions` e `rpg_character_live_state` são
mantidas por compatibilidade, mas a V1.3.5 usa `rpg_campaign_session_state` como
estado de sessão em tempo real.
