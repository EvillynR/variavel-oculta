extends RefCounted
## Utilitário dos testes (Prioridade 1): converte uma direção do mundo nas ações
## de movimento reais, no referencial de controle da protagonista
## (player.get_control_basis()), com intensidade analógica. Necessário porque a
## câmera agora gira e muda de composição: uma tecla sozinha não corresponde mais
## a uma direção fixa do mundo como na câmera lateral antiga.

static func press_world(player: Node, world_dir: Vector3) -> void:
	var basis: Basis = player.get_control_basis()
	var right := Vector3(basis.x.x, 0, basis.x.z).normalized()
	var fwd := Vector3(-basis.z.x, 0, -basis.z.z).normalized()
	var d := Vector3(world_dir.x, 0, world_dir.z).normalized()
	var lx := d.dot(right)
	var ly := d.dot(fwd)
	var mag := maxf(absf(lx), absf(ly))
	if mag < 0.0001:
		release_moves()
		return
	lx /= mag
	ly /= mag
	for pair in [["move_right", lx], ["move_left", -lx], ["move_forward", ly], ["move_back", -ly]]:
		if pair[1] > 0.01:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])


static func release_moves() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(a)


## Prompt 1: a escola agora tem portas físicas (scenes/world/door.tscn). Os
## testes que existiam antes delas percorrem vãos abertos; para continuarem
## medindo o que mediam (câmera, colisão, navegação), as portas são abertas à
## força (ignorando a tranca) logo depois de a cena entrar na árvore.
## Os testes de portas e de percurso completo NÃO usam isto.
## Funciona mesmo chamado antes do _ready das portas (Door.testing_force_open).
static func open_all_doors(tree: SceneTree) -> void:
	Door.testing_force_open = true
	# Prompt 3: a UI de enigmas passou a funcionar e abre (pausando o jogo) ao
	# ler o caderno da Room 1. Os testes anteriores a ela medem interação,
	# câmera e monstros — para eles, a UI não abre sozinha.
	load("res://scripts/puzzles/puzzle_ui.gd").testing_disable_auto_open = true
	for door in tree.get_nodes_in_group("door"):
		door.open(true, true)


## Pós-Prompt 2: a câmera padrão virou fixa (estilo diorama). Os testes que
## medem a câmera antiga (órbita, composições, colisão da lente) continuam
## valendo para esse estilo, que segue disponível (camera_style = ORBIT).
static func use_orbit_camera(tree: SceneTree) -> void:
	load("res://scripts/camera_controller.gd").testing_force_style = 0
	for c in tree.get_nodes_in_group("camera_controller"):
		c.camera_style = 0
		c.snap_to_target()


## Pós-Prompt 3: a colisão de cada móvel é uma caixa (StaticBody, grupo
## "prop_body") filha do CSG visível; para regras de visão/fade vale o CSG.
static func fade_target(c: Object) -> Object:
	if c is Node and (c as Node).is_in_group("prop_body") and (c as Node).get_parent() is GeometryInstance3D:
		return (c as Node).get_parent()
	# Versão 5: enfeites do pátio (lanterna de pedra) somem por inteiro.
	if c is Node and (c as Node).is_in_group("prop_body") and (c as Node).get_parent().is_in_group("camera_fade"):
		return (c as Node).get_parent()
	# Peças de porta (verga, batentes): o corpo de colisão tem a malha como
	# filha; o que aparece (ou é cortado pela câmera) é a malha.
	if c is StaticBody3D:
		for child in (c as Node).get_children():
			if child is GeometryInstance3D:
				return child
	return c
