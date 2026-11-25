class_name NarrativeManager
extends Node
## Avalia e dispara eventos narrativos (Etapa 5, Fase 2).
## Escuta os sinais que já existem (enigmas, pistas, salas, monstros), confere
## gatilho + condições do NarrativeEvent e emite event_triggered. Não exibe
## nada: a interface futura (telefone, documentos, diálogos) só precisa se
## conectar a event_triggered e, ao terminar de exibir, chamar finish_event().
## Enquanto não houver interface, auto_finish encerra o evento na hora.
##
## Garantias:
## - eventos com once = true disparam uma única vez (também após carregar save);
## - eventos desativados (enabled = false) nunca disparam, nem manualmente;
## - a narrativa avança por condições de jogo, nunca por tempo decorrido.

signal event_triggered(event: NarrativeEvent)
signal event_finished(event: NarrativeEvent)
signal event_refused(event_id: StringName, reason: String)

const TT := NarrativeEvent.TriggerType

@export var database: NarrativeDatabase
@export var puzzle_manager: PuzzleManager
@export var clue_manager: ClueManager
@export var room_progress: RoomProgressManager
## Opcional. Com ele, cada E confirmado reavalia os eventos de INTERACTION
## (ex.: reler um documento depois de cumprir a condição); `once` impede
## repetição. Sem ele, usa interaction_registered (só a 1ª interação).
@export var interactor: PlayerInteractor
## true = encerra o evento logo após emiti-lo (sem interface ainda).
## A interface futura desliga isto e chama finish_event().
@export var auto_finish: bool = true
@export var log_to_console: bool = true

var _fired: Dictionary = {}      # StringName -> vezes disparado
var _finished: Dictionary = {}   # StringName -> true
var _active: Array[StringName] = []


func _ready() -> void:
	add_to_group("narrative_manager")
	# Prompt 2: o banco vem de data/game_data.json (GameData), fonte principal.
	if database == null:
		database = GameData.get_instance().narrative_db
	if database == null:
		push_error("NarrativeManager: NarrativeDatabase não atribuído.")
		return
	if puzzle_manager != null:
		for problem in database.validate(puzzle_manager.database):
			push_error("NarrativeDatabase: " + problem)
		if interactor == null:
			puzzle_manager.interaction_registered.connect(func(i): _on_trigger(TT.INTERACTION, i))
		puzzle_manager.puzzle_solved.connect(func(p): _on_trigger(TT.PUZZLE_SOLVED, p.id))
	if interactor != null:
		# Adiado: o InteractionRouter (que registra a interação e revela pistas)
		# precisa reagir primeiro, para as condições já estarem atualizadas.
		interactor.interaction_performed.connect(func(i, _a, _t): _on_trigger.call_deferred(TT.INTERACTION, i))
	if clue_manager != null:
		clue_manager.clue_discovered.connect(func(c): _on_trigger(TT.CLUE_DISCOVERED, c.id))
	if room_progress != null:
		room_progress.room_entered.connect(func(r): _on_trigger(TT.ROOM_ENTERED, r))
		room_progress.room_completed.connect(func(r): _on_trigger(TT.ROOM_COMPLETED, r))
	_connect_monsters.call_deferred()


# ------------------------------------------------------------ API pública

## Dispara um evento MANUAL (ex.: a futura sequência de despertar).
## Retorna true se disparou.
func trigger_manual(event_id: StringName) -> bool:
	var event := database.get_event(event_id) if database != null else null
	if event == null:
		event_refused.emit(event_id, "inexistente")
		return false
	return _try_fire(event)


## Chamado pela interface quando terminar de exibir o evento.
func finish_event(event_id: StringName) -> void:
	if not _active.has(event_id):
		return
	_active.erase(event_id)
	_finished[event_id] = true
	var event := database.get_event(event_id)
	event_finished.emit(event)
	_on_trigger(TT.EVENT_FINISHED, event_id)


func has_fired(event_id: StringName) -> bool:
	return _fired.has(event_id)


func fire_count(event_id: StringName) -> int:
	return _fired.get(event_id, 0)


func is_finished(event_id: StringName) -> bool:
	return _finished.has(event_id)


## Diagnóstico: por que um evento não dispararia agora ("" = dispararia).
func why_blocked(event: NarrativeEvent) -> String:
	if not event.enabled:
		return "desativado: " + event.disabled_reason
	if event.once and _fired.has(event.id):
		return "já disparado"
	for e in event.blocked_by_events:
		if _fired.has(e):
			return "bloqueado por " + String(e)
	for i in event.required_interactions:
		if puzzle_manager == null or not puzzle_manager.has_interaction(i):
			return "falta interação " + String(i)
	for c in event.required_clues:
		if clue_manager == null or not clue_manager.is_discovered(c):
			return "falta pista " + String(c)
	for p in event.required_puzzles_solved:
		if puzzle_manager == null or not puzzle_manager.is_solved(p):
			return "falta enigma " + String(p)
	for r in event.required_rooms_completed:
		if room_progress == null or not room_progress.is_completed(r):
			return "falta concluir " + String(r)
	for e in event.required_events:
		if not _finished.has(e):
			return "falta evento " + String(e)
	return ""


# ------------------------------------------------------------ interno

func _connect_monsters() -> void:
	for node in get_tree().get_nodes_in_group("monster"):
		if node is MonsterController and node.config != null:
			var monster_id: StringName = node.config.monster_id
			node.state_changed.connect(func(_prev, current):
				_on_trigger(TT.MONSTER_STATE, monster_id, StringName(MonsterController.State.keys()[current])))


func _on_trigger(trigger: int, trigger_id: StringName, state: StringName = &"") -> void:
	if database == null:
		return
	var candidates := database.get_events_for_trigger(trigger, trigger_id)
	if trigger == TT.MONSTER_STATE:
		candidates = candidates.filter(func(e): return e.trigger_state == state)
	candidates.sort_custom(func(a, b): return a.priority > b.priority)
	for event in candidates:
		_try_fire(event)


func _try_fire(event: NarrativeEvent) -> bool:
	var reason := why_blocked(event)
	if reason != "":
		if not event.enabled or event.trigger == TT.MANUAL:
			_log("recusado %s (%s)" % [event.id, reason])
		event_refused.emit(event.id, reason)
		return false
	_fired[event.id] = _fired.get(event.id, 0) + 1
	_active.append(event.id)
	_log("%s %s — %s" % [NarrativeEvent.EventType.keys()[event.type], event.id, event.title])
	event_triggered.emit(event)
	if auto_finish:
		finish_event(event.id)
	return true


func _log(text: String) -> void:
	if log_to_console:
		print("[Narrativa] ", text)


# ----------------------------------------------- persistência (sem disco)

func get_save_data() -> Dictionary:
	var fired := {}
	for k in _fired:
		fired[String(k)] = _fired[k]
	var finished: Array[String] = []
	for k in _finished:
		finished.append(String(k))
	return {"fired": fired, "finished": finished}


## Estados já conhecidos não reemitem sinais ao carregar.
func load_save_data(data: Dictionary) -> void:
	_fired.clear()
	_finished.clear()
	_active.clear()
	var fired: Dictionary = data.get("fired", {})
	for k in fired:
		_fired[StringName(k)] = int(fired[k])
	for k in data.get("finished", []):
		_finished[StringName(k)] = true
