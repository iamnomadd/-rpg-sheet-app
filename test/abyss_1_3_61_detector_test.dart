import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/app/abyss_resource_art.dart';
import 'package:rpg_sheet_app/app/abyss_tab_art.dart';
import 'package:rpg_sheet_app/app/abyss_theme.dart';
import 'package:rpg_sheet_app/app/theme.dart';
import 'package:rpg_sheet_app/utils/action_art.dart';

String? art(ActionArtKind kind, String name, {String category = ''}) =>
    ActionArtResolver.resolve(kind: kind, name: name, category: category)?.replaceFirst(ActionArtResolver.folder, '').replaceFirst('.webp', '');

void main() {
  group('B: barras de recurso', () {
    test('B1: "Saúde Mental" é sanidade (não vida)', () {
      expect(abyssResourceKind('Saúde Mental'), 'res_sanity');
      expect(abyssResourceKind('Saúde'), 'res_life');
      expect(abyssResourceKind('Sanidade'), 'res_sanity');
    });
    test('B2: "Pontos de Esforço" é energia', () {
      expect(abyssResourceKind('Pontos de Esforço'), 'res_energy');
      expect(abyssResourceKind('Esforço'), 'res_energy');
    });
    test('abyssResourceArt usa o tipo sem mudar resultados', () {
      expect(abyssResourceArt('Vida'), '${abyssResourceArtFolder}res_life.webp');
      expect(abyssResourceArt('XYZ'), '${abyssResourceArtFolder}res_generic.webp');
      expect(abyssResourceArt(''), isNull);
      expect(abyssResourceKind(''), isNull);
    });
  });

  group('C: detector de ações', () {
    test('C1: expressões antes dos elementos', () {
      expect(art(ActionArtKind.spell, 'Arma Sagrada', category: 'Magia'), 'spell_enchanted_weapon');
      expect(art(ActionArtKind.spell, 'Visão no Escuro', category: 'Magia'), 'spell_vision');
      expect(art(ActionArtKind.spell, 'Arma Mágica', category: 'Magia'), 'spell_enchanted_weapon');
      expect(art(ActionArtKind.spell, 'Escuridão', category: 'Magia'), 'spell_shadow', reason: 'sem a expressão, segue sombra');
      expect(art(ActionArtKind.spell, 'Chama Sagrada', category: 'Magia'), 'spell_fire', reason: 'termos sem espaço seguem a ordem de sempre');
    });
    test('C2: "Chuva Ácida" é veneno', () {
      expect(art(ActionArtKind.spell, 'Chuva Ácida', category: 'Magia'), 'spell_poison');
      expect(art(ActionArtKind.spell, 'Chuva', category: 'Magia'), 'spell_water');
    });
    test("C3: 'mort' não vale para habilidade", () {
      expect(art(ActionArtKind.ability, 'Golpe Mortal', category: 'Habilidade'), isNot('spell_death'));
      expect(art(ActionArtKind.ability, 'Golpe Mortal', category: 'Técnica'), 'ability_technique');
      expect(art(ActionArtKind.spell, 'Nuvem Mortal', category: 'Magia'), 'spell_death');
      expect(art(ActionArtKind.spell, 'Mortalha', category: 'Magia'), 'spell_death');
      expect(art(ActionArtKind.spell, 'Golpe Mortal', category: 'Magia'), 'spell_death');
      expect(art(ActionArtKind.ability, 'Toque da Morte', category: 'Habilidade'), 'spell_death', reason: "'morte' continua valendo");
    });
  });

  group('D: aba selecionada pelo parâmetro', () {
    Future<double> opacityOf(WidgetTester tester, Widget icon) async {
      await tester.pumpWidget(MaterialApp(home: Center(child: icon)));
      return tester.widget<Opacity>(find.byKey(const ValueKey('abyss-tab-art-general'))).opacity;
    }

    testWidgets('selected decide a opacidade mesmo com outra cor', (tester) async {
      expect(await opacityOf(tester, themedCharacterTabIcon('abyss', 'general', size: 22, color: Colors.red, selected: true)), 1.0);
      expect(await opacityOf(tester, themedCharacterTabIcon('abyss', 'general', size: 22, color: AbyssColors.goldLight, selected: false)), abyssTabArtUnselectedOpacity);
    });
    testWidgets('sem selected, segue a dedução pela cor', (tester) async {
      expect(await opacityOf(tester, themedCharacterTabIcon('abyss', 'general', size: 22, color: AbyssColors.goldLight)), 1.0);
      expect(await opacityOf(tester, themedCharacterTabIcon('abyss', 'general', size: 22, color: Colors.red)), abyssTabArtUnselectedOpacity);
    });
    test('outros temas ignoram selected (mesmo widget de antes)', () {
      for (final themeId in ['classic', 'parchment', 'vampire', 'cyberpunk', 'ice']) {
        final a = themedCharacterTabIcon(themeId, 'skills', size: 22, color: Colors.red, selected: true);
        final b = themedCharacterTabIcon(themeId, 'skills', size: 22, color: Colors.red);
        expect(a.runtimeType, b.runtimeType, reason: themeId);
        if (a is Icon && b is Icon) {
          expect(a.icon, b.icon);
          expect(a.size, b.size);
          expect(a.color, b.color);
        }
      }
    });
  });
}
