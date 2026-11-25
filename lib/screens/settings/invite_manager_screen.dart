import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/cloud_service.dart';
import '../../utils/error_message.dart';

class InviteManagerScreen extends StatefulWidget {
  const InviteManagerScreen({super.key});
  @override
  State<InviteManagerScreen> createState()=>_InviteManagerScreenState();
}

class _InviteManagerScreenState extends State<InviteManagerScreen> {
  CloudSession? _session;
  List<Map<String,dynamic>> _items=[];
  bool _loading=true;
  String? _error;

  @override
  void initState(){super.initState();_load();}

  Future<void> _load() async {
    setState((){_loading=true;_error=null;});
    try{
      final s=await CloudService.ensureSession();
      if(!await CloudService.isAppAdmin(s)) throw Exception('Esta conta não possui acesso administrativo.');
      final items=await CloudService.listInvitesAdmin(s);
      if(mounted)setState((){_session=s;_items=items;_loading=false;});
    }catch(e){if(mounted)setState((){_error=e.toString().replaceFirst('Exception: ','');_loading=false;});}
  }

  Future<void> _create() async {
    final label=TextEditingController();
    int uses=1,days=0;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal)=>AlertDialog(
      title:const Text('Novo convite'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:label,decoration:const InputDecoration(labelText:'Identificação',hintText:'Ex.: João')),
        const SizedBox(height:12),
        DropdownButtonFormField<int>(value:uses,decoration:const InputDecoration(labelText:'Quantidade de usos'),
          items:[1,2,5,10].map((v)=>DropdownMenuItem(value:v,child:Text('$v'))).toList(),onChanged:(v)=>setLocal(()=>uses=v??1)),
        const SizedBox(height:12),
        DropdownButtonFormField<int>(value:days,decoration:const InputDecoration(labelText:'Validade'),
          items:const [DropdownMenuItem(value:0,child:Text('Sem expiração')),DropdownMenuItem(value:7,child:Text('7 dias')),DropdownMenuItem(value:30,child:Text('30 dias'))],
          onChanged:(v)=>setLocal(()=>days=v??0)),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Criar convite'))],
    )));
    if(ok!=true||_session==null)return;
    try{
      final exp=days==0?null:DateTime.now().toUtc().add(Duration(days:days));
      final code=await CloudService.createInviteAdmin(_session!,label:label.text,maxUses:uses,expiresAt:exp);
      if(!mounted)return;
      await Clipboard.setData(ClipboardData(text:code));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Convite $code criado e copiado.')));
      await _load();
    }catch(e){
      debugPrint('Criar convite falhou: $e');
      final appMessage=appErrorMessage(e);
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(appMessage==null?genericErrorMessage:'Erro: $appMessage')));
    }
  }

  Future<void> _revoke(Map<String,dynamic> item) async {
    if(_session==null)return;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Revogar convite?'),
      content:Text('O código ${item['code']} deixará de aceitar novos acessos.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Revogar'))]));
    if(ok==true){await CloudService.revokeInviteAdmin(_session!,item['id'].toString());await _load();}
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Gerenciar convites'),actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh))]),
    floatingActionButton:_loading||_error!=null?null:FloatingActionButton.extended(onPressed:_create,icon:const Icon(Icons.add),label:const Text('Novo convite')),
    body:_loading?const Center(child:CircularProgressIndicator()):_error!=null?Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(_error!,textAlign:TextAlign.center))):
      _items.isEmpty?const Center(child:Text('Nenhum convite criado.')):
      ListView.separated(padding:const EdgeInsets.fromLTRB(16,16,16,96),itemCount:_items.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(ctx,i){
        final x=_items[i]; final revoked=x['revoked_at']!=null; final used=(x['uses']??0) as int; final max=(x['max_uses']??1) as int;
        final expired=x['expires_at']!=null && (DateTime.tryParse(x['expires_at'].toString())?.isBefore(DateTime.now().toUtc())??false);
        final active=!revoked&&!expired&&used<max;
        return Card(child:ListTile(
          leading:Icon(active?Icons.confirmation_number_outlined:Icons.block_outlined),
          title:Text(x['code']?.toString()??''),
          subtitle:Text('${(x['label']??'').toString().isEmpty?'Sem identificação':x['label']} • $used/$max uso(s) • ${active?'Ativo':revoked?'Revogado':expired?'Expirado':'Esgotado'}'),
          onTap:()=>Clipboard.setData(ClipboardData(text:x['code']?.toString()??'')).then((_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Código copiado.')));}),
          trailing:active?IconButton(tooltip:'Revogar',onPressed:()=>_revoke(x),icon:const Icon(Icons.block)):null,
        ));
      }),
  );
}
