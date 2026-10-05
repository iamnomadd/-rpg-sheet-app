import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase/supabase.dart';

import '../../models/character.dart';
import '../../services/app_state.dart';
import '../../services/cloud_service.dart';

class PlayerTurnBanner extends StatefulWidget {
  final Character character;
  const PlayerTurnBanner({super.key, required this.character});
  @override State<PlayerTurnBanner> createState() => _PlayerTurnBannerState();
}
class _PlayerTurnBannerState extends State<PlayerTurnBanner> with SingleTickerProviderStateMixin {
  bool turn = false; int round = 1;
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
  @override
  void initState(){
    super.initState();
    _turnPulse=AnimationController(vsync:this,duration:const Duration(milliseconds:2400));
    _pulse=CurvedAnimation(parent:_turnPulse,curve:Curves.easeInOut);
    _turnPulse.repeat(reverse:true);
    _scheduleRefresh(Duration.zero);
  }
  void _scheduleRefresh(Duration delay) {
    _syncTimer?.cancel();
    _syncTimer=Timer(delay,(){
      if(mounted)_refresh();
    });
  }
  Duration get _nextRefreshDelay {
    if(_syncFailures<=0)return _realtimeConnected ? const Duration(seconds:15) : const Duration(milliseconds:1200);
    final seconds=(1 << _syncFailures.clamp(1,3)) * 2;
    return Duration(seconds:seconds.clamp(4,12));
  }
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
      turn = isTurn;
      round = state['round'] is int ? state['round'] as int : round;
      _syncFailures = 0;
      _syncStatus = 'Tempo real';
    });
  }

  void _ensureRealtime(CloudSession session, Iterable<String> campaignIds) {
    final nextIds = campaignIds.where((e) => e.isNotEmpty).toSet();
    if (nextIds.isEmpty) return;
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
        if (patch is Map && patch.isNotEmpty && mounted) setState(() => pendingPatch = Map<String,dynamic>.from(patch));
      }
      // Approved campaign IDs are intentionally discovered from the player's own link records via REST.
      final links=await CloudService.approvedPlayerCampaigns(session);
      _ensureRealtime(session, links.map((raw) => '${raw['campaign_id'] ?? ''}'));
      for(final raw in links){
        final state=await CloudService.fetchSessionState(session,'${raw['campaign_id']}');
        if(state==null || state['active']!=true) continue;
        final init=(state['initiative'] as List? ?? []).whereType<Map>().toList();
        final ix=state['current_index'] is int ? state['current_index'] as int : 0;
        if(ix>=0 && ix<init.length && '${init[ix]['id']}'==widget.character.id){
          if(generation!=_syncGeneration) return;
          if(mounted) setState((){turn=true;round=state['round'] is int?state['round']:1;_syncFailures=0;_syncStatus=_realtimeConnected?'Tempo real':'Online';});
          return;
        }
      }
      if(generation!=_syncGeneration) return;
      if (mounted) setState(() { turn=false;  _syncFailures=0; _syncStatus=_realtimeConnected?'Tempo real':'Online'; });
    } catch (_) {
      _syncFailures++;
      if(mounted) setState(()=>_syncStatus=_syncFailures>=3?'Offline':'Reconectando');
    } finally {
      _refreshing=false;
      if(mounted)_scheduleRefresh(_nextRefreshDelay);
    }
  }
  Future<void> _applyPatch() async {
    final patch=pendingPatch; if(patch==null) return;
    final resources=patch['resourceValues'];
    if(resources is Map) resources.forEach((k,v){ if(v is num) widget.character.resourceValues[k.toString()]=v.toInt(); });
    final conditions=patch['conditions'];
    if(conditions is List) widget.character.conditions=conditions.map((e)=>e.toString()).toList();
    await context.read<AppState>().updateCharacter(widget.character);
    final session=await CloudService.ensureSession();
    if(widget.character.shareCode.isNotEmpty) await CloudService.clearSharedCharacterPatch(session, widget.character.shareCode);
    if(mounted) setState(()=>pendingPatch=null);
  }
  @override Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final reduceMotion = appState.reduceAnimations || MediaQuery.maybeOf(context)?.disableAnimations == true;
    return (turn || pendingPatch!=null || widget.character.shareCode.isNotEmpty) ? SafeArea(top:false, child: Column(mainAxisSize:MainAxisSize.min, children:[
    if(!turn && pendingPatch==null && widget.character.shareCode.isNotEmpty)
      Padding(padding:const EdgeInsets.fromLTRB(16,2,16,4),child:Row(mainAxisAlignment:MainAxisAlignment.end,children:[Icon((_syncStatus=='Online'||_syncStatus=='Tempo real')?Icons.cloud_done_outlined:_syncStatus=='Offline'?Icons.cloud_off_outlined:Icons.sync,size:16),const SizedBox(width:6),Text(_syncStatus,style:Theme.of(context).textTheme.labelSmall)])),
    if(pendingPatch!=null) Card(margin:const EdgeInsets.fromLTRB(16,4,16,4), child:ListTile(leading:const Icon(Icons.sync), title:const Text('Alteração do Mestre'), subtitle:const Text('Recursos ou condições foram atualizados.'), trailing:FilledButton(onPressed:_applyPatch, child:const Text('Aplicar')))),
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
        builder:(context,child){
          final accent=Theme.of(context).colorScheme.primary;
          final pulseValue = reduceMotion ? 0.0 : _pulse.value;
          final strength=0.72+(0.28*pulseValue);
          return Container(
            margin:const EdgeInsets.fromLTRB(16,4,16,10),
            decoration:BoxDecoration(
              borderRadius:BorderRadius.circular(18),
              gradient:LinearGradient(colors:[
                accent.withOpacity(0.48+(0.20*pulseValue)),
                accent.withOpacity(0.24+(0.14*pulseValue)),
              ]),
              border:Border.all(color:accent.withOpacity(0.72+(0.25*pulseValue)),width:1.4),
              boxShadow:[BoxShadow(color:accent.withOpacity(0.16+(0.16*pulseValue)),blurRadius:16+(10*pulseValue),spreadRadius:1+(2*pulseValue))],
            ),
            child:ListTile(
              contentPadding:const EdgeInsets.symmetric(horizontal:18,vertical:8),
              leading:Container(
                width:44,height:44,
                decoration:BoxDecoration(shape:BoxShape.circle,color:accent.withOpacity(strength)),
                child:Icon(Icons.flash_on_rounded,color:Theme.of(context).colorScheme.onPrimary),
              ),
              title:Text('SEU TURNO',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800,letterSpacing:0.8)),
              subtitle:Text('Rodada $round • $_syncStatus'),
              trailing:IconButton(tooltip:'Atualizar agora',icon:const Icon(Icons.refresh_rounded),onPressed:_refresh),
            ),
          );
        },
      ) : const SizedBox.shrink(key:ValueKey('no-active-turn')),
    ),
  ])) : const SizedBox.shrink();
  }
}
