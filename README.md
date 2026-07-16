# **OUTBREAK PROTOCOL: PAMPA**

**Documento de design e documentação do estado implementado**

**Plataforma:** PC (Windows)

**Engine:** Godot 4.6, renderização Forward Plus e física Jolt

**Gênero atual:** FPS de sobrevivência e extração com hordas de infectados

**Público-alvo:** 17+ | Classificação equivalente: M (Mature)

**Jogadores:** 1 jogador em solo ou 1 a 4 jogadores em coop online

**Mapa disponível:** Estância Queimada

**Referências de direção:** S.T.A.L.K.E.R., Call of Duty: Zombies e jogos de extração

---

# **VISÃO ATUAL DO JOGO**

Outbreak Protocol: Pampa é um FPS em primeira pessoa ambientado em uma região rural corrompida do sul do Brasil. O jogador entra na Estância Queimada, enfrenta uma população contínua de infectados, recolhe sucata, compra armamento e melhorias em bancadas e procura os fragmentos que liberam o confronto final.

O protótipo inicial evoluiu para uma partida de sobrevivência em mapa aberto. O jogo combina exploração livre, pressão crescente, hordas ativadas por coletáveis, economia durante a expedição, chefe final e extração voluntária no modo solo.

O jogo possui dois modos selecionáveis no menu principal:

* **Solo:** um jogador, pausa global, bancada com pausa e extração persistente.
* **Coop:** até quatro jogadores conectados por ENet, com host autoritativo, lobby, prontidão, sincronização de carregamento, combate, estado dos jogadores e revives.

---

# **HISTÓRIA E FLUXO DE JOGO**

## **História**

Algo aconteceu no extremo sul do Rio Grande do Sul. Os primeiros registros falam em tremores sísmicos, falhas de comunicação e, por fim, silêncio. A região foi isolada depois do evento conhecido como **A Ruptura**.

A matéria orgânica mudou. Pessoas que permaneceram na zona perderam a cognição e se tornaram criaturas agressivas. Artefatos anômalos surgiram pelo território, e uma criatura muito maior passou a responder à energia liberada por esses fragmentos.

O agente entra na Estância Queimada para sobreviver, recuperar material e investigar a origem da anomalia. A narrativa concreta do jogo acontece principalmente pelo ambiente, pelos fragmentos e pela progressão até o chefe.

## **Fluxo da partida implementado**

**[ INTRODUÇÃO ]**

O jogo mostra a classificação indicativa e a identidade visual do projeto. O jogador pode pular as telas com Enter, Escape ou clique do mouse.

**[ MENU PRINCIPAL ]**

O menu apresenta o operador em 3D, o mapa Estância Queimada, seleção entre Solo e Coop, acesso às configurações gráficas e o botão de início.

**[ CARREGAMENTO ]**

Uma tela própria carrega o mapa em segundo plano, mostra o progresso e monta a cena de gameplay. No multiplayer, ela também aguarda a criação do personagem local e a sincronização dos participantes.

**[ INSERÇÃO ]**

O agente entra com:

* C19;
* faca;
* 250 de sucata;
* 1 kit médico;
* vida cheia;
* sem colete;
* reservas iniciais de munição para 9 mm, rifle e cartuchos.

**[ SOBREVIVÊNCIA E EXPLORAÇÃO ]**

Entre 32 e 40 infectados permanecem ativos ao redor dos jogadores em condições normais. O diretor cria inimigos fora da visão direta, reaproveita instâncias distantes e mantém a pressão enquanto o grupo explora casas, fazenda, posto de gasolina, cabana, estradas, veículos, açude e zona industrial.

**[ ECONOMIA ]**

Cada infectado derrotado deixa sucata. O agente recolhe o material por proximidade e o usa nas quatro bancadas distribuídas pelo mapa para adquirir armas, munição, proteção, kits médicos e melhorias específicas por arma.

**[ FRAGMENTOS E HORDAS ]**

Existem três fragmentos principais. Cada coleta ativa uma horda especial. As hordas possuem, respectivamente, 24, 36 e 50 infectados, com alta presença de corredores, distribuídos ao longo de aproximadamente 8 segundos.

**[ CONFRONTO FINAL ]**

Depois dos três fragmentos, o Fragmento 2 fica disponível. Ao coletá-lo, o jogo inicia uma contagem de 8 segundos, aumenta a pressão dos infectados e cria o chefe próximo aos jogadores. A morte do chefe conclui o objetivo do mapa e exibe a condição de vitória no HUD.

**[ EXTRAÇÃO SOLO ]**

No modo solo, o jogador pode abrir o menu de pausa e escolher **Sair da Expedição**. Essa decisão inicia uma contagem de 60 segundos. O jogo volta a rodar e o agente precisa permanecer vivo até o fim do tempo.

Uma extração concluída retorna ao menu principal e guarda para a próxima expedição:

* sucata;
* fragmentos coletados;
* colete;
* kits médicos;
* armas adquiridas;
* melhorias das armas;
* munição reserva;
* munição dos carregadores;
* arma equipada.

O arquivo de extração é consumido ao iniciar a expedição seguinte. Uma morte, reinício ou saída normal sem concluir outra extração não cria um novo salvamento. Vida e God Mode não persistem.

**Estado atual importante:** a extração persistente está disponível apenas no modo solo. Derrotar o chefe conclui o mapa, mas não inicia automaticamente a contagem de extração.

---

# **O AGENTE**

## **Perfil atual**

O jogador controla um soldado sem nome fixo. Em primeira pessoa, o jogo usa mãos e armas próprias de FPS. O corpo completo do Soldier representa o agente para outros participantes no multiplayer e recebe animações direcionais de movimento.

O agente possui 100 pontos de vida. O colete absorve dano antes da vida e pode chegar a 100 pontos. Cada kit médico recupera até 50 HP, com limite de três kits carregados.

## **Controles implementados**

| Ação | Tecla ou comando | Comportamento atual |
| :--- | :--- | :--- |
| Mover | WASD | Movimento em primeira pessoa |
| Correr | Shift | Aumenta a velocidade de 5 para 8 unidades por segundo |
| Pular | Espaço | Salto com assistência para pequenos degraus |
| Mirar | Botão direito | ADS com ajuste de arma e campo de visão |
| Atirar | Botão esquerdo | Disparo semiautomático ou automático conforme a arma |
| Recarregar | R | Transfere munição da reserva para o carregador |
| Ataque corpo a corpo | V | Executa golpe de curta distância |
| Trocar arma | 1 a 6 ou roda do mouse | Seleciona somente armas já adquiridas |
| Interagir | E | Abre bancada e interage com objetivos próximos |
| Reviver aliado | Segurar E | Coop, revive aliado caído a até 2,5 m em 4 segundos |
| Usar kit médico | H | Consome um kit e recupera até 50 HP |
| Lanterna | F | Liga ou desliga a lanterna sincronizada |
| Placar | Segurar Tab | Exibe jogadores, sucata, vida e estado da equipe |
| Pausa | Escape | Pausa o mundo apenas no modo solo |
| Fechar bancada | Escape | Fecha a interface de criação sem abrir o menu de pausa no mesmo comando |
| God Mode | O | Alterna invulnerabilidade e permite compras sem gastar sucata |

## **Vida, queda e morte**

No solo, o dano letal mata o agente e reinicia a expedição depois do feedback de morte.

No coop, o dano letal coloca o agente no estado **Caído**. Outro jogador pode revivê-lo. Se o tempo de queda terminar, o agente passa a **Espectador**. A partida encerra quando toda a equipe estiver fora do estado ativo.

## **Pausa e bancada**

No solo, Escape pausa toda a árvore de cenas. Abrir uma bancada também pausa o mundo, bloqueia movimento e combate e libera o cursor. Fechar a bancada restaura os controles e a captura do mouse.

No coop, o menu e a bancada bloqueiam somente os controles do jogador local. Inimigos, aliados e a sessão continuam ativos.

---

# **GAMEPLAY**

## **Perspectiva e apresentação**

O gameplay usa câmera em primeira pessoa, mira dinâmica, hitmarker, indicador de headshot, contador de munição, recuo, sway, animações de arma, muzzle flash, fumaça e marcas de impacto.

O HUD apresenta:

* vida e colete;
* kit médico e sucata;
* munição do carregador e da reserva;
* mira e confirmação de acerto;
* mensagens de interação e compra;
* estado de extração;
* estado de caído e progresso de revive;
* placar da equipe;
* alerta, vida e estado de fúria do chefe;
* confirmação de conclusão do mapa.

## **Combate**

O jogo oferece cinco armas de fogo e uma faca. C19 e faca fazem parte do equipamento inicial. As demais armas precisam ser compradas em bancada.

| Slot | Arma | Tipo | Dano base de gameplay | Carregador | Alcance | Custo |
| :---: | :--- | :--- | ---: | ---: | ---: | ---: |
| 1 | C19 | Pistola semiautomática | 25 | 19 | 50 m | Inicial |
| 2 | SMG45 | Submetralhadora automática | 20 | 30 | 50 m | 1.800 |
| 3 | AK | Rifle automático | 35 | 30 | 100 m | 3.200 |
| 4 | LMG63 | Metralhadora leve automática | 30 | 100 | 80 m | 5.000 |
| 5 | Sawnoff | Escopeta de dois canos | 160 total no sistema visual, validada por pellets | 2 | 10 m | 2.400 |
| 6 | Faca | Corpo a corpo | 70 no modelo local, ataque validado em rede | Sem munição | 3 m | Inicial |

Os infectados possuem hitboxes de cabeça, torso e membros. Acertos na cabeça causam multiplicador maior, enquanto membros reduzem o dano. O chefe também possui hitboxes ligadas ao esqueleto.

## **Progressão de dificuldade**

A vida dos infectados aumenta 25% a cada 120 segundos, até o máximo de quatro vezes a vida base.

O diretor alterna a composição da população:

* durante os primeiros 120 segundos do ciclo, aproximadamente 15% dos ativos são corredores;
* nos 60 segundos seguintes, a proporção usa o valor de pressão de 45%;
* hordas de fragmento e batalha do chefe usam aproximadamente 90% de corredores.

Durante o chefe, a população alvo recebe multiplicador de 1,75 e o intervalo de criação cai para 0,30 segundo.

---

# **MUNDO DO JOGO**

# **O MAPA: ESTÂNCIA QUEIMADA**

Estância Queimada é o único mapa jogável. O cenário usa terreno 3D com materiais de solo, navegação própria e uma composição rural aberta que inclui:

* campos e trechos de grama;
* casas e agrupamentos residenciais;
* fazenda e estruturas rurais;
* cabana;
* posto de gasolina;
* açude;
* estradas e cruzamentos;
* carros civis, viaturas, táxi, SUV, esportivos e Humvee;
* aeronaves e elementos de cenário militar;
* zona industrial;
* paredes invisíveis de limite;
* quatro bancadas de criação;
* três Fragmentos e um Fragmento 2;
* floresta de borda e vegetação interna.

## **Vegetação**

As quatro florestas de borda usam a cena otimizada de árvores. O interior do mapa gera 96 árvores visuais com os mesmos pinheiros, agrupadas em MultiMesh para reduzir chamadas de renderização.

As árvores internas ficam em áreas de grama, respeitam espaçamento aproximado de 18 metros, variam rotação e escala e evitam a zona industrial, construções, estradas e outras áreas excluídas. As árvores são maiores que o personagem e não possuem colisão individual.

Os grupos de vegetação usam distância de visibilidade e transição gradual. A floresta de borda também recebe controle de visibilidade para reduzir custo quando está distante.

## **Navegação e spawn**

O mapa utiliza uma malha de navegação externa pré-calculada e possui fallback de construção em runtime. O diretor valida terreno, inclinação, espaço livre, caminho até o jogador e visibilidade antes de criar inimigos.

Na zona industrial, regras específicas mantêm infectados e chefe dentro da área válida e evitam que o spawn aconteça em estruturas ou pisos incorretos.

## **Atmosfera**

O mapa combina vento ambiente, neblina, glow, iluminação direcional, nuvens, lua, halo, névoa baixa, partículas no ar e uma parede de tempestade no limite. O sistema possui estados de dia e noite e ajusta lanterna, luz, atmosfera e efeitos conforme o estado.

O menu de gráficos pode desligar ou reduzir os elementos mais caros sem alterar a lógica da partida.

---

# **ECONOMIA E BANCADA**

## **Sucata**

Todo infectado derrotado gera uma coleta de sucata. Os valores atuais são:

| Chance | Valor |
| :--- | ---: |
| 60% | 50 |
| 25% | 75 |
| 12% | 125 |
| 3% | 250 |

As coletas permanecem por 30 segundos, piscam nos 8 segundos finais e são atraídas para jogadores próximos. O sistema limita a 64 coletas ativas e combina valor em uma coleta existente quando necessário.

## **Suprimentos**

| Item | Quantidade ou efeito | Limite | Custo |
| :--- | :--- | ---: | ---: |
| Kit médico | Recupera até 50 HP | 3 | 450 |
| Colete | Completa até 100 pontos | 100 | 12 por ponto ausente |
| Munição 9 mm | +60 | 240 | 250 |
| Munição de rifle | +120 | 600 | 450 |
| Cartuchos | +16 | 64 | 350 |

## **Melhorias por arma**

Cada arma de fogo possui progressão separada:

* **Dano:** três níveis, com multiplicadores de 1,15, 1,30 e 1,50.
* **Carregamento rápido:** reduz o tempo de recarga.
* **Carregador estendido:** aumenta a capacidade em 50%; a Sawnoff passa de 2 para 4.
* **Rapid Fire:** reduz o intervalo entre disparos em 20%.

| Arma | Dano I / II / III | Recarga rápida | Carregador estendido | Rapid Fire |
| :--- | :--- | ---: | ---: | ---: |
| C19 | 600 / 1.200 / 2.400 | 900 | 1.100 | 1.300 |
| SMG45 | 750 / 1.500 / 3.000 | 1.100 | 1.400 | 1.700 |
| AK | 900 / 1.800 / 3.600 | 1.350 | 1.650 | 1.950 |
| LMG63 | 1.200 / 2.400 / 4.800 | 1.800 | 2.400 | 2.600 |
| Sawnoff | 800 / 1.600 / 3.200 | 1.200 | 1.500 | 1.700 |

## **God Mode**

A tecla O ativa uma ferramenta de teste integrada. Enquanto o God Mode estiver ativo, o agente não recebe dano e todas as compras podem ser concluídas sem exigir ou descontar sucata. Esse estado funciona localmente e passa pela autoridade do servidor em partidas de rede, mas não faz parte da persistência da extração.

---

# **INIMIGOS**

## **Corrompidos**

Os Corrompidos são o inimigo comum implementado. Eles usam uma máquina de estados com patrulha, perseguição, ataque, busca e morte.

Comportamentos concretos:

* detectam jogadores em até 28 metros;
* perdem o alvo depois de 45 metros em condições de busca;
* vagam quando não detectam um alvo;
* perseguem o jogador vivo mais adequado;
* contornam obstáculos com navegação e sondas físicas;
* atacam a aproximadamente 2 metros;
* causam 10 de dano com intervalo de 1,5 segundo;
* recebem variação entre caminhantes e corredores;
* sincronizam posição, estado visual, ataques e áudio no multiplayer;
* retornam a um pool quando ficam distantes e invisíveis;
* deixam sucata ao morrer.

O corpo do infectado usa animações de idle, caminhada, corrida, ataque, reação e morte. Sons de voz, corrida, ataque e morte acompanham o estado visual.

## **Chefe final**

O chefe atual usa o modelo de uma grande criatura corrompida. Ele não representa ainda, de forma definitiva, o Negrinho do Pastoreio descrito no planejamento inicial.

Características implementadas:

* 12.000 HP base;
* +60% de vida para cada jogador adicional vivo;
* introdução com rugido e invulnerabilidade temporária;
* caminhada e corrida conforme a distância;
* quatro variações de ataque, entre 40 e 85 de dano;
* seleção do jogador vivo mais próximo;
* navegação própria e tratamento especial da zona industrial;
* estado de fúria abaixo de 35% da vida;
* aumento de 30% na velocidade de movimento e ataques durante a fúria;
* música de batalha, passos, corrida, ataques, rugidos e som de morte;
* barra de vida, alerta de chegada e indicador de fúria no HUD;
* conclusão do mapa quando derrotado.

---

# **MULTIPLAYER COOP**

## **Conexão e lobby**

O coop utiliza ENet sobre UDP na porta 7000. A interface foi preparada para conexão direta por IPv4, com instruções para uso via Radmin VPN.

O lobby permite:

* criar partida;
* entrar pelo IPv4 do host;
* definir nome do jogador;
* exibir até quatro participantes;
* marcar ou cancelar prontidão;
* permitir início somente pelo host e quando todos estiverem prontos;
* copiar o caminho dos logs de diagnóstico.

O jogo valida uma versão interna do protocolo antes de aceitar participantes.

## **Autoridade e sincronização**

O host controla:

* criação dos jogadores;
* população e comportamento dos infectados;
* dano confirmado;
* munição e cadência validadas;
* compras e inventário da partida;
* sucata e coletáveis;
* progressão dos fragmentos;
* criação, vida e morte do chefe;
* estados de caído, revive e derrota da equipe.

Cada cliente controla seu movimento local e publica transformações para os outros participantes. O corpo em terceira pessoa, animações, lanterna, arma equipada e estados principais são replicados.

O carregamento multiplayer possui confirmação de mapa pronto, estado de espera dos peers, timeout de 120 segundos e logs de diagnóstico para host e convidados.

## **Limites atuais do coop**

* A extração persistente não funciona no multiplayer.
* A conclusão do chefe é sincronizada, mas não existe retorno de equipe para um lobby pós-partida.
* A sessão usa conexão direta e depende da rede/VPN configurada pelos jogadores.
* Não existem matchmaking público, reconexão ou migração de host.

---

# **INTERFACE, MENUS E CONFIGURAÇÕES**

## **Fluxo de telas**

1. Intro de classificação e logotipo.
2. Menu principal com operador 3D.
3. Seleção Solo ou Coop.
4. Lobby de rede, quando Coop estiver selecionado.
5. Tela de carregamento do mapa.
6. Gameplay em Estância Queimada.

## **Menu de pausa**

O menu de pausa oferece:

* retomar jogo;
* recomeçar no solo;
* sair da expedição no solo;
* abrir gráficos;
* voltar ao menu principal;
* fechar o jogo.

## **Configurações gráficas**

O jogo salva as configurações em `user://graphics_settings.cfg` e oferece os presets **PC Fraco**, **Equilibrado**, **Qualidade** e **Personalizado**.

Opções disponíveis:

* modo janela ou tela cheia;
* VSync;
* limite ilimitado, 30, 60, 120, 144 ou 240 FPS;
* escala interna do 3D;
* FXAA, MSAA 2x, MSAA 4x e TAA;
* qualidade e distância de sombras;
* sombras da lanterna;
* neblina, glow e SSAO;
* distância de renderização da câmera;
* distância de detalhes do terreno;
* resolução das texturas das casas em 256, 512 ou 1024 pixels.

Alterações sensíveis de tela exigem confirmação e revertem automaticamente se o jogador não confirmar.

---

# **ÁUDIO E ATMOSFERA**

O áudio implementado usa:

* vento ambiente em loop;
* passos do agente sobre grama;
* sons de dano e morte do jogador;
* disparos e recargas próprios de cada arma;
* vozes, corrida, ataque e morte dos infectados;
* rugido, ataques, passos, corrida e morte do chefe;
* música dedicada para a batalha final.

A atmosfera visual alterna iluminação diurna e noturna, com neblina, lua, nuvens, partículas, glow e tempestade no limite do mapa. A lanterna torna-se parte importante da leitura do cenário no estado noturno.

---

# **OTIMIZAÇÃO E ESTABILIDADE IMPLEMENTADAS**

O projeto usa soluções específicas para manter o mapa e a população ativos:

* pooling de infectados gerenciado pelo diretor;
* população limitada e reciclagem de inimigos distantes;
* limite e combinação de coletas de sucata;
* árvores internas agrupadas em MultiMesh;
* distância de visibilidade para florestas;
* referências e consultas físicas reutilizadas nos sistemas mais frequentes;
* atualizações de navegação e seleção de alvo em intervalos controlados;
* HUD e efeitos que suspendem processamento quando inativos;
* carregamento do mapa em segundo plano;
* presets gráficos completos;
* desativação, durante o carregamento, de colisões côncavas vazias ou inválidas;
* testes automatizados para combate, armas, projéteis, hitmarker, economia, pausa, HUD, animações, chefe, população, dificuldade, coleta, extração e multiplayer.

---

# **O QUE MUDOU EM RELAÇÃO AO PLANEJAMENTO INICIAL**

| Planejamento inicial | Estado concreto do jogo |
| :--- | :--- |
| Extração por pontos físicos periféricos e secundários | Extração voluntária pelo menu, com sobrevivência por 60 segundos, somente no solo |
| Contagem de extração de 90 segundos | Contagem atual de 60 segundos |
| Missões variáveis por run | Objetivo fixo de três Fragmentos, Fragmento 2 e chefe |
| Progressão rural, periurbana e centro urbano linear | Um único mapa aberto com exploração livre e zona industrial |
| Inventário limitado e mochila | Inventário de combate com seis slots fixos, munição, colete, kits, sucata e melhorias |
| Pistola e kit básico | C19, faca, 250 de sucata, reservas de munição e 1 kit médico |
| Terminais de sucata | Quatro bancadas de criação com interface completa |
| Acessórios Mira Aprimorada e Saque Rápido | Melhorias atuais: dano, recarga rápida, carregador estendido e Rapid Fire |
| Economia de 15 a 40 de sucata por zumbi | Drops atuais de 50, 75, 125 ou 250 |
| Inimigos humanos, animais e folclóricos | Infectado humano comum e um chefe de criatura grande |
| Três fases narrativas do Negrinho do Pastoreio | Chefe de fase única com introdução, quatro ataques e estado de fúria |
| Inventário por Tab | Tab exibe o placar da equipe |
| F1 e F2 para tratamento | H usa o kit médico; não existe sistema de sangramento |
| Ping tático em Q | Não implementado |
| Stealth baseado em ruído e estamina | Movimento, corrida e IA por percepção; sem estamina ou propagação de ruído |
| Briefing de rádio como primeira tela | Intro de logos, menu principal 3D e tela de carregamento |
| Campanha com escolhas e lore colecionável | Progressão de partida por fragmentos e chefe, sem campanha narrativa persistente |
| Coop planejado | Coop funcional por conexão direta/Radmin, com lobby, autoridade do host, revive e sincronização |

---

# **O QUE FALTOU DO PLANEJAMENTO INICIAL**

Esta seção registra tudo que estava previsto no primeiro GDD e ainda não existe no estado atual do jogo.

## **Estrutura de extração e progressão**

* Pontos físicos de extração no mapa.
* Extração automática ou orientada depois da vitória contra o chefe.
* Extração persistente compartilhada entre participantes do coop.
* Base jogável entre expedições.
* Tela de preparo e seleção de loadout antes da partida.
* Mochila com capacidade limitada e organização manual.
* Cofre ou inventário permanente fora da expedição.
* Progressão de campanha e prestígio.
* Perda completa e claramente apresentada do equipamento ao morrer.
* Missões variáveis por run.
* Escolha narrativa final entre destruir o dispositivo ou extrair os dados.
* Mapas futuros afetados pelas decisões da campanha.

## **Mundo e objetivos**

* Divisão completa entre zona rural, periurbana, vilarejo e centro urbano.
* Centro urbano colonial com prédio principal de missão.
* Acampamento da primeira expedição como objetivo narrativo.
* Dispositivo de monitoramento como segundo objetivo.
* Fonte da Ruptura e dispositivo final como terceiro objetivo.
* Portas travadas, passagens compráveis e rotas alternativas.
* Pontos de saque ambiental em pilhas de entulho.
* Terminais de comunicação e transmissões de missão.
* Objetos narrativos dentro de casas e locais de interesse.

## **Mecânicas do agente**

* Agachamento.
* Estamina.
* Ruído de corrida, tiros e detritos influenciando a detecção.
* Transposição automática de muros e cercas.
* Verificação física de munição ao segurar R.
* Descarte do carregador parcial ao recarregar.
* Sangramento e ação de estancar ferimentos.
* Inventário e mapa físico abertos por Tab.
* Ping tático em Q.
* Granadas.
* Kits especiais como visão noturna e gancho.
* Classes ou kit de Médico de Campo.
* Feedback contextual de tutorial nos primeiros minutos.

## **Armas, itens e economia**

* Rifle bolt-action.
* Sistema de acessórios físicos de mira e estabilizador de recuo como itens separados.
* Penetração de inimigos no nível máximo de dano.
* Mercadores Atravessadores com estoque limitado por run.
* Power-ups temporários planejados, como estabilizador neural, adrenalina e bloqueador de anomalia.
* Anomalias ambientais que causem dano e alterem rotas.
* Balanceamento final da economia e das bancadas.

## **Inimigos e chefe originalmente planejados**

* Traíras mutantes.
* Jaguatirica mutante.
* Saqueadores rivais humanos com cobertura e comportamento neutro ou hostil.
* Boitatá Corrompido como mini-chefe ambiental.
* Negrinho do Pastoreio com identidade visual definitiva.
* Três fases distintas do chefe: Tangível, Anomalia e Fusão.
* Invocação de Corrompidos pelo chefe como mecânica de fase.
* Campos de anomalia usados como ataques.
* Canhões de anomalia ativados por sucata na fase final.
* Recompensa narrativa do chefe com dados e amostra biológica.

## **Narrativa e conteúdo**

* Contato da SINAL e transmissões por rádio.
* Briefing de missão falado.
* Fitas de rádio, cadernetas e fotografias colecionáveis.
* Enciclopédia de criaturas e eventos.
* Narrativa ambiental dirigida em cada zona.
* Explicação completa da Ruptura dentro do jogo.
* Desfecho narrativo e escolhas de campanha.
* Trilha baseada em instrumentos gaúchos processados eletronicamente.
* Identidade folclórica definitiva para inimigos e anomalias.

## **Multiplayer e serviços**

* Matchmaking público.
* Convites por plataforma.
* Reconexão em partida.
* Migração de host.
* Persistência de inventário em coop.
* Retorno automático de toda a equipe ao lobby depois da vitória ou extração.
* Ping de comunicação tática.
* Sistema específico de classes e funções cooperativas.

## **Produção e acabamento**

* Mais mapas selecionáveis.
* Polimento visual final de todas as zonas.
* Otimização e validação completa em hardware-alvo variado.
* Balanceamento final de armas, economia, população, dificuldade e chefe.
* Revisão final de acessibilidade e remapeamento de controles.
* Salvamento permanente versionado além da extração de uma única run.
* Tutorial, onboarding e comunicação clara de todos os objetivos.
* Localização e revisão final de todos os textos da interface.

---

***Documento final de referência do estado implementado, atualizado em 14 de julho de 2026.***

***O arquivo original permanece preservado como registro do planejamento inicial.***
