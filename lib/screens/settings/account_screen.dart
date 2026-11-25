import 'package:flutter/material.dart';
import '../../services/cloud_service.dart';
import 'sync_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override State<AccountScreen> createState()=>_AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  CloudSession? _session;
  bool _loading=true;
  String? _error;

  @override void initState(){super.initState();_load();}

  Future<void> _load() async {
    if(mounted)setState((){_loading=true;_error=null;});
    try {
      final stored=await CloudService.loadSession();
      if(stored==null){
        if(mounted)setState(()=>_session=null);
      } else {
        final session=await CloudService.ensureSession();
        if(mounted)setState(()=>_session=session);
      }
    } catch(e) {
      if(mounted)setState(()=>_error=e.toString().replaceFirst('Exception: ',''));
    } finally {
      if(mounted)setState(()=>_loading=false);
    }
  }

  Future<void> _signOut() async {
    final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(
      title:const Text('Sair da conta?'),
      content:const Text('Suas fichas locais continuarão neste dispositivo. A sincronização da conta será desconectada até você entrar novamente.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Sair')),
      ],
    ));
    if(ok!=true)return;
    await CloudService.signOut();
    if(!mounted)return;
    setState(()=>_session=null);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Conta desconectada.')));
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      appBar:AppBar(title:const Text('Conta')),
      body:_loading
        ? const Center(child:CircularProgressIndicator())
        : RefreshIndicator(
          onRefresh:_load,
          child:ListView(padding:const EdgeInsets.all(16),children:[
            Card(child:Padding(
              padding:const EdgeInsets.all(18),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[
                  CircleAvatar(radius:26,child:Icon(_session?.isAnonymous==true?Icons.person_outline:Icons.person)),
                  const SizedBox(width:14),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(_session==null?'Sem conta conectada':(_session!.isAnonymous?'Sessão temporária':'Conta Grimório'),
                      style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w700)),
                    const SizedBox(height:3),
                    Text(_session?.email.isNotEmpty==true?_session!.email:'Nenhum e-mail conectado',
                      maxLines:1,overflow:TextOverflow.ellipsis),
                  ])),
                ]),
                if(_error!=null)...[
                  const SizedBox(height:14),
                  Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
                ],
              ]),
            )),
            const SizedBox(height:16),
            Text('Dados e sincronização',style:Theme.of(context).textTheme.titleMedium),
            const SizedBox(height:8),
            Card(child:ListTile(
              leading:const Icon(Icons.cloud_sync_outlined),
              title:const Text('Backup, importação e nuvem'),
              subtitle:const Text('Exporte, importe, restaure backups e sincronize seus dados com a nuvem.'),
              trailing:const Icon(Icons.chevron_right),
              onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const SyncScreen())),
            )),
            const SizedBox(height:16),
            if(_session!=null)...[
              Text('Sincronização',style:Theme.of(context).textTheme.titleMedium),
              const SizedBox(height:8),
              Card(child:Column(children:[
                ListTile(
                  leading:const Icon(Icons.cloud_done_outlined),
                  title:const Text('Sessão da nuvem'),
                  subtitle:Text(_session!.isAnonymous
                    ? 'Sessão temporária. Proteja o acesso com e-mail usando um convite quando necessário.'
                    : 'Conta conectada e disponível para sincronização.'),
                ),
                const Divider(height:1),
                ListTile(
                  leading:const Icon(Icons.refresh),
                  title:const Text('Verificar sessão'),
                  subtitle:const Text('Atualiza e valida sua sessão com segurança.'),
                  onTap:_load,
                ),
              ])),
              const SizedBox(height:18),
              OutlinedButton.icon(
                onPressed:_signOut,
                icon:const Icon(Icons.logout),
                label:const Text('Sair da conta'),
              ),
            ] else ...[
              Card(child:const ListTile(
                leading:Icon(Icons.info_outline),
                title:Text('Nenhuma sessão conectada'),
                subtitle:Text('Volte à tela de acesso para entrar na sua conta. Seus dados locais não foram apagados.'),
              )),
            ],
          ]),
        ),
    );
  }
}
