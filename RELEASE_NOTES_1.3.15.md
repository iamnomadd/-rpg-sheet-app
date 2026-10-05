# RPG Sheet 1.3.15+115

## Correção — Vida de NPCs/Monstros
- Corrigido o ajuste rápido de **Receber dano** e **Curar** na ficha de NPC/Monstro do Modo Mestre.
- A tela agora usa a mesma regra das fichas de player: dano reduz a Vida atual sem passar de 0 e cura aumenta sem ultrapassar a Vida máxima.
- O cálculo considera o valor atual e o máximo que estiverem visíveis no editor, em vez de valores antigos capturados ao abrir a janela.
- Após salvar, `Vida`, `hp` e `maxHp` permanecem sincronizados e a ficha é atualizada imediatamente.
- Nenhuma alteração de banco de dados.
