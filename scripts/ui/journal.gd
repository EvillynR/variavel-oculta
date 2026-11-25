class_name ClueJournal
extends CanvasLayer
## Prompt 3 — diário de pistas (ação "diario"): pistas descobertas no
## ClueManager, na ordem de descoberta, com o texto de cada uma.

var clue_manager: ClueManager
var _root: Control
var _list: VBoxContainer


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var box := UIStyle.modal(_root, 620.0, 0.7)
	box.add_child(UIStyle.label("DIÁRIO DE PISTAS", 26))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	scroll.add_child(_list)
	box.add_child(UIStyle.label("[J] fechar", 14, UIStyle.DIM))
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func toggle() -> void:
	_root.visible = not _root.visible
	if _root.visible:
		refresh()


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var clues: Array = clue_manager.get_discovered_clues() if clue_manager != null else []
	if clues.is_empty():
		_list.add_child(UIStyle.label("Nenhuma pista encontrada ainda.", 17, UIStyle.DIM))
	for clue in clues:
		_list.add_child(UIStyle.label(clue.title if clue.title != "" else String(clue.id), 20))
		_list.add_child(UIStyle.label(clue.content, 16, UIStyle.DIM))


## Títulos atualmente listados (testes).
func listed_titles() -> Array[String]:
	var out: Array[String] = []
	for c in _list.get_children():
		if c is Label and not c.is_queued_for_deletion():
			out.append(c.text)
	return out


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("diario") and not get_tree().paused:
		toggle()
		get_viewport().set_input_as_handled()
