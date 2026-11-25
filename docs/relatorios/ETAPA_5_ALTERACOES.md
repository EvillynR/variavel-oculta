# Etapa 5 — Arquitetura narrativa (registro por fase)

## Fase 1 — Modelo de dados e validação (concluída, aguardando revisão)

Nenhuma cena foi alterada. Nenhum .tres existente foi alterado.

### Novos
- `scripts/narrative/room_data.gd` (`RoomData`): sala de aula ou local narrativo — id, ordem, matéria,
  status de conteúdo (TEST/PROVISIONAL/FINAL), âncora na cena ou ponto de integração, nome técnico
  provisório documentado, enigmas, pistas, interações, gatilhos de ativação, monstro, conclusão
  (enigmas exigidos + saída), evento de saída, eventos e nível narrativo. Enum `RoomState` compartilhado.
- `scripts/narrative/narrative_event.gd` (`NarrativeEvent`): 9 tipos de evento, 3 níveis, gatilho
  (manual, interação, pista, enigma, entrar/concluir sala, estado de monstro, fim de outro evento),
  condições por id, `once`, prioridade, `enabled` + `disabled_reason`, etiquetas de segredo.
- `scripts/narrative/narrative_database.gd` (`NarrativeDatabase`): salas, eventos, configurações de
  monstros e destino final; consultas; `validate(puzzle_db)` e `get_warnings(puzzle_db)` cruzando com
  o `PuzzleDatabase` existente (que continua sendo a fonte de verdade de enigmas e pistas).
- `tests/narrative_data_test.gd`: 40 verificações com dados de TESTE montados em memória.

### Alterado
- `scripts/monsters/monster_config.gd`: só campos novos, no fim do arquivo, com padrões neutros
  (sala, estados permitidos, eventos por estado, audição, retorno, modelo, animações, sons, notas do
  placeholder). O `polvo_config.tres` não foi tocado e o Polvo se comporta igual.

### Regras que a validação garante
- Sala de aula precisa de matéria, enigma, monstro, gatilho, evento de saída e ordem única.
- Enigma/pista/monstro: existe, pertence a uma única sala e o `room_id` bate com a sala.
- A saída da sala é liberada pelos enigmas dela (e só por eles).
- Ponto de integração não pode apontar para geometria; nome técnico provisório exige documentação.
- Destino final da história: precisa ser um local narrativo, nunca sala de aula nem sala de nome
  técnico provisório (impede ligar o fim da história à sala `Exit`).
- Conteúdo FINAL não pode usar enigmas ou textos marcados [TESTE]/[PROVISÓRIO].
- Segredos têm nível mínimo (ex.: subsolo, gravação prévia e visita anterior só no nível 3);
  revelação nunca no nível inicial e sempre única; evento não pode ter nível maior que o da sala.
- Evento desativado exige motivo; dependências circulares são detectadas.

## Fase 2 — Progresso das salas, gerenciador narrativo e volumes (concluída, aguardando revisão)

### Novos
- `scripts/narrative/room_volume.gd` (`RoomVolume`): Area3D só de detecção (camada 0, não monitorável,
  máscara 1). Avisa o gerenciador quando a protagonista começa/deixa de sobrepor o volume.
  Independente das zonas de câmera; não altera câmera, controles nem movimento.
- `scripts/narrative/room_progress_manager.gd` (`RoomProgressManager`): sala atual com histerese
  (permanece na sala enquanto ainda sobrepõe o volume dela; troca só após 0,25 s estável) e estados
  LOCKED → AVAILABLE → ACTIVE → MONSTER_AWAKE → SOLVED → COMPLETED. Sinais: room_entered,
  room_exited, current_room_changed, room_state_changed, room_completed. Save em memória.
- `scripts/narrative/narrative_manager.gd` (`NarrativeManager`): escuta enigmas, pistas, interações,
  salas e estados dos monstros; dispara eventos por gatilho + condições; `once` respeitado inclusive
  após carregar; eventos desativados recusados até manualmente. Sinais event_triggered,
  event_finished, event_refused. Interface futura: conectar a event_triggered, desligar auto_finish e
  chamar finish_event(). Log no console com o prefixo [Narrativa].
- `tools/build_narrative_minimal.gd`: gera o banco mínimo; não sobrescreve sem `-- --force`.
- `data/narrative/narrative_database.tres`, `data/narrative/rooms/room_1.tres` e
  `data/narrative/test/teste_*.tres` (3 eventos técnicos marcados [TESTE]).
- `tests/room_progress_test.gd`: 37 verificações.

### Alterados
- `scenes/main.tscn`: só adições — `Systems/RoomProgressManager`, `Systems/NarrativeManager`,
  `RoomVolumes/Room1Volume` e um BoxShape3D. `collision_mask = 5` da protagonista preservado.
- `data/monsters/polvo_config.tres`: `room_id = &"room_1"` (campo da Fase 1; não muda comportamento).

### Limitações
- Banco mínimo: só Room 1/Polvo. Rooms 2–4, a sala técnica `Exit` e os pontos de integração
  (Música, monitoramento, subsolo) ainda não têm RoomData nem volume (Fase 4).
- Transição entre salas adjacentes foi testada com volumes de teste criados em memória no
  corredor: no mapa atual nenhuma sala é vizinha direta de outra (há corredor entre elas).
- A histerese de 0,25 s ignora idas e voltas mais rápidas que isso; quem realmente fica 0,25 s do
  outro lado gera um evento legítimo de saída/entrada.
- Eventos são avaliados no momento do gatilho; um evento cuja condição ainda não foi cumprida só
  volta a ser avaliado no próximo gatilho (ex.: reler o documento).

## Fase 3 — Componentes dos monstros e sistema de audição (concluída, aguardando revisão)

Backup: `Jogo3D_Etapa5_Fase2.zip` (estado anterior completo). Nenhuma cena foi alterada:
`main.tscn`, `monster.tscn`, protagonista, câmera, iluminação, controles e `NarrativeManager`
seguem idênticos. `build_monster_assets.gd` não foi usado.

### Como a audição funciona
Um único caminho, dentro da arquitetura existente (não há segundo sistema de percepção):
fonte de som → `SoundStimulus` → grupo `sound_listener` → `MonsterController.receive_sound_stimulus`
→ `MonsterPerception.evaluate_sound` (física do som) → `MonsterController` (estado, duplicatas)
→ `INVESTIGATING` pelo `_change_state` de sempre → `state_changed` → `NarrativeManager`.

- `MonsterPerception.evaluate_sound()`: intensidade × peso do tipo × abafamento por parede;
  alcance = `hearing_radius × intensidade × sensitivity`; nível = 1 − distância/alcance.
  Fora do alcance → `OUT_OF_RANGE`; nível abaixo de `investigate_threshold` → `BELOW_THRESHOLD`
  (som irrelevante); tipo ignorado → `IGNORED_KIND`; sensibilidade 0 → `DEAF`.
  Parede: raio dos "ouvidos" (altura dos olhos) até o som; ignora o próprio corpo, a fonte,
  personagens e obstáculos abaixo de 1 m (carteiras).
- `MonsterController`:
  - `hear_stimulus(posição)` mantém o comportamento anterior (ordem de roteiro: investiga sem
    conferir alcance). `hear_stimulus(posição, intensidade, tipo, fonte)` e
    `receive_sound_stimulus(SoundStimulus)` passam pela audição real. Retornam a reação.
  - Só reage nos estados de `HearingProfile.reactive_states` (padrão = os mesmos de antes:
    PATROLLING, RETURNING, SEARCHING, INVESTIGATING). INACTIVE e AWAKENING nunca reagem
    (o despertar continua só pelos gatilhos); CHASING ignora sons (a perseguição segue a visão).
    Respeita `MonsterConfig.allowed_states`.
  - O destino é o ponto navegável mais próximo do som (navmesh): o monstro vai até onde consegue,
    nunca através de paredes. A posição fica congelada no momento do som
    (`get_last_heard_position()`); ele não acompanha a protagonista.
  - Duplicatas: o mesmo estímulo (mesmo id) só é processado uma vez (`DUPLICATE`); sons a menos de
    `merge_radius` da investigação em curso, ou de uma concluída há menos de `merge_time`, são o
    mesmo som (`MERGED`). Som novo em outro ponto durante a investigação atualiza o destino sem
    reemitir `state_changed` (mantém a correção da Etapa 4.5).
  - `last_state_cause = &"som"` nas transições causadas pela audição (assinatura de
    `state_changed` inalterada). Sinal novo `sound_perceived(stimulus, reaction)` para depuração;
    a narrativa não o usa.

### Novos
- `scripts/monsters/sound_stimulus.gd` (`SoundStimulus`): estímulo lógico (id único, posição,
  intensidade, tipo, fonte), tipos `KIND_*`, enum `Reaction`, `broadcast()` e `scripted_at()`.
- `scripts/monsters/hearing_profile.gd` (`HearingProfile`): sensibilidade, raio, limiar de
  investigação, abafamento por parede, tipos ignorados, peso por tipo, estados reativos, duplicatas.
- `scripts/monsters/sound_stimulus_source.gd` (`SoundStimulusSource`): componente reutilizável;
  `emit_stimulus()` com intervalo mínimo (ações contínuas não viram rastreador), liga/desliga,
  sinal `stimulus_emitted` (para som provisório futuro). Não toca áudio.
- `data/monsters/hearing/polvo_audicao.tres`: audição do Polvo [PROVISÓRIO] — 8 m, limiar 0,25
  (investiga até ~6 m com intensidade 1), paredes abafam 50%.
- `data/monsters/hearing/perfil_padrao.tres`, `perfil_baixa_audicao.tres`,
  `perfil_alta_sensibilidade.tres`, `perfil_somente_roteiro.tres`: perfis genéricos de percepção,
  independentes e sem vínculo com monstros (nenhum dos cinco monstros restantes foi criado).
- `tests/monster_hearing_test.gd`: 63 verificações na cena real.

### Alterados
- `scripts/monsters/monster_config.gd`: campo `hearing_profile` e `get_hearing()`. Sem perfil, usa
  `noise_sensitivity`/`hearing_radius` (compatibilidade; padrão continua surdo a fontes de som).
- `scripts/monsters/monster_perception.gd`: `evaluate_sound()`; `can_see()` intacto.
- `scripts/monsters/monster_controller.gd`: audição descrita acima; grupo `sound_listener`;
  `_change_state` ganhou parâmetro opcional `cause`. Demais estados e transições iguais.
- `data/monsters/polvo_config.tres`: `hearing_profile = polvo_audicao.tres` (demais valores iguais).
- `tests/narrative_data_test.gd`: a verificação "campos novos neutros" agora também confere que a
  audição do Polvo vem do perfil próprio (o rótulo antigo "surdo a passos" deixou de ser verdade).

### Testes (Godot 4.7.2 headless, resultados reais)
- Novo: `monster_hearing_test` 63/63.
- Regressão: `etapa45_navigation_test` 149/149, `puzzle_system_test` 49/49,
  `player_monster_collision_test` 48/48, `narrative_data_test` 40/40, `room_progress_test` 37/37,
  `monster_pilot_test` 33/33, `interaction_prompt_test` 24/24, `camera_behavior_test` 10/10,
  `camera_occlusion_test` sem bloqueios, `camera_geometry_sweep_test` sem problemas.
  Mesmos números da linha de base rodada antes das alterações.

### Pontos de integração preparados (não ligados)
- Corrida da protagonista: `SoundStimulusSource` filho do Player, `kind = passos_corrida`,
  chamado pelo `player.gd` enquanto corre. Exige alterar a protagonista: decisão da responsável.
- Objetos derrubados, portas, mecanismos: `SoundStimulusSource` filho do objeto, chamado pelo
  script da ação quando ela existir (`objeto_derrubado`, `porta`, `mecanismo`).
- Código sem nó (ex.: um evento de enigma): `SoundStimulus.broadcast(get_tree(), SoundStimulus.new(...))`.
- Som provisório: conectar `stimulus_emitted` a um AudioStreamPlayer3D irmão da fonte.
- Narrativa: eventos `MONSTER_STATE` com `trigger_state = "INVESTIGATING"` já funcionam; quem
  precisar distinguir a causa lê `monster.last_state_cause`.
- Monstro novo: novo `MonsterConfig` com `hearing_profile` apontando para um perfil (ou cópia).

### Limitações
- Nenhuma fonte de som está na cena (de propósito): no jogo atual o Polvo só ouve quando uma ação
  futura emitir estímulos ou um script chamar `hear_stimulus`.
- Propagação simplificada: distância em linha reta + um teste de parede; não segue corredores
  nem portas. Um som do corredor é avaliado pela linha reta através da parede (abafado).
- O navmesh cobre só a Room 1: sons de fora levam o Polvo ao ponto navegável mais próximo,
  junto à parede ou porta.
- Os valores do Polvo e dos perfis são de calibragem inicial; recalibrar com os sons reais.
- `leash_radius` continua sem uso (não fazia parte desta fase).

## Fase 4 — Preparação das seis salas e dos seis monstros (concluída, aguardando revisão)

Backup: `Jogo3D_Etapa5_Fase3.zip` (estado aprovado da Fase 3). Protagonista, controles, câmera,
iluminação, enigmas, pistas e colisões não foram alterados; `collision_mask = 5` mantido.
Nenhum script gerador de cena foi usado; `main.tscn` recebeu só acréscimos (0 linhas removidas).

### Situação das salas (medida no mapa real)
| Sala | Matéria | Monstro | Nó na cena | Situação |
|---|---|---|---|---|
| room_1 | Ciências | O Polvo (`octopus`) | `School/Room 1` | Física, jogável (enigmas de TESTE), navmesh camada 1 |
| room_2 | Matemática | O Ângulo (`angle`) | `School/Room 2` | Física, pendente, navmesh camada 2 |
| room_3 | Artes | A Pintora (`painter`) | `School/Exit` (nome técnico provisório) | Física, pendente, navmesh camada 3 — sem parede leste |
| room_4 | Português/Literatura | O Leitor (`reader`) | `School/Room 3` | Física, pendente, navmesh camada 4 |
| room_5 | Geografia | O Cartógrafo (`cartographer`) | `School/Room 4` | Física, pendente, navmesh camada 5 |
| room_6 | Música | O Maestro (`maestro`) | — | Ponto de integração: sem geometria, volume ou navegação |

Atenção aos nomes: a numeração das salas narrativas não coincide com a dos nós da cena
(room_4 = nó "Room 3"; room_5 = nó "Room 4"; room_3 = área oeste do nó "Exit").
Portas conferidas por física: salas 1, 2, 4 e 5 têm porta de 3 m na parede leste para os
corredores 1, 2, 3 e 4. A área de Artes (nó Exit) é aberta para o corredor do próprio nó em
toda a extensão (24,8 m): não há parede leste nem porta — registrado como pendência de cenário.

### Novos campos
- `RoomData`: `ContentStatus.PENDING` (valor novo no fim do enum), `theme`, `entry_required_rooms`,
  `connected_area_paths`, `connection_notes`, `planned_interaction_ids`, `pending_items`,
  `navigation_layer`, `navigation_mesh`, `navigation_region_path`; `is_pending()`, `navigation_layer_bit()`.
- `MonsterConfig`: `navigation_layers` (padrão 1 = Polvo igual).

### Comportamentos
- Validação (`NarrativeDatabase`): salas pendentes podem ficar sem enigma/gatilho, mas precisam de
  `pending_items` (aviso, não erro); regras antigas intactas para as demais. Novas regras: conexões
  e navegação proibidas em pontos de integração; camada de navegação única por sala; navmesh exige
  região; pontos de integração no formato `room_x.nome` e nunca iguais a interações reais; entrada
  não pode depender de sala posterior; por monstro: estados permitidos válidos, `state_events`
  apontando para evento MONSTER_STATE do próprio monstro e estado, `animation_map` com estados
  válidos, camada da sala incluída, notas obrigatórias em sala pendente.
- `RoomProgressManager`: sala pendente ou sem enigma nunca é dada como resolvida (sem a guarda, a
  regra antiga a resolveria na hora e liberaria a seguinte); `entry_required_rooms` respeitado.
- `MonsterController`:
  - agente usa `config.navigation_layers`; pontos mais próximos (posto, busca, som) consultam só as
    regiões dessas camadas (`_closest_navigable`). Medido: sem isso, um som no corredor junto à
    Room 2 levaria o Polvo a mirar um ponto dentro da Room 2. A prontidão da navegação continua
    esperando o mapa sincronizar (como antes).
  - encaixe de modelo: com `visual_scene`, instancia o modelo como `VisualModel` em
    `visual_offset`, esconde o placeholder do `VisualLink` e toca a animação de `animation_map` a
    cada estado (ausente = ignorada). Sem `visual_scene` (todos hoje), nada muda.

### Arquivos novos
- Monstros: `data/monsters/{angulo,pintora,leitor,cartografo,maestro}_config.tres` e
  `data/monsters/hearing/{...}_audicao.tres` (audição individual, cópia do perfil padrão, [PROVISÓRIO]).
- Salas: `data/narrative/rooms/room_2.tres` … `room_6.tres`.
- Eventos previstos (desativados, com motivo): `data/narrative/planned/{monstro}_despertar.tres` e
  `room_N_saida.tres` para as salas 2–6.
- Navegação: `data/navigation/room_{2,3,4,5}_navmesh.tres`; `tools/bake_rooms_navmesh.gd` (só grava
  navmeshes novos; não toca na Room 1 nem em cenas; não sobrescreve sem `--force`).
- `tests/six_rooms_test.gd`: 68 verificações.

### Arquivos alterados
- `scenes/main.tscn` (+76 linhas, 0 removidas): `RoomVolumes/{Room2,Exit,Room3,Room4}Volume` e
  `Navigation/{Room2,Exit,Room3,Room4}Navigation` (camadas 2–5).
- `data/monsters/polvo_config.tres`: só acréscimos (`state_events` com o evento já existente
  `teste_polvo_despertar`, `placeholder_notes`).
- `data/narrative/rooms/room_1.tres`: só acréscimos (tema, conexão, navegação).
- `data/narrative/narrative_database.tres`: seis salas, 13 eventos, seis monstros.
- Scripts: `room_data.gd`, `narrative_database.gd`, `room_progress_manager.gd`,
  `monster_config.gd`, `monster_controller.gd`.
- `tools/build_narrative_minimal.gd`: aviso para não usar `--force` (apagaria as seis salas).
- Testes que fixavam o estado antigo, ajustados para conferir o novo:
  `room_progress_test` (banco de 6 salas; 5 volumes; limpeza das salas temporárias por id em vez de
  `resize(1)`, que apagava as salas 2–6 da memória), `narrative_data_test` (`state_events` do Polvo),
  `monster_hearing_test` (nenhum monstro usa perfil genérico).

### Testes (Godot 4.7.2 headless, resultados reais)
- Novo: `six_rooms_test` 68/68.
- Regressão: `etapa45_navigation_test` 149/149, `monster_hearing_test` 63/63,
  `puzzle_system_test` 49/49, `player_monster_collision_test` 48/48, `narrative_data_test` 40/40,
  `room_progress_test` 37/37, `monster_pilot_test` 33/33, `interaction_prompt_test` 24/24,
  `camera_behavior_test` 10/10, `camera_occlusion_test` sem bloqueios,
  `camera_geometry_sweep_test` sem problemas.
- Problema introduzido e corrigido nesta fase: a consulta por região deixava o Polvo "pronto" antes
  de o mapa sincronizar (detectado pelo `monster_pilot_test`); a prontidão voltou a esperar o mapa.

### Limitações
- Salas 2–6 só em dados: sem enigmas, gatilhos, Interactables nem monstros na cena. Os cinco
  monstros não têm comportamento próprio (não especificado); usam a máquina compartilhada quando
  instanciados.
- Salas 2–5 estão vazias: navmesh retangular; reassar com `bake_rooms_navmesh.gd -- --force`
  quando houver móveis (e marcar os móveis como no bake da Room 1).
- Sala de Artes aberta para o corredor: a borda do navmesh fica a ~1,2 m do corredor, menos que a
  distância de captura (1,3 m). Revisar ao implementar a Pintora.
- Música: falta todo o cenário; Maestro sem camada de navegação.
- Locais narrativos (monitoramento, subsolo) e `final_destination_id` ainda não cadastrados.
- Níveis narrativos das salas (1,1,2,2,2,3) e textos de tema são provisórios.
- `leash_radius` continua sem uso; `sound_bank` ainda não é tocado por ninguém.
