import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase/supabase.dart';

import '../../app/abyss_tab_art.dart';
import '../../app/abyss_theme.dart';
import '../../models/character.dart';
import '../../services/app_state.dart';
import '../../services/cloud_service.dart';
import '../campaigns/initiative_tools.dart';

/// Intervalo entre consultas quando a ficha não tem código de compartilhamento
/// nem campanha vinculada aprovada (o tempo real nunca conecta).
const playerTurnIdleRefresh = Duration(seconds: 60);

/// Próxima consulta do aviso de turno. Com falhas: os atrasos (backoff) de
/// sempre. Sem shareCode e sem campanhas aprovadas: [playerTurnIdleRefresh].
/// Com tempo real conectado: 15 s; desconectado: reconexão rápida (1,2 s).
Duration playerTurnRefreshDelay({required int failures, required bool realtimeConnected, required bool hasShareCode, required bool hasCampaigns}) {
  if (failures > 0) {
    final seconds = (1 << failures.clamp(1, 3)) * 2;
    return Duration(seconds: seconds.clamp(4, 12));
  }
  if (!hasShareCode && !hasCampaigns) return playerTurnIdleRefresh;
  return realtimeConnected ? const Duration(seconds: 15) : const Duration(milliseconds: 1200);
}

/// Estado do turno POR campanha (1.3.74): o aviso aparece se for a vez do
/// personagem em QUALQUER campanha. O _refresh e o tempo real atualizam o
/// mesmo mapa.
class PlayerTurnTracker {
  final Map<String, ({bool isTurn, int round})> _byCampaign = {};

  /// É a vez do personagem em alguma campanha.
  bool get isTurn => _byCampaign.values.any((t) => t.isTurn);

  /// Rodada da (primeira) campanha em que é a vez; senão 1.
  int get round {
    for (final t in _byCampaign.values) {
      if (t.isTurn) return t.round;
    }
    return 1;
  }

  /// Atualiza uma campanha.
  void set(String campaignId, {required bool isTurn, required int round}) => _byCampaign[campaignId] = (isTurn: isTurn, round: round);

  /// Rodada conhecida de uma campanha (ou [fallback]).
  int roundOf(String campaignId, int fallback) => _byCampaign[campaignId]?.round ?? fallback;

  /// Mantém só as campanhas ainda vinculadas.
  void retain(Set<String> campaignIds) => _byCampaign.removeWhere((id, _) => !campaignIds.contains(id));
}

class PlayerTurnBanner extends StatefulWidget {
  final Character character;
  const PlayerTurnBanner({super.key, required this.character});

  /// Desliga o tempo real (só nos testes, que não têm WebSocket).
  @visibleForTesting
  static bool debugDisableRealtime = false;

  @override State<PlayerTurnBanner> createState() => _PlayerTurnBannerState();
}
class _PlayerTurnBannerState extends State<PlayerTurnBanner> with SingleTickerProviderStateMixin {
  final _turns = PlayerTurnTracker();
  bool get turn => _turns.isTurn;
  int get round => _turns.round;
  /// Se a última consulta achou campanhas vinculadas aprovadas.
  bool _hasCampaigns = false;
  Map<String,dynamic>? pendingPatch;
  Timer? _syncTimer;
  late final AnimationController _turnPulse;
  late final Animation<double> _pulse;
  bool _refreshing=false;
  int _syncGeneration=0;
  int _syncFailures=0;
  String _syncStatus='Conectando';
  SupabaseClient? _realtimeClient;
  RealtimeChannel? _turnChannel;
  bool _realtimeConnected = false;
  String _realtimeAccessToken = '';
  Set<String> _campaignIds = <String>{};
  // Patch de condições já aplicado automaticamente (evita aplicar de novo
  // entre ciclos de _refresh enquanto a limpeza na nuvem não chega).
  String? _appliedConditionsPatch;
  @override
  void initState(){
    super.initState();
    _turnPulse=AnimationController(vsync:this,duration:const Duration(milliseconds:2400));
    _pulse=CurvedAnimation(parent:_turnPulse,curve:Curves.easeInOut);
    // O brilho só roda durante o turno (e sem "reduzir movimento"): ver _syncPulse.
    _scheduleRefresh(Duration.zero);
  }

  bool _reduceMotion() =>
      (Provider.of<AppState?>(context, listen: false)?.reduceAnimations ?? false) || MediaQuery.maybeOf(context)?.disableAnimations == true;

  /// Liga o brilho da borda só enquanto é o turno e "reduzir movimento" está
  /// desligado; fora disso, para (sem redesenhar a tela à toa).
  void _syncPulse() {
    if (!mounted) return;
    final shouldRun = turn && !_reduceMotion();
    if (shouldRun && !_turnPulse.isAnimating) {
      _turnPulse.repeat(reverse: true);
    } else if (!shouldRun && _turnPulse.isAnimating) {
      _turnPulse.stop();
      _turnPulse.value = 0;
    }
  }
  void _scheduleRefresh(Duration delay) {
    _syncTimer?.cancel();
    _syncTimer=Timer(delay,(){
      if(mounted)_refresh();
    });
  }
  Duration get _nextRefreshDelay => playerTurnRefreshDelay(
        failures: _syncFailures,
        realtimeConnected: _realtimeConnected,
        hasShareCode: widget.character.shareCode.isNotEmpty,
        hasCampaigns: _hasCampaigns,
      );
  @override
  void dispose(){
    _syncTimer?.cancel();
    final client = _realtimeClient;
    final channel = _turnChannel;
    if (client != null && channel != null) client.removeChannel(channel);
    client?.dispose();
    _turnPulse.dispose();
    super.dispose();
  }
  void _handleRealtimeState(Map<String, dynamic> state) {
    final campaignId = '${state['campaign_id'] ?? ''}';
    if (!_campaignIds.contains(campaignId)) return;
    final active = state['active'] == true;
    final init = (state['initiative'] as List? ?? []).whereType<Map>().toList();
    final ix = state['current_index'] is int ? state['current_index'] as int : 0;
    final isTurn = active && ix >= 0 && ix < init.length && '${init[ix]['id']}' == widget.character.id;
    if (!mounted) return;
    setState(() {
      // Só a campanha do evento muda; a vez em outra campanha continua.
      _turns.set(campaignId, isTurn: isTurn, round: state['round'] is int ? state['round'] as int : _turns.roundOf(campaignId, 1));
      _syncFailures = 0;
      _syncStatus = 'Tempo real';
    });
    _syncPulse();
  }

  void _ensureRealtime(CloudSession session, Iterable<String> campaignIds) {
    final nextIds = campaignIds.where((e) => e.isNotEmpty).toSet();
    if (nextIds.isEmpty || PlayerTurnBanner.debugDisableRealtime) return;
    final sameCampaigns = _turnChannel != null &&
        _campaignIds.length == nextIds.length &&
        _campaignIds.containsAll(nextIds);
    if (sameCampaigns) {
      if (_realtimeAccessToken != session.accessToken) {
        _realtimeClient?.realtime.setAuth(session.accessToken);
        _realtimeAccessToken = session.accessToken;
      }
      return;
    }

    final oldClient = _realtimeClient;
    final oldChannel = _turnChannel;
    if (oldClient != null && oldChannel != null) oldClient.removeChannel(oldChannel);
    oldClient?.dispose();
    _campaignIds = nextIds;
    _realtimeConnected = false;
    _realtimeAccessToken = session.accessToken;
    final client = CloudService.createRealtimeClient(session);
    final channel = client
        .channel('player-turn:${session.userId}:${widget.character.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rpg_campaign_session_state',
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty) _handleRealtimeState(Map<String, dynamic>.from(record));
          },
        )
        .subscribe((status, error) {
          if (!mounted) return;
          final connected = status == RealtimeSubscribeStatus.subscribed;
          setState(() {
            _realtimeConnected = connected;
            if (connected) {
              _syncFailures = 0;
              _syncStatus = 'Tempo real';
            } else if (_syncStatus == 'Tempo real') {
              _syncStatus = 'Reconectando';
            }
          });
          if (!connected) _scheduleRefresh(const Duration(milliseconds: 1200));
        });
    _realtimeClient = client;
    _turnChannel = channel;
  }


  Future<void> _refresh() async {
    if(_refreshing) return;
    _refreshing=true;
    final generation=++_syncGeneration;
    if(mounted && _syncFailures>0) setState(()=>_syncStatus='Reconectando');
    try {
      final session = await CloudService.ensureSession();
      if (widget.character.shareCode.isNotEmpty) {
        final shared = await CloudService.sharedCharacterByCode(session, widget.character.shareCode);
        final patch = shared?['master_patch'];
        if (patch is Map && patch.isNotEmpty && mounted) {
          final data = Map<String,dynamic>.from(patch);
          if (isConditionsOnlyPatch(data)) {
            await _autoApplyConditions(data, '${shared?['master_patch_updated_at']}|$data');
          } else {
            setState(() => pendingPatch = data);
          }
        }
      }
      // Approved campaign IDs are intentionally discovered from the player's own link records via REST.
      final links=await CloudService.approvedPlayerCampaigns(session);
      final linkedIds=links.map((raw) => '${raw['campaign_id'] ?? ''}').where((id)=>id.isNotEmpty).toSet();
      _hasCampaigns=linkedIds.isNotEmpty;
      _ensureRealtime(session, links.map((raw) => '${raw['campaign_id'] ?? ''}'));
      // Estado do turno por campanha (o mesmo mapa do tempo real).
      final checked=<String,({bool isTurn,int round})>{};
      for(final raw in links){
        final campaignId='${raw['campaign_id']}';
        final state=await CloudService.fetchSessionState(session,campaignId);
        if(state==null || state['active']!=true){
          checked[campaignId]=(isTurn:false,round:1);
          continue;
        }
        final init=(state['initiative'] as List? ?? []).whereType<Map>().toList();
        final ix=state['current_index'] is int ? state['current_index'] as int : 0;
        final stateRound=state['round'] is int?state['round'] as int:1;
        if(ix>=0 && ix<init.length && '${init[ix]['id']}'==widget.character.id){
          if(generation!=_syncGeneration) return;
          checked[campaignId]=(isTurn:true,round:stateRound);
          if(mounted){
            setState((){
              _turns.retain(linkedIds);
              for(final e in checked.entries){_turns.set(e.key,isTurn:e.value.isTurn,round:e.value.round);}
              _syncFailures=0;_syncStatus=_realtimeConnected?'Tempo real':'Online';
            });
          }
          _syncPulse();
          return;
        }
        checked[campaignId]=(isTurn:false,round:stateRound);
      }
      if(generation!=_syncGeneration) return;
      if (mounted) {
        setState(() {
          _turns.retain(linkedIds);
          for(final e in checked.entries){_turns.set(e.key,isTurn:e.value.isTurn,round:e.value.round);}
          _syncFailures=0; _syncStatus=_realtimeConnected?'Tempo real':'Online';
        });
      }
      _syncPulse();
    } catch (_) {
      _syncFailures++;
      if(mounted) setState(()=>_syncStatus=_syncFailures>=3?'Offline':'Reconectando');
    } finally {
      _refreshing=false;
      if(mounted)_scheduleRefresh(_nextRefreshDelay);
    }
  }
  /// Condições enviadas pelo mestre entram sozinhas na ficha.
  Future<void> _autoApplyConditions(Map<String,dynamic> patch, String key) async {
    if (_appliedConditionsPatch == key) return;
    _appliedConditionsPatch = key;
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    widget.character.conditions = conditionsFromRaw(patch['conditions']);
    await appState.updateCharacter(widget.character);
    if (mounted) setState(() => pendingPatch = null);
    messenger?.showSnackBar(const SnackBar(content: Text('O mestre atualizou suas condições.'), duration: Duration(seconds: 2)));
    final session = await CloudService.ensureSession();
    await CloudService.clearSharedCharacterPatch(session, widget.character.shareCode);
  }

  Future<void> _applyPatch() async {
    final patch=pendingPatch; if(patch==null) return;
    // A vida (Vida/PV) do jogador é só dele: ignora mesmo se vier no patch.
    widget.character.resourceValues.addAll(patchResourcesWithoutLife(patch['resourceValues']));
    final conditions=patch['conditions'];
    if(conditions is List) widget.character.conditions=conditions.map((e)=>e.toString()).toList();
    await context.read<AppState>().updateCharacter(widget.character);
    final session=await CloudService.ensureSession();
    if(widget.character.shareCode.isNotEmpty) await CloudService.clearSharedCharacterPatch(session, widget.character.shareCode);
    if(mounted) setState(()=>pendingPatch=null);
  }
  /// Ícone do status de conexão.
  IconData get _statusIcon => (_syncStatus=='Online'||_syncStatus=='Tempo real')?Icons.cloud_done_outlined:_syncStatus=='Offline'?Icons.cloud_off_outlined:Icons.sync;

  /// Moldura dos cards do app (mesmo raio e espessura), na paleta do tema.
  /// [glow] (0..1) clareia só a borda dourada.
  ShapeBorder _cardFrame(AbyssPalette p, {bool gold = false, double glow = 0}) => AbyssFrameBorder(
        side: BorderSide(color: gold ? Color.lerp(p.gold, p.goldLight, glow)! : p.outline, width: 2),
        innerColor: gold ? Color.lerp(p.goldLine, p.gold, glow)! : p.goldLine,
      );

  @override Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final reduceMotion = appState.reduceAnimations || MediaQuery.maybeOf(context)?.disableAnimations == true;
    // Liga/para o brilho quando o turno ou o "reduzir movimento" mudam.
    if ((turn && !reduceMotion) != _turnPulse.isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncPulse());
    }
    final p = AbyssPalette.of(context);
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: p.goldLight);
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(color: p.creamMuted);
    return (turn || pendingPatch!=null || widget.character.shareCode.isNotEmpty) ? SafeArea(top:false, child: Column(mainAxisSize:MainAxisSize.min, children:[
    if(!turn && pendingPatch==null && widget.character.shareCode.isNotEmpty)
      Padding(padding:const EdgeInsets.fromLTRB(16,2,16,4),child:Row(mainAxisAlignment:MainAxisAlignment.end,children:[Icon(_statusIcon,size:16,color:p.creamMuted),const SizedBox(width:6),Text(_syncStatus,style:theme.textTheme.labelSmall?.copyWith(color:p.creamMuted))])),
    if(pendingPatch!=null) Card(
      margin:const EdgeInsets.fromLTRB(16,4,16,4),
      color:p.card,
      shape:_cardFrame(p),
      child:ListTile(
        leading:Icon(Icons.sync,color:p.gold),
        title:Text('Alteração do Mestre',style:titleStyle),
        subtitle:Text('Recursos ou condições foram atualizados.',style:mutedStyle),
        trailing:FilledButton(onPressed:_applyPatch, child:const Text('Aplicar')),
      ),
    ),
    AnimatedSwitcher(
      duration:reduceMotion ? Duration.zero : const Duration(milliseconds:500),
      reverseDuration:reduceMotion ? Duration.zero : const Duration(milliseconds:400),
      switchInCurve:Curves.easeOutCubic,
      switchOutCurve:Curves.easeInCubic,
      transitionBuilder:(child,animation)=>FadeTransition(
        opacity:animation,
        child:SlideTransition(position:Tween<Offset>(begin:const Offset(0,0.18),end:Offset.zero).animate(animation),child:child),
      ),
      child:turn ? AnimatedBuilder(
        key:const ValueKey('active-turn'),
        animation:_pulse,
        // O conteúdo não muda com o brilho: só a borda é redesenhada.
        child:ListTile(
          contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:6),
          // "Seu turno" é a hora de agir: a arte do card Ações.
          leading:ThemedSectionIcon(appState.themeId,'actions',fallbackIcon:Icons.sports_martial_arts,color:p.gold),
          title:Text('SEU TURNO',style:titleStyle),
          subtitle:Row(children:[
            Flexible(child:Text('Rodada $round',style:theme.textTheme.bodyMedium?.copyWith(color:p.cream))),
            const SizedBox(width:10),
            Icon(_statusIcon,size:14,color:p.creamMuted),
            const SizedBox(width:4),
            Flexible(child:Text(_syncStatus,overflow:TextOverflow.ellipsis,style:theme.textTheme.labelSmall?.copyWith(color:p.creamMuted))),
          ]),
          trailing:IconButton(tooltip:'Atualizar agora',icon:Icon(Icons.refresh_rounded,color:p.gold),onPressed:_refresh),
        ),
        builder:(context,child){
          // Brilho suave só na borda dourada; fixo com "reduzir movimento".
          final glow = reduceMotion ? 0.0 : _pulse.value;
          return Card(
            key:const ValueKey('turn-card'),
            margin:const EdgeInsets.fromLTRB(16,4,16,10),
            color:p.card,
            shape:_cardFrame(p,gold:true,glow:glow),
            child:child,
          );
        },
      ) : const SizedBox.shrink(key:ValueKey('no-active-turn')),
    ),
  ])) : const SizedBox.shrink();
  }
}
