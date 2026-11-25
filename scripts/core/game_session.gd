class_name GameSession
extends Node
## Prompt 3 — a "casca" do jogo dentro da cena principal: monta HUD, telefone,
## diário e pausa; aplica configurações; grava checkpoints em user:// e os
## restaura (usando o save em memória já existente de RoomProgressManager,
## PuzzleManager, ClueManager e NarrativeManager, mais portas, monstros,
## protagonista e telefone).
##
## Checkpoints: início de um jogo novo, entrada em sala liberada (anterior
## concluída) e conclusão de sala.

signal checkpoint_saved(reason: String)
signal checkpoint_restored

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const WAKE_EVENT := &"cena_abertura"
const SAVE_VERSION := 1

var hud: GameHUD
var phone: PhoneUI
var journal: ClueJournal
var pause_menu: PauseMenu
var story: StoryDirector
var rooms: RoomProgressManager
var narrative: NarrativeManager
var puzzles: PuzzleManager
var clues: ClueManager
var player: CharacterBody3D
var start_mode: String = ""
var last_checkpoint_reason: String = ""
var ready_done := false


func _ready() -> void:
	add_to_group("game_session")
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveSystem.load_settings()
	SaveSystem.apply_global()
	rooms = get_tree().get_first_node_in_group("room_progress_manager")
	narrative = get_tree().get_first_node_in_group("narrative_manager")
	var systems := get_parent().get_node_or_null("Systems")
	if systems != null:
		puzzles = systems.get_node_or_null("PuzzleManager")
		clues = systems.get_node_or_null("ClueManager")
	player = get_tree().get_first_node_in_group("player")
	hud = GameHUD.new()
	add_child(hud)
	phone = PhoneUI.new()
	add_child(phone)
	journal = ClueJournal.new()
	journal.clue_manager = clues
	add_child(journal)
	pause_menu = PauseMenu.new()
	pause_menu.session = self
	add_child(pause_menu)
	# A história contada como filme: cenas, documentos e o mapa.
	story = StoryDirector.new()
	add_child(story)
	story.setup(phone, hud)
	SaveSystem.apply_to_scene(get_parent())
	if rooms != null:
		rooms.room_entered.connect(_on_room_entered)
		rooms.room_completed.connect(func(r): _save_deferred("sala concluída: %s" % r))
	start_mode = SaveSystem.pending_action
	SaveSystem.pending_action = ""
	# Rodando a cena do jogo direto (editor/F6) conta como jogo novo; os testes
	# que instanciam a cena manualmente não disparam a abertura.
	if start_mode == "" and get_tree().current_scene == get_parent():
		start_mode = "new"
	if story != null:
		story.enabled = start_mode != ""
	_start.call_deferred()


func _start() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	SaveSystem.apply_to_scene(get_parent())
	match start_mode:
		"continue", "checkpoint":
			var data := SaveSystem.read_save()
			if data.is_empty():
				_begin_new_game()
			else:
				await restore(data)
				if narrative != null and not narrative.has_fired(WAKE_EVENT):
					_play_wake_call()
		"new":
			_begin_new_game()
	ready_done = true


func _begin_new_game() -> void:
	SaveSystem.delete_save()
	save_checkpoint("início")
	await _play_wake_call()


## A abertura (cena de filme): Yuko acorda no chão da sala. A voz do telefone
## só aparece quando ela pega o mapa (cena_mapa). O checkpoint da abertura é
## gravado pelo efeito "checkpoint" no fim da cena.
func _play_wake_call() -> void:
	if story != null:
		story.start_new_game()


func can_pause() -> bool:
	if get_tree().paused:
		return false
	if story != null and story.is_busy():
		return false   # Game Over ou UI de enigma já pausaram
	var pz := get_parent().get_node_or_null("PuzzleUI")
	if pz != null and pz.has_method("is_open") and pz.is_open():
		return false
	var go := get_tree().get_first_node_in_group("game_over_ui")
	return go == null or not go.is_open()


# ----------------------------------------------------------------- save

func _on_room_entered(room_id: StringName) -> void:
	var room := rooms.database.get_room(room_id) if rooms.database != null else null
	if room == null:
		return
	# "Sala liberada": local narrativo, primeira sala ou a anterior concluída.
	var unlocked := not room.is_classroom() or rooms._previous_completed(room)
	if unlocked:
		_save_deferred("entrou em %s" % room_id)


func _save_deferred(reason: String) -> void:
	await get_tree().physics_frame
	save_checkpoint(reason)


func save_checkpoint(reason: String) -> bool:
	if player == null:
		return false
	var data := build_save()
	data["reason"] = reason
	var ok := SaveSystem.write_save(data)
	if ok:
		last_checkpoint_reason = reason
		checkpoint_saved.emit(reason)
	return ok


func build_save() -> Dictionary:
	var p: Vector3 = player.global_position
	var doors := {}
	for d in get_tree().get_nodes_in_group("door"):
		doors[String(d.door_id)] = {"open": d.is_open(), "unlocked": d.manually_unlocked, "story_locked": d.story_locked}
	var monsters := {}
	for m in get_tree().get_nodes_in_group("monster"):
		if m is MonsterController and m.config != null:
			var mp: Vector3 = m.global_position
			monsters[String(m.config.monster_id)] = {"active": m.is_active(), "state": m.get_state_name(),
				"pos": [mp.x, mp.y, mp.z], "yaw": m.rotation.y}
	return {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"current_room": String(rooms.current_room) if rooms != null else "",
		"player": {"pos": [p.x, p.y, p.z], "visual_yaw": player.visual.rotation.y if "visual" in player else 0.0},
		"rooms": rooms.get_save_data() if rooms != null else {},
		"puzzles": puzzles.get_save_data() if puzzles != null else {},
		"clues": clues.get_save_data() if clues != null else {},
		"narrative": narrative.get_save_data() if narrative != null else {},
		"doors": doors,
		"monsters": monsters,
		"phone": phone.history.duplicate(true),
		"story": story.get_save_data() if story != null else {},
		"objective": hud.objective,
	}


## Restaura um save nesta cena (recém-carregada). Ordem: pistas → enigmas →
## narrativa → monstros → salas → portas → protagonista → telefone/HUD.
func restore(data: Dictionary) -> void:
	if clues != null and data.has("clues"):
		clues.load_save_data(data.clues)
	if puzzles != null and data.has("puzzles"):
		puzzles.load_save_data(data.puzzles)
	if narrative != null and data.has("narrative"):
		narrative.load_save_data(data.narrative)
	var saved_monsters: Dictionary = data.get("monsters", {})
	for m in get_tree().get_nodes_in_group("monster"):
		if not (m is MonsterController) or m.config == null:
			continue
		var s: Dictionary = saved_monsters.get(String(m.config.monster_id), {})
		if s.is_empty() or not bool(s.get("active", false)):
			# Gravado dormindo (ex.: "ele se acalmou"): o gatilho do objeto
			# barulhento não pode acordá-lo de novo ao carregar.
			if not s.is_empty() and m.is_active():
				m.deactivate(true)
			continue
		var pos := _vec(s.get("pos", []), m.global_position)
		m.global_position = pos
		m.rotation.y = float(s.get("yaw", m.rotation.y))
		if not m.is_active():
			m.activate(&"save", pos, true)
		# Ninguém volta perseguindo: o monstro retoma a vigia de onde estava.
		m._change_state(MonsterController.State.PATROLLING)
	if rooms != null and data.has("rooms"):
		rooms.load_save_data(data.rooms)
	var saved_doors: Dictionary = data.get("doors", {})
	for d in get_tree().get_nodes_in_group("door"):
		var ds: Dictionary = saved_doors.get(String(d.door_id), {})
		if bool(ds.get("unlocked", false)):
			d.unlock()
		if bool(ds.get("story_locked", false)):
			d.lock(true)
		if bool(ds.get("open", false)):
			d.open(true, true)
		else:
			d._refresh_lock()
	var pd: Dictionary = data.get("player", {})
	player.global_position = _vec(pd.get("pos", []), player.global_position)
	player.velocity = Vector3.ZERO
	if "visual" in player:
		player.visual.rotation.y = float(pd.get("visual_yaw", 0.0))
	phone.load_history(data.get("phone", []))
	if story != null:
		story.load_save_data(data.get("story", {}))
	hud.set_objective(str(data.get("objective", "")))
	await get_tree().physics_frame
	var cam := get_tree().get_first_node_in_group("camera_controller")
	if cam != null:
		cam.snap_to_target()
	checkpoint_restored.emit()


func _vec(a: Variant, fallback: Vector3) -> Vector3:
	if typeof(a) == TYPE_ARRAY and a.size() == 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fallback


# ------------------------------------------------------------ navegação

## Recarrega a cena e restaura o último checkpoint gravado.
func restore_last_checkpoint() -> void:
	SaveSystem.pending_action = "checkpoint" if SaveSystem.has_save() else "new"
	get_tree().paused = false
	if get_tree().current_scene == get_parent():
		get_tree().reload_current_scene()
	else:
		# Cena montada à mão (testes): restaura sem recarregar.
		var data := SaveSystem.read_save()
		SaveSystem.pending_action = ""
		pause_menu.close()
		if not data.is_empty():
			await restore(data)


func go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _wait_seconds(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time() if get_process_delta_time() > 0.0 else 1.0 / 60.0
