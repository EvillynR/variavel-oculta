# Prioridade 1 — Correção da jogabilidade 2.5D

Projeto Godot 4.7.2 (Forward+, física Jolt). Este documento registra o estado do jogo, as causas
medidas de cada problema, o que foi alterado, como foi validado e o que ainda falta. Todos os números
abaixo vêm de execuções reais no Godot 4.7.2 (testes headless e capturas renderizadas em Vulkan).

## 1. O que existe no jogo

O jogo é um terror 2.5D ambientado numa escola. O mapa é uma faixa: a sala inicial, quatro corredores
ligados por portas e as salas narrativas a oeste dos corredores.

| Sala narrativa | Matéria | Monstro | Nó na cena | Situação |
|---|---|---|---|---|
| room_1 | Ciências | O Polvo | `School/Room 1` | Jogável (enigmas de teste) |
| room_2 | Matemática | O Ângulo | `School/Room 2` | Geometria pronta, conteúdo pendente |
| room_3 | Artes | A Pintora | `School/Exit` | Geometria pronta, conteúdo pendente |
| room_4 | Português/Literatura | O Leitor | `School/Room 3` | Geometria pronta, conteúdo pendente |
| room_5 | Geografia | O Cartógrafo | `School/Room 4` | Geometria pronta, conteúdo pendente |
| room_6 | Música | O Maestro | — | Só em dados (ponto de integração) |

Sistemas já existentes antes desta etapa (preservados): interação contextual pela tecla E
(`PlayerInteractor`, `Interactable`, `InteractionRouter`); enigmas e pistas (`PuzzleManager`,
`ClueManager`, banco de dados em `data/`); progresso das salas com estados (bloqueada → disponível →
ativa → monstro desperto → resolvida → concluída); gerenciador narrativo orientado a eventos; o Polvo
com navegação, visão e audição; zonas de câmera por cômodo. A protagonista ainda é uma cápsula
provisória (modelo preservado).

## 2. Controles

| Tecla | Ação | Estado |
|---|---|---|
| W A S D | Andar (relativo à câmera) | Funcional |
| Shift | Correr | Funcional |
| Ctrl | Agachar | Funcional (agora só levanta se houver espaço acima) |
| E | Interação contextual | Funcional (inalterada) |
| ← → | Girar a câmera em volta da protagonista | **Novo** |
| ↑ ↓ | Subir/descer a câmera | **Novo** |
| Espaço (`Jump`) | Pular | Mapeada, **sem comportamento implementado** |
| Esc (`pause`) | Pausa | Mapeada, **sem comportamento implementado** |
| — | Esconder-se, subir/atravessar obstáculos | **Não existem** |

As setas eram teclas livres no mapa de entrada; não há conflito com nenhuma ação existente (verificado
por teste). Enquanto uma tecla de movimento fica pressionada, a direção de controle fica travada, mesmo
que a câmera mude de composição ou faça um corte; ao soltar, ela se realinha com a câmera. O giro feito
pelo jogador com as setas vale imediatamente. A protagonista agora publica seu estado de movimento
(`move_state`: parada, andando, correndo, agachada; sinal `move_state_changed`) para integrar sons,
animações e futuras ações.

## 3. Problemas encontrados e causas medidas

### 3.1 Protagonista quase preta
Todas as luzes do cenário são SpotLights no teto apontadas para baixo. O chão e o topo dos móveis
recebem luz direta, mas o lado da protagonista que a câmera vê tem normal horizontal (N·L ≈ 0) e recebe
só o ambiente azul escuro. Teste de diagnóstico (`tests/protagonist_lighting_diag.gd`): desligar as
sombras não mudou a luminância medida, portanto sombras não eram a causa. Luminância da protagonista
medida na Room 1: 0,000 a 0,142 (ela estava no quadro, mas totalmente preta).

### 3.2 Modelo flutuando
`player.gd` centralizava a cápsula de 1,1 m a 0,9 m de altura (como se tivesse 1,8 m): o modelo
flutuava 0,35 m acima dos pés e era menor que a colisão.

### 3.3 Protagonista presa nas paredes
O `CharacterBody3D` não desliza quando o movimento chega a menos de 15° da normal da superfície
(`wall_min_slide_angle`). Nos batentes das portas, encostando quase de frente, ela parava. Medido na
versão original: 99 e 150 quadros parada nos batentes.

### 3.4 Câmera atravessando o cenário
A câmera antiga ficava propositalmente fora das salas, atrás de paredes escondidas ("corte de
maquete") e de paredes invisíveis. No tour de 20 cenários, a lente estava fora do prédio ou atrás de
paredes em 7 deles. Não havia controle pelas setas.

## 4. O que foi feito

### 4.1 Iluminação (`scripts/protagonist_light_rig.gd`, novo)
Conjunto de luzes preso à protagonista. Uma luz de preenchimento quente vinda do lado da câmera e uma
contraluz fria por trás afetam **somente a camada visual 11**, onde a protagonista foi colocada (ela
continua também na camada 1 e recebe a luz original). Um halo fraco de curto alcance (3,6 m, com sombra
e sem brilho especular) ilumina só o chão e os objetos imediatamente em volta. As luzes originais, o
ambiente e a exposição não foram alterados; as propostas P1/P2 não foram aplicadas.

### 4.2 Protagonista (`scripts/player.gd`)
- O modelo acompanha a altura da colisão (1,8 m em pé, 1,1 m agachada) com a base no chão.
- Deslizamento assistido: contra o cenário estático, quando o input empurra contra a parede num ângulo
  pequeno, garante 55% da velocidade ao longo da superfície (continua sem atravessar). Contra
  personagens (o Polvo) o comportamento original foi mantido: ela é bloqueada de frente.
- Ao soltar o agachamento, só levanta se a cápsula em pé couber.
- Referencial de controle estável (descrito na seção 2).

### 4.3 Câmera (`scripts/camera_controller.gd`, reescrito com a API pública preservada)
- **Órbita:** o enquadramento de cada zona é tratado como desvio horizontal, elevação e distância em
  volta da protagonista; as setas somam um desvio limitado (±80° horizontal, 8° a 68° de elevação). A
  rotação só avança se ainda houver pelo menos 2,2 m livres naquela direção.
- **Colisão obrigatória:** a lente é uma esfera lançada do peito da protagonista. Toda geometria sólida
  bloqueia: paredes visíveis, invisíveis e do corte de maquete, chão, teto e móveis, além das peças
  visíveis sem colisão (vergas das portas). A aproximação é imediata (nunca atravessa); o afastamento
  é suave. Uma verificação final garante folga mínima de 0,28 m entre a lente e qualquer superfície.
- **Contenção:** a lente fica dentro do cômodo da protagonista (zona de câmera que a contém) e sob o
  teto. Sem isso ela escapava pela fresta entre o topo das paredes invisíveis e o teto.
- **Composições alternativas:** quando a direção pedida não tem espaço, a câmera escolhe entre 13
  composições seguras (mais alta e/ou girada), com histerese: 1,5 s mínimo em cada composição, vantagem
  exigida para trocar e vantagem maior para trocar de lado; prefere ficar atrás do movimento.
- **Cortes limpos:** se o caminho até a protagonista for bloqueado de repente (por exemplo, ao virar a
  esquina de uma porta), a câmera corta direto para uma composição segura já enquadrada, em vez de dar um
  tranco parcial.
- **Enquadramento:** o foco desce em direção ao corpo quando necessário para pés e cabeça caberem no
  quadro; quando a câmera precisa ficar mais perto, o FOV abre (até 60°).
- **Limites das zonas:** passaram a valer para o trilho que a câmera segue, não para a lente.
- **Corte de maquete:** só esconde uma peça da zona se ela realmente estiver entre a lente e a
  protagonista (na prática, quase nunca, porque a lente não fica mais atrás de paredes).

### 4.4 Mapa de entrada (`project.godot`)
Quatro ações novas nas setas: `camera_rotate_left`, `camera_rotate_right`, `camera_rotate_up` e
`camera_rotate_down`. Nenhuma ação existente foi alterada.

### 4.5 Cena (`scenes/main.tscn`)
Só acréscimos: o recurso do script e o nó `Player/ProtagonistLightRig`. `collision_mask = 5` da
protagonista preservado. Nenhuma parede, colisão, sala, enigma ou dado narrativo foi alterado.
`build_monster_assets.gd` não foi usado.

## 5. Validação

### 5.1 Testes automatizados (Godot 4.7.2, headless, resultados finais)

| Teste | Antes | Depois |
|---|---|---|
| `player_wall_movement_test` (novo: paredes, portas, móveis, modelo) | 17/21 | **21/21** |
| `camera_solid_collision_test` (novo: colisão rigorosa, setas, percursos) | — | 59/63 |
| `player_monster_collision_test` | 48/48 | 48/48 |
| `interaction_prompt_test` | 24/24 | 24/24 |
| `puzzle_system_test` | 49/49 | 49/49 |
| `narrative_data_test` | 40/40 | 40/40 |
| `room_progress_test` | 37/37 | 37/37 |
| `monster_pilot_test` | 33/33 | 33/33 |
| `monster_hearing_test` | 63/63 | 63/63 |
| `six_rooms_test` | 68/68 | 68/68 |
| `camera_occlusion_test` | sem bloqueios | sem bloqueios |
| `camera_geometry_sweep_test` | sem problemas | sem problemas |
| `camera_behavior_test` | 10/10 | 9/10 |
| `etapa45_navigation_test` | 149/149 | 161/164 |

No teste rigoroso da câmera, a varredura de todas as 11 áreas (com tensão de perseguição 0 e 1) deu
zero casos de lente dentro de geometria, zero lente rente a superfícies, zero oclusão da protagonista e
zero protagonista fora do quadro. As setas giram e sobem a câmera sem atravessar nada, inclusive
seguradas em cantos e junto a paredes.

Os testes `camera_behavior_test` e `etapa45_navigation_test` ganharam verificações a mais (cortes
contados à parte), por isso o total passou de 149 para 164.

### 5.2 Testes antigos atualizados (e por quê)
Algumas verificações antigas exigiam literalmente o comportamento que o novo requisito proíbe ("a
parede invisível **não** puxa a câmera", "parede do corredor escondida", "yaw da câmera travado em 10°").
Elas foram substituídas pela verificação equivalente do requisito novo (lente dentro do cômodo, parede
visível, referencial de controle estável). Testes que andavam apertando uma única tecla, supondo câmera
lateral fixa, passaram a usar `tests/test_input.gd`, que converte a direção do mundo no referencial real
de controle. Arquivos: `camera_behavior_test.gd`, `etapa45_navigation_test.gd`,
`player_monster_collision_test.gd`, `room_progress_test.gd` e `monster_pilot_test.gd`.

### 5.3 Verificação visual (capturas reais, Vulkan, 1280×720)
Luminância da protagonista na Room 1 (escala 0–1): antes 0,000–0,142, depois 0,213–0,315. Luminância
média da cena: antes 0,010–0,042, depois 0,008–0,054 (a cena continua escura; 57% a 95% dos pixels
quase pretos). Imagens em `docs/capturas/`: `comparativo_iluminacao_room1.png` (8 cenários de luz) e
`comparativo_salas_e_corredores.png` (sala inicial, corredores, salas 1 a 4 e área de Artes). Métricas
em `metricas_luz_antes.csv` e `metricas_luz_depois.csv`.

Não houve teste com jogador humano: a sensação de controle e de câmera em tempo real precisa ser
conferida jogando no editor.

## 6. Limitações restantes
- Em algumas trajetórias pelas portas estreitas (sala inicial → corredor, corredor 1 → corredor 2 →
  Room 2) há 2 ou 3 cortes em vez de 1 e passos de câmera de até 0,52 m em um quadro. Na perseguição
  dentro da Room 1, quando a protagonista corre contra a parede onde a câmera está, ocorrem 2 a 3 cortes.
  São as 8 verificações que ainda falham (4 do teste rigoroso, 1 do `camera_behavior_test`, 3 do
  `etapa45_navigation_test`).
- Longe das luzes do teto, o chão em volta da protagonista é pouco legível; melhorar isso exige mexer nas
  luzes das salas (propostas P1/P2, não aplicadas sem autorização).
- A câmera agora fica dentro de cada cômodo e corta ao entrar numa sala: o visual mudou em relação à vista
  "de fora" da versão anterior. No corredor, W não leva mais direto à porta da sala; a direção é a da tela.
- Os vãos de porta na parede oeste da área de Artes (nó `Exit`) dão para o vazio, sem chão; não foram
  alterados (cenário).
- Pular, pausar, esconder-se e escalar não estão implementados.

## 7. Arquivos
Alterados: `scripts/camera_controller.gd`, `scripts/player.gd`, `project.godot`, `scenes/main.tscn`.
Novos: `scripts/protagonist_light_rig.gd`, `tests/player_wall_movement_test.gd`,
`tests/camera_solid_collision_test.gd`, `tests/protagonist_lighting_diag.gd`, `tests/test_input.gd`,
`docs/capturas/*`, este documento. Testes atualizados: listados em 5.2.

Como rodar: `godot --headless -s tests/<teste>.gd` (o teste rigoroso da câmera e o de paredes com
`--fixed-fps 60`). Capturas: `xvfb-run godot --path . --rendering-driver vulkan --fixed-fps 60 --script
res://tests/lighting_compare_capture.gd -- --out=<pasta> --variant=original`.
