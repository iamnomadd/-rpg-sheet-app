import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/character.dart';
import '../../services/app_state.dart';
import '../../widgets/confirm_delete_dialog.dart';
import 'custom_sprite.dart';

/// Escolhe um arquivo de imagem e devolve os bytes (null se cancelado).
typedef CustomSpritePicker = Future<Uint8List?> Function();

/// Imagem única sem imageQuality/maxWidth: o corte precisa da imagem inteira.
Future<Uint8List?> _pickFromGallery() async {
  final file = await ImagePicker().pickImage(source: ImageSource.gallery);
  return file == null ? null : await file.readAsBytes();
}

/// Folha "Personagem 2D": usar o personagem do tema ou as imagens próprias.
/// Em [readOnly] mostra as imagens, sem trocar nada.
Future<void> showCustomSpriteSheet(
  BuildContext context,
  Character character, {
  bool readOnly = false,
  CustomSpritePicker? pick,
  CustomSpriteLimits limits = const CustomSpriteLimits(),
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CustomSpriteSheet(
      character: character,
      readOnly: readOnly,
      pick: pick ?? _pickFromGallery,
      limits: limits,
    ),
  );
}

Widget _thumb(String? dataUri, {double size = 64}) {
  final bytes = dataUri == null ? null : customSpriteDataUriBytesOf(dataUri);
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: size,
      height: size,
      child: bytes == null
          ? const ColoredBox(color: Color(0x22888888), child: Icon(Icons.image_not_supported_outlined, size: 20))
          : Image.memory(bytes, fit: BoxFit.contain, filterQuality: FilterQuality.medium, gaplessPlayback: true),
    ),
  );
}

class _CustomSpriteSheet extends StatefulWidget {
  final Character character;
  final bool readOnly;
  final CustomSpritePicker pick;
  final CustomSpriteLimits limits;

  const _CustomSpriteSheet({required this.character, required this.readOnly, required this.pick, required this.limits});

  @override
  State<_CustomSpriteSheet> createState() => _CustomSpriteSheetState();
}

class _CustomSpriteSheetState extends State<_CustomSpriteSheet> {
  bool _busy = false;

  Character get _c => widget.character;
  bool get _hasImages => _c.customSpriteImages['normal']?.isNotEmpty ?? false;

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Grava; se não der, volta ao que era e nada fica salvo pela metade.
  Future<void> _apply(Map<String, String> images, bool enabled) async {
    final oldImages = Map<String, String>.from(_c.customSpriteImages);
    final oldEnabled = _c.customSpriteEnabled;
    _c.customSpriteImages = images;
    _c.customSpriteEnabled = enabled && (images['normal']?.isNotEmpty ?? false);
    try {
      await context.read<AppState>().updateCharacter(_c);
    } catch (_) {
      _c.customSpriteImages = oldImages;
      _c.customSpriteEnabled = oldEnabled;
      _message('Não foi possível salvar as imagens. O armazenamento pode estar cheio.');
    }
    if (mounted) setState(() {});
  }

  Future<Uint8List?> _pickBytes() async {
    try {
      return await widget.pick();
    } catch (_) {
      _message('Não foi possível abrir a imagem.');
      return null;
    }
  }

  Future<void> _singleImage() async {
    final bytes = await _pickBytes();
    if (bytes == null || !mounted) return;
    final result = await showDialog<_PreviewResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SheetPreviewDialog(bytes: bytes, limits: widget.limits),
    );
    if (!mounted || result == null) return;
    if (result.separate) {
      await _separateImages();
      return;
    }
    await _apply(result.images, true);
  }

  Future<void> _separateImages() async {
    final images = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SeparateImagesDialog(pick: _pickBytes, limits: widget.limits),
    );
    if (!mounted || images == null) return;
    await _apply(images, true);
  }

  Future<void> _replacePose(String pose) async {
    final bytes = await _pickBytes();
    if (bytes == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final uri = await processCustomSpriteSingle(bytes, pose, limits: widget.limits, keep: _c.customSpriteImages);
      if (!mounted) return;
      await _apply({..._c.customSpriteImages, pose: uri}, _c.customSpriteEnabled);
    } on CustomSpriteException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final ok = await confirmDelete(
      context,
      title: 'Remover imagens próprias?',
      message: 'As imagens próprias desta ficha serão apagadas e o personagem do tema volta a aparecer.',
      confirmLabel: 'Remover',
    );
    if (!ok || !mounted) return;
    await _apply({}, false);
  }

  Widget _option({required bool selected, required String title, String? subtitle, VoidCallback? onTap}) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        selected: selected,
        enabled: onTap != null || selected,
        onTap: onTap,
      );

  @override
  Widget build(BuildContext context) {
    final using = customSpriteActive(_c);
    final editable = !widget.readOnly && !_busy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Personagem 2D', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _option(
            selected: !using,
            title: 'Usar o personagem do tema',
            onTap: editable && using ? () => _apply(_c.customSpriteImages, false) : null,
          ),
          _option(
            selected: using,
            title: 'Usar minhas imagens',
            subtitle: _hasImages ? null : 'Adicione uma imagem própria primeiro.',
            onTap: editable && _hasImages && !using ? () => _apply(_c.customSpriteImages, true) : null,
          ),
          if (_hasImages) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
              for (final pose in customSpritePoses)
                Column(mainAxisSize: MainAxisSize.min, children: [
                  _thumb(resolveCustomSpriteImage(_c.customSpriteImages, pose)),
                  const SizedBox(height: 4),
                  Text(customSpritePoseLabels[pose]!, style: Theme.of(context).textTheme.labelSmall),
                  if (!_c.customSpriteImages.containsKey(pose))
                    Text(pose == 'critical' ? 'usa Ferido' : 'usa Normal', style: Theme.of(context).textTheme.labelSmall),
                  if (!widget.readOnly)
                    IconButton(
                      tooltip: 'Trocar este estado (${customSpritePoseLabels[pose]})',
                      visualDensity: VisualDensity.compact,
                      onPressed: editable ? () => _replacePose(pose) : null,
                      icon: const Icon(Icons.swap_horiz),
                    ),
                ]),
            ]),
          ],
          if (_busy) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator())),
          if (!widget.readOnly) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: editable ? _singleImage : null,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_hasImages ? 'Trocar por imagem única' : 'Adicionar imagem própria'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: editable ? _separateImages : null,
              icon: const Icon(Icons.collections_outlined),
              label: const Text('Imagens separadas'),
            ),
            if (_hasImages)
              TextButton.icon(
                onPressed: editable ? _remove : null,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remover imagens próprias'),
              ),
          ],
        ]),
      ),
    );
  }
}

class _PreviewResult {
  final Map<String, String> images;
  final bool separate;
  const _PreviewResult(this.images, {this.separate = false});
}

/// Prévia da imagem única: layout sugerido pela proporção, partes rotuladas.
class _SheetPreviewDialog extends StatefulWidget {
  final Uint8List bytes;
  final CustomSpriteLimits limits;
  const _SheetPreviewDialog({required this.bytes, required this.limits});

  @override
  State<_SheetPreviewDialog> createState() => _SheetPreviewDialogState();
}

class _SheetPreviewDialogState extends State<_SheetPreviewDialog> {
  ui.Image? _source;
  CustomSpriteLayout? _layout;
  Map<String, String>? _images;
  String? _error;
  int _run = 0;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      final source = await decodeCustomSpriteSource(widget.bytes, limits: widget.limits);
      if (!mounted) {
        source.dispose();
        return;
      }
      _source = source;
      await _process(suggestCustomSpriteLayout(source.width, source.height));
    } on CustomSpriteException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _process(CustomSpriteLayout layout) async {
    final source = _source;
    if (source == null) return;
    final run = ++_run;
    setState(() {
      _layout = layout;
      _images = null;
      _error = null;
    });
    try {
      final images = await processCustomSpritePanels(
        source,
        stripPanelRects(source.width, source.height, layout),
        customSpriteLayoutPoses(layout),
        limits: widget.limits,
      );
      if (mounted && run == _run) setState(() => _images = images);
    } on CustomSpriteException catch (e) {
      if (mounted && run == _run) setState(() => _error = e.message);
    }
  }

  @override
  void dispose() {
    _source?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = _layout;
    final images = _images;
    return AlertDialog(
      title: const Text('Imagem única'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (layout != null)
              SegmentedButton<CustomSpriteLayout>(
                segments: [
                  for (final option in CustomSpriteLayout.values)
                    ButtonSegment(value: option, label: Text(customSpriteLayoutLabels[option]!)),
                ],
                selected: {layout},
                onSelectionChanged: (value) => _process(value.first),
              ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
            else if (images == null)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else
              Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
                for (final pose in customSpriteLayoutPoses(layout!))
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    _thumb(images[pose], size: 84),
                    const SizedBox(height: 4),
                    Text(customSpritePoseLabels[pose]!, style: Theme.of(context).textTheme.labelSmall),
                  ]),
              ]),
            if (layout == CustomSpriteLayout.row3) ...[
              const SizedBox(height: 8),
              Text('O Crítico usa a imagem de Ferido.', style: Theme.of(context).textTheme.bodySmall),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(context, const _PreviewResult({}, separate: true)), child: const Text('Usar imagens separadas')),
        FilledButton(onPressed: images == null ? null : () => Navigator.pop(context, _PreviewResult(images)), child: const Text('Salvar')),
      ],
    );
  }
}

/// Uma imagem por estado; Normal obrigatório.
class _SeparateImagesDialog extends StatefulWidget {
  final CustomSpritePicker pick;
  final CustomSpriteLimits limits;
  const _SeparateImagesDialog({required this.pick, required this.limits});

  @override
  State<_SeparateImagesDialog> createState() => _SeparateImagesDialogState();
}

class _SeparateImagesDialogState extends State<_SeparateImagesDialog> {
  final Map<String, String> _images = {};
  String? _busyPose;
  String? _error;

  Future<void> _choose(String pose) async {
    final bytes = await widget.pick();
    if (bytes == null || !mounted) return;
    setState(() {
      _busyPose = pose;
      _error = null;
    });
    try {
      final uri = await processCustomSpriteSingle(bytes, pose, limits: widget.limits, keep: _images);
      if (mounted) setState(() => _images[pose] = uri);
    } on CustomSpriteException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busyPose = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Imagens separadas'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final pose in customSpritePoses)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _thumb(_images[pose], size: 48),
                title: Text(customSpritePoseLabels[pose]!),
                subtitle: Text(pose == 'normal' ? 'Obrigatório' : 'Opcional'),
                trailing: _busyPose == pose
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton(onPressed: _busyPose == null ? () => _choose(pose) : null, child: const Text('Escolher')),
              ),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _images.containsKey('normal') && _busyPose == null ? () => Navigator.pop(context, Map<String, String>.from(_images)) : null,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
