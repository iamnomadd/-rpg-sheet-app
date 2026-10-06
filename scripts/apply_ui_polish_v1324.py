from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

# --- Character sheet: star toggle, critical threshold, incapacitated crop ---
p = ROOT / 'lib' / 'screens' / 'character' / 'character_screen.dart'
s = p.read_text(encoding='utf-8')

old = "detail['showInScene'] == true ? Icons.visibility : Icons.visibility_off_outlined"
new = "detail['showInScene'] == true ? Icons.star : Icons.star_border"
if old not in s:
    raise SystemExit('Em Cena visibility icon pattern not found')
s = s.replace(old, new)

# Critical/agony starts at 40% max life instead of 30%.
if "if (_lifeRatio <= .30) return 'agony';" not in s:
    raise SystemExit('Critical threshold pattern not found')
s = s.replace("if (_lifeRatio <= .30) return 'agony';", "if (_lifeRatio <= .40) return 'agony';")

# Crop the lower embedded caption only for incapacitated sprite.
old_img = "child: Image.asset(_asset, height: 198, fit: BoxFit.contain, filterQuality: FilterQuality.none),"
new_img = """child: incapacitated
                              ? ClipRect(
                                  child: SizedBox(
                                    height: 174,
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: Image.asset(_asset, height: 198, fit: BoxFit.contain, filterQuality: FilterQuality.none),
                                    ),
                                  ),
                                )
                              : Image.asset(_asset, height: 198, fit: BoxFit.contain, filterQuality: FilterQuality.none),"""
count = s.count(old_img)
if count < 1:
    raise SystemExit('Character sprite image pattern not found')
s = s.replace(old_img, new_img)

p.write_text(s, encoding='utf-8')

# --- NPC sheet: normalize action, ability and inventory cards to the approved spacing ---
p = ROOT / 'lib' / 'screens' / 'campaigns' / 'npc_sheet_screen.dart'
s = p.read_text(encoding='utf-8')

# Cards generated from action lists.
s = s.replace(
    "return Card(child: ListTile(",
    "return Card(margin: const EdgeInsets.only(bottom: 9), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),",
)
# Simple Habilidades/Inventário list cards.
s = s.replace(
    "...items.map((name) => Card(child: ListTile(",
    "...items.map((name) => Card(margin: const EdgeInsets.only(bottom: 9), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),",
)
# Empty-state cards should not visually grow more than needed.
s = s.replace(
    "if (items.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Nenhum item em $title.'))),",
    "if (items.isEmpty) Card(margin: const EdgeInsets.only(bottom: 9), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text('Nenhum item em $title.'))),",
)
s = s.replace(
    "if (weaponNames.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Nenhum ataque cadastrado.'))),",
    "if (weaponNames.isEmpty) const Card(margin: EdgeInsets.only(bottom: 9), child: Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text('Nenhum ataque cadastrado.'))),",
)

p.write_text(s, encoding='utf-8')

# --- Master screen: compact the remaining summary cards ---
p = ROOT / 'lib' / 'screens' / 'campaigns' / 'campaigns_screen.dart'
s = p.read_text(encoding='utf-8')

old1 = "Card(child:ListTile(leading:Icon(c.combatActive?Icons.play_circle_fill:Icons.pause_circle_outline),title:Text(c.combatActive?'Sessão em andamento':'Sessão preparada'),subtitle:Text('${c.initiative.length} na iniciativa • ${c.conditions.length} condições'),trailing:const Icon(Icons.chevron_right),onTap:(){_tabs.animateTo(3);})),"
new1 = "Card(margin: const EdgeInsets.only(bottom: 9), child:ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), leading:Icon(c.combatActive?Icons.play_circle_fill:Icons.pause_circle_outline),title:Text(c.combatActive?'Sessão em andamento':'Sessão preparada'),subtitle:Text('${c.initiative.length} na iniciativa • ${c.conditions.length} condições'),trailing:const Icon(Icons.chevron_right),onTap:(){_tabs.animateTo(3);})),"
if old1 not in s:
    raise SystemExit('Master session summary card pattern not found')
s = s.replace(old1, new1)

old2 = "Card(child: ListTile(leading: const Icon(Icons.movie_filter_outlined), title: const Text('Cena atual'), subtitle: Text(c.masterScene.isEmpty ? 'Nenhuma cena definida.' : c.masterScene), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MasterToolsScreen(campaignId: c.id))))),"
new2 = "Card(margin: const EdgeInsets.only(bottom: 9), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), leading: const Icon(Icons.movie_filter_outlined), title: const Text('Cena atual'), subtitle: Text(c.masterScene.isEmpty ? 'Nenhuma cena definida.' : c.masterScene), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MasterToolsScreen(campaignId: c.id))))),"
if old2 not in s:
    raise SystemExit('Master current scene card pattern not found')
s = s.replace(old2, new2)

p.write_text(s, encoding='utf-8')

# --- Version bump ---
p = ROOT / 'lib' / 'core' / 'app_version.dart'
s = p.read_text(encoding='utf-8')
s = s.replace("1.3.23", "1.3.24").replace("appBuildNumber = 123", "appBuildNumber = 124")
p.write_text(s, encoding='utf-8')

p = ROOT / 'pubspec.yaml'
s = p.read_text(encoding='utf-8').replace('version: 1.3.23+123', 'version: 1.3.24+124')
p.write_text(s, encoding='utf-8')

p = ROOT / 'web' / 'rpg_service_worker.js'
s = p.read_text(encoding='utf-8').replace("const VERSION='1.3.23+123';", "const VERSION='1.3.24+124';")
p.write_text(s, encoding='utf-8')

(ROOT / 'RELEASE_NOTES_1.3.24.md').write_text("""# RPG Sheet 1.3.24\n\n- Troca o controle Em Cena por estrela: vazia quando desmarcada e preenchida com a cor do tema quando marcada.\n- Estado crítico do personagem 2D passa a ativar em 40% ou menos da Vida máxima.\n- Remove visualmente a legenda embutida abaixo do sprite Incapacitado por recorte do asset.\n- Padroniza o espaçamento dos cards restantes nas abas do NPC/Mestre.\n- Compacta Sessão preparada e Cena atual para o padrão oficial de cards.\n""", encoding='utf-8')

print('v1.3.24 UI polish applied')
