import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/abyss_resource_art.dart';
import '../../app/abyss_theme.dart';
import '../../app/condition_presets.dart';
import '../../models/character.dart';
import '../../models/rpg_system.dart';
import '../../services/app_state.dart';
import '../../services/web_platform.dart';
import 'character_sprites.dart';
import 'custom_sprite.dart';

/// Tamanho lógico do cartão (proporção 4:5).
const shareCardSize = Size(360, 450);

/// Largura do PNG gerado (px).
const shareImageWidth = 1080.0;

/// Limites do cartão: acima deles, mostra os primeiros e um "+N".
const shareCardMaxResources = 4;
const shareCardMaxAttributes = 6;
const shareCardMaxConditions = 4;

/// Nome do arquivo da imagem: `<nome-do-personagem>.png`.
String shareImageFileName(String characterName) {
  final safe = characterName.trim().replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), '_');
  return '${safe.isEmpty ? 'personagem' : safe}.png';
}

/// Os primeiros itens que cabem e quantos ficaram de fora ("+N"). Com mais
/// itens que [max], mostra `max - 1` e um "+N" no lugar do último.
({List<T> shown, int hidden}) shareCardLimit<T>(List<T> items, int max) {
  if (items.length <= max) return (shown: items, hidden: 0);
  return (shown: items.take(max - 1).toList(), hidden: items.length - (max - 1));
}

int _life(Character c, {required bool max}) {
  final values = max ? c.resourceMaxValues : c.resourceValues;
  for (final entry in values.entries) {
    final key = entry.key.toLowerCase();
    if (key == 'vida' || key == 'pv') return entry.value;
  }
  return max ? 0 : c.hp;
}

/// Pose atual do personagem (mesma regra do card de combate).
String characterSharePose(Character c) => characterPoseFor(
      life: _life(c, max: false),
      lifeMax: _life(c, max: true),
      hasNegativeStatus: c.conditions.any((name) => conditionPresetFor(name)?.positive != true),
    );

/// Cartão da ficha para compartilhar como imagem: nome, sistema, personagem
/// 2D na pose atual, recursos, atributos e condições, nas cores do tema.
class CharacterShareCard extends StatelessWidget {
  final Character character;
  final RpgSystem system;

  const CharacterShareCard({super.key, required this.character, required this.system});

  @override
  Widget build(BuildContext context) {
    final p = AbyssPalette.of(context);
    final themeId = context.select<AppState, String>((s) => s.themeId);
    final c = character;
    final resourceNames = [
      ...system.resources.where(c.resourceValues.containsKey),
      ...c.resourceValues.keys.where((name) => !system.resources.contains(name)),
    ];
    final attributeNames = [
      ...system.attributes.where(c.attributes.containsKey),
      ...c.attributes.keys.where((name) => !system.attributes.contains(name)),
    ];
    final resources = shareCardLimit(resourceNames, shareCardMaxResources);
    final attributes = shareCardLimit(attributeNames, shareCardMaxAttributes);
    final conditions = shareCardLimit(c.conditions, shareCardMaxConditions);

    TextStyle style(double size, {Color? color, FontWeight weight = FontWeight.w600}) =>
        TextStyle(fontSize: size, color: color ?? p.cream, fontWeight: weight, height: 1.2);

    Widget sectionTitle(String text) => Text(text.toUpperCase(), style: style(10, color: p.gold, weight: FontWeight.w800).copyWith(letterSpacing: 1.2));

    Widget cell(Widget child) => Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: p.raised, borderRadius: BorderRadius.circular(8), border: Border.all(color: p.goldLine)),
          alignment: Alignment.centerLeft,
          child: child,
        );

    // Números grandes encolhem (fonte menor) dentro de uma largura máxima.
    Widget fitted(Widget child, double maxWidth) => ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: child),
        );

    Widget more(int hidden) => cell(Center(child: Text('+$hidden', style: style(12, color: p.goldLight, weight: FontWeight.w800))));

    final attributeCells = <Widget>[
      for (final name in attributes.shown)
        cell(Row(children: [
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: style(11, color: p.creamMuted))),
          const SizedBox(width: 4),
          fitted(Text('${c.attributes[name] ?? 0}', style: style(13, weight: FontWeight.w800)), 40),
        ])),
      if (attributes.hidden > 0) more(attributes.hidden),
    ];

    Widget grid(List<Widget> cells, int columns) {
      final rows = <Widget>[];
      for (var i = 0; i < cells.length; i += columns) {
        if (rows.isNotEmpty) rows.add(const SizedBox(height: 6));
        rows.add(Row(children: [
          for (var j = 0; j < columns; j++) ...[
            if (j > 0) const SizedBox(width: 6),
            Expanded(child: i + j < cells.length ? cells[i + j] : const SizedBox.shrink()),
          ],
        ]));
      }
      return Column(mainAxisSize: MainAxisSize.min, children: rows);
    }

    final conditionCells = <Widget>[
      for (final name in conditions.shown)
        cell(Row(children: [
          ConditionIcon(name, size: 16, color: conditionPresetFor(name)?.positive == true ? p.goldLight : p.cream),
          const SizedBox(width: 4),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: style(11))),
        ])),
      if (conditions.hidden > 0) more(conditions.hidden),
    ];

    // O cartão é uma imagem de tamanho fixo: o texto não segue a escala do
    // sistema (os limites "+N" e as reticências garantem que tudo caiba).
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox.fromSize(
        key: const ValueKey('share-card'),
        size: shareCardSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.gold, width: 1.5),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [p.backgroundTop, p.backgroundMiddle, p.backgroundBottom],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(c.name.isEmpty ? 'Personagem' : c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: style(22, weight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(system.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: style(13, color: p.creamMuted, weight: FontWeight.w500)),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    width: 140,
                    decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.goldLine)),
                    padding: const EdgeInsets.all(8),
                    child: _ShareSprite(character: c, themeId: themeId),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (resourceNames.isEmpty) Text('Sem recursos', style: style(12, color: p.creamMuted)),
                      for (final name in resources.shown)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Row(children: [
                              Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: style(12))),
                              const SizedBox(width: 6),
                              fitted(Text('${c.resourceValues[name] ?? 0} / ${c.resourceMaxValues[name] ?? 0}', style: style(12, weight: FontWeight.w800)), 80),
                            ]),
                            const SizedBox(height: 3),
                            AbyssResourceBar(
                              value: (c.resourceMaxValues[name] ?? 0) <= 0 ? 0 : ((c.resourceValues[name] ?? 0) / c.resourceMaxValues[name]!).clamp(0.0, 1.0),
                              secondary: name.toLowerCase() != 'vida',
                              colors: abyssResourceBarColors(name),
                            ),
                          ]),
                        ),
                      if (resources.hidden > 0) Text('+${resources.hidden} recursos', style: style(11, color: p.goldLight, weight: FontWeight.w800)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              sectionTitle('Atributos'),
              const SizedBox(height: 6),
              if (attributeCells.isEmpty) Text('Sem atributos', style: style(12, color: p.creamMuted)) else grid(attributeCells, 3),
              const SizedBox(height: 12),
              sectionTitle('Condições'),
              const SizedBox(height: 6),
              if (conditionCells.isEmpty) Text('Nenhuma condição ativa', style: style(12, color: p.creamMuted)) else grid(conditionCells, 2),
              const Spacer(),
              Text('Grimório', textAlign: TextAlign.right, style: style(10, color: p.goldDim, weight: FontWeight.w700).copyWith(letterSpacing: 1)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Personagem 2D na pose atual: sprite do tema (pixel art: contain, sem
/// filtro e sem anti-aliasing) ou a imagem própria, como no card de combate.
class _ShareSprite extends StatelessWidget {
  final Character character;
  final String themeId;

  const _ShareSprite({required this.character, required this.themeId});

  @override
  Widget build(BuildContext context) {
    final pose = characterSharePose(character);
    final custom = customSpriteActive(character) ? resolveCustomSpriteImage(character.customSpriteImages, pose) : null;
    final bytes = custom == null ? null : customSpriteDataUriBytesOf(custom);
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(bytes, key: ValueKey('share-sprite-custom-$pose'), fit: BoxFit.contain, filterQuality: FilterQuality.medium, gaplessPlayback: true),
      );
    }
    return Image.asset(
      characterSpritePath(themeId: themeId, pose: pose),
      key: ValueKey('share-sprite-$pose'),
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.none,
      isAntiAlias: false,
    );
  }
}

/// Gera o PNG do [RepaintBoundary] de [key] com ~[shareImageWidth] px de largura.
Future<Uint8List> renderShareImage(GlobalKey key) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: shareImageWidth / boundary.size.width);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('PNG vazio');
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Prévia do cartão com "Compartilhar" e "Salvar imagem". A imagem é gerada
/// só no aparelho; nada vai para a nuvem.
class CharacterShareImageScreen extends StatefulWidget {
  final Character character;
  final RpgSystem system;

  const CharacterShareImageScreen({super.key, required this.character, required this.system});

  @override
  State<CharacterShareImageScreen> createState() => _CharacterShareImageScreenState();
}

class _CharacterShareImageScreenState extends State<CharacterShareImageScreen> {
  final _boundary = GlobalKey();
  bool _busy = false;

  String get _fileName => shareImageFileName(widget.character.name);

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function(Uint8List bytes) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await renderShareImage(_boundary);
      await action(bytes);
    } catch (e) {
      debugPrint('Imagem da ficha falhou: $e');
      _message('Não foi possível gerar a imagem.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() => _run((bytes) async {
        if (kIsWeb && !WebPlatform.instance.canShareFiles()) {
          // Navegador sem compartilhamento de arquivos: baixa a imagem.
          final ok = WebPlatform.instance.download(bytes, _fileName, 'image/png');
          _message(ok
              ? 'Este navegador não compartilha imagens. A imagem foi baixada.'
              : 'Este navegador não compartilha nem baixa imagens.');
          return;
        }
        await Share.shareXFiles(
          [XFile.fromData(bytes, mimeType: 'image/png', name: _fileName)],
          fileNameOverrides: [_fileName],
        );
      });

  Future<void> _save() => _run((bytes) async {
        if (kIsWeb) {
          final ok = WebPlatform.instance.download(bytes, _fileName, 'image/png');
          _message(ok ? 'Imagem salva.' : 'Não foi possível salvar a imagem.');
          return;
        }
        // Fora do Web não há download sem dependência nova: usa o compartilhar
        // do sistema, que oferece salvar o arquivo.
        await Share.shareXFiles(
          [XFile.fromData(bytes, mimeType: 'image/png', name: _fileName)],
          fileNameOverrides: [_fileName],
        );
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compartilhar como imagem')),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: RepaintBoundary(
                    key: _boundary,
                    child: CharacterShareCard(character: widget.character, system: widget.system),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 8, children: [
              FilledButton.icon(
                onPressed: _busy ? null : _share,
                icon: const Icon(Icons.ios_share),
                label: const Text('Compartilhar'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Salvar imagem'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
