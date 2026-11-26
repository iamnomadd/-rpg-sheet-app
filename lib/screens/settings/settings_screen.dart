import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../services/app_state.dart';
import 'theme_screen.dart';
import 'beta_check_screen.dart';
import 'share_with_friend.dart';
import 'account_screen.dart';
import '../../services/cloud_service.dart';
import '../../core/app_version.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Configurações')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Conta', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: FutureBuilder<CloudSession?>(
                future: CloudService.loadSession(),
                builder:(context,snap){
                  final session=snap.data;
                  return ListTile(
                    leading:const Icon(Icons.account_circle_outlined),
                    title:Text(session?.isAnonymous==false?'Minha conta':'Conta e acesso'),
                    subtitle:Text(session?.email.isNotEmpty==true?session!.email:'Gerencie sua sessão e sincronização.'),
                    trailing:const Icon(Icons.chevron_right),
                    onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AccountScreen())),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text('Aparência', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Aparência e temas'),
                    subtitle: Text('Escolha entre ${appThemes.length} estilos visuais para o Grimório.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemeScreen())),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.text_fields),
                    title: const Text('Texto maior'),
                    subtitle: const Text('Aumenta os textos do aplicativo para facilitar a leitura.'),
                    value: state.largeText,
                    onChanged: state.setLargeText,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.density_small),
                    title: const Text('Modo compacto'),
                    subtitle: const Text('Usa uma densidade ainda menor para mostrar mais conteúdo na tela.'),
                    value: state.compactMode,
                    onChanged: state.setCompactMode,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.motion_photos_off_outlined),
                    title: const Text('Reduzir animações'),
                    subtitle: const Text('Desativa movimentos decorativos do personagem 2D.'),
                    value: state.reduceAnimations,
                    onChanged: state.setReduceAnimations,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Mestre', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.workspace_premium_outlined),
                title: const Text('Ativar ferramentas de Mestre'),
                subtitle: const Text('Exibe a área Mestre na navegação. Você pode jogar e mestrar no mesmo aparelho.'),
                value: state.masterToolsEnabled,
                onChanged: state.setMasterToolsEnabled,
              ),
            ),
            const SizedBox(height: 16),
            // 1.3.72: a entrada "Gerenciar convites" (InviteManagerScreen) ficou
            // escondida porque a entrada no Grimório foi liberada (Criar conta).
            // A tela, as funções do CloudService e as tabelas continuam.
            Text('Manutenção', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.storage_outlined),
                    title: const Text('Resumo dos dados locais'),
                    subtitle: Text('${state.characters.length} fichas • ${state.systems.length} sistemas • ${state.campaigns.length} campanhas • ${state.diceHistory.length} rolagens'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      state.dataIntegrityIssues.isEmpty
                          ? Icons.verified_outlined
                          : Icons.warning_amber_rounded,
                    ),
                    title: const Text('Verificação de integridade'),
                    subtitle: Text(
                      state.dataIntegrityIssues.isEmpty
                          ? 'Nenhum problema estrutural detectado.'
                          : '${state.dataIntegrityIssues.length} ponto(s) para revisar.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BetaCheckScreen()),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.history_toggle_off),
                    title: const Text('Limpar histórico de dados'),
                    subtitle: const Text('Remove somente o histórico de rolagens.'),
                    onTap: state.diceHistory.isEmpty ? null : () => _clearDice(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Center(child: Text(appVersionDisplay)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _clear(context),
              icon: const Icon(Icons.delete_forever),
              label: const Text('Apagar todos os dados locais'),
            ),
            const SizedBox(height: 20),
            // Para todos os usuários (sem relação com o código de vínculo do Mestre).
            const ShareWithFriendSection(),
          ],
        ),
      ),
    );
  }

  Future<void> _clearDice(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Limpar histórico?'),
        content: const Text('As fichas, sistemas e campanhas não serão alterados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Limpar')),
        ],
      ),
    );
    if (result == true && context.mounted) {
      context.read<AppState>().clearDiceHistory();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Histórico de rolagens limpo.')));
    }
  }

  Future<void> _clear(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const _ClearAllDialog(),
    );
    if (result == true && context.mounted) {
      await context.read<AppState>().clearAll();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados apagados deste aparelho. Sincronização automática desligada.')));
    }
  }
}

/// Confirmação do "Apagar todos os dados locais": só libera o botão depois de
/// digitar APAGAR.
class _ClearAllDialog extends StatefulWidget {
  const _ClearAllDialog();

  @override
  State<_ClearAllDialog> createState() => _ClearAllDialogState();
}

class _ClearAllDialogState extends State<_ClearAllDialog> {
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  bool get _ok => _confirm.text.trim().toUpperCase() == 'APAGAR';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Apagar todos os dados deste aparelho?'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Fichas, sistemas personalizados e campanhas serão apagados SÓ deste aparelho. A sincronização automática será desligada para não apagar o seu backup na nuvem. Para trazer os dados de volta, use Restaurar da nuvem em Dados e sincronização.'),
            const SizedBox(height: 14),
            TextField(
              controller: _confirm,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Digite APAGAR para confirmar'),
              onChanged: (_) => setState(() {}),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: _ok ? () => Navigator.pop(context, true) : null, child: const Text('Apagar')),
        ],
      );
}
