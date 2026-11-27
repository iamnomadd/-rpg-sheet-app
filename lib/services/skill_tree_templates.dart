import 'skill_tree_rules.dart';

class SkillTreeTemplates {
  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c');

  static String? templateKeyForClass(String className) {
    final value = _normalize(className);
    if (value.isEmpty) return null;
    const aliases = <String, List<String>>{
      'paladino': ['paladino', 'templario', 'cavaleiro sagrado'],
      'guerreiro': ['guerreiro', 'soldado', 'mercenario'],
      'lutador': ['lutador', 'pugilista', 'monge marcial'],
      'mago': ['mago', 'feiticeiro', 'bruxo', 'arcanista'],
      'ladino': ['ladino', 'assassino', 'trapaceiro', 'gatuno'],
      'arqueiro': ['arqueiro', 'cacador', 'ranger'],
      'clerigo': ['clerigo', 'sacerdote', 'curandeiro divino'],
      'barbaro': ['barbaro', 'berserker'],
      'investigador': ['investigador', 'detetive', 'perito'],
      'pistoleiro': ['pistoleiro', 'atirador', 'gunslinger'],
      'ocultista': ['ocultista', 'medium', 'exorcista'],
      'medico': ['medico', 'socorrista', 'paramedico'],
    };
    for (final entry in aliases.entries) {
      if (entry.value.any((alias) => value == alias || value.contains(alias))) return entry.key;
    }
    return null;
  }

  static String? templateLabelForClass(String className) {
    final key = templateKeyForClass(className);
    return key == null ? null : _labels[key];
  }

  static bool hasTemplate(String className) => templateKeyForClass(className) != null;

  /// Recurso usado no custo das habilidades do modelo: o primeiro recurso do
  /// sistema que não é de vida (Vida, PV, Pontos de Vida, PV Temporários e
  /// Sanidade não contam). Null = sem custo.
  static String? costResource(Iterable<String> resources) {
    for (final resource in resources) {
      final key = _normalize(resource);
      final life = key == 'vida' || key == 'pv' || key == 'pontos de vida' || key == 'sanidade' || key.startsWith('pv ') || key.contains('vida');
      if (!life) return resource;
    }
    return null;
  }

  /// Árvore completa do modelo da classe (1.3.79): nós e ramos. Todos os nós
  /// começam bloqueados. [resources] = recursos do sistema da ficha (para o
  /// custo). O que aparece na tela continua decidido pelo sistema.
  static ({List<Map<String, dynamic>> nodes, List<Map<String, dynamic>> branches}) generate(String className, {Iterable<String> resources = const []}) {
    final key = templateKeyForClass(className);
    final template = key == null ? null : _templates[key];
    if (key == null || template == null) return (nodes: <Map<String, dynamic>>[], branches: <Map<String, dynamic>>[]);
    final classIndex = _templates.keys.toList().indexOf(key);
    final branchIds = [for (var b = 0; b < template.branches.length; b++) 'template_${key}_ramo_${b + 1}'];
    final branches = [
      for (var b = 0; b < template.branches.length; b++)
        <String, dynamic>{
          'id': branchIds[b],
          'name': template.branches[b],
          // Cores diferentes em cada ramo (e variando entre as classes).
          'color': skillTreeBranchColors[(classIndex + b * 3) % skillTreeBranchColors.length].toARGB32(),
        },
    ];
    final resource = costResource(resources);
    final ids = List<String>.generate(template.skills.length, (index) => 'template_${key}_${index + 1}');
    int depth(int index) {
      var d = 1;
      var parent = template.skills[index].parent;
      while (parent != null) {
        d++;
        parent = template.skills[parent].parent;
      }
      return d;
    }

    final nodes = <Map<String, dynamic>>[
      for (var i = 0; i < template.skills.length; i++)
        () {
          final seed = template.skills[i];
          final cost = resource == null ? 0 : seed.cost;
          return <String, dynamic>{
            'id': ids[i],
            'name': seed.name,
            'description': seed.description,
            'parentId': seed.parent == null ? '' : ids[seed.parent!],
            'level': depth(i),
            'unlocked': false,
            'template': key,
            'branchId': branchIds[seed.branch],
            'rankTexts': [seed.talento, seed.facanha, seed.lenda],
            if (seed.exclusive) 'exclusiveGroup': 'template_${key}_escolha',
            'addToAbilities': true,
            'ability': <String, dynamic>{
              'category': seed.category,
              'damage': seed.damage,
              'cost': cost,
              'resource': cost > 0 ? resource : '',
              'durationType': 'instant',
              'turns': '',
            },
          };
        }(),
    ];
    return (nodes: nodes, branches: branches);
  }

  /// Nós do modelo da classe (ver [generate]).
  static List<Map<String, dynamic>> forClass(String className, {Iterable<String> resources = const []}) =>
      generate(className, resources: resources).nodes;

  static const _labels = <String, String>{
    'paladino': 'Paladino', 'guerreiro': 'Guerreiro', 'lutador': 'Lutador', 'mago': 'Mago',
    'ladino': 'Ladino', 'arqueiro': 'Arqueiro', 'clerigo': 'Clérigo', 'barbaro': 'Bárbaro',
    'investigador': 'Investigador', 'pistoleiro': 'Pistoleiro', 'ocultista': 'Ocultista', 'medico': 'Médico',
  };

  static const _templates = <String, _Template>{
    'paladino': _Template(
      ['Fé', 'Escudo', 'Julgamento'],
      [
        _Seed(0, 'Juramento', 'Passiva', 'Um ideal guia suas ações.', 'Ganha coragem ao seguir o juramento.', 'Aliados próximos também ganham coragem.', 'Nada consegue te amedrontar.'),
        _Seed(0, 'Mãos Restauradoras', 'Magia', 'Cura um aliado com um toque.', 'Cura ferimentos leves.', 'Cura ferimentos graves.', 'Também remove uma condição negativa.', parent: 0, cost: 1),
        _Seed(0, 'Purificação', 'Magia', 'Remove um mal que aflige um aliado.', 'Remove um veneno ou doença.', 'Remove qualquer condição negativa.', 'Protege o aliado contra novos males por um tempo.', parent: 1, cost: 2),
        _Seed(1, 'Postura Defensiva', 'Técnica', 'Prepara-se para receber golpes.', 'Fica mais difícil de acertar até o próximo turno.', 'Também protege um aliado ao lado.', 'Protege todos os aliados próximos.'),
        _Seed(1, 'Aura Protetora', 'Passiva', 'Aliados perto de você ficam mais seguros.', 'Aura pequena ao seu redor.', 'A aura fica maior.', 'A aura também reduz o dano mágico.', parent: 3),
        _Seed(1, 'Escudo da Fé', 'Magia', 'Cria uma barreira de luz.', 'A barreira protege você.', 'A barreira protege um aliado.', 'A barreira devolve parte do dano.', parent: 4, cost: 2),
        _Seed(2, 'Golpe Radiante', 'Habilidade', 'Ataque com energia sagrada.', 'Golpe extra de luz.', 'O golpe causa mais dano.', 'O golpe também cega o inimigo por um instante.', cost: 1, damage: '1d6'),
        _Seed(2, 'Desafio Sagrado', 'Técnica', 'Força um inimigo a lutar com você.', 'Um inimigo foca em você.', 'O inimigo também fica mais lento.', 'Dois inimigos focam em você.', parent: 6, exclusive: true),
        _Seed(2, 'Julgamento', 'Habilidade', 'Um golpe decisivo contra o mal.', 'Golpe forte contra um inimigo.', 'Golpe mais forte contra criaturas malignas.', 'O golpe pode derrubar o inimigo.', parent: 6, cost: 3, damage: '2d6', exclusive: true),
      ],
    ),
    'guerreiro': _Template(
      ['Armas', 'Resistência', 'Comando'],
      [
        _Seed(0, 'Treino com Armas', 'Passiva', 'Domina armas de combate.', 'Usa bem armas comuns.', 'Usa bem qualquer arma.', 'Seus ataques raramente erram.'),
        _Seed(0, 'Golpe Poderoso', 'Habilidade', 'Um ataque com toda a força.', 'Golpe forte.', 'O golpe causa mais dano.', 'O golpe também derruba o alvo.', parent: 0, cost: 1, damage: '1d8'),
        _Seed(0, 'Ataque Duplo', 'Técnica', 'Ataca duas vezes seguidas.', 'Dois ataques rápidos.', 'Os dois ataques causam mais dano.', 'Pode dividir os ataques entre dois alvos.', parent: 1, cost: 2, damage: '1d8'),
        _Seed(1, 'Pele Grossa', 'Passiva', 'Aguenta mais pancada.', 'Recebe um pouco menos de dano.', 'Recebe menos dano.', 'Ignora o primeiro golpe de cada combate.'),
        _Seed(1, 'Segundo Fôlego', 'Técnica', 'Recupera forças no meio da luta.', 'Recupera um pouco de vida.', 'Recupera mais vida.', 'Também remove o cansaço.', parent: 3, cost: 1),
        _Seed(1, 'Última Resistência', 'Passiva', 'Continua lutando quando deveria cair.', 'Fica de pé uma vez por combate.', 'Fica de pé com mais vida.', 'Fica de pé e ganha um ataque extra.', parent: 4),
        _Seed(2, 'Grito de Guerra', 'Habilidade', 'Um grito que anima o grupo.', 'Aliados ganham coragem.', 'Aliados também atacam melhor.', 'Inimigos fracos fogem.', cost: 1),
        _Seed(2, 'Proteger Aliado', 'Técnica', 'Toma um golpe no lugar de um aliado.', 'Recebe um ataque por um aliado.', 'Recebe menos dano ao proteger.', 'Contra-ataca quem atacou o aliado.', parent: 6, exclusive: true),
        _Seed(2, 'Ordem de Ataque', 'Técnica', 'Manda um aliado atacar agora.', 'Um aliado ataca fora da vez.', 'O ataque do aliado causa mais dano.', 'Dois aliados atacam fora da vez.', parent: 6, cost: 2, exclusive: true),
      ],
    ),
    'lutador': _Template(
      ['Punhos', 'Corpo', 'Fluxo'],
      [
        _Seed(0, 'Punhos Firmes', 'Passiva', 'Luta bem sem armas.', 'Socos causam dano como uma arma.', 'Socos causam mais dano.', 'Socos quebram pedra e madeira.'),
        _Seed(0, 'Sequência Rápida', 'Técnica', 'Vários golpes em pouco tempo.', 'Dois golpes rápidos.', 'Três golpes rápidos.', 'Os golpes também atordoam.', parent: 0, cost: 1, damage: '1d6'),
        _Seed(0, 'Golpe Atordoante', 'Técnica', 'Um golpe que deixa o alvo tonto.', 'O alvo perde a próxima ação.', 'Funciona em alvos maiores.', 'O alvo fica tonto por mais tempo.', parent: 1, cost: 2, damage: '1d6'),
        _Seed(1, 'Corpo Treinado', 'Passiva', 'Corpo forte e resistente.', 'Recebe menos dano de golpes.', 'Também resiste a venenos.', 'Também resiste a magia.'),
        _Seed(1, 'Esquiva', 'Técnica', 'Desvia de um ataque no último instante.', 'Desvia de um ataque.', 'Desvia e fica perto do atacante.', 'Desvia e contra-ataca.', parent: 3),
        _Seed(1, 'Pele de Ferro', 'Passiva', 'Golpes leves quase não machucam.', 'Ignora dano pequeno.', 'Ignora mais dano.', 'Armas comuns quase não te ferem.', parent: 4),
        _Seed(2, 'Respiração', 'Habilidade', 'Concentra-se e recupera o fôlego.', 'Recupera um pouco de energia.', 'Recupera mais energia.', 'Também cura um pouco de vida.', cost: 1),
        _Seed(2, 'Postura da Pedra', 'Técnica', 'Fica firme como uma rocha.', 'Não pode ser derrubado.', 'Também recebe menos dano.', 'Quem te atacar se machuca.', parent: 6, cost: 1, exclusive: true),
        _Seed(2, 'Postura do Vento', 'Técnica', 'Move-se leve como o vento.', 'Anda mais rápido.', 'Pode correr pelas paredes.', 'Fica quase impossível de acertar.', parent: 6, cost: 1, exclusive: true),
      ],
    ),
    'mago': _Template(
      ['Fogo', 'Proteção', 'Saber'],
      [
        _Seed(0, 'Faísca', 'Magia', 'Lança uma pequena chama.', 'Chama pequena num alvo.', 'A chama causa mais dano.', 'A chama atinge dois alvos.', cost: 1, damage: '1d6'),
        _Seed(0, 'Bola de Fogo', 'Magia', 'Explosão de fogo numa área.', 'Explosão numa área pequena.', 'Explosão numa área grande.', 'O fogo continua queimando no chão.', parent: 0, cost: 3, damage: '2d6'),
        _Seed(0, 'Muralha de Chamas', 'Magia', 'Ergue uma parede de fogo.', 'Parede curta por pouco tempo.', 'Parede longa.', 'A parede dura até o fim do combate.', parent: 1, cost: 3),
        _Seed(1, 'Escudo Arcano', 'Magia', 'Uma barreira mágica te protege.', 'Bloqueia um ataque fraco.', 'Bloqueia um ataque forte.', 'Também protege um aliado.', cost: 1),
        _Seed(1, 'Contramágica', 'Magia', 'Desfaz uma magia inimiga.', 'Desfaz uma magia fraca.', 'Desfaz qualquer magia comum.', 'Devolve a magia para quem lançou.', parent: 3, cost: 2),
        _Seed(1, 'Teleporte Curto', 'Magia', 'Some e aparece perto dali.', 'Teleporta poucos passos.', 'Teleporta mais longe.', 'Leva um aliado junto.', parent: 4, cost: 2),
        _Seed(2, 'Estudo Arcano', 'Passiva', 'Conhece muito sobre magia.', 'Reconhece magias comuns.', 'Reconhece qualquer magia.', 'Sabe como desfazer magias antigas.'),
        _Seed(2, 'Familiar', 'Magia', 'Invoca um pequeno ajudante mágico.', 'Um bichinho que observa por você.', 'O bichinho entrega objetos.', 'O bichinho lança magias simples.', parent: 6, cost: 1, exclusive: true),
        _Seed(2, 'Mente Ampliada', 'Passiva', 'Guarda mais energia mágica.', 'Ganha um pouco mais de energia.', 'Ganha mais energia.', 'Recupera energia com um descanso curto.', parent: 6, exclusive: true),
      ],
    ),
    'ladino': _Template(
      ['Sombra', 'Truques', 'Esperteza'],
      [
        _Seed(0, 'Passo Silencioso', 'Passiva', 'Move-se sem fazer barulho.', 'Passos sem som.', 'Também não deixa rastros.', 'Nem animais percebem sua presença.'),
        _Seed(0, 'Ataque Furtivo', 'Habilidade', 'Golpe extra contra quem não te vê.', 'Golpe extra contra quem não te vê.', 'O golpe extra causa mais dano.', 'O golpe extra também ignora parte da armadura.', parent: 0, damage: '1d6'),
        _Seed(0, 'Desaparecer', 'Técnica', 'Some de vista por um instante.', 'Some até o fim do turno.', 'Some e se move sem ser visto.', 'Fica invisível até atacar.', parent: 1, cost: 1),
        _Seed(1, 'Mãos Leves', 'Passiva', 'Furta e abre fechaduras com facilidade.', 'Abre fechaduras simples.', 'Abre qualquer fechadura comum.', 'Furta até o que está sendo vigiado.'),
        _Seed(1, 'Veneno na Lâmina', 'Técnica', 'A arma envenena o alvo.', 'Envenena o próximo golpe.', 'O veneno dura mais.', 'O veneno também enfraquece o alvo.', parent: 3, cost: 2, exclusive: true),
        _Seed(1, 'Bomba de Fumaça', 'Técnica', 'Cria fumaça e facilita a fuga.', 'Fumaça numa área pequena.', 'Fumaça numa área grande.', 'A fumaça também confunde quem está dentro.', parent: 3, cost: 2, exclusive: true),
        _Seed(2, 'Olhos Atentos', 'Passiva', 'Nota detalhes que os outros perdem.', 'Percebe armadilhas simples.', 'Percebe portas e passagens secretas.', 'Quase nunca é pego de surpresa.'),
        _Seed(2, 'Lábia', 'Habilidade', 'Convence os outros com conversa.', 'Engana guardas e curiosos.', 'Engana pessoas desconfiadas.', 'Faz um inimigo acreditar que é amigo.', parent: 6),
        _Seed(2, 'Plano de Fuga', 'Técnica', 'Sempre tem uma saída pronta.', 'Foge do combate sem ser atacado.', 'Leva um aliado junto na fuga.', 'Todo o grupo foge sem ser seguido.', parent: 7, cost: 1),
      ],
    ),
    'arqueiro': _Template(
      ['Mira', 'Floresta', 'Flechas'],
      [
        _Seed(0, 'Olho de Águia', 'Passiva', 'Enxerga longe e com detalhes.', 'Vê alvos distantes.', 'Ataques de longe erram menos.', 'Acerta alvos quase escondidos.'),
        _Seed(0, 'Tiro Certeiro', 'Habilidade', 'Um disparo cuidadoso e preciso.', 'Disparo preciso.', 'O disparo causa mais dano.', 'O disparo atinge um ponto fraco.', parent: 0, cost: 1, damage: '1d8'),
        _Seed(0, 'Tiro Perfurante', 'Técnica', 'A flecha atravessa o primeiro alvo.', 'Atinge dois alvos em linha.', 'Atinge três alvos em linha.', 'Também atravessa escudos.', parent: 1, cost: 2, damage: '1d8'),
        _Seed(1, 'Rastreador', 'Passiva', 'Segue rastros na natureza.', 'Segue rastros recentes.', 'Segue rastros antigos.', 'Sabe quantos passaram e para onde foram.'),
        _Seed(1, 'Camuflagem', 'Técnica', 'Some na vegetação.', 'Fica difícil de ver parado.', 'Fica difícil de ver andando.', 'Ataca sem revelar onde está.', parent: 3, cost: 1),
        _Seed(1, 'Companheiro Animal', 'Habilidade', 'Um animal leal te acompanha.', 'O animal ajuda a vigiar.', 'O animal ajuda no combate.', 'O animal protege você de ataques.', parent: 4),
        _Seed(2, 'Disparo Rápido', 'Técnica', 'Atira mais de uma vez.', 'Dois disparos no turno.', 'Três disparos no turno.', 'Os disparos podem ir para alvos diferentes.', cost: 1, damage: '1d6'),
        _Seed(2, 'Chuva de Flechas', 'Técnica', 'Muitas flechas sobre uma área.', 'Flechas numa área pequena.', 'Flechas numa área grande.', 'Inimigos na área ficam presos no lugar.', parent: 6, cost: 3, damage: '1d6', exclusive: true),
        _Seed(2, 'Flecha Marcada', 'Técnica', 'Marca um alvo para o grupo.', 'Aliados acertam o alvo mais fácil.', 'O alvo marcado não consegue se esconder.', 'Aliados causam mais dano no alvo.', parent: 6, cost: 2, exclusive: true),
      ],
    ),
    'clerigo': _Template(
      ['Cura', 'Luz', 'Fé'],
      [
        _Seed(0, 'Cura Leve', 'Magia', 'Fecha feridas com uma prece.', 'Cura um pouco um aliado.', 'Cura mais.', 'Cura dois aliados de uma vez.', cost: 1),
        _Seed(0, 'Restauração', 'Magia', 'Remove males do corpo.', 'Remove um veneno ou doença.', 'Remove qualquer condição negativa.', 'Também devolve a força perdida.', parent: 0, cost: 2),
        _Seed(0, 'Milagre', 'Magia', 'Um pedido atendido pelos deuses.', 'Cura muito um aliado.', 'Cura todo o grupo.', 'Traz de volta um aliado que acabou de cair.', parent: 1, cost: 3),
        _Seed(1, 'Chama Sagrada', 'Magia', 'Fogo divino sobre um inimigo.', 'Atinge um inimigo.', 'Causa mais dano a mortos-vivos.', 'Atinge dois inimigos.', cost: 1, damage: '1d6'),
        _Seed(1, 'Expulsar Mortos', 'Magia', 'Afasta mortos-vivos com fé.', 'Mortos-vivos fracos fogem.', 'Mortos-vivos fortes também fogem.', 'Mortos-vivos fracos são destruídos.', parent: 3, cost: 2),
        _Seed(1, 'Luz do Dia', 'Magia', 'Cria uma luz forte e sagrada.', 'Ilumina uma grande área.', 'A luz afasta criaturas das trevas.', 'A luz fere criaturas das trevas.', parent: 4, cost: 2),
        _Seed(2, 'Oração', 'Habilidade', 'Pede ajuda aos deuses.', 'Recebe um sinal ou conselho.', 'Aliados ganham coragem.', 'Recebe uma resposta clara.'),
        _Seed(2, 'Bênção', 'Magia', 'Protege e fortalece os aliados.', 'Um aliado fica mais forte.', 'Dois aliados ficam mais fortes.', 'Todo o grupo fica mais forte.', parent: 6, cost: 1, exclusive: true),
        _Seed(2, 'Santuário', 'Magia', 'Ninguém consegue atacar o protegido.', 'Protege um aliado por pouco tempo.', 'Protege por mais tempo.', 'Protege todo o grupo por um instante.', parent: 6, cost: 2, exclusive: true),
      ],
    ),
    'barbaro': _Template(
      ['Fúria', 'Selvagem', 'Força'],
      [
        _Seed(0, 'Fúria', 'Habilidade', 'Entra em um estado de raiva.', 'Bate mais forte durante a fúria.', 'Também recebe menos dano na fúria.', 'A fúria dura até o fim do combate.', cost: 1),
        _Seed(0, 'Golpe Brutal', 'Habilidade', 'Um golpe pesado e sem cuidado.', 'Golpe forte.', 'O golpe causa mais dano.', 'O golpe derruba o alvo.', parent: 0, cost: 1, damage: '1d10'),
        _Seed(0, 'Fúria Imparável', 'Passiva', 'Nada te para enquanto está com raiva.', 'Não pode ser derrubado na fúria.', 'Ignora medo e confusão na fúria.', 'Continua lutando mesmo muito ferido.', parent: 1),
        _Seed(1, 'Instinto', 'Passiva', 'Sente o perigo antes de ver.', 'Difícil de pegar de surpresa.', 'Age primeiro no combate.', 'Sente inimigos escondidos por perto.'),
        _Seed(1, 'Corrida Selvagem', 'Técnica', 'Corre muito rápido.', 'Anda o dobro.', 'Atravessa terreno difícil sem parar.', 'Ataca ao final da corrida.', parent: 3, cost: 1),
        _Seed(1, 'Rugido', 'Habilidade', 'Um rugido que assusta inimigos.', 'Um inimigo fica com medo.', 'Vários inimigos ficam com medo.', 'Inimigos fracos fogem.', parent: 4, cost: 2),
        _Seed(2, 'Corpo Robusto', 'Passiva', 'Muito forte e resistente.', 'Carrega muito peso.', 'Recebe menos dano.', 'Ganha mais vida.'),
        _Seed(2, 'Arremesso', 'Técnica', 'Joga objetos ou inimigos longe.', 'Joga um objeto pesado.', 'Joga um inimigo.', 'Joga um inimigo contra outro.', parent: 6, cost: 1, damage: '1d8', exclusive: true),
        _Seed(2, 'Aguentar Tudo', 'Passiva', 'Resiste a dor e cansaço.', 'Resiste ao cansaço.', 'Também resiste a venenos.', 'Ignora a primeira condição negativa.', parent: 6, exclusive: true),
      ],
    ),
    'investigador': _Template(
      ['Observação', 'Conversa', 'Dedução'],
      [
        _Seed(0, 'Olhar Analítico', 'Passiva', 'Vê detalhes que os outros não veem.', 'Nota detalhes estranhos.', 'Nota pistas escondidas.', 'Nada numa cena passa despercebido.'),
        _Seed(0, 'Leitura de Pistas', 'Habilidade', 'Liga pistas entre si.', 'Liga duas pistas.', 'Descobre o que falta na cena.', 'Sabe a ordem dos fatos.', parent: 0),
        _Seed(0, 'Reconstrução da Cena', 'Habilidade', 'Imagina o que aconteceu no local.', 'Entende o que houve.', 'Sabe quantos estavam lá.', 'Sabe quem fez e como.', parent: 1, cost: 1),
        _Seed(1, 'Entrevista', 'Habilidade', 'Faz as perguntas certas.', 'Consegue respostas simples.', 'Consegue respostas de quem não quer falar.', 'Descobre segredos sem a pessoa perceber.'),
        _Seed(1, 'Percepção de Mentira', 'Passiva', 'Percebe quando mentem.', 'Nota mentiras óbvias.', 'Nota mentiras bem contadas.', 'Sabe qual parte é mentira.', parent: 3),
        _Seed(1, 'Contatos', 'Habilidade', 'Conhece gente que ajuda.', 'Um contato com informações.', 'Contatos em vários lugares.', 'Um contato influente ajuda o grupo.', parent: 4),
        _Seed(2, 'Pesquisa', 'Habilidade', 'Acha informação em arquivos e registros.', 'Acha informações comuns.', 'Acha informações raras.', 'Acha o que alguém tentou esconder.'),
        _Seed(2, 'Teoria do Caso', 'Habilidade', 'Monta uma hipótese sobre o caso.', 'O mestre confirma uma suspeita.', 'O mestre confirma duas suspeitas.', 'Descobre o próximo passo do culpado.', parent: 6, cost: 2, exclusive: true),
        _Seed(2, 'Palpite Certeiro', 'Passiva', 'Um palpite que costuma acertar.', 'Recebe uma pista quando trava.', 'A pista é mais útil.', 'Sabe quando está no caminho errado.', parent: 6, exclusive: true),
      ],
    ),
    'pistoleiro': _Template(
      ['Saque', 'Precisão', 'Estilo'],
      [
        _Seed(0, 'Saque Rápido', 'Passiva', 'Puxa a arma num instante.', 'Saca sem perder tempo.', 'Age primeiro no combate.', 'Atira antes de qualquer um.'),
        _Seed(0, 'Dois Alvos', 'Técnica', 'Atira em dois inimigos de uma vez.', 'Um tiro em cada alvo.', 'Os tiros causam mais dano.', 'Atira em três alvos.', parent: 0, cost: 1, damage: '1d6'),
        _Seed(0, 'Leque de Balas', 'Técnica', 'Esvazia a arma em vários alvos.', 'Atinge inimigos à frente.', 'Atinge mais inimigos.', 'Inimigos atingidos ficam com medo.', parent: 1, cost: 3, damage: '1d6'),
        _Seed(1, 'Mira Fria', 'Passiva', 'Mantém a calma ao atirar.', 'Erra menos sob pressão.', 'Erra menos de longe.', 'Quase nunca erra.'),
        _Seed(1, 'Tiro Certeiro', 'Habilidade', 'Um disparo cuidadoso.', 'Disparo preciso.', 'O disparo causa mais dano.', 'O disparo desarma o alvo.', parent: 3, cost: 1, damage: '1d8'),
        _Seed(1, 'Ricochete', 'Técnica', 'A bala bate numa parede e acerta o alvo.', 'Acerta alvos atrás de cobertura.', 'A bala ricocheteia em dois alvos.', 'Acerta alvos que você não vê.', parent: 4, cost: 2, damage: '1d6'),
        _Seed(2, 'Recarga Ágil', 'Passiva', 'Recarrega muito rápido.', 'Recarrega sem perder a ação.', 'Recarrega duas armas.', 'Nunca fica sem tiro no combate.'),
        _Seed(2, 'Tiro de Supressão', 'Técnica', 'Obriga inimigos a se esconder.', 'Inimigos param de avançar.', 'Inimigos não atacam no turno.', 'Aliados atacam enquanto eles se escondem.', parent: 6, cost: 2, exclusive: true),
        _Seed(2, 'Duelo', 'Técnica', 'Desafia um inimigo para um duelo.', 'Ataca melhor contra o desafiado.', 'Recebe menos dano dele.', 'Um tiro derruba o desafiado se ele estiver fraco.', parent: 6, cost: 2, exclusive: true),
      ],
    ),
    'ocultista': _Template(
      ['Véu', 'Rituais', 'Mente'],
      [
        _Seed(0, 'Sensibilidade Oculta', 'Passiva', 'Sente presenças sobrenaturais.', 'Sente que algo estranho está perto.', 'Sabe de onde vem.', 'Sabe o que é.'),
        _Seed(0, 'Canalizar Presença', 'Habilidade', 'Conversa com uma presença do além.', 'Faz uma pergunta simples.', 'Faz várias perguntas.', 'A presença ajuda o grupo.', parent: 0, cost: 1),
        _Seed(0, 'Mestre do Véu', 'Magia', 'Abre uma passagem para o outro lado.', 'Vê o outro lado por um instante.', 'Atravessa por um momento.', 'Leva aliados junto.', parent: 1, cost: 3),
        _Seed(1, 'Símbolo de Proteção', 'Magia', 'Desenha um símbolo que protege.', 'Protege uma pessoa.', 'Protege uma sala.', 'Criaturas do além não entram.', cost: 1),
        _Seed(1, 'Círculo de Contenção', 'Magia', 'Prende uma criatura num círculo.', 'Prende uma criatura fraca.', 'Prende uma criatura forte.', 'Prende por muito mais tempo.', parent: 3, cost: 2),
        _Seed(1, 'Banimento', 'Magia', 'Expulsa uma criatura do além.', 'Expulsa uma criatura fraca.', 'Expulsa uma criatura forte.', 'A criatura não pode voltar.', parent: 4, cost: 3, damage: '2d6'),
        _Seed(2, 'Leitura Ritual', 'Habilidade', 'Entende símbolos e rituais estranhos.', 'Lê símbolos comuns.', 'Lê símbolos raros.', 'Sabe como desfazer um ritual.'),
        _Seed(2, 'Resistência Mental', 'Passiva', 'Mantém a mente firme diante do horror.', 'Resiste ao medo.', 'Resiste ao controle da mente.', 'Ajuda um aliado a se recuperar do medo.', parent: 6, exclusive: true),
        _Seed(2, 'Conhecimento Proibido', 'Passiva', 'Sabe segredos que poucos sabem.', 'Conhece criaturas raras.', 'Sabe suas fraquezas.', 'Sabe como derrotá-las.', parent: 6, exclusive: true),
      ],
    ),
    'medico': _Template(
      ['Atendimento', 'Emergência', 'Farmácia'],
      [
        _Seed(0, 'Primeiros Socorros', 'Habilidade', 'Trata ferimentos rapidamente.', 'Para um sangramento.', 'Cura um pouco de vida.', 'Cura e remove a dor.'),
        _Seed(0, 'Tratamento de Campo', 'Habilidade', 'Cuida de um aliado em plena luta.', 'Cura um aliado.', 'Cura mais.', 'Cura dois aliados.', parent: 0, cost: 1),
        _Seed(0, 'Salvar Vida', 'Habilidade', 'Traz de volta quem está quase morrendo.', 'Estabiliza um aliado caído.', 'O aliado levanta com pouca vida.', 'O aliado levanta com bastante vida.', parent: 1, cost: 3),
        _Seed(1, 'Triagem', 'Passiva', 'Sabe quem precisa de ajuda primeiro.', 'Vê quem está pior.', 'Atende mais rápido.', 'Atende dois de uma vez.'),
        _Seed(1, 'Controle de Hemorragia', 'Técnica', 'Estanca um sangramento grave.', 'Para um sangramento.', 'Para vários sangramentos.', 'Impede novos sangramentos por um tempo.', parent: 3, cost: 1),
        _Seed(1, 'Mãos Firmes', 'Passiva', 'Trabalha bem sob pressão.', 'Não erra com pressa.', 'Não erra sob ataque.', 'Nunca erra um tratamento.', parent: 4),
        _Seed(2, 'Farmacologia', 'Passiva', 'Conhece remédios e venenos.', 'Reconhece remédios comuns.', 'Prepara remédios simples.', 'Prepara antídotos raros.'),
        _Seed(2, 'Estimulante', 'Técnica', 'Uma injeção que dá energia.', 'Aliado ganha energia.', 'Aliado também age mais rápido.', 'Aliado ignora o cansaço.', parent: 6, cost: 2, exclusive: true),
        _Seed(2, 'Anestésico', 'Técnica', 'Um remédio que tira a dor ou faz dormir.', 'Tira a dor de um aliado.', 'Faz um inimigo ficar lento.', 'Faz um inimigo dormir.', parent: 6, cost: 2, exclusive: true),
      ],
    ),
  };
}

/// Ramos e habilidades de um modelo de classe.
class _Template {
  final List<String> branches;
  final List<_Seed> skills;
  const _Template(this.branches, this.skills);
}

/// Uma habilidade do modelo: ramo, nome, categoria, descrição de uma frase e
/// os textos de Talento, Façanha e Lenda. [parent] = índice da habilidade
/// anterior (do mesmo ramo); [exclusive] = parte da escolha "uma das duas".
class _Seed {
  final int branch;
  final String name;
  final String category;
  final String description;
  final String talento;
  final String facanha;
  final String lenda;
  final int? parent;
  final int cost;
  final String damage;
  final bool exclusive;

  const _Seed(this.branch, this.name, this.category, this.description, this.talento, this.facanha, this.lenda,
      {this.parent, this.cost = 0, this.damage = '', this.exclusive = false});
}
