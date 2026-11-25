class_name DocumentUI
extends CanvasLayer
## Papel na tela: pistas (ClueData) e documentos de história (eventos DOCUMENT).
## Pausa o jogo enquanto está aberto. Fecha com E, Esc ou o botão.

signal closed

var _root: Control
var _title: Label
var _body: Label
var _kind: Label
var _open := false
var _opened_frame := 0
var _was_paused := false


func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var paper := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.86, 0.82, 0.71)
	sb.border_color = Color(0.45, 0.38, 0.28)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 18
	sb.content_margin_left = 42
	sb.content_margin_right = 42
	sb.content_margin_top = 30
	sb.content_margin_bottom = 26
	paper.add_theme_stylebox_override("panel", sb)
	paper.set_anchors_preset(Control.PRESET_CENTER)
	paper.custom_minimum_size = Vector2(700, 0)
	paper.grow_horizontal = Control.GROW_DIRECTION_BOTH
	paper.grow_vertical = Control.GROW_DIRECTION_BOTH
	paper.rotation_degrees = -0.8
	_root.add_child(paper)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	paper.add_child(box)
	_kind = _label(14, Color(0.4, 0.3, 0.22))
	box.add_child(_kind)
	_title = _label(25, Color(0.16, 0.1, 0.07))
	box.add_child(_title)
	var line := ColorRect.new()
	line.color = Color(0.45, 0.35, 0.25, 0.5)
	line.custom_minimum_size = Vector2(0, 2)
	box.add_child(line)
	_body = _label(19, Color(0.18, 0.13, 0.1))
	_body.custom_minimum_size = Vector2(616, 0)
	box.add_child(_body)
	var hint := _label(14, Color(0.4, 0.32, 0.25))
	hint.text = "[E] ou [Esc] fechar  ·  [J] diário de pistas"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(hint)


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func is_open() -> bool:
	return _open


func show_document(kind: String, title: String, text: String) -> void:
	_kind.text = kind.to_upper()
	_title.text = title
	_body.text = text
	_root.visible = true
	_open = true
	_opened_frame = Engine.get_process_frames()
	_was_paused = get_tree().paused
	get_tree().paused = true
	while _open and is_inside_tree():
		await _next_frame()


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	if is_inside_tree():
		get_tree().paused = _was_paused
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _open or Engine.get_process_frames() <= _opened_frame + 2:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


## Próximo quadro sem quebrar quando a cena é trocada no meio (voltar ao menu,
## recarregar o checkpoint): fora da árvore, usa o laço principal do jogo.
func _next_frame() -> void:
	if is_inside_tree():
		await get_tree().process_frame
	else:
		await (Engine.get_main_loop() as SceneTree).process_frame
