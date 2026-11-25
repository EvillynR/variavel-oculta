class_name AnswerValidator
extends RefCounted
## Validação de respostas por tipo de enigma. Funções estáticas, sem estado.

const ACCENTS := {
	"á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a",
	"é": "e", "è": "e", "ê": "e", "ë": "e",
	"í": "i", "ì": "i", "î": "i", "ï": "i",
	"ó": "o", "ò": "o", "ô": "o", "õ": "o", "ö": "o",
	"ú": "u", "ù": "u", "û": "u", "ü": "u",
	"ç": "c", "ñ": "n",
}


## answer depende do tipo:
## MULTIPLE_CHOICE -> int (índice) | NUMERIC/DOOR_CODE/DOCUMENT -> String
## sequências -> PackedStringArray/Array | OBJECT_MATCHING -> Dictionary
static func is_correct(puzzle: PuzzleData, answer: Variant) -> bool:
	if puzzle == null:
		return false

	var types := PuzzleData.QuestionType
	match puzzle.question_type:
		types.MULTIPLE_CHOICE:
			return typeof(answer) == TYPE_INT and answer == puzzle.correct_option
		types.NUMERIC:
			var given := parse_number(str(answer))
			var expected := parse_number(puzzle.correct_answer)
			return given.ok and expected.ok \
				and absf(given.value - expected.value) <= puzzle.numeric_tolerance + 0.000001
		types.DOOR_CODE:
			return normalize_code(str(answer)) == normalize_code(puzzle.correct_answer)
		types.DOCUMENT_INTERPRETATION:
			var given_text := normalize_text(str(answer), puzzle)
			if given_text == "":
				return false
			if given_text == normalize_text(puzzle.correct_answer, puzzle):
				return true
			for alternative in puzzle.accepted_answers:
				if given_text == normalize_text(alternative, puzzle):
					return true
			return false
		types.OBJECT_MATCHING:
			return typeof(answer) == TYPE_DICTIONARY and _pairs_match(puzzle, answer)
		_:
			if puzzle.is_sequence_type():
				return _sequence_matches(puzzle, answer, false)
	return false


## Para entrada passo a passo (ex.: notas): true se a sequência dada é um
## prefixo correto da sequência esperada.
static func is_correct_prefix(puzzle: PuzzleData, partial: Variant) -> bool:
	return puzzle != null and puzzle.is_sequence_type() and _sequence_matches(puzzle, partial, true)


static func parse_number(text: String) -> Dictionary:
	var cleaned := text.strip_edges().replace(" ", "").replace(",", ".")
	if cleaned.is_valid_float() or cleaned.is_valid_int():
		return {"ok": true, "value": cleaned.to_float()}
	return {"ok": false, "value": 0.0}


static func normalize_code(text: String) -> String:
	return text.strip_edges().replace(" ", "").replace("-", "").to_upper()


static func normalize_text(text: String, puzzle: PuzzleData) -> String:
	var result := text.strip_edges()
	while result.contains("  "):
		result = result.replace("  ", " ")
	if not puzzle.case_sensitive:
		result = result.to_lower()
	if puzzle.ignore_accents:
		for accented in ACCENTS:
			result = result.replace(accented, ACCENTS[accented])
			if puzzle.case_sensitive:
				result = result.replace(accented.to_upper(), ACCENTS[accented].to_upper())
	return result


static func _sequence_matches(puzzle: PuzzleData, answer: Variant, allow_prefix: bool) -> bool:
	if typeof(answer) != TYPE_PACKED_STRING_ARRAY and typeof(answer) != TYPE_ARRAY:
		return false
	var given: Array = Array(answer)
	var expected := puzzle.correct_sequence
	if allow_prefix:
		if given.size() > expected.size():
			return false
	elif given.size() != expected.size():
		return false
	for i in given.size():
		if normalize_text(str(given[i]), puzzle) != normalize_text(expected[i], puzzle):
			return false
	return true


static func _pairs_match(puzzle: PuzzleData, answer: Dictionary) -> bool:
	if answer.size() != puzzle.correct_pairs.size():
		return false
	var expected := {}
	for key in puzzle.correct_pairs:
		expected[normalize_text(str(key), puzzle)] = normalize_text(str(puzzle.correct_pairs[key]), puzzle)
	for key in answer:
		var k := normalize_text(str(key), puzzle)
		if not expected.has(k) or expected[k] != normalize_text(str(answer[key]), puzzle):
			return false
	return true
