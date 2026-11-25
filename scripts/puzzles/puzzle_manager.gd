class_name PuzzleManager
extends Node
## Estado e validação dos enigmas: interações registradas, tentativas,
## conclusão e liberação de saídas. Não apresenta UI e não controla monstros;
## outros sistemas reagem aos sinais.

signal interaction_registered(interaction_id: StringName)
signal puzzle_became_available(puzzle: PuzzleData)
signal answer_submitted(puzzle: PuzzleData, correct: bool)
signal sequence_step_submitted(puzzle: PuzzleData, step_index: int, correct: bool)
## Só emitido quando o enigma define wrong_step_emits_event = true.
signal wrong_step_event(puzzle: PuzzleData)
signal puzzle_solved(puzzle: PuzzleData)
signal exit_unlocked(exit_id: StringName)

## IN_PROGRESS: passo de sequência correto, mas a sequência ainda não terminou.
enum SubmitResult { CORRECT, INCORRECT, IN_PROGRESS, NOT_AVAILABLE, ALREADY_SOLVED, UNKNOWN_PUZZLE }

@export var database: PuzzleDatabase
@export var clue_manager: ClueManager

var _interactions: Dictionary = {}       # StringName -> true
var _solved: Dictionary = {}             # StringName -> true
var _attempts: Dictionary = {}           # StringName -> int
var _available_notified: Dictionary = {} # StringName -> true
var _sequence_buffers: Dictionary = {}   # StringName -> PackedStringArray
var _unlocked_exits: Dictionary = {}     # StringName -> true


func _ready() -> void:
	add_to_group("puzzle_manager")
	# Prompt 2: o banco vem de data/game_data.json (GameData), fonte principal.
	if database == null:
		database = GameData.get_instance().puzzle_db
	if database == null:
		push_error("PuzzleManager: nenhum PuzzleDatabase atribuído.")
		return
	var problems := database.validate()
	for problem in problems:
		push_error("PuzzleDatabase: " + problem)
	if clue_manager != null:
		clue_manager.clue_discovered.connect(func(_clue): _refresh_availability())
	# Adiado para que os outros sistemas já estejam conectados aos sinais.
	_refresh_availability.call_deferred()


# ------------------------------------------------------------ interações

## Chamado pelo sistema de interação após uma ação confirmada do jogador.
## Repetir a mesma interação não gera evento duplicado.
func register_interaction(interaction_id: StringName) -> bool:
	if interaction_id == &"" or _interactions.has(interaction_id):
		return false
	_interactions[interaction_id] = true
	interaction_registered.emit(interaction_id)
	_refresh_availability()
	return true


func has_interaction(interaction_id: StringName) -> bool:
	return _interactions.has(interaction_id)


# ------------------------------------------------------------ enigmas

func is_available(puzzle_id: StringName) -> bool:
	var puzzle := _get_puzzle(puzzle_id)
	if puzzle == null or is_solved(puzzle_id):
		return false
	for interaction_id in puzzle.required_interactions:
		if not _interactions.has(interaction_id):
			return false
	for clue_id in puzzle.required_clue_ids:
		if clue_manager == null or not clue_manager.is_discovered(clue_id):
			return false
	for other_id in puzzle.prerequisite_puzzle_ids:
		if not is_solved(other_id):
			return false
	return true


func is_solved(puzzle_id: StringName) -> bool:
	return _solved.has(puzzle_id)


func get_attempts(puzzle_id: StringName) -> int:
	return _attempts.get(puzzle_id, 0)


## Pistas já descobertas do enigma (para a UI consultar).
func get_discovered_hints(puzzle_id: StringName) -> Array[ClueData]:
	var result: Array[ClueData] = []
	var puzzle := _get_puzzle(puzzle_id)
	if puzzle == null or clue_manager == null:
		return result
	for clue_id in puzzle.hint_ids:
		if clue_manager.is_discovered(clue_id):
			result.append(database.get_clue(clue_id))
	return result


## Envia uma resposta completa. Veja AnswerValidator.is_correct para o formato.
func submit_answer(puzzle_id: StringName, answer: Variant) -> SubmitResult:
	var puzzle := _get_puzzle(puzzle_id)
	if puzzle == null:
		return SubmitResult.UNKNOWN_PUZZLE
	if is_solved(puzzle_id):
		return SubmitResult.ALREADY_SOLVED
	if not is_available(puzzle_id):
		return SubmitResult.NOT_AVAILABLE

	_attempts[puzzle_id] = get_attempts(puzzle_id) + 1
	var correct := AnswerValidator.is_correct(puzzle, answer)
	answer_submitted.emit(puzzle, correct)

	if not correct:
		return SubmitResult.INCORRECT

	_mark_solved(puzzle)
	return SubmitResult.CORRECT


## Entrada passo a passo para sequências (notas musicais, ordem de imagens...).
## Um passo errado reinicia a sequência.
func submit_sequence_step(puzzle_id: StringName, step: String) -> SubmitResult:
	var puzzle := _get_puzzle(puzzle_id)
	if puzzle == null or not puzzle.is_sequence_type():
		return SubmitResult.UNKNOWN_PUZZLE
	if is_solved(puzzle_id):
		return SubmitResult.ALREADY_SOLVED
	if not is_available(puzzle_id):
		return SubmitResult.NOT_AVAILABLE

	var buffer: PackedStringArray = _sequence_buffers.get(puzzle_id, PackedStringArray())
	buffer.append(step)
	var index := buffer.size() - 1

	if not AnswerValidator.is_correct_prefix(puzzle, buffer):
		_sequence_buffers.erase(puzzle_id)
		_attempts[puzzle_id] = get_attempts(puzzle_id) + 1
		sequence_step_submitted.emit(puzzle, index, false)
		if puzzle.wrong_step_emits_event:
			wrong_step_event.emit(puzzle)
		return SubmitResult.INCORRECT

	_sequence_buffers[puzzle_id] = buffer
	sequence_step_submitted.emit(puzzle, index, true)

	if buffer.size() == puzzle.correct_sequence.size():
		_sequence_buffers.erase(puzzle_id)
		_attempts[puzzle_id] = get_attempts(puzzle_id) + 1
		answer_submitted.emit(puzzle, true)
		_mark_solved(puzzle)
		return SubmitResult.CORRECT

	return SubmitResult.IN_PROGRESS


func get_sequence_progress(puzzle_id: StringName) -> int:
	var buffer: PackedStringArray = _sequence_buffers.get(puzzle_id, PackedStringArray())
	return buffer.size()


# ------------------------------------------------------------ saídas

## Uma saída só abre quando existe pelo menos um enigma ligado a ela
## e todos os enigmas ligados a ela estão resolvidos.
func is_exit_unlocked(exit_id: StringName) -> bool:
	if database == null:
		return false
	var linked := database.get_puzzles_for_exit(exit_id)
	if linked.is_empty():
		return false
	for puzzle in linked:
		if not is_solved(puzzle.id):
			return false
	return true


# ----------------------------------------------- persistência (sem disco)

func get_save_data() -> Dictionary:
	return {
		"interactions": _keys_as_strings(_interactions),
		"solved": _keys_as_strings(_solved),
		"attempts": _attempts.duplicate(),
	}


func load_save_data(data: Dictionary) -> void:
	_interactions.clear()
	_solved.clear()
	_attempts.clear()
	_sequence_buffers.clear()
	_unlocked_exits.clear()
	_available_notified.clear()
	for value in data.get("interactions", []):
		_interactions[StringName(value)] = true
	for value in data.get("solved", []):
		if _get_puzzle(StringName(value)) != null:
			_solved[StringName(value)] = true
	for key in data.get("attempts", {}):
		_attempts[StringName(key)] = int(data["attempts"][key])
	# Estados já conhecidos não emitem sinais de novo ao carregar.
	for puzzle in database.puzzles:
		if puzzle == null:
			continue
		if puzzle.unlocks_exit != &"" and is_exit_unlocked(puzzle.unlocks_exit):
			_unlocked_exits[puzzle.unlocks_exit] = true
		if is_solved(puzzle.id) or is_available(puzzle.id):
			_available_notified[puzzle.id] = true


# ------------------------------------------------------------ interno

func _mark_solved(puzzle: PuzzleData) -> void:
	_solved[puzzle.id] = true
	puzzle_solved.emit(puzzle)

	var exit_id := puzzle.unlocks_exit
	if exit_id != &"" and not _unlocked_exits.has(exit_id) and is_exit_unlocked(exit_id):
		_unlocked_exits[exit_id] = true
		exit_unlocked.emit(exit_id)

	_refresh_availability()


## Avisa (uma única vez) quando um enigma passa a aceitar respostas.
func _refresh_availability() -> void:
	if database == null:
		return
	for puzzle in database.puzzles:
		if puzzle == null or _available_notified.has(puzzle.id):
			continue
		if is_available(puzzle.id):
			_available_notified[puzzle.id] = true
			puzzle_became_available.emit(puzzle)


func _get_puzzle(puzzle_id: StringName) -> PuzzleData:
	return database.get_puzzle(puzzle_id) if database != null else null


func _keys_as_strings(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in source:
		result.append(String(key))
	return result
