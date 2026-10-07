import 'package:flutter/material.dart';

/// Pergunta antes de excluir. Retorna true só se o usuário confirmar; Cancelar
/// ou fechar tocando fora retorna false.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Excluir',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(confirmLabel)),
      ],
    ),
  );
  return result == true;
}
