import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Textos e ícones dos botões de diminuir/aumentar um recurso.
class ResourceActionLabels {
  final String decrease;
  final String increase;
  final IconData decreaseIcon;
  final IconData increaseIcon;

  const ResourceActionLabels({
    required this.decrease,
    required this.increase,
    required this.decreaseIcon,
    required this.increaseIcon,
  });
}

/// Textos dos botões conforme o nome do recurso (sem diferenciar maiúsculas e
/// ignorando espaços nas pontas).
ResourceActionLabels resourceActionLabels(String resourceName) {
  final name = resourceName.trim().toLowerCase();
  if (name == 'vida' || name == 'pv') {
    return const ResourceActionLabels(
      decrease: 'Receber dano',
      increase: 'Curar',
      decreaseIcon: Icons.heart_broken_outlined,
      increaseIcon: Icons.favorite_outline,
    );
  }
  if (name == 'energia') {
    return const ResourceActionLabels(
      decrease: 'Gastar energia',
      increase: 'Recuperar energia',
      decreaseIcon: Icons.bolt_outlined,
      increaseIcon: Icons.bolt,
    );
  }
  return ResourceActionLabels(
    decrease: 'Gastar $name'.trim(),
    increase: 'Recuperar $name'.trim(),
    decreaseIcon: Icons.remove_circle_outline,
    increaseIcon: Icons.add_circle_outline,
  );
}

/// Abre a janela inferior de ajuste rápido. Retorna o delta com sinal
/// (negativo para diminuir, positivo para aumentar) ou null se o usuário fechar
/// sem aplicar.
Future<int?> showResourceQuickAdjust(
  BuildContext context, {
  required String name,
  required int current,
  required int max,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ResourceQuickAdjustSheet(name: name, current: current, max: max),
  );
}

class _ResourceQuickAdjustSheet extends StatefulWidget {
  final String name;
  final int current;
  final int max;

  const _ResourceQuickAdjustSheet({required this.name, required this.current, required this.max});

  @override
  State<_ResourceQuickAdjustSheet> createState() => _ResourceQuickAdjustSheetState();
}

class _ResourceQuickAdjustSheetState extends State<_ResourceQuickAdjustSheet> {
  static const _maxAmount = 999999;
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply(int sign) {
    final amount = int.tryParse(_controller.text) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Informe um valor maior que zero.');
      return;
    }
    Navigator.of(context).pop(sign * (amount > _maxAmount ? _maxAmount : amount));
  }

  @override
  Widget build(BuildContext context) {
    final labels = resourceActionLabels(widget.name);
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(child: Text(widget.name, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                  Text('${widget.current} / ${widget.max}', style: textTheme.titleMedium),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(labelText: 'Quantidade', errorText: _error),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(labels.decreaseIcon),
                      label: Text(labels.decrease),
                      onPressed: () => _apply(-1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(labels.increaseIcon),
                      label: Text(labels.increase),
                      onPressed: () => _apply(1),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Área de toque da barra de recurso: a barra tem só 14 px de altura, então o
/// toque ganha 6 px acima e abaixo.
class ResourceBarTapTarget extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final String label;

  const ResourceBarTapTarget({super.key, required this.child, required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ajustar $label',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: child,
        ),
      ),
    );
  }
}
