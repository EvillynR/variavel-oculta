class_name StoryDirector
extends Node
## Diretor da história de Yuko.
##
## Escuta o NarrativeManager e transforma eventos em "filme":
##   CUTSCENE  -> CutscenePlayer (roteiro em data/story.json)
##   DOCUMENT  -> DocumentUI (papel na tela) + comentário da Yuko
##   NOTE do "Mapa" -> frase escrita no mapa (não há voz: o mapa é a voz)
## Também mostra as pistas como documento quando a Yuko examina um objeto,
## cuida do mapa (MapUI), do FLUXO DE CADA SALA e do fim do jogo.
##
## Fluxo da sala (pedido da equipe, story.json → "room_flow"):
##   entra → a porta fecha e tranca atrás dela → procura pistas
##   → a pista barulhenta acorda o professor → ela se esconde
##   → "ELE SE ACALMOU" (o professor volta ao posto e dorme de novo)
##   → a pergunta (última pista) só abre com ele dormindo
##   → resposta certa: a porta abre sozinha e ele acorda de novo → fuga
##   → saiu da sala: a porta fecha atrás dela e ele volta ao posto.
##
## Versão 5.7 — o enigma da melodia (Música, story.json → "music_sequences"):
##   pistas → E no piano → o Maestro toca (cada nota aparece na lousa com o
##   número e some) → ele para, observa e acorda → ela se esconde → calmo →
##   teclado da porta: certo = destrava e abre; errado = som desafinado, o
##   Maestro reage e caça de novo (captura = volta ao checkpoint). O piano pode
##   ser pedido de novo com ele calmo (ele toca e acorda outra vez).
##
## Fila: uma coisa de cada vez. Cenas e documentos esperam o
## painel de enigma e a tela de captura fecharem — nada se sobrepõe.

signal cutscene_started(id: StringName)
signal cutscene_finished(id: StringName)
signal game_ended

const STORY_PATH := "res://data/story.json"
const OPENING := &"cena_abertura"

var story: Dictionary = {}
var cutscenes: CutscenePlayer
var documents: DocumentUI
var map: MapUI
var narrative: NarrativeManager
var phone: Node
var hud: Node
var player: CharacterBody3D

## Só conta a história quando o jogo foi iniciado de verdade (menu: novo
## jogo / continuar / checkpoint). Testes que montam a cena à mão ficam sem
## cenas e sem papéis na tela — a mesma regra da abertura em GameSession.
var enabled := false

var _queue: Array[Callable] = []
var _running := false
var _busy_reason := ""
var ended := false

var _cutscene_room := ""
var _cutscene_first_cam := Vector3.INF

var audio: StoryAudio

var _toast_layer: CanvasLayer
var _toast: Label
var _toast_left := 0.0


func _ready() -> void:
	add_to_group("story_director")
	add_to_group("quality_listener")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_story()
	cutscenes = CutscenePlayer.new()
	cutscenes.protagonist_name = String(story.get("protagonist", "Yuko"))
	cutscenes.map_speaker = String(story.get("map_speaker", "Mapa"))
	add_child(cutscenes)
	documents = DocumentUI.new()
	add_child(documents)
	map = MapUI.new()
	map.director = self
	var m: Dictionary = story.get("map", {})
	map.areas = m.get("areas", [])
	map.targets = m.get("targets", [])
	add_child(map)
	audio = StoryAudio.new()
	audio.name = "StoryAudio"
	add_child(audio)
	_build_toast()
	narrative = get_tree().get_first_node_in_group("narrative_manager")
	player = get_tree().get_first_node_in_group("player")
	if narrative != null:
		narrative.event_triggered.connect(_on_event)
	var interactor := get_tree().get_first_node_in_group("player_interactor")
	if interactor != null:
		interactor.interaction_performed.connect(_on_interaction)
	apply_quality.call_deferred(int(SaveSystem.get_setting("quality")))
	_connect_monsters.call_deferred()
	_connect_flow.call_deferred()


func setup(p_phone: Node, p_hud: Node) -> void:
	phone = p_phone
	hud = p_hud
	if phone != null and phone.has_method("apply_subtitle_size"):
		cutscenes.apply_subtitle_size(int(SaveSystem.get_setting("subtitle_size")))


func _load_story() -> void:
	var f := FileAccess.open(STORY_PATH, FileAccess.READ)
	if f == null:
		push_error("StoryDirector: %s não encontrado." % STORY_PATH)
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("StoryDirector: %s inválido." % STORY_PATH)
		return
	story = data


# ================================================================ API

func is_busy() -> bool:
	return _running or cutscenes.playing or documents.is_open()


## Jogo novo: tela preta + cena de abertura.
func start_new_game() -> void:
	cutscenes.set_black(1.0)
	if player != null and "visual" in player:
		_pose_now("lying")
	if narrative == null or not narrative.trigger_manual(OPENING):
		cutscenes.set_black(0.0)


func get_save_data() -> Dictionary:
	return {"map": map.obtained, "revealed": map.revealed.keys(), "ended": ended,
		"notes": map.get_save_data(), "flow": _phase.duplicate()}


func load_save_data(data: Dictionary) -> void:
	map.set_obtained(bool(data.get("map", false)))
	for r in data.get("revealed", []):
		map.reveal(String(r))
	map.load_notes(data.get("notes", []))
	_phase = {}
	var saved: Dictionary = data.get("flow", {})
	for room_id in saved:
		_phase[String(room_id)] = String(saved[room_id])
	# Portas do fluxo: sala em andamento ou concluída fica trancada.
	for room_id in _phase:
		var ph: String = _phase[room_id]
		if ph in [PH_SEARCH, PH_AWAKE, PH_CALM, PH_DONE]:
			_lock_door_when_clear(room_id)


func toast(text: String, seconds: float = 2.5) -> void:
	_toast.text = text
	_toast.get_parent().visible = true
	_toast_left = seconds


# ================================================================ fila

func _enqueue(job: Callable) -> void:
	_queue.append(job)
	if not _running:
		_run_queue()


func _run_queue() -> void:
	_running = true
	while not _queue.is_empty() and is_inside_tree():
		await _wait_until_free()
		if not is_inside_tree():
			break
		var job: Callable = _queue.pop_front()
		await job.call()
	_running = false


func _wait_until_free() -> void:
	while is_inside_tree():
		var blocked := false
		if phone != null and "state" in phone and String(phone.state) != "idle":
			blocked = true
		var pz := get_tree().get_first_node_in_group("puzzle_ui")
		if pz != null and pz.has_method("is_open") and pz.is_open():
			blocked = true
		var go := get_tree().get_first_node_in_group("game_over_ui")
		if go != null and go.has_method("is_open") and go.is_open():
			blocked = true
		if map.is_open():
			map.close()
		var pm := get_tree().get_first_node_in_group("pause_menu")
		if pm != null and pm.has_method("is_open") and pm.is_open():
			blocked = true
		if not blocked:
			return
		await _next_frame()


# ================================================================ eventos

func _on_event(event: NarrativeEvent) -> void:
	if not enabled:
		return
	match event.type:
		NarrativeEvent.EventType.CUTSCENE:
			if event.trigger == NarrativeEvent.TriggerType.MONSTER_STATE:
				# O professor acorda no mesmo quadro em que ela mexe na pista
				# barulhenta: primeiro o papel (o que caiu), depois a cena.
				_enqueue.call_deferred(_play_cutscene.bind(event))
			else:
				_enqueue(_play_cutscene.bind(event))
		NarrativeEvent.EventType.NOTE:
			if event.speaker == cutscenes.map_speaker:
				# Escrito no mapa: não pausa o jogo, espera só o que estiver na frente.
				var area := String(event.room_id)
				var text := "\n".join(event.lines)
				_enqueue(func(): map.write_note(area, text))
			else:
				_enqueue(_show_event_document.bind(event))
		NarrativeEvent.EventType.DOCUMENT, NarrativeEvent.EventType.RESEARCH_LOG:
			_enqueue(_show_event_document.bind(event))


func _play_cutscene(event: NarrativeEvent) -> void:
	await play_story_cutscene(event.id, String(event.room_id))


## Toca uma cena do roteiro pelo id (eventos da história e cenas do diretor,
## como a melodia do Maestro, que pode repetir).
func play_story_cutscene(id: StringName, room_id: String = "") -> void:
	var cs: Dictionary = story.get("cutscenes", {}).get(String(id), {})
	if cs.is_empty():
		push_warning("StoryDirector: cena %s sem roteiro em story.json." % id)
		return
	if game_over_open():
		return
	cutscene_started.emit(id)
	_cutscene_room = room_id if room_id != "" else String(cs.get("room_id", ""))
	# Primeira posição de câmera da cena (para a Yuko deitada olhar para ela).
	_cutscene_first_cam = Vector3.INF
	for st in cs.get("steps", []):
		var c: Dictionary = st.get("cam", {})
		var f: Dictionary = c.get("from", c.get("to", {}))
		var pos: Variant = f.get("pos", null)
		if pos is Array and pos.size() == 3:
			_cutscene_first_cam = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
			break
	if map.is_open():
		map.close()
	_toast_left = 0.0
	_toast.get_parent().visible = false
	await cutscenes.play(cs, self)
	if not is_inside_tree():
		return
	cutscene_finished.emit(id)
	await _apply_effects(cs.get("effects", []))


func game_over_open() -> bool:
	var go := get_tree().get_first_node_in_group("game_over_ui")
	return go != null and go.has_method("is_open") and go.is_open()


func _show_event_document(event: NarrativeEvent) -> void:
	await documents.show_document("documento", event.title, "\n\n".join(event.lines))
	if not is_inside_tree():
		return
	var doc: Dictionary = story.get("documents", {}).get(String(event.id), {})
	for line in doc.get("after", []):
		await cutscenes.say_outside(String(line[0]), String(line[1]), self)


## Pistas: ao examinar um objeto que revela pista, o texto aparece no papel.
func _on_interaction(interaction_id: StringName, _action: StringName, _target: Node) -> void:
	if not enabled:
		return
	var def: InteractiveObjectData = GameData.get_instance().get_object(interaction_id)
	if def == null:
		return
	for effect in def.effects:
		if effect is Dictionary and String(effect.get("type", "")) == "music_sequence":
			_on_music_piano(String(effect.get("room_id", "")))
		if effect is Dictionary and String(effect.get("type", "")) == "reveal_clue":
			var clue: ClueData = GameData.get_instance().puzzle_db.get_clue(StringName(str(effect.get("clue_id", ""))))
			if clue != null:
				_enqueue(func(): await documents.show_document("pista" if clue.puzzle_id != &"" else "achado", clue.title, clue.content))


# ================================================================ o Leitor imita vozes (lore)

const FALSE_VOICES := [
	"Yuko? Sou eu... pode sair, ele já foi embora.",
	"Ei! Aqui! Não tem mais ninguém na sala!",
	"Yuko... volta para a carteira. A aula ainda não acabou.",
]
var _false_voice_cooldown := 0.0
var _false_voice_index := 0


func _connect_monsters() -> void:
	for m in get_tree().get_nodes_in_group("monster"):
		if m is MonsterController and not m.false_voice_emitted.is_connected(_on_false_voice):
			m.false_voice_emitted.connect(_on_false_voice)


func _on_false_voice(_where: Vector3, _clue: String) -> void:
	if not enabled or _false_voice_cooldown > 0.0 or is_busy():
		return
	_false_voice_cooldown = 18.0
	var text: String = FALSE_VOICES[_false_voice_index % FALSE_VOICES.size()]
	_false_voice_index += 1
	cutscenes.say_outside("???", text)


# ================================================================ efeitos

func _apply_effects(effects: Array) -> void:
	for e in effects:
		if not is_inside_tree():
			return
		if typeof(e) != TYPE_DICTIONARY:
			continue
		match String(e.get("type", "")):
			"unlock_door":
				for d in get_tree().get_nodes_in_group("door"):
					if d is Door and String(d.door_id) == String(e.get("door_id", "")):
						d.unlock()
			"open_door":
				# destranca e abre (com animação): usada no pátio, cuja porta fica
				# do lado da câmera e não aparece na tela para a Yuko apertar E.
				for d in get_tree().get_nodes_in_group("door"):
					if d is Door and String(d.door_id) == String(e.get("door_id", "")):
						d.unlock()
						d.open(true, false)
				if String(e.get("toast", "")) != "":
					toast(String(e.get("toast", "")), 6.0)
			"activate_monster":
				for m in get_tree().get_nodes_in_group("monster"):
					if m is MonsterController and m.resolve_config() != null and String(m.resolve_config().monster_id) == String(e.get("monster_id", "")):
						# "patrol": já sai patrulhando (sem mirar na Yuko na porta).
						if bool(e.get("patrol", false)):
							m.activate(&"roteiro", m.global_position, true)
						else:
							m.activate(&"roteiro", player.global_position if player != null else m.global_position)
			"set_objective":
				if hud != null and hud.has_method("set_objective"):
					hud.set_objective(String(e.get("text", "")))
			"map_obtained":
				map.set_obtained(true)
				toast("Mapa guardado — aperte [M] para abrir.", 4.0)
			"show_controls":
				var k := func(a: String) -> String: return SaveSystem.key_name(a)
				toast("%s%s%s%s andar  ·  %s correr  ·  %s agachar (sem barulho)  ·  %s interagir\n%s pistas  ·  %s mapa  ·  %s pausa" % [
					k.call("move_forward"), k.call("move_left"), k.call("move_back"), k.call("move_right"),
					k.call("run"), k.call("crouch"), k.call("interact"), k.call("diario"), k.call("mapa"), k.call("pause")], 9.0)
			"map_reveal":
				map.reveal(String(e.get("area", "")))
			"checkpoint":
				if not is_inside_tree():
					return
				var session := get_tree().get_first_node_in_group("game_session")
				if session != null:
					await get_tree().physics_frame
					session.save_checkpoint(String(e.get("reason", "história")))
			"end_game":
				await _end_game()
			# ---- versão 5.7 (enigma da melodia; também valem como passo de cena)
			"monster_place":
				var mp := _monster_by_id(String(e.get("monster_id", "")))
				var pos: Array = e.get("pos", [])
				if mp != null and pos.size() >= 3:
					if mp.is_active():
						mp.deactivate(false)
					mp.global_position = Vector3(float(pos[0]), mp.global_position.y, float(pos[2]))
					if pos.size() >= 4:
						mp.rotation.y = deg_to_rad(float(pos[3]))
					mp.velocity = Vector3.ZERO
					mp.reset_physics_interpolation()
			"player_place":
				var pp: Array = e.get("pos", [])
				if player != null and pp.size() >= 3:
					player.global_position = Vector3(float(pp[0]), player.global_position.y, float(pp[2]))
					player.velocity = Vector3.ZERO
					var look: Array = e.get("look", [])
					if look.size() >= 3 and "visual" in player and player.visual != null:
						var d := Vector3(float(look[0]), 0, float(look[2])) - Vector3(float(pp[0]), 0, float(pp[2]))
						player.visual.rotation.y = atan2(d.x, d.z)
					player.reset_physics_interpolation()
			"monster_pose":
				var mm := _monster_by_id(String(e.get("monster_id", "")))
				if mm != null:
					for an in mm.find_children("*", "MonsterAnimator", true, false):
						(an as MonsterAnimator).pose(StringName(String(e.get("pose", "search"))))
			"sound":
				audio.play(String(e.get("name", "")), float(e.get("volume", 0.0)))
			"music_awake":
				_music_wake(String(e.get("room_id", "")), "awake", "objective_hide", &"melodia")
				var cm := get_tree().get_first_node_in_group("clue_manager")
				var mcfg := music_config(String(e.get("room_id", "")))
				if cm != null and String(mcfg.get("pista_final", "")) != "":
					cm.discover(StringName(String(mcfg.pista_final)))
			"music_wrong":
				_music_wake(String(e.get("room_id", "")), "erro", "objective_wrong", &"desafinou")
				toast("DESAFINADO! Ele ouviu o erro. Esconda-se!", 4.0)


func _end_game() -> void:
	ended = true
	game_ended.emit()
	var layer := CanvasLayer.new()
	layer.layer = 120
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(820, 0)
	box.add_theme_constant_override("separation", 18)
	layer.add_child(box)
	for t in [["FIM DO CAPÍTULO 1", 34], ["Yuko descobriu que já estudou nesta escola — e que nunca esteve sozinha.", 18],
			["Quem é o Observador? O que é a Fase 3?", 18], ["", 10], ["Obrigado por jogar.", 20]]:
		var l := UIStyle.label(String(t[0]), int(t[1]))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	var btn := UIStyle.button("Voltar ao menu", func():
		var session := get_tree().get_first_node_in_group("game_session")
		if session != null:
			session.go_to_main_menu()
		else:
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	box.add_child(btn)
	btn.grab_focus()
	get_tree().paused = true


# ================================================================ contexto da cena (chamado pelo CutscenePlayer)

func cutscene_anchor(anchor: String) -> Vector3:
	if anchor == "player" and player != null:
		return player.global_position
	if anchor.begins_with("monster:"):
		var id := anchor.substr(8)
		for m in get_tree().get_nodes_in_group("monster"):
			if m is MonsterController and m.resolve_config() != null and String(m.resolve_config().monster_id) == id:
				return m.global_position
	return player.global_position if player != null else Vector3.ZERO


func cutscene_line(_speaker: String, _text: String) -> void:
	pass


## Passo "effects" de uma cena: efeitos no meio do filme (pôr o Maestro no piano...).
func cutscene_effects(effects: Array) -> void:
	await _apply_effects(effects)


## Passo "sequencia" de uma cena: a lousa da sala mostra a melodia, nota a nota.
func cutscene_sequence(room_id: String) -> void:
	var cfg := music_config(room_id)
	for l in get_tree().get_nodes_in_group("lousa_notas"):
		if l is LousaNotas and String(l.room_id) == room_id:
			await (l as LousaNotas).apresentar(cfg.get("notas", []), float(cfg.get("intervalo", 2.4)), float(cfg.get("pausa", 0.5)))
			return
	push_warning("StoryDirector: sala %s sem LousaNotas." % room_id)


## Passo "map_open"/"map_close" das cenas: o mapa abre na tela durante a cena.
func cutscene_map(open: bool) -> void:
	if open:
		map.obtained = true   # na cena do mapa ela já está com ele nas mãos
		map.open()
	else:
		map.close()


## Fala do "Mapa" numa cena: a frase se escreve sozinha no mapa.
func cutscene_map_write(text: String) -> void:
	await map.write_note(_cutscene_room if _cutscene_room != "" else "patio", text)


func cutscene_ring(_seconds: float) -> void:
	pass


func cutscene_pose(pose: String, seconds: float) -> void:
	if player == null or not ("visual" in player):
		return
	if pose == "lying":
		_pose_now("lying")
		return
	if pose == "standing":
		var yuko := _yuko()
		if yuko != null:
			await yuko.wake_up(seconds)
		else:
			# cápsula provisória (sem modelo animado)
			var v: Node3D = player.visual
			var from_rot := v.rotation
			var from_pos := v.position
			var to_pos: Vector3 = player.visual_standing_position() if player.has_method("visual_standing_position") else Vector3(0, 0.9, 0)
			var t := 0.0
			while t < seconds and is_inside_tree():
				await _next_frame()
				t += get_process_delta_time() if get_process_delta_time() > 0.0 else 1.0 / 60.0
				var k := clampf(t / seconds, 0.0, 1.0)
				k = k * k * (3.0 - 2.0 * k)
				v.rotation = Vector3(lerpf(from_rot.x, 0.0, k), from_rot.y, lerpf(from_rot.z, 0.0, k))
				v.position = from_pos.lerp(to_pos, k)
		if player.has_method("update_crouch"):
			player.update_crouch()


func _yuko() -> YukoAnimator:
	if player == null or not ("visual" in player) or player.visual == null:
		return null
	for c in player.visual.get_children():
		if c is YukoAnimator:
			return c
	return null


func _pose_now(pose: String) -> void:
	if pose != "lying":
		return
	var yuko := _yuko()
	if yuko != null:
		yuko.pose_lying(_cutscene_first_cam)
		return
	var v: Node3D = player.visual
	v.rotation = Vector3(0, v.rotation.y, deg_to_rad(88.0))
	v.position = player.visual_lying_position() if player.has_method("visual_lying_position") else Vector3(0, 0.28, 0)


# ================================================================ fluxo da sala

const PH_SEARCH := "busca"      # entrou: porta trancada, procurando pistas
const PH_AWAKE := "acordado"    # a pista barulhenta acordou o professor
const PH_CALM := "calmo"        # ele se acalmou: a pergunta pode ser respondida
const PH_ESCAPE := "fuga"       # resposta certa: porta aberta, ele acordou de novo
const PH_DONE := "concluida"    # saiu: porta fechada atrás dela
## Perseguição mínima: o professor fica acordado e caçando por pelo menos
## este tempo (s) antes de poder "se acalmar" (pedido da equipe: >= 30 s).
const MIN_AWAKE_TIME := 30.0
## Depois do tempo mínimo, quanto tempo ela precisa ficar escondida sem ser
## achada para ele desistir e voltar ao posto (s).
const HIDE_TO_CALM := 5.0
## De quanto em quanto tempo ele "ouve" onde ela está enquanto ela não se esconde (s).
const HUNT_INTERVAL := 0.6

var _phase := {}            # room_id -> fase
var _awake_time := {}       # room_id -> segundos acordado
var _hidden_time := {}      # room_id -> segundos escondida (enquanto ele procura)
var _hunt_clock := {}       # room_id -> relógio da caça
var _giving_up := {}        # room_id -> já desistiu e está voltando ao posto
var _pending_locks := {}    # door_id -> true (fecha quando o vão estiver livre)
var _pending_calm_save := false
var _rooms_mgr: Node
var _puzzles: Node


func _flow() -> Dictionary:
	return story.get("room_flow", {})


func _connect_flow() -> void:
	_rooms_mgr = get_tree().get_first_node_in_group("room_progress_manager")
	_puzzles = get_tree().get_first_node_in_group("puzzle_manager")
	if _rooms_mgr != null:
		_rooms_mgr.room_entered.connect(_on_flow_room_entered)
		_rooms_mgr.room_completed.connect(_on_flow_room_completed)
	if _puzzles != null:
		_puzzles.puzzle_solved.connect(_on_flow_puzzle_solved)
		_puzzles.answer_submitted.connect(_on_flow_answer)
	for m in get_tree().get_nodes_in_group("monster"):
		if m is MonsterController:
			m.state_changed.connect(_on_flow_monster_state.bind(m))


## Fase da sala no fluxo ("" = ainda não entrou).
func get_room_phase(room_id: String) -> String:
	return String(_phase.get(room_id, ""))


func _monster_for(room_id: String) -> MonsterController:
	var mid := String(_flow().get(room_id, {}).get("monster_id", ""))
	for m in get_tree().get_nodes_in_group("monster"):
		if m is MonsterController and m.resolve_config() != null and String(m.resolve_config().monster_id) == mid:
			return m
	return null


func _door(door_id: String) -> Door:
	for d in get_tree().get_nodes_in_group("door"):
		if d is Door and String(d.door_id) == door_id:
			return d
	return null


func _lock_door_when_clear(room_id: String) -> void:
	var door_id := String(_flow().get(room_id, {}).get("door_id", ""))
	var d := _door(door_id)
	if d == null:
		return
	d.story_locked = true
	d._refresh_lock()
	_pending_locks[door_id] = true


func _objective(text: String) -> void:
	if text != "" and hud != null and hud.has_method("set_objective"):
		hud.set_objective(text)


func _note(room_id: String, key: String) -> void:
	var text := String(_flow().get(room_id, {}).get("notes", {}).get(key, ""))
	if text != "":
		_enqueue(func(): map.write_note(room_id, text))


func _save(reason: String) -> void:
	var session := get_tree().get_first_node_in_group("game_session")
	if session != null and session.has_method("save_checkpoint"):
		session.save_checkpoint(reason)


## A pergunta da sala só abre com o professor dormindo (PuzzleUI pergunta aqui).
func puzzle_block_reason(puzzle: PuzzleData) -> String:
	var room_id := String(puzzle.room_id)
	if not _flow().has(room_id):
		return ""
	var m := _monster_for(room_id)
	if m != null and m.is_active():
		return "Agora não — ele está te procurando. Espere ele se acalmar."
	return ""


func _on_flow_room_entered(room_id: StringName) -> void:
	var rid := String(room_id)
	if not enabled or not _flow().has(rid) or get_room_phase(rid) != "":
		return
	_phase[rid] = PH_SEARCH
	_lock_door_when_clear(rid)
	var cfg: Dictionary = _flow()[rid]
	_note(rid, "enter")
	_enqueue(func(): _objective(String(cfg.get("objective_search", "Procure as pistas da sala."))))


func _on_flow_monster_state(previous: int, current: int, m: MonsterController) -> void:
	if not enabled:
		return
	for rid in _flow():
		if _monster_for(rid) != m:
			continue
		var ph := get_room_phase(rid)
		if previous == MonsterController.State.INACTIVE and current != MonsterController.State.INACTIVE and ph in [PH_SEARCH, ""]:
			_phase[rid] = PH_AWAKE
			_awake_time[rid] = 0.0
			_hidden_time[rid] = 0.0
			_giving_up[rid] = false
			_note(rid, "awake")
			_enqueue(func(): _objective(String(_flow()[rid].get("objective_hide", "Esconda-se! Espere ele se acalmar."))))


func _process_flow(delta: float) -> void:
	if get_tree().paused:
		return
	# portas que esperam o vão ficar livre para fechar atrás dela
	for door_id in _pending_locks.keys():
		var d := _door(door_id)
		if d == null:
			_pending_locks.erase(door_id)
			continue
		if not d.is_open():
			_pending_locks.erase(door_id)
			continue
		if _player_clear_of(d) and d.close():
			_pending_locks.erase(door_id)
			_on_door_closed_behind(door_id)
	# Professor acordado: caça a Yuko. Enquanto ela não se esconde, ele sabe
	# onde ela está (ouve os passos) e corre atrás. Escondida, ele procura em
	# volta. Só depois de MIN_AWAKE_TIME e com ela escondida há HIDE_TO_CALM s
	# ele desiste, volta ao posto e aparece "ELE SE ACALMOU".
	var hidden: bool = player != null and player.has_method("is_hidden") and player.is_hidden()
	for rid in _phase:
		var ph: String = _phase[rid]
		if ph != PH_AWAKE and ph != PH_ESCAPE:
			continue
		var m := _monster_for(rid)
		if m == null:
			continue
		_hunt_clock[rid] = float(_hunt_clock.get(rid, 0.0)) + delta
		var feed := float(_hunt_clock[rid]) >= HUNT_INTERVAL
		if feed:
			_hunt_clock[rid] = 0.0
		if ph == PH_ESCAPE:
			# fuga: ele corre atrás dela até ela sair da sala
			if feed and not hidden and m.is_active() and player != null:
				m.hunt(player.global_position)
			continue
		_awake_time[rid] = float(_awake_time.get(rid, 0.0)) + delta
		var awake := float(_awake_time[rid])
		if not m.is_active():
			if awake >= MIN_AWAKE_TIME:
				_calm(rid, m)
			elif player != null:
				m.activate(&"perseguicao", player.global_position, true)
			continue
		if hidden:
			_hidden_time[rid] = float(_hidden_time.get(rid, 0.0)) + delta
			if m.state == MonsterController.State.CHASING and not player.is_witness(m):
				m.lose_track()
			if awake < MIN_AWAKE_TIME or float(_hidden_time[rid]) < HIDE_TO_CALM:
				# ainda procurando: ronda perto de onde ela sumiu
				if m.state in [MonsterController.State.RETURNING, MonsterController.State.PATROLLING, MonsterController.State.INVESTIGATING] and feed and player != null:
					var a := randf() * TAU
					m.prowl(player.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 4.5))
			elif not _giving_up.get(rid, false):
				_giving_up[rid] = true
				m.give_up()
			elif m.state == MonsterController.State.PATROLLING or m._state_time > 10.0:
				_calm(rid, m)
		else:
			_hidden_time[rid] = 0.0
			_giving_up[rid] = false
			if feed and player != null:
				m.hunt(player.global_position)
	if _pending_calm_save and player != null and not (player.has_method("is_hidden") and player.is_hidden()):
		_pending_calm_save = false
		_save("ele se acalmou")


func _player_clear_of(d: Door) -> bool:
	if player == null:
		return true
	var local := d.to_local(player.global_position)
	return absf(local.x) > 1.2 or absf(local.z) > 2.2


func _on_door_closed_behind(door_id: String) -> void:
	for rid in _phase:
		if String(_flow()[rid].get("door_id", "")) == door_id and _phase[rid] == PH_SEARCH:
			_enqueue(func(): _save("porta fechou: %s" % rid))


func _calm(rid: String, m: MonsterController) -> void:
	_phase[rid] = PH_CALM
	if m.is_active():
		m.deactivate(true)
	_note(rid, "calm")
	_enqueue(func(): _objective(String(_flow()[rid].get("objective_answer", "Ele se acalmou. Responda a pergunta."))))
	_pending_calm_save = true


func _on_flow_puzzle_solved(puzzle: PuzzleData) -> void:
	var rid := String(puzzle.room_id)
	if not enabled or not _flow().has(rid) or String(_flow()[rid].get("puzzle_id", "")) != String(puzzle.id):
		return
	_phase[rid] = PH_ESCAPE
	var cfg: Dictionary = _flow()[rid]
	if not music_config(rid).is_empty():
		audio.play("destrava", -2.0)
	_enqueue(func():
		var d := _door(String(cfg.get("door_id", "")))
		if d != null:
			d.unlock()
			d.open(true)
		_pending_locks.erase(String(cfg.get("door_id", "")))
		var m := _monster_for(rid)
		if m != null and player != null:
			if m.is_active():
				m.hear_stimulus(player.global_position)
			else:
				m.activate(&"resposta_certa", player.global_position)
		map.write_note(rid, String(cfg.get("notes", {}).get("open", "CORRA.")))
		_objective(String(cfg.get("objective_run", "A porta abriu! Corra!"))))


func _on_flow_room_completed(room_id: StringName) -> void:
	var rid := String(room_id)
	if not enabled or not _flow().has(rid):
		return
	_phase[rid] = PH_DONE
	var cfg: Dictionary = _flow()[rid]
	var m := _monster_for(rid)
	if m != null:
		m.deactivate(true)
	_lock_door_when_clear(rid)
	for e in cfg.get("on_done", []):
		_apply_effects([e])
	_enqueue(func(): _objective(String(cfg.get("next_objective", ""))))


# ================================================================ versão 5.7: o enigma da melodia

var _music_wrong_pending := false


func music_config(room_id: String) -> Dictionary:
	return story.get("music_sequences", {}).get(room_id, {})


func _monster_by_id(id: String) -> MonsterController:
	for m in get_tree().get_nodes_in_group("monster"):
		if m is MonsterController and m.resolve_config() != null and String(m.resolve_config().monster_id) == id:
			return m
	return null


## E no piano: pede a melodia ao professor (só com as pistas lidas e ele dormindo).
func _on_music_piano(room_id: String) -> void:
	var cfg := music_config(room_id)
	if cfg.is_empty():
		return
	var ph := get_room_phase(room_id)
	if _puzzles != null and _puzzles.is_solved(StringName(String(cfg.get("puzzle_id", "")))):
		toast("A porta já está aberta. Não é hora de música!", 3.0)
		return
	if ph == PH_AWAKE:
		toast("Agora não — ele está te procurando. Esconda-se!", 3.0)
		return
	if ph in [PH_ESCAPE, PH_DONE]:
		toast("Não é hora de música. Saia daqui!", 3.0)
		return
	var cm := get_tree().get_first_node_in_group("clue_manager")
	var faltam: PackedStringArray = []
	for cid in cfg.get("pistas_antes", []):
		if cm != null and not cm.is_discovered(StringName(String(cid))):
			var c: ClueData = GameData.get_instance().puzzle_db.get_clue(StringName(String(cid)))
			faltam.append(c.title if c != null else String(cid))
	if not faltam.is_empty():
		toast("A tampa do piano não abre. Antes, leia: %s." % ", ".join(faltam), 4.5)
		return
	_enqueue(func(): await play_story_cutscene(StringName(String(cfg.get("cena", ""))), room_id))


## Depois da melodia (ou de um erro no teclado): o professor acorda e caça.
func _music_wake(room_id: String, note_key: String, objective_key: String, reason: StringName) -> void:
	if not _flow().has(room_id):
		return
	_phase[room_id] = PH_AWAKE
	_awake_time[room_id] = 0.0
	_hidden_time[room_id] = 0.0
	_hunt_clock[room_id] = 0.0
	_giving_up[room_id] = false
	_pending_calm_save = false
	var m := _monster_for(room_id)
	if m != null and player != null:
		if m.is_active():
			m.hunt(player.global_position)
		else:
			m.activate(reason, player.global_position)
	_note(room_id, note_key)
	var cfg: Dictionary = _flow()[room_id]
	_enqueue(func(): _objective(String(cfg.get(objective_key, cfg.get("objective_hide", "Esconda-se!")))))


## Resposta errada no teclado da melodia: fecha o painel, som desafinado e o
## Maestro reage (cena curta) e volta a caçar. Não há vidas no jogo: a
## consequência é a caçada; se ele a pegar, volta ao último checkpoint.
func _on_flow_answer(puzzle: PuzzleData, correct: bool) -> void:
	if not enabled or correct or puzzle == null:
		return
	var rid := String(puzzle.room_id)
	var cfg := music_config(rid)
	if cfg.is_empty() or String(cfg.get("puzzle_id", "")) != String(puzzle.id) or _music_wrong_pending:
		return
	_music_wrong_pending = true
	audio.play("erro", -2.0)
	await get_tree().create_timer(0.8, true).timeout
	var pz := get_tree().get_first_node_in_group("puzzle_ui")
	if pz != null and pz.has_method("close_puzzle"):
		pz.close_puzzle()
	_music_wrong_pending = false
	_enqueue(func(): await play_story_cutscene(StringName(String(cfg.get("cena_erro", ""))), rid))


func _process_music_ambient() -> void:
	var want := ""
	var vol := -10.0
	if enabled and _rooms_mgr != null and not ended:
		var cur := String(_rooms_mgr.current_room)
		var cfg := music_config(cur)
		if not cfg.is_empty() and get_room_phase(cur) in [PH_SEARCH, PH_AWAKE, PH_CALM, PH_ESCAPE]:
			want = String(cfg.get("ambiente", ""))
	audio.ambient(want, vol)


# ================================================================ versão 6.0: qualidade gráfica

## Leve: as luzes da escola deixam de fazer sombra (a luz continua igual).
## Equilibrada/Alta: sombras como sempre. Chamado pelas Configurações.
func apply_quality(q: int) -> void:
	var scene := get_parent()
	if scene == null:
		return
	for l in scene.find_children("*", "Light3D", true, false):
		var light := l as Light3D
		if not light.has_meta("sombra_original"):
			light.set_meta("sombra_original", light.shadow_enabled)
		light.shadow_enabled = bool(light.get_meta("sombra_original")) and q >= 1


# ================================================================ aviso curto

func _build_toast() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 45
	add_child(_toast_layer)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.65)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -140
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_layer.add_child(panel)
	_toast = UIStyle.label("", 19)
	_toast.autowrap_mode = TextServer.AUTOWRAP_OFF   # com quebra automática o painel encolhia até 1 letra
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_toast)
	panel.visible = false


func _process(delta: float) -> void:
	if enabled:
		_process_flow(delta)
	_process_music_ambient()
	if _false_voice_cooldown > 0.0 and not get_tree().paused:
		_false_voice_cooldown -= delta
	if _toast_left > 0.0:
		_toast_left -= delta if delta > 0.0 else 1.0 / 60.0
		if _toast_left <= 0.0:
			_toast.get_parent().visible = false


## Próximo quadro sem quebrar quando a cena é trocada no meio (voltar ao menu,
## recarregar o checkpoint): fora da árvore, usa o laço principal do jogo.
func _next_frame() -> void:
	if is_inside_tree():
		await get_tree().process_frame
	else:
		await (Engine.get_main_loop() as SceneTree).process_frame
