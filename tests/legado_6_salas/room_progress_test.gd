extends SceneTree
## Etapa 5, Fase 2 — volumes de sala, progressão e NarrativeManager.
## Conduz a protagonista só pelas ações do Input Map. Banco narrativo mínimo
## (Room 1 / Polvo, conteúdo de TESTE). Volumes extras usados no teste de
## salas adjacentes são criados só em memória e removidos ao final.
## Uso: godot --headless --path . --script res://tests/room_progress_test.gd

var passed := 0
var failed := 0
var main: Node
var player: CharacterBody3D
var camera: Camera3D
var controller: Node3D
var rooms: RoomProgressManager
var narrative: NarrativeManager
var puzzles: PuzzleManager
var clues: ClueManager
var polvo: MonsterController
var log := {"entered": [], "exited": [], "changed": [], "completed": [], "events": []}

const S := RoomData.RoomState


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	preload("res://tests/test_input.gd").open_all_doors(self)  # Prompt 1: portas físicas
	await _physics(10)
	player = main.get_node("Player")
	controller = main.get_node("CameraController")
	camera = controller.get_node("Camera3D")
	rooms = main.get_node("Systems/RoomProgressManager")
	narrative = main.get_node("Systems/NarrativeManager")
	puzzles = main.get_node("Systems/PuzzleManager")
	clues = main.get_node("Systems/ClueManager")
	polvo = main.get_node("Room1Gameplay/Polvo")
	rooms.log_to_console = false
	narrative.log_to_console = false
	rooms.room_entered.connect(func(r): log["entered"].append(r))
	rooms.room_exited.connect(func(r): log["exited"].append(r))
	rooms.current_room_changed.connect(func(a, b): log["changed"].append([a, b]))
	rooms.room_completed.connect(func(r): log["completed"].append(r))
	# "Interface futura": só escuta o sinal, sem tocar no NarrativeManager.
	narrative.event_triggered.connect(func(e): log["events"].append(e.id))

	await _structure()
	await _enter_exit()
	await _door_jitter()
	await _adjacent_volumes()
	await _no_time_progression()
	await _progression_and_events()
	await _save_load()

	print("RESULTADO: %d/%d testes passaram" % [passed, passed + failed])
	quit(1 if failed > 0 else 0)


# ------------------------------------------------------------ estrutura

func _structure() -> void:
	print("--- estrutura")
	var db: NarrativeDatabase = rooms.database
	_check("banco narrativo mínimo válido", db.validate(puzzles.database).is_empty(), str(db.validate(puzzles.database)))
	# Fase 4: o banco passou a ter as seis salas e os seis monstros.
	_check("banco: seis salas, seis monstros, Room 1 com o Polvo", db.get_classrooms().size() == 6 and db.monsters.size() == 6 and db.get_room(&"room_1").monster_id == &"octopus", "")
	_check("conteúdo da Room 1 marcado como TESTE", db.get_room(&"room_1").content_status == RoomData.ContentStatus.TEST, "")
	var volumes := root.get_tree().get_nodes_in_group("room_volume")
	var ok := true
	for v in volumes:
		var r: RoomData = db.get_room(v.room_id)
		if r == null or r.geometry_status != RoomData.GeometryStatus.PHYSICAL:
			ok = false
	# Fase 4: um volume por sala física (room_1..room_5); Música não tem cenário.
	var physical := 0
	for r in db.rooms:
		if r.geometry_status == RoomData.GeometryStatus.PHYSICAL:
			physical += 1
	# Prompt 1: 8 locais físicos (6 salas + sala inicial + Monitoramento); a
	# sala inicial não tem volume (é o ponto de partida).
	_check("volumes só para salas com geometria", ok and physical == 8 and volumes.size() == 7, "%d volume(s)" % volumes.size())
	var v1: Area3D = volumes[0]
	_check("volume invisível para câmera/raios (camada 0, não monitorável)", v1.collision_layer == 0 and not v1.monitorable, "")
	_check("volume separado das zonas de câmera", not v1.has_method("get_occluding_geometry") and v1.get_parent().name == "RoomVolumes", "")
	_check("protagonista inalterada (camada 1, máscara 5)", player.collision_layer == 1 and player.collision_mask == 5, "")
	_check("estado inicial: Room 1 disponível, fora de sala", rooms.get_state_name(&"room_1") == "AVAILABLE" and rooms.current_room == &"", rooms.get_state_name(&"room_1"))


# ------------------------------------------------------------ entrada/saída

func _enter_exit() -> void:
	print("--- entrada e saída andando pela porta")
	await _teleport(Vector3(0, 0.05, -10.5))
	_reset_log()
	var zone_before: Node = controller.current_zone
	await _walk(Vector3.LEFT, 150, [])
	_check("entrou: um único room_entered(room_1)", log["entered"] == [&"room_1"], str(log["entered"]))
	_check("sala atual = room_1, estado ACTIVE", rooms.current_room == &"room_1" and rooms.get_state_name(&"room_1") == "ACTIVE", rooms.get_state_name(&"room_1"))
	_check("câmera usa a zona da Room 1 normalmente", controller.current_zone != null and controller.current_zone.name == "Room1Camera", str(controller.current_zone))
	_reset_log()
	for leg in [[Vector3.FORWARD, 80], [Vector3.LEFT, 60], [Vector3.BACK, 120], [Vector3.RIGHT, 40]]:
		await _walk(leg[0], leg[1], ["run"])
	await _physics(30)
	_check("andar/correr 5 s dentro da sala não gera eventos", log["entered"].is_empty() and log["exited"].is_empty() and log["changed"].is_empty(), str(log))
	await _teleport(Vector3(-8, 0.05, -10.5))
	await _physics(30)
	_reset_log()
	await _walk(Vector3.RIGHT, 150, [])
	await _physics(30)
	_check("saiu: um único room_exited(room_1)", log["exited"] == [&"room_1"] and log["entered"].is_empty(), str(log["exited"]))
	_check("sala atual vazia no corredor", rooms.current_room == &"", "")
	# agachada e correndo
	for mods in [["crouch"], ["run"]]:
		await _teleport(Vector3(0, 0.05, -10.5))
		await _physics(30)
		_reset_log()
		await _walk(Vector3.LEFT, 260 if mods == ["crouch"] else 90, mods)
		await _physics(30)
		_check("entrada %s: um evento" % mods[0], log["entered"] == [&"room_1"] and log["changed"].size() == 1, str(log["changed"]))


# ------------------------------------------------------------ porta

func _door_jitter() -> void:
	print("--- porta: ir e voltar sobre a soleira")
	await _teleport(Vector3(-3.0, 0.05, -10.5))
	await _physics(30)
	_reset_log()
	var min_x := INF
	var max_x := -INF
	for i in 18:   # 18 trocas de direção a cada 10 quadros, cruzando a linha x = -3,5
		await _walk(Vector3.LEFT if i % 2 == 0 else Vector3.RIGHT, 10, [])
		min_x = minf(min_x, player.global_position.x)
		max_x = maxf(max_x, player.global_position.x)
	await _physics(30)
	_check("o vai-e-volta de fato cruza a soleira (parede em x = -3,5)", min_x < -3.5 and max_x > -3.35, "x de %.2f a %.2f" % [min_x, max_x])
	_check("vai-e-volta rápido na porta: sem alternância contínua (≤ 2 trocas)", log["changed"].size() <= 2, "%d trocas: %s" % [log["changed"].size(), log["changed"]])
	await _teleport(Vector3(-3.45, 0.05, -10.5))   # parada exatamente na soleira
	await _physics(30)
	_reset_log()
	await _physics(180)
	_check("parada na soleira por 3 s: nenhum evento", log["changed"].is_empty(), str(log["changed"]))


# ------------------------------------------------------------ salas adjacentes

func _adjacent_volumes() -> void:
	print("--- duas salas adjacentes (volumes de teste, só em memória)")
	var db: NarrativeDatabase = rooms.database
	var added: Array[Node] = []
	for spec in [[&"teste_sala_a", -14.0], [&"teste_sala_b", -18.0]]:
		var room := RoomData.new()
		room.id = spec[0]
		room.kind = RoomData.Kind.STORY_AREA
		db.rooms.append(room)
		rooms._states[room.id] = S.AVAILABLE
		var vol := RoomVolume.new()
		vol.room_id = spec[0]
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = Vector3(6.0, 4.5, 4.0)
		vol.add_child(shape)
		main.add_child(vol)
		vol.global_position = Vector3(0, 2.25, spec[1])   # A: z -12..-16 | B: z -16..-20
		added.append(vol)
	await _teleport(Vector3(0, 0.05, -13.0))
	await _physics(30)
	_check("começa na sala A", rooms.current_room == &"teste_sala_a", str(rooms.current_room))
	_reset_log()
	await _walk(Vector3.FORWARD, 90, [])
	await _physics(30)
	_check("A → B: uma única troca, sem passar por 'nenhuma sala'", log["changed"] == [[&"teste_sala_a", &"teste_sala_b"]], str(log["changed"]))
	await _teleport(Vector3(0, 0.05, -16.0))
	await _physics(30)
	_reset_log()
	for i in 20:
		await _walk(Vector3.FORWARD if i % 2 == 0 else Vector3.BACK, 8, [])
	await _physics(30)
	_check("vai-e-volta na divisa A/B: ≤ 2 trocas", log["changed"].size() <= 2, "%d trocas" % log["changed"].size())
	for v in added:
		v.queue_free()
	await _teleport(Vector3(0, 0.05, -40.0))
	await _physics(30)
	# Remove só as salas de teste (antes: resize(1), que supunha banco só com a Room 1).
	for r in db.rooms.duplicate():
		if r.id in [&"teste_sala_a", &"teste_sala_b"]:
			db.rooms.erase(r)
	rooms._states.erase(&"teste_sala_a")
	rooms._states.erase(&"teste_sala_b")


# ------------------------------------------------------------ tempo

func _no_time_progression() -> void:
	print("--- narrativa não avança com o tempo")
	_reset_log()
	await _physics(600)
	_check("10 s parada no corredor: nenhum evento narrativo", log["events"].is_empty(), str(log["events"]))


# ------------------------------------------------------------ progressão

func _progression_and_events() -> void:
	print("--- progressão da Room 1 e eventos narrativos")
	await _teleport(Vector3(-13.2, 0.05, -13.0))   # ao lado do caderno
	await _physics(30)
	_reset_log()
	await _press_e()
	_check("ler o caderno (E) dispara o documento de teste", log["events"].count(&"teste_room_1_caderno") == 1, str(log["events"]))
	for i in 3:
		await _press_e()
	_check("reler 3 vezes não repete o evento", narrative.fire_count(&"teste_room_1_caderno") == 1, "%d" % narrative.fire_count(&"teste_room_1_caderno"))

	await _teleport(Vector3(-13.2, 0.05, -24.0))   # experimento
	await _physics(10)
	await _press_e()
	await _physics(5)
	_check("experimento desperta o Polvo → sala MONSTER_AWAKE", rooms.get_state_name(&"room_1") == "MONSTER_AWAKE", rooms.get_state_name(&"room_1"))
	_check("despertar do Polvo dispara o evento uma vez", narrative.fire_count(&"teste_polvo_despertar") == 1, "")
	polvo._change_state(MonsterController.State.INACTIVE)   # tira o Polvo do caminho do teste
	polvo.global_position = Vector3(-21.2, polvo.global_position.y, -18.7)

	# Resolve os dois enigmas com as respostas já cobertas pela Etapa 3.
	puzzles.submit_answer(&"teste_ciencias_alternativa", 1)
	clues.discover_from_object(&"room_1.tabela_periodica")
	_check("1º enigma resolvido: sala ainda não resolvida (falta o código)", rooms.get_state_name(&"room_1") == "MONSTER_AWAKE", rooms.get_state_name(&"room_1"))
	puzzles.submit_answer(&"teste_ciencias_codigo", "0427")
	await _physics(2)
	_check("enigmas resolvidos com a protagonista dentro → SOLVED", rooms.get_state_name(&"room_1") == "SOLVED", rooms.get_state_name(&"room_1"))
	_check("ainda não concluída nem evento de saída", log["completed"].is_empty() and narrative.fire_count(&"teste_room_1_saida") == 0, "")

	await _teleport(Vector3(-8, 0.05, -10.5))
	await _physics(30)
	await _walk(Vector3.RIGHT, 150, [])
	await _physics(30)
	_check("ao sair: COMPLETED, room_completed uma vez", rooms.get_state_name(&"room_1") == "COMPLETED" and log["completed"] == [&"room_1"], str(log["completed"]))
	_check("evento de saída disparado uma vez", narrative.fire_count(&"teste_room_1_saida") == 1, "")
	await _walk(Vector3.LEFT, 150, [])
	await _physics(30)
	await _walk(Vector3.RIGHT, 150, [])
	await _physics(30)
	_check("voltar e sair de novo não repete conclusão nem evento", log["completed"] == [&"room_1"] and narrative.fire_count(&"teste_room_1_saida") == 1, "")

	# evento desativado (cadastro em memória, como a futura ligação inicial)
	var off := NarrativeEvent.new()
	off.id = &"teste_desativado"
	off.enabled = false
	off.disabled_reason = "Teste: espera a Etapa 7."
	off.title = "[TESTE] desativado"
	narrative.database.events.append(off)
	_check("evento desativado não dispara nem manualmente", not narrative.trigger_manual(&"teste_desativado") and not narrative.has_fired(&"teste_desativado"), "")
	narrative.database.events.erase(off)


# ------------------------------------------------------------ save

func _save_load() -> void:
	print("--- persistência em memória")
	var room_data: Dictionary = JSON.parse_string(JSON.stringify(rooms.get_save_data()))
	var narr_data: Dictionary = JSON.parse_string(JSON.stringify(narrative.get_save_data()))
	var main2: Node = load("res://scenes/main.tscn").instantiate()
	main.queue_free()
	await _physics(2)
	root.add_child(main2)
	preload("res://tests/test_input.gd").open_all_doors(self)  # Prompt 1: portas físicas
	await _physics(10)
	var rooms2: RoomProgressManager = main2.get_node("Systems/RoomProgressManager")
	var narr2: NarrativeManager = main2.get_node("Systems/NarrativeManager")
	rooms2.log_to_console = false
	narr2.log_to_console = false
	var refired := []
	narr2.event_triggered.connect(func(e): refired.append(e.id))
	rooms2.load_save_data(room_data)
	narr2.load_save_data(narr_data)
	_check("estado das salas restaurado (COMPLETED, visitada)", rooms2.is_completed(&"room_1") and rooms2.was_visited(&"room_1"), "")
	_check("eventos restaurados como já disparados", narr2.has_fired(&"teste_room_1_caderno") and narr2.has_fired(&"teste_room_1_saida"), "")
	main2.get_node("Systems/PuzzleManager").register_interaction(&"room_1.caderno_laboratorio")
	narr2._on_trigger(NarrativeEvent.TriggerType.INTERACTION, &"room_1.caderno_laboratorio")
	_check("após carregar, a mesma interação não redispara o evento", refired.is_empty(), str(refired))


# ------------------------------------------------------------ utilidades

func _reset_log() -> void:
	for k in log:
		log[k] = []


func _press_e() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.device = InputEvent.DEVICE_ID_KEYBOARD
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	await process_frame
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await process_frame
	await process_frame


func _walk(world_dir: Vector3, frames: int, mods: Array) -> void:
	for i in frames:
		preload("res://tests/test_input.gd").press_world(player, world_dir)
		for m in mods:
			Input.action_press(m)
		await physics_frame
		await process_frame
	for a in ["move_forward", "move_back", "move_left", "move_right", "run", "crouch"]:
		Input.action_release(a)


func _teleport(p: Vector3) -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "run", "crouch"]:
		Input.action_release(a)
	player.velocity = Vector3.ZERO
	player.global_position = p
	await _physics(3)
	controller.snap_to_target()
	await _physics(2)


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("%s %s  %s" % ["OK    " if ok else "FALHA ", name, detail])
