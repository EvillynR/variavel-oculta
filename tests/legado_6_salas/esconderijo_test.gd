extends SceneTree
## Prompt 2 — esconderijos (armário alto e embaixo da mesa do professor) com a
## cena real e o Polvo real (Room 1). A entrada/saída usa a tecla E de verdade.
## Uso: godot --headless --fixed-fps 60 --path . --script res://tests/esconderijo_test.gd

const T := preload("res://tests/test_input.gd")
var main: Node
var player: CharacterBody3D
var polvo: MonsterController
var locker: HidingSpot
var desk: HidingSpot
var caught := 0
var passed := 0
var failed := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _phys(6)
	player = main.get_node("Player")
	polvo = main.get_node("Room1Gameplay/Polvo")
	for m in get_nodes_in_group("monster"):
		if m != polvo:
			m.process_mode = Node.PROCESS_MODE_DISABLED
	polvo.player_caught.connect(func(): caught += 1)
	for s in get_nodes_in_group("hiding_spot"):
		if s.spot_id == &"room_1.esconderijo_armario":
			locker = s
		elif s.spot_id == &"room_1.esconderijo_mesa":
			desk = s
	_check("12 esconderijos na escola (armário + mesa em cada sala)", get_nodes_in_group("hiding_spot").size() == 12, str(get_nodes_in_group("hiding_spot").size()))
	_check("Room 1 tem armário e mesa-esconderijo", locker != null and desk != null, "")

	print("--- tecla E: entrar e sair")
	await _place(locker.get_front_position())
	await _press_e()
	_check("E esconde a protagonista no armário", player.is_hidden() and locker.is_occupied(), "")
	_check("escondida: dentro do móvel, sem colisão, modelo oculto", player.global_position.distance_to(locker.get_hide_position()) < 0.05 and player.collision_layer == 0 and not player.visual.visible, "")
	var hud := main.get_node_or_null("HidingHUD") as CanvasLayer
	_check("câmera/HUD mostram o estado: vinheta + \"ESCONDIDA — E para sair\"", hud != null and hud.visible, "")
	var ctl = get_first_node_in_group("camera_controller")
	await _phys(30)
	_check("câmera enquadra a frente do esconderijo (lente fora do móvel)", ctl.camera.global_position.distance_to(locker.get_front_position()) > 1.5 and not ctl._lens_touches(ctl.camera.global_position), "%.2f m" % ctl.camera.global_position.distance_to(locker.get_front_position()))
	await _phys(10)
	await _press_e()
	_check("E de novo sai pela frente do móvel", not player.is_hidden() and player.global_position.distance_to(locker.get_front_position()) < 0.3 and player.visual.visible and not hud.visible, "")
	await _place(desk.get_front_position())
	await _press_e()
	_check("mesa do professor: E esconde embaixo da mesa", player.is_hidden() and desk.is_occupied(), "")
	await _phys(5)
	await _press_e()
	_check("mesa do professor: E sai", not player.is_hidden(), "")

	print("--- monstro em CHASING NÃO viu a entrada → perde a protagonista")
	polvo.activate(&"teste_esconderijo", polvo.global_position, true)
	await _phys(3)
	_face(polvo, Vector3(1, 0, 0))   # olhando para +X: o armário fica fora do cone
	await _place(locker.get_front_position())
	polvo._last_known_position = locker.get_front_position()
	polvo._change_state(MonsterController.State.CHASING)
	await _press_e()
	_check("ao se esconder, o Polvo não é testemunha", player.is_hidden() and not player.is_witness(polvo), "")
	var left_chase := false
	for i in 60 * 12:
		await physics_frame
		if polvo.state != MonsterController.State.CHASING:
			left_chase = true
	_check("Polvo sai de CHASING (perdeu a protagonista)", left_chase and polvo.state != MonsterController.State.CHASING, polvo.get_state_name())
	_check("escondida e não vista: nenhuma captura em 12 s", caught == 0, "capturas=%d" % caught)
	await _press_e()
	await _phys(5)

	print("--- escondida, à vista e de frente: continua invisível")
	await _place(desk.get_front_position())
	_face(polvo, Vector3(1, 0, 0))
	polvo._change_state(MonsterController.State.PATROLLING)
	await _phys(2)
	await _press_e()
	polvo.global_position = desk.get_front_position() + Vector3(4.0, 0, 0)
	_face(polvo, desk.get_front_position() - polvo.global_position)
	var ever_seen := false
	for i in 120:
		await physics_frame
		_face(polvo, desk.get_front_position() - polvo.global_position)
		if polvo.perception.can_see(player) or polvo.state == MonsterController.State.CHASING:
			ever_seen = true
	_check("Polvo a 4 m olhando para a mesa não a enxerga", not ever_seen, polvo.get_state_name())
	await _press_e()
	await _phys(5)

	print("--- monstro VIU a protagonista entrar → vai até o esconderijo e captura")
	await _place(locker.get_front_position())
	polvo.global_position = locker.get_front_position() + Vector3(5.0, 0, 2.0)
	_face(polvo, locker.get_front_position() - polvo.global_position)
	polvo._change_state(MonsterController.State.CHASING)
	await _phys(3)
	_check("antes de entrar, o Polvo a enxerga", polvo.perception.can_see(player), "")
	await _press_e()
	_check("ao se esconder à vista, o Polvo vira testemunha", player.is_hidden() and player.is_witness(polvo), "")
	for i in 60 * 8:
		await physics_frame
		if caught > 0:
			break
	_check("testemunha alcança o esconderijo e captura", caught == 1, "capturas=%d, distância %.2f" % [caught, polvo.global_position.distance_to(locker.get_front_position())])
	paused = false

	print("RESULTADO: %d/%d testes passaram" % [passed, passed + failed])
	quit(1 if failed > 0 else 0)


func _face(m: Node3D, dir: Vector3) -> void:
	dir.y = 0.0
	m.rotation.y = atan2(-dir.x, -dir.z)
	m._look_yaw_target = null


func _press_e() -> void:
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	await _phys(2)


func _place(p: Vector3) -> void:
	T.release_moves()
	player.global_position = p
	player.velocity = Vector3.ZERO
	await _phys(4)


func _phys(n: int) -> void:
	for i in n:
		await physics_frame


func _check(label: String, ok: bool, info: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("%s %s  %s" % ["OK    " if ok else "FALHA ", label, info])
