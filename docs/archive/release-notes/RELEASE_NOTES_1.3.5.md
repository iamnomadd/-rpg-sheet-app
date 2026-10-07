# RPG Sheet 1.3.5 — Backend e Manutenção

- Mantém todas as correções funcionais da V1.3.4.
- Supabase de produção recebeu índices para `rpg_campaign_session_state.master_id` e `rpg_character_link_requests.requester_id`.
- Políticas RLS redundantes foram consolidadas em estado de sessão, sessões legadas, estado ao vivo e fichas compartilhadas.
- Avisos de performance de RLS (`auth_rls_initplan` e políticas permissivas duplicadas) foram eliminados; restam apenas índices novos/legados ainda sem uso registrado.
- Migrations V1.3.5 adicionadas ao repositório e documentação de backend criada em `supabase/README.md`.
- Adicionado `supabase/full_setup_1.3.5.sql` como bootstrap documentado do esquema usado pela versão atual.
- Flutter do CI fixado em 3.47.5 e dependências diretas fixadas em versões exatas para reduzir variações de build.
- O componente “Seu Turno” foi extraído de `character_screen.dart` para `player_turn_banner.dart`, reduzindo acoplamento da tela de ficha.
- Novos testes cobrem estado completo de campanha e restauração de preferências modernas.

## Hotfix de build +106

- Corrigida a dependência direta `supabase` de `2.15.4` para `^2.14.0`, faixa disponível e compatível com o resolvedor do Flutter/Dart usado no CI.
- Número de build e cache do PWA atualizados para `1.3.5+106`.
- Nenhuma alteração funcional ou de banco de dados nesta correção.
