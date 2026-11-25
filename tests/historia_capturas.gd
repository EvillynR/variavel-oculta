extends SceneTree
## Capturas da história (renderização real): abertura, mapa, documento,
## enigma, cena de entrada e despertar de monstro, monitores e final.
## Uso: xvfb-run godot --path . --rendering-driver vulkan --fixed-fps 60 --script res://tests/historia_capturas.gd -- --out=<pasta>

var out_dir := "user://historia"
var main: Node
var player: CharacterBody3D
var director: StoryDirector
var puzzle_ui: PuzzleUI
var interactor: PlayerInteractor
var shots := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	SaveSystem.save_path = "user://teste_capturas_save.json"
	SaveSystem.delete_save()
	SaveSystem.pending_action = "new"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _phys(4)
	player = main.get_node("Player")
	director = get_first_node_in_group("story_director")
	puzzle_ui = get_first_node_in_group("puzzle_ui")
	interactor = get_first_node_in_group("player_interactor")
	# Só desenha os quadros fotografados (renderização por software é lenta).
	RenderingServer.render_loop_enabled = false
	var yuko: YukoAnimator = player.get_node("Visual/Yuko")
	# Abertura: deitada → apoiada → de cócoras → de pé
	await _until_time(9.0)
	await _shot("abertura_deitada")
	await _until(func(): return yuko.scripted and yuko.rotation.z < 1.2, 6000)
	await _wait(0.5)
	await _shot("abertura_levantando_a")
	await _until(func(): return yuko.rotation.z < 0.6, 600)
	await _shot("abertura_levantando_b")
	await _until(func(): return yuko.rotation.z < 0.15, 600)
	await _shot("abertura_levantando_c")
	await _until(func(): return not director.is_busy(), 6000)
	await _phys(30)
	await _shot("jogo_patio")
	await _use("patio.bilhete")
	await _until(func(): return director.documents.is_open(), 120)
	await _shot("patio_aviso")
	director.documents.close()
	await _until(func(): return not director.is_busy(), 600)
	# O mapa: a "voz" se escreve nele
	await _use("patio.mapa")
	await _until(func(): return director.map.is_open(), 3000)
	await _wait(2.4)
	await _shot("cena_mapa_escrevendo")
	await _until(func(): return director.map.notes.size() >= 3, 3000)
	await _wait(1.8)
	await _shot("cena_mapa_escritos")
	await _until(func(): return not director.is_busy(), 6000)
	await _phys(10)
	director.map.open()
	await _phys(3)
	await _shot("mapa_aberto")
	director.map.close()
	# Corredor (janelas em grade, luminárias pendentes)
	_door("patio.porta").open(false, true)
	player.global_position = Vector3(0.0, 0.05, -52.0)
	await _wait(2.0)
	await _shot("corredor_janelas")
	# Sala de Português
	_door("room_1.porta").open(false, true)
	player.global_position = Vector3(-6.0, 0.05, -10.5)
	await _until(func(): return director.cutscenes.playing, 300)
	await _wait(3.5)
	await _shot("entrada_portugues")
	await _until(func(): return not director.is_busy(), 6000)
	player.global_position = Vector3(-10.0, 0.05, -12.5)
	await _wait(2.5)
	await _shot("porta_fecha_e_escrito")
	for spot in ["room_1.quadro", "room_1.caderno", "room_1.gaveta", "room_1.chamada"]:
		await _stand(spot)
		await _shot("moveis_" + spot)
	await _use("room_1.livro_preso")
	await _until(func(): return director.documents.is_open(), 120)
	await _shot("pista_barulhenta")
	await _until(func(): return director.cutscenes.playing or director.documents.is_open() == false, 10)
	while not director.cutscenes.playing:
		if director.documents.is_open():
			director.documents.close()
		await process_frame
		_clock += 1.0 / 60.0
	await _wait(2.0)
	await _shot("leitor_desperta")
	await _until(func(): return not director.is_busy() and director._queue.is_empty(), 6000)
	await _wait(1.2)
	await _shot("escrito_esconda_se")
	player.enter_hiding(_spot("room_1.esconderijo_mesa"))
	await _wait(6.0)
	await _shot("leitor_procurando")
	await _until(func(): return director.get_room_phase("room_1") == "calmo", 60 * 90)
	await _wait(1.6)
	await _shot("escrito_ele_se_acalmou")
	player.leave_hiding()
	await _phys(10)
	# Outras salas: proporção dos móveis (sem cenas no caminho)
	director.enabled = false
	for spot in ["room_2.prova", "room_2.transferidor", "room_3.frascos", "room_3.armario", "room_4.globo", "room_4.mapa_cidade"]:
		await _stand(spot)
		await _shot("moveis_" + spot)
	director.enabled = true
	# Sala de Música (o Maestro)
	var rooms_m: RoomProgressManager = get_first_node_in_group("room_progress_manager")
	for rid in [&"room_1", &"room_2", &"room_3", &"room_4"]:
		rooms_m._set_state(rid, RoomData.RoomState.COMPLETED)
	await _phys(5)
	_door("room_5.porta").unlock()
	_door("room_5.porta").open(false, true)
	player.global_position = Vector3(-6.0, 0.05, -175.0)
	await _until(func(): return director.cutscenes.playing, 600)
	await _wait(3.5)
	await _shot("entrada_musica")
	await _until(func(): return not director.is_busy(), 6000)
	for spot in ["room_5.partitura", "room_5.quadro"]:
		await _stand(spot)
		await _shot("moveis_" + spot)
	await _use("room_5.piano")
	while not director.cutscenes.playing:
		if director.documents.is_open():
			director.documents.close()
		await process_frame
		_clock += 1.0 / 60.0
	await _wait(2.0)
	await _shot("maestro_desperta")
	await _until(func(): return not director.is_busy() and director._queue.is_empty(), 6000)
	await _wait(3.0)
	await _shot("maestro_cacando")
	director.enabled = false
	for m in get_nodes_in_group("monster"):
		m.deactivate(true)
	director.enabled = true
	# Saída e final
	for rid in [&"room_1", &"room_2", &"room_3", &"room_4", &"room_5"]:
		var rooms: RoomProgressManager = get_first_node_in_group("room_progress_manager")
		rooms._set_state(rid, RoomData.RoomState.COMPLETED)
	director.map.reveal("saida")
	await _until(func(): return not director.is_busy() and director._queue.is_empty(), 9000)
	await _wait(6.0)
	director.map.open()
	await _phys(3)
	await _shot("mapa_com_saida")
	director.map.close()
	_door("sala_saida.porta").unlock()
	_door("sala_saida.porta").open(false, true)
	player.global_position = Vector3(1.0, 0.05, -194.0)
	await _until(func(): return director.cutscenes.playing, 600)
	await _wait(4.0)
	await _shot("monitores")
	await _until(func(): return not director.is_busy(), 6000)
	await _use("sala_saida.ficha")
	await _until(func(): return director.map.is_open(), 3000)
	await _until(func(): return director.map.notes.any(func(n): return String(n.text).contains("TESTES ACABARAM")), 6000)
	await _wait(2.5)
	await _shot("final_mapa")
	await _until(func(): return director.ended, 9000)
	await _phys(5)
	await _shot("fim_capitulo")
	SaveSystem.delete_save()
	quit()


var _t0 := 0.0
var _clock := 0.0


func _until_time(t: float) -> void:
	while _clock < t:
		await process_frame
		_clock += 1.0 / 60.0


func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await process_frame
		t += 1.0 / 60.0
		_clock += 1.0 / 60.0


func _freeze_later(m: Node) -> void:
	await _phys(2)
	m.process_mode = Node.PROCESS_MODE_DISABLED


func _door(id: String) -> Door:
	for d in get_nodes_in_group("door"):
		if String(d.door_id) == id:
			return d
	return null


func _spot(id: String) -> Node3D:
	for s in get_nodes_in_group("hiding_spot"):
		if String(s.spot_id) == id:
			return s
	return null


func _stand(id: String) -> void:
	await _until(func(): return not paused, 6000)
	for it in get_nodes_in_group("interactable"):
		if String(it.interaction_id) == id:
			player.global_position = it.get_meta("stand", it.global_position) + Vector3(0, 0.05, 0)
	await _wait(1.6)


func _use(id: String) -> void:
	await _until(func(): return not paused, 6000)
	for it in get_nodes_in_group("interactable"):
		if String(it.interaction_id) == id:
			player.global_position = it.get_meta("stand", it.global_position) + Vector3(0, 0.05, 0)
	await _phys(6)
	interactor._update_target()
	interactor.try_interact()
	await _phys(3)


func _shot(name: String) -> void:
	RenderingServer.render_loop_enabled = true
	for i in 3:
		await RenderingServer.frame_post_draw
	RenderingServer.render_loop_enabled = false
	root.get_texture().get_image().save_png("%s/%02d_%s.png" % [out_dir, shots, name])
	print("captura ", name)
	shots += 1


func _until(cond: Callable, max_frames: int) -> void:
	var n := 0
	while not cond.call() and n < max_frames:
		await process_frame
		_clock += 1.0 / 60.0
		n += 1


func _phys(n: int) -> void:
	for i in n:
		await physics_frame
		_clock += 1.0 / 60.0
