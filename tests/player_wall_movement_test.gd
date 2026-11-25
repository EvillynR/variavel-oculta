extends SceneTree
## Prioridade 1 — movimento junto a paredes, portas e móveis.
## Usa as ações reais (move_*), convertidas da direção desejada no mundo para o
## referencial de controle que a protagonista usa (câmera / controle travado).
## Mede o avanço real e os quadros "presa" (input pressionado sem avanço).
## Uso: godot --headless -s tests/player_wall_movement_test.gd

var results := []
var main: Node
var player: CharacterBody3D
var controller: Node3D

# nome, início, direção no mundo (XZ), quadros, avanço mínimo exigido (m) no eixo
# de interesse, eixo de interesse (vetor XZ), posição proibida (função de checagem)
const CASES := [
	# Deslizar ao longo da parede leste invisível do corredor empurrando contra ela (30°).
	["corredor: desliza na parede leste", Vector3(2.4, 0.05, -14), Vector3(0.5, 0, -0.866), 120, 4.0, Vector3(0, 0, -1)],
	# Batente oeste da porta corredor 1 → 2 (x -3,49..-1,99), vindo encostada na parede oeste.
	["porta corredor 1 → 2 (batente oeste, 20°)", Vector3(-3.0, 0.05, -24), Vector3(0.36, 0, -0.93), 160, 6.0, Vector3(0, 0, -1)],
	# Room 1: andar encostada na parede norte (até a estante 2x em x -10).
	["Room 1: desliza na parede norte", Vector3(-6, 0.05, -8.0), Vector3(-0.866, 0, 0.5), 66, 2.4, Vector3(-1, 0, 0)],
	# Room 1: parede oeste.
	["Room 1: desliza na parede oeste", Vector3(-23.0, 0.05, -10), Vector3(-0.5, 0, -0.866), 150, 6.0, Vector3(0, 0, -1)],
	# Porta do corredor para a Room 1 (vão z -12..-9).
	["porta corredor → Room 1 (reta)", Vector3(0, 0.05, -10.5), Vector3(-1, 0, 0), 150, 6.0, Vector3(-1, 0, 0)],
	# Porta pegando o batente em diagonal: tem de escorregar para dentro.
	["porta corredor → Room 1 (diagonal no batente)", Vector3(0, 0.05, -8.0), Vector3(-0.85, 0, -0.53), 180, 5.0, Vector3(-1, 0, 0)],
	# Porta entre corredor 1 e corredor 2 (vão x -2..2 em z -28,4) vindo encostada no lado.
	["porta corredor 1 → 2 (batente leste, 20°)", Vector3(2.4, 0.05, -25), Vector3(-0.36, 0, -0.93), 160, 6.0, Vector3(0, 0, -1)],
	# Ângulo pequeno (10°) contra os batentes: era aqui que a protagonista grudava
	# (wall_min_slide_angle padrão = 15°).
	["porta corredor 1 → 2 (batente leste, 10°)", Vector3(2.4, 0.05, -25), Vector3(-0.17, 0, -0.985), 170, 6.0, Vector3(0, 0, -1)],
	["porta corredor 1 → 2 (batente oeste, 10°)", Vector3(-3.0, 0.05, -24), Vector3(0.17, 0, -0.985), 170, 6.0, Vector3(0, 0, -1)],
	["porta Room 1 → corredor (batente, 10°)", Vector3(-5.0, 0.05, -12.6), Vector3(0.985, 0, 0.17), 170, 4.0, Vector3(1, 0, 0)],
	# Contornar a carteira 01 empurrando contra a lateral dela.
	["Room 1: contorna carteira", Vector3(-12.6, 0.05, -18.0), Vector3(-0.94, 0, -0.34), 160, 3.0, Vector3(-1, 0, 0)],
	# Sala inicial → corredor (porta z -4, vão x -1.5..1.5) começando no canto.
	["sala inicial → corredor (canto)", Vector3(-2.5, 0.05, -2.5), Vector3(0.45, 0, -0.89), 150, 3.0, Vector3(0, 0, -1)],
	# Room 2: porta (vão z -42..-39) a partir do corredor 2.
	["porta corredor 2 → Room 2", Vector3(0, 0.05, -40.5), Vector3(-1, 0, 0), 150, 6.0, Vector3(-1, 0, 0)],
	# Room 4 (nó Room 3): porta z -97..-94.
	["porta corredor 3 → nó Room 3", Vector3(0, 0.05, -95.5), Vector3(-1, 0, 0), 150, 6.0, Vector3(-1, 0, 0)],
	# Room 5 (nó Room 4): porta z -121,4..-118,4.
	["porta corredor 4 → nó Room 4", Vector3(0, 0.05, -119.9), Vector3(-1, 0, 0), 150, 6.0, Vector3(-1, 0, 0)],
	# (História de Yuko: a sala de Artes foi removida; a porta dela virou parede.)
	# Canto: empurrar direto contra o canto não pode tremer nem atravessar.
	["Room 1: canto noroeste (sem atravessar)", Vector3(-22, 0.05, -9), Vector3(-0.7, 0, 0.7), 120, -1.0, Vector3(-1, 0, 0)],
]


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	preload("res://tests/test_input.gd").open_all_doors(self)  # Prompt 1: portas físicas
	player = main.get_node("Player")
	controller = main.get_node("CameraController")
	await _phys(10)

	for c in CASES:
		await _run_case(c)

	# Agachar sob nada não pode deixar a protagonista enterrada nem flutuando.
	_release_all()
	player.global_position = Vector3(-10, 0.05, -18)
	await _phys(20)
	# Modelo animado da Yuko: mede pelos ossos (pés e cabeça) no lugar da
	# antiga cápsula esticada.
	var shape := player.get_node("CollisionShape3D") as CollisionShape3D
	var cap := shape.shape as CapsuleShape3D
	var ext := _bone_extent()
	_check("modelo apoiado no chão (em pé)", ext.x >= -0.02 and ext.x < 0.15, "pés a %.2f m do chão" % ext.x)
	_check("modelo do tamanho da colisão (em pé)", ext.y > 1.4 and ext.y <= cap.height + 0.05, "topo dos ossos %.2f m, colisão %.2f m" % [ext.y, cap.height])
	Input.action_press("crouch")
	await _phys(30)
	ext = _bone_extent()
	_check("modelo apoiado no chão (agachada)", ext.x >= -0.02 and ext.x < 0.15, "pés a %.2f m do chão" % ext.x)
	Input.action_release("crouch")
	await _phys(10)

	# Colisão com o Polvo continua ativa (máscara 5 preservada).
	_check("collision_mask = 5 preservada", player.collision_mask == 5, "mask = %d" % player.collision_mask)

	var ok := 0
	for r in results:
		if r: ok += 1
	print("RESULTADO: %d/%d testes passaram" % [ok, results.size()])
	quit()


func _run_case(c: Array) -> void:
	_release_all()
	player.velocity = Vector3.ZERO
	player.global_position = c[1]
	await _phys(6)
	if controller.has_method("snap_to_target"):
		controller.snap_to_target()
	await _phys(4)
	var dir: Vector3 = (c[2] as Vector3).normalized()
	var axis: Vector3 = c[5]
	var start: Vector3 = player.global_position
	var stuck := 0
	var max_stuck := 0
	var last := start
	var min_x := 1e9
	var max_x := -1e9
	var min_z := 1e9
	var max_z := -1e9
	for i in int(c[3]):
		_press_world(dir)
		await physics_frame
		var p := player.global_position
		var step := Vector2(p.x - last.x, p.z - last.z).length()
		if step < 0.004:
			stuck += 1
			max_stuck = maxi(max_stuck, stuck)
		else:
			stuck = 0
		last = p
		min_x = minf(min_x, p.x); max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.z); max_z = maxf(max_z, p.z)
	_release_all()
	var progress := (player.global_position - start).dot(axis)
	var required: float = c[4]
	if required < 0.0:
		# Canto: não pode sair da sala (parede oeste em -23,4, norte em -7,6).
		var inside := min_x > -23.45 + 0.2 and max_z < -7.6 - 0.2
		_check(c[0], inside, "x mín %.2f, z máx %.2f" % [min_x, max_z])
	else:
		_check(c[0], progress >= required and max_stuck < 15,
			"avanço %.2f m (mín %.1f), maior trecho parado %d quadros, fim %s" % [progress, required, max_stuck, _v(player.global_position)])


## Converte a direção no mundo para as ações, no mesmo referencial que a
## protagonista usa para interpretar o input.
func _press_world(dir: Vector3) -> void:
	var basis: Basis
	if player.has_method("get_control_basis"):
		basis = player.get_control_basis()
	else:
		basis = get_root().get_viewport().get_camera_3d().global_basis
	var right := Vector3(basis.x.x, 0, basis.x.z).normalized()
	var fwd := Vector3(-basis.z.x, 0, -basis.z.z).normalized()
	var lx := dir.dot(right)
	var ly := dir.dot(fwd)
	var m := maxf(absf(lx), absf(ly))
	lx /= m
	ly /= m
	_set_action("move_right", maxf(lx, 0.0))
	_set_action("move_left", maxf(-lx, 0.0))
	_set_action("move_forward", maxf(ly, 0.0))
	_set_action("move_back", maxf(-ly, 0.0))


func _set_action(a: String, s: float) -> void:
	if s > 0.01:
		Input.action_press(a, s)
	else:
		Input.action_release(a)


func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "run", "crouch"]:
		Input.action_release(a)


func _check(label: String, ok: bool, info: String) -> void:
	results.append(ok)
	print("%s %s  %s" % ["OK    " if ok else "FALHOU", label, info])


func _v(p: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z]


func _phys(n: int) -> void:
	for i in n:
		await physics_frame


## (menor, maior) altura dos ossos do modelo em relação aos pés da protagonista.
func _bone_extent() -> Vector2:
	var sk: Skeleton3D = player.get_node("Visual").find_children("*", "Skeleton3D", true, false)[0]
	var lo := INF
	var hi := -INF
	for b in sk.get_bone_count():
		var y: float = (sk.global_transform * sk.get_bone_global_pose(b)).origin.y - player.global_position.y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return Vector2(lo, hi)
