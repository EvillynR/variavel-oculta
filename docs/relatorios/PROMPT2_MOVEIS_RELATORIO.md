# Prompt 2 — Cenografia, móveis e furtividade

Base: o `VO_Prompt1.zip` entregue no Prompt 1. Ele foi preservado sem alterações, com cópia de backup.
O visual dos personagens não foi alterado: as cápsulas provisórias continuam as mesmas.

## Como os testes foram executados

- Motor: Godot 4.7.1 headless.
- Todas as suítes rodam com `--fixed-fps 60`.
- O placar completo está em `docs/capturas/prompt2/placar_testes.txt`.

| Suíte | Prompt 1 | Prompt 2 |
|---|---|---|
| game_data_test | 106/106 | **142/142** |
| narrative_data_test | 40/40 | 40/40 |
| puzzle_system_test | 49/49 | 49/49 |
| interaction_prompt_test | 24/24 | 24/24 |
| room_progress_test | 37/37 | 37/37 |
| player_monster_collision_test | 48/48 | 48/48 |
| player_wall_movement_test | 21/21 | 21/21 |
| camera_behavior_test | 10/10 | 10/10 |
| camera_occlusion_test | sem bloqueios | **sem bloqueios** (2 áreas a mais cobertas) |
| camera_geometry_sweep_test | sem problemas | **sem problemas** |
| camera_solid_collision_test | 59/63 | 59/63 |
| etapa45_navigation_test | 159/164 | 159/164 |
| six_rooms_test | 70/72 | 70/72 |
| monster_pilot_test | 31/33 | 31/33 |
| monster_hearing_test | 60/63 | 60/63 |
| door_test | 40/40 | 40/40 |
| **percurso_completo_test** | 21/21 | **21/21** |
| floor_sweep_test | 13/13 | 13/13 |
| **esconderijo_test (novo)** | — | **16/16** |
| **ruido_test (novo)** | — | **9/9** |

## Validado em execução

### Biblioteca de móveis (`scenes/props/`, 17 cenas)

- Os móveis são feitos de primitivas CSG, com colisão.
- **Peças:** carteira com cadeira, cadeira solta, mesa do professor, quadro-negro, armário alto, estante, cavalete, mapa-múndi, globo, piano, estante de partitura, bancada de laboratório, quadro de avisos, lixeira, armários de alunos, mesa de cartas e entulho.
- **Materiais:** seis novos em `assets/materials/prop_*.tres` (madeira escura com a textura existente, metal, lousa, papel, tecido e mapa).
- **Geração:** os arquivos saem de `tools/prompt2_gerar_moveis.py`.

### Salas mobiliadas (111 móveis)

A instalação é feita por `tools/prompt2_mobiliar.py`, que é reexecutável e parte da cena do Prompt 1.

- **Sala inicial:** 5 carteiras, incluindo a carteira onde ela acorda, quadro-negro e lixeira.
- **Ciências:**
  - 3 bancadas de laboratório e quadro-negro;
  - os interativos que já existiam foram preservados (experimento, caderno, tabela e armário);
  - esconderijos: armário alto e mesa do professor.
- **Matemática:** 24 carteiras em fileiras, formando corredores de 2 m e ângulos mortos. O corredor central de 6 m é o posto do Ângulo.
- **Artes:**
  - 6 cavaletes e uma mesa de trabalho;
  - a parede oeste ficou livre para as pinturas do Prompt 5.
- **Português:** 8 estantes, formando corredores a oeste e a leste.
- **Geografia:** 2 mapas-múndi, globo, mesa de cartas e estante.
- **Música:** piano, 5 cadeiras e 5 estantes de partitura em semicírculo, e uma estante de partituras.
- **Corredores:** 15 conjuntos de armários de alunos, 5 quadros de aviso, entulho e uma cadeira tombada.
- **Cada sala de aula** tem armário alto e mesa do professor como esconderijos (12 no total).

### Garantias

- **Nada trava o caminho:** o percurso completo continua passando sem ficar preso (21/21), atravessando as 9 portas e as 7 salas.
- **Sem becos nas paredes:** o teste de deslizar nas paredes passa (21/21).
- **Navmeshes:** foram reassados com os móveis (`tools/bake_all_navmesh.gd -- --force`).
- **Monstros contornam a mobília:**
  - não há rota entre salas para o monstro;
  - 60 pontos navegáveis por sala estão sem móvel no corpo (`six_rooms`);
  - o monstro alcança pontos atrás de carteiras e do armário (`etapa45`).

### Esconderijos (`scripts/world/hiding_spot.gd`)

- **Entrada e saída:**
  - a tecla E esconde a protagonista, pelo PlayerInteractor e pelo InteractionRouter que já existiam;
  - E de novo a faz sair pela frente do móvel.
- **Enquanto escondida:**
  - fica sem colisão, sem se mover e com o modelo oculto dentro do móvel (o modelo não foi alterado);
  - a câmera enquadra a frente do esconderijo;
  - aparece uma vinheta com "ESCONDIDA — E para sair" e um rótulo sobre o móvel.
- **Visão dos monstros:**
  - ao entrar, os monstros ativos que estão vendo a protagonista viram **testemunhas**;
  - para os outros, `MonsterPerception.can_see` retorna falso;
  - testemunhas perseguem até a frente do móvel e capturam.

Resultados do `esconderijo_test` (16/16):
- **Não viu entrar:** o Polvo em CHASING perde a protagonista, sai de CHASING e não captura em 12 s.
- **À vista, mas já escondida:** o Polvo a 4 m, olhando para a mesa, não a enxerga.
- **Viu entrar:** ele vira testemunha, chega ao esconderijo e captura.

### Ruído (`player_noise` no JSON)

- Os passos viram `SoundStimulus`, entregues pelo sistema de audição que já existia.
- **Intensidades:** correr = 1,0, andar = 0,55 e agachada = 0,15.
- O intervalo entre passos é contado em tempo de jogo.
- O carregador do JSON valida a seção.

Resultados do `ruido_test` (9/9), sempre fora do cone de visão do Polvo:
- correndo a 3,6–5,9 m, ele **investiga**;
- agachada na mesma distância, **não investiga** (OUT_OF_RANGE);
- andando na mesma distância, também não investiga;
- andando a ~2 m, investiga;
- parada, ela não faz barulho.

### Câmera com móveis (`camera_controller.gd`)

- Móveis do grupo `camera_fade` que ficam entre a lente e a protagonista ficam **translúcidos na hora** e voltam ao normal devagar.
- Os móveis não empurram mais a lente. Antes, as estantes provocavam cortes e saltos.
- A colisão física dos móveis continua valendo para a protagonista e os monstros.
- A oclusão ficou sem bloqueios, e a varredura de geometria da câmera, sem problemas.

## Testes atualizados (com justificativa)

Todas as mudanças estão comentadas com "Prompt 2" no código.

- **`camera_occlusion_test`, `camera_solid_collision_test` e `camera_geometry_sweep_test`:**
  - um móvel entre a lente e a protagonista só é aceito se a câmera **de fato** o deixou translúcido (`transparency ≥ 0,5`); paredes continuam proibidas;
  - o teste de oclusão mede até a posição **real** da protagonista, porque um ponto da grade pode cair dentro de um móvel e a física a empurra para fora;
  - o teste de oclusão ganhou as áreas Música e Corredor 5;
  - o teste de colisão da câmera ignora peças-filhas de um `CSGCombiner3D`, como a própria câmera já fazia: elas não são geometria separada.
- **`game_data_test`:** a Room 1 agora tem 7 objetos funcionais, porque ganhou os 2 esconderijos.
- **`six_rooms_test`:** a escola ganhou o nó `Props`.

## Parcial

- **Cortes de câmera:** são os mesmos 4 itens do Prompt 1 no `camera_solid_collision_test` (3 cortes onde se aceitam 2, e um salto de 0,36–0,42 m na Artes durante a perseguição da Pintora). O mesmo vale para os 3 itens de "2 cortes" no `etapa45`.
- **Iluminação:** os spots só iluminam o centro das salas, e os móveis nas bordas ficam quase pretos nas capturas de jogo. As vistas de planta (`docs/capturas/prompt2/p*.jpg`) usam uma luz extra só para documentar o layout. O ajuste de luz fica para o polimento do Prompt 5.
- **Professor da Room 1:** o bloco provisório que já existia foi mantido. A mesa-esconderijo da sala é outra mesa, perto da parede sul.
- **Estado de esconderijo:** não é salvo. Entra no sistema de save do Prompt 3.

## Pendente (já existia antes; fora do escopo do Prompt 2)

- **Despertar por entrada de sala:** os monstros despertam ao entrar na sala, o que explica 2 falhas no `six_rooms` e fica para o Prompt 5.
- **Pausa do Game Over:** congela a busca do Polvo no `monster_pilot` e no `etapa45`. Fica para o Prompt 3.
- **Audição:** 3 verificações do `monster_hearing` falham com `--fixed-fps`. Esse teste usa tempo real (`Time.get_ticks_msec`) para os intervalos.

## Capturas

- `docs/capturas/prompt2/00_antes_depois.jpg`: as mesmas câmeras do Prompt 1, antes e depois.
- `docs/capturas/prompt2/00_plantas.jpg`: vistas de cima de cada sala.
- As imagens individuais estão na mesma pasta.

## Arquivos

**Novos**
- `scenes/props/*.tscn` (17 cenas)
- `assets/materials/prop_*.tres` (6)
- `scripts/world/hiding_spot.gd`
- `tests/esconderijo_test.gd` e `tests/ruido_test.gd`
- `tools/prompt2_*.py`
- `docs/capturas/prompt2/`

**Alterados**
- `scenes/main.tscn`, `data/game_data.json` (12 esconderijos e `player_noise`) e os navmeshes.
- `player.gd`, `monster_perception.gd`, `monster_controller.gd`, `camera_controller.gd`, `interaction_router.gd` e `game_data.gd`.
- 4 testes antigos foram atualizados.
