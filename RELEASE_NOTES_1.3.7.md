# RPG Sheet 1.3.7 — Fluidez e Tema Pirata

## Navegação
- Transições da navegação principal e das abas da ficha ficaram mais suaves, com curva `easeInOutCubic` e duração adaptada à distância entre páginas.
- Páginas adjacentes podem ser preparadas antecipadamente e cada página é isolada com `RepaintBoundary` para reduzir repinturas durante a animação.
- A opção **Reduzir animações** continua desativando as transições.

## Tema Sombrio Pirata
- Paleta refeita conforme a identidade oficial: azul-marinho muito escuro, preto azulado, cinza escuro e ouro envelhecido/bronze nos detalhes e bordas.
- Removidos os marrons quentes que dominavam superfícies e fundos.
- Botões, cards, menus, campos, barra inferior e indicadores receberam acabamento mais escuro e frio.
- Ícones principais e das abas da ficha receberam conjunto pirata próprio, com variações selecionadas.

## PWA
- O service worker passa a assumir a atualização imediatamente (`skipWaiting` + `clients.claim`), reduzindo casos em que o navegador continua exibindo ícones ou tema da versão anterior após uma publicação.

## Versão
- App: `1.3.7+107`.
