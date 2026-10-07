# Publicação Web automática — V1.2.2
Use `build-web-netlify-auto-v1.2.2.yml` em `.github/workflows/` no repositório que recebe os ZIPs de versão.
Configure GitHub Actions secrets: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `NETLIFY_AUTH_TOKEN`, `NETLIFY_SITE_ID`.
Depois disso, cada novo `rpg_sheet_app_v*.zip` enviado à branch `main` dispara build, testes, artifact e deploy de produção no Netlify.
O PWA também avisa quando um novo Service Worker estiver pronto e oferece o botão Atualizar.
