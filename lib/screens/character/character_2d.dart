part of 'character_screen.dart';

class _CombatCharacter2D extends StatelessWidget {
  final Character character;
  final Animation<double> idle;
  const _CombatCharacter2D({required this.character, required this.idle});

  List<String> get _negativeStatuses => character.conditions.where((name) {
    final preset = conditionPresetFor(name);
    return preset == null || !preset.positive;
  }).toList();

  List<String> get _positiveStatuses => character.conditions.where((name) {
    final preset = conditionPresetFor(name);
    return preset?.positive == true;
  }).toList();

  bool _positiveContains(String fragment) =>
      _positiveStatuses.any((s) => s.toLowerCase().contains(fragment));

  int get _life {
    for (final entry in character.resourceValues.entries) {
      final key = entry.key.toLowerCase();
      if (key == 'vida' || key == 'pv') return entry.value;
    }
    return character.hp;
  }

  int get _lifeMax {
    for (final entry in character.resourceMaxValues.entries) {
      final key = entry.key.toLowerCase();
      if (key == 'vida' || key == 'pv') return entry.value;
    }
    return 0;
  }

  bool _statusContains(String fragment) =>
      _negativeStatuses.any((s) => s.toLowerCase().contains(fragment));

  double get _lifeRatio => _lifeMax > 0 ? (_life / _lifeMax).clamp(0.0, 1.0) : 1.0;

  String get _pose => characterPoseFor(life: _life, lifeMax: _lifeMax, hasNegativeStatus: _negativeStatuses.isNotEmpty);

  String get _healthLabel {
    if (_life <= 0) return 'Incapacitado';
    if (_lifeRatio <= .30) return 'Crítico';
    if (_lifeRatio <= .60) return 'Ferido';
    if (_negativeStatuses.isNotEmpty) return 'Afetado';
    return 'Estável';
  }

  Widget _statusEffects(BuildContext context, double phase) {
    final scheme = Theme.of(context).colorScheme;
    final burning = _statusContains('queim') || _statusContains('fogo');
    final poisoned = _statusContains('enven') || _statusContains('veneno');
    final frozen = _statusContains('congel') || _statusContains('gelo');
    final bleeding = _statusContains('sangr');
    final stunned = _statusContains('atordo') || _statusContains('tonto');
    final protected = _positiveContains('proteg');
    final inspired = _positiveContains('inspir');
    final strengthened = _positiveContains('fortal');
    final accelerated = _positiveContains('aceler');
    final regenerating = _positiveContains('regener');

    return IgnorePointer(
      child: Stack(children: [
        if (burning)
          ...List.generate(5, (i) => Positioned(
            left: 54.0 + i * 23 + (i.isEven ? phase * 4 : -phase * 3),
            bottom: 20.0 + (i % 2) * 10 + phase * 8,
            child: Transform.scale(
              scale: .75 + phase * .28,
              child: Icon(Icons.local_fire_department, size: 20 + phase * 4, color: Colors.deepOrange.withOpacity(.50 + phase * .20)),
            ),
          )),
        if (poisoned)
          ...List.generate(6, (i) => Positioned(
            left: 45.0 + (i * 29) % 140,
            top: 35.0 + (i * 31) % 105 - phase * 8,
            child: Container(
              width: 5 + (i % 3) * 2,
              height: 5 + (i % 3) * 2,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.greenAccent.withOpacity(.28 + phase * .22)),
            ),
          )),
        if (frozen)
          ...List.generate(5, (i) => Positioned(
            left: 62.0 + (i * 31) % 125,
            top: 35.0 + (i * 37) % 130 + (phase - .5) * 7,
            child: Icon(Icons.ac_unit, size: 11 + (i % 3) * 3, color: Colors.lightBlueAccent.withOpacity(.35 + phase * .22)),
          )),
        if (bleeding)
          ...List.generate(3, (i) => Positioned(
            left: 88.0 + i * 24,
            top: 105.0 + i * 16 + phase * 7,
            child: Icon(Icons.water_drop, size: 13 + i * 2, color: Colors.redAccent.withOpacity(.42 + phase * .20)),
          )),
        if (stunned)
          Positioned(
            top: 12, left: 0, right: 0,
            child: Transform.rotate(
              angle: (phase - .5) * .18,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.star, size: 14, color: scheme.primary.withOpacity(.75)),
                const SizedBox(width: 25),
                Icon(Icons.blur_circular, size: 17, color: scheme.primary.withOpacity(.7)),
                const SizedBox(width: 24),
                Icon(Icons.star, size: 12, color: scheme.primary.withOpacity(.65)),
              ]),
            ),
          ),
        if (protected)
          Positioned(
            left: 48, right: 48, top: 25, bottom: 18,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(80),
                border: Border.all(color: scheme.primary.withOpacity(.30 + phase * .16), width: 2),
                boxShadow: [BoxShadow(color: scheme.primary.withOpacity(.08 + phase * .06), blurRadius: 16)],
              ),
            ),
          ),
        if (inspired)
          ...List.generate(4, (i) => Positioned(
            left: 55.0 + i * 38,
            top: 22.0 + (i.isEven ? phase * 14 : (1 - phase) * 16),
            child: Icon(Icons.auto_awesome, size: 12 + (i % 2) * 5, color: Colors.amberAccent.withOpacity(.55 + phase * .25)),
          )),
        if (strengthened)
          Positioned(
            left: 65, right: 65, bottom: 18,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                boxShadow: [BoxShadow(color: scheme.primary.withOpacity(.28 + phase * .18), blurRadius: 18, spreadRadius: 3)],
              ),
            ),
          ),
        if (accelerated)
          ...List.generate(3, (i) => Positioned(
            left: 45.0 - phase * (10 + i * 4),
            top: 72.0 + i * 35,
            child: Container(
              width: 35 + i * 9, height: 2,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: scheme.primary.withOpacity(.25 + phase * .25)),
            ),
          )),
        if (regenerating)
          ...List.generate(5, (i) => Positioned(
            left: 64.0 + (i * 29) % 115,
            bottom: 25.0 + (i * 24) % 110 + phase * 13,
            child: Icon(Icons.add, size: 10 + (i % 2) * 4, color: Colors.greenAccent.withOpacity(.48 + phase * .24)),
          )),
      ]),
    );
  }

  /// Tocar no personagem abre a folha "Personagem 2D" (imagens próprias).
  Widget _customizeTarget(BuildContext context, {required Widget child}) => Semantics(
        button: true,
        label: 'Personagem 2D',
        child: Tooltip(
          message: 'Personagem 2D',
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            // Toque discreto: sem ripple nem realce sobre o personagem.
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            onTap: () => showCustomSpriteSheet(context, character),
            child: child,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final negatives = _negativeStatuses;
    final positives = _positiveStatuses;
    final visibleStatuses = [...negatives, ...positives];
    final incapacitated = _pose == 'incapacitated';
    final critical = _pose == 'critical';
    final agony = _pose == 'agony';
    final state = context.watch<AppState>();
    final themeId = state.themeId;
    final reduceMotion = state.reduceAnimations || MediaQuery.maybeOf(context)?.disableAnimations == true;
    final vampiricTheme = themeId == 'vampire';
    final spritePath = characterSpritePath(themeId: themeId, pose: _pose);
    // Imagens próprias (ilustrações) no lugar do sprite do tema, quando ligadas.
    final customImage = customSpriteActive(character) ? resolveCustomSpriteImage(character.customSpriteImages, _pose) : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(children: [
          Row(children: [
            Expanded(child: Text('Estado do personagem', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                _healthLabel,
                key: ValueKey('$_pose-$_healthLabel'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: incapacitated || critical || agony ? scheme.error : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          _customizeTarget(context, child: AnimatedBuilder(
            animation: idle,
            builder: (context, _) {
              final phase = idle.value;
              final wounded = !incapacitated && !critical && _lifeRatio <= .60;
              final criticalPixelSway = phase < .25 ? -1.0 : phase < .50 ? 0.0 : phase < .75 ? 1.0 : 0.0;
              final criticalPixelBreath = phase < .25 || (phase >= .50 && phase < .75) ? 0.0 : -1.0;
              final breath = reduceMotion || incapacitated ? 0.0 : critical ? (vampiricTheme ? criticalPixelBreath : (phase - .5) * 2.0) : agony ? (phase - .5) * 2.0 : wounded ? (phase - .5) * 2.7 : (phase - .5) * 3.6;
              final lean = reduceMotion || incapacitated || critical ? 0.0 : agony ? -.018 + (phase - .5) * .034 : wounded ? -.009 + (phase - .5) * .016 : (phase - .5) * .008;
              final scale = reduceMotion || incapacitated || critical ? 1.0 : 1.0 + (agony ? phase * .005 : wounded ? phase * .006 : phase * .009);
              final sideSway = reduceMotion || incapacitated ? 0.0 : critical ? (vampiricTheme ? criticalPixelSway : (phase - .5) * 2.0) : agony ? (phase - .5) * 2.0 : wounded ? (phase - .5) * 1.2 : (phase - .5) * .6;
              return SizedBox(
                height: 220,
                child: Stack(alignment: Alignment.center, children: [
                  Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        (critical || agony ? scheme.error : scheme.primary).withOpacity(.08 + phase * .035),
                        Colors.transparent,
                      ],
                      radius: .74,
                    ),
                  ))),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                    child: customImage != null
                        ? CustomSpriteView(
                            key: ValueKey('custom-$_pose'),
                            dataUri: customImage,
                            pose: _pose,
                            breath: idle,
                            reduceMotion: reduceMotion,
                          )
                        : Transform.translate(
                      key: ValueKey(_pose),
                      offset: Offset(sideSway, breath),
                      child: Transform.rotate(
                        angle: lean,
                        child: Transform.scale(
                          scale: scale,
                          child: characterUsesSpecialSprite(themeId)
                              ? SizedBox(
                                  height: 198,
                                  width: 198,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Image.asset(
                                        spritePath,
                                        width: 182,
                                        height: 182,
                                        fit: BoxFit.contain,
                                        alignment: Alignment.bottomCenter,
                                        filterQuality: FilterQuality.none,
                                        isAntiAlias: false,
                                      ),
                                    ),
                                  ),
                                )
                              : Image.asset(spritePath, height: 198, fit: BoxFit.contain, filterQuality: FilterQuality.none),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(child: _statusEffects(context, phase)),
                ]),
              );
            },
          )),
          if (visibleStatuses.isNotEmpty) ...[
            const SizedBox(height: 2),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: visibleStatuses.map((name) {
                final preset = conditionPresetFor(name);
                final positive = preset?.positive == true;
                return Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: ConditionIcon(
                    name,
                    size: 16,
                    // A arte respeita os 16 px pedidos (não encosta no texto).
                    artSize: 16,
                    color: positive ? scheme.tertiary : scheme.error,
                  ),
                  label: Text(name),
                  side: BorderSide(color: (positive ? scheme.tertiary : scheme.error).withOpacity(.22)),
                );
              }).toList(),
            ),
          ],
        ]),
      ),
    );
  }
}
