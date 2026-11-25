class_name ClueManager
extends Node
## Registra as pistas descobertas. Impede duplicações e respeita pré-requisitos.
## Não decide quando um objeto foi usado: quem chama discover() é o objeto
## interativo depois de uma interação confirmada (Etapa 6).

signal clue_discovered(clue: ClueData)

@export var database: PuzzleDatabase

var _discovered: Dictionary = {}  # StringName -> true, na ordem de descoberta


func _ready() -> void:
	add_to_group("clue_manager")
	# Prompt 2: o banco vem de data/game_data.json (GameData), fonte principal.
	if database == null:
		database = GameData.get_instance().puzzle_db
	if database == null:
		push_error("ClueManager: nenhum PuzzleDatabase atribuído.")


## Tenta descobrir a pista. Retorna true só na primeira descoberta válida.
func discover(clue_id: StringName) -> bool:
	var clue := _get_clue(clue_id)
	if clue == null:
		push_warning("ClueManager: pista inexistente: %s" % clue_id)
		return false
	if is_discovered(clue_id) or not can_discover(clue_id):
		return false

	_discovered[clue_id] = true
	clue_discovered.emit(clue)
	return true


## Descobre todas as pistas ligadas a um objeto interativo.
func discover_from_object(object_id: StringName) -> Array[ClueData]:
	var revealed: Array[ClueData] = []
	if database == null:
		return revealed
	for clue in database.get_clues_for_object(object_id):
		if discover(clue.id):
			revealed.append(clue)
	return revealed


func can_discover(clue_id: StringName) -> bool:
	var clue := _get_clue(clue_id)
	if clue == null:
		return false
	for required in clue.required_clue_ids:
		if not is_discovered(required):
			return false
	return true


func is_discovered(clue_id: StringName) -> bool:
	return _discovered.has(clue_id)


func get_discovered_clues(puzzle_id: StringName = &"") -> Array[ClueData]:
	var result: Array[ClueData] = []
	for clue_id in _discovered:
		var clue := _get_clue(clue_id)
		if clue != null and (puzzle_id == &"" or clue.puzzle_id == puzzle_id):
			result.append(clue)
	return result


# ----------------------------------------------- persistência (sem disco)

func get_save_data() -> Dictionary:
	var ids: Array[String] = []
	for clue_id in _discovered:
		ids.append(String(clue_id))
	return {"discovered": ids}


func load_save_data(data: Dictionary) -> void:
	_discovered.clear()
	for clue_id in data.get("discovered", []):
		if _get_clue(StringName(clue_id)) != null:
			_discovered[StringName(clue_id)] = true


func _get_clue(clue_id: StringName) -> ClueData:
	return database.get_clue(clue_id) if database != null else null
