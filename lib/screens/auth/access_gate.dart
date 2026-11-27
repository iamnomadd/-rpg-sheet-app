import 'package:flutter/material.dart';
import '../../services/cloud_service.dart';
import '../../services/password_recovery.dart';
import '../../utils/error_message.dart';
import '../../widgets/install_app_prompt.dart';

/// Mensagem clara para um erro do "Criar conta" (1.3.72).
String createAccountErrorMessage(Object error) {
  if (error is CloudRequestException) {
    final text = error.message.toLowerCase();
    if (text.contains('already') || text.contains('registered') || text.contains('exists') || text.contains('email_exists')) {
      return 'Este e-mail já está em uso. Use a aba Entrar.';
    }
    if (text.contains('password')) return 'Use uma senha com pelo menos 6 caracteres.';
    if (error.statusCode == 404) return 'A criação de conta ainda não está disponível. Tente novamente mais tarde.';
  }
  return appErrorMessage(error) ?? genericErrorMessage;
}

class AccessGate extends StatefulWidget {
  final Widget child;
  const AccessGate({super.key,required this.child});
  @override State<AccessGate> createState()=>_AccessGateState();
}
class _AccessGateState extends State<AccessGate>{
  bool _loading=true,_allowed=false,_login=true;
  String? _error;
  /// Aviso informativo (ex.: e-mail de recuperação enviado).
  String? _info;
  /// Sessão do link de recuperação: mostra "Criar nova senha".
  CloudSession? _recovery;
  final _email=TextEditingController(),_password=TextEditingController();
  final _newPassword=TextEditingController(),_confirmPassword=TextEditingController();

  @override void initState(){
    super.initState();
    PasswordRecovery.events.addListener(_onRecovery);
    _check();
    _onRecovery();
  }
  @override void dispose(){
    PasswordRecovery.events.removeListener(_onRecovery);
    _email.dispose();_password.dispose();_newPassword.dispose();_confirmPassword.dispose();
    super.dispose();
  }

  /// Link de recuperação de senha tratado pelo app (1.3.74).
  void _onRecovery(){
    final event=PasswordRecovery.events.value;
    if(event==null||!mounted)return;
    PasswordRecovery.events.value=null;
    final session=event.session;
    if(session!=null){
      setState((){_recovery=session;_error=null;_info=null;_newPassword.clear();_confirmPassword.clear();});
      return;
    }
    if(_allowed&&_recovery==null){
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content:Text(event.error??passwordRecoveryExpiredMessage)));
      return;
    }
    setState((){_recovery=null;_login=true;_info=null;_error=event.error;});
  }

  Future<void> _forgotPassword() async{
    final controller=TextEditingController(text:_email.text.trim());
    final email=await showDialog<String>(context:context,builder:(dialogContext)=>AlertDialog(
      title:const Text('Esqueci minha senha'),
      content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Text('Informe o e-mail da sua conta. Vamos enviar um link para criar uma senha nova.'),
        const SizedBox(height:12),
        TextField(controller:controller,autofocus:true,keyboardType:TextInputType.emailAddress,autocorrect:false,decoration:const InputDecoration(labelText:'E-mail',prefixIcon:Icon(Icons.alternate_email))),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(dialogContext,controller.text.trim()),child:const Text('Enviar link')),
      ],
    ));
    WidgetsBinding.instance.addPostFrameCallback((_)=>controller.dispose());
    if(email==null||!mounted)return;
    if(!email.contains('@')){setState((){_info=null;_error='Informe um e-mail válido.';});return;}
    _email.text=email;
    setState((){_loading=true;_error=null;_info=null;});
    try{
      await PasswordRecovery.request(email);
      if(mounted)setState(()=>_info=passwordRecoverySentMessage);
    }catch(e){
      if(mounted)setState(()=>_error=appErrorMessage(e)??genericErrorMessage);
    }
    if(mounted)setState(()=>_loading=false);
  }

  Future<void> _saveNewPassword() async{
    final session=_recovery;
    if(session==null)return;
    if(_newPassword.text.length<6){setState(()=>_error='Use uma senha com pelo menos 6 caracteres.');return;}
    if(_newPassword.text!=_confirmPassword.text){setState(()=>_error='As senhas não são iguais.');return;}
    setState((){_loading=true;_error=null;});
    try{
      await CloudService.updatePassword(session,_newPassword.text);
      final ok=await CloudService.hasAppAccess(session);
      if(!mounted)return;
      setState((){
        _recovery=null;
        _allowed=ok;
        _login=true;
        _error=ok?null:'Esta conta ainda não possui acesso ao Grimório.';
      });
      if(ok)ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content:Text(passwordChangedMessage)));
    }catch(e){
      if(mounted)setState(()=>_error=appErrorMessage(e)??genericErrorMessage);
    }
    if(mounted)setState(()=>_loading=false);
  }

  Widget _newPasswordScreen(BuildContext context)=>Scaffold(key:const ValueKey('new-password'),body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(
    constraints:const BoxConstraints(maxWidth:430),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Icon(Icons.lock_reset_outlined,size:58,color:Theme.of(context).colorScheme.primary),
      const SizedBox(height:18),
      Text('Criar nova senha',textAlign:TextAlign.center,style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w800)),
      const SizedBox(height:6),
      Text(_recovery?.email.isNotEmpty==true?'Conta: ${_recovery!.email}':'Escolha a senha nova da sua conta.',textAlign:TextAlign.center),
      const SizedBox(height:24),
      AutofillGroup(child:Column(children:[
        TextField(controller:_newPassword,obscureText:true,autofillHints:const [AutofillHints.newPassword],textInputAction:TextInputAction.next,decoration:const InputDecoration(labelText:'Senha nova',prefixIcon:Icon(Icons.lock_outline))),
        const SizedBox(height:12),
        TextField(controller:_confirmPassword,obscureText:true,autofillHints:const [AutofillHints.newPassword],textInputAction:TextInputAction.done,onSubmitted:(_)=>_saveNewPassword(),decoration:const InputDecoration(labelText:'Confirmar senha',prefixIcon:Icon(Icons.lock_outline))),
      ])),
      if(_error!=null)...[const SizedBox(height:12),Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error))],
      const SizedBox(height:18),
      FilledButton.icon(onPressed:_saveNewPassword,icon:const Icon(Icons.check),label:const Text('Salvar senha')),
      const SizedBox(height:6),
      TextButton(onPressed:()=>setState((){_recovery=null;_error=null;}),child:const Text('Cancelar')),
    ]),
  )))));

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
      if(!ok)throw Exception('Esta conta ainda não possui acesso ao Grimório.');
      if(mounted)setState(()=>_allowed=true);
    }catch(e){if(mounted)setState(()=>_error=e.toString().replaceFirst('Exception: ',''));}
    if(mounted)setState(()=>_loading=false);
  }

  /// "Criar conta" (1.3.72): mesmo fluxo do antigo convite, trocando o
  /// resgate do código por claim_rpg_open_access.
  Future<void> _createAccount() async{
    if(!_email.text.contains('@')){setState(()=>_error='Informe um e-mail válido.');return;}
    if(_password.text.length<6){setState(()=>_error='Use uma senha com pelo menos 6 caracteres.');return;}
    setState((){_loading=true;_error=null;});
    try{
      var session=await CloudService.ensureSession();
      final ok=await CloudService.claimOpenAccess(session);
      if(!ok)throw const AppMessageException('Não foi possível criar a conta agora. Tente novamente.');
      if(session.isAnonymous){
        session=await CloudService.protectAnonymousWithEmail(session,email:_email.text,password:_password.text);
      }
      final hasAccess = await CloudService.hasAppAccess(session);
      if (!hasAccess) throw const AppMessageException('Esta conta ainda não possui acesso ao Grimório.');
      if(mounted)setState(()=>_allowed=true);
    }catch(e){if(mounted)setState(()=>_error=createAccountErrorMessage(e));}
    if(mounted)setState(()=>_loading=false);
  }

  @override Widget build(BuildContext context){
    if(_loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if(_recovery!=null)return _newPasswordScreen(context);
    if(_allowed)return widget.child;
    return Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:430),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Icon(Icons.auto_awesome_mosaic_outlined,size:58,color:Theme.of(context).colorScheme.primary),
        const SizedBox(height:18),
        Text('Grimório',textAlign:TextAlign.center,style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w800)),
        const SizedBox(height:6),
        Text(_login?'Entre para acessar suas fichas.':'Crie sua conta para guardar suas fichas.',textAlign:TextAlign.center),
        const SizedBox(height:24),
        SegmentedButton<bool>(segments:const[
          ButtonSegment(value:true,label:Text('Entrar'),icon:Icon(Icons.login)),
          ButtonSegment(value:false,label:Text('Criar conta'),icon:Icon(Icons.person_add_alt_1_outlined)),
        ],selected:{_login},onSelectionChanged:(v)=>setState((){_login=v.first;_error=null;_info=null;})),
        const SizedBox(height:18),
        AutofillGroup(child:Column(children:[
        TextField(controller:_email,keyboardType:TextInputType.emailAddress,autocorrect:false,autofillHints:const [AutofillHints.username,AutofillHints.email],textInputAction:TextInputAction.next,decoration:const InputDecoration(labelText:'E-mail',prefixIcon:Icon(Icons.alternate_email))),
        const SizedBox(height:12),
        TextField(controller:_password,obscureText:true,autofillHints:const [AutofillHints.password],textInputAction:TextInputAction.done,onSubmitted:(_)=>_login?_signIn():_createAccount(),decoration:const InputDecoration(labelText:'Senha',prefixIcon:Icon(Icons.lock_outline))),
        ])),
        if(_error!=null)...[const SizedBox(height:12),Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error))],
        if(_info!=null)...[const SizedBox(height:12),Text(_info!,key:const ValueKey('access-info'),textAlign:TextAlign.center)],
        const SizedBox(height:18),
        FilledButton.icon(onPressed:_login?_signIn:_createAccount,icon:Icon(_login?Icons.login:Icons.person_add_alt_1_outlined),label:Text(_login?'Entrar':'Criar conta')),
        if(_login)Align(alignment:Alignment.center,child:TextButton(onPressed:_forgotPassword,child:const Text('Esqueci minha senha'))),
        if(!_login)...[const SizedBox(height:10),Text('Você poderá usar o mesmo login no site/PWA em seus dispositivos.',textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodySmall)],
        // Instalar o app (Web): botão no Android/Chrome, instrução no iPhone/iPad.
        const SizedBox(height:14),
        const InstallAppPrompt(),
      ]),
    )))));
  }
}
