extends SceneTree
## Colisão física entre a protagonista e o monstro (pendência da Etapa 4.5).
## Confere as camadas/máscaras reais e conduz a protagonista só pelas ações do
## Input Map, em quatro direções, andando, correndo e agachada.
## Uso: godot --headless --path . --script res://tests/player_monster_collision_test.gd

var passed := 0
var failed := 0
var main: Node
var player: CharacterBody3D
var camera: Camera3D
var polvo: MonsterController


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	preload("res://tests/test_input.gd").open_all_doors(self)  # Prompt 1: portas físicas
	await _physics(10)
	player = main.get_node("Player")
	camera = main.get_node("CameraController/Camera3D")
	polvo = main.get_node("Room1Gameplay/Polvo")
	while not polvo.is_navigation_ready():
		await _physics(1)

	print("--- camadas e máscaras reais (bit n = camada n)")
	print("INFO   protagonista: layer=%d %s  mask=%d %s" % [player.collision_layer, _bits(player.collision_layer), player.collision_mask, _bits(player.collision_mask)])
	print("INFO   Polvo:        layer=%d %s  mask=%d %s" % [polvo.collision_layer, _bits(polvo.collision_layer), polvo.collision_mask, _bits(polvo.collision_mask)])
	var floor_body: Object = main.get_node("School/Room 1/Floor")
	print("INFO   cenário (CSG): layer=%d %s" % [floor_body.collision_layer, _bits(floor_body.collision_layer)])
	_check("protagonista continua só na camada 1", player.collision_layer == 1, "")
	_check("protagonista colide com o cenário (camada 1)", player.get_collision_mask_value(1), "")
	_check("protagonista colide com monstros (camada 3)", player.get_collision_mask_value(3), "")
	_check("protagonista não ganhou outras camadas na máscara", player.collision_mask & ~(1 | 4) == 0, "mask=%d" % player.collision_mask)
	_check("Polvo continua só na camada 3", polvo.collision_layer == 4 and polvo.get_collision_layer_value(3), "")
	_check("Polvo colide com cenário e protagonista (camada 1)", polvo.get_collision_mask_value(1), "")

	print("--- protagonista contra o Polvo parado (área livre da Room 1)")
	var spot := Vector3(-10.0, polvo.global_position.y, -16.0)
	var dirs := {"leste→oeste": Vector3.LEFT, "oeste→leste": Vector3.RIGHT, "norte→sul": Vector3.FORWARD, "sul→norte": Vector3.BACK}
	for label in dirs:
		var d: Vector3 = dirs[label]
		for mods in [[], ["run"], ["crouch"]]:
			polvo._change_state(MonsterController.State.INACTIVE)
			polvo.global_position = spot
			polvo.velocity = Vector3.ZERO
			await _teleport(spot - d * 3.0 + Vector3(0, 0.05, 0))
			var frames := 150 if mods == ["crouch"] else 90
			var min_dist := INF
			for i in frames:
				await _step(d, mods)
				min_dist = minf(min_dist, _flat(player.global_position, polvo.global_position))
			var passed_through := (player.global_position - spot).dot(d) > 0.0
			var mode: String = mods[0] if mods.size() > 0 else "andando"
			_check("%s (%s): não atravessa" % [label, mode], not passed_through and min_dist > 0.75,
				"dist. mín %.2f m (contato 0,85)" % min_dist)
			_check("%s (%s): Polvo não foi empurrado" % [label, mode], _flat(polvo.global_position, spot) < 0.02,
				"%.3f m" % _flat(polvo.global_position, spot))
			_check("%s (%s): protagonista não subiu no Polvo" % [label, mode], player.global_position.y < 0.1, "y=%.2f" % player.global_position.y)

	print("--- contato de raspão: desliza pelo lado, não trava")
	polvo.global_position = spot
	await _teleport(Vector3(-6.0, 0.05, -15.6))
	for i in 150:
		await _step(Vector3.LEFT, [])
	_check("desvia do Polvo deslizando e segue caminho", player.global_position.x < spot.x - 1.5, "x=%.2f" % player.global_position.x)

	print("--- perseguição: alcance e contato")
	polvo.global_position = Vector3(-20.0, spot.y, -18.7)
	polvo.rotation.y = -PI / 2.0
	polvo._change_state(MonsterController.State.PATROLLING)
	await _teleport(Vector3(-15.5, 0.05, -18.7))
	var start := player.global_position
	var caught := [0]
	polvo.player_caught.connect(func(): caught[0] += 1)
	var min_d := INF
	for i in 360:
		await _physics(1)
		min_d = minf(min_d, _flat(player.global_position, polvo.global_position))
	_check("Polvo alcança a protagonista parada (player_caught uma vez)", caught[0] == 1, "%d" % caught[0])
	_check("Polvo para antes do contato físico", min_d > 0.84, "dist. mín %.2f" % min_d)
	_check("protagonista parada não é empurrada", _flat(player.global_position, start) < 0.05, "%.3f m" % _flat(player.global_position, start))
	# Correndo de encontro ao Polvo em perseguição.
	min_d = INF
	var mpos_before := polvo.global_position
	for i in 60:
		await _step(Vector3.LEFT, ["run"])
		min_d = minf(min_d, _flat(player.global_position, polvo.global_position))
	# Pode contorná-lo deslizando pelo lado; o que não pode é haver sobreposição.
	_check("correndo contra o Polvo em perseguição: sem sobreposição dos corpos", min_d > 0.8, "dist. mín %.2f (contato 0,85)" % min_d)
	_check("correndo contra o Polvo: ele não é empurrado para trás", polvo.global_position.x <= mpos_before.x + 0.05, "Δx %.3f" % (polvo.global_position.x - mpos_before.x))
	polvo._change_state(MonsterController.State.RETURNING)

	print("RESULTADO: %d/%d testes passaram" % [passed, passed + failed])
	quit(1 if failed > 0 else 0)


func _bits(v: int) -> String:
	var on := []
	for i in 32:
		if v & (1 << i):
			on.append(str(i + 1))
	return "(camadas %s)" % ", ".join(on)


func _step(world_dir: Vector3, mods: Array) -> void:
	# Prioridade 1: a câmera agora gira (setas) e muda de composição, então uma
	# tecla sozinha não equivale mais a uma direção do mundo. A direção é
	# convertida no referencial de controle real da protagonista, com intensidade
	# analógica nas ações (o que o teste quer verificar é a colisão, não a câmera).
	var basis: Basis = player.get_control_basis() if player.has_method("get_control_basis") else camera.global_basis
	var right := Vector3(basis.x.x, 0, basis.x.z).normalized()
	var fwd := Vector3(-basis.z.x, 0, -basis.z.z).normalized()
	var lx := world_dir.dot(right)
	var ly := world_dir.dot(fwd)
	var mag := maxf(absf(lx), absf(ly))
	lx /= mag
	ly /= mag
	for pair in [["move_right", lx], ["move_left", -lx], ["move_forward", ly], ["move_back", -ly]]:
		if pair[1] > 0.01:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])
	for m in mods:
		Input.action_press(m)
	await physics_frame
	await process_frame
	for a in ["move_forward", "move_back", "move_left", "move_right", "run", "crouch"]:
		Input.action_release(a)


func _teleport(p: Vector3) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = p
	await _physics(3)
	main.get_node("CameraController").snap_to_target()
	await _physics(2)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("%s %s  %s" % ["OK    " if ok else "FALHA ", name, detail])
