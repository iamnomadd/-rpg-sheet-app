import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../core/feature_flags.dart';
import '../widgets/save_failed_banner.dart';
import 'abyss_theme.dart';
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
import '../widgets/flush_on_background.dart';
import '../widgets/update_available_listener.dart';

class RpgSheetApp extends StatefulWidget {
  const RpgSheetApp({super.key});

  @override
  State<RpgSheetApp> createState() => _RpgSheetAppState();
}

class _RpgSheetAppState extends State<RpgSheetApp> {
  final _tabIndex = ValueNotifier<int>(0);
  final _themeCache = AppThemeCache();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _tabIndex.value);
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
      final target = mainTabIndex('settings', masterToolsEnabled: context.read<AppState>().masterToolsEnabled);
      _tabIndex.value = target;
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
    _tabIndex.dispose();
    super.dispose();
  }

  static Widget _mainPage(String role) => switch (role) {
        'characters' => const HomeScreen(),
        'systems' => const SystemsScreen(),
        'tree' => const SkillTreesScreen(),
        'dice' => const DiceScreen(),
        'campaigns' => const MasterScreen(),
        _ => const SettingsScreen(),
      };

  @override
  Widget build(BuildContext context) {
    // Observa só o que o MaterialApp usa. A aba atual fica no _tabIndex e não
    // reconstrói o app.
    final themeId = context.select<AppState, String>((s) => s.themeId);
    final compact = context.select<AppState, bool>((s) => s.compactMode);
    final largeText = context.select<AppState, bool>((s) => s.largeText);
    return FlushOnBackground(child: MaterialApp(
      title: 'Grimório',
      debugShowCheckedModeBanner: false,
      theme: _themeCache.resolve(themeId, compact),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final content = child ?? const SizedBox.shrink();
        final themedContent = AbyssBackground(child: SaveFailedBanner(child: content));
        final userScale = largeText ? 1.15 : (compact ? 0.90 : 1.0);
        final systemScale = media.textScaler.scale(1.0);
        final combinedScale = (systemScale * userScale).clamp(0.85, 2.0).toDouble();
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(combinedScale)),
          child: themedContent,
        );
      },
      home: AccessGate(child: MainTabsShell(
        controller: _pageController,
        index: _tabIndex,
        pageBuilder: _mainPage,
      )),
    ));
  }
}

/// Tema do app (buildTheme + ajustes de densidade), guardado enquanto o tema e
/// o modo compacto não mudam. Devolver sempre a mesma instância evita que o
/// AnimatedTheme do MaterialApp anime e reconstrua o app a cada build.
class AppThemeCache {
  String? _themeId;
  bool? _compact;
  ThemeData? _theme;

  ThemeData resolve(String themeId, bool compact) {
    final cached = _theme;
    if (cached != null && _themeId == themeId && _compact == compact) return cached;
    _themeId = themeId;
    _compact = compact;
    return _theme = buildAppTheme(themeId, compact);
  }
}

ThemeData buildAppTheme(String themeId, bool compact) => buildAbyssAppTheme(buildTheme(themeId), compact);

typedef MainTab = ({String role, String label});

/// Fonte única das abas principais, na ordem da barra: Fichas, Sistemas,
/// Árvore, [Dados], [Mestre], Config. A barra e o PageView saem desta lista,
/// então botões e páginas nunca divergem.
List<MainTab> mainTabs({required bool masterToolsEnabled}) => [
      (role: 'characters', label: 'Fichas'),
      (role: 'systems', label: 'Sistemas'),
      (role: 'tree', label: 'Árvore'),
      if (diceTabEnabled) (role: 'dice', label: 'Dados'),
      if (masterToolsEnabled) (role: 'campaigns', label: 'Mestre'),
      (role: 'settings', label: 'Config.'),
    ];

/// Posição de uma aba na barra atual; 0 (Fichas) se ela não estiver ativa.
int mainTabIndex(String role, {required bool masterToolsEnabled}) {
  final index = mainTabs(masterToolsEnabled: masterToolsEnabled).indexWhere((tab) => tab.role == role);
  return index < 0 ? 0 : index;
}

/// Abas principais: PageView + barra inferior. Trocar de aba só atualiza o
/// [index]; apenas a barra reconstrói (ValueListenableBuilder), e as páginas e
/// o MaterialApp ficam como estão.
class MainTabsShell extends StatelessWidget {
  final PageController controller;
  final ValueNotifier<int> index;
  /// Página de cada aba, pelo papel (`role`) de [mainTabs].
  final Widget Function(String role) pageBuilder;

  const MainTabsShell({
    super.key,
    required this.controller,
    required this.index,
    required this.pageBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final themeId = context.select<AppState, String>((s) => s.themeId);
    final masterToolsEnabled = context.select<AppState, bool>((s) => s.masterToolsEnabled);
    final reduceAnimations = context.select<AppState, bool>((s) => s.reduceAnimations);
    final destinations = mainTabs(masterToolsEnabled: masterToolsEnabled);
    final pages = [for (final tab in destinations) pageBuilder(tab.role)];
    final reduceMotion = reduceAnimations || MediaQuery.maybeDisableAnimationsOf(context) == true;
    return UpdateAvailableListener(child: Scaffold(
      body: PageView(
        controller: controller,
        allowImplicitScrolling: true,
        onPageChanged: (value) => index.value = value,
        children: pages.map((page) => RepaintBoundary(child: page)).toList(),
      ),
      bottomNavigationBar: Material(
        color: Theme.of(context).navigationBarTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Container(
            height: 78,
            decoration: AbyssNavBarDecoration(palette: AbyssPalette.of(context)),
            child: ValueListenableBuilder<int>(
              valueListenable: index,
              builder: (context, current, _) {
                final safeIndex = current >= pages.length ? pages.length - 1 : current;
                return Row(
                  children: List.generate(destinations.length, (value) {
                    final item = destinations[value];
                    final selected = value == safeIndex;
                    return Expanded(
                      child: InkWell(
                        onTap: () {
                          index.value = value;
                          if (reduceMotion) {
                            controller.jumpToPage(value);
                          } else {
                            final distance = (value - safeIndex).abs();
                            final duration = Duration(milliseconds: (380 + (distance - 1).clamp(0, 3) * 45).toInt());
                            controller.animateToPage(value, duration: duration, curve: Curves.easeInOutCubic);
                          }
                        },
                        child: AbyssTabCell(
                          selected: selected,
                          reduceMotion: reduceMotion,
                          fill: true,
                          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                          icon: (color, _) => Icon(themedMainIcon(themeId, item.role), size: 24, color: color),
                          label: item.label,
                          labelStyle: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
      ),
    ));
  }
}
