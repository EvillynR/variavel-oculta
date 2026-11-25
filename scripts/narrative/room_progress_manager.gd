class_name RoomProgressManager
extends Node
## Estado de progressão de cada sala e sala atual da protagonista
## (Etapa 5, Fase 2). Só lógica: não controla câmera, monstros nem UI.
##
## Sala atual com histerese:
## - enquanto a protagonista ainda sobrepõe o volume da sala atual, ela
##   continua sendo a sala atual (atravessar uma porta encostando em dois
##   volumes não alterna a sala);
## - uma troca só é confirmada depois de transition_confirm_time segundos
##   estável na nova situação (outra sala ou fora de qualquer sala).
## Assim entrar/sair emite um único evento por mudança real.
##
## Estados (RoomData.RoomState):
## LOCKED -> AVAILABLE (sala anterior concluída; a 1ª começa disponível)
## -> ACTIVE (protagonista entrou) -> MONSTER_AWAKE (monstro da sala ativado)
## -> SOLVED (enigmas exigidos resolvidos e saída liberada)
## -> COMPLETED (resolvida e a protagonista saiu da sala).

signal room_entered(room_id: StringName)
signal room_exited(room_id: StringName)
signal current_room_changed(previous: StringName, current: StringName)
signal room_state_changed(room_id: StringName, previous: int, current: int)
signal room_completed(room_id: StringName)

const S := RoomData.RoomState

@export var database: NarrativeDatabase
@export var puzzle_manager: PuzzleManager
## Tempo estável exigido antes de confirmar uma troca de sala (s).
@export var transition_confirm_time: float = 0.25
@export var log_to_console: bool = true

var current_room: StringName = &""
var _states: Dictionary = {}       # StringName -> RoomData.RoomState
var _visited: Dictionary = {}      # StringName -> true
var _inside: Dictionary = {}       # StringName -> int (volumes sobrepostos dessa sala)
var _last_entered: StringName = &""
var _pending: StringName = &""
var _pending_time: float = 0.0
var _has_pending: bool = false


func _ready() -> void:
	add_to_group("room_progress_manager")
	# Prompt 2: o banco vem de data/game_data.json (GameData), fonte principal.
	if database == null:
		database = GameData.get_instance().narrative_db
	if database == null:
		push_error("RoomProgressManager: NarrativeDatabase não atribuído.")
		return
	for room in database.rooms:
		if room != null:
			_states[room.id] = S.LOCKED
	var classrooms := database.get_classrooms()
	if not classrooms.is_empty():
		_states[classrooms[0].id] = S.AVAILABLE
	if puzzle_manager != null:
		puzzle_manager.puzzle_solved.connect(func(_p): _refresh_solved())
		puzzle_manager.exit_unlocked.connect(func(_e): _refresh_solved())
	_connect_monsters.call_deferred()
	_check_volumes.call_deferred()


# ------------------------------------------------------------ consultas

func get_room_state(room_id: StringName) -> int:
	return _states.get(room_id, S.LOCKED)


func get_state_name(room_id: StringName) -> String:
	return S.keys()[get_room_state(room_id)]


func is_completed(room_id: StringName) -> bool:
	return get_room_state(room_id) == S.COMPLETED


func was_visited(room_id: StringName) -> bool:
	return _visited.has(room_id)


# ------------------------------------------------------------ volumes

func notify_volume_entered(volume: RoomVolume) -> void:
	if not _states.has(volume.room_id):
		return
	_inside[volume.room_id] = _inside.get(volume.room_id, 0) + 1
	_last_entered = volume.room_id


func notify_volume_exited(volume: RoomVolume) -> void:
	if not _inside.has(volume.room_id):
		return
	_inside[volume.room_id] -= 1
	if _inside[volume.room_id] <= 0:
		_inside.erase(volume.room_id)


func _physics_process(delta: float) -> void:
	# Escondida num móvel a protagonista fica sem colisão e "sai" dos volumes;
	# ela continua na mesma sala (senão a sala se concluiria com a resposta).
	var p := get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("is_hidden") and p.is_hidden():
		_has_pending = false
		return
	var desired := _desired_room()
	if desired == current_room:
		_has_pending = false
		return
	if not _has_pending or desired != _pending:
		_has_pending = true
		_pending = desired
		_pending_time = 0.0
	_pending_time += delta
	if _pending_time >= transition_confirm_time:
		_has_pending = false
		_commit(desired)


func _desired_room() -> StringName:
	if current_room != &"" and _inside.has(current_room):
		return current_room   # ainda dentro da sala atual: não troca
	if _inside.is_empty():
		return &""
	if _inside.has(_last_entered):
		return _last_entered
	return _inside.keys()[0]


func _commit(new_room: StringName) -> void:
	var previous := current_room
	current_room = new_room
	if previous != &"":
		_log("saiu de %s" % previous)
		room_exited.emit(previous)
		if get_room_state(previous) == S.SOLVED:
			_set_state(previous, S.COMPLETED)
	if new_room != &"":
		_visited[new_room] = true
		_log("entrou em %s" % new_room)
		if get_room_state(new_room) in [S.LOCKED, S.AVAILABLE]:
			if get_room_state(new_room) == S.LOCKED:
				_log("aviso: %s entrada antes de ser liberada na progressão" % new_room)
			_set_state(new_room, S.ACTIVE)
		room_entered.emit(new_room)
	current_room_changed.emit(previous, new_room)


# ------------------------------------------------------------ progressão

func _connect_monsters() -> void:
	for node in get_tree().get_nodes_in_group("monster"):
		if node is MonsterController and node.config != null:
			var monster_id: StringName = node.config.monster_id
			node.activated.connect(func(_reason): _on_monster_activated(monster_id))
			if node.is_active():
				_on_monster_activated(monster_id)


func _on_monster_activated(monster_id: StringName) -> void:
	var room := database.get_room_for_monster(monster_id)
	if room == null:
		return
	if get_room_state(room.id) in [S.LOCKED, S.AVAILABLE, S.ACTIVE]:
		_set_state(room.id, S.MONSTER_AWAKE)


func _refresh_solved() -> void:
	if puzzle_manager == null:
		return
	for room in database.rooms:
		if room == null or not room.is_classroom():
			continue
		if get_room_state(room.id) in [S.SOLVED, S.COMPLETED]:
			continue
		# Fase 4: sala pendente ou sem enigma nunca se resolve sozinha (sem
		# esta guarda, "nenhum enigma exigido" a daria como resolvida).
		if room.is_pending() or room.get_required_puzzles().is_empty():
			continue
		var done := true
		for pid in room.get_required_puzzles():
			if not puzzle_manager.is_solved(pid):
				done = false
		if room.exit_id != &"" and not puzzle_manager.is_exit_unlocked(room.exit_id):
			done = false
		if done:
			_set_state(room.id, S.SOLVED)
			if current_room != room.id:   # resolvida de fora: conclui na hora
				_set_state(room.id, S.COMPLETED)


func _set_state(room_id: StringName, new_state: int) -> void:
	var previous: int = get_room_state(room_id)
	if previous == new_state:
		return
	_states[room_id] = new_state
	_log("%s: %s -> %s" % [room_id, S.keys()[previous], S.keys()[new_state]])
	room_state_changed.emit(room_id, previous, new_state)
	if new_state == S.COMPLETED:
		room_completed.emit(room_id)
		_unlock_next(room_id)


func _unlock_next(room_id: StringName) -> void:
	var rooms := database.get_classrooms()
	for i in rooms.size() - 1:
		if rooms[i].id == room_id and get_room_state(rooms[i + 1].id) == S.LOCKED:
			if _entry_conditions_met(rooms[i + 1]):
				_set_state(rooms[i + 1].id, S.AVAILABLE)
	# Fase 4: salas com entry_required_rooms podem estar esperando esta.
	for room in rooms:
		if get_room_state(room.id) == S.LOCKED and room_id in room.entry_required_rooms and _previous_completed(room) and _entry_conditions_met(room):
			_set_state(room.id, S.AVAILABLE)


func _entry_conditions_met(room: RoomData) -> bool:
	for rid in room.entry_required_rooms:
		if not is_completed(rid):
			return false
	return true


func _previous_completed(room: RoomData) -> bool:
	var rooms := database.get_classrooms()
	var index := rooms.find(room)
	return index <= 0 or is_completed(rooms[index - 1].id)


## Volumes cujo room_id não existe no banco, ou que apontam para pontos de
## integração (sem geometria), são relatados — não são usados.
func _check_volumes() -> void:
	for volume in get_tree().get_nodes_in_group("room_volume"):
		var room: RoomData = database.get_room(volume.room_id)
		if room == null:
			push_warning("RoomProgressManager: volume %s aponta para sala fora do banco: %s" % [volume.name, volume.room_id])
		elif room.geometry_status != RoomData.GeometryStatus.PHYSICAL:
			push_error("RoomProgressManager: volume físico para ponto de integração %s." % room.id)


func _log(text: String) -> void:
	if log_to_console:
		print("[Salas] ", text)


# ----------------------------------------------- persistência (sem disco)

func get_save_data() -> Dictionary:
	var states := {}
	for room_id in _states:
		states[String(room_id)] = _states[room_id]
	var visited: Array[String] = []
	for room_id in _visited:
		visited.append(String(room_id))
	return {"states": states, "visited": visited}


func load_save_data(data: Dictionary) -> void:
	var states: Dictionary = data.get("states", {})
	for key in states:
		if _states.has(StringName(key)):
			_states[StringName(key)] = int(states[key])
	_visited.clear()
	for room_id in data.get("visited", []):
		_visited[StringName(room_id)] = true
