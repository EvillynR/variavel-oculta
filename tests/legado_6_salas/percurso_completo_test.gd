extends SceneTree
## Prompt 1 — percurso completo: a protagonista é conduzida SÓ pelas ações do
## Input Map (move_*, interact) da sala inicial até cada uma das seis salas e
## até a Sala de Monitoramento, abrindo cada porta com a tecla E.
## As portas são destrancadas no início (unlock), mas começam FECHADAS.
## Os monstros ficam desligados: o despertar por entrada de sala ainda existe
## (monster_room_activation.gd, tratado no Prompt 5) e não é o objeto deste teste.
## Uso: godot --headless --fixed-fps 60 --path . --script res://tests/percurso_completo_test.gd

const T := preload("res://tests/test_input.gd")
## Etapas: ["andar", destino] | ["E"] (abre a porta à frente) | ["sala", id esperado]
const ROUTE := [
	["andar", Vector3(0, 0, -2.4)], ["E"], ["andar", Vector3(0, 0, -7.0)],
	["andar", Vector3(-2.2, 0, -10.5)], ["E"], ["andar", Vector3(-8.0, 0, -10.5)], ["andar", Vector3(-12.0, 0, -18.0)], ["sala", &"room_1"],
	["andar", Vector3(-8.0, 0, -10.5)], ["andar", Vector3(-1.0, 0, -10.5)], ["andar", Vector3(0, 0, -40.5)],
	["andar", Vector3(-2.2, 0, -40.5)], ["E"], ["andar", Vector3(-8.0, 0, -40.5)], ["andar", Vector3(-12.0, 0, -48.0)], ["sala", &"room_2"],
	["andar", Vector3(-8.0, 0, -40.5)], ["andar", Vector3(-1.0, 0, -40.5)], ["andar", Vector3(0, 0, -71.0)],
	["andar", Vector3(-2.2, 0, -71.0)], ["E"], ["andar", Vector3(-8.0, 0, -71.0)], ["andar", Vector3(-12.0, 0, -76.0)], ["sala", &"room_3"],
	["andar", Vector3(-8.0, 0, -71.0)], ["andar", Vector3(-1.0, 0, -71.0)], ["andar", Vector3(0, 0, -95.5)],
	["andar", Vector3(-2.2, 0, -95.5)], ["E"], ["andar", Vector3(-8.0, 0, -95.5)], ["andar", Vector3(-12.0, 0, -104.0)], ["sala", &"room_4"],
	["andar", Vector3(-8.0, 0, -95.5)], ["andar", Vector3(-1.0, 0, -95.5)], ["andar", Vector3(0, 0, -119.9)],
	["andar", Vector3(-2.2, 0, -119.9)], ["E"], ["andar", Vector3(-8.0, 0, -119.9)], ["andar", Vector3(-12.0, 0, -128.0)], ["sala", &"room_5"],
	["andar", Vector3(-8.0, 0, -119.9)], ["andar", Vector3(-1.0, 0, -119.9)], ["andar", Vector3(0, 0, -175.0)],
	["andar", Vector3(-2.2, 0, -175.0)], ["E"], ["andar", Vector3(-8.0, 0, -175.0)], ["andar", Vector3(-12.0, 0, -180.0)], ["sala", &"room_6"],
	["andar", Vector3(-8.0, 0, -175.0)], ["andar", Vector3(-1.0, 0, -175.0)], ["andar", Vector3(0, 0, -188.7)],
	["E"], ["andar", Vector3(0, 0, -193.0)], ["andar", Vector3(0, -6, -213.0)], ["andar", Vector3(0, -6, -219.0)],
	["andar", Vector3(-2.2, -6, -219.0)], ["E"], ["andar", Vector3(-8.0, -6, -219.0)], ["andar", Vector3(-11.0, -6, -222.0)], ["sala", &"sala_monitoramento"],
]

var main: Node
var player: CharacterBody3D
var rooms: RoomProgressManager
var passed := 0
var failed := 0
var entered: Array = []
var min_y := INF


func _initialize() -> void:
	Door.testing_force_open = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _phys(6)
	for m in get_nodes_in_group("monster"):
		m.process_mode = Node.PROCESS_MODE_DISABLED
	for d in get_nodes_in_group("door"):
		d.unlock()
	await _phys(2)
	_check("todas as portas destrancadas e FECHADAS no início", get_nodes_in_group("door").all(func(d): return d.get_state_name() == "CLOSED"), "")
	player = main.get_node("Player")
	rooms = get_first_node_in_group("room_progress_manager")
	rooms.room_entered.connect(func(r): entered.append(r))
	player.global_position = Vector3(0, 0.05, 1.5)
	await _phys(5)

	var step := 0
	var stuck := false
	var doors_opened := 0
	for e in ROUTE:
		step += 1
		match e[0]:
			"andar":
				var ok: bool = await _walk_to(e[1])
				if not ok:
					_check("etapa %d: chegar a %s" % [step, e[1]], false, "parou em %s" % player.global_position.snappedf(0.01))
					stuck = true
			"E":
				var door: Door = _nearest_door()
				var was := door.get_state_name()
				Input.action_press("interact")
				await process_frame
				await process_frame
				Input.action_release("interact")
				await _phys(35)
				var ok_open := door.is_open()
				if ok_open:
					doors_opened += 1
				_check("etapa %d: E abre %s" % [step, door.name], ok_open, "%s → %s" % [was, door.get_state_name()])
			"sala":
				await _phys(25)
				_check("%s: protagonista dentro e entrada registrada" % e[1], entered.has(e[1]) and rooms.current_room == e[1], "atual=%s" % rooms.current_room)
		if stuck:
			break
	T.release_moves()
	_check("percurso completo sem ficar presa", not stuck, "")
	_check("9 portas abertas pela tecla E", doors_opened == 9, str(doors_opened))
	_check("nunca caiu abaixo do piso do subsolo (y ≥ −6,1)", min_y >= -6.1, "y mín %.2f" % min_y)
	_check("terminou no piso da Sala de Monitoramento (y ≈ −6)", absf(player.global_position.y + 6.0) < 0.15, "y=%.2f" % player.global_position.y)
	print("salas visitadas: ", entered)
	print("RESULTADO: %d/%d testes passaram" % [passed, passed + failed])
	quit(1 if failed > 0 else 0)


func _nearest_door() -> Door:
	var best: Door = null
	for d in get_nodes_in_group("door"):
		if best == null or d.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position):
			best = d
	return best


## Anda até o ponto (só x/z) usando as ações reais. false = não chegou (preso).
func _walk_to(target: Vector3) -> bool:
	var last := player.global_position
	var still := 0
	for i in 2400:
		var to := target - player.global_position
		to.y = 0.0
		if to.length() < 0.35:
			T.release_moves()
			return true
		T.press_world(player, to.normalized())
		await physics_frame
		min_y = minf(min_y, player.global_position.y)
		if player.global_position.distance_to(last) < 0.004:
			still += 1
			if still > 90:
				T.release_moves()
				return false
		else:
			still = 0
		last = player.global_position
	T.release_moves()
	return false


func _phys(n: int) -> void:
	for i in n:
		await physics_frame


func _check(label: String, ok: bool, info: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("%s %s  %s" % ["OK    " if ok else "FALHA ", label, info])
