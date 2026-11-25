import 'package:flutter/widgets.dart';

/// Chama [onRemoved] quando sai da árvore. Usado nos diálogos de edição para
/// liberar os controladores de texto só depois que o diálogo termina de fechar
/// (a animação de saída ainda redesenha os campos).
class DisposeOnRemoved extends StatefulWidget {
  final VoidCallback onRemoved;
  final Widget child;

  const DisposeOnRemoved({super.key, required this.onRemoved, required this.child});

  @override
  State<DisposeOnRemoved> createState() => _DisposeOnRemovedState();
}

class _DisposeOnRemovedState extends State<DisposeOnRemoved> {
  @override
  void dispose() {
    widget.onRemoved();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
