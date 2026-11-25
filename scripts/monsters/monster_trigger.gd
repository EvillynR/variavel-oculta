class_name MonsterTrigger
extends Node
## Liga eventos do sistema de enigmas ao despertar de um monstro.
## Cada monstro configura os seus próprios gatilhos; nenhum gatilho
## conhece outros monstros. Escuta apenas sinais do PuzzleManager, que já
## ignora interações repetidas.

@export var monster: MonsterController
@export var puzzle_manager: PuzzleManager
## Interações (ids de Interactable) que despertam este monstro.
@export var activation_interaction_ids: Array[StringName] = []
## Enigmas cuja conclusão desperta este monstro.
@export var activation_puzzle_solved_ids: Array[StringName] = []
## Enigmas de sequência cujo passo errado desperta/atrai este monstro
## (somente se o enigma tiver wrong_step_emits_event = true).
@export var activation_wrong_step_puzzle_ids: Array[StringName] = []


func _ready() -> void:
	if monster == null:
		monster = get_parent() as MonsterController
	if puzzle_manager == null:
		puzzle_manager = get_tree().get_first_node_in_group("puzzle_manager") as PuzzleManager
	if monster == null or puzzle_manager == null:
		push_error("%s: monstro ou PuzzleManager ausente; gatilho desativado." % get_path())
		return
	_load_triggers_from_data()

	puzzle_manager.interaction_registered.connect(_on_interaction_registered)
	puzzle_manager.puzzle_solved.connect(_on_puzzle_solved)
	puzzle_manager.wrong_step_event.connect(_on_wrong_step)
	_check_already_triggered.call_deferred()


## Prompt 2: os gatilhos vêm de data/game_data.json — objetos com o efeito
## "activate_monster" (RoomData.activation_interaction_ids) e
## RoomData.activation_puzzle_ids da sala do monstro. Valores colocados na cena
## são substituídos (avisando se divergirem), para não haver duas fontes.
func _load_triggers_from_data() -> void:
	var cfg: MonsterConfig = monster.resolve_config() if monster.has_method("resolve_config") else monster.config
	if cfg == null:
		return
	var room := GameData.get_instance().narrative_db.get_room_for_monster(cfg.monster_id)
	if room == null:
		return
	if not activation_interaction_ids.is_empty() and activation_interaction_ids != room.activation_interaction_ids:
		push_warning("%s: gatilhos da cena %s ignorados; valem os do JSON %s." % [get_path(), activation_interaction_ids, room.activation_interaction_ids])
	activation_interaction_ids = room.activation_interaction_ids.duplicate()
	if not room.activation_puzzle_ids.is_empty():
		activation_puzzle_solved_ids = room.activation_puzzle_ids.duplicate()


## Estado carregado de um save: se o gatilho já aconteceu, o monstro começa acordado.
func _check_already_triggered() -> void:
	for interaction_id in activation_interaction_ids:
		if puzzle_manager.has_interaction(interaction_id):
			monster.activate(&"estado_restaurado", monster.global_position, true)
			return


func _on_interaction_registered(interaction_id: StringName) -> void:
	if interaction_id in activation_interaction_ids:
		monster.activate(interaction_id, _stimulus_position(interaction_id))


func _on_puzzle_solved(puzzle: PuzzleData) -> void:
	if puzzle.id in activation_puzzle_solved_ids:
		monster.activate(StringName("resolvido:" + String(puzzle.id)), monster.global_position)


func _on_wrong_step(puzzle: PuzzleData) -> void:
	if puzzle.id in activation_wrong_step_puzzle_ids:
		monster.activate(StringName("erro:" + String(puzzle.id)), monster.global_position)


func _stimulus_position(interaction_id: StringName) -> Vector3:
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is Interactable and node.interaction_id == interaction_id:
			return node.global_position
	return monster.global_position
