# RPG Sheet 1.3.14+114

## Minha Conta e dados
- A central **Backup, importação e nuvem** foi movida de Configurações para **Minha Conta**.
- Backup local, importação/exportação e sincronização continuam disponíveis na mesma central, agora agrupados junto às funções da conta.
- O atalho permanece acessível mesmo sem sessão conectada, porque importação e backup local não dependem da nuvem.

## Versão
- Corrigida a identificação visual que ainda mostrava `V1.3.11`.
- Metadados internos de backup e exportação agora usam uma constante única de versão.
- Versão do pacote e cache do PWA atualizados para `1.3.14+114`.

## Deploy de testes
- Mantido o workflow GitHub Actions → Cloudflare Pages (`rpg-sheet-test.pages.dev`).
- O workflow continua compatível com o projeto enviado como ZIP na raiz do repositório.
- Nenhuma etapa de deploy para Netlify foi adicionada.
