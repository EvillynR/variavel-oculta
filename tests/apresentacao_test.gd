extends SceneTree
## Versão 6.1 — os atalhos de apresentação (scenes/apresentacao/*.tscn):
## cada um abre o jogo na frente da porta da sala, com as anteriores resolvidas,
## e a sala começa normalmente quando ela entra.
## Uso: godot --headless --fixed-fps 60 --path . --script res://tests/apresentacao_test.gd

const SALAS := [
	["room_1", "sala_1_portugues", "cena_portugues", -10.5],
	["room_2", "sala_2_matematica", "cena_matematica", -40.5],
	["room_3", "sala_3_ciencias", "cena_ciencias", -95.5],
	["room_4", "sala_4_geografia", "cena_geografia", -119.9],
	["room_5", "sala_5_musica", "cena_musica", -175.0],
	["final", "sala_6_final_saida", "cena_monitores", 0.0],
]
var passed := 0
var failed := 0


func _initialize() -> void:
	SaveSystem.save_path = "user://teste_apresentacao.json"
	for s in SALAS:
		await _testa(s)
	print("RESULTADO: %d ok, %d falhas" % [passed, failed])
	SaveSystem.delete_save()
	quit(1 if failed > 0 else 0)


func _testa(s: Array) -> void:
	var rid: String = s[0]
	var launcher: Node = load("res://scenes/apresentacao/%s.tscn" % s[1]).instantiate()
	root.add_child(launcher)
	current_scene = launcher
	for i in 30:
		await process_frame
		if current_scene != null and current_scene != launcher and current_scene.name == "Main" or (current_scene != null and current_scene.has_node("Player")):
			break
	var main := current_scene
	_check("%s: o atalho abre o jogo" % s[1], main != null and main.has_node("Player"))
	if main == null or not main.has_node("Player"):
		return
	var session: GameSession = get_first_node_in_group("game_session")
	await _until(func(): return session.ready_done, 600)
	var director: StoryDirector = get_first_node_in_group("story_director")
	var rooms: RoomProgressManager = get_first_node_in_group("room_progress_manager")
	var narrative: NarrativeManager = get_first_node_in_group("narrative_manager")
	var gom := get_first_node_in_group("game_over_ui")
	if gom != null:
		gom.process_mode = Node.PROCESS_MODE_DISABLED
	var player: CharacterBody3D = main.get_node("Player")
	await _until(func(): return not director.is_busy(), 3000)
	_check("%s: começa no corredor (%.1f, %.1f)" % [rid, player.global_position.x, player.global_position.z], String(rooms.current_room) == "" or not String(rooms.current_room).begins_with("room_"))
	var antes := ["room_1", "room_2", "room_3", "room_4", "room_5"].slice(0, ["room_1", "room_2", "room_3", "room_4", "room_5", "final"].find(rid))
	var ok := true
	for r in antes:
		ok = ok and rooms.is_completed(StringName(r))
	_check("%s: salas anteriores resolvidas (%s)" % [rid, ", ".join(antes) if not antes.is_empty() else "nenhuma"], ok)
	# entra
	var door_id: String = (rid + ".porta") if rid != "final" else "sala_saida.porta"
	var door: Door = null
	for d in get_nodes_in_group("door"):
		if String(d.door_id) == door_id:
			door = d
	_check("%s: porta destrancada" % rid, door != null and not door.is_locked())
	door.open(false, true)
	var dentro := Vector3(-6.0, 0.05, float(s[3])) if rid != "final" else Vector3(1.0, 0.05, -194.0)
	player.global_position = dentro
	player.velocity = Vector3.ZERO
	await _until(func(): return narrative.has_fired(StringName(s[2])), 600)
	_check("%s: entrou e a cena da sala começou (%s)" % [rid, s[2]], narrative.has_fired(StringName(s[2])))
	await _until(func(): return not director.is_busy(), 6000)
	if rid != "final":
		_check("%s: sala começa do zero (fase 'busca')" % rid, director.get_room_phase(rid) == "busca")
	get_tree_safe_free(main)
	await process_frame
	await process_frame


func get_tree_safe_free(n: Node) -> void:
	paused = false
	n.queue_free()
	current_scene = null


func _until(cond: Callable, max_frames: int) -> void:
	var n := 0
	while not cond.call() and n < max_frames:
		await process_frame
		n += 1


func _check(name: String, ok: bool) -> void:
	if ok:
		passed += 1
		print("  ok  ", name)
	else:
		failed += 1
		print("  FALHA  ", name)
