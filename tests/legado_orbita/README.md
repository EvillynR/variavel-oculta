# Testes da câmera de órbita (não usada no jogo)

O jogo usa a câmera FIXA (estilo diorama, Little Nightmares). A câmera de órbita
continua no código (`camera_style = ORBIT`), mas ninguém joga com ela.

`camera_geometry_sweep_test.gd` mede a órbita encostando nas paredes. Com os
móveis em escala 3x (estantes de 6,9 m nas paredes laterais) ela encosta nas
estantes — não afeta o jogo. A câmera do jogo é medida por
`tests/camera_occlusion_test.gd` e `tests/camera_behavior_test.gd`.
