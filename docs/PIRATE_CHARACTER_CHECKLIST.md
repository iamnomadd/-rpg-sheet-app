# Checklist — Personagem 2D do Tema Pirata

## Regra visual obrigatória
- [x] Usar exclusivamente o pirata esqueleto em pixel art aprovado.
- [x] Não usar CustomPainter, formas geométricas ou versão simplificada como personagem final.
- [x] Manter o mesmo personagem e a mesma identidade visual em todos os estados.
- [x] Alterar somente pose/expressão corporal entre Normal, Crítico e Incapacitado.

## Identidade do personagem
- [x] Caveira/esqueleto visível.
- [x] Braços, antebraços, mãos e dedos com aparência óssea.
- [x] Bandana vermelha.
- [x] Colete azul-escuro.
- [x] Botas e cinto em tons de marrom.
- [x] Corda e medalhão.
- [x] Roupa e acabamento gastos de aventureiro/pirata.
- [x] Pixel art detalhada compatível com o estilo visual aprovado.

## Estados
- [x] Normal: pirata esqueleto em pé.
- [x] Crítico: o mesmo pirata esqueleto abatido/curvado.
- [x] Incapacitado: o mesmo pirata esqueleto sentado/caído.
- [x] Nenhum estado pode retornar ao sprite humano padrão.

## Implementação
- [x] Assets dedicados em assets/character2d/pirate_normal.webp, pirate_critical.webp e pirate_incapacitated.webp.
- [x] Renderização com FilterQuality.none e antialias desativado para preservar o pixel art.
- [x] Tema Sombrio Pirata seleciona os três assets conforme o estado atual.
