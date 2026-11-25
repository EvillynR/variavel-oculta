extends SceneTree
## Versão 5.7 — o enigma da melodia na Sala de Música (o Maestro).
##  - todas as salas têm onde escrever/escolher a resposta (teclado na tela
##    para códigos, alternativas com clique ou tecla de número);
##  - só Português e Música têm professor; as outras: pistas → pergunta → porta;
##  - Música: o piano só toca depois das pistas; o Maestro se senta e toca; as
##    notas aparecem UMA de cada vez na lousa (com número e som) e somem; no fim a
##    lousa fica vazia; ele para, observa e acorda (caça);
##  - escondida, ele se acalma; teclado da porta: errado → som desafinado, o
##    Maestro reage e caça de novo; o piano pode ser pedido de novo; certo
##    (3784) → destrava e a porta abre.
## Uso: godot --headless --fixed-fps 60 --path . --script res://tests/musica_enigma_test.gd

var main: Node
var player: CharacterBody3D
var session: GameSession
var director: StoryDirector
var rooms: RoomProgressManager
var interactor: PlayerInteractor
var puzzle_ui: PuzzleUI
var puzzles: PuzzleManager
var clues: ClueManager
var lousa: LousaNotas
var teclado: TecladoPorta
var passed := 0
var failed := 0
var frames := 0
var seen: Array = []
var caught := 0


func _initialize() -> void:
	SaveSystem.save_path = "user://teste_musica.json"
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
	interactor = get_first_node_in_group("player_interactor")
	puzzle_ui = get_first_node_in_group("puzzle_ui")
	puzzles = main.get_node("Systems/PuzzleManager")
	clues = get_first_node_in_group("clue_manager")
	lousa = get_first_node_in_group("lousa_notas")
	teclado = get_first_node_in_group("teclado_porta")
	director.cutscene_started.connect(func(id): seen.append(String(id)))
	for m in get_nodes_in_group("monster"):
		m.player_caught.connect(func(): caught += 1)
	var gom := get_first_node_in_group("game_over_ui")
	if gom != null:
		gom.process_mode = Node.PROCESS_MODE_DISABLED

	# ---------------------------------------------------------- todas as salas
	var flow: Dictionary = director._flow()
	var music: Dictionary = director.music_config("room_5")
	for rid in ["room_1", "room_2", "room_3", "room_4", "room_5"]:
		var cfg: Dictionary = flow[rid]
		var p: PuzzleData = puzzles.database.get_puzzle(StringName(String(cfg.puzzle_id)))
		puzzle_ui._active_puzzle = p
		puzzle_ui._root.visible = true
		puzzle_ui._rebuild_content()
		var ok := false
		if p.question_type == PuzzleData.QuestionType.DOOR_CODE:
			ok = puzzle_ui._code_display != null and puzzle_ui._keypad_buttons.size() == 12
		elif p.question_type == PuzzleData.QuestionType.MULTIPLE_CHOICE:
			ok = puzzle_ui._option_buttons.size() == p.options.size() and p.options.size() >= 2
		else:
			ok = puzzle_ui._answer != null
		_check("%s: dá para responder %s (%s)" % [rid, p.id, PuzzleData.QuestionType.keys()[p.question_type]], ok)
		puzzle_ui._root.visible = false
		puzzle_ui._active_puzzle = null
		var teacher := String(cfg.get("monster_id", ""))
		var expect_teacher: bool = rid in ["room_1", "room_5"]
		_check("%s: %s" % [rid, "com professor (fluxo do monstro)" if expect_teacher else "sem professor (pistas → pergunta → porta)"], (teacher != "") == expect_teacher)
	_check("só Música tem enigma de melodia", director.story.get("music_sequences", {}).keys() == ["room_5"])
	var answer := ""
	for n in music.notas:
		answer += str(int(n.numero))
	_check("sequência configurada Dó=3, Mi=7, Si=8, Ré=4 → %s" % answer, answer == "3784" and music.notas.size() == 4)
	_check("a senha do teclado vem da sequência", puzzles.database.get_puzzle(&"mus_teclado").correct_answer == answer)
	_check("lousa e teclado da porta na cena", lousa != null and teclado != null)

	await _until(func(): return director.cutscenes.playing, 300)
	await _until(func(): return not director.is_busy(), 6000)

	# ---------------------------------------------------------- entra na Música
	for done in [&"room_1", &"room_2", &"room_3", &"room_4"]:
		rooms._set_state(done, RoomData.RoomState.COMPLETED)
	await _phys(5)
	var door := _door("room_5.porta")
	door.unlock()
	door.open(false, true)
	await _teleport(Vector3(-6.0, 0.05, -175.0))
	await _until(func(): return seen.has("cena_musica"), 300)
	await _until(func(): return not director.is_busy(), 6000)
	await _teleport(Vector3(-10.0, 0.05, -177.0))
	await _until(func(): return not door.is_open(), 300)
	_check("porta fechou e trancou atrás dela", not door.is_open() and door.is_locked())
	_check("fase 'busca'", director.get_room_phase("room_5") == "busca")
	await _phys(10)
	_check("som ambiente da sala tocando", director.audio.ambient_name == String(music.ambiente))
	var maestro := _monster("maestro")
	_check("Maestro dormindo no posto", not maestro.is_active())

	# piano antes das pistas: não toca
	await _use("room_5.piano")
	await _phys(10)
	_check("piano antes das pistas: avisa o que falta ler (\"%s\")" % director._toast.text.replace("\n", " "), director._toast.text.contains("Antes, leia") and not seen.has("cena_maestro_toca"))
	_check("e o Maestro continua dormindo", not maestro.is_active())
	for obj in ["room_5.quadro", "room_5.partitura", "room_5.bilhete"]:
		await _use(obj)
		await _close_docs()
	# teclado antes da melodia: ainda falta a pista final
	await _use("room_5.teclado")
	await _phys(5)
	_check("teclado antes da melodia não abre", not puzzle_ui.is_open())

	# ---------------------------------------------------------- a melodia
	var shown: Array = []
	var visible_max := [0]
	lousa.nota_mostrada.connect(func(i, nome, numero):
		shown.append([i, nome, numero, lousa._som.stream.resource_path if lousa._som.stream != null else "", maestro.global_position, paused]))
	await _use("room_5.piano")
	await _until(func(): return lousa.apresentando, 1200)
	_check("E no piano: começa a cena da melodia", seen.has("cena_maestro_toca") and director.cutscenes.playing)
	var at_piano: Array = music.maestro_piano
	_check("o Maestro foi para o piano", Vector2(maestro.global_position.x - float(at_piano[0]), maestro.global_position.z - float(at_piano[2])).length() < 0.3)
	var anims := maestro.find_children("*", "MonsterAnimator", true, false)
	_check("Maestro tocando (animação 'Tocando')", not anims.is_empty() and (anims[0] as MonsterAnimator).current == &"idle")
	var states: Array = []
	while lousa.apresentando:
		var cur: String = String(lousa.nota_atual.get("nome", ""))
		if states.is_empty() or states[-1] != cur:
			states.append(cur)
		await _frame()
	if states.is_empty() or states[-1] != String(lousa.nota_atual.get("nome", "")):
		states.append(String(lousa.nota_atual.get("nome", "")))
	_check("4 notas mostradas, na ordem: %s" % str(shown.map(func(x): return "%s=%d" % [x[1], x[2]])),
		shown.size() == 4 and shown[0][1] == "Dó" and shown[0][2] == 3 and shown[1][1] == "Mi" and shown[1][2] == 7 and shown[2][1] == "Si" and shown[2][2] == 8 and shown[3][1] == "Ré" and shown[3][2] == 4)
	_check("cada nota com o seu som (%s)" % str(shown.map(func(x): return String(x[3]).get_file())),
		shown.size() == 4 and String(shown[0][3]).ends_with("do.wav") and String(shown[1][3]).ends_with("mi.wav") and String(shown[2][3]).ends_with("si.wav") and String(shown[3][3]).ends_with("re.wav"))
	_check("uma nota de cada vez, lousa vazia entre elas: %s" % str(states), states == ["", "Dó", "", "Mi", "", "Si", "", "Ré", ""] or states == ["Dó", "", "Mi", "", "Si", "", "Ré", ""])
	_check("o jogo fica pausado enquanto ele toca", shown.size() == 4 and shown.all(func(x): return x[5]))
	_check("no fim a lousa fica vazia (sem consultar de novo)", lousa.nota_atual.is_empty() and not lousa._nota.visible and not lousa._rotulo.visible)
	await _until(func(): return not director.cutscenes.playing, 3000)
	await _until(func(): return not director.is_busy() and director._queue.is_empty(), 3000)
	_check("depois de tocar ele acorda e caça", maestro.is_active() and director.get_room_phase("room_5") == "acordado")
	_check("objetivo: esconder", session.hud.objective.contains("Esconda-se"))
	_check("pista final descoberta (sem números)", clues.is_discovered(&"mus_sequencia") and not _has_digit(puzzles.database.get_clue(&"mus_sequencia").content))
	_check("nenhuma pista da sala mostra a senha", not _any_clue_has(answer))
	# enquanto ele caça: piano e teclado não funcionam
	await _use("room_5.teclado")
	await _phys(3)
	_check("teclado bloqueado com ele acordado", not puzzle_ui.is_open())
	await _hide_until_calm(maestro)

	# ---------------------------------------------------------- resposta errada
	await _use("room_5.teclado")
	await _until(func(): return puzzle_ui.is_open(), 120)
	_check("com ele calmo o teclado abre (teclado numérico na tela)", puzzle_ui.is_open() and puzzle_ui._code_display != null)
	await _phys(30)
	var before_erro := director.audio.history.size()
	for d in "347":
		puzzle_ui._code_digit(d)
	_check("o visor mostra os números digitados (%s / pedestal %s)" % [puzzle_ui._code_display.text, teclado._visor.text], puzzle_ui._code_display.text == "3 4 7 _" and teclado._visor.text == "3 4 7 _")
	puzzle_ui._code_digit("8")
	await _until(func(): return not puzzle_ui.is_open(), 300)
	_check("4 dígitos: confere sozinho; errado fecha o painel", not puzzle_ui.is_open() and not puzzles.is_solved(&"mus_teclado"))
	_check("som desafinado", director.audio.history.slice(before_erro).has("erro"))
	await _until(func(): return seen.has("cena_maestro_erro"), 300)
	_check("o Maestro reage (cena 'Desafinado')", seen.has("cena_maestro_erro"))
	await _until(func(): return not director.is_busy() and director._queue.is_empty(), 3000)
	_check("e volta a caçar", maestro.is_active() and director.get_room_phase("room_5") == "acordado")
	_check("objetivo e mapa avisam do erro", session.hud.objective.contains("Desafinou") and _has_note("room_5", "DESAFINADO"))
	await _hide_until_calm(maestro)

	# ---------------------------------------------------------- ouvir de novo
	var n_before := seen.filter(func(x): return x == "cena_maestro_toca").size()
	shown.clear()
	await _use("room_5.piano")
	await _until(func(): return lousa.apresentando, 1200)
	await _until(func(): return not lousa.apresentando, 3000)
	await _until(func(): return not director.is_busy() and director._queue.is_empty(), 3000)
	_check("com ele calmo dá para pedir a melodia de novo (%d notas)" % shown.size(), seen.filter(func(x): return x == "cena_maestro_toca").size() == n_before + 1 and shown.size() == 4)
	_check("e ele acorda outra vez", maestro.is_active() and director.get_room_phase("room_5") == "acordado")
	await _hide_until_calm(maestro)

	# ---------------------------------------------------------- resposta certa (teclado físico)
	await _use("room_5.teclado")
	await _until(func(): return puzzle_ui.is_open(), 120)
	await _phys(30)
	var before_ok := director.audio.history.size()
	for k in [KEY_3, KEY_7, KEY_KP_8, KEY_4]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.pressed = true
		puzzle_ui._input(ev)
	await _until(func(): return puzzles.is_solved(&"mus_teclado"), 120)
	_check("3784 pelo teclado do computador: certo", puzzles.is_solved(&"mus_teclado"))
	_check("som de destravar", director.audio.history.slice(before_ok).has("destrava"))
	_check("pedestal fica verde (ABERTO)", teclado._visor.text == "ABERTO")
	puzzle_ui.close_puzzle()
	await _until(func(): return not director.is_busy() and director._queue.is_empty(), 600)
	_check("a porta abriu sozinha", door.is_open() and not door.is_locked())
	_check("o Maestro acordou de novo (fuga)", maestro.is_active() and director.get_room_phase("room_5") == "fuga")
	await _use("room_5.piano")
	await _phys(5)
	_check("piano depois de resolver: não toca de novo", seen.filter(func(x): return x == "cena_maestro_toca").size() == n_before + 1)
	maestro.process_mode = Node.PROCESS_MODE_DISABLED
	await _teleport(Vector3(0, 0.05, -178.0))
	await _until(func(): return rooms.is_completed(&"room_5"), 300)
	_check("saiu: Música concluída", rooms.is_completed(&"room_5"))
	await _phys(10)
	_check("o som ambiente para fora da sala", director.audio.ambient_name == "")
	_check("ninguém foi pega no teste", caught == 0)
	print("RESULTADO: %d ok, %d falhas" % [passed, failed])
	SaveSystem.delete_save()
	quit(1 if failed > 0 else 0)


# ------------------------------------------------------------------ ajudas

func _hide_until_calm(m: MonsterController) -> void:
	var spot := _spot("room_5.esconderijo_mesa")
	player.enter_hiding(spot)
	await _phys(3)
	var t := 0
	while director.get_room_phase("room_5") != "calmo" and t < 60 * 120:
		await _frame()
		t += 1
	_check("escondida: ele se acalmou (%.0f s)" % float(director._awake_time.get("room_5", 0.0)), director.get_room_phase("room_5") == "calmo" and not m.is_active())
	player.leave_hiding()
	await _phys(10)


func _has_digit(t: String) -> bool:
	for c in t:
		if c >= "0" and c <= "9":
			return true
	return false


func _any_clue_has(code: String) -> bool:
	for c in puzzles.database.clues:
		if String(c.room_id) == "room_5" and c.content.contains(code):
			return true
	return false


func _has_note(area: String, text: String) -> bool:
	for n in director.map.notes:
		if String(n.area) == area and String(n.text).contains(text):
			return true
	return false


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
		print("  ok  ", name)
	else:
		failed += 1
		print("  FALHA  ", name)
