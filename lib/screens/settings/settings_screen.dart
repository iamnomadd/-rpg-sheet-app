import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import 'theme_screen.dart';
import 'beta_check_screen.dart';
import 'invite_manager_screen.dart';
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
                    subtitle: const Text('Escolha entre 10 estilos visuais para o RPG Sheet.'),
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
            FutureBuilder<CloudSession?>(
              future: CloudService.loadSession(),
              builder: (context, snap) {
                final session=snap.data;
                if(session==null) return const SizedBox.shrink();
                return FutureBuilder<bool>(
                  future: CloudService.isAppAdmin(session),
                  builder:(context,adminSnap){
                    if(adminSnap.data!=true) return const SizedBox.shrink();
                    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Text('Administração',style:Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height:8),
                      Card(child:ListTile(
                        leading:const Icon(Icons.confirmation_number_outlined),
                        title:const Text('Gerenciar convites'),
                        subtitle:const Text('Crie, copie e revogue códigos de acesso ao RPG Sheet.'),
                        trailing:const Icon(Icons.chevron_right),
                        onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const InviteManagerScreen())),
                      )),
                      const SizedBox(height:16),
                    ]);
                  },
                );
              },
            ),
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
      builder: (_) => AlertDialog(
        title: const Text('Apagar todos os dados?'),
        content: const Text('Esta ação remove fichas, sistemas personalizados e campanhas deste dispositivo. Faça um backup antes se quiser preservar os dados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (result == true && context.mounted) {
      await context.read<AppState>().clearAll();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados locais apagados.')));
    }
  }
}
