# RPG Sheet — regras do projeto para o Claude Code

App Flutter de fichas de RPG de mesa (Web/PWA e Android). Repositório: iamnomadd/-rpg-sheet-app. Responda e escreva mensagens de PR em português.

## Fluxo de trabalho (obrigatório)
- Nunca faça push direto na main. Trabalhe numa branch nova e abra um pull request. Nunca faça merge: quem revisa e mescla é o dono do projeto.
- Faça SOMENTE o que foi pedido. Não refatore, não renomeie, não adicione dependências e não altere outros temas, telas, workflows ou testes sem pedido explícito.
- Se algo fora do escopo precisar mudar, pare e avise em vez de mudar.
- Antes de editar, confirme o estado atual da main (versão e arquivos envolvidos). Se algo não bater com o pedido, pare e avise.
- Rode `flutter pub get`, `flutter analyze` e `flutter test` quando o ambiente tiver o Flutter e informe o resultado real. Se não tiver, diga isso claramente em vez de afirmar que passou.
- No PR, liste exatamente os arquivos alterados e o resultado da validação. Nunca invente hash, status de deploy ou resultado de teste.

## Versão (toda mudança que chega ao app)
Suba a versão para a PRÓXIMA acima da atual da main (nunca igual nem abaixo), nos 4 arquivos, sempre no mesmo formato X.Y.Z+N:
- pubspec.yaml (`version:`)
- lib/core/app_version.dart (`appVersion` e `appBuildNumber`)
- web/version.json (`version`, `build`, `fullVersion`)
- web/rpg_service_worker.js (`const VERSION='X.Y.Z+N';`)
Os arquivos estáticos usam cache primeiro, então sem subir a versão os usuários continuam vendo a antiga.

## Temas e personagem 2D
- Cada tema tem identidade própria e, quando aplicável, personagem próprio. IDs internos: Vampírico = 'vampire'; Cyberpunk = 'cyberpunk'; Pirata = 'parchment'. Os ids não são previsíveis: confirme em lib/app/theme.dart antes de usar.
- O widget de combate é `_CombatCharacter2D`, em lib/screens/character/character_screen.dart. Os sprites ficam em assets/character2d/. Os temas sem personagem próprio usam normal.png, agony.png e incapacitated.png.
- Nunca altere o personagem de um tema ao mexer em outro.
- Pose por vida (já implementada em `_pose`, não altere sem pedido): vida <= 0 incapacitado; vida > 0 e <= 30% crítico; 31% a 40% agony; condição negativa também usa agony quando não está crítico; demais normal.
- Renderização dos sprites: BoxFit.contain, FilterQuality.none, isAntiAlias false, mesma área fixa nos estados. O card (altura 220) não pode mudar de altura entre estados.
- Animação do estado Crítico dos temas com sprite próprio: movimento SOMENTE em pixels inteiros (1 a 2 px), sem escala nem rotação no sprite, para não borrar o pixel art. Com "reduzir movimento" ativado, X e Y ficam em 0. Não altere a animação dos temas que já estão no ar sem pedido explícito.

## Imagens (sprites)
- Você não gera nem altera imagens. As artes são criadas e aprovadas pelo dono do projeto e já chegam em assets/character2d/ com nomes exclusivos por tema (por exemplo, vampiric_normal.png, vampiric_agony.png, vampiric_critical.png, vampiric_incapacitated.png). Não sobrescreva sprites existentes.
- Padrão das artes: mesmo canvas nos 4 estados do tema, alfa real (só 0 e 255), nenhum pixel tocando a borda, mesma linha de base e mesma escala.

## Deploy
- O deploy é automático a partir da main (workflow "Build and Deploy RPG Sheet to Cloudflare Test"): pub get, analyze, testes, build e deploy. O CI usa `--no-fatal-infos --no-fatal-warnings`; os avisos antigos do analyze existem na main e não são regressão.
- Nunca altere workflows, assinatura do Android ou configurações de nuvem (Supabase, Cloudflare) sem pedido explícito. Não inclua segredos, chaves ou senhas em nenhum arquivo.
