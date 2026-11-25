class_name PauseMenu
extends CanvasLayer
## Prompt 3 — pausa (ação "pause", Esc). Pausa de verdade a árvore; ao sair,
## devolve o estado anterior (a UI de enigmas já pausa sozinha e convive).

var session: Node
var buttons: Dictionary = {}
var _root: Control
var _prev_paused := false


func _ready() -> void:
	add_to_group("pause_menu")
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var box := UIStyle.modal(_root, 420.0, 0.7)
	box.add_child(UIStyle.label("PAUSA", 30))
	buttons["continuar"] = UIStyle.button("Continuar", close)
	buttons["config"] = UIStyle.button("Configurações", _open_settings)
	buttons["checkpoint"] = UIStyle.button("Voltar ao último checkpoint", func(): session.restore_last_checkpoint())
	buttons["menu"] = UIStyle.button("Menu principal", func(): session.go_to_main_menu())
	for k in ["continuar", "config", "checkpoint", "menu"]:
		box.add_child(buttons[k])
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open() -> void:
	if is_open():
		return
	_prev_paused = get_tree().paused
	get_tree().paused = true
	(buttons["checkpoint"] as Button).disabled = not SaveSystem.has_save()
	_root.visible = true
	(buttons["continuar"] as Button).grab_focus()


func close() -> void:
	if not is_open():
		return
	for c in _root.get_children():
		if c is SettingsPanel:
			c.queue_free()
	_root.visible = false
	get_tree().paused = _prev_paused


func _open_settings() -> void:
	var p := SettingsPanel.new()
	_root.add_child(p)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if is_open():
		for c in _root.get_children():
			if c is SettingsPanel:
				c.close()
				get_viewport().set_input_as_handled()
				return
		close()
		get_viewport().set_input_as_handled()
	elif session != null and session.can_pause():
		open()
		get_viewport().set_input_as_handled()
