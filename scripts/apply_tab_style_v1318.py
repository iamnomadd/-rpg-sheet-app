from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# ----------------------------
# Theme: vampire palette + global TabBar reference style
# ----------------------------
p = ROOT / 'lib/app/theme.dart'
s = p.read_text(encoding='utf-8')

# Vampire border color becomes #B7211C while primary remains #B70F00.
s = s.replace("outline: const Color(0xFFB70F00),", "outline: const Color(0xFFB7211C),")
s = s.replace("outlineVariant: const Color(0xFFB70F00),", "outlineVariant: const Color(0xFFB7211C),")
s = s.replace("onSecondaryContainer: const Color(0xFFF3F3F3),", "onSecondaryContainer: const Color(0xFFB70F00),")

# Replace vampire-specific border usages, but keep the theme primary red untouched elsewhere.
replacements = {
    "side: BorderSide(color: vampire ? const Color(0xFFB70F00) : scheme.outlineVariant.withOpacity(.18), width: vampire ? 1.35 : 1),":
        "side: BorderSide(color: vampire ? const Color(0xFFB7211C) : scheme.outlineVariant.withOpacity(.18), width: vampire ? 1.35 : 1),",
    "borderSide: BorderSide(color: vampire ? const Color(0xFFB70F00) : scheme.outlineVariant.withOpacity(pirate ? .55 : .28), width: vampire ? 1.2 : 1),":
        "borderSide: BorderSide(color: vampire ? const Color(0xFFB7211C) : scheme.outlineVariant.withOpacity(pirate ? .55 : .28), width: vampire ? 1.2 : 1),",
    "borderSide: BorderSide(color: vampire ? const Color(0xFFB70F00) : scheme.primary.withOpacity(.85), width: vampire ? 1.6 : (pirate ? 1.4 : 1)),":
        "borderSide: BorderSide(color: vampire ? const Color(0xFFB7211C) : scheme.primary.withOpacity(.85), width: vampire ? 1.6 : (pirate ? 1.4 : 1)),",
    "side: pirate ? const BorderSide(color: Color(0xFF8A6C3E), width: 1.1) : (vampire ? const BorderSide(color: Color(0xFFB70F00), width: 1.2) : null),":
        "side: pirate ? const BorderSide(color: Color(0xFF8A6C3E), width: 1.1) : (vampire ? const BorderSide(color: Color(0xFFB7211C), width: 1.2) : null),",
    "side: BorderSide(color: vampire ? const Color(0xFFB70F00) : (pirate ? scheme.primary.withOpacity(.42) : scheme.outlineVariant.withOpacity(.55)), width: vampire ? 1.2 : 1),":
        "side: BorderSide(color: vampire ? const Color(0xFFB7211C) : (pirate ? scheme.primary.withOpacity(.42) : scheme.outlineVariant.withOpacity(.55)), width: vampire ? 1.2 : 1),",
    "side: BorderSide(color: vampire ? const Color(0xFFB70F00) : scheme.outlineVariant.withOpacity(.18), width: vampire ? 1.3 : 1),":
        "side: BorderSide(color: vampire ? const Color(0xFFB7211C) : scheme.outlineVariant.withOpacity(.18), width: vampire ? 1.3 : 1),",
    "side: pirate ? BorderSide(color: scheme.primary.withOpacity(.20)) : (vampire ? const BorderSide(color: Color(0xFFB70F00), width: 1.2) : BorderSide.none),":
        "side: pirate ? BorderSide(color: scheme.primary.withOpacity(.20)) : (vampire ? const BorderSide(color: Color(0xFFB7211C), width: 1.2) : BorderSide.none),",
    "side: BorderSide(color: vampire ? const Color(0xFFB70F00) : scheme.outlineVariant.withOpacity(.18), width: vampire ? 1.2 : 1),":
        "side: BorderSide(color: vampire ? const Color(0xFFB7211C) : scheme.outlineVariant.withOpacity(.18), width: vampire ? 1.2 : 1),",
    "side: BorderSide(color: vampire ? const Color(0xFFB70F00) : (pirate ? scheme.primary.withOpacity(.28) : scheme.outlineVariant.withOpacity(.22)), width: vampire ? 1.1 : 1),":
        "side: BorderSide(color: vampire ? const Color(0xFFB7211C) : (pirate ? scheme.primary.withOpacity(.28) : scheme.outlineVariant.withOpacity(.22)), width: vampire ? 1.1 : 1),",
    "color: vampire ? const Color(0xFFB70F00) : (pirate ? scheme.primary.withOpacity(.20) : scheme.outlineVariant.withOpacity(.18)),":
        "color: vampire ? const Color(0xFFB7211C) : (pirate ? scheme.primary.withOpacity(.20) : scheme.outlineVariant.withOpacity(.18)),",
}
for old, new in replacements.items():
    s = s.replace(old, new)

# Add a global TabBarTheme matching the Master Mode visual language.
anchor = "    navigationBarTheme: NavigationBarThemeData(\n"
if "tabBarTheme: TabBarThemeData(" not in s:
    tab_theme = """    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurface,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      indicatorColor: scheme.primary,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: vampire ? const Color(0xFFB7211C) : scheme.outlineVariant.withOpacity(.32),
      dividerHeight: 1,
      overlayColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.pressed) ? scheme.primary.withOpacity(.10) : Colors.transparent),
    ),
"""
    s = s.replace(anchor, tab_theme + anchor)

p.write_text(s, encoding='utf-8')

# ----------------------------
# Character sheet tabs: same visual language as Master Mode.
# ----------------------------
p = ROOT / 'lib/screens/character/character_screen.dart'
s = p.read_text(encoding='utf-8')
old = """              SliverPersistentHeader(
                pinned: true,
                delegate: _CharacterTabsHeader(
                  height: 54,
                  child: Material(
                    color: state.themeId == 'parchment' ? Theme.of(context).colorScheme.surface.withOpacity(.96) : Theme.of(context).scaffoldBackgroundColor,
                    child: Container(
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(.20)))),
                      child: SizedBox(height: 54, child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: Row(children: order.asMap().entries.map((entry) {
                          final index=entry.key,id=entry.value,selected=tab==index; final colors=Theme.of(context).colorScheme;
                          final pirate=state.themeId=='parchment';
                          final vampire=state.themeId=='vampire';
                          final tabRadius=BorderRadius.circular(pirate?6:12);
                          return Padding(padding:const EdgeInsets.only(right:6),child:InkWell(
                            borderRadius:tabRadius,onTap:(){
                              final previousTab=tab;
                              setState(()=>tab=index);
                              if (reduceMotion) {
                                _tabController.jumpToPage(index);
                              } else {
                                final distance=(index-previousTab).abs();
                                _tabController.animateToPage(index,duration:Duration(milliseconds:(380+(distance-1).clamp(0,3)*40).toInt()),curve:Curves.easeInOutCubic);
                              }
                            },
                            child:AnimatedContainer(duration:reduceMotion ? Duration.zero : const Duration(milliseconds:160),padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
                              decoration:BoxDecoration(
                                color:vampire?const Color(0xFF242426):(selected?(pirate?colors.primaryContainer.withOpacity(.72):colors.primary.withOpacity(.16)):Colors.transparent),
                                borderRadius:tabRadius,
                                border:Border.all(color:vampire?const Color(0xFFB70F00):(selected?colors.primary.withOpacity(pirate ? .50 : .28):(pirate?colors.outlineVariant.withOpacity(.32):Colors.transparent)),width:vampire?1.2:1),
                              ),
                              child:Row(mainAxisSize:MainAxisSize.min,children:[
                                themedCharacterTabIcon(state.themeId,id,size:18,color:state.themeId=='vampire'?colors.primary:(selected?colors.primary:colors.onSurfaceVariant)),const SizedBox(width:7),
                                Text(_tabLabel(id),style:Theme.of(context).textTheme.labelLarge?.copyWith(color:selected?(pirate?colors.onPrimaryContainer:colors.onSurface):colors.onSurfaceVariant,fontWeight:selected?FontWeight.w800:FontWeight.w600,letterSpacing:pirate ? .2 : null)),
                              ]),
                            ),
                          ));
                        }).toList()),
                      )),
                    ),
                  ),
                ),
              ),"""
new = """              SliverPersistentHeader(
                pinned: true,
                delegate: _CharacterTabsHeader(
                  height: 72,
                  child: Material(
                    color: state.themeId == 'parchment' ? Theme.of(context).colorScheme.surface.withOpacity(.96) : Theme.of(context).scaffoldBackgroundColor,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(
                          color: state.themeId == 'vampire'
                              ? const Color(0xFFB7211C)
                              : Theme.of(context).colorScheme.outlineVariant.withOpacity(.32),
                        )),
                      ),
                      child: SizedBox(
                        height: 72,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: order.asMap().entries.map((entry) {
                            final index = entry.key, id = entry.value, selected = tab == index;
                            final colors = Theme.of(context).colorScheme;
                            final vampire = state.themeId == 'vampire';
                            return InkWell(
                              onTap: () {
                                final previousTab = tab;
                                setState(() => tab = index);
                                if (reduceMotion) {
                                  _tabController.jumpToPage(index);
                                } else {
                                  final distance = (index - previousTab).abs();
                                  _tabController.animateToPage(
                                    index,
                                    duration: Duration(milliseconds: (380 + (distance - 1).clamp(0, 3) * 40).toInt()),
                                    curve: Curves.easeInOutCubic,
                                  );
                                }
                              },
                              child: AnimatedContainer(
                                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(
                                    color: selected ? colors.primary : Colors.transparent,
                                    width: selected ? 4 : 4,
                                  )),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    themedCharacterTabIcon(
                                      state.themeId,
                                      id,
                                      size: 22,
                                      color: vampire ? colors.primary : (selected ? colors.primary : colors.onSurfaceVariant),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _tabLabel(id),
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: selected ? colors.primary : colors.onSurface,
                                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList()),
                        ),
                      ),
                    ),
                  ),
                ),
              ),"""
if old not in s:
    raise SystemExit('character tab block not found')
s = s.replace(old, new)
p.write_text(s, encoding='utf-8')

# ----------------------------
# Main navigation: Master-style icons + labels + underline.
# ----------------------------
p = ROOT / 'lib/app/app.dart'
s = p.read_text(encoding='utf-8')
old = """        NavigationDestination destination(String role, String label) => NavigationDestination(
          icon: Icon(themedMainIcon(appState.themeId, role)),
          selectedIcon: Icon(themedSelectedMainIcon(appState.themeId, role)),
          label: label,
        );
        final destinations = <NavigationDestination>[
          destination('characters', 'Fichas'),
          destination('systems', 'Sistemas'),
          destination('tree', 'Árvore'),
          destination('dice', 'Dados'),
          if (appState.masterToolsEnabled) destination('campaigns', 'Mestre'),
          destination('settings', 'Config.'),
        ];"""
new = """        final destinations = <({String role, String label})>[
          (role: 'characters', label: 'Fichas'),
          (role: 'systems', label: 'Sistemas'),
          (role: 'tree', label: 'Árvore'),
          (role: 'dice', label: 'Dados'),
          if (appState.masterToolsEnabled) (role: 'campaigns', label: 'Mestre'),
          (role: 'settings', label: 'Config.'),
        ];"""
if old not in s:
    raise SystemExit('main destination block not found')
s = s.replace(old, new)
old2 = """          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              border: appState.themeId == 'vampire'
                  ? const Border(top: BorderSide(color: Color(0xFFB70F00), width: 1.2))
                  : null,
            ),
            child: NavigationBar(
              selectedIndex: safeIndex,
              onDestinationSelected: (value) {
                setState(() => index = value);
                if (reduceMotion) {
                  _pageController.jumpToPage(value);
                } else {
                  final distance = (value - safeIndex).abs();
                  final duration = Duration(milliseconds: (380 + (distance - 1).clamp(0, 3) * 45).toInt());
                  _pageController.animateToPage(value, duration: duration, curve: Curves.easeInOutCubic);
                }
              },
              destinations: destinations,
            ),
          ),"""
new2 = """          bottomNavigationBar: Material(
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
          ),"""
if old2 not in s:
    raise SystemExit('bottom navigation block not found')
s = s.replace(old2, new2)
p.write_text(s, encoding='utf-8')

# ----------------------------
# Version metadata
# ----------------------------
p = ROOT / 'pubspec.yaml'
s = p.read_text(encoding='utf-8').replace('version: 1.3.17+117', 'version: 1.3.18+118')
p.write_text(s, encoding='utf-8')

p = ROOT / 'lib/core/app_version.dart'
s = p.read_text(encoding='utf-8')
s = s.replace("appVersion = '1.3.17'", "appVersion = '1.3.18'")
s = s.replace('appBuildNumber = 117', 'appBuildNumber = 118')
p.write_text(s, encoding='utf-8')

p = ROOT / 'web/rpg_service_worker.js'
s = p.read_text(encoding='utf-8').replace("const VERSION='1.3.17+117';", "const VERSION='1.3.18+118';")
p.write_text(s, encoding='utf-8')

p = ROOT / 'README.md'
s = p.read_text(encoding='utf-8')
s = s.replace('V1.3.17 (Web/PWA)', 'V1.3.18 (Web/PWA)')
s = s.replace('**1.3.17+117**', '**1.3.18+118**')
p.write_text(s, encoding='utf-8')

notes = ROOT / 'RELEASE_NOTES_1.3.18.md'
notes.write_text("""# RPG Sheet 1.3.18+118\n\n## Navegação unificada\n- O padrão visual de abas do Modo Mestre passa a ser a referência para a navegação principal e para as fichas.\n- Ícone acima do texto, estado ativo destacado pela cor do tema e indicador inferior contínuo.\n- Transições existentes foram preservadas.\n\n## Tema Vampírico\n- Cor principal preservada em `#B70F00`.\n- Bordas e divisores vampíricos passam a usar `#B7211C`.\n- Ações tonais agora herdam o vermelho do tema no texto/ícone, eliminando inconsistências como o botão Curar neutro.\n- Fundo preto e superfícies cinza escuro permanecem inalterados.\n""", encoding='utf-8')
