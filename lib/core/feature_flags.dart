/// Interruptores de recursos do app.
library;

/// Aba Dados escondida desde 1.3.52; true reativa.
///
/// Só tira a aba "Dados" da barra inferior e do PageView. A DiceScreen, o
/// histórico de rolagens (`diceHistory`) e as preferências continuam intactos.
/// É mutável de propósito: os testes que dependem da aba ligam no setUp e
/// desligam no tearDown.
bool diceTabEnabled = false;
