extends SceneTree
## Versão 5.2 — "mesmo escondida, o monstro a encontra".
## Nas duas salas com professor (Português/Leitor e Música/Maestro):
##  - versão 5.4: o único esconderijo é embaixo da mesa do professor;
##  - o professor acorda e CAÇA a Yuko; ela corre e se esconde com ele a
##    poucos metros (como no jogo) — ele não pode pegá-la; ronda, desiste
##    e aparece "ele se acalmou" (>= 30 s);
##  - pega no flagra: escondendo-se com ele colado (<= 3,5 m), ele a encontra.
## Uso: godot --headless --fixed-fps 60 --path . --script res://tests/esconderijo_test.gd

var main: Node
var player: Node3D
var session: GameSession
var director: Node
var rooms: RoomProgressManager
var narrative: NarrativeManager
var interactor: PlayerInteractor
var puzzle_ui: PuzzleUI
var puzzles: PuzzleManager
var passed := 0
var failed := 0
var frames := 0
var caught := 0
const ANSWERS := {}
var seen: Array = []


func _initialize() -> void:
	SaveSystem.save_path = "user://teste_esconderijo.json"
	SaveSystem.delete_save()
	SaveSystem.pending_action = "new"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _phys(4)
	player = main.get_node("Player")
	session = get_first_node_in_group("game_session")
	director = get_first_node_in_group("story_director")
	rooms = get_first_node_in_group("room_progress_manager")
	narrative = get_first_node_in_group("narrative_manager")
	interactor = get_first_node_in_group("player_interactor")
	puzzle_ui = get_first_node_in_group("puzzle_ui")
	puzzles = main.get_node("Systems/PuzzleManager")
	for m in get_nodes_in_group("monster"):
		m.player_caught.connect(func(): caught += 1)
	# a tela de "VOCÊ FOI ENCONTRADA" recarregaria a cena; aqui só contamos
	var gom := get_first_node_in_group("game_over_ui")
	if gom != null:
		gom.process_mode = Node.PROCESS_MODE_DISABLED
	director.cutscene_started.connect(func(id): seen.append(String(id)))
	await _until(func(): return director.cutscenes.playing, 300)
	await _until(func(): return not director.is_busy(), 6000)

	for r in [["room_1", -10.5, "reader", "room_1.livro_preso", "cena_leitor_desperta"],
			["room_5", -175.0, "maestro", "room_5.piano", "cena_maestro_toca"]]:
		var rid: String = r[0]
		if rid == "room_5":
			for done in [&"room_1", &"room_2", &"room_3", &"room_4"]:
				rooms._set_state(done, RoomData.RoomState.COMPLETED)
			await _phys(5)
		var spots := get_nodes_in_group("hiding_spot").filter(func(s): return String(s.spot_id).begins_with(rid + "."))
		_check("%s: só a mesa do professor como esconderijo (%d)" % [rid, spots.size()], spots.size() == 1 and String(spots[0].spot_id).ends_with("esconderijo_mesa"))
		# todos funcionam (entra e sai)
		var all_ok := true
		for s in spots:
			player.enter_hiding(s)
			await _phys(2)
			all_ok = all_ok and player.is_hidden()
			player.leave_hiding()
			await _phys(2)
			all_ok = all_ok and not player.is_hidden()
		_check("%s: dá para entrar e sair embaixo da mesa" % rid, all_ok)
		var door := _door("%s.porta" % rid)
		door.unlock()
		door.open(false, true)
		await _teleport(Vector3(-6.0, 0.05, float(r[1])))
		await _until(func(): return director.cutscenes.playing, 300)
		await _until(func(): return not director.is_busy(), 6000)
		await _teleport(Vector3(-10.0, 0.05, float(r[1]) - 2.0))
		if rid == "room_5":
			# versão 5.7: o piano só toca depois das pistas; a melodia é cena do diretor
			for c in ["room_5.quadro", "room_5.partitura", "room_5.bilhete"]:
				await _use(c)
				await _close_docs()
		await _use(r[3])
		await _close_docs()
		await _until(func(): return narrative.has_fired(StringName(r[4])) or seen.has(String(r[4])), 300)
		await _until(func(): return not director.is_busy() and director._queue.is_empty(), 6000)
		var m := _monster(r[2])
		_check("%s: professor acordado" % rid, m.is_active())
		# ela fica longe dele; ele vem caçando; quando chega a ~5 m ela se esconde
		var spot: Node3D = spots[0]
		var best := -1.0
		for s in spots:
			var d: float = s.global_position.distance_to(m.global_position)
			if d > best:
				best = d
				spot = s
		player.global_position = spot.get_front_position()
		await _phys(2)
		var t := 0
		while t < 60 * 20:
			await _frame()
			t += 1
			var d := Vector2(m.global_position.x - player.global_position.x, m.global_position.z - player.global_position.z).length()
			# versão 5.7: o Maestro acorda no piano, já perto da mesa — espera ele terminar de acordar
			if d <= 5.0 and m.state == MonsterController.State.CHASING:
				break
		var dist := Vector2(m.global_position.x - player.global_position.x, m.global_position.z - player.global_position.z).length()
		_check("%s: ele veio atrás dela (a %.1f m)" % [rid, dist], dist <= 5.5 and m.state == MonsterController.State.CHASING)
		var before := caught
		player.enter_hiding(spot)
		await _phys(2)
		_check("%s: escondeu com ele a %.1f m — ele não a viu entrar" % [rid, dist], not player.is_witness(m))
		var closest := 99.0
		t = 0
		while director.get_room_phase(rid) != "calmo" and t < 60 * 120 and caught == before:
			await _frame()
			t += 1
			closest = minf(closest, m.global_position.distance_to(player.global_position))
		_check("%s: escondida, ele não a encontrou (chegou a %.1f m do esconderijo)" % [rid, closest], caught == before)
		_check("%s: ele se acalmou depois de >= 30 s (%.0f s)" % [rid, float(director._awake_time.get(rid, 0.0))], director.get_room_phase(rid) == "calmo" and float(director._awake_time.get(rid, 0.0)) >= 30.0)
		player.leave_hiding()
		await _phys(10)

	# pega no flagra: colado nela ao se esconder
	var m2 := _monster("reader")
	var spot2 := _spot("room_1.esconderijo_mesa")
	player.global_position = spot2.get_front_position()
	m2.activate(&"teste", player.global_position, true)
	m2.global_position = player.global_position + Vector3(0, 0, 2.0)
	m2.process_mode = Node.PROCESS_MODE_DISABLED   # parado, olhando para ela
	m2.look_at(Vector3(player.global_position.x, m2.global_position.y, player.global_position.z))
	await _phys(2)
	if m2.perception.can_see(player):
		player.enter_hiding(spot2)
		_check("no flagra (a 2 m, olhando): ele sabe onde ela está", player.is_witness(m2))
		player.leave_hiding()
		# e um pouco mais longe (5 m) o mesmo olhar já não basta
		m2.global_position = player.global_position + Vector3(0, 0, 5.0)
		m2.look_at(Vector3(player.global_position.x, m2.global_position.y, player.global_position.z))
		await _phys(2)
		player.enter_hiding(spot2)
		_check("a 5 m, mesmo olhando, esconder-se funciona", not player.is_witness(m2))
		player.leave_hiding()
	else:
		_check("no flagra: ele enxerga a Yuko a 2 m", false)
	print("RESULTADO: %d ok, %d falhas" % [passed, failed])
	SaveSystem.delete_save()
	quit(1 if failed > 0 else 0)


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


func _monster(id: String) -> MonsterController:
	for m in get_nodes_in_group("monster"):
		if m is MonsterController and String(m.resolve_config().monster_id) == id:
			return m
	return null


func _teleport(p: Vector3) -> void:
	player.global_position = p
	player.velocity = Vector3.ZERO
	await _phys(20)


func _use(id: String) -> void:
	var target: Interactable = null
	for it in get_nodes_in_group("interactable"):
		if String(it.interaction_id) == id:
			target = it
	if target == null:
		_check("objeto %s existe" % id, false)
		return
	await _until(func(): return not paused, 6000)
	var stand: Vector3 = target.get_meta("stand", target.global_position + Vector3(0.9, 0, 0))
	player.global_position = stand + Vector3(0, 0.05, 0)
	player.velocity = Vector3.ZERO
	await _phys(6)
	interactor._update_target()
	var ok := interactor.get_current_target() == target
	if not ok:
		var cur := interactor.get_current_target()
		print("  alvo atual: %s (esperado %s)" % [cur.interaction_id if cur else "nenhum", id])
	_check("usar %s" % id, ok and interactor.try_interact())
	await _phys(4)


func _close_docs() -> void:
	await _until(func(): return director.documents.is_open() or (director._queue.is_empty() and not director._running), 120)
	while director.documents.is_open() or director.cutscenes.playing or director._running:
		if director.documents.is_open():
			director.documents.close()
		await _frame()


func _answer(pid: StringName) -> void:
	await _until(func(): return puzzle_ui.is_open(), 120)
	_check("pergunta %s abriu" % pid, puzzle_ui.is_open() and puzzle_ui._active_puzzle.id == pid)
	if not puzzle_ui.is_open():
		print("  disponível? ", puzzles.is_available(pid))
		return
	var wrong: Variant = 0 if typeof(ANSWERS[pid]) == TYPE_INT and ANSWERS[pid] != 0 else "9999"
	puzzle_ui._submit_answer(wrong)
	_check("%s: resposta errada recusada" % pid, not puzzles.is_solved(pid))
	puzzle_ui._submit_answer(ANSWERS[pid])
	_check("%s: resposta certa aceita" % pid, puzzles.is_solved(pid))
	puzzle_ui.close_puzzle()
	await _phys(3)


func _until(cond: Callable, max_frames: int) -> void:
	var n := 0
	while not cond.call() and n < max_frames:
		await _frame()
		n += 1


func _frame() -> void:
	await process_frame
	frames += 1


func _phys(n: int) -> void:
	for i in n:
		await physics_frame
		frames += 1


func _check(name: String, ok: bool) -> void:
	if ok:
		passed += 1
		print("  ok   ", name)
	else:
		failed += 1
		print("  FALHA ", name)
