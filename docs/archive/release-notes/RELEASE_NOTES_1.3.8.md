# RPG Sheet 1.3.8 — Controle rápido de Vida

## Novidades

- A janela de configuração de **Vida** agora possui duas ações rápidas:
  - **Receber dano**: informa o dano recebido e o app desconta automaticamente da vida atual.
  - **Curar**: informa a cura recebida e o app soma automaticamente à vida atual.
- O dano nunca reduz a vida abaixo de `0`.
- A cura nunca ultrapassa a vida máxima configurada.
- O ajuste manual de valor atual/máximo continua disponível.
- O mesmo comportamento foi aplicado ao controle de Vida da aba **Em Cena/Ações** para manter a ficha consistente.

### Exemplo

- Vida atual: `20 / 20`
- Dano recebido: `15`
- Resultado: `5 / 20`

## Testes

Foi adicionada cobertura para:
- desconto automático de dano;
- limite mínimo em zero;
- limite de cura pela vida máxima.

## Versão

- App/PWA: `1.3.8+108`.
