# RPG Sheet 1.3.4 — Estabilidade e Refinamento

- Sessão Supabase mais resistente a múltiplas abas/PWAs, reaproveitando o refresh token mais recente e evitando tempestades de renovação.
- Acesso offline permitido por até 7 dias quando a conta já foi validada online neste dispositivo.
- “Seu Turno” acompanha o estado real da conexão Realtime, renova o token usado pelo canal e mantém polling rápido apenas como fallback.
- Backup local atualizado para schema 4 / app 1.3.4 e agora inclui Modo Mestre e Reduzir animações de forma consistente.
- Exportação de campanha preserva cena, objetivos, log, combate e turno; importação remapeia IDs de iniciativa.
- Importação de personagem preserva condições, ordem das ações e grupos ocultos.
- Imagem 2D escolhida no Web/PWA passa a ser incorporada de forma persistente à ficha (com limite de tamanho), em vez de depender de URL blob temporária.
- “Reduzir animações” e a preferência de acessibilidade do sistema agora afetam as transições principais e o banner de turno.
- Escala de texto do RPG Sheet passa a respeitar a escala configurada no dispositivo/navegador.
- Removida opção “Compartilhar com Mestre” sem ação no menu individual do inventário.
- Terminologia do PWA e do Sistema Padrão revisada.
