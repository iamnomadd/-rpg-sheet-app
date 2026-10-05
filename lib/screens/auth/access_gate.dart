import 'package:flutter/material.dart';
import '../../services/cloud_service.dart';

class AccessGate extends StatefulWidget {
  final Widget child;
  const AccessGate({super.key,required this.child});
  @override State<AccessGate> createState()=>_AccessGateState();
}
class _AccessGateState extends State<AccessGate>{
  bool _loading=true,_allowed=false,_login=true;
  String? _error;
  final _email=TextEditingController(),_password=TextEditingController(),_invite=TextEditingController();

  @override void initState(){super.initState();_check();}
  @override void dispose(){_email.dispose();_password.dispose();_invite.dispose();super.dispose();}

  Future<void> _check() async{
    setState((){_loading=true;_error=null;});
    try{
      final stored=await CloudService.loadSession();
      if(stored==null){
        if(mounted)setState(()=>_allowed=false);
      }else{
        final session=await CloudService.ensureSession();
        final ok=await CloudService.hasAppAccess(session);
        if(mounted)setState(()=>_allowed=ok);
      }
    }catch(e){
      final stored = await CloudService.loadSession();
      final offlineAllowed = stored != null && await CloudService.hasRecentValidatedAccess(stored);
      if(mounted){
        setState((){
          _allowed = offlineAllowed;
          _error = offlineAllowed ? null : e.toString().replaceFirst('Exception: ','');
        });
      }
    }
    if(mounted)setState(()=>_loading=false);
  }

  Future<void> _signIn() async{
    if(_email.text.trim().isEmpty||_password.text.isEmpty)return;
    setState((){_loading=true;_error=null;});
    try{
      final session=await CloudService.signIn(_email.text,_password.text);
      final ok=await CloudService.hasAppAccess(session);
      if(!ok)throw Exception('Esta conta ainda não possui acesso ao RPG Sheet.');
      if(mounted)setState(()=>_allowed=true);
    }catch(e){if(mounted)setState(()=>_error=e.toString().replaceFirst('Exception: ',''));}
    if(mounted)setState(()=>_loading=false);
  }

  Future<void> _redeem() async{
    if(_invite.text.trim().isEmpty)return;
    if(!_email.text.contains('@')){setState(()=>_error='Informe um e-mail válido.');return;}
    if(_password.text.length<6){setState(()=>_error='Use uma senha com pelo menos 6 caracteres.');return;}
    setState((){_loading=true;_error=null;});
    try{
      var session=await CloudService.ensureSession();
      final ok=await CloudService.redeemInvite(session,_invite.text);
      if(!ok)throw Exception('Convite inválido, expirado ou já utilizado.');
      if(session.isAnonymous){
        session=await CloudService.protectAnonymousWithEmail(session,email:_email.text,password:_password.text);
      }
      final hasAccess = await CloudService.hasAppAccess(session);
      if (!hasAccess) throw Exception('Esta conta ainda não possui acesso ao RPG Sheet.');
      if(mounted)setState(()=>_allowed=true);
    }catch(e){if(mounted)setState(()=>_error=e.toString().replaceFirst('Exception: ',''));}
    if(mounted)setState(()=>_loading=false);
  }

  @override Widget build(BuildContext context){
    if(_loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if(_allowed)return widget.child;
    return Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:430),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Icon(Icons.auto_awesome_mosaic_outlined,size:58,color:Theme.of(context).colorScheme.primary),
        const SizedBox(height:18),
        Text('RPG Sheet',textAlign:TextAlign.center,style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w800)),
        const SizedBox(height:6),
        Text(_login?'Entre para acessar suas fichas.':'Crie seu acesso usando um convite.',textAlign:TextAlign.center),
        const SizedBox(height:24),
        SegmentedButton<bool>(segments:const[
          ButtonSegment(value:true,label:Text('Entrar'),icon:Icon(Icons.login)),
          ButtonSegment(value:false,label:Text('Tenho convite'),icon:Icon(Icons.vpn_key_outlined)),
        ],selected:{_login},onSelectionChanged:(v)=>setState((){_login=v.first;_error=null;})),
        const SizedBox(height:18),
        if(!_login)...[
          TextField(controller:_invite,textCapitalization:TextCapitalization.characters,decoration:const InputDecoration(labelText:'Código do convite',prefixIcon:Icon(Icons.key_outlined))),
          const SizedBox(height:12),
        ],
        AutofillGroup(child:Column(children:[
        TextField(controller:_email,keyboardType:TextInputType.emailAddress,autocorrect:false,autofillHints:const [AutofillHints.username,AutofillHints.email],textInputAction:TextInputAction.next,decoration:const InputDecoration(labelText:'E-mail',prefixIcon:Icon(Icons.alternate_email))),
        const SizedBox(height:12),
        TextField(controller:_password,obscureText:true,autofillHints:const [AutofillHints.password],textInputAction:TextInputAction.done,onSubmitted:(_)=>_login?_signIn():_redeem(),decoration:const InputDecoration(labelText:'Senha',prefixIcon:Icon(Icons.lock_outline))),
        ])),
        if(_error!=null)...[const SizedBox(height:12),Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error))],
        const SizedBox(height:18),
        FilledButton.icon(onPressed:_login?_signIn:_redeem,icon:Icon(_login?Icons.login:Icons.verified_user_outlined),label:Text(_login?'Entrar':'Validar convite e continuar')),
        if(!_login)...[const SizedBox(height:10),Text('O convite libera esta conta. Você poderá usar o mesmo login no site/PWA em seus dispositivos.',textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodySmall)],
      ]),
    )))));
  }
}
