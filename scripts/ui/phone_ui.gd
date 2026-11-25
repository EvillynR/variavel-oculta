class_name PhoneUI
extends CanvasLayer
## Prompt 3 — o telefone (lore, seção 3): chamada recebida do "Desconhecido",
## vibração (tremor + brilho), legendas, alertas curtos e histórico (ação
## "telefone"). Disparado pelos eventos PHONE_CALL do NarrativeManager.
## Eventos com phone_kind = "alerta" viram um aviso curto, sem tela de chamada.

signal call_started(event: NarrativeEvent)
signal line_shown(speaker: String, text: String)

const RING_TIME := 1.6
var history: Array[Dictionary] = []   # {speaker, text, kind, event}
var state: String = "idle"            # idle | ringing | call | alert
var _queue: Array[NarrativeEvent] = []
var _phone: PanelContainer
var _phone_box: VBoxContainer
var _status: Label
var _caller: Label
var _subtitle: Label
var _subtitle_panel: PanelContainer
var _history_root: Control
var _history_list: VBoxContainer
var _glow: StyleBoxFlat
var _busy := false
var _phone_rest := Vector2.ZERO


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("subtitle_listener")
	_build()
	var nm := get_tree().get_first_node_in_group("narrative_manager")
	if nm != null:
		nm.event_triggered.connect(_on_event)


func _build() -> void:
	_phone = PanelContainer.new()
	_phone.custom_minimum_size = Vector2(230, 120)
	_glow = UIStyle.panel_box(Color(0.35, 0.6, 0.75))
	_glow.bg_color = Color(0.03, 0.04, 0.05, 0.95)
	_glow.set_corner_radius_all(14)
	_glow.set_border_width_all(2)
	_phone.add_theme_stylebox_override("panel", _glow)
	_phone.anchor_left = 1.0
	_phone.anchor_right = 1.0
	_phone.anchor_top = 1.0
	_phone.anchor_bottom = 1.0
	_phone.offset_left = -300
	_phone.offset_right = -30
	_phone.offset_top = -190
	_phone.offset_bottom = -40
	add_child(_phone)
	_phone_box = VBoxContainer.new()
	_phone.add_child(_phone_box)
	_status = UIStyle.label("Chamada recebida", 14, UIStyle.DIM)
	_caller = UIStyle.label("Desconhecido", 22)
	_caller.autowrap_mode = TextServer.AUTOWRAP_OFF
	_phone_box.add_child(_status)
	_phone_box.add_child(_caller)
	_phone.visible = false
	_subtitle_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.6)
	sb.set_content_margin_all(10)
	_subtitle_panel.add_theme_stylebox_override("panel", sb)
	_subtitle_panel.anchor_left = 0.08
	_subtitle_panel.anchor_right = 0.72
	_subtitle_panel.anchor_top = 1.0
	_subtitle_panel.anchor_bottom = 1.0
	_subtitle_panel.offset_top = -150
	_subtitle_panel.offset_bottom = -90
	add_child(_subtitle_panel)
	_subtitle = UIStyle.label("", 22)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_panel.add_child(_subtitle)
	_subtitle_panel.visible = false
	_history_root = Control.new()
	_history_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_history_root)
	var box := UIStyle.modal(_history_root, 560.0, 0.55)
	box.add_child(UIStyle.label("TELEFONE — mensagens", 24))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 320)
	box.add_child(scroll)
	_history_list = VBoxContainer.new()
	_history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_history_list)
	box.add_child(UIStyle.label("[T] fechar", 14, UIStyle.DIM))
	_history_root.visible = false
	apply_subtitle_size()


func apply_subtitle_size() -> void:
	if _subtitle != null:
		_subtitle.add_theme_font_size_override("font_size", int(SaveSystem.get_setting("subtitle_size")))


func is_history_open() -> bool:
	return _history_root.visible


func toggle_history() -> void:
	_history_root.visible = not _history_root.visible
	if _history_root.visible:
		for c in _history_list.get_children():
			c.queue_free()
		if history.is_empty():
			_history_list.add_child(UIStyle.label("Nenhuma mensagem.", 16, UIStyle.DIM))
		for h in history:
			var tag := "  (alerta)" if h.kind == "alerta" else ""
			_history_list.add_child(UIStyle.label("%s%s: %s" % [h.speaker, tag, h.text], 17))


## Restaura o histórico de um save (sem tocar de novo).
func load_history(entries: Array) -> void:
	history.clear()
	for e in entries:
		if typeof(e) == TYPE_DICTIONARY:
			history.append({"speaker": str(e.get("speaker", "")), "text": str(e.get("text", "")), "kind": str(e.get("kind", "chamada")), "event": str(e.get("event", ""))})


## Versão 3: não há mais voz no telefone (o mapa escreve). O histórico [T]
## fica desligado; ligue aqui se o telefone voltar à história.
@export var history_key_enabled := false


func _unhandled_input(event: InputEvent) -> void:
	if history_key_enabled and event.is_action_pressed("telefone") and not get_tree().paused:
		toggle_history()
		get_viewport().set_input_as_handled()


func _on_event(event: NarrativeEvent) -> void:
	if event.type != NarrativeEvent.EventType.PHONE_CALL:
		return
	_queue.append(event)
	if not _busy:
		_run_queue()


func _run_queue() -> void:
	_busy = true
	while not _queue.is_empty():
		# Não fala por cima de uma cena de filme ou de um documento aberto.
		var director := get_tree().get_first_node_in_group("story_director")
		while director != null and director.cutscenes.playing or (director != null and director.documents.is_open()):
			await get_tree().process_frame
		var event: NarrativeEvent = _queue.pop_front()
		if String(event.phone_kind) == "alerta":
			await _play_alert(event)
		else:
			await _play_call(event)
	_busy = false
	state = "idle"


func _speaker(event: NarrativeEvent) -> String:
	return event.speaker if event.speaker != "" else "Desconhecido"


func _play_call(event: NarrativeEvent) -> void:
	state = "ringing"
	call_started.emit(event)
	_status.text = "Chamada recebida"
	_caller.text = _speaker(event)
	_phone.visible = true
	await _vibrate(RING_TIME)
	state = "call"
	_status.text = "Em chamada"
	for line in event.lines:
		# "Yuko: ..." dentro da chamada = fala da protagonista no telefone.
		var who := _speaker(event)
		var text := String(line)
		for name in ["Yuko"]:
			if text.begins_with(name + ": "):
				who = name
				text = text.substr(name.length() + 2)
		_add_history(who, text, "chamada", event.id)
		await _show_subtitle("%s: %s" % [who, text], maxf(2.8, text.length() * 0.075))
	_status.text = "Chamada encerrada"
	await _wait(0.8)
	_phone.visible = false


func _play_alert(event: NarrativeEvent) -> void:
	state = "alert"
	_status.text = "Mensagem"
	_caller.text = _speaker(event)
	_phone.visible = true
	var text := " ".join(event.lines)
	_add_history(_speaker(event), text, "alerta", event.id)
	_vibrate(0.5)   # corre junto com a legenda
	await _show_subtitle("%s: %s" % [_speaker(event), text], 2.2)
	_phone.visible = false


func _add_history(speaker: String, text: String, kind: String, event_id: StringName) -> void:
	history.append({"speaker": speaker, "text": text, "kind": kind, "event": String(event_id)})
	line_shown.emit(speaker, text)


func _show_subtitle(text: String, seconds: float) -> void:
	_subtitle.text = text
	_subtitle_panel.visible = true
	await _wait(seconds)
	_subtitle_panel.visible = false


## Cena de filme: o celular toca (sem tela de legenda — a cena cuida disso).
func cinematic_ring(seconds: float) -> void:
	_status.text = "Chamada recebida"
	_caller.text = "Desconhecido"
	_phone.visible = true
	await _vibrate(seconds)
	_status.text = "Em chamada"
	await _wait(0.6)
	_phone.visible = false


## Tremor + brilho da borda (vibração), sem áudio.
func _vibrate(seconds: float) -> void:
	var t := 0.0
	var base_off := Vector2(_phone.offset_left, _phone.offset_top)
	while t < seconds:
		var d := get_process_delta_time() if get_process_delta_time() > 0.0 else 1.0 / 60.0
		t += d
		var shake := sin(t * 60.0) * 3.0 if fmod(t, 0.5) < 0.35 else 0.0
		_phone.offset_left = base_off.x + shake
		_phone.offset_right = base_off.x + 270 + shake
		_glow.border_color = Color(0.35, 0.6, 0.75).lerp(Color(0.85, 0.95, 1.0), 0.5 + 0.5 * sin(t * 14.0))
		await get_tree().process_frame
	_phone.offset_left = base_off.x
	_phone.offset_right = base_off.x + 270
	_glow.border_color = Color(0.35, 0.6, 0.75)


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time() if get_process_delta_time() > 0.0 else 1.0 / 60.0
