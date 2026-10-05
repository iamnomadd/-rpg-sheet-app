import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../services/cloud_service.dart';

import '../screens/home/home_screen.dart';
import '../screens/auth/access_gate.dart';
import '../screens/systems/systems_screen.dart';
import '../screens/campaigns/campaigns_screen.dart';
import '../screens/dice/dice_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/home/skill_trees_screen.dart';
import 'theme.dart';

class RpgSheetApp extends StatefulWidget {
  const RpgSheetApp({super.key});

  @override
  State<RpgSheetApp> createState() => _RpgSheetAppState();
}

class _RpgSheetAppState extends State<RpgSheetApp> {
  int index = 0;
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: index);
    _listenForAuthLinks();
  }

  Future<void> _listenForAuthLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) await _handleIncomingLink(initial);
    } catch (_) {}
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) => _handleIncomingLink(uri), onError: (_) {});
  }

  Future<void> _handleIncomingLink(Uri uri) async {
    if (!kIsWeb && (uri.scheme != 'rpgsheet' || uri.host != 'auth-callback')) return;
    try {
      final result = await CloudService.handleAuthCallback(uri);
      if (!mounted || result == null) return;
      final target = context.read<AppState>().masterToolsEnabled ? 5 : 4;
      setState(() => index = target);
      if (_pageController.hasClients) _pageController.jumpToPage(target);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        result.isAnonymous ? 'Confirmação recebida. Atualizando sua conta...' : 'E-mail confirmado. Sua nuvem está protegida.',
      )));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final baseTheme = buildTheme(appState.themeId);
    final compact = appState.compactMode;
    return MaterialApp(
      title: 'RPG Sheet',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        visualDensity: compact ? const VisualDensity(horizontal: -3, vertical: -3) : VisualDensity.standard,
        cardTheme: compact ? baseTheme.cardTheme.copyWith(margin: EdgeInsets.zero) : baseTheme.cardTheme,
        inputDecorationTheme: compact
            ? baseTheme.inputDecorationTheme.copyWith(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                isDense: true,
                constraints: const BoxConstraints(minHeight: 48),
                labelStyle: baseTheme.inputDecorationTheme.labelStyle?.copyWith(fontSize: 11.5),
                floatingLabelStyle: baseTheme.inputDecorationTheme.labelStyle?.copyWith(fontSize: 11.5),
              )
            : baseTheme.inputDecorationTheme,
        listTileTheme: compact ? const ListTileThemeData(dense: true, minVerticalPadding: 2, contentPadding: EdgeInsets.symmetric(horizontal: 10)) : const ListTileThemeData(),
        filledButtonTheme: compact ? FilledButtonThemeData(style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), minimumSize: const Size(44, 38), shape: appState.themeId == 'parchment' ? BeveledRectangleBorder(borderRadius: BorderRadius.circular(7)) : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))) : baseTheme.filledButtonTheme,
        outlinedButtonTheme: compact ? OutlinedButtonThemeData(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), minimumSize: const Size(44, 38), shape: appState.themeId == 'parchment' ? BeveledRectangleBorder(borderRadius: BorderRadius.circular(7)) : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))) : baseTheme.outlinedButtonTheme,
      ),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final content = child ?? const SizedBox.shrink();
        final themedContent = appState.themeId == 'parchment'
            ? DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF050A12),
                      Color(0xFF080F18),
                      Color(0xFF111820),
                    ],
                    stops: [0, .52, 1],
                  ),
                ),
                child: content,
              )
            : content;
        final userScale = appState.largeText ? 1.15 : (compact ? 0.90 : 1.0);
        final systemScale = media.textScaler.scale(1.0);
        final combinedScale = (systemScale * userScale).clamp(0.85, 2.0).toDouble();
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(combinedScale)),
          child: themedContent,
        );
      },
      home: Builder(builder: (context) {
        final pages = <Widget>[
          const HomeScreen(),
          const SystemsScreen(),
          const SkillTreesScreen(),
          const DiceScreen(),
          if (appState.masterToolsEnabled) const MasterScreen(),
          const SettingsScreen(),
        ];
        final safeIndex = index >= pages.length ? pages.length - 1 : index;
        final reduceMotion = appState.reduceAnimations || MediaQuery.maybeOf(context)?.disableAnimations == true;
        final destinations = <({String role, String label})>[
          (role: 'characters', label: 'Fichas'),
          (role: 'systems', label: 'Sistemas'),
          (role: 'tree', label: 'Árvore'),
          (role: 'dice', label: 'Dados'),
          if (appState.masterToolsEnabled) (role: 'campaigns', label: 'Mestre'),
          (role: 'settings', label: 'Config.'),
        ];
        return AccessGate(child: Scaffold(
          body: PageView(
            controller: _pageController,
            allowImplicitScrolling: true,
            onPageChanged: (value) { if (mounted) setState(() => index = value); },
            children: pages.map((page) => RepaintBoundary(child: page)).toList(),
          ),
          bottomNavigationBar: Material(
            color: Theme.of(context).navigationBarTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
            child: SafeArea(
              top: false,
              child: Container(
                height: 78,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(
                    color: appState.themeId == 'vampire'
                        ? const Color(0xFFB7211C)
                        : Theme.of(context).colorScheme.outlineVariant.withOpacity(.32),
                  )),
                ),
                child: Row(
                  children: List.generate(destinations.length, (value) {
                    final item = destinations[value];
                    final selected = value == safeIndex;
                    final scheme = Theme.of(context).colorScheme;
                    final vampire = appState.themeId == 'vampire';
                    return Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() => index = value);
                          if (reduceMotion) {
                            _pageController.jumpToPage(value);
                          } else {
                            final distance = (value - safeIndex).abs();
                            final duration = Duration(milliseconds: (380 + (distance - 1).clamp(0, 3) * 45).toInt());
                            _pageController.animateToPage(value, duration: duration, curve: Curves.easeInOutCubic);
                          }
                        },
                        child: AnimatedContainer(
                          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(
                              color: selected ? scheme.primary : Colors.transparent,
                              width: 4,
                            )),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                selected
                                    ? themedSelectedMainIcon(appState.themeId, item.role)
                                    : themedMainIcon(appState.themeId, item.role),
                                size: 24,
                                color: vampire ? scheme.primary : (selected ? scheme.primary : scheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: selected ? scheme.primary : scheme.onSurface,
                                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ));
      }),
    );
  }
}
