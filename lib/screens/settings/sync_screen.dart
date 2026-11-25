import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../../services/cloud_service.dart';
import '../../services/rpg_file_service.dart';
import '../../utils/error_message.dart';
import 'import_export_screen.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> with WidgetsBindingObserver {
  final protectEmail = TextEditingController();
  final protectPassword = TextEditingController();
  bool busy = false;
  CloudSession? session;
  String? connectionError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final loaded = CloudService.configured
          ? await CloudService.ensureSession()
          : await CloudService.loadSession();
      if (!mounted) return;
      setState(() {
        session = loaded;
        connectionError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        connectionError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    protectEmail.dispose();
    protectPassword.dispose();
    super.dispose();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      debugPrint('Sincronização falhou: $e');
      _message(appErrorMessage(e) ?? genericErrorMessage);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _activateAnonymous() => _run(() async {
        final result = await CloudService.signInAnonymously();
        if (!mounted) return;
        setState(() {
          session = result;
          connectionError = null;
        });
        await context.read<AppState>().syncNow(silent: true);
      });

  Future<void> _protectCloud() => _run(() async {
        final current = session;
        if (current == null) return;
        final result = await CloudService.protectAnonymousWithEmail(
          current,
          email: protectEmail.text,
          password: protectPassword.text,
        );
        if (!mounted) return;
        setState(() => session = result);
        protectPassword.clear();
        _message(
          result.isAnonymous
              ? 'Verifique o e-mail enviado para concluir a proteção da nuvem.'
              : 'Nuvem protegida com sucesso.',
        );
      });

  Future<void> _signInExisting() async {
    final email = TextEditingController();
    final password = TextEditingController();
    final credentials = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recuperar nuvem protegida'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Use o e-mail e a senha vinculados anteriormente. Se houver um backup na conta, ele substituirá os dados locais deste aparelho.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, [email.text, password.text]),
            child: const Text('Entrar e recuperar'),
          ),
        ],
      ),
    );
    email.dispose();
    password.dispose();
    if (credentials == null || credentials.length != 2 || !mounted) return;

    await _run(() async {
      final result = await CloudService.signIn(credentials[0], credentials[1]);
      final data = await CloudService.downloadBackup(result);
      if (data != null && mounted) {
        await context.read<AppState>().replaceFromBackup(data);
      } else if (mounted) {
        await CloudService.uploadBackup(result, context.read<AppState>().cloudPayload());
      }
      if (!mounted) return;
      setState(() => session = result);
      _message(data == null ? 'Conta conectada. Dados locais enviados para a nuvem.' : 'Nuvem recuperada neste aparelho.');
    });
  }

  Future<void> _upload() => _run(() async {
        final current = await CloudService.ensureSession();
        if (!mounted) return;
        setState(() => session = current);
        final state = context.read<AppState>();
        // Aparelho vazio por cima de um backup com dados: só com confirmação.
        if (state.isLocalEmpty) {
          final cloud = await CloudService.downloadSnapshot(current);
          if (!mounted) return;
          if (state.wouldOverwriteCloudWithEmpty(cloud?.payload)) {
            final counts = AppState.backupCounts(cloud!.payload);
            final confirm = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Substituir o backup da nuvem?'),
                content: Text('Este aparelho está vazio. Enviar agora vai substituir o backup da nuvem, que tem ${counts.characters} ficha(s) e ${counts.campaigns} campanha(s). Continuar?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
                  FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Substituir')),
                ],
              ),
            );
            if (confirm != true || !mounted) return;
          }
        }
        await CloudService.uploadBackup(current, state.cloudPayload());
        _message('Dados enviados para a nuvem.');
      });

  Future<void> _download() => _run(() async {
        final current = await CloudService.ensureSession();
        if (!mounted) return;
        setState(() => session = current);
        final data = await CloudService.downloadBackup(current);
        if (data == null) {
          _message('Nenhum backup encontrado na nuvem.');
          return;
        }
        if (!mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Restaurar da nuvem?'),
            content: const Text('Os dados locais de fichas, sistemas, campanhas, rolagens e preferências serão substituídos pelo backup da nuvem.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Restaurar')),
            ],
          ),
        );
        if (confirm != true || !mounted) return;
        await context.read<AppState>().replaceFromBackup(data);
        _message('Dados restaurados da nuvem.');
      });

  Future<void> _syncNow() => _run(() async {
        final result = await context.read<AppState>().syncNow();
        final refreshed = await CloudService.loadSession();
        if (mounted) setState(() => session = refreshed);
        _message(result);
      });

  Future<void> _backupFile() => _run(() async {
        await RpgFileService.exportBackup(context.read<AppState>());
        _message('Backup local gerado.');
      });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final current = session;
    final anonymous = current?.isAnonymous ?? false;
    final connected = current != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Dados e sincronização')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.import_export),
              title: const Text('Importar, exportar e backup local'),
              subtitle: const Text('Compartilhe fichas, sistemas e campanhas ou restaure arquivos .rpg.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportExportScreen())),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(
                !CloudService.configured
                    ? Icons.cloud_off_outlined
                    : connected
                        ? anonymous
                            ? Icons.cloud_outlined
                            : Icons.cloud_done_outlined
                        : Icons.cloud_sync_outlined,
              ),
              title: Text(
                !CloudService.configured
                    ? 'Nuvem aguardando configuração'
                    : connected
                        ? anonymous
                            ? 'Nuvem ativa'
                            : 'Nuvem protegida'
                        : 'Nuvem indisponível',
              ),
              subtitle: Text(
                !CloudService.configured
                    ? 'A conexão com a nuvem não está configurada neste site/PWA.'
                    : connected
                        ? anonymous
                            ? 'Seus dados sincronizam sem cadastro. Proteja a nuvem para poder recuperá-la em outro aparelho.'
                            : 'Protegida por ${current.email}.'
                        : connectionError ?? 'Não foi possível iniciar a sincronização.',
              ),
              trailing: busy ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2)) : null,
            ),
          ),
          if (!connected && CloudService.configured) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : _activateAnonymous,
              icon: const Icon(Icons.cloud_sync_outlined),
              label: const Text('Tentar ativar nuvem'),
            ),
          ],
          if (connected && anonymous) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Proteja sua nuvem', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    const Text('Opcional. Vincule um e-mail para recuperar suas fichas caso troque de aparelho, remova o PWA ou limpe os dados do navegador.'),
                    const SizedBox(height: 14),
                    TextField(
                      controller: protectEmail,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email_outlined)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: protectPassword,
                      enabled: !busy,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Senha', prefixIcon: Icon(Icons.lock_outline)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy ? null : _protectCloud,
                        icon: const Icon(Icons.shield_outlined),
                        label: const Text('Proteger minha nuvem'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (connected) ...[
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: busy ? null : _syncNow, icon: const Icon(Icons.sync), label: const Text('Sincronizar agora')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: state.autoSync,
              onChanged: busy ? null : state.setAutoSync,
              title: const Text('Sincronização automática'),
              subtitle: Text(state.syncStatus),
              secondary: const Icon(Icons.devices_outlined),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Opções manuais'),
              children: [
                ListTile(leading: const Icon(Icons.cloud_upload_outlined), title: const Text('Forçar envio deste aparelho'), onTap: busy ? null : _upload),
                ListTile(leading: const Icon(Icons.cloud_download_outlined), title: const Text('Restaurar cópia da nuvem'), onTap: busy ? null : _download),
              ],
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy || !CloudService.configured ? null : _signInExisting,
            icon: const Icon(Icons.restore_outlined),
            label: const Text('Já protegi minha nuvem — recuperar conta'),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Dados deste aparelho', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                Text('${state.characters.length} fichas • ${state.systems.length} sistemas'),
                Text('${state.campaigns.length} campanhas • ${state.savedRolls.length} rolagens favoritas'),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: busy ? null : _backupFile, icon: const Icon(Icons.save_alt), label: const Text('Gerar backup local .rpg')),
          const SizedBox(height: 14),
          Text(state.lastSyncUtc == null ? 'Ainda não houve sincronização neste aparelho.' : 'Última sincronização: ${state.lastSyncUtc!.toLocal()}'),
          const SizedBox(height: 6),
          const Text('A nuvem anônima funciona sem cadastro. O vínculo de e-mail é opcional e serve para recuperação em outros aparelhos.'),
        ],
      ),
    );
  }
}
