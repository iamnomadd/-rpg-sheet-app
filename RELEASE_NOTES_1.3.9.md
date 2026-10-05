# RPG Sheet 1.3.9 — Fichas de NPCs e Monstros

## Modo Mestre
- A aba **NPCs** passa a aceitar fichas completas controladas pelo Mestre.
- Novo fluxo **Criar NPC / Monstro**, com tipo `NPC`, `Monstro`, `Aliado` ou `Chefe`.
- É possível escolher o sistema usado como base para atributos, perícias e recursos.
- Novo fluxo **Usar ficha existente**: uma ficha da aba Fichas pode ser copiada para a campanha como NPC.
- A cópia é independente: alterações no NPC não alteram a ficha original e vice-versa.
- NPCs antigos de nome simples podem ser convertidos para o novo formato de ficha.
- NPCs completos podem ser duplicados para preparar grupos de inimigos rapidamente.

## Ficha de NPC
- Nova tela com abas: **Resumo, Status, Ações, Habilidades, Inventário e Notas**.
- Controle de atributos e recursos diretamente pelo Mestre.
- Vida/recursos suportam edição manual, **Receber dano** e **Curar**.
- Condições podem ser adicionadas e removidas.
- Ataques, dano, poderes, habilidades e inventário podem ser cadastrados e editados.
- Notas privadas do Mestre ficam dentro da própria ficha do NPC.

## Combate
- NPCs completos usam IDs estáveis na iniciativa.
- Ao tocar em um NPC completo na iniciativa, o Mestre abre sua ficha para controlar recursos/condições durante o combate.
- NPCs completos podem ser adicionados ao iniciar a iniciativa ou durante um combate em andamento.

## Importação e exportação
- Exportação de Mestre preserva fichas completas de NPCs.
- Pacote de jogadores não inclui a ficha completa dos NPCs, evitando expor estatísticas/notas privadas.
- Ao importar uma campanha, IDs de NPCs e referências de iniciativa são remapeados para cópias independentes.

## Compatibilidade
- Campanhas antigas continuam aceitas por meio da lista legada de NPCs simples.
- Nenhuma migração de Supabase é necessária nesta versão.

**Versão:** `1.3.9+109`
