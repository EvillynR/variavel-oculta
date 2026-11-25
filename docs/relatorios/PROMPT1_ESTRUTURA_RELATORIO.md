# Prompt 1 — Estrutura física, portas, luz e câmera

Base: `Jogo3D_Ajustes_Testes_Sala3_Camera.zip`, preservado sem alterações e com backup separado.
O visual dos personagens não foi alterado: as cápsulas provisórias continuam iguais.

## Como os testes foram executados

- Motor: Godot 4.7.1 headless.
- Todas as suítes rodam com `--fixed-fps 60`. Sem essa opção, os testes de percurso mudam de resultado conforme a velocidade da máquina.
- Exemplo: `godot --headless --fixed-fps 60 --path . --script res://tests/<teste>.gd`
- O placar completo está em `docs/capturas/prompt1/placar_testes.txt`.

| Suíte | Antes (mesmo modo) | Depois |
|---|---|---|
| game_data_test | 67/71 | **106/106** |
| narrative_data_test | 40/40 | 40/40 |
| puzzle_system_test | 49/49 | 49/49 |
| interaction_prompt_test | 24/24 | 24/24 |
| room_progress_test | 35/37 | **37/37** |
| six_rooms_test | 53/67 | 70/72 |
| player_monster_collision_test | 48/48 | 48/48 |
| player_wall_movement_test | 20/21 | **21/21** |
| camera_behavior_test | 9/10 | **10/10** |
| camera_occlusion_test | sem bloqueios | sem bloqueios |
| camera_geometry_sweep_test | sem problemas | sem problemas |
| camera_solid_collision_test | 57/63 | 59/63 |
| etapa45_navigation_test | 158/164 | 159/164 |
| monster_pilot_test | 31/33 | 31/33 |
| monster_hearing_test | 60/63 | 60/63 |
| **door_test (novo)** | — | **40/40** |
| **percurso_completo_test (novo)** | — | **21/21** |
| **floor_sweep_test (novo)** | — | **13/13** |

## Validado em execução

### Percurso completo (`percurso_completo_test`)

- A protagonista é conduzida só pelas ações do Input Map.
- Ela sai da sala inicial, abre 9 portas com a tecla E e entra nas 6 salas, registradas pelo RoomProgressManager.
- Depois desce a rampa e chega à Sala de Monitoramento, no piso y −6.
- Ela não fica presa e não cai em nenhum ponto.

### Varredura de piso (`floor_sweep_test`)

- Cerca de 16.000 pontos testados, a cada 0,5 m.
- Todas as áreas caminháveis, 14 soleiras e passagens, e a rampa.
- Nenhum buraco e nenhum ponto apoiado só no FallSafety.

### Sala 3 (nó `Room 3`, room_4, Português)

- As 5 peças `WallEast*` eram duplicadas e fechavam o vão. Foram removidas.
- O vão real, em z −94…−97, já tinha a abertura no Corridor3.
- `player_wall_movement_test` e `door_test` confirmam a passagem.

### Artes (nó `Exit`)

- A sala não tinha parede leste. Ganhou a parede, com porta em z −72,5…−69,5.
- Os dois vãos da parede oeste davam para o vazio. Foram fechados.
- O trecho de corredor z −52,5…−90 recebeu a barreira leste invisível que existia em todos os outros corredores.

### Corredor 5 e Música

- Passagem aberta no fim do Corredor 4.
- Corredor 5 com piso, teto, paredes e 4 luzes, em x −3,5…3,5 e z −138…−190.
- Paredes da Música refeitas no padrão da escola, com rodapé de madeira, friso e reboco.
- O vão sul da Música dava para o vazio e foi fechado.
- A Música ganhou porta leste em z −176,5…−173,5 e 2 luzes. Antes, ela não tinha nenhuma luz.

### Subsolo e Sala de Monitoramento

- Porta trancada no fim do Corredor 5.
- Rampa de 18,4° descendo de y 0 até y −6.
- Corredor subterrâneo com 2 luzes.
- Sala de Monitoramento em x −17,5…−3,5, z −226…−212, com:
  - 6 monitores emissivos;
  - mesa, console e cadeira, todos com colisão;
  - luz azulada;
  - volume de sala, navmesh e câmera.

### Portas (`scenes/world/door.tscn` + `scripts/world/door.gd`)

- **Peças:** batente (só visual), bandeira, folha dupla com colisão e puxador.
- **Estados:** FECHADA, ABERTA e TRANCADA.
- **Interação:**
  - a tecla E funciona pelo PlayerInteractor e pelo InteractionRouter existentes;
  - o texto muda entre "E  Abrir", "E  Fechar" e "Trancada";
  - tentar abrir uma porta trancada mostra a mensagem "Trancada.".
- A porta não fecha se houver alguém no vão.
- A linha de visada da tecla E ignora as folhas da própria porta.
- 9 portas instaladas: sala inicial, as 6 salas, acesso ao subsolo e Sala de Monitoramento.
- **Navegação:** cada porta tem um `NavigationLink3D` que só fica ativo com a porta aberta. Fechada, a folha entra no bake como obstáculo. Teste: sem rota com a porta fechada; com rota com a porta aberta.

### Tranca (dados no JSON, campo `door` do objeto)

- `room_available`:
  - a porta fica trancada enquanto a sala estiver LOCKED;
  - a room_2 só abre quando a room_1 é concluída, e isso foi testado.
- `manual`:
  - só abre com o efeito novo `{"type": "unlock_door", "door_id": ...}`, também testado;
  - é usado no acesso ao subsolo, que começa inacessível.
- `none`: a porta nunca tranca. Vale para a sala inicial e para a Sala de Monitoramento.
- O carregador do JSON valida o campo `door` e o efeito `unlock_door`, com mensagens de erro legíveis (testadas).

### Dados

- `room_6.navigation_layer` corrigido de 32 para 6. O banco agora carrega sem erros, só com os avisos de "sala pendente".
- Criados dois locais narrativos (`STORY_AREA`): `sala_inicial` e `sala_monitoramento`.
- `final_destination_id` = `sala_monitoramento`.

### Volumes de sala

- Encolhidos para x ≤ −4,1.
- Encostada numa porta fechada pelo lado do corredor, a protagonista não registra entrada em nenhuma das 7 salas (testado).

### Navmeshes

- Nova ferramenta: `tools/bake_all_navmesh.gd -- --force`.
- Assa as 6 salas, os corredores (camada 7), a sala inicial (camada 7) e o subsolo com o Monitoramento (camada 8).
- Usa só colisores estáticos. Antes, a malha visual do boneco do professor virava obstáculo.
- Inclui o armário da Room 1.

### Câmera (`scripts/camera_controller.gd`)

- **Saltos de ~0,55 m por quadro:**
  - causa: o recuo da lente era feito em degraus de 6% do braço;
  - correção: busca binária do ponto livre mais distante;
  - resultado: o maior salto caiu para 0,06–0,12 m nos percursos sem monstros.
- **Giro pelas setas:**
  - a lente agora gira junto com o jogador;
  - antes, o acompanhamento lento da zona fazia um giro de 62° aparecer como 13°;
  - as composições automáticas não anulam mais o giro do jogador.
- **Troca automática de composição:** a velocidade linear da lente fica limitada a 9 m/s.
- **Troca para o lado oposto:** vira um corte limpo, em vez de a câmera passar girando por trás da protagonista.
- **Zonas novas:** Corredor 5, Música, rampa, corredor subterrâneo e Monitoramento.
- **Zonas corrigidas:** Artes, que ganhou oclusores para a parede nova, e Corredor 4.
- A câmera não atravessa paredes: o teste de oclusão e a varredura de geometria ficaram sem problemas.

### Piso de segurança

O `FallSafety` foi rebaixado para y −20 e ampliado. Na posição antiga, ele cortaria o subsolo.

## Testes antigos atualizados (com justificativa)

Nenhum teste foi apagado ou enfraquecido. Todas as mudanças estão comentadas com "Prompt 1".

- **Portas abertas no início:** 13 suítes que medem câmera, colisão e navegação abrem as portas à força no começo, com `test_input.open_all_doors`. Elas percorrem vãos que não tinham portas.
- **Contagens:** os testes passam a esperar a Música física, os 2 locais narrativos, 7 volumes e 9 regiões de navegação. Continuam exigindo exatamente 6 salas de aula.
- **Regras de "ponto de integração":** continuam testadas, mas agora numa cópia em memória em que a Música volta a ser ponto de integração.
- **Novas regras de validação:** foram acrescentados testes de erro para porta mal configurada.
- **Prompt das portas:** o texto pode ser "E  Abrir", "E  Fechar" ou "Trancada", porque ele muda durante o jogo.
- **Navegação entre salas:** a regra "sem rota Room 2 → Room 1" agora usa a máscara do monstro. Com a máscara de corredores, a rota pelas portas abertas passa a existir, e isso também foi testado.
- **Rota da Artes no teste de câmera:** a volta passa pela porta nova.

## Parcial

- **Cortes de câmera:**
  - ainda há 3 cortes onde o teste aceita 2, na saída da sala inicial e na junção dos corredores 1 e 2;
  - em `etapa45_navigation_test`, há 2 cortes em vez de 1 no trajeto corredor → Room 1;
  - a linha de base tinha o mesmo número de cortes, além dos saltos que agora sumiram;
  - a composição automática alterna de lado duas vezes em 2 m. A próxima melhoria é restringir a escolha de composição perto das portas.
- **Portas das salas 3 a 6:** ficam destrancadas enquanto a sala anterior estiver PENDING (`allow_if_previous_pending`). Sem isso, o jogo travaria até o conteúdo do Prompt 4 existir.
- **Corredores livres:** as trancas fecham as salas, não os corredores. O acesso ao subsolo é a única porta de corredor trancada.
- **Captura da rampa:** a imagem `09_rampa_subsolo` saiu mal enquadrada, apontando para a parede. A rampa foi validada pelos testes de percurso e de piso, não pela imagem.

## Pendente (fora do escopo do Prompt 1)

Estas falhas já existiam na linha de base:

- **Despertar por entrada de sala:** os monstros 2 a 6 despertam ao entrar na sala (`monster_room_activation.gd`). Isso explica a falha "entrar na Room 2 real: ACTIVE" no `six_rooms_test` e fica para o Prompt 5.
- **Busca do Polvo:** o teste de busca e retorno fica congelado porque o Game Over pausa o jogo (`monster_pilot`). O mesmo vale para "Polvo entrou em CHASING" no `etapa45`. Fica para o Prompt 3.
- **Audição:** há duplicidade de estímulo em 3 verificações de `monster_hearing`.
- **Estado das portas no save:** ainda não é salvo. Entra junto com os checkpoints, no Prompt 3.
- **Móveis:** as salas 2 a 6 continuam vazias, o que fica para o Prompt 2.

## Arquivos

**Novos**
- `scenes/world/door.tscn` e `scripts/world/door.gd`
- `tools/bake_all_navmesh.gd`
- `data/navigation/corridors_navmesh.tres`, `initial_navmesh.tres` e `subsolo_navmesh.tres`
- os testes `door_test`, `percurso_completo_test` e `floor_sweep_test`
- `docs/capturas/prompt1/`

**Alterados**
- `scenes/main.tscn`, gerado por `tools/prompt1_gerar_cena.py` a partir da cena original. É reexecutável.
- `data/game_data.json`, gerado por `tools/prompt1_gerar_json.py`.
- `camera_controller.gd`, `interactable.gd`, `player_interactor.gd`, `interaction_router.gd`, `interactive_object_data.gd` e `game_data.gd`.
- Os navmeshes das salas foram reassados.
- 15 testes antigos foram atualizados.
