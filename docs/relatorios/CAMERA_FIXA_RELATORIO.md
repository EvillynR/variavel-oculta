# Câmera fixa no estilo Little Nightmares (ajuste pós-Prompt 2)

Pedido: câmeras fixas nos cômodos, sem giro, com a transição entre cômodos quase imperceptível e com luz por onde a personagem anda, no estilo de câmera de Little Nightmares.

- **Base:** o `VO_Prompt2.zip`, preservado e com backup.
- **Personagens:** o visual não foi alterado; continuam as cápsulas provisórias.

## Placar (Godot 4.7.1 headless, `--fixed-fps 60`)

| Suíte | Antes | Agora |
|---|---|---|
| **camera_fixa_test (novo)** | — | **12/12** |
| percurso_completo_test | 21/21 | 21/21 |
| esconderijo_test / ruido_test | 16/16 · 9/9 | 16/16 · 9/9 |
| camera_occlusion_test (já com a câmera fixa) | sem bloqueios | **sem bloqueios** |
| door_test / floor_sweep_test | 40/40 · 13/13 | 40/40 · 13/13 |
| game_data / narrative / puzzle / interaction / room_progress | 100% | 100% |
| player_monster_collision / player_wall_movement | 100% | 100% |
| camera_behavior / camera_solid / camera_geometry_sweep (estilo órbita) | 10/10 · 59/63 · sem problemas | 10/10 · 59/63 · sem problemas |
| etapa45 / six_rooms / monster_pilot / monster_hearing | 159/164 · 70/72 · 31/33 · 60/63 | sem mudança |

O placar completo está em `docs/capturas/camera_fixa/placar_testes.txt`.

## Validado em execução

### Como a câmera funciona (`scripts/camera_controller.gd`)

`camera_style = FIXED` passou a ser o padrão.

- **Ângulo fixo por cômodo:** a câmera é de diorama, vista de lado. A inclinação é baixa (17°) e a lente é estreita (FOV de 30°), o que achata a perspectiva como numa maquete. O ângulo vem da zona de câmera do cômodo.
- **Setas:** não giram mais a câmera.
- **Acompanhamento:**
  - suave, com amortecimento crítico (0,55 s);
  - zona morta lateral de 0,6 m, para que passos pequenos não movam a câmera;
  - leve antecipação na direção do movimento.
- **Troca de cômodo:** é um deslizamento de ~1,25–1,6 s, sem corte. A câmera não colide com nada.
- **Corte de maquete:**
  - a parede da frente do cômodo some por inteiro, junto com a porta instalada nela;
  - qualquer parede que fique entre a lente e a protagonista também some;
  - o recorte antecipa ~0,25 s do movimento.
- **Móveis e portas:** ficam translúcidos quando estão na frente dela.
- **Luz que acompanha a protagonista:**
  - `LuzDaProtagonista`: OmniLight quente, com sombra e alcance de 7,5 m;
  - fica do lado da câmera, um pouco acima dela;
  - por onde ela anda fica iluminado, e o resto do cômodo continua escuro.
- **Controles:** a direção das teclas segue o ângulo fixo, e o percurso inteiro continua passando.

### `camera_fixa_test`

O teste faz o percurso completo, da sala inicial até a Sala de Monitoramento, passando por mais de 12 zonas, e verifica:
- zero cortes;
- maior passo da lente: 0,087 m por quadro;
- a orientação fica parada em 100% dos quadros;
- 1 s segurando as setas não muda nada;
- a protagonista fica sempre no quadro e sempre visível;
- a lente nunca entra em geometria visível;
- a luz fica sempre acesa, a até 3 m dela.

### Capturas da câmera de jogo

`docs/capturas/camera_fixa/00_grade.jpg` reúne os 9 cômodos.

## Testes atualizados (com justificativa)

- **Estilo de órbita:** o estilo antigo continua disponível (`camera_style = ORBIT`). `camera_behavior_test`, `camera_solid_collision_test`, `camera_geometry_sweep_test` e `etapa45_navigation_test` continuam medindo esse estilo, por meio de `test_input.use_orbit_camera(self)`. Os placares deles ficaram iguais aos de antes.
- **Portas no estilo de órbita:** passaram a ficar translúcidas, mas continuam sólidas para a lente.

## Parcial

- **Translucidez nas capturas:** as imagens usam o renderizador Compatibility (opengl3), que ignora a translucidez dos móveis. No jogo, que usa Forward+, o fade funciona. Paredes e portas recortadas somem nos dois renderizadores.
- **Ajuste fino:** distância, inclinação, FOV e suavização são exports do CameraController ("Câmera fixa (estilo diorama)"). Vale ajustá-los no editor jogando, porque a sensação final de "Little Nightmares" depende de gosto.
- **Ângulo único:** todos os cômodos usam a mesma direção de vista (de leste para oeste). Isso mantém os controles estáveis entre cômodos. Para dar ângulos diferentes a alguns cômodos, basta mudar o `camera_offset` da zona, e a troca continua sendo um deslizamento.

## Pendente (já existia antes)

- **Despertar por entrada de sala:** fica para o Prompt 5 (2 falhas no `six_rooms`).
- **Pausa do Game Over:** congela a busca do Polvo (`monster_pilot` e `etapa45`).
- **Audição:** o `monster_hearing` usa tempo real e falha em 3 itens com `--fixed-fps`.
