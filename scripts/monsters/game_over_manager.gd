extends CanvasLayer
## Captura global dos monstros. UI simples e funcional sem depender de arte final.

var _panel: PanelContainer
var _shade: ColorRect
var _message: Label
var _player: Node3D
var _checkpoint: Transform3D
var _locked := false
## Versão 6.2: antes da tela, a Yuko morre na frente da câmera (s, no máximo).
@export var death_time: float = 2.2
## true enquanto a animação da morte toca (antes da tela aparecer).
var dying := false

func _ready() -> void:
	add_to_group("game_over_ui")
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.hide()
	_shade.hide()
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player != null:
		_checkpoint = _player.global_transform
	_connect_monsters.call_deferred()

func _connect_monsters() -> void:
	for node in get_tree().get_nodes_in_group("monster"):
		if node is MonsterController and not node.player_caught.is_connected(_on_player_caught.bind(node)):
			node.player_caught.connect(_on_player_caught.bind(node))

func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.0, 0.0, 0.0, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade = shade
	add_child(shade)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-220, -130)
	_panel.custom_minimum_size = Vector2(440, 260)
	shade.add_child(_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	_panel.add_child(box)
	_message = Label.new()
	_message.text = "VOCÊ FOI ENCONTRADA"
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_message)
	# Prompt 3: o checkpoint é restaurado de verdade (GameSession + user://).
	var retry := UIStyle.button("Tentar do checkpoint", _retry)
	retry.name = "TentarDoCheckpoint"
	box.add_child(retry)
	var menu := UIStyle.button("Menu principal", _to_menu)
	menu.name = "MenuPrincipal"
	box.add_child(menu)

func _on_player_caught(monster: Node = null) -> void:
	if _locked:
		return
	_locked = true
	get_tree().paused = true
	# Versão 6.2.1: o Maestro só faz a Yuko levitar; quando ela perde, a tela de
	# game over (checkpoint) aparece direto, com ela ainda no ar (sem a morte).
	var levitou: bool = monster is MonsterController and (monster as MonsterController).levitate_catch
	var yuko := _yuko()
	if yuko != null and death_time > 0.0 and not levitou:
		dying = true
		var length := yuko.die()
		var wait := clampf(length + 0.4, 0.8, death_time)
		var t := 0.0
		while t < wait and is_inside_tree() and dying:
			await get_tree().process_frame
			t += get_process_delta_time() if get_process_delta_time() > 0.0 else 1.0 / 60.0
		if not dying:
			return
		dying = false
	_shade.show()
	_panel.show()
	var retry := _panel.find_child("TentarDoCheckpoint", true, false) as Button
	if retry != null:
		retry.grab_focus()

func is_open() -> bool:
	return _panel.visible


func _yuko() -> YukoAnimator:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		return null
	for c in _player.find_children("*", "Node3D", true, false):
		if c is YukoAnimator:
			return c
	return null


## Fecha a tela sem trocar de cena (testes que seguem depois da captura).
func dismiss() -> void:
	dying = false
	var yuko := _yuko()
	if yuko != null:
		yuko.revive()
	if _player != null and _player.has_method("set_levitation"):
		_player.set_levitation(0.0)
	_locked = false
	_shade.hide()
	_panel.hide()
	get_tree().paused = false


func _retry() -> void:
	var session := get_tree().get_first_node_in_group("game_session")
	dismiss()
	if session != null:
		session.restore_last_checkpoint()
	else:
		get_tree().reload_current_scene()


func _to_menu() -> void:
	var session := get_tree().get_first_node_in_group("game_session")
	dismiss()
	if session != null:
		session.go_to_main_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
