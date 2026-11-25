extends SceneTree
## Testes headless do sistema de enigmas e pistas (Etapa 3), usando os nós
## reais da cena principal e o conteúdo de teste em res://data.

var passed := 0
var failed := 0
var counts := {}

func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var clues: ClueManager = main.get_node("Systems/ClueManager")
	var puzzles: PuzzleManager = main.get_node("Systems/PuzzleManager")
	var db: PuzzleDatabase = puzzles.database
	var R := PuzzleManager.SubmitResult

	for sig in ["clue_discovered", "interaction_registered", "puzzle_solved", "exit_unlocked", "wrong_step_event", "puzzle_became_available"]:
		counts[sig] = 0
	clues.clue_discovered.connect(func(_c): counts["clue_discovered"] += 1)
	puzzles.interaction_registered.connect(func(_i): counts["interaction_registered"] += 1)
	puzzles.puzzle_solved.connect(func(_p): counts["puzzle_solved"] += 1)
	puzzles.exit_unlocked.connect(func(_e): counts["exit_unlocked"] += 1)
	puzzles.wrong_step_event.connect(func(_p): counts["wrong_step_event"] += 1)
	puzzles.puzzle_became_available.connect(func(_p): counts["puzzle_became_available"] += 1)

	print("--- integridade dos dados")
	_check("banco de teste sem erros", db.validate().is_empty(), str(db.validate()))
	var broken := PuzzleDatabase.new()
	var a := PuzzleData.new(); a.id = &"x"; a.question_type = PuzzleData.QuestionType.DOOR_CODE; a.correct_answer = "1"
	var b := PuzzleData.new(); b.id = &"x"; b.question_type = PuzzleData.QuestionType.DOOR_CODE; b.correct_answer = "1"
	b.hint_ids = [&"nao_existe"]
	broken.puzzles = [a, b]
	var problems := broken.validate()
	_check("detecta id duplicado e pista inexistente", problems.size() == 2, str(problems))

	print("--- validação por tipo")
	var P := func(id): return db.get_puzzle(id)
	_v(P.call(&"teste_ciencias_alternativa"), 1, true); _v(P.call(&"teste_ciencias_alternativa"), 0, false)
	_v(P.call(&"teste_ciencias_alternativa"), "1", false)
	_v(P.call(&"teste_ciencias_codigo"), " 04-27 ", true); _v(P.call(&"teste_ciencias_codigo"), "0472", false)
	_v(P.call(&"teste_numerico"), "3.14", true); _v(P.call(&"teste_numerico"), "3,145", true)
	_v(P.call(&"teste_numerico"), "3,2", false); _v(P.call(&"teste_numerico"), "pi", false)
	_v(P.call(&"teste_documento"), "PORAO", true); _v(P.call(&"teste_documento"), "  o   Subsolo ", true)
	_v(P.call(&"teste_documento"), "telhado", false); _v(P.call(&"teste_documento"), "", false)
	_v(P.call(&"teste_associacao"), {"pincel_largo": "vermelho", "pincel_fino": "azul"}, true)
	_v(P.call(&"teste_associacao"), {"pincel_largo": "azul", "pincel_fino": "vermelho"}, false)
	_v(P.call(&"teste_associacao"), {"pincel_fino": "azul"}, false)
	_v(P.call(&"teste_imagens"), PackedStringArray(["quadro_c", "quadro_a", "quadro_b"]), true)
	_v(P.call(&"teste_imagens"), ["quadro_a", "quadro_c", "quadro_b"], false)
	_v(P.call(&"teste_logica"), ["2", "4", "8", "16"], true); _v(P.call(&"teste_logica"), ["2", "4", "8"], false)
	_v(P.call(&"teste_musica_sequencia"), ["mi", "re", "do", "re", "mi"], true)

	print("--- pistas")
	_check("pista com pré-requisito bloqueada", not clues.discover(&"teste_pista_tabela"), "")
	_check("descoberta inicial", clues.discover(&"teste_pista_caderno"), "")
	_check("descoberta repetida não duplica", not clues.discover(&"teste_pista_caderno") and counts["clue_discovered"] == 1, "sinais=%d" % counts["clue_discovered"])
	_check("pista inexistente não quebra", not clues.discover(&"nao_existe"), "")
	_check("pistas de teste não revelam resposta", db.clues.all(func(c): return not c.reveals_answer), "")

	print("--- progressão da sala de teste (room_1)")
	var mc := &"teste_ciencias_alternativa"
	var code := &"teste_ciencias_codigo"
	_check("sem interação: resposta recusada", puzzles.submit_answer(mc, 1) == R.NOT_AVAILABLE and puzzles.get_attempts(mc) == 0, "")
	_check("interação errada não libera", puzzles.register_interaction(&"room_1.objeto_errado") and not puzzles.is_available(mc), "")
	puzzles.register_interaction(&"room_1.caderno_laboratorio")
	_check("interação repetida não duplica evento", not puzzles.register_interaction(&"room_1.caderno_laboratorio") and counts["interaction_registered"] == 2, "eventos=%d" % counts["interaction_registered"])
	_check("enigma disponível após interação certa", puzzles.is_available(mc), "")
	_check("resposta errada: INCORRECT", puzzles.submit_answer(mc, 2) == R.INCORRECT, "")
	_check("saída fechada após erro", not puzzles.is_exit_unlocked(&"room_1_exit"), "")
	_check("resposta certa: CORRECT", puzzles.submit_answer(mc, 1) == R.CORRECT and puzzles.is_solved(mc), "")
	_check("já resolvido não conta de novo", puzzles.submit_answer(mc, 1) == R.ALREADY_SOLVED and counts["puzzle_solved"] == 1, "")
	_check("saída ainda fechada (falta o 2º enigma)", not puzzles.is_exit_unlocked(&"room_1_exit") and counts["exit_unlocked"] == 0, "")
	_check("código exige a pista da tabela", puzzles.submit_answer(code, "0427") == R.NOT_AVAILABLE, "")
	clues.discover_from_object(&"room_1.tabela_periodica")
	_check("pista liberada pelo objeto certo", clues.is_discovered(&"teste_pista_tabela"), "")
	_check("dicas descobertas consultáveis", puzzles.get_discovered_hints(code).size() == 1, "")
	_check("código certo libera a saída uma vez", puzzles.submit_answer(code, "0427") == R.CORRECT and puzzles.is_exit_unlocked(&"room_1_exit") and counts["exit_unlocked"] == 1, "")
	_check("saída sem enigma ligado continua fechada", not puzzles.is_exit_unlocked(&"saida_inexistente"), "")

	print("--- sequência musical nota a nota")
	var music := &"teste_musica_sequencia"
	_check("nota certa: em andamento", puzzles.submit_sequence_step(music, "Mi") == R.IN_PROGRESS, "")
	_check("nota errada reinicia e gera evento", puzzles.submit_sequence_step(music, "Fá") == R.INCORRECT and puzzles.get_sequence_progress(music) == 0 and counts["wrong_step_event"] == 1, "")
	var last := R.INCORRECT
	for note in ["Mi", "Ré", "Dó", "Ré", "Mi"]:
		last = puzzles.submit_sequence_step(music, note)
	_check("sequência completa resolve", last == R.CORRECT and puzzles.is_solved(music), "")
	_check("nenhum evento de erro extra", counts["wrong_step_event"] == 1, "")

	print("--- persistência em memória")
	var clue_save := clues.get_save_data()
	var puzzle_save := puzzles.get_save_data()
	var json_roundtrip: Dictionary = JSON.parse_string(JSON.stringify({"c": clue_save, "p": puzzle_save}))
	var clues2 := ClueManager.new(); clues2.database = db
	var puzzles2 := PuzzleManager.new(); puzzles2.database = db; puzzles2.clue_manager = clues2
	root.add_child(clues2); root.add_child(puzzles2)
	var reemitted := [0]
	puzzles2.exit_unlocked.connect(func(_e): reemitted[0] += 1)
	clues2.load_save_data(json_roundtrip["c"])
	puzzles2.load_save_data(json_roundtrip["p"])
	await process_frame
	_check("estado restaurado via JSON", puzzles2.is_solved(code) and puzzles2.is_exit_unlocked(&"room_1_exit") and clues2.is_discovered(&"teste_pista_tabela") and puzzles2.has_interaction(&"room_1.caderno_laboratorio"), "")
	_check("carregar não reemite sinais", reemitted[0] == 0, "")
	_check("tentativas preservadas", puzzles2.get_attempts(mc) == puzzles.get_attempts(mc), "%d" % puzzles2.get_attempts(mc))

	print("RESULTADO: %d/%d testes passaram" % [passed, passed + failed])
	quit(1 if failed > 0 else 0)


func _v(puzzle: PuzzleData, answer: Variant, expected: bool) -> void:
	var got := AnswerValidator.is_correct(puzzle, answer)
	_check("%s ← %s" % [puzzle.id, str(answer)], got == expected, "esperado %s" % expected)


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("%s  %s  %s" % ["OK   " if ok else "FALHA", name, detail if not ok else ""])
