extends SceneTree
## Gera o conteúdo de TESTE da Etapa 3 em res://data usando o ResourceSaver.

const T := PuzzleData.QuestionType

func _initialize() -> void:
	push_error("OBSOLETO (Prompt 2): os dados agora ficam em data/game_data.json, carregado por GameData. Esta ferramenta gravava os .tres antigos (arquivados em docs/legado/legado_tres_pre_json.zip) e foi desativada para não criar um segundo banco.")
	quit(1)
	return
	DirAccess.make_dir_recursive_absolute("res://data/puzzles")
	DirAccess.make_dir_recursive_absolute("res://data/clues")

	var clues := [
		_clue(&"teste_pista_caderno", &"room_1", &"teste_ciencias_alternativa", ClueData.SourceType.DOCUMENT,
			&"room_1.caderno_laboratorio", "[TESTE] Caderno de laboratório",
			"[TESTE] Texto provisório. A anotação aponta qual frasco foi usado, sem dizer a resposta.", []),
		_clue(&"teste_pista_tabela", &"room_1", &"teste_ciencias_codigo", ClueData.SourceType.OBJECT,
			&"room_1.tabela_periodica", "[TESTE] Tabela marcada",
			"[TESTE] Quatro elementos circulados na tabela.", [&"teste_pista_caderno"]),
		_clue(&"teste_pista_partitura", &"room_test", &"teste_musica_sequencia", ClueData.SourceType.DOCUMENT,
			&"room_test.partitura", "[TESTE] Partitura rasgada",
			"[TESTE] Metade de uma melodia.", []),
	]
	var clue_res: Array[ClueData] = []
	for clue in clues:
		clue_res.append(_save(clue, "res://data/clues/%s.tres" % clue.id))

	var puzzles := []

	var p := _puzzle(&"teste_ciencias_alternativa", &"room_1", "Ciências", T.MULTIPLE_CHOICE, "[TESTE] Qual frasco?")
	p.options = PackedStringArray(["Frasco azul", "Frasco verde", "Frasco vermelho"])
	p.correct_option = 1
	p.hint_ids = [&"teste_pista_caderno"]
	p.required_interactions = [&"room_1.caderno_laboratorio"]
	p.monster_id = &"octopus"
	p.unlocks_exit = &"room_1_exit"
	puzzles.append(p)

	p = _puzzle(&"teste_ciencias_codigo", &"room_1", "Ciências", T.DOOR_CODE, "[TESTE] Cadeado do armário")
	p.correct_answer = "0427"
	p.hint_ids = [&"teste_pista_tabela"]
	p.required_clue_ids = [&"teste_pista_tabela"]
	p.prerequisite_puzzle_ids = [&"teste_ciencias_alternativa"]
	p.unlocks_exit = &"room_1_exit"
	puzzles.append(p)

	p = _puzzle(&"teste_musica_sequencia", &"room_test", "Música", T.MUSIC_SEQUENCE, "[TESTE] Melodia")
	p.correct_sequence = PackedStringArray(["Mi", "Ré", "Dó", "Ré", "Mi"])
	p.hint_ids = [&"teste_pista_partitura"]
	p.monster_id = &"maestro"
	p.wrong_step_emits_event = true
	puzzles.append(p)

	p = _puzzle(&"teste_numerico", &"room_test", "Matemática", T.NUMERIC, "[TESTE] Valor aproximado")
	p.correct_answer = "3,14"
	p.numeric_tolerance = 0.01
	puzzles.append(p)

	p = _puzzle(&"teste_documento", &"room_test", "Geografia", T.DOCUMENT_INTERPRETATION, "[TESTE] Onde fica a passagem?")
	p.correct_answer = "subsolo"
	p.accepted_answers = PackedStringArray(["porão", "o subsolo"])
	puzzles.append(p)

	p = _puzzle(&"teste_associacao", &"room_test", "Artes", T.OBJECT_MATCHING, "[TESTE] Cada pincel na sua tinta")
	p.correct_pairs = {"pincel_fino": "azul", "pincel_largo": "vermelho"}
	puzzles.append(p)

	p = _puzzle(&"teste_imagens", &"room_test", "Artes", T.IMAGE_ORDER, "[TESTE] Ordem dos quadros")
	p.correct_sequence = PackedStringArray(["quadro_c", "quadro_a", "quadro_b"])
	puzzles.append(p)

	p = _puzzle(&"teste_logica", &"room_test", "Matemática", T.LOGIC_SEQUENCE, "[TESTE] Próximos da sequência")
	p.correct_sequence = PackedStringArray(["2", "4", "8", "16"])
	puzzles.append(p)

	var puzzle_res: Array[PuzzleData] = []
	for puzzle in puzzles:
		puzzle_res.append(_save(puzzle, "res://data/puzzles/%s.tres" % puzzle.id))

	var db := PuzzleDatabase.new()
	db.puzzles = puzzle_res
	db.clues = clue_res
	print("validação: ", db.validate())
	ResourceSaver.save(db, "res://data/puzzle_database.tres")
	print("conteúdo de teste gerado")
	quit()


func _puzzle(id: StringName, room: StringName, subject: String, type: int, title: String) -> PuzzleData:
	var p := PuzzleData.new()
	p.id = id
	p.room_id = room
	p.subject = subject
	p.question_type = type
	p.title = title
	p.description = "[TESTE] Enunciado provisório."
	p.solution_explanation = "[TESTE] Explicação provisória."
	return p


func _clue(id, room, puzzle, source, object_id, title, content, required) -> ClueData:
	var c := ClueData.new()
	c.id = id
	c.room_id = room
	c.puzzle_id = puzzle
	c.source_type = source
	c.source_object_id = object_id
	c.title = title
	c.content = content
	c.required_clue_ids.assign(required)
	return c


func _save(res: Resource, path: String) -> Resource:
	var err := ResourceSaver.save(res, path)
	assert(err == OK, "falha ao salvar " + path)
	return load(path)
