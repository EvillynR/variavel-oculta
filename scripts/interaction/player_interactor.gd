class_name PlayerInteractor
extends Node
## Lê a ação "interact" e aciona o objeto interativo mais adequado ao alcance.
## Fica fora da cena da protagonista para não alterá-la.

## Emitido a cada interação confirmada (objeto + ação).
signal interaction_performed(interaction_id: StringName, action_id: StringName, interactable: Interactable)

@export var player: Node3D
@export var input_action: StringName = &"interact"
## Exige linha de visada (camada do cenário) entre a protagonista e o objeto,
## para que nada seja selecionado através de uma parede.
@export var require_line_of_sight: bool = true
@export_flags_3d_physics var line_of_sight_mask: int = 1

var _candidates: Array[Interactable] = []
var _current: Interactable = null


func _ready() -> void:
	add_to_group("player_interactor")
	if not InputMap.has_action(input_action):
		push_error("PlayerInteractor: ação '%s' não existe no Input Map." % input_action)


func register_candidate(target: Interactable) -> void:
	if not _candidates.has(target):
		_candidates.append(target)


func unregister_candidate(target: Interactable) -> void:
	_candidates.erase(target)
	if target == _current:
		target.set_highlighted(false)
		_current = null


func get_current_target() -> Interactable:
	return _current


func _process(_delta: float) -> void:
	_update_target()
	if _current != null and Input.is_action_just_pressed(input_action):
		try_interact()


## Interage com o alvo atual. Retorna true se a interação aconteceu.
func try_interact() -> bool:
	_update_target()
	if _current == null or player == null:
		return false
	var target := _current
	if not target.interact(player):
		return false
	interaction_performed.emit(target.interaction_id, target.action_id, target)
	return true


func _has_line_of_sight(target: Interactable) -> bool:
	if player == null:
		return false
	var from := player.global_position + Vector3.UP * 1.2
	var to := target.global_position + Vector3.UP * 0.9
	var query := PhysicsRayQueryParameters3D.create(from, to, line_of_sight_mask)
	var exclude: Array[RID] = target.line_of_sight_exclude.duplicate()
	if player is CollisionObject3D:
		exclude.append(player.get_rid())
	query.exclude = exclude
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _update_target() -> void:
	var best: Interactable = null
	var best_score := INF
	for candidate in _candidates:
		if not is_instance_valid(candidate) or not candidate.can_interact():
			continue
		if require_line_of_sight and not _has_line_of_sight(candidate):
			continue
		var distance := candidate.global_position.distance_to(player.global_position) if player else 0.0
		var score := distance - candidate.selection_priority * 100.0
		if score < best_score:
			best_score = score
			best = candidate

	if best != _current:
		if _current != null and is_instance_valid(_current):
			_current.set_highlighted(false)
		_current = best
	# Reaplica sempre: se o alvo deixou de estar disponível, o prompt some.
	if _current != null:
		_current.set_highlighted(true)
