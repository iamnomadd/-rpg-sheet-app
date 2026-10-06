# RPG Sheet — instruções para Claude Code

Este repositório contém o RPG Sheet, desenvolvido em Flutter/Dart.

## Papel do Claude Code

O Claude Code atua como executor técnico das tarefas especificadas em Issues e Pull Requests. Implemente somente o escopo solicitado e deixe decisões de produto, UX e arquitetura fora do escopo para revisão humana/ChatGPT.

## Regras obrigatórias

- Nunca faça alterações diretamente na branch `main`.
- Trabalhe em branch própria e entregue as mudanças por Pull Request.
- Não remova funcionalidades existentes sem instrução explícita.
- Preserve compatibilidade com fichas/dados existentes sempre que possível.
- Não altere Supabase, Cloudflare, autenticação, secrets ou configuração de deploy sem solicitação explícita.
- Não atualize Flutter, Dart ou dependências apenas por conveniência.
- Não adicione dependências novas se a tarefa puder ser resolvida com o projeto atual.
- Não exponha, imprima ou grave secrets/tokens no repositório, logs, Issues ou PRs.
- Mantenha a alteração restrita aos arquivos necessários para a tarefa.

## Validação mínima

Antes de considerar uma implementação concluída:

1. Execute `flutter pub get` quando necessário.
2. Execute `flutter analyze --no-fatal-infos --no-fatal-warnings`.
3. Execute `flutter test`.
4. Quando a tarefa afetar Web, execute `flutter build web --release` se o ambiente permitir.
5. Informe no PR quais validações foram executadas e seus resultados.

## Pull Requests

Todo PR criado pelo Claude deve conter:

- objetivo da tarefa;
- resumo das alterações;
- arquivos principais modificados;
- testes/validações executados;
- riscos ou pontos que precisam de revisão;
- itens que ficaram fora do escopo.

Se houver dúvida sobre um requisito, não invente comportamento novo. Registre a dúvida no PR/Issue e preserve o comportamento existente.

## Fluxo do projeto

O fluxo esperado é:

`Usuário -> ChatGPT -> Issue/PR no GitHub -> Claude Code -> PR -> CI -> revisão do ChatGPT/usuário -> merge`

O GitHub é a fonte oficial do estado do projeto e do histórico das alterações.
