# RPG Sheet 1.3.10 — Ambiente de testes Cloudflare Pages

**Versão:** `1.3.10+110`

## Objetivo

Separar o ambiente de testes do ambiente oficial de produção para que novas versões possam ser validadas sem consumir deploys do Netlify.

## Alterações

- GitHub Actions continua responsável por instalar dependências, analisar, testar e compilar o Flutter Web.
- Após um build bem-sucedido, `build/web` é enviado automaticamente ao Cloudflare Pages.
- Projeto de testes configurado no workflow: `rpg-sheet-test`.
- URL estável de testes: `https://rpg-sheet-test.pages.dev`.
- Autenticação do deploy feita apenas por repository secrets:
  - `CLOUDFLARE_API_TOKEN`
  - `CLOUDFLARE_ACCOUNT_ID`
- O artefato `rpg-sheet-web` continua sendo gerado no GitHub Actions.
- Supabase continua sendo configurado no build pelos secrets existentes `SUPABASE_URL` e `SUPABASE_ANON_KEY`.
- Nenhuma alteração de banco de dados nesta versão.

## Fluxo recomendado

1. Subir a nova versão no GitHub.
2. GitHub Actions compila e publica automaticamente no Cloudflare Pages de testes.
3. Validar a versão em `rpg-sheet-test.pages.dev`.
4. Corrigir em uma nova versão se necessário.
5. Publicar no Netlify somente quando a versão estiver aprovada.
