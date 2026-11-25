# Ajustes pós-Prompt 3 — câmera, portas e colisão dos móveis

- **Base:** o `VO_Prompt3.zip`, preservado e com backup.
- **Personagens:** o visual não foi alterado; continuam as cápsulas provisórias.
- **Método:** testes visuais internos. Capturei a câmera de jogo em dezenas de pontos do percurso (renderizador Compatibility) e inspecionei cada imagem antes e depois de cada correção. As capturas finais estão em `docs/capturas/ajustes_p3/`.

## Problemas relatados e o que foi feito

### 1. Câmera no fim do corredor (imagem 1)

- **Causa:** a parede do fim do Corredor 5, com a porta do subsolo, estava na lista de paredes de corte da zona. A câmera fixa sumia com ela o tempo todo, e a rampa aparecia do outro lado.
- **Correção (`camera_controller.gd`):**
  - **Paredes da frente:** só somem as paredes entre a lente e a protagonista (finas no eixo da visão). Paredes de fundo e laterais ficam.
  - **Junções:** pontas curtas de parede de junção vistas de quina também somem. Antes viravam uma barra vertical no quadro.
  - **Qualquer parede da frente:** some se estiver no quadro, e não só as listadas na zona.
  - **Limite da câmera:** ela para antes do fim dos corredores (Corredor 5: z −185,5; corredor do subsolo: z −223), para não mostrar o que há além da parede.
  - **Trava de enquadramento:** a protagonista nunca sai do quadro. A margem é de até 70% da meia-largura visível, calculada pela proporção real da tela.
- **Captura `d01`:** o fim do corredor mostra a parede com a porta "Trancada".

### 2. Faixas escuras no chão (imagem 3)

- **Causa:** as paredes recortadas ficavam "só sombra" e continuavam escurecendo o chão por onde a protagonista anda.
- **Correção:** na câmera fixa, a peça recortada vai para uma camada de render que a câmera e as luzes ignoram. Ela some por inteiro, sem sombra, e a colisão continua igual.
- **Também acrescentei (`School/Exterior`, só visual, sem colisão):**
  - um chão externo do lado aberto da maquete;
  - um preenchimento sob a rampa do subsolo.

### 3. Porta aberta não fechava (imagem 2)

- **Causa:** a área que impedia o fechamento cobria todo o giro das folhas (≈1,6 m para cada lado). Quem estava perto o bastante para apertar E sempre estava "no caminho".
- **Correção (`door.gd`):**
  - só a soleira bloqueia o fechamento;
  - se a protagonista estiver na área do giro, a porta fecha e a colisão das folhas só volta quando a área esvaziar, para ninguém ficar preso.
- **Testado:** abrir e fechar a porta da Música de 3 posições (corredor, corredor deslocado e dentro da sala), e a colisão voltando depois que ela sai da área do giro.

### 4. Colisão dos móveis

- **Teste novo `moveis_colisao_test`:** a protagonista anda contra cada móvel por 8 direções.
- **Antes:** em **179 casos** o corpo dela entrava no móvel. A colisão era peça por peça do CSG (pernas, assento, encosto), e os vãos entre elas deixavam a cápsula entrar.
- **Correção:** cada móvel tem agora **uma caixa sólida** no próprio volume. É um StaticBody no grupo `prop_body`, gerado por `tools/prompt2_gerar_moveis.py`.
  - A câmera não colide com essas caixas; o fade usa o móvel visível.
  - Os navmeshes foram reassados.
- **Depois:** **0 casos** em 96 móveis, e nenhum monstro dentro de móvel.

### 5. Prompt duplicado

"E Abrir" aparecia duas vezes, no rótulo do objeto e na HUD. Ficou só o rótulo junto do objeto.

## Placar (Godot 4.7.1 headless, `--fixed-fps 60`)

| Suíte | Antes | Agora |
|---|---|---|
| **moveis_colisao_test (novo)** | — | **3/3** |
| **door_test** | 40/40 | **48/48** |
| camera_fixa_test | 12/12 | 12/12 |
| percurso_completo / save_load / fluxo_menu | 21/21 · 27/27 · 31/31 | iguais |
| esconderijo / ruido / floor_sweep | 100% | 100% |
| camera_occlusion / camera_geometry_sweep | sem problemas | sem problemas |
| game_data / narrative / puzzle / interaction / room_progress / monster_pilot | 100% | 100% |
| player_monster_collision / player_wall_movement / camera_behavior | 100% | 100% |
| camera_solid_collision (estilo órbita) | 59/63 | 59/63 |
| etapa45 / six_rooms / monster_hearing | 161/164 · 70/72 · 60/63 | iguais |

O placar completo está em `docs/capturas/ajustes_p3/placar_testes.txt`.

## Testes atualizados (com justificativa)

- **Testes de câmera (`camera_occlusion`, `camera_fixa`, `camera_solid_collision` e `camera_geometry_sweep`):**
  - a colisão do móvel agora é uma caixa à parte, então as regras de visão usam o móvel visível (`test_input.fade_target`);
  - peça recortada na camada de corte conta como recortada;
  - móveis deixaram de contar como "peça visual sem colisão".
- **`six_rooms_test`:** a escola ganhou o nó `Exterior`, que é só visual.

## Parcial e pendente

- **Linha no teto:** nas junções de corredor, a verga fina da passagem ainda aparece como uma linha no teto, sem tapar a protagonista.
- **Monstro na frente:** um monstro entre a câmera e a protagonista (ex.: o Leitor) não fica translúcido, de propósito.
- **Já existiam antes:**
  - os cortes do estilo de órbita (opcional);
  - o despertar por entrada de sala (Prompt 5);
  - o `monster_hearing` com tempo real.
