# Prompt 2 — Banco JSON, seis salas e objetos interativos

Base: versão aprovada do Prompt 1 (backup completo feito antes de qualquer edição). Godot 4.7.2.
Todos os números deste documento vêm de execuções reais (testes headless).

## 1. Decisão: uma única fonte de dados

Antes desta fase, os dados configuráveis estavam espalhados em 48 arquivos `.tres` e em propriedades da
cena principal (ação e texto dos objetos, gatilho do Polvo). Agora **`data/game_data.json` é a única fonte
principal**. Os sistemas continuam usando os mesmos tipos (`PuzzleData`, `ClueData`, `RoomData`,
`NarrativeEvent`, `MonsterConfig`, `HearingProfile`), mas eles são criados em memória a partir do JSON pelo
carregador `GameData`. Não existe um segundo banco em paralelo:

- os 48 `.tres` de dados foram arquivados em `legado_tres_pre_json.zip` (fora do carregamento do Godot)
  depois de comprovada a equivalência e de toda a regressão passar sem eles;
- a cena principal não referencia mais nenhum deles;
- as ferramentas que gravavam esses `.tres` (`build_test_content.gd`, `build_narrative_minimal.gd`,
  `build_monster_assets.gd`) foram desativadas: ao rodar, explicam que os dados estão no JSON e encerram.

Continuam como `.tres` apenas os navmeshes (`data/navigation/`), que são geometria assada e não dados
configuráveis; o JSON os referencia pelo caminho.

## 2. Como a migração foi feita (controlada)

1. `tools/migrate_tres_to_json.gd` leu os `.tres` reais e a cena e gerou o JSON automaticamente, sem
   redigitação. Ele grava só os campos diferentes do padrão e os enums pelo nome (ex.: `"CLASSROOM"`).
2. Na primeira geração, conferi se algum dado se perdia e achei um caso: a pista de teste
   `teste_pista_partitura` é revelada pelo objeto `room_test.partitura`, que não existe na cena (é usado
   pelos testes de enigmas). A ferramenta foi corrigida para preservá-lo como objeto `TEST_ONLY`.
3. `tools/verify_json_migration.gd` comparou campo a campo os dados carregados do JSON com os `.tres`.
   A primeira execução encontrou 5 diferenças reais (o carregador perdia `connected_area_paths`, uma lista
   tipada de caminhos de nó); depois da correção: **1.151 campos comparados, 0 diferenças**. A ordem das
   listas também foi conferida (ela decide, por exemplo, qual sala começa disponível).
4. A única diferença posterior é intencional: a pendência dos vãos da parede oeste da área de Artes,
   acrescentada já no JSON (seção 5).
5. Só depois disso os `.tres` foram arquivados e toda a regressão foi executada sem eles.

Identificadores, referências, condições e a configuração do Polvo foram preservados (comparados campo a
campo, inclusive o perfil de audição `polvo_audicao`).

## 3. Formato do JSON

```json
{
  "format_version": 1,
  "description": "…",
  "final_destination_id": "",
  "hearing_profiles": [ { "id": "polvo_audicao", "hearing_radius": 8.0, … } ],
  "monsters":  [ { "monster_id": "octopus", "display_name": "O Polvo", "room_id": "room_1",
                   "hearing_profile": "polvo_audicao", "state_events": { "AWAKENING": "teste_polvo_despertar" }, … } ],
  "puzzles":   [ { "id": "teste_ciencias_alternativa", "room_id": "room_1", "question_type": "MULTIPLE_CHOICE", … } ],
  "clues":     [ { "id": "teste_pista_tabela", "room_id": "room_1", "required_clue_ids": ["teste_pista_caderno"], … } ],
  "rooms":     [ { "id": "room_3", "kind": "CLASSROOM", "order": 3, "subject": "Artes", "monster_id": "painter",
                   "geometry_status": "PHYSICAL", "content_status": "PENDING", "scene_anchor": "School/Exit",
                   "technical_name_provisional": true, "pending_items": ["…"], … } ],
  "events":    [ { "id": "teste_room_1_caderno", "type": "DOCUMENT", "trigger": "INTERACTION",
                   "trigger_id": "room_1.caderno_laboratorio", … } ],
  "objects":   [ { "id": "room_1.caderno_laboratorio", "room_id": "room_1", "implementation": "FUNCTIONAL",
                   "scene_node": "Room1Gameplay/Interactables/CadernoLaboratorio",
                   "action": "ler", "prompt": "E  Ler",
                   "conditions": { "required_clues": [] },
                   "effects": [ { "type": "reveal_clue", "clue_id": "teste_pista_caderno" } ] } ]
}
```

Regras gerais: cada seção é uma lista; cada item tem id único na seção; campos ausentes usam o padrão da
classe; nomes de campos são os mesmos das classes GDScript; enums são escritos pelo nome; perfis de
audição são referenciados por id e recursos de arquivo (navmesh, cena do modelo, sons) pelo caminho.

### Objetos interativos

| Campo | Significado |
|---|---|
| `id` | Mesmo `interaction_id` do nó Interactable; formato `sala.nome` |
| `room_id` | Sala dona do objeto |
| `implementation` | `FUNCTIONAL` (existe na cena e funciona), `PLANNED` (só reservado), `TEST_ONLY` (só testes automatizados) |
| `scene_node` | Caminho do Interactable na cena principal (obrigatório e exclusivo de `FUNCTIONAL`) |
| `action`, `prompt`, `one_shot`, `enabled`, `selection_priority` | Comportamento da interação |
| `conditions` | `required_interactions`, `required_clues`, `required_puzzles_solved`, `required_rooms_completed` (todas precisam ser verdadeiras) |
| `effects` | `{"type": "reveal_clue", "clue_id"}` e `{"type": "activate_monster", "monster_id"}` |
| `notes` | Observações |

Referências narrativas não são digitadas no objeto: o carregador calcula `narrative_event_ids` a partir dos
eventos com gatilho `INTERACTION` ou que exigem a interação. Também são **calculados** (e recusados se
escritos no JSON): `ClueData.source_object_id` (vem de `reveal_clue`), `RoomData.activation_interaction_ids`
(vem de `activate_monster`), `RoomData.interaction_ids` e `planned_interaction_ids` (vêm dos objetos da sala).
Assim cada informação existe em um só lugar.

Objetos `PLANNED` não podem ter efeitos nem condições, e um evento ativo não pode depender deles: um objeto
sem função na cena não vira funcional só nos dados. Objeto `FUNCTIONAL` em sala sem cenário físico é erro.

## 4. Como os dados são carregados

`scripts/data/game_data.gd` (classe `GameData`) lê o JSON uma vez (`GameData.get_instance()`), converte os
tipos conferindo cada campo, liga os efeitos dos objetos e valida. A validação reúne as regras novas (formato,
tipos, enums, ids repetidos, referências de objetos, efeitos e condições) e reaproveita os validadores que já
existiam (`PuzzleDatabase.validate()` e `NarrativeDatabase.validate()`/`get_warnings()`), em vez de duplicá-los.
Erros nunca derrubam o jogo: vão para o console e para `GameData.errors`, e os testes exigem a lista vazia.

Integração nos sistemas existentes, sem controlador paralelo:

| Sistema | Antes | Agora |
|---|---|---|
| PuzzleManager, ClueManager | `puzzle_database.tres` na cena | `GameData.puzzle_db` |
| NarrativeManager, RoomProgressManager | `narrative_database.tres` na cena | `GameData.narrative_db` |
| Polvo (MonsterController) | `polvo_config.tres` na cena | `config_id = "octopus"` -> JSON |
| Gatilho do Polvo (MonsterTrigger) | lista na cena | objetos com `activate_monster` |
| Interactable | ação, texto e uso único na cena | definição do objeto no JSON (+ condições) |

O pipeline de interação continua o mesmo: Interactable -> PlayerInteractor -> InteractionRouter ->
PuzzleManager/ClueManager; as condições só foram acrescentadas em `Interactable.can_interact()`. Na cena, o
nó guarda apenas o `interaction_id`, que é o elo com os dados.

Exemplos reais de mensagens de erro (do teste `game_data_test.gd`):
- `rooms[1] "room_2": campo desconhecido "corredor".`
- `rooms[0] "room_1": "kind" = "SALA" inválido; aceitos: CLASSROOM, STORY_AREA.`
- `objects "room_6.gatilho_monstro": objeto FUNCTIONAL numa sala sem cenário físico (room_6). Use PLANNED até a geometria existir.`
- `clues[0] "teste_pista_caderno": "source_object_id" é calculado pelo carregador e não pode ser escrito no JSON (use um efeito {"type": "reveal_clue"} no objeto que revela a pista).`

## 5. As seis salas (estado real)

Mapeamento preservado (a numeração narrativa não coincide com o nome dos nós):

| Sala | Matéria | Monstro | Nó na cena | Cenário | Conteúdo | Objetos (func./plan.) | Enigmas | Eventos |
|---|---|---|---|---|---|---|---|---|
| room_1 | Ciências | O Polvo | `School/Room 1` | físico | TEST | 4 / 0 | 2 de teste | 3 ativos |
| room_2 | Matemática | O Ângulo | `School/Room 2` | físico | PENDING | 0 / 3 | — | 2 desativados |
| room_3 | Artes | A Pintora | `School/Exit` (nome provisório) | físico, incompleto | PENDING | 0 / 3 | — | 2 desativados |
| room_4 | Português/Literatura | O Leitor | `School/Room 3` | físico | PENDING | 0 / 3 | — | 2 desativados |
| room_5 | Geografia | O Cartógrafo | `School/Room 4` | físico | PENDING | 0 / 3 | — | 2 desativados |
| room_6 | Música | O Maestro | — | sem cenário | PENDING | 0 / 3 | — | 2 desativados |

Cada sala registra: id, matéria, monstro, objetos, enigmas, pistas, eventos, entrada (a anterior na ordem +
`entry_required_rooms`), resolução (`required_puzzle_ids`/enigmas) e saída (`exit_id`, `exit_event_id`), além
de `content_status`, `geometry_status` e `pending_items`. Apenas a room_1 é jogável, com enigmas de teste.

Dependências de cenário ou recursos (registradas em `pending_items`, nada foi inventado na geometria):
- **Artes (room_3):** sem parede leste (aberta para o corredor do nó Exit) e, acrescentado nesta fase, dois vãos
  na parede oeste sem chão do outro lado (medido pela geometria no Prompt 1). Nó com nome técnico provisório.
- **Música (room_6):** sem geometria, volume, navegação nem nó; existe só nos dados (ponto de integração).
- **Salas 2 a 6:** sem enigma real, sem gatilho de despertar, sem instância do monstro na cena, sem modelo,
  animações e sons; móveis ausentes (navmesh retangular).
- **Sala 1:** enigmas e eventos ainda são de TESTE.

## 6. Validação (resultados finais, sem os `.tres` no projeto)

| Teste | Resultado |
|---|---|
| `game_data_test` (novo) | 70/70 |
| `puzzle_system_test` | 49/49 |
| `narrative_data_test` | 40/40 |
| `interaction_prompt_test` | 24/24 |
| `room_progress_test` | 37/37 |
| `player_monster_collision_test` | 48/48 |
| `monster_pilot_test` | 33/33 |
| `monster_hearing_test` | 63/63 |
| `six_rooms_test` | 68/68 |
| `player_wall_movement_test` | 21/21 |
| `camera_occlusion_test` / `camera_geometry_sweep_test` | sem bloqueios / sem problemas |
| `camera_behavior_test` | 9/10 (limitação de câmera do Prompt 1) |
| `etapa45_navigation_test` | 160/164 (limitação de câmera do Prompt 1) |

O `game_data_test` cobre: banco real sem erros; seis salas e mapeamento para os nós; âncoras existentes na
cena; cada Interactable da cena cadastrado como `FUNCTIONAL` no caminho certo e recebendo os valores do
JSON; nenhum objeto não funcional na cena; Polvo e gatilho vindos do JSON; condição de pista bloqueando e
liberando a interação em jogo; nenhum `.tres` de dados referenciado; e 13 casos de JSON com problemas, cada
um com mensagem compreensível. A cena principal também foi executada sem nenhum erro.

Correção sobre o relatório do Prompt 1: o `etapa45_navigation_test` roda em tempo real, e o resultado varia
com o ritmo dos quadros (161/164 informado antes). Em modo determinístico (`--fixed-fps 60`), as versões do
Prompt 1 e do Prompt 2 dão o mesmo resultado item a item, 160/164: a quarta falha é um passo de câmera de
0,57 m ao sair da Room 1, limitação da câmera do Prompt 1, não desta fase.

Testes ajustados à nova fonte (mesmo sentido, nova origem dos dados): `narrative_data_test`,
`six_rooms_test` e `monster_hearing_test` passaram a usar o `GameData` em vez de carregar `.tres`; as duas
checagens que identificavam o perfil de audição pelo nome do arquivo agora o identificam pelo id do JSON.

## 7. Arquivos

Novos: `data/game_data.json`, `scripts/data/game_data.gd`, `scripts/data/interactive_object_data.gd`,
`tools/migrate_tres_to_json.gd`, `tools/verify_json_migration.gd`, `tests/game_data_test.gd`,
`legado_tres_pre_json.zip`, este documento.

Alterados: `scripts/puzzles/puzzle_manager.gd`, `scripts/puzzles/clue_manager.gd`,
`scripts/narrative/narrative_manager.gd`, `scripts/narrative/room_progress_manager.gd` (banco do JSON);
`scripts/monsters/monster_controller.gd` (`config_id`, `resolve_config()`); `scripts/monsters/monster_trigger.gd`
(gatilhos do JSON); `scripts/interaction/interactable.gd` (definição e condições do JSON); `scenes/main.tscn`
(só remoção das referências aos `.tres` e dos valores que foram para o JSON, mais `config_id` do Polvo);
`tools/build_test_content.gd`, `tools/build_narrative_minimal.gd`, `tools/build_monster_assets.gd` (desativados);
os três testes citados acima.

Removidos do projeto (arquivados em `legado_tres_pre_json.zip`): os 48 `.tres` de dados de `data/puzzles`,
`data/clues`, `data/narrative`, `data/monsters` e `data/puzzle_database.tres`.

Não foram alterados: geometria, paredes, portas e volumes; enigmas e monstros (nenhuma implementação nova);
protagonista, câmera e iluminação do Prompt 1. `build_monster_assets.gd` não foi usado.

## 8. Como editar e verificar

Editar `data/game_data.json` e rodar `godot --headless -s tests/game_data_test.gd`: qualquer erro de formato
ou referência aparece com o local exato. No jogo, os erros também aparecem no console ao iniciar.
