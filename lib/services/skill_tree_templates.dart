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

  static List<Map<String, dynamic>> forClass(String className) {
    final key = templateKeyForClass(className);
    if (key == null) return <Map<String, dynamic>>[];
    final skills = _templates[key] ?? const <_SkillSeed>[];
    final ids = List<String>.generate(skills.length, (index) => 'template_${key}_${index + 1}');
    return List<Map<String, dynamic>>.generate(skills.length, (index) {
      final seed = skills[index];
      return <String, dynamic>{
        'id': ids[index],
        'name': seed.name,
        'description': seed.description,
        'parentId': seed.parentIndex == null ? '' : ids[seed.parentIndex!],
        'level': seed.level,
        'unlocked': false,
        'template': key,
      };
    });
  }

  static const _labels = <String, String>{
    'paladino': 'Paladino', 'guerreiro': 'Guerreiro', 'lutador': 'Lutador', 'mago': 'Mago',
    'ladino': 'Ladino', 'arqueiro': 'Arqueiro', 'clerigo': 'Clérigo', 'barbaro': 'Bárbaro',
    'investigador': 'Investigador', 'pistoleiro': 'Pistoleiro', 'ocultista': 'Ocultista', 'medico': 'Médico',
  };

  static const _templates = <String, List<_SkillSeed>>{
    'paladino': [
      _SkillSeed(1, 'Juramento', 'Escolha um ideal que orienta suas ações e fortalece sua presença.'),
      _SkillSeed(2, 'Golpe Radiante', 'Canalize energia sagrada em um ataque corpo a corpo.', 0),
      _SkillSeed(3, 'Mãos Restauradoras', 'Recupere a vitalidade de um aliado próximo.', 0),
      _SkillSeed(4, 'Aura Protetora', 'Aliados próximos recebem proteção contra ameaças.', 1),
      _SkillSeed(5, 'Desafio Sagrado', 'Marque um inimigo e force-o a encarar você.', 1),
      _SkillSeed(6, 'Purificação', 'Remova uma condição negativa simples de um aliado.', 2),
      _SkillSeed(7, 'Escudo da Fé', 'Erga uma defesa temporária para você ou um aliado.', 3),
      _SkillSeed(8, 'Julgamento', 'Cause um golpe poderoso contra um alvo marcado.', 4),
      _SkillSeed(9, 'Aura de Coragem', 'Reduza medo e hesitação dos aliados próximos.', 6),
      _SkillSeed(10, 'Avatar do Juramento', 'Assuma por alguns instantes a forma máxima do seu juramento.', 7),
    ],
    'guerreiro': [
      _SkillSeed(1, 'Postura de Combate', 'Adote uma postura estável e preparada para o confronto.'),
      _SkillSeed(2, 'Golpe Preciso', 'Troque força bruta por maior controle do ataque.', 0),
      _SkillSeed(3, 'Guarda Firme', 'Melhore sua defesa até sua próxima ação.', 0),
      _SkillSeed(4, 'Investida', 'Avance rapidamente e pressione um inimigo.', 1),
      _SkillSeed(5, 'Contra-ataque', 'Responda a uma abertura deixada pelo adversário.', 2),
      _SkillSeed(6, 'Domínio de Arma', 'Aprimore sua eficiência com a arma escolhida.', 1),
      _SkillSeed(7, 'Quebra de Guarda', 'Crie uma abertura contra alvos defensivos.', 4),
      _SkillSeed(8, 'Segundo Fôlego', 'Recupere-se durante o combate e continue lutando.', 2),
      _SkillSeed(9, 'Veterano', 'Mantenha precisão e defesa sob pressão.', 6),
      _SkillSeed(10, 'Mestre de Batalha', 'Converta experiência em controle total do ritmo da luta.', 8),
    ],
    'lutador': [
      _SkillSeed(1, 'Base Sólida', 'Melhore equilíbrio, guarda e movimentação em combate desarmado.'),
      _SkillSeed(2, 'Jab Rápido', 'Ataque veloz para medir distância e abrir combinações.', 0),
      _SkillSeed(3, 'Esquiva Curta', 'Saia da linha de ataque sem perder posição.', 0),
      _SkillSeed(4, 'Combinação', 'Encadeie golpes após acertar um ataque inicial.', 1),
      _SkillSeed(5, 'Clinch', 'Controle um alvo a curta distância.', 2),
      _SkillSeed(6, 'Golpe no Corpo', 'Ataque que reduz o ritmo do adversário.', 3),
      _SkillSeed(7, 'Contra-golpe', 'Responda imediatamente após uma esquiva bem-sucedida.', 2),
      _SkillSeed(8, 'Pressão Constante', 'Mantenha o adversário sob ameaça contínua.', 5),
      _SkillSeed(9, 'Leitura de Movimento', 'Antecipe padrões de luta observados.', 6),
      _SkillSeed(10, 'Finalização Técnica', 'Execute uma sequência decisiva quando surgir uma abertura.', 8),
    ],
    'mago': [
      _SkillSeed(1, 'Canalização Arcana', 'Aprenda a reunir e controlar energia mágica.'),
      _SkillSeed(2, 'Projétil Arcano', 'Dispare energia concentrada contra um alvo.', 0),
      _SkillSeed(3, 'Barreira Mística', 'Crie uma defesa breve de energia.', 0),
      _SkillSeed(4, 'Amplificação', 'Aumente o alcance ou intensidade de uma magia.', 1),
      _SkillSeed(5, 'Passo Etéreo', 'Reposicione-se com um deslocamento mágico curto.', 2),
      _SkillSeed(6, 'Controle Elemental', 'Molde um elemento escolhido de forma mais precisa.', 3),
      _SkillSeed(7, 'Dissipar', 'Enfraqueça um efeito mágico ativo.', 2),
      _SkillSeed(8, 'Conjuração Dupla', 'Prepare duas manifestações menores em sequência.', 5),
      _SkillSeed(9, 'Reserva Arcana', 'Sustente magia por mais tempo antes de se esgotar.', 6),
      _SkillSeed(10, 'Mestre Arcano', 'Execute uma manifestação de grande poder e controle.', 8),
    ],
    'ladino': [
      _SkillSeed(1, 'Movimento Furtivo', 'Desloque-se com discrição e escolha rotas de menor exposição.'),
      _SkillSeed(2, 'Ataque Oportuno', 'Aproveite distrações para atingir pontos vulneráveis.', 0),
      _SkillSeed(3, 'Mãos Ágeis', 'Manipule objetos e mecanismos rapidamente.', 0),
      _SkillSeed(4, 'Passo Sombrio', 'Reposicione-se sem chamar atenção.', 1),
      _SkillSeed(5, 'Evasão', 'Reduza o impacto de ataques de área ou armadilhas.', 3),
      _SkillSeed(6, 'Golpe Debilitante', 'Cause uma penalidade breve ao acertar um ponto crítico.', 1),
      _SkillSeed(7, 'Especialista em Armadilhas', 'Detecte e neutralize mecanismos perigosos.', 2),
      _SkillSeed(8, 'Desaparecer', 'Quebre a linha de visão e volte à furtividade.', 4),
      _SkillSeed(9, 'Instinto de Sobrevivência', 'Reaja mais rápido a ameaças inesperadas.', 6),
      _SkillSeed(10, 'Sombra Perfeita', 'Combine furtividade, mobilidade e precisão em uma ação decisiva.', 7),
    ],
    'arqueiro': [
      _SkillSeed(1, 'Mira Treinada', 'Aprimore postura, respiração e controle do disparo.'),
      _SkillSeed(2, 'Tiro Preciso', 'Priorize precisão contra um único alvo.', 0),
      _SkillSeed(3, 'Passo de Caçador', 'Reposicione-se mantendo distância segura.', 0),
      _SkillSeed(4, 'Tiro Imobilizante', 'Acerte um ponto que dificulta o movimento do alvo.', 1),
      _SkillSeed(5, 'Rajada', 'Faça disparos rápidos contra alvos próximos entre si.', 1),
      _SkillSeed(6, 'Olho de Águia', 'Identifique alvos e detalhes a longa distância.', 2),
      _SkillSeed(7, 'Emboscada', 'Ganhe vantagem ao atacar de posição preparada.', 5),
      _SkillSeed(8, 'Tiro de Cobertura', 'Controle uma área e dificulte o avanço inimigo.', 4),
      _SkillSeed(9, 'Caçador Experiente', 'Rastreie e antecipe rotas de fuga.', 6),
      _SkillSeed(10, 'Disparo Impecável', 'Realize um disparo excepcional quando tiver tempo para mirar.', 8),
    ],
    'clerigo': [
      _SkillSeed(1, 'Prece', 'Canalize sua fé para produzir pequenos efeitos de apoio.'),
      _SkillSeed(2, 'Cura Menor', 'Restaure parte da vitalidade de um aliado.', 0),
      _SkillSeed(3, 'Bênção', 'Conceda um bônus breve a um aliado.', 0),
      _SkillSeed(4, 'Proteção Consagrada', 'Reduza dano ou ameaça contra um alvo protegido.', 2),
      _SkillSeed(5, 'Luz Reveladora', 'Exponha ameaças ocultas ou efeitos sombrios.', 2),
      _SkillSeed(6, 'Cura em Área', 'Compartilhe recuperação entre aliados próximos.', 1),
      _SkillSeed(7, 'Purificar', 'Remova uma condição negativa ou influência nociva.', 4),
      _SkillSeed(8, 'Intervenção', 'Proteja um aliado em um momento crítico.', 3),
      _SkillSeed(9, 'Milagre Menor', 'Produza um efeito extraordinário limitado pela situação.', 6),
      _SkillSeed(10, 'Voz da Fé', 'Fortaleça todo o grupo em um momento decisivo.', 8),
    ],
    'barbaro': [
      _SkillSeed(1, 'Fúria', 'Entre em um estado agressivo de combate e resistência.'),
      _SkillSeed(2, 'Golpe Pesado', 'Concentre força em um ataque de grande impacto.', 0),
      _SkillSeed(3, 'Pele de Ferro', 'Suporte melhor dano físico enquanto luta.', 0),
      _SkillSeed(4, 'Avanço Brutal', 'Atravesse a linha inimiga sem perder o ritmo.', 1),
      _SkillSeed(5, 'Intimidação', 'Use presença e violência para pressionar adversários.', 0),
      _SkillSeed(6, 'Fúria Persistente', 'Mantenha o estado de fúria por mais tempo.', 2),
      _SkillSeed(7, 'Esmagar', 'Quebre defesas, objetos ou obstáculos com força extrema.', 3),
      _SkillSeed(8, 'Recusar a Queda', 'Continue agindo mesmo após receber um golpe crítico.', 5),
      _SkillSeed(9, 'Predador de Batalha', 'Ganhe impulso ao derrubar ou pressionar inimigos.', 6),
      _SkillSeed(10, 'Fúria Implacável', 'Atinga o auge de força e resistência por um curto período.', 8),
    ],
    'investigador': [
      _SkillSeed(1, 'Olhar Analítico', 'Observe uma cena e identifique detalhes fora do padrão.'),
      _SkillSeed(2, 'Leitura de Pistas', 'Relacione evidências e estabeleça conexões prováveis.', 0),
      _SkillSeed(3, 'Entrevista', 'Conduza perguntas de forma metódica e perceba inconsistências.', 0),
      _SkillSeed(4, 'Reconstrução da Cena', 'Organize pistas para estimar a sequência dos acontecimentos.', 1),
      _SkillSeed(5, 'Percepção de Mentira', 'Reconheça sinais de contradição ou evasão.', 2),
      _SkillSeed(6, 'Pesquisa Profunda', 'Encontre informação relevante em arquivos, redes ou registros.', 1),
      _SkillSeed(7, 'Perfil Comportamental', 'Antecipe tendências de um alvo a partir de padrões observados.', 4),
      _SkillSeed(8, 'Instinto Investigativo', 'Receba uma pista adicional quando a investigação estagnar.', 5),
      _SkillSeed(9, 'Teoria do Caso', 'Consolide evidências em uma hipótese verificável.', 6),
      _SkillSeed(10, 'Dedução Final', 'Conecte rapidamente os elementos-chave de um caso complexo.', 8),
    ],
    'pistoleiro': [
      _SkillSeed(1, 'Saque Rápido', 'Prepare e empunhe sua arma com velocidade.'),
      _SkillSeed(2, 'Tiro Controlado', 'Dispare com precisão mesmo sob pressão.', 0),
      _SkillSeed(3, 'Recarga Ágil', 'Reduza o tempo necessário para recarregar.', 0),
      _SkillSeed(4, 'Dois Alvos', 'Alterne rapidamente entre ameaças próximas.', 1),
      _SkillSeed(5, 'Tiro de Supressão', 'Force inimigos a procurar cobertura.', 1),
      _SkillSeed(6, 'Mira Fria', 'Ignore parte das penalidades de distância ou pressão.', 3),
      _SkillSeed(7, 'Ricochete', 'Use ângulos e superfícies para alcançar um alvo difícil.', 1),
      _SkillSeed(8, 'Última Bala', 'Ganhe eficiência extra quando a munição estiver no fim.', 2),
      _SkillSeed(9, 'Olho Morto', 'Identifique rapidamente a maior ameaça em combate.', 5),
      _SkillSeed(10, 'Duelo Perfeito', 'Execute uma sequência decisiva de mira, saque e disparo.', 8),
    ],
    'ocultista': [
      _SkillSeed(1, 'Sensibilidade Oculta', 'Perceba sinais de fenômenos sobrenaturais próximos.'),
      _SkillSeed(2, 'Símbolo de Proteção', 'Prepare uma defesa simples contra influências anômalas.', 0),
      _SkillSeed(3, 'Leitura Ritual', 'Interprete inscrições, padrões e práticas esotéricas.', 0),
      _SkillSeed(4, 'Canalizar Presença', 'Interaja de forma controlada com uma manifestação.', 1),
      _SkillSeed(5, 'Banimento Menor', 'Afaste temporariamente uma entidade ou efeito sobrenatural.', 1),
      _SkillSeed(6, 'Conhecimento Proibido', 'Reconheça padrões raros e perigosos do oculto.', 2),
      _SkillSeed(7, 'Círculo de Contenção', 'Restrinja uma manifestação a uma área preparada.', 4),
      _SkillSeed(8, 'Resistência Mental', 'Mantenha controle diante de fenômenos perturbadores.', 5),
      _SkillSeed(9, 'Ritual Avançado', 'Conduza uma operação ocultista complexa com preparação.', 6),
      _SkillSeed(10, 'Mestre do Véu', 'Manipule temporariamente a fronteira entre o normal e o oculto.', 8),
    ],
    'medico': [
      _SkillSeed(1, 'Primeiros Socorros', 'Estabilize ferimentos e evite piora imediata.'),
      _SkillSeed(2, 'Triagem', 'Identifique rapidamente quem precisa de atendimento primeiro.', 0),
      _SkillSeed(3, 'Controle de Hemorragia', 'Reduza perda de sangue e estabilize ferimentos graves.', 0),
      _SkillSeed(4, 'Tratamento de Campo', 'Recupere um aliado usando recursos limitados.', 1),
      _SkillSeed(5, 'Farmacologia', 'Utilize medicamentos e substâncias com maior eficiência.', 1),
      _SkillSeed(6, 'Diagnóstico Rápido', 'Identifique a causa provável de sintomas incomuns.', 2),
      _SkillSeed(7, 'Procedimento de Emergência', 'Execute uma intervenção crítica sob pressão.', 3),
      _SkillSeed(8, 'Gestão de Trauma', 'Mantenha pacientes graves estáveis durante uma crise.', 5),
      _SkillSeed(9, 'Especialista Clínico', 'Aplique conhecimento avançado a quadros complexos.', 6),
      _SkillSeed(10, 'Salvar Vida', 'Realize uma intervenção decisiva em uma situação extrema.', 8),
    ],
  };
}

class _SkillSeed {
  final int level;
  final String name;
  final String description;
  final int? parentIndex;
  const _SkillSeed(this.level, this.name, this.description, [this.parentIndex]);
}
