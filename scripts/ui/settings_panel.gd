class_name SettingsPanel
extends Control
## Prompt 3 — configurações (usadas no menu principal e na pausa).
## Tudo é gravado em user:// na hora (SaveSystem).

signal closed

var _waiting_action: String = ""
var _key_buttons: Dictionary = {}
var _sliders: Dictionary = {}
var fullscreen_check: CheckBox


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SaveSystem.load_settings()
	var box := UIStyle.modal(self, 640.0, 0.82)
	box.add_child(UIStyle.label("CONFIGURAÇÕES", 26))
	_slider(box, "volume", "Volume geral", 0.0, 1.0, 0.05)
	_slider(box, "brightness", "Brilho", 0.6, 1.6, 0.05)
	_slider(box, "camera_sensitivity", "Sensibilidade da câmera", 0.5, 2.0, 0.1)
	_slider(box, "subtitle_size", "Tamanho da legenda", 16.0, 36.0, 1.0)
	var qrow := HBoxContainer.new()
	var ql := UIStyle.label("Qualidade gráfica", 16)
	ql.autowrap_mode = TextServer.AUTOWRAP_OFF
	ql.custom_minimum_size = Vector2(250, 0)
	qrow.add_child(ql)
	var qopt := OptionButton.new()
	for i in SaveSystem.QUALITY_NAMES.size():
		qopt.add_item(SaveSystem.QUALITY_NAMES[i], i)
	qopt.selected = clampi(int(SaveSystem.get_setting("quality")), 0, 2)
	qopt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qopt.item_selected.connect(func(i): _apply_setting("quality", int(i)))
	qrow.add_child(qopt)
	box.add_child(qrow)
	box.add_child(UIStyle.label("Se o jogo travar, use Equilibrada ou Leve.", 13, UIStyle.DIM))
	fullscreen_check = CheckBox.new()
	fullscreen_check.text = "Tela cheia"
	fullscreen_check.add_theme_color_override("font_color", UIStyle.TEXT)
	fullscreen_check.button_pressed = bool(SaveSystem.get_setting("fullscreen"))
	fullscreen_check.toggled.connect(func(on): _apply_setting("fullscreen", on))
	box.add_child(fullscreen_check)
	box.add_child(UIStyle.label("Teclas (clique e pressione a nova tecla)", 16, UIStyle.DIM))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	box.add_child(grid)
	for a in SaveSystem.REMAP_ACTIONS:
		var name_label := UIStyle.label(SaveSystem.REMAP_ACTIONS[a], 15)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.custom_minimum_size = Vector2(260, 0)
		grid.add_child(name_label)
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 28)
		b.text = SaveSystem.key_name(a)
		b.pressed.connect(_start_remap.bind(a))
		grid.add_child(b)
		_key_buttons[a] = b
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(UIStyle.button("Teclas padrão", func():
		SaveSystem.reset_keys()
		_refresh_keys()))
	row.add_child(UIStyle.button("Voltar", close))


func close() -> void:
	_waiting_action = ""
	closed.emit()
	queue_free()


func _slider(box: VBoxContainer, key: String, text: String, lo: float, hi: float, step: float) -> void:
	var row := HBoxContainer.new()
	var l := UIStyle.label(text, 16)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2(250, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(SaveSystem.get_setting(key))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v): _apply_setting(key, int(v) if key == "subtitle_size" else v))
	row.add_child(s)
	box.add_child(row)
	_sliders[key] = s


func _apply_setting(key: String, value: Variant) -> void:
	SaveSystem.set_setting(key, value)
	SaveSystem.apply_global()
	var scene := get_tree().current_scene
	if scene != null:
		SaveSystem.apply_to_scene(scene)
	get_tree().call_group("subtitle_listener", "apply_subtitle_size")


func _start_remap(action: String) -> void:
	_waiting_action = action
	(_key_buttons[action] as Button).text = "pressione…"


func _input(event: InputEvent) -> void:
	if _waiting_action == "" or not (event is InputEventKey) or not event.pressed:
		return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code != KEY_ESCAPE or _waiting_action == "pause":
		SaveSystem.remap_action(_waiting_action, code)
	_waiting_action = ""
	_refresh_keys()
	get_viewport().set_input_as_handled()


func _refresh_keys() -> void:
	for a in _key_buttons:
		(_key_buttons[a] as Button).text = SaveSystem.key_name(a)
