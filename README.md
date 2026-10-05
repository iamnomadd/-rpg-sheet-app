# RPG Sheet — V1.3.17 (Web/PWA)

Versão atual do projeto: **1.3.17+117**. A plataforma principal é Flutter Web/PWA, publicada pelo workflow `Build RPG Sheet Web`. O fluxo Android antigo permanece apenas como histórico/legado e não é o caminho de distribuição atual.

Principais documentos desta versão: `RELEASE_NOTES_1.3.13.md`, `RELEASE_NOTES_1.3.17.md` e `supabase/README.md`.

---

# RPG Sheet App — V1.0.1

## Correção de atualizações Android
- Assinatura release permanente via GitHub Actions.
- Keystore mantido fora do projeto e carregado por GitHub Secrets.
- Mantém o mesmo pacote Android do app para permitir atualização nas próximas versões.
- A migração para esta chave pode exigir uma última desinstalação da versão anterior.
- Depois disso, futuras versões assinadas com a mesma chave poderão atualizar por cima da instalada.

# RPG Sheet App — V0.21.6

## Alterações desta versão
- Aba **Geral** renomeada para **Resumo**.
- Aba **Atrib./Rec.** renomeada para **Status**.
- Removido o botão/ícone de câmera sobre o avatar no cabeçalho da ficha.
- O avatar do cabeçalho permanece apenas como identificação visual; a experiência detalhada do personagem fica na aba Ações.
- Mantidas as funcionalidades da V0.21.5.

# RPG Sheet App — V0.14

## V0.9 — Preparação para conta e sincronização
- Nova central de Conta e Sincronização.
- Resumo dos dados locais: fichas, sistemas, campanhas e histórico de dados.
- Atalho para gerar backup completo antes da futura sincronização.
- Interface preparada para login e nuvem, sem fingir que existe um backend conectado.
- Nenhum dado é enviado à internet nesta versão.
- Mantém todas as funções da V0.8.

### Importante
A sincronização real entre aparelhos exige configurar um backend (por exemplo, Supabase ou Firebase). A V0.9 deixa a base de interface pronta, mas não ativa um serviço externo sem configuração/credenciais.

Versão do projeto: 0.14.0+21


## V0.10.0 — Interface e experiência

- Padronização visual geral em Material 3.
- Cards, campos, botões e navegação com espaçamento e cantos consistentes.
- Melhor leitura em telas pequenas e grandes.
- Estados vazios e confirmações preservados/melhorados.
- Tela de fichas, sistemas, dados, campanhas e configurações revisadas visualmente.
- Aba Geral continua somente leitura e com blocos reordenáveis.
- Criador de sistemas continua sem fórmulas automáticas/atributos derivados.
- Identificação visual da versão: V0.10.0.
- Mantém compatibilidade com os dados locais das versões anteriores.

## V0.10.1 — Temas
- 10 temas visuais: Clássico Escuro, Pergaminho, Medieval, Arcano, Vampírico, Floresta, Oceano, Cyberpunk, Infernal e Gelo.
- Seletor em Configurações > Aparência e temas.
- O tema altera cores, superfícies, cantos e a identidade por ícones da tela de seleção.
- A escolha é salva localmente e restaurada ao abrir o app.


## V0.10.2 — Identidade dos Temas
- Paletas reforçadas para Pergaminho, Medieval, Vampírico, Floresta, Oceano, Infernal e Gelo.
- Clássico, Cyberpunk e Arcano preservam suas paletas aprovadas.
- Ícones principais da ficha agora mudam de linguagem visual conforme o tema.
- Cyberpunk usa símbolos mais tecnológicos/HUD; Arcano usa símbolos místicos; demais temas recebem identidade própria.
- Sem fórmulas automáticas/atributos derivados.


## V0.10.3 — Temas e navegação da ficha

- Oceano foi substituído por **Elemento Ar** (branco/cinza).
- Floresta foi substituída por **Elemento Terra** (tons terrosos).
- Pergaminho foi substituído por **Sombrio**; na V1.3.3 ele evolui para **Sombrio Pirata** (mar noturno, madeira e ouro antigo).
- Nova ordem da ficha: **Geral → Atrib./Rec. → Habilidades → Perícias → Inventário → Seções**.
- Atributos e Recursos agora compartilham uma única aba.
- Habilidades e Inventário ganharam abas próprias.
- A aba Extras foi removida da navegação principal.
- Compatibilidade com os dados existentes foi preservada.


## V0.10.4 — Refinamento visual

- Barra de navegação da ficha refinada.
- Ícones selecionados agora possuem variações próprias por tema.
- Tema Cyberpunk recebeu navegação mais angular e tecnológica.
- Tema Arcano usa indicador mais suave/místico.
- Temas Medieval, Sombrio Pirata e Infernal possuem formas de seleção próprias.
- Melhor contraste entre ícones ativos e inativos.
- Leve destaque de borda na barra da ficha para separar a navegação do conteúdo.
- Mantida a ordem: Geral → Atrib./Rec. → Habilidades → Perícias → Inventário → Seções.
- Versão 0.10.4+17.

## V0.11 — Criador de Sistemas Avançado

- Editor de sistemas reorganizado com resumo da estrutura e contadores.
- Atributos, perícias, recursos e seções agora podem ser renomeados diretamente.
- Itens podem ser reorganizados por arrastar e soltar; a nova ordem é refletida na ficha.
- Proteção contra nomes duplicados dentro da mesma categoria.
- Confirmação antes de excluir elementos estruturais.
- Renomeações preservam os valores já preenchidos nas fichas vinculadas ao sistema.
- Novos elementos são sincronizados com fichas existentes ao salvar o sistema.
- Editor de dados mantido e organização automática dos dados por quantidade de faces.
- Fórmulas automáticas/atributos derivados não foram adicionados nesta versão.
- Versão 0.11.0+18.

## V0.12 — Sessão de RPG

- Nova central **Sessão de RPG** dentro das campanhas no Modo Mestre.
- Contador de rodadas com avanço, retorno e reinício.
- Rastreador de iniciativa com ordenação automática do maior para o menor.
- Controle rápido dos recursos das fichas vinculadas à campanha, com botões de +1 e -1.
- Registro de condições ativas durante a sessão.
- Notas rápidas da sessão, separadas das notas gerais e das notas privadas do mestre.
- Dados de sessão ficam salvos junto da campanha e entram normalmente em backup/exportação.
- Compatibilidade preservada com campanhas criadas nas versões anteriores.
- Sem fórmulas automáticas/atributos derivados.
- Versão 0.12.0+19.

## V0.13 — Biblioteca de Sistemas

- Nova biblioteca de modelos prontos dentro da tela de Sistemas.
- Modelos genéricos iniciais: Fantasia Heroica, Investigação, Horror e Sobrevivência e Aventura Cinematográfica.
- Qualquer modelo vira um sistema normal e totalmente editável após ser criado.
- Sistemas existentes podem ser duplicados sem alterar o original.
- Menu rápido por sistema com Editar, Duplicar, Exportar e Excluir.
- Importação de arquivos de sistema `.rpg` diretamente pela tela de Sistemas.
- Importação e exportação agora preservam também a lista de dados configurada pelo sistema.
- Nomes duplicados recebem sufixo automaticamente.
- Fórmulas automáticas/atributos derivados continuam fora desta versão.
- Versão 0.13.0+20.

## V0.14 — Compartilhamento

- Compartilhamento direto de fichas pelo próprio editor.
- Duas formas de compartilhar ficha: arquivo `.rpg` editável ou resumo em texto.
- Campanhas agora podem ser compartilhadas em **Pacote para Jogadores** ou **Cópia Completa do Mestre**.
- Pacote para Jogadores não inclui notas privadas do mestre, dados privados de sessão nem fichas marcadas como ocultas.
- Cópia Completa do Mestre inclui fichas, sistemas usados, notas privadas e estado da sessão.
- Importação de campanha `.rpg` adicionada, recriando IDs para evitar conflitos com dados existentes.
- Sistemas e fichas incluídos no pacote de campanha são importados junto com a campanha.
- Resumo público de campanha pode ser compartilhado como texto.
- A área Importar/Exportar passou a listar também campanhas.
- O compartilhamento desta versão funciona por arquivos/cópias independentes; permissões e convites em tempo real dependem da futura sincronização em nuvem.
- Versão 0.14.0+21.


## V0.15 — Qualidade e configurações
- Texto maior (acessibilidade) com preferência persistente.
- Modo compacto para aproveitar melhor telas menores.
- Configurações reorganizadas por Aparência, Dados e segurança e Manutenção.
- Resumo dos dados locais (fichas, sistemas, campanhas e rolagens).
- Limpeza independente do histórico de rolagens.
- Aviso de backup antes da exclusão total de dados.
- Removido o placeholder de PDF das configurações.
- Versão 0.15.0+22.


## V0.16 — Personalização Avançada
- Personalização da ordem das abas em cada ficha.
- Botão dedicado de personalização no topo da ficha.
- Reordenação por arrastar e soltar com prévia dos ícones do tema atual.
- Opção Restaurar para voltar à ordem padrão.
- A ordem personalizada é salva junto da ficha e preservada em exportações/backups.
- A aba Geral continua permitindo reorganizar seus blocos internos.
- Compatibilidade automática com fichas antigas.
- Sem fórmulas automáticas/atributos derivados.


## V0.17 — Ferramentas de Mestre
- Novo Painel do Mestre por campanha.
- Cena atual da campanha.
- Objetivos privados com checklist.
- Referência rápida de NPCs e locais.
- Acesso centralizado às notas privadas.
- Registro de acontecimentos da sessão.
- Novos dados persistem em campanhas, backups e exportações.
- Compatível com campanhas antigas.

## V0.18 — Dados e Automações de Rolagem
- Atalhos rápidos para rolagens comuns.
- Favoritos/rolagens salvas com nome próprio.
- Repetição de qualquer rolagem pelo histórico.
- Integração com fichas: um atributo pode ser aplicado como modificador da rolagem atual.
- Presets preservam quantidade, dado, modificador e modo (normal/vantagem/desvantagem).
- Favoritos são salvos localmente e incluídos no backup completo.
- Histórico ampliado na tela para as 30 rolagens mais recentes.
- Mantém expressões personalizadas como `2d6+3` e dados definidos por sistema.
- Sem fórmulas automáticas de atributos derivados.

## V0.19 — Backup e Migração
- Backup completo atualizado para incluir fichas, sistemas, campanhas, favoritos de rolagem, histórico de dados e preferências visuais.
- Restauração seletiva em três grupos: dados de jogo, rolagens/favoritos e preferências.
- Prévia do conteúdo do backup antes da restauração, com contadores de fichas, sistemas, campanhas e rolagens.
- Compatibilidade de migração com backups antigos no formato V1 e novos backups no formato V2.
- Backups antigos continuam restauráveis mesmo sem os campos adicionados nesta versão.
- Fichas, sistemas e campanhas são restaurados como um conjunto para preservar vínculos internos.
- Tema, texto maior e modo compacto podem acompanhar a migração quando presentes no arquivo.
- Identificação visual atualizada para V0.19.0.
- Versão 0.19.0+26.


## V0.20.1 — Refinamento da Ficha
- Revisão estrutural dos dados locais antes da V1.0.
- Nova tela **Verificação beta** em Configurações > Manutenção.
- Diagnóstico de referências quebradas entre fichas, sistemas e campanhas.
- Correção automática segura para vínculos inválidos, sistema genérico ausente, rodadas inválidas e histórico acima do limite.
- Leitura de dados locais mais resistente a JSON corrompido/inválido, evitando falhas ao iniciar o app.
- Proteção contra exclusão de sistema que ainda esteja sendo usado por fichas.
- Resumo de fichas, sistemas, campanhas e rolagens na verificação beta.
- Compatibilidade preservada com dados e backups das versões anteriores.
- Sem fórmulas automáticas/atributos derivados.
- Versão 0.20.1+28.


## V0.21 — Conta e Nuvem
- Login e criação de conta por e-mail via Supabase Auth.
- Envio de fichas, sistemas, campanhas, rolagens e preferências para a nuvem.
- Restauração do backup da conta em outro aparelho.
- Sessão da conta persistida localmente.
- Fallback seguro: sem chaves do Supabase, o app continua funcionando normalmente em modo local.
- Inclui `supabase/setup.sql` com tabela e políticas RLS.
- Compilar com `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` para ativar a nuvem.
- Versão 0.21.0+29.


## V0.21.1 — Refinamento da ficha
- Cards de atributos menores e mais compactos.
- Vida e Energia podem ser alteradas diretamente na aba Geral com -/+, além do ajuste manual.
- Atributos, habilidades e inventário permanecem somente leitura na aba Geral.
- Mantidas as barras temáticas e toda a base de Conta e Nuvem da V0.21.
- Versão 0.21.1+30.


## V0.21.2 — Habilidades, inventário e árvore
- Barras de Vida e Energia centralizadas também na aba Geral, iguais ao comportamento visual em Recursos.
- Habilidades agora aceitam nome e descrição.
- Itens de inventário agora aceitam nome e descrição.
- Nova Árvore de Habilidades por personagem, com pré-requisitos e estado desbloqueado.
- A Árvore pode ser acessada pela ficha e pela navegação principal do app.
- Compatibilidade mantida com fichas antigas.
- Versão 0.21.2+31.


## V0.21.3 — Itens e Habilidades Avançados
- Barra de abas da ficha realinhada com células de altura e largura consistentes e rolagem horizontal.
- Habilidades e inventário agora podem ser editados após a criação.
- Categorias de inventário: Arma, Armadura, Consumível, Acessório, Ferramenta e Outro.
- Armas possuem campo de dano.
- Categorias de habilidades incluem Magia, Técnica, Passiva e Outro.
- Magias possuem dano e duração instantânea ou por turnos.
- Compatibilidade mantida com itens e habilidades de versões anteriores.
- Versão 0.21.3+32.


## V0.21.4 — Árvore Visual, Dados e Identidade dos Temas
- Árvore de Habilidades redesenhada como ramificações visuais conectadas, com zoom e navegação por arraste.
- Nós da árvore mostram estados desbloqueado, disponível e bloqueado por pré-requisito.
- Habilidades da árvore podem ser criadas, editadas, removidas e reorganizadas por pré-requisito.
- Skills desbloqueadas da árvore aparecem em formato de lista compacta na aba Geral.
- Importação/exportação preserva descrições, categorias, detalhes avançados e a árvore de habilidades.
- Resumos de Habilidades e Inventário na Geral agora exibem categoria, dano e duração quando aplicáveis.
- Tela de Dados reorganizada para reduzir rolagem vertical; botão Rolar e resultado imediato ficam próximos.
- Favoritos e rolagem com ficha foram compactados em áreas expansíveis.
- Ícones da navegação principal e da ficha receberam identidades mais distintas por tema.
- O desenho do ícone não muda ao selecionar/desselecionar uma aba; somente destaque, cor e indicador mudam.
- Indicadores de seleção acompanham melhor a linguagem visual de cada tema.
- Assistência de IA permanece apenas como ideia futura e não foi implementada.
- Versão 0.21.4+33.

## V0.21.7
- Armas podem vincular o carregador a um consumível do inventário; recarregar transfere apenas a munição disponível do estoque.
- Consumíveis podem aplicar um efeito opcional em Vida, Energia ou outro recurso ao serem usados.
- Árvore de habilidades ganhou legenda de estados e indicação explícita da direção de progressão.
- Condições do personagem podem ser adicionadas/removidas rapidamente na aba Ações.
- Grupos de Ações podem ser reordenados ou ocultados por personagem.
- Mantém compatibilidade com fichas anteriores; os novos campos possuem valores padrão na migração local.


## V0.22.0 — Sincronização entre dispositivos
- Sincronização automática via Supabase para contas conectadas.
- Comparação de data local/nuvem e estratégia de versão mais recente.
- Botão Sincronizar agora, status e data da última sincronização.
- Envio/restauração manual preservados como opções de recuperação.
- Backup local .rpg continua independente da nuvem.
- Requer SUPABASE_URL e SUPABASE_ANON_KEY no build para ativar a nuvem.


## V0.22.0 — Supabase conectado
Esta build possui como configuração padrão o projeto Supabase do RPG Sheet usando somente a chave pública/publishable. `SUPABASE_URL` e `SUPABASE_ANON_KEY` via `--dart-define` continuam podendo sobrescrever os valores padrão. Nunca inclua `service_role` no site/PWA.

## V0.22.1 — Correções de teste
- Categoria de inventário `Munição`, com quantidade e sem efeitos de Vida/Energia.
- Armas vinculam preferencialmente itens da categoria `Munição`; vínculo antigo com Consumível é preservado para compatibilidade.
- Seletor de categoria atualizado para menu ancorado abaixo do campo sempre que houver espaço.
- A aba Ações não mostra mais notificações para ações bem-sucedidas; mensagens ficam reservadas para erros/ações impossíveis.
- Permissão `INTERNET` adicionada explicitamente ao manifesto Android de release para permitir Supabase no APK.
- Erros de rede da nuvem passam a usar mensagem amigável em vez de expor `SocketException`.

## V0.22.2 — Nuvem sem cadastro obrigatório
- Sincronização em nuvem passa a criar uma sessão anônima automaticamente quando não há conta vinculada.
- E-mail e senha deixam de ser obrigatórios para usar a nuvem.
- Nova área **Proteja sua nuvem** permite vincular e-mail/senha opcionalmente para recuperação em outro aparelho.
- Nova opção para recuperar uma nuvem já protegida em outro aparelho.
- Sessões Supabase passam a tentar renovação por refresh token antes da sincronização.
- RLS existente continua isolando cada usuário, inclusive sessões anônimas autenticadas.
- Requer habilitar **Anonymous Sign-Ins** e **Manual Linking** no Supabase Auth.
- Versão 0.22.2+43.

### Fix de build 1.0.1
O workflow remove `test/widget_test.dart` somente quando ele é criado automaticamente pelo `flutter create`. Esse teste padrão referencia `MyApp`, que não existe neste projeto, e fazia o passo Analyze falhar antes da compilação.


## Política de versionamento

Cada atualização distribuída recebe uma nova versão sequencial, inclusive correções/hotfixes.


## Fluxo de publicação a partir da 1.3.10

- Cada push em `main` executa dependências, análise, testes e build Flutter Web no GitHub Actions.
- O build final (`build/web`) é publicado automaticamente no projeto de testes Cloudflare Pages `rpg-sheet-test`.
- URL de teste: `https://rpg-sheet-test.pages.dev`.
- O deploy usa os repository secrets `CLOUDFLARE_API_TOKEN` e `CLOUDFLARE_ACCOUNT_ID`.
- Netlify permanece como ambiente de produção e deve receber somente versões aprovadas.
