extends SceneTree
## História de Yuko do começo ao fim (sem jogador), no fluxo da versão 5:
## acorda no PÁTIO (cerejeira, céu aberto) → mapa (a "voz" escrita no mapa) →
##   Português (o Leitor) e Música (o Maestro): entra → porta fecha atrás dela
##     → pistas → pista barulhenta acorda o professor → ele CAÇA por >= 30 s
##     → ela se esconde → "ele se acalmou" → pergunta (bloqueada com ele
##     acordado) → resposta certa abre a porta e o acorda → sai → porta fecha
##   Matemática, Ciências e Geografia: pistas + pergunta, porta fecha e abre,
##     sem professor.
## → saída (fim do corredor, escondida no mapa até Música) → monitores → final.
## Também confere o erro relatado: usar o cadeado antes da hora mostra o
## motivo de novo (e não "já examinou este objeto").
## Uso: godot --headless --fixed-fps 60 --path . --script res://tests/historia_completa_test.gd

var main: Node
var player: CharacterBody3D
var director: StoryDirector
var session: GameSession
var rooms: RoomProgressManager
var puzzles: PuzzleManager
var narrative: NarrativeManager
var interactor: PlayerInteractor
var puzzle_ui: PuzzleUI
var passed := 0
var failed := 0
var cutscenes_seen: Array = []
var docs_seen := 0
var frames := 0
var saves: Array = []

const ANSWERS := {&"port_gaveta": "2212", &"mat_cofre": "5450", &"cie_frasco": 3, &"geo_ponto": 1, &"mus_teclado": "3784"}
var router: Node


func _initialize() -> void:
	SaveSystem.save_path = "user://teste_historia_save.json"
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
	puzzles = main.get_node("Systems/PuzzleManager")
	interactor = get_first_node_in_group("player_interactor")
	puzzle_ui = get_first_node_in_group("puzzle_ui")
	router = main.get_node("Systems/InteractionRouter")
	director.cutscene_started.connect(func(id): cutscenes_seen.append(String(id)))
	director.documents.closed.connect(func(): docs_seen += 1)
	session.checkpoint_saved.connect(func(r): saves.append(String(r)))
	var yuko: YukoAnimator = player.get_node("Visual/Yuko")

	# ---------------------------------------------------------- abertura
	await _until(func(): return director.cutscenes.playing, 300)
	_check("abertura começa sozinha (jogo novo)", narrative.has_fired(&"cena_abertura") and director.cutscenes.playing)
	_check("jogo pausado durante a cena", paused)
	# versão 6.2: a Yuko deita e levanta com a animação "Levantando" do modelo
	var com_clipe := yuko._has_clip(&"levantar")
	if com_clipe:
		_check("Yuko deitada no começo (primeiro quadro de Levantando)", yuko.current == &"levantar" and yuko.scripted)
	else:
		_check("Yuko deitada de lado no começo (rosto para a câmera)", yuko.rotation.z > 1.2 and yuko.scripted)
	var mid_pitch := -1.0
	var viu_meio := false
	while director.cutscenes.playing:
		await _frame()
		if yuko.rotation.z > 0.3 and yuko.rotation.z < 1.0:
			mid_pitch = yuko.rotation.z
		if com_clipe and yuko.current == &"levantar" and yuko.anim.speed_scale > 0.0:
			var pos := yuko.anim.current_animation_position
			var tot := yuko.anim.current_animation_length
			if pos > tot * 0.3 and pos < tot * 0.8:
				viu_meio = true
	_check("levanta aos poucos (passa pelo meio da animação)", viu_meio if com_clipe else mid_pitch > 0.0)
	await _until(func(): return not director.is_busy(), 6000)
	_check("abertura termina e devolve o controle", not paused and not director.cutscenes.playing)
	_check("Yuko de pé depois da abertura", absf(yuko.rotation.x) < 0.01 and absf(yuko.rotation.z) < 0.01 and yuko.position.length() < 0.01 and not yuko.scripted)
	_check("objetivo: o banco do pátio", session.hud.objective.contains("banco do pátio"))
	_check("acordou no pátio", player.global_position.x < -4.0 and player.global_position.z < -58.0 and player.global_position.z > -84.0)
	_check("porta do pátio trancada antes do mapa", _door("patio.porta").is_locked())
	_check("checkpoint gravado na abertura", SaveSystem.has_save())
	_check("sem mapa ainda", not director.map.obtained)
	_check("sem telefone: tecla T desligada", not session.phone.history_key_enabled)

	await _use("patio.bilhete")
	await _close_docs()
	# ---------------------------------------------------------- mapa
	await _use("patio.mapa")
	await _until(func(): return cutscenes_seen.has("cena_mapa"), 300)
	var map_was_open := false
	while director.cutscenes.playing:
		map_was_open = map_was_open or director.map.is_open()
		await _frame()
	await _until(func(): return not director.is_busy(), 6000)
	_check("cena do mapa tocou", cutscenes_seen.has("cena_mapa"))
	_check("o mapa abriu na cena (a voz se escreve nele)", map_was_open)
	_check("mapa fechado depois da cena", not director.map.is_open())
	_check("mapa obtido", director.map.obtained)
	_check("escrito do mapa: 'NÃO FAÇA BARULHO'", _has_note("patio", "NÃO FAÇA BARULHO"))
	_check("nenhuma fala da voz no telefone", session.phone.history.is_empty())
	_check("porta do pátio destrancada", not _door("patio.porta").is_locked())
	_check("objetivo: Sala de Português", session.hud.objective.contains("Português"))
	_check("alvo do mapa = Sala de Português", String(director.map._current_target().get("text", "")) == "Sala de Português")
	_check("saída escondida no mapa", not director.map._visible(_area("sala_saida")))
	_check("só dois professores na escola", get_nodes_in_group("monster").size() == 2 and _monster("reader") != null and _monster("maestro") != null)
	_grava_apresentacao("room_1", "room_1.porta")

	# ---------------------------------------------------------- 5 salas
	# [sala, z da porta, cena de entrada, professor, cena do despertar, pistas, pista barulhenta, pergunta, id da pergunta, esconderijo]
	var plan := [
		["room_1", -10.5, "cena_portugues", "reader", "cena_leitor_desperta",
			["room_1.quadro", "room_1.caderno", "room_1.chamada"], "room_1.livro_preso", "room_1.gaveta", &"port_gaveta", "room_1.esconderijo_mesa"],
		["room_2", -40.5, "cena_matematica", "", "",
			["room_2.quadro", "room_2.prova", "room_2.comanda", "room_2.transferidor", "room_2.diario"], "", "room_2.cofre", &"mat_cofre", ""],
		["room_3", -95.5, "cena_ciencias", "", "",
			["room_3.cartaz_ph", "room_3.caderno", "room_3.frascos", "room_3.relatorio"], "", "room_3.armario", &"cie_frasco", ""],
		["room_4", -119.9, "cena_geografia", "", "",
			["room_4.rosa", "room_4.plano", "room_4.globo", "room_4.foto"], "", "room_4.mapa_cidade", &"geo_ponto", ""],
		["room_5", -175.0, "cena_musica", "maestro", "cena_maestro_toca",
			["room_5.quadro", "room_5.partitura", "room_5.bilhete", "room_5.programa"], "room_5.piano", "room_5.teclado", &"mus_teclado", "room_5.esconderijo_mesa"],
	]
	for r in plan:
		var rid := String(r[0])
		var door := _door("%s.porta" % rid)
		var has_teacher := String(r[3]) != ""
		var monster: MonsterController = _monster(r[3]) if has_teacher else null
		_check("%s: porta destrancada na hora certa" % rid, not door.is_locked())
		door.open(false, true)
		await _teleport(Vector3(-6.0, 0.05, float(r[1])))
		await _until(func(): return cutscenes_seen.has(r[2]), 300)
		await _until(func(): return not director.is_busy(), 6000)
		_check("%s: cena de entrada" % rid, cutscenes_seen.has(r[2]))
		await _teleport(Vector3(-10.0, 0.05, float(r[1]) - 2.0))
		await _until(func(): return not door.is_open(), 300)
		_check("%s: a porta fechou atrás dela" % rid, not door.is_open())
		_check("%s: e ficou trancada" % rid, door.is_locked())
		_check("%s: escrito de entrada no mapa" % rid, _has_note(rid, String(director._flow()[rid].notes.enter).split("\n")[0]))
		_check("%s: fase 'busca'" % rid, director.get_room_phase(rid) == "busca")
		if rid == "room_2":
			# erro relatado: cadeado usado antes da hora travava em "já examinou"
			await _use(r[7])
			await _phys(3)
			await _use(r[7])
			await _phys(3)
			var msg: String = router._feedback_label.text
			_check("cadeado antes da hora: mostra o motivo de novo (\"%s\")" % msg.replace("\n", " / "), msg.contains("Ainda falta") and not msg.contains("já examinou"))
		for obj in r[5]:
			await _use(obj)
			await _close_docs()
		if has_teacher:
			_check("%s: professor dormindo antes do barulho" % rid, not monster.is_active())
			# a pista barulhenta
			await _use(r[6])
			await _close_docs()
			await _until(func(): return cutscenes_seen.has(r[4]), 300)
			await _until(func(): return not director.is_busy() and director._queue.is_empty(), 6000)
			_check("%s: a pista barulhenta acordou o professor" % rid, monster.is_active())
			_check("%s: cena do professor despertando" % rid, cutscenes_seen.has(r[4]))
			_check("%s: escrito 'esconda-se'" % rid, _has_note(rid, String(director._flow()[rid].notes.awake).split("\n")[0]))
			_check("%s: objetivo: esconder" % rid, session.hud.objective.contains("Esconda-se"))
			# a pergunta não abre com ele acordado
			await _use(r[7])
			await _phys(3)
			_check("%s: pergunta bloqueada com ele acordado" % rid, not puzzle_ui.is_open())
			# esconde (fora da vista dele) e espera ele se acalmar; ele continua caçando
			var start_pos := monster.global_position
			var spot := _spot(String(r[9]))
			player.enter_hiding(spot)
			await _phys(3)
			_check("%s: escondida" % rid, player.is_hidden())
			var max_move := 0.0
			var t := 0
			while director.get_room_phase(rid) != "calmo" and t < 60 * 120:
				await _frame()
				t += 1
				max_move = maxf(max_move, monster.global_position.distance_to(start_pos))
				if t == 60 * 20:
					_check("%s: ainda acordado aos 20 s (perseguição mínima de 30 s)" % rid, monster.is_active())
			var awake_s := float(director._awake_time.get(rid, 0.0))
			_check("%s: o professor se mexeu procurando por ela (%.1f m)" % [rid, max_move], max_move > 4.0)
			_check("%s: 'ele se acalmou' só depois de 30 s (%.0f s acordado)" % [rid, awake_s], director.get_room_phase(rid) == "calmo" and awake_s >= 30.0)
			_check("%s: escrito 'ele se acalmou' no mapa" % rid, _has_note(rid, String(director._flow()[rid].notes.calm).split("\n")[0]))
			_check("%s: monstro voltou a dormir no posto" % rid, not monster.is_active() and monster.global_position.distance_to(monster.get_home_position()) < 0.5)
			player.leave_hiding()
			await _phys(10)
			_check("%s: checkpoint 'ele se acalmou'" % rid, saves.has("ele se acalmou"))
			saves.clear()
		# a pergunta (última pista)
		await _use(r[7])
		await _answer(r[8])
		await _until(func(): return not director.is_busy() and director._queue.is_empty(), 600)
		_check("%s: a porta abriu sozinha" % rid, door.is_open() and not door.is_locked())
		_check("%s: escrito 'a porta abriu'" % rid, _has_note(rid, String(director._flow()[rid].notes.open).split("\n")[0]))
		if has_teacher:
			_check("%s: o professor acordou de novo" % rid, monster.is_active())
			_check("%s: fase 'fuga' + objetivo correr" % rid, director.get_room_phase(rid) == "fuga" and session.hud.objective.contains("Corra"))
			monster.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			_check("%s: sem professor, sem perseguição" % rid, director.get_room_phase(rid) == "fuga" and not session.hud.objective.contains("Corra"))
		# sai pela porta
		await _teleport(Vector3(0, 0.05, float(r[1]) - 3.0))
		await _until(func(): return rooms.is_completed(StringName(rid)), 300)
		_check("%s: concluída ao sair" % rid, rooms.is_completed(StringName(rid)))
		await _until(func(): return not door.is_open(), 300)
		_check("%s: a porta fechou atrás dela" % rid, not door.is_open() and door.is_locked())
		if has_teacher:
			monster.process_mode = Node.PROCESS_MODE_INHERIT
			_check("%s: professor de volta ao posto, dormindo" % rid, not monster.is_active() and monster.global_position.distance_to(monster.get_home_position()) < 0.5)
		await _until(func(): return narrative.has_fired(StringName("nota_%s_fim" % rid)) and not director.is_busy() and director._queue.is_empty(), 600)
		_check("%s: escrito de saída no mapa" % rid, _has_note(rid, String(director._flow()[rid].notes.done).split("\n")[0]))
		_check("%s: sala riscada no mapa" % rid, director.map._completed_rooms().has(rid))
		var proxima := {"room_1": "room_2", "room_2": "room_3", "room_3": "room_4", "room_4": "room_5", "room_5": "final"}
		_grava_apresentacao(proxima[rid], (proxima[rid] + ".porta") if proxima[rid] != "final" else "sala_saida.porta")
		if rid == "room_4":
			_check("saída ainda escondida antes de Música", not director.map._visible(_area("sala_saida")) and _door("sala_saida.porta").is_locked())

	# ---------------------------------------------------------- saída (fim do corredor)
	_check("saída aparece no mapa depois de Música", director.map._visible(_area("sala_saida")))
	_check("porta da saída destrancada", not _door("sala_saida.porta").is_locked())
	_check("objetivo: a saída", session.hud.objective.contains("saída"))
	_door("sala_saida.porta").open(false, true)
	await _teleport(Vector3(1.0, 0.05, -194.0))
	await _until(func(): return cutscenes_seen.has("cena_monitores"), 300)
	await _until(func(): return not director.is_busy(), 6000)
	_check("cena dos monitores", cutscenes_seen.has("cena_monitores"))
	await _use("sala_saida.ficha")
	await _until(func(): return cutscenes_seen.has("cena_final"), 300)
	var map_in_final := false
	while director.cutscenes.playing:
		map_in_final = map_in_final or director.map.is_open()
		await _frame()
	await _until(func(): return director.ended, 9000)
	_check("final: o mapa revela quem escrevia", map_in_final and _has_note("sala_saida", "OS TESTES ACABARAM"))
	_check("final: fim do capítulo", director.ended)
	_check("22 papéis lidos (17 pistas + 5 documentos da história): %d" % docs_seen, docs_seen == 22)
	print("tempo de jogo simulado: %.1f min (%d quadros)" % [frames / 3600.0, frames])
	print("RESULTADO: %d ok, %d falhas" % [passed, failed])
	SaveSystem.delete_save()
	quit(1 if failed > 0 else 0)


# ------------------------------------------------------------------ ajudas

func _has_note(area: String, text: String) -> bool:
	for n in director.map.notes:
		if String(n.area) == area and String(n.text).contains(text):
			return true
	return false


func _area(id: String) -> Dictionary:
	for a in director.map.areas:
		if String(a.id) == id:
			return a
	return {}


## Versão 6.1 — com "-- --gerar-saves-apresentacao", grava o começo de cada
## sala em data/apresentacao/<sala>.json (as cenas de scenes/apresentacao/
## carregam esses saves: dá para abrir qualquer sala direto com F6).
func _grava_apresentacao(nome: String, door_id: String) -> void:
	if not OS.get_cmdline_user_args().has("--gerar-saves-apresentacao"):
		return
	var d := _door(door_id)
	var data := session.build_save()
	var dp := d.global_position
	# no corredor, de frente para a porta da próxima sala
	var pos := Vector3(0.0, 0.05, dp.z) if absf(dp.x) > 2.0 else Vector3(dp.x, 0.05, dp.z + 4.0)
	var look := Vector3(dp.x, 0.0, dp.z) - Vector3(pos.x, 0.0, pos.z)
	data["player"] = {"pos": [pos.x, pos.y, pos.z], "visual_yaw": atan2(look.x, look.z)}
	data["current_room"] = ""
	data["reason"] = "apresentação: %s" % nome
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/apresentacao"))
	var f := FileAccess.open("res://data/apresentacao/%s.json" % nome, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("  save da apresentação: ", nome)


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
	# versão 5.7: a resposta errada da melodia faz o Maestro reagir (testado em musica_enigma_test)
	if pid != &"mus_teclado":
		puzzle_ui._submit_answer(wrong)
		_check("%s: resposta errada recusada" % pid, not puzzles.is_solved(pid))
	if puzzle_ui._code_display != null:
		# códigos: digitados no teclado da tela, um número de cada vez (confere sozinho)
		await _phys(50)
		for d in String(ANSWERS[pid]):
			puzzle_ui._code_digit(d)
		await _until(func(): return puzzles.is_solved(pid), 120)
	else:
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
