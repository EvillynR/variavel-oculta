extends SceneTree
## Versão 5.7 — capturas do enigma da melodia (renderização real).
## Uso: xvfb-run godot --path . --rendering-driver vulkan --fixed-fps 60 --script res://tests/musica_capturas.gd -- --out=<pasta>

var out_dir := "user://musica"
var main: Node
var player: CharacterBody3D
var director: StoryDirector
var puzzle_ui: PuzzleUI
var interactor: PlayerInteractor
var lousa: LousaNotas
var shots := 0
var _keep_render := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	SaveSystem.save_path = "user://teste_musica_capturas.json"
	SaveSystem.delete_save()
	SaveSystem.pending_action = ""
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _phys(4)
	player = main.get_node("Player")
	director = get_first_node_in_group("story_director")
	puzzle_ui = get_first_node_in_group("puzzle_ui")
	interactor = get_first_node_in_group("player_interactor")
	lousa = get_first_node_in_group("lousa_notas")
	var gom := get_first_node_in_group("game_over_ui")
	if gom != null:
		gom.process_mode = Node.PROCESS_MODE_DISABLED
	director.enabled = true
	RenderingServer.render_loop_enabled = false
	var rooms_m: RoomProgressManager = get_first_node_in_group("room_progress_manager")
	for rid in [&"room_1", &"room_2", &"room_3", &"room_4"]:
		rooms_m._set_state(rid, RoomData.RoomState.COMPLETED)
	await _phys(5)
	_door("room_5.porta").unlock()
	_door("room_5.porta").open(false, true)
	player.global_position = Vector3(-6.0, 0.05, -175.0)
	await _until(func(): return director.cutscenes.playing, 600)
	await _until(func(): return not director.is_busy(), 6000)
	player.global_position = Vector3(-10.0, 0.05, -177.0)
	await _phys(30)
	for c in ["room_5.quadro", "room_5.partitura", "room_5.bilhete"]:
		await _use(c)
		await _close_docs()
	# a lousa vazia (jogo) perto da lousa
	await _stand("room_5.quadro")
	await _shot("lousa_jogo")
	# as cenas de filme não andam com o laço de desenho desligado: liga até o fim
	_keep_render = true
	RenderingServer.render_loop_enabled = true
	await _use("room_5.piano")
	await _until(func(): return director.cutscenes.playing, 600)
	await _wait(3.0)
	await _shot("maestro_senta_piano")
	await _until(func(): return not lousa.nota_atual.is_empty(), 6000)
	await _wait(0.5)
	await _shot("lousa_nota_1")
	await _until(func(): return lousa.nota_atual.is_empty(), 6000)
	await _until(func(): return not lousa.nota_atual.is_empty(), 6000)
	await _until(func(): return lousa.nota_atual.is_empty(), 6000)
	await _until(func(): return not lousa.nota_atual.is_empty(), 6000)
	await _wait(0.5)
	await _shot("lousa_nota_3_si")
	await _until(func(): return lousa.nota_atual.is_empty(), 6000)
	await _until(func(): return not lousa.nota_atual.is_empty(), 6000)
	await _wait(0.5)
	await _shot("lousa_nota_4_re")
	await _until(func(): return not lousa.apresentando, 6000)
	await _wait(0.3)
	await _shot("lousa_vazia_fim")
	await _wait(2.6)
	await _shot("maestro_observa")
	await _until(func(): return not director.is_busy() and director._queue.is_empty(), 6000)
	await _wait(1.5)
	await _shot("maestro_acorda_jogo")
	# pula a espera: ele se acalma
	var m: MonsterController = null
	for mm in get_nodes_in_group("monster"):
		if String(mm.resolve_config().monster_id) == "maestro":
			m = mm
	director._calm("room_5", m)
	m.deactivate(true)
	await _phys(10)
	await _stand("room_5.teclado")
	await _phys(40)
	await _shot("teclado_porta_jogo")
	await _use("room_5.teclado")
	await _until(func(): return puzzle_ui.is_open(), 120)
	await _phys(20)
	puzzle_ui._code_digit("3")
	puzzle_ui._code_digit("7")
	await _phys(5)
	await _shot("teclado_tela")
	puzzle_ui._code_digit("4")
	puzzle_ui._code_digit("8")
	await _until(func(): return director.cutscenes.playing, 600)
	await _wait(1.2)
	await _shot("erro_maestro")
	print("capturas: ", shots)
	quit(0)


func _door(id: String) -> Door:
	for d in get_nodes_in_group("door"):
		if String(d.door_id) == id:
			return d
	return null


func _target(id: String) -> Interactable:
	for it in get_nodes_in_group("interactable"):
		if String(it.interaction_id) == id:
			return it
	return null


func _stand(id: String) -> void:
	var t := _target(id)
	var stand: Vector3 = t.get_meta("stand", t.global_position)
	player.global_position = stand + Vector3(0, 0.05, 0)
	player.velocity = Vector3.ZERO
	var d := t.global_position - stand
	player.visual.rotation.y = atan2(d.x, d.z)
	var gc := get_first_node_in_group("camera_controller")
	await _phys(6)
	if gc != null and gc.has_method("snap_to_target"):
		gc.snap_to_target()
	await _phys(30)


func _use(id: String) -> void:
	await _until(func(): return not paused, 6000)
	var t := _target(id)
	var stand: Vector3 = t.get_meta("stand", t.global_position)
	player.global_position = stand + Vector3(0, 0.05, 0)
	player.velocity = Vector3.ZERO
	await _phys(6)
	interactor._update_target()
	interactor.try_interact()
	await _phys(4)


func _close_docs() -> void:
	await _until(func(): return director.documents.is_open() or (director._queue.is_empty() and not director._running), 120)
	while director.documents.is_open() or director.cutscenes.playing or director._running:
		if director.documents.is_open():
			director.documents.close()
		await process_frame


func _shot(name: String) -> void:
	RenderingServer.render_loop_enabled = true
	for i in 3:
		await RenderingServer.frame_post_draw
	RenderingServer.render_loop_enabled = _keep_render
	root.get_texture().get_image().save_png("%s/%02d_%s.png" % [out_dir, shots, name])
	print("captura ", name)
	shots += 1


func _until(cond: Callable, max_frames: int) -> void:
	var n := 0
	while not cond.call() and n < max_frames:
		await process_frame
		n += 1


func _wait(s: float) -> void:
	for i in int(s * 60.0):
		await process_frame


func _phys(n: int) -> void:
	for i in n:
		await physics_frame
