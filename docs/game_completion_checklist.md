# Roadmap e Checklist de Conclusão: Outbreak Protocol - Pampa

Este documento detalha todos os sistemas, mecânicas, assets e conteúdos necessários para que o jogo **Outbreak Protocol: Pampa** atinja sua versão final (1.0), com base no Game Design Document (GDD).

---

## 1. Sistemas Core e Mecânicas do Jogador (O Agente)
- [ ] **Movimentação Tática:** Andar, correr (gasta stamina, faz barulho), agachar (silencioso) e transpor obstáculos (pular muros/cercas).
- [ ] **Sistema de Combate e Armas:**
  - [ ] Balística, dispersão, recuo real e mira (ADS).
  - [ ] Tipos de armas: Pistolas, Escopetas, Rifles de ferrolho (bolt-action), Rifles automáticos e Armas brancas.
  - [ ] Gerenciamento de munição (recarga descarta munição parcial, checagem física do carregador).
- [ ] **Saúde e Sobrevivência:**
  - [ ] Sistema de estamina.
  - [ ] Sangramento (cura lenta, interrompida por fogo) e uso de kits médicos.
- [ ] **Inventário e Interface:**
  - [ ] Inventário físico limitado (pausa o movimento/vulnerabilidade ao abrir).
  - [ ] HUD minimalista (barra de vida, balas no pente, contador de sucata).
  - [ ] Mapa físico utilizável in-game.
- [ ] **Stealth e Detecção:**
  - [ ] Geração de ruído do jogador baseada na velocidade e terreno.
  - [ ] Detecção de inimigos baseada em visão e audição (pisar em detritos).
- [ ] **Multiplayer Co-op (1 a 4 jogadores):**
  - [ ] Sincronização de rede (movimento, inimigos, loot).
  - [ ] Sistema de ping/comunicação (Sinalizar tático).
  - [ ] Mecânica de reanimação/reviver (Kit de Médico de Campo a ser detalhado).

## 2. Economia e Progressão (Durante a Incursão)
- [ ] **Sistema de Sucata:**
  - [ ] Drops de inimigos (15-40 comuns, 80-200 pesados) e pontos de coleta no mapa.
- [ ] **Terminais de Melhoria e Passagens:**
  - [ ] Terminais de sucata básicos e completos espalhados pelas zonas.
  - [ ] Portões/passagens bloqueadas que custam sucata (100 a 300).
  - [ ] Sistema de Upgrade de Armas:
    - [ ] Mira Aprimorada, Saque Rápido, Estabilizador de Recuo.
    - [ ] Dano (Nível I, II e III com penetração de inimigos).
    - [ ] Carregador Estendido, Recarga Rápida.
- [ ] **Power-ups Temporários e Comércio:**
  - [ ] Itens consumíveis: Estabilizador neural, Adrenalina de campo, Bloqueador de anomalia.
  - [ ] Mercadores (Atravessadores) em pontos fixos com estoque limitado (compartilhado no co-op).

## 3. Design de Nível e Mapa (Pampa Corrompido)
- [ ] **Zona 1: Perímetro / Zona Rural:**
  - [ ] Campos abertos, eucaliptais, cercas, nevoeiro baixo.
- [ ] **Zona 2: Estância Abandonada:**
  - [ ] Casarão em ruínas, galpões, silos. Terminal inicial.
- [ ] **Zona 3: Estrada Rural (Passagem):**
  - [ ] Linhas de visão abertas, extração periférica 1.
- [ ] **Zona 4: Vilarejo do Interior:**
  - [ ] Casas, praça, armazém, barricadas. Terminal completo.
- [ ] **Zona 5: Zona Industrial / Subúrbio:**
  - [ ] Galpões, ruas destruídas, anomalias frequentes. Extração secundária 2.
- [ ] **Zona 6: Centro Urbano (Área do Boss):**
  - [ ] Arquitetura colonial deteriorada, geometria distorcida por anomalias.
- [ ] **Elementos Ambientais Ambientais:**
  - [ ] Campos de anomalia que causam dano/distorção.
  - [ ] Áreas alagadas (arroios).

## 4. Inimigos e Inteligência Artificial
- [ ] **Inimigos Comuns:**
  - [ ] *Corrompidos:* Ex-humanos, comportamento de horda, atração por som.
  - [ ] *Traíras Mutantes:* Ficam em áreas alagadas, sentem vibração, muito rápidas na água.
  - [ ] *Jaguatirica Mutante:* Camuflada, caça furtiva, ataca pelas costas/flancos.
- [ ] **Inimigos Especiais e NPCs:**
  - [ ] *Saqueadores Rivais:* IA com uso de cobertura, táticas de flanco, resgate de aliados.
  - [ ] *Boitatá Corrompido (Mini-Boss):* Combate ambiental, cega o jogador, imune a armas comuns inicialmente.
- [ ] **Boss Final (O Negrinho do Pastoreio):**
  - [ ] *Fase 1 (Tangível):* Invoca Corrompidos, vulnerável no peito.
  - [ ] *Fase 2 (Anomalia):* Forma de névoa, usa ataques em área (campos de anomalia).
  - [ ] *Fase 3 (Fusão):* Forma gigante e rápida, combate direto, uso de canhões de anomalia no cenário.

## 5. Loop de Jogo e Narrativa
- [ ] **Loop de Incursão:**
  - [ ] Loadout/Preparação -> Infiltração -> Coleta -> Decisão Crítica (Extrair ou Avançar) -> Extração (evento de 90 segundos de sobrevivência) ou Morte (perda de loot).
- [ ] **Sistema de Narrativa:**
  - [ ] *Rádio:* Transmissões da SINAL (início, fim e via terminais).
  - [ ] *Storytelling Ambiental:* Rastros, barricadas, acampamentos de expedição.
  - [ ] *Coletáveis:* Fitas, cadernetas e fotos que geram entradas na enciclopédia/lore.
- [ ] **Objetivos de Campanha (Missões In-Game):**
  - [ ] 1. Encontrar acampamento da Primeira Expedição.
  - [ ] 2. Recuperar Dispositivo de Monitoramento.
  - [ ] 3. Alcançar a Fonte e derrotar o Boss.
  - [ ] 4. Decisão final (destruir dispositivo ou extrair os dados).

## 6. Audiovisual e Atmosfera
- [ ] **Arte e Gráficos:**
  - [ ] Iluminação de "Pampa": luz do fim de tarde, névoa.
  - [ ] Design de criaturas unindo realismo orgânico com folclore.
  - [ ] Efeitos visuais de anomalias e radiação.
- [ ] **Áudio:**
  - [ ] Trilha sonora reativa (instrumentos gaúchos processados eletronicamente).
  - [ ] Som dinâmico de tensão quando detectado (saturação de frequência em vez de música heroica).
  - [ ] Uso do silêncio absoluto para indicar perigo.

## 7. Questões Abertas a Decidir / Refinar (Pendente de Game Design)
- [ ] Definir o "Sistema de Prestígio" ou loop de endgame após o fim da campanha.
- [ ] Realizar o balanceamento final da economia de sucata (valores finais para coleta e custos em cada área).
- [ ] Documentar e implementar especificamente o kit do Médico de Campo para o modo Co-op.
- [ ] Mapear o número exato e localização dos terminais de melhoria pelo mapa.
- [ ] Decidir a abordagem de Dificuldade (única e punitiva vs. ajustável).
- [ ] Definir regras precisas de spawn para os Saqueadores Rivais.
