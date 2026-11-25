extends SceneTree
## Testes headless de comportamento da câmera. Simula as ações de input reais
## (Input.action_press) sem alterar a protagonista.

var results := []

func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	# Versão 5: o jogo começa no pátio; a órbita é medida a partir do corredor,
	# então a protagonista nasce lá (como antes, quando o jogo começava no corredor).
	main.get_node("Player").position = Vector3(0, 0.05, -8)
	root.add_child(main)
	preload("res://tests/test_input.gd").open_all_doors(self)  # Prompt 1: portas físicas
	preload("res://tests/test_input.gd").use_orbit_camera(self)  # mede o estilo de órbita (opcional)
	await _frames(5)
	var player: CharacterBody3D = main.get_node("Player")
	var controller: Node3D = main.get_node("CameraController")
	var camera: Camera3D = controller.get_node("Camera3D")

	# 1. Início fora de zona: a câmera precisa se mover e ter FOV válido.
	player.global_position = Vector3(0, 0.05, -16)
	await _frames(3)
	var before := camera.global_position
	await _frames(90)
	_check("início fora de zona: câmera acompanha", camera.global_position.distance_to(before) > 1.0 and camera.fov > 20.0,
		"moveu %.2f m, fov %.1f" % [camera.global_position.distance_to(before), camera.fov])

	# 2. Caminhada pelo corredor: sem saltos, sem NaN, yaw limitado, direção de controle estável.
	controller.snap_to_target()
	var max_step := 0.0
	var max_yaw_dev := 0.0
	var last := camera.global_position
	var min_dir_dot := 1.0
	var last_fwd := _control_forward(player)
	# Na vista lateral o corredor (eixo Z) corresponde a esquerda/direita.
	var walk_action := "move_right" if camera.global_basis.x.z < 0.0 else "move_left"
	Input.action_press(walk_action)
	Input.action_press("run")
	var cuts0: int = controller.cut_count
	var cuts := 0
	await physics_frame
	last_fwd = _control_forward(player)  # mede com a tecla já segurada
	for i in 150:
		await process_frame
		if controller.cut_count != cuts0:
			# corte limpo ao atravessar a porta entre os corredores (Prioridade 1)
			cuts += controller.cut_count - cuts0
			cuts0 = controller.cut_count
		else:
			max_step = maxf(max_step, camera.global_position.distance_to(last))
		last = camera.global_position
		var fwd := _control_forward(player)
		min_dir_dot = minf(min_dir_dot, fwd.dot(last_fwd))
		last_fwd = fwd
		max_yaw_dev = maxf(max_yaw_dev, camera.global_position.x)
	Input.action_release(walk_action)
	Input.action_release("run")
	_check("corredor: sem saltos fora do corte da porta (passo máx < 0,5 m/frame, ≤ 1 corte)", max_step < 0.5 and cuts <= 1, "passo máx %.3f m, %d corte(s)" % [max_step, cuts])
	# Prioridade 1: a câmera gira/troca de composição; o que precisa ficar estável é
	# o referencial de CONTROLE da protagonista, e a lente tem de ficar no corredor.
	_check("corredor: lente sempre dentro do corredor", max_yaw_dev < 2.9, "x máx %.2f (parede leste em 2,9)" % max_yaw_dev)
	_check("corredor: referência de controle estável entre frames", min_dir_dot > 0.999, "dot mín %.5f" % min_dir_dot)
	_check("corredor: protagonista andou", player.global_position.z < -17.0, "z = %.2f" % player.global_position.z)

	# 3. Entrar na Room 1 pela porta ativa o corte; voltar ao corredor restaura.
	var wall: GeometryInstance3D = main.get_node("School/Corridor/FrontWallProfessorRoom_Lower")
	player.global_position = Vector3(-8, 0.05, -18)
	await _frames(4)
	_check("Room 1: zona ativa", controller.current_zone != null and controller.current_zone.name == "Room1Camera", str(controller.current_zone))
	# Prioridade 1: a lente fica dentro da sala; o corte de maquete só esconde o
	# que realmente bloqueia a visão — a parede do corredor fica atrás da câmera.
	_check("Room 1: lente dentro da sala e parede do corredor visível", camera.global_position.x < -3.6 and wall.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "x %.2f" % camera.global_position.x)
	player.global_position = Vector3(0, 0.05, -18)
	await _frames(4)
	_check("corredor: parede restaurada", wall.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "cast_shadow=%d" % wall.cast_shadow)

	# 4. Parede escondida continua com colisão: andar contra ela a partir da sala.
	player.global_position = Vector3(-6, 0.05, -18)
	await _frames(4)
	var cam_right := camera.global_basis.x
	# Descobre qual ação leva para +X (direção do corredor) com a câmera atual.
	var action := "move_right" if cam_right.x > 0.0 else "move_left"
	var fwd_axis := -camera.global_basis.z
	if absf(fwd_axis.x) > absf(cam_right.x):
		action = "move_forward" if fwd_axis.x > 0.0 else "move_back"
	Input.action_press(action)
	await _frames(120)
	Input.action_release(action)
	_check("colisão preservada na parede escondida", player.global_position.x < -3.3, "x = %.2f (parede em -3,5)" % player.global_position.x)

	# 5. Tensão de perseguição abre o FOV e afasta a câmera (num ponto com espaço:
	# no corredor a lente agora é contida pelas paredes).
	player.global_position = Vector3(-19, 0.05, -21.5)
	await _frames(4)
	controller.snap_to_target()
	await _frames(60)
	var calm_fov := camera.fov
	var calm_dist := camera.global_position.distance_to(player.global_position)
	controller.set_tension(1.0)
	await _frames(240)
	_check("tensão: FOV maior e câmera mais distante", camera.fov > calm_fov + 3.0 and camera.global_position.distance_to(player.global_position) > calm_dist + 1.0,
		"fov %.1f→%.1f, dist %.2f→%.2f" % [calm_fov, camera.fov, calm_dist, camera.global_position.distance_to(player.global_position)])
	controller.set_tension(0.0)

	var failed := results.filter(func(r): return not r)
	print("RESULTADO: %d/%d testes passaram" % [results.size() - failed.size(), results.size()])
	quit(1 if failed.size() > 0 else 0)


func _control_forward(p: Node) -> Vector3:
	var b: Basis = p.get_control_basis()
	return Vector3(-b.z.x, 0.0, -b.z.z).normalized()


func _flat_forward(camera: Camera3D) -> Vector3:
	var f := -camera.global_basis.z
	f.y = 0.0
	return f.normalized()


func _check(name: String, ok: bool, detail: String) -> void:
	results.append(ok)
	print("%s  %s  %s" % ["OK   " if ok else "FALHA", name, detail])


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
