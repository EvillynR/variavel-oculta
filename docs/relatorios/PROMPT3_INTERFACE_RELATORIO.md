# Prompt 3 — Menus, interface, telefone e checkpoints

- **Base:** o `VO_CameraFixa.zip`, preservado e com cópia de backup.
- **Personagens:** o visual não foi alterado; continuam as cápsulas provisórias.

## Placar (Godot 4.7.1 headless, `--fixed-fps 60`)

| Suíte | Antes | Agora |
|---|---|---|
| **fluxo_menu_test (novo)** | — | **31/31** |
| **save_load_test (novo)** | — | **27/27** |
| **monster_pilot_test** | 31/33 | **35/35** |
| etapa45_navigation_test | 159/164 | **161/164** |
| game_data_test | 142/142 | 142/142 |
| narrative / puzzle / interaction / room_progress | 100% | 100% |
| player_monster_collision / player_wall_movement | 100% | 100% |
| door / percurso_completo / floor_sweep / esconderijo / ruido / camera_fixa | 100% | 100% |
| camera_occlusion / camera_geometry_sweep | sem problemas | sem problemas |
| camera_behavior / camera_solid_collision (estilo órbita) | 10/10 · 59/63 | 10/10 · 59/63 |
| six_rooms / monster_hearing | 70/72 · 60/63 | sem mudança |

O placar completo está em `docs/capturas/prompt3/placar_testes.txt`.

## Validado em execução

### 1. Menu principal (`scenes/ui/main_menu.tscn`)

- É a nova cena inicial do projeto.
- **Opções:** Novo jogo, Continuar, Configurações, Créditos e Sair. "Continuar" só aparece quando existe um save.
- **Visual:** sóbrio, feito só com a UI do Godot (fundo escuro, título, destaque em vermelho ao passar o mouse).
- **Créditos:** o texto é provisório ("créditos finais da equipe: a definir"). Não inventei nomes.

### 2. Pausa (Esc, ação `pause`)

- **Opções:** Continuar, Configurações, Voltar ao último checkpoint e Menu principal.
- O jogo pausa de verdade, e ao fechar a pausa ele volta ao estado anterior.
- **Convivência com a UI de enigmas:** com um enigma aberto, Esc fecha o enigma, e a pausa não abre por cima (testado).

### 3. Configurações (`user://vo_config.cfg`)

- **Opções:** volume geral (barramento Master), brilho (`adjustment_brightness` do ambiente), sensibilidade da câmera, tamanho da legenda e tela cheia.
- **Remapeamento:** uma tecla por ação, para as 10 ações, com botão "Teclas padrão".
- O teste confirma que tudo é gravado, relido e aplicado.

### 4. Checkpoints e save (`user://vo_save.json`)

**Quando o jogo grava:**
- no início de um jogo novo;
- de novo, depois da chamada do despertar;
- ao entrar em uma sala liberada (a anterior concluída, ou um local narrativo);
- ao concluir uma sala.

**O que o save guarda:** reaproveita o `get_save_data` / `load_save_data` que já existiam em RoomProgressManager, PuzzleManager, ClueManager e NarrativeManager. Além disso, guarda portas (aberta e destrancada), monstros (ativo, posição e direção), posição da protagonista, histórico do telefone e objetivo.

**O que o `save_load_test` confirma (27/27), numa cena nova:**
- pistas, enigma resolvido e interações restaurados;
- chamada já disparada, que não toca de novo;
- estado das salas restaurado;
- porta aberta e acesso ao subsolo destrancado;
- o Polvo ativo, em vigia, a 0,09 m da posição salva;
- a protagonista na posição salva;
- histórico do telefone e objetivo restaurados;
- checkpoint gravado ao entrar numa sala liberada, e não gravado numa sala com a anterior pendente.

**Game Over:**
- Agora tem "Tentar do checkpoint", que restaura de verdade (testado: posição e pistas voltam), e "Menu principal".
- O antigo "Tentar novamente" só recarregava a cena.

### 5. Telefone (`scripts/ui/phone_ui.gd`)

- Responde aos eventos PHONE_CALL do NarrativeManager.
- **Chamada:**
  - tela "Chamada recebida" do "Desconhecido";
  - vibração feita com tremor e brilho pulsante da borda, sem áudio;
  - depois, "Em chamada" com legendas.
- **Alertas** (`phone_kind = "alerta"`): aviso curto, sem tela de chamada.
- **Histórico:** tecla T; tudo fica guardado no save.
- **Chamada inicial da lore:** evento `telefone_despertar` com "Não faça barulho. Eles ainda não sabem que você acordou.". Toca 1,2 s depois de um jogo novo começar (testado no fluxo real do menu).
- **Alerta "Ele está perto.":** evento `telefone_alerta_polvo`, disparado quando o Polvo entra em CHASING.

### 6. HUD

- Objetivo atual, vindo do novo campo `objective` dos eventos narrativos.
- Indicador "AGACHADA" ou "ESCONDIDA".
- Prompt de interação centralizado.

### 7. Diário de pistas (tecla J)

Lista as pistas descobertas no ClueManager, com o título e o texto de cada uma (testado com a tecla remapeada).

### 8. Testes dos monstros que quebravam pela pausa do Game Over

- **`monster_pilot_test`:**
  - agora verifica que a captura abre o Game Over e pausa o jogo;
  - em seguida fecha a tela e testa a busca separadamente;
  - resultado: **a busca e o retorno do Polvo funcionam de verdade** (SEARCHING → RETURNING → PATROLLING, sem oscilar).
- **`etapa45_navigation_test`:** a perseguição fecha o Game Over que tenha ficado aberto da volta anterior. As duas perseguições, andando e correndo, entram em CHASING.

## Defeito antigo encontrado e corrigido

A **UI de enigmas nunca funcionava na cena do jogo**.

- **Causa:** os caminhos padrão `Systems/PuzzleManager` eram relativos à própria UI, e ela registrava "PuzzleManager não encontrado" em toda partida. O `fluxo_menu_test` pegou esse erro porque conta os erros do motor.
- **Correção:** os caminhos agora são `../Systems/...`.
- **Novo comportamento:** como a UI passou a funcionar, ela abre sozinha só quando um enigma fica disponível durante o jogo, por ação da protagonista, na sala em que ela está.
  - Sem essa regra, os 7 enigmas de teste sem requisito abririam na tela no primeiro segundo de jogo.
  - Testado: ler o caderno na Room 1 abre o enigma e pausa; Esc fecha o enigma e despausa.

## Testes atualizados (com justificativa)

- **`game_data_test`:** o jogo agora tem 15 eventos, por causa da chamada do despertar e do alerta do Polvo.
- **`monster_pilot_test` e `etapa45_navigation_test`:** captura e busca passaram a ser testadas separadamente (item 8).
- **Testes antigos que carregam a cena:** chamam `test_input.open_all_doors`, que agora também desliga a abertura automática de enigmas. Esses testes medem interação, câmera e monstros, e antes a UI de enigmas nunca abria. A convivência entre enigma e pausa tem teste próprio, no `fluxo_menu_test`.

## Parcial

- **Textos provisórios, para revisão da autora:**
  - objetivo "Saia da sala sem fazer barulho.";
  - texto dos créditos;
  - alerta "Ele está perto." ligado à perseguição do Polvo.
  
  A fala do despertar é a da lore, literal.
- **Sensibilidade da câmera:** na câmera fixa (padrão), ela muda a rapidez com que a câmera acompanha a protagonista; no estilo de órbita, muda a velocidade do giro pelas setas.
- **Tela cheia:** não dá para verificar em modo headless (a opção é gravada e aplicada fora do headless).
- **Capturas:** as telas (`docs/capturas/prompt3/00_grade.jpg`) foram feitas no renderizador Compatibility. Em resoluções de 540 linhas, a parte de baixo das Configurações fica no limite da tela.

## Pendente (já existia antes)

- **Despertar por entrada de sala:** fica para o Prompt 5 (2 falhas no `six_rooms`).
- **Audição:** o `monster_hearing` usa tempo real e falha em 3 itens com `--fixed-fps`.
- **Cortes do estilo de órbita:** são os mesmos itens de antes (estilo opcional).

## Arquivos

**Novos**
- `scripts/core/save_system.gd` e `game_session.gd`
- `scripts/ui/` (menu principal, configurações, pausa, telefone, HUD, diário e estilo)
- `scenes/ui/main_menu.tscn`
- `tests/fluxo_menu_test.gd`, `save_load_test.gd` e `test_errors.gd`
- `docs/capturas/prompt3/`

**Alterados**
- `project.godot`: cena inicial e ações `telefone` (T) e `diario` (J).
- `scenes/main.tscn`: nó `GameSession`.
- `data/game_data.json`: 2 eventos de telefone.
- `narrative_event.gd`: campos `objective` e `phone_kind`.
- `game_over_manager.gd` e `puzzle_ui.gd`.
- 4 testes.
