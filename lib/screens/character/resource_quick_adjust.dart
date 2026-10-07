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

/// Valores finais de um recurso (atual e máximo).
@immutable
class ResourceValues {
  final int current;
  final int max;

  const ResourceValues({required this.current, required this.max});

  @override
  bool operator ==(Object other) => other is ResourceValues && other.current == current && other.max == max;

  @override
  int get hashCode => Object.hash(current, max);

  @override
  String toString() => 'ResourceValues($current / $max)';
}

/// Abre a folha do recurso com atual e máximo editáveis e o ajuste por
/// quantidade (dano/cura, gastar/recuperar). Retorna os valores finais ou null
/// se o usuário fechar sem salvar.
Future<ResourceValues?> showResourceQuickAdjust(
  BuildContext context, {
  required String name,
  required int current,
  required int max,
}) {
  return showModalBottomSheet<ResourceValues>(
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
  static const _invalidNumber = 'Informe um número válido.';
  static final _numberFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(6),
  ];

  late final _currentController = TextEditingController(text: '${widget.current < 0 ? 0 : widget.current}');
  late final _maxController = TextEditingController(text: '${widget.max < 0 ? 0 : widget.max}');
  final _amountController = TextEditingController();
  String? _currentError;
  String? _maxError;
  String? _amountError;

  @override
  void dispose() {
    _currentController.dispose();
    _maxController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// Lê atual e máximo digitados; null (com erro nos campos) se algum for inválido.
  ({int current, int max})? _readValues() {
    final current = int.tryParse(_currentController.text);
    final max = int.tryParse(_maxController.text);
    setState(() {
      _currentError = current == null ? _invalidNumber : null;
      _maxError = max == null ? _invalidNumber : null;
    });
    if (current == null || max == null) return null;
    return (current: current, max: max);
  }

  void _saveValues() {
    final values = _readValues();
    if (values == null) return;
    Navigator.of(context).pop(ResourceValues(current: values.current.clamp(0, values.max), max: values.max));
  }

  void _applyAmount(int sign) {
    final values = _readValues();
    final amount = int.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      setState(() => _amountError = 'Informe um valor maior que zero.');
      return;
    }
    if (values == null) return;
    final next = (values.current + sign * amount).clamp(0, values.max);
    Navigator.of(context).pop(ResourceValues(current: next, max: values.max));
  }

  @override
  Widget build(BuildContext context) {
    final labels = resourceActionLabels(widget.name);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: TextField(
                      controller: _currentController,
                      keyboardType: TextInputType.number,
                      inputFormatters: _numberFormatters,
                      decoration: InputDecoration(labelText: 'Valor atual', errorText: _currentError),
                      onChanged: (_) {
                        if (_currentError != null) setState(() => _currentError = null);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _maxController,
                      keyboardType: TextInputType.number,
                      inputFormatters: _numberFormatters,
                      decoration: InputDecoration(labelText: 'Valor máximo', errorText: _maxError),
                      onChanged: (_) {
                        if (_maxError != null) setState(() => _maxError = null);
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                FilledButton(onPressed: _saveValues, child: const Text('Salvar valores')),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: _numberFormatters,
                  decoration: InputDecoration(labelText: 'Quantidade', errorText: _amountError),
                  onChanged: (_) {
                    if (_amountError != null) setState(() => _amountError = null);
                  },
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(labels.decreaseIcon),
                      label: Text(labels.decrease),
                      onPressed: () => _applyAmount(-1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(labels.increaseIcon),
                      label: Text(labels.increase),
                      onPressed: () => _applyAmount(1),
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
