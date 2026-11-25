extends SceneTree
## Captura → "Tentar do checkpoint" no meio da história (pergunta 17: volta
## ao ÚLTIMO checkpoint). Cena real recarregada (reload_current_scene).
## Confere: sala, pistas, monstro, mapa (e escritos), objetivo, portas do
## fluxo da sala e que as cenas já vistas NÃO repetem.
## Uso: godot --headless --fixed-fps 60 --path . --script res://tests/checkpoint_historia_test.gd

var passed := 0
var failed := 0


func _initialize() -> void:
	SaveSystem.save_path = "user://teste_checkpoint_save.json"
	SaveSystem.delete_save()
	SaveSystem.pending_action = "new"
	change_scene_to_file("res://scenes/main.tscn")
	await _phys(6)
	var d: StoryDirector = get_first_node_in_group("story_director")
	await _until(func(): return d.cutscenes.playing, 600)
	await _until(func(): return not d.is_busy(), 6000)
	await _use("patio.mapa")
	await _until(func(): return d.map.obtained and not d.is_busy(), 6000)
	var player: CharacterBody3D = get_first_node_in_group("player")
	_door("room_1.porta").open(false, true)
	player.global_position = Vector3(-6.0, 0.05, -10.5)
	await _until(func(): return get_first_node_in_group("narrative_manager").has_fired(&"cena_portugues"), 300)
	await _until(func(): return not d.is_busy(), 6000)
	player.global_position = Vector3(-10.0, 0.05, -12.5)
	await _until(func(): return not _door("room_1.porta").is_open(), 300)
	await _until(func(): return not d.is_busy() and d._queue.is_empty(), 600)
	await _phys(5)
	var saved := SaveSystem.read_save()
	_check("checkpoint com a porta fechada atrás dela", String(saved.get("reason", "")) == "porta fechou: room_1")
	# Avança: lê o quadro e puxa o livro preso (o Leitor acorda).
	await _use("room_1.quadro")
	await _close_docs()
	await _use("room_1.livro_preso")
	await _close_docs()
	await _until(func(): return get_first_node_in_group("narrative_manager").has_fired(&"cena_leitor_desperta"), 600)
	await _until(func(): return not d.is_busy(), 6000)
	var leitor := _monster("reader")
	_check("Leitor acordou com o barulho", leitor.is_active() and d.get_room_phase("room_1") == "acordado")
	# Captura!
	leitor.player_caught.emit()
	# versão 6.2: antes da tela, a Yuko morre (animação)
	await _until(func(): return get_first_node_in_group("game_over_ui").is_open(), 400)
	var go := get_first_node_in_group("game_over_ui")
	_check("tela de captura aberta", go.is_open() and paused)
	go._retry()
	await _phys(12)
	# Cena recarregada: pega tudo de novo
	d = get_first_node_in_group("story_director")
	player = get_first_node_in_group("player")
	await _phys(30)
	var nm: NarrativeManager = get_first_node_in_group("narrative_manager")
	var rooms: RoomProgressManager = get_first_node_in_group("room_progress_manager")
	var session: GameSession = get_first_node_in_group("game_session")
	var pp := player.global_position
	print("   voltou para ", pp)
	_check("voltou para dentro da Sala de Português", pp.x < -4.0 and pp.x > -23.4 and pp.z < -7.5 and pp.z > -30.0)
	_check("Leitor dormindo de novo (estado do checkpoint)", not _monster("reader").is_active())
	_check("porta da sala continua fechada e trancada", not _door("room_1.porta").is_open() and _door("room_1.porta").is_locked())
	_check("fase da sala: busca", d.get_room_phase("room_1") == "busca")
	_check("mapa continua com ela (e os escritos)", d.map.obtained and d.map.notes.size() >= 5)
	_check("objetivo da sala restaurado", session.hud.objective.contains("pistas"))
	_check("porta do pátio continua destrancada", not _door("patio.porta").is_locked())
	_check("cena de entrada NÃO repete", not d.cutscenes.playing and nm.has_fired(&"cena_portugues"))
	_check("abertura NÃO repete", nm.has_fired(&"cena_abertura") and not d.is_busy())
	_check("sala atual: Português", rooms.current_room == &"room_1")
	_check("Yuko de pé", absf(player.get_node("Visual/Yuko").rotation.x) < 0.01)
	_check("pista barulhenta foi desfeita", not get_first_node_in_group("clue_manager").is_discovered(&"port_classes"))
	await _use("room_1.livro_preso")
	await _close_docs()
	await _until(func(): return _monster("reader").is_active(), 600)
	_check("o livro cai de novo e o Leitor acorda de novo", _monster("reader").is_active())
	print("RESULTADO: %d ok, %d falhas" % [passed, failed])
	SaveSystem.delete_save()
	quit(1 if failed > 0 else 0)


func _monster(id: String) -> MonsterController:
	for m in get_nodes_in_group("monster"):
		if m is MonsterController and String(m.resolve_config().monster_id) == id:
			return m
	return null


func _door(id: String) -> Door:
	for dd in get_nodes_in_group("door"):
		if String(dd.door_id) == id:
			return dd
	return null


func _use(id: String) -> void:
	await _until(func(): return not paused, 6000)
	var player: CharacterBody3D = get_first_node_in_group("player")
	var interactor: PlayerInteractor = get_first_node_in_group("player_interactor")
	for it in get_nodes_in_group("interactable"):
		if String(it.interaction_id) == id:
			player.global_position = it.get_meta("stand", it.global_position) + Vector3(0, 0.05, 0)
	await _phys(6)
	interactor._update_target()
	interactor.try_interact()
	await _phys(3)


func _close_docs() -> void:
	var d: StoryDirector = get_first_node_in_group("story_director")
	await _until(func(): return d.documents.is_open(), 120)
	while d.documents.is_open() or d._running:
		if d.documents.is_open():
			d.documents.close()
		await process_frame


func _until(cond: Callable, max_frames: int) -> void:
	var n := 0
	while not cond.call() and n < max_frames:
		await process_frame
		n += 1


func _phys(n: int) -> void:
	for i in n:
		await physics_frame


func _check(name: String, ok: bool) -> void:
	if ok:
		passed += 1
		print("  ok   ", name)
	else:
		failed += 1
		print("  FALHA ", name)
