class_name PuzzleDatabase
extends Resource
## Conjunto de enigmas e pistas do jogo. Só dados e consultas.

@export var puzzles: Array[PuzzleData] = []
@export var clues: Array[ClueData] = []


func get_puzzle(puzzle_id: StringName) -> PuzzleData:
	for puzzle in puzzles:
		if puzzle != null and puzzle.id == puzzle_id:
			return puzzle
	return null


func get_clue(clue_id: StringName) -> ClueData:
	for clue in clues:
		if clue != null and clue.id == clue_id:
			return clue
	return null


func get_puzzles_for_room(room_id: StringName) -> Array[PuzzleData]:
	var result: Array[PuzzleData] = []
	for puzzle in puzzles:
		if puzzle != null and puzzle.room_id == room_id:
			result.append(puzzle)
	return result


func get_puzzles_for_exit(exit_id: StringName) -> Array[PuzzleData]:
	var result: Array[PuzzleData] = []
	if exit_id == &"":
		return result
	for puzzle in puzzles:
		if puzzle != null and puzzle.unlocks_exit == exit_id:
			result.append(puzzle)
	return result


func get_clues_for_object(object_id: StringName) -> Array[ClueData]:
	var result: Array[ClueData] = []
	for clue in clues:
		if clue != null and clue.source_object_id == object_id:
			result.append(clue)
	return result


## Verifica a integridade dos dados. Retorna a lista de problemas (vazia = ok).
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	var puzzle_ids := {}
	var clue_ids := {}

	for clue in clues:
		if clue == null:
			errors.append("Pista nula na lista.")
			continue
		if clue.id == &"":
			errors.append("Pista sem id: '%s'." % clue.title)
		elif clue_ids.has(clue.id):
			errors.append("Id de pista duplicado: %s." % clue.id)
		clue_ids[clue.id] = true

	for puzzle in puzzles:
		if puzzle == null:
			errors.append("Enigma nulo na lista.")
			continue
		if puzzle.id == &"":
			errors.append("Enigma sem id: '%s'." % puzzle.title)
		elif puzzle_ids.has(puzzle.id):
			errors.append("Id de enigma duplicado: %s." % puzzle.id)
		puzzle_ids[puzzle.id] = true
		errors.append_array(_validate_answer(puzzle))

	for puzzle in puzzles:
		if puzzle == null:
			continue
		for clue_id in puzzle.hint_ids + puzzle.required_clue_ids:
			if not clue_ids.has(clue_id):
				errors.append("%s referencia pista inexistente: %s." % [puzzle.id, clue_id])
		for other_id in puzzle.prerequisite_puzzle_ids:
			if not puzzle_ids.has(other_id):
				errors.append("%s depende de enigma inexistente: %s." % [puzzle.id, other_id])
			elif other_id == puzzle.id:
				errors.append("%s depende de si mesmo." % puzzle.id)

	for clue in clues:
		if clue == null:
			continue
		if clue.puzzle_id != &"" and not puzzle_ids.has(clue.puzzle_id):
			errors.append("Pista %s aponta para enigma inexistente: %s." % [clue.id, clue.puzzle_id])
		for other_id in clue.required_clue_ids:
			if not clue_ids.has(other_id):
				errors.append("Pista %s depende de pista inexistente: %s." % [clue.id, other_id])

	return errors


func _validate_answer(puzzle: PuzzleData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var types := PuzzleData.QuestionType
	match puzzle.question_type:
		types.MULTIPLE_CHOICE:
			if puzzle.options.size() < 2:
				errors.append("%s: múltipla escolha com menos de 2 alternativas." % puzzle.id)
			if puzzle.correct_option < 0 or puzzle.correct_option >= puzzle.options.size():
				errors.append("%s: correct_option fora das alternativas." % puzzle.id)
		types.NUMERIC:
			if not AnswerValidator.parse_number(puzzle.correct_answer).ok:
				errors.append("%s: correct_answer não é número." % puzzle.id)
		types.DOOR_CODE, types.DOCUMENT_INTERPRETATION:
			if puzzle.correct_answer.strip_edges() == "":
				errors.append("%s: correct_answer vazio." % puzzle.id)
		types.OBJECT_MATCHING:
			if puzzle.correct_pairs.is_empty():
				errors.append("%s: correct_pairs vazio." % puzzle.id)
		_:
			if puzzle.is_sequence_type() and puzzle.correct_sequence.is_empty():
				errors.append("%s: correct_sequence vazio." % puzzle.id)
	return errors
