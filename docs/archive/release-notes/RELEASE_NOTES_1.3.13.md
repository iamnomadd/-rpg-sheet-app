# RPG Sheet 1.3.13+113

## Workflow de testes por ZIP
- O GitHub Actions agora suporta o formato real do repositório, no qual as versões do RPG Sheet são enviadas como arquivos ZIP.
- Se houver um projeto Flutter extraído na raiz, ele continua sendo usado normalmente.
- Caso contrário, o workflow localiza automaticamente o pacote `rpg_sheet_app_v*.zip` de versão mais recente, descompacta em área temporária e encontra o `pubspec.yaml` antes de executar o Flutter.
- `flutter pub get`, análise, testes e build passam a ser executados no diretório correto do projeto extraído.
- O resultado do `build/web` é copiado para um artefato isolado e publicado somente no projeto de testes `rpg-sheet-test` do Cloudflare Pages.
- Nenhuma etapa de deploy para Netlify foi adicionada.

## Aplicação
- Mantidas as alterações funcionais da 1.3.12, incluindo o Resumo ampliado das fichas de NPC/Monstro no Modo Mestre.
- Nenhuma alteração de banco de dados nesta versão.
