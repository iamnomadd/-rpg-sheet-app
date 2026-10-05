import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';

class BetaCheckScreen extends StatefulWidget {
  const BetaCheckScreen({super.key});

  @override
  State<BetaCheckScreen> createState() => _BetaCheckScreenState();
}

class _BetaCheckScreenState extends State<BetaCheckScreen> {
  bool repairing = false;

  Future<void> _repair() async {
    setState(() => repairing = true);
    final repaired = await context.read<AppState>().repairDataIntegrity();
    if (!mounted) return;
    setState(() => repairing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          repaired == 0
              ? 'Nenhuma correção necessária.'
              : '$repaired ajuste(s) realizado(s).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final issues = state.dataIntegrityIssues;

    return Scaffold(
      appBar: AppBar(title: const Text('Verificação de integridade')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        issues.isEmpty
                            ? Icons.verified_outlined
                            : Icons.warning_amber_rounded,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          issues.isEmpty
                              ? 'Dados locais consistentes'
                              : '${issues.length} ponto(s) para revisar',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    issues.isEmpty
                        ? 'Nenhum problema estrutural foi detectado nas fichas, sistemas e campanhas.'
                        : 'A verificação procura referências quebradas e dados incompatíveis entre versões.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (issues.isNotEmpty)
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < issues.length; i++) ...[
                    ListTile(
                      leading: const Icon(Icons.error_outline),
                      title: Text(issues[i]),
                    ),
                    if (i != issues.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: const Text('Fichas'),
                  trailing: Text('${state.characters.length}'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: const Text('Sistemas'),
                  trailing: Text('${state.systems.length}'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: const Text('Campanhas'),
                  trailing: Text('${state.campaigns.length}'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.casino_outlined),
                  title: const Text('Rolagens no histórico'),
                  trailing: Text('${state.diceHistory.length}'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: repairing || issues.isEmpty ? null : _repair,
            icon: repairing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.build_circle_outlined),
            label: Text(repairing ? 'Verificando...' : 'Corrigir automaticamente'),
          ),
          const SizedBox(height: 8),
          const Text(
            'A correção automática não apaga fichas válidas. Ela restaura referências básicas, remove vínculos quebrados e normaliza dados incompatíveis.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
