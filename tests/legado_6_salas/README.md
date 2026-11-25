# Testes do layout antigo (6 salas)

Estes testes foram escritos para a versão anterior da escola:

- 6 salas, com Artes e Música;
- o Polvo na Room 1 (`Room1Gameplay`);
- os enigmas de teste `teste_ciencias_*`;
- portas das salas 3–6 destrancadas;
- o telefone tocando ao acordar.

A história de Yuko mudou isso de propósito:

- são 4 salas (Português, Matemática, Ciências e Geografia);
- os monstros ficam em `MonsterRoster`;
- os enigmas são reais;
- as portas abrem na ordem do mapa;
- a voz só liga quando Yuko pega o mapa.

Ficam aqui como referência. Quem quiser reaproveitar algum deve apontá-lo para os nós e ids novos (veja `tools/story_content.py`).

A cobertura atual está em `tests/`:

| Teste | O que cobre |
|---|---|
| `historia_completa_test` | Abertura → mapa → 8 enigmas → monstros → saídas → subsolo → final |
| `checkpoint_historia_test` | Captura e "Tentar do checkpoint" no meio da história |
| `fluxo_menu_test` | Menu → novo jogo → cenas → telefone → HUD → diário → enigma → pausa → checkpoint → menu |
| `camera_behavior_test`, `camera_geometry_sweep_test`, `camera_occlusion_test` | Câmera |
| `moveis_colisao_test`, `player_wall_movement_test` | Colisão |
