# Etapa 4.5 — Câmera, colisões e navegação

Godot 4.7.2, Forward+. A protagonista (cena, script, cápsula, controles) NÃO foi alterada.

## Diagnóstico
- Zonas das salas com `use_z_limits = false`: zona morta (2 m) + antecipação (1,2 m) + tensão (+2 m)
  levavam a câmera para fora da sala pelas paredes norte/sul (lado de fora das paredes, sem luz).
- Paredes de porta entre corredores iam até x = 6,6 (3,5 m para fora do prédio), no espaço da câmera.
- A câmera não tinha nenhuma colisão. Varredura original: 705 posições com câmera dentro, rente
  ou atrás de geometria visível. Depois: 0.
- Sobreposição Polvo/protagonista: eixo da câmera = eixo da aproximação; com a configuração A
  (3,2 m) ficavam sobrepostos em 42,6% da aproximação; com B, 0%.
- Carteiras (CSGBox3D) sem `use_collision`; armário sem corpo físico e fora do navmesh.

## Arquivos alterados
- `scripts/camera_controller.gd`: colisão por esfera (pivô no peito da protagonista → câmera).
  Ignora geometria invisível, paredes do corte de maquete, personagens e o grupo `camera_ignore`.
  Lente que encostaria na geometria: recua na hora. Parede só na frente: aproximação suave
  (máx. 12 m/s) e retorno suave. Yaw continua vindo da posição ideal (controles estáveis).
- `scenes/main.tscn`:
  - Rooms 1–4: perfil B (9, 5.6, 0), limites em Z dentro da sala; batentes de porta do corredor
    adjacente adicionados ao corte de maquete (Room 1, 2 e 3).
  - Zonas novas: ExitCamera e 5 zonas de corredor (Corridor1..4, ExitCorridor), com limites em Z
    e corte dos batentes das junções. Perfil padrão também B (sem salto de altura nas frestas).
  - InitialRoomCamera: Z de 0..0 para -3..3 (yaw não gira mais ~16° ao sair da sala).
  - CENÁRIO: 15 paredes de batente aparadas até x = 3,1 (antes 6,6 / 5,5), só a parte fora do prédio.
  - Carteiras com `use_collision = true`; armário com StaticBody3D (grupo `camera_ignore`).
- `data/navigation/room_1_navmesh.tres`: reassado incluindo o armário.
- `scripts/monsters/monster_controller.gd`: `hear_stimulus` durante INVESTIGATING agora atualiza o destino.
- `tests/camera_occlusion_test.gd`: móveis do grupo `camera_ignore` não contam como oclusão de nível.

## Novos
- `tools/bake_room1_navmesh.gd` — reassa só o navmesh (não sobrescreve o Polvo).
- `tests/etapa45_navigation_test.gd` — portas, corrida, agachamento, colisões, câmera, monstro, perseguição.
- `tests/camera_geometry_sweep_test.gd` — varredura da câmera contra a geometria em 11 áreas.
- `tests/chase_framing_compare.gd` — compara enquadramentos A/B e alternativas.
- `tests/camera_tour_capture.gd` — capturas reais Forward+ com métricas.

## Pendências
- Protagonista: máscara de colisão = 1, então ela atravessa o corpo do monstro (camada 3).
  Correção mínima proposta: `collision_mask = 5` em `scenes/player/player.tscn`. Aguardando autorização.
- Protagonista: cápsula visual de 1,10 m elevada a 0,90 m em pé (flutua 0,35 m).
- Cenário/iluminação: perto das paredes norte/sul da Room 1 a imagem fica ~92% escura por falta de
  luz (a câmera está dentro da sala); a protagonista escura some no fundo escuro.
- Cenário: tabela periódica a 0,5 m da parede; zona `Room1Camera_A_Original` desativada (sobra).
- Armário pode cobrir parcialmente os pés da protagonista por instantes (escolha: não puxar a câmera por móveis).

---

# Etapa 4.5b — Pendências (colisão protagonista × monstro, proposta de luz)

## Colisão protagonista × Polvo
Camadas reais conferidas em tempo de execução (bit n = camada n; valor = 2^(n-1)):
- Protagonista: layer 1 (valor 1), mask 1 (valor 1) — só cenário.
- Polvo: layer 3 (valor 4), mask 1 (valor 1).
- Cenário (CSG, armário, carteiras): layer 1.

Sintoma real medido: a protagonista não detectava o Polvo, mas o Polvo detectava a protagonista;
na sobreposição, o motor separava os corpos movendo o Polvo — ela o EMPURRAVA de 2,8 a 5 m.

Correção (1 linha): `collision_mask = 5` (camadas 1 + 3) como sobrescrita da instância Player
em `scenes/main.tscn`. `scenes/player/player.tscn` e `scripts/player.gd` não foram tocados;
camada, cápsula e movimentação da protagonista seguem iguais.
Recomendação: a responsável pela protagonista pode mover essa propriedade para `player.tscn`
quando a protagonista for usada em outras cenas.

## Proposta de iluminação (NÃO aplicada)
A iluminação original de `main.tscn` está intacta. As propostas são cenas separadas,
instanciadas só pelo script de comparação:
- `scenes/proposals/room1_luz_p1_chao.tscn` — P1: 2 spots verticais sobre as faixas norte e sul.
- `scenes/proposals/room1_luz_p2_parede.tscn` — P2: os mesmos spots inclinados 28° para as paredes.
- `tests/lighting_compare_capture.gd` — capturas Forward+ original/P1/P2 com métricas.
Para aplicar a P1 de forma definitiva: instanciar `room1_luz_p1_chao.tscn` dentro de `School/Room 1`.

## Arquivos desta rodada
- Alterados: `scenes/main.tscn` (1 linha), `tests/etapa45_navigation_test.gd` (pendência virou verificação).
- Novos: `tests/player_monster_collision_test.gd`, `tests/lighting_compare_capture.gd`,
  `scenes/proposals/room1_luz_p1_chao.tscn`, `scenes/proposals/room1_luz_p2_parede.tscn`.
