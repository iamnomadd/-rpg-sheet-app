import 'dart:math';

import '../models/character.dart';
import 'app_state.dart';

/// Gênero do nome da ficha de exemplo (para o texto do resumo).
enum ExampleGender { male, female }

/// Os 5 nomes da ficha de exemplo (1.3.75), na ordem fixa.
const exampleCharacterNames = <(String, ExampleGender)>[
  ('Aaron', ExampleGender.male),
  ('Kael', ExampleGender.male),
  ('Selene', ExampleGender.female),
  ('Dorian', ExampleGender.male),
  ('Mira', ExampleGender.female),
];

/// Sistema usado na ficha de exemplo: Tormenta20 (sistema padrão com PV, PM e
/// perícias).
const exampleCharacterSystemId = 'tormenta20';

/// Nome livre a partir de [base]: "Kael", "Kael (2)", "(3)"... (a mesma
/// regra de nomes repetidos dos sistemas e campanhas).
String _uniqueName(String base, Set<String> taken) {
  var name = base;
  var counter = 2;
  while (taken.contains(name.toLowerCase())) {
    name = '$base ($counter)';
    counter++;
  }
  return name;
}

/// Nome da ficha de exemplo:
/// - sem ficha chamada "Aaron", sempre "Aaron";
/// - senão, sorteia um dos outros 4 nomes ainda sem ficha;
/// - com os 5 em uso, sorteia qualquer um e aplica "(2)", "(3)"...
/// [random] é injetável nos testes.
({String name, ExampleGender gender}) pickExampleCharacterName(Iterable<String> existingNames, {Random? random}) {
  final rng = random ?? Random();
  final taken = existingNames.map((n) => n.trim().toLowerCase()).toSet();
  final first = exampleCharacterNames.first;
  if (!taken.contains(first.$1.toLowerCase())) return (name: first.$1, gender: first.$2);
  final free = exampleCharacterNames.skip(1).where((n) => !taken.contains(n.$1.toLowerCase())).toList();
  if (free.isNotEmpty) {
    final pick = free[rng.nextInt(free.length)];
    return (name: pick.$1, gender: pick.$2);
  }
  final pick = exampleCharacterNames[rng.nextInt(exampleCharacterNames.length)];
  return (name: _uniqueName(pick.$1, taken), gender: pick.$2);
}

/// Resumo da seção "Anotações" com o nome e o gênero da ficha.
String exampleCharacterSummary(String name, ExampleGender gender) {
  final intro = gender == ExampleGender.female
      ? '$name é uma aventureira que cresceu nas docas e aprendeu magia sozinha.'
      : '$name é um aventureiro que cresceu nas docas e aprendeu magia sozinho.';
  return '$intro Procura o irmão desaparecido e confia em poucas pessoas. '
      'Prefere resolver as coisas com astúcia antes de sacar a espada.';
}

/// Detalhes de um item/habilidade no mesmo formato que o editor da ficha
/// grava (os campos que a categoria não usa ficam vazios/nulos).
Map<String, dynamic> _details(
  String category, {
  String damage = '',
  int? quantity,
  int? ammo,
  int? ammoMax,
  String effectResource = '',
  int effectValue = 0,
  int? cost,
  String resource = '',
  String durationType = '',
}) =>
    {
      'category': category,
      'damage': damage,
      'durationType': durationType,
      'turns': '',
      'quantity': quantity,
      'ammo': ammo,
      'ammoMax': ammoMax,
      'ammoItem': '',
      'effectResource': effectResource,
      'effectValue': effectValue,
      'cost': cost,
      'resource': resource,
      // Nada fixado no Em Cena.
      'showInScene': false,
    };

/// Cria a ficha de exemplo (uma ficha normal: salva, editável e apagável) e
/// devolve a ficha, ou null se o sistema Tormenta20 não estiver disponível.
Future<Character?> createExampleCharacter(AppState state, {Random? random}) async {
  if (!state.systems.any((s) => s.id == exampleCharacterSystemId)) return null;
  final picked = pickExampleCharacterName(state.characters.map((c) => c.name), random: random);
  final character = await state.addCharacter(
    name: picked.name,
    systemId: exampleCharacterSystemId,
  );

  // Atributos do Tormenta20 com valores plausíveis.
  character.attributes.addAll({
    'Força': 10,
    'Destreza': 16,
    'Constituição': 12,
    'Inteligência': 15,
    'Sabedoria': 13,
    'Carisma': 11,
  });

  // PV e PM abaixo do máximo.
  character.resourceValues.addAll({'PV': 18, 'PM': 7});
  character.resourceMaxValues.addAll({'PV': 24, 'PM': 10});
  character.hp = 18;
  character.maxHp = 24;

  // Inventário: 1 item de cada categoria.
  final items = <(String, String, Map<String, dynamic>)>[
    ('Espada curta', 'Lâmina leve, fácil de esconder sob a capa.', _details('Arma', damage: '1d6', ammo: 0, ammoMax: 0)),
    ('Gibão de couro', 'Proteção leve que não atrapalha os movimentos.', _details('Armadura')),
    ('Poção de cura', 'Frasco vermelho que fecha ferimentos leves.', _details('Consumível', quantity: 2, effectResource: 'PV', effectValue: 5)),
    ('Flechas', 'Aljava com flechas de ponta de ferro.', _details('Munição', quantity: 20)),
    ('Amuleto de prata', 'Lembrança do irmão desaparecido.', _details('Acessório')),
    ('Kit de ladino', 'Gazuas, arames e uma pequena lima.', _details('Ferramenta')),
    ('Mapa rasgado', 'Metade de um mapa das docas com uma marca vermelha.', _details('Outro')),
  ];
  for (final (name, description, details) in items) {
    character.inventory.add(name);
    character.inventoryDescriptions[name] = description;
    character.inventoryDetails[name] = details;
  }

  // Habilidades: 1 de cada categoria.
  final abilities = <(String, String, Map<String, dynamic>)>[
    ('Golpe preciso', 'Um ataque certeiro em um ponto fraco do alvo.', _details('Habilidade', damage: '1d6', cost: 0, resource: 'PM', durationType: 'instant')),
    ('Seta arcana', 'Um raio de energia mágica que nunca erra o alvo.', _details('Magia', damage: '2d4', cost: 2, resource: 'PM', durationType: 'instant')),
    ('Esquiva acrobática', 'Rola para longe de um golpe no último instante.', _details('Técnica', cost: 0, resource: 'PM', durationType: 'instant')),
    ('Visão no escuro', 'Enxerga na penumbra como se fosse dia.', _details('Passiva')),
    ('Contatos na guilda', 'Conhece quem vende informação nas docas.', _details('Outro', cost: 0, resource: 'PM', durationType: 'instant')),
  ];
  for (final (name, description, details) in abilities) {
    character.abilities.add(name);
    character.abilityDescriptions[name] = description;
    character.abilityDetails[name] = details;
  }

  // Resumo na seção "Anotações" do Tormenta20.
  // O nome base é o nome escolhido (sem o sufixo "(2)").
  final baseName = picked.name.replaceFirst(RegExp(r' \(\d+\)$'), '');
  character.sectionNotes['Anotações'] = exampleCharacterSummary(baseName, picked.gender);

  // Perícia treinada (perícia do sistema).
  character.skills.add('Furtividade');

  await state.updateCharacter(character);
  return character;
}
