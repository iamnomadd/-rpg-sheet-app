from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

p = ROOT / 'lib' / 'app' / 'theme.dart'
s = p.read_text(encoding='utf-8')
s = s.replace("if (role == 'abilities') {\n      return ImageIcon(const AssetImage('assets/cyberpunk/demon.png'), size: size * 1.22, color: iconColor);\n    }", "if (role == 'abilities') {\n      return Icon(Icons.precision_manufacturing_outlined, size: size * 1.12, color: iconColor);\n    }")
s = s.replace("    dividerTheme: DividerThemeData(\n      space: 20,\n      thickness: pirate ? 1.2 : 1,\n      color: vampire ? const Color(0xFFFF5C5C) : (pirate ? scheme.primary.withOpacity(.20) : scheme.outlineVariant.withOpacity(.18)),\n    ),", "    dividerTheme: DividerThemeData(\n      space: 20,\n      thickness: 1,\n      color: borderlessCards ? Colors.transparent : scheme.outlineVariant.withOpacity(.18),\n    ),")
p.write_text(s, encoding='utf-8')

p = ROOT / 'lib' / 'app' / 'app.dart'
s = p.read_text(encoding='utf-8')
old = """      theme: baseTheme.copyWith(
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
      ),"""
new = """      theme: baseTheme.copyWith(
        visualDensity: compact
            ? const VisualDensity(horizontal: -4, vertical: -4)
            : const VisualDensity(horizontal: -3, vertical: -3),
        cardTheme: baseTheme.cardTheme.copyWith(margin: EdgeInsets.zero),
        inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
          contentPadding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 7 : 10),
          isDense: true,
          constraints: BoxConstraints(minHeight: compact ? 42 : 48),
          labelStyle: baseTheme.inputDecorationTheme.labelStyle?.copyWith(fontSize: compact ? 11 : 11.5),
          floatingLabelStyle: baseTheme.inputDecorationTheme.labelStyle?.copyWith(fontSize: compact ? 11 : 11.5),
        ),
        listTileTheme: ListTileThemeData(
          dense: true,
          minVerticalPadding: compact ? 0 : 2,
          minLeadingWidth: compact ? 30 : 34,
          contentPadding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
        ),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 6 : 8),
          minimumSize: Size(44, compact ? 34 : 38),
          shape: appState.themeId == 'parchment'
              ? BeveledRectangleBorder(borderRadius: BorderRadius.circular(7))
              : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        )),
        outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 6 : 8),
          minimumSize: Size(44, compact ? 34 : 38),
          shape: appState.themeId == 'parchment'
              ? BeveledRectangleBorder(borderRadius: BorderRadius.circular(7))
              : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        )),
      ),"""
if old not in s:
    raise SystemExit('density block not found')
s = s.replace(old, new)
p.write_text(s, encoding='utf-8')

p = ROOT / 'lib' / 'screens' / 'character' / 'character_screen.dart'
s = p.read_text(encoding='utf-8')
old = "...system.sections.map((section) => Card(child: ListTile(title: Text(section), subtitle: Text((character.sectionNotes[section] ?? '').isEmpty ? 'Toque para preencher.' : character.sectionNotes[section]!), trailing: const Icon(Icons.edit), onTap: () => onEdit(character, section)))),"
new = """...system.sections.map((section) => Card(
        margin: const EdgeInsets.only(bottom: 9),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          title: Text(section, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            (character.sectionNotes[section] ?? '').isEmpty ? 'Toque para preencher.' : character.sectionNotes[section]!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.edit),
          onTap: () => onEdit(character, section),
        ),
      )),"""
if old not in s:
    raise SystemExit('sections card block not found')
s = s.replace(old, new)
p.write_text(s, encoding='utf-8')

p = ROOT / 'lib' / 'screens' / 'settings' / 'settings_screen.dart'
s = p.read_text(encoding='utf-8').replace(
    "subtitle: const Text('Reduz o espaço de controles para mostrar mais conteúdo na tela.'),",
    "subtitle: const Text('Usa uma densidade ainda menor para mostrar mais conteúdo na tela.'),",
)
p.write_text(s, encoding='utf-8')

p = ROOT / 'lib' / 'core' / 'app_version.dart'
s = p.read_text(encoding='utf-8').replace("1.3.21", "1.3.22").replace("appBuildNumber = 121", "appBuildNumber = 122")
p.write_text(s, encoding='utf-8')

p = ROOT / 'pubspec.yaml'
s = p.read_text(encoding='utf-8').replace('version: 1.3.21+121', 'version: 1.3.22+122')
p.write_text(s, encoding='utf-8')

p = ROOT / 'web' / 'rpg_service_worker.js'
s = p.read_text(encoding='utf-8').replace("const VERSION='1.3.21+121';", "const VERSION='1.3.22+122';")
p.write_text(s, encoding='utf-8')

(ROOT / 'RELEASE_NOTES_1.3.22.md').write_text("""# RPG Sheet 1.3.22\n\n- Padroniza a densidade visual: o antigo modo compacto vira a proporção padrão do app.\n- Torna o Modo compacto ainda mais enxuto, principalmente em paddings, campos, listas e botões.\n- Mantém Texto maior com a escala atual.\n- Remove divisores internos coloridos dos temas Vampírico, Arcano, Cyberpunk e Sombrio Pirata.\n- Troca o ícone de Habilidades do Cyberpunk por um símbolo de mão/braço robótico.\n- Padroniza os cards de Seções para seguir o espaçamento visual usado nos cards de inventário.\n""", encoding='utf-8')

print('v1.3.22 design system refinement applied')