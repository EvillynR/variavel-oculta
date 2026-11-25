extends Node3D
## Desperta cada criatura apenas quando a protagonista entra na própria sala.
## Gatilho provisório de progressão; os objetos narrativos podem substituí-lo depois.

var _by_room: Dictionary = {}

func _ready() -> void:
	for node in get_tree().get_nodes_in_group("monster"):
		if node is MonsterController:
			var cfg: MonsterConfig = node.resolve_config()
			if cfg != null and cfg.room_id != &"":
				_by_room[cfg.room_id] = node
	var manager := get_tree().get_first_node_in_group("room_progress_manager") as RoomProgressManager
	if manager != null:
		manager.room_entered.connect(_on_room_entered)
	else:
		push_warning("MonsterRoomActivation: RoomProgressManager indisponível; gatilhos por entrada não conectados.")

func _on_room_entered(room_id: StringName) -> void:
	# O Polvo não deve despertar só porque a protagonista entrou na sala.
	# Ele é ativado pelo efeito explícito do experimento em interaction_router.gd.
	# Versão final: cada monstro tem seu gatilho no JSON (enigma, objeto ou a
	# cena de entrada). Só desperta na entrada a sala que não tem nenhum.
	var room := GameData.get_instance().narrative_db.get_room(room_id)
	if room == null or not room.activation_puzzle_ids.is_empty() or not room.activation_interaction_ids.is_empty() or not room.activation_story_ids.is_empty():
		return
	var monster := _by_room.get(room_id) as MonsterController
	if monster != null and not monster.is_active():
		monster.activate(StringName("entrada_" + String(room_id)), monster.global_position)
