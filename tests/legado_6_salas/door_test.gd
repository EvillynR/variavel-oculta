extends SceneTree
## Prompt 1 — portas físicas (scenes/world/door.tscn), com a cena real.
## Estados, tranca pela progressão, tranca manual + efeito unlock_door, tecla E
## pelo PlayerInteractor real, bloqueio físico, links de navegação e volumes de
## sala que não podem disparar com a protagonista no corredor.
## Uso: godot --headless --fixed-fps 60 --path . --script res://tests/door_test.gd

const T := preload("res://tests/test_input.gd")
## porta, lado do corredor, lado da sala, id da sala
const SIDE_DOORS := [
	["PortaRoom1", Vector3(-2.2, 0.05, -10.5), Vector3(-6.0, 0.05, -10.5), &"room_1"],
	["PortaRoom2", Vector3(-2.2, 0.05, -40.5), Vector3(-6.0, 0.05, -40.5), &"room_2"],
	["PortaArtes", Vector3(-2.2, 0.05, -71.0), Vector3(-6.0, 0.05, -71.0), &"room_3"],
	["PortaRoom3", Vector3(-2.2, 0.05, -95.5), Vector3(-6.0, 0.05, -95.5), &"room_4"],
	["PortaRoom4", Vector3(-2.2, 0.05, -119.9), Vector3(-6.0, 0.05, -119.9), &"room_5"],
	["PortaMusica", Vector3(-2.2, 0.05, -175.0), Vector3(-6.0, 0.05, -175.0), &"room_6"],
	["PortaMonitoramento", Vector3(-2.2, -5.95, -219.0), Vector3(-6.0, -5.95, -219.0), &"sala_monitoramento"],
]

var main: Node
var player: CharacterBody3D
var rooms: RoomProgressManager
var router: InteractionRouter
var passed := 0
var failed := 0
var entered: Array = []


func _initialize() -> void:
	Door.testing_force_open = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _phys(6)
	for m in get_nodes_in_group("monster"):
		m.process_mode = Node.PROCESS_MODE_DISABLED   # isola as portas dos monstros
	player = main.get_node("Player")
	rooms = get_first_node_in_group("room_progress_manager")
	router = main.find_children("*", "InteractionRouter", true, false)[0]
	rooms.room_entered.connect(func(r): entered.append(r))

	print("--- estados iniciais")
	var doors := get_nodes_in_group("door")
	_check("9 portas instaladas", doors.size() == 9, str(doors.size()))
	var expected := {"PortaInicial": "CLOSED", "PortaRoom1": "CLOSED", "PortaRoom2": "LOCKED", "PortaArtes": "CLOSED",
		"PortaRoom3": "CLOSED", "PortaRoom4": "CLOSED", "PortaMusica": "CLOSED", "PortaSubsolo": "LOCKED", "PortaMonitoramento": "CLOSED"}
	for d in doors:
		_check("%s começa %s" % [d.name, expected[String(d.name)]], d.get_state_name() == expected[String(d.name)], d.get_state_name())

	print("--- porta fechada bloqueia; volume da sala não dispara do corredor")
	for spec in SIDE_DOORS:
		var d: Door = main.get_node("School/Doors/" + spec[0])
		entered.clear()
		await _place(spec[1])
		await _walk_dir(Vector3.LEFT, 90)
		var pos := player.global_position
		_check("%s fechada: protagonista para na porta" % spec[0], pos.x > -3.6, "x=%.2f" % pos.x)
		await _phys(25)
		_check("%s fechada: encostada na porta, %s não registra entrada" % [spec[0], spec[3]], not entered.has(spec[3]), str(entered))

	print("--- tecla E (PlayerInteractor real)")
	var d1: Door = main.get_node("School/Doors/PortaRoom1")
	await _place(SIDE_DOORS[0][1])
	await _phys(4)
	var interactor: PlayerInteractor = get_first_node_in_group("player_interactor")
	_check("porta é o alvo do E pelo lado do corredor (linha de visada ignora a própria folha)", interactor.get_current_target() != null and interactor.get_current_target().get_parent() == d1, str(interactor.get_current_target()))
	await _press_e()
	await _phys(40)
	_check("E abre a porta", d1.is_open(), d1.get_state_name())
	_check("prompt vira \"E  Fechar\"", interactor.get_current_target() != null and interactor.get_current_target().prompt_text == "E  Fechar", "")
	entered.clear()
	await _walk_dir(Vector3.LEFT, 120)
	await _phys(25)
	_check("porta aberta: atravessa para dentro da sala", player.global_position.x < -6.0, "x=%.2f" % player.global_position.x)
	_check("porta aberta: entrada na room_1 registrada", entered.has(&"room_1"), str(entered))
	await _place(Vector3(-3.5, 0.05, -10.5))   # bem no vão
	await _phys(6)
	await _press_e()
	await _phys(30)
	_check("não fecha com a protagonista no vão", d1.is_open(), d1.get_state_name())
	await _place(Vector3(-1.6, 0.05, -10.5))
	await _phys(6)
	print("   alvo do E: ", interactor.get_current_target().get_parent().name if interactor.get_current_target() else "nenhum", " vão ocupado: ", d1._doorway_blocked())
	await _press_e()
	await _phys(40)
	_check("E fecha a porta quando o vão está livre", d1.get_state_name() == "CLOSED", d1.get_state_name())

	print("--- abrir e FECHAR de onde se aperta o E (defeito relatado: não fechava mais)")
	var dm: Door = main.get_node("School/Doors/PortaMusica")
	for spot in [Vector3(-2.3, 0.05, -175.0), Vector3(-2.4, 0.05, -176.2), Vector3(-4.8, 0.05, -175.0)]:
		await _place(spot)
		await _phys(4)
		if not dm.is_open():
			await _press_e()
			await _phys(40)
		_check("em %s: porta aberta" % spot, dm.is_open(), dm.get_state_name())
		await _press_e()
		await _phys(40)
		_check("em %s: E fecha a porta" % spot, dm.get_state_name() == "CLOSED", dm.get_state_name() + " " + router._feedback_label.text)
	# do lado do giro (dentro da sala, a 1,2 m): a folha não pode prender a protagonista
	_check("fechou com ela na área do giro: colisão das folhas espera", dm._collision_pending, "")
	await _place(Vector3(-8.0, 0.05, -175.0))
	await _phys(6)
	_check("saiu da área do giro: colisão das folhas volta", not dm._collision_pending and not dm._leaf_shapes[0].disabled, "")

	print("--- tranca pela progressão (room_2 só abre depois da room_1 concluída)")
	var d2: Door = main.get_node("School/Doors/PortaRoom2")
	await _place(SIDE_DOORS[1][1])
	await _phys(4)
	await _press_e()
	await _phys(20)
	_check("room_2 trancada: E não abre", not d2.is_open() and d2.get_state_name() == "LOCKED", d2.get_state_name())
	_check("mensagem \"Trancada.\" na tela", router._feedback_panel.visible and router._feedback_label.text == "Trancada.", router._feedback_label.text)
	_check("prompt da porta trancada = \"Trancada\"", interactor.get_current_target() != null and interactor.get_current_target().prompt_text == "Trancada", "")
	rooms._set_state(&"room_1", RoomData.RoomState.COMPLETED)   # conclusão da room_1 (atalho de teste)
	await _phys(2)
	_check("room_1 concluída → room_2 AVAILABLE → porta destrancada", d2.get_state_name() == "CLOSED", d2.get_state_name())
	await _press_e()
	await _phys(30)
	_check("agora E abre a room_2", d2.is_open(), d2.get_state_name())

	print("--- tranca manual + efeito unlock_door (acesso ao subsolo)")
	var ds: Door = main.get_node("School/Doors/PortaSubsolo")
	_check("subsolo trancado e open() sem força recusa", not ds.open() and ds.get_state_name() == "LOCKED", ds.get_state_name())
	var probe := InteractiveObjectData.new()
	probe.id = &"room_1.teste_alavanca"
	probe.room_id = &"room_1"
	probe.effects = [{"type": "unlock_door", "door_id": "sala_monitoramento.porta_subsolo"}] as Array[Dictionary]
	GameData.get_instance().objects.append(probe)
	router._on_interaction_performed(&"room_1.teste_alavanca", &"manipular", null)
	GameData.get_instance().objects.erase(probe)
	await _phys(2)
	_check("efeito unlock_door destranca o subsolo", ds.get_state_name() == "CLOSED", ds.get_state_name())

	print("--- navegação: link só com a porta aberta")
	var map: RID = main.get_world_3d().navigation_map
	var room3_door: Door = main.get_node("School/Doors/PortaRoom3")
	var from := Vector3(0, 0, -95.5)
	var to := Vector3(-13.5, 0, -104.0)
	await _phys(3)
	var closed_path := NavigationServer3D.map_get_path(map, from, to, true, 8 | 64)
	_check("porta fechada: sem rota corredor → sala (camadas 4|7)", closed_path.is_empty() or _flat(closed_path[closed_path.size() - 1], to) > 3.0, "")
	room3_door.open(true, true)
	await _phys(3)
	var open_path := NavigationServer3D.map_get_path(map, from, to, true, 8 | 64)
	_check("porta aberta: rota corredor → sala pelo link", not open_path.is_empty() and _flat(open_path[open_path.size() - 1], to) < 1.0, "%d pontos" % open_path.size())

	print("RESULTADO: %d/%d testes passaram" % [passed, passed + failed])
	quit(1 if failed > 0 else 0)


func _press_e() -> void:
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame


func _walk_dir(dir: Vector3, frames: int) -> void:
	for i in frames:
		T.press_world(player, dir)
		await physics_frame
	T.release_moves()


func _place(p: Vector3) -> void:
	T.release_moves()
	player.global_position = p
	player.velocity = Vector3.ZERO
	await _phys(3)


func _phys(n: int) -> void:
	for i in n:
		await physics_frame


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _check(label: String, ok: bool, info: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("%s %s  %s" % ["OK    " if ok else "FALHA ", label, info])
