extends Control
## Prompt 3 — menu principal (cena inicial do projeto). Só UI do Godot.

const GAME_SCENE := "res://scenes/main.tscn"

var continue_button: Button
var buttons: Dictionary = {}
var _overlay: Control


func _ready() -> void:
	SaveSystem.load_settings()
	SaveSystem.apply_global()
	get_tree().paused = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.012, 0.016)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Vinheta: faixas escuras nas bordas.
	var glow := ColorRect.new()
	glow.color = Color(0.25, 0.03, 0.03, 0.06)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(glow)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 110)
	margin.add_theme_constant_override("margin_top", 120)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title := UIStyle.label("VARIÁVEL OCULTA", 56, Color(0.82, 0.8, 0.76))
	box.add_child(title)
	box.add_child(UIStyle.label("Não faça barulho.", 18, UIStyle.ACCENT))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 50)
	box.add_child(spacer)
	buttons["novo"] = UIStyle.button("Novo jogo", new_game)
	continue_button = UIStyle.button("Continuar", continue_game)
	buttons["continuar"] = continue_button
	buttons["apresentacao"] = UIStyle.button("Apresentação: ir para uma sala", open_presentation)
	buttons["config"] = UIStyle.button("Configurações", open_settings)
	buttons["creditos"] = UIStyle.button("Créditos", open_credits)
	buttons["sair"] = UIStyle.button("Sair", func(): get_tree().quit())
	for k in ["novo", "continuar", "apresentacao", "config", "creditos", "sair"]:
		box.add_child(buttons[k])
	continue_button.visible = SaveSystem.has_save()
	(buttons["continuar"] if continue_button.visible else buttons["novo"]).grab_focus.call_deferred()


func new_game() -> void:
	SaveSystem.pending_action = "new"
	get_tree().change_scene_to_file(GAME_SCENE)


func continue_game() -> void:
	if not SaveSystem.has_save():
		return
	SaveSystem.pending_action = "continue"
	get_tree().change_scene_to_file(GAME_SCENE)


## Versão 6.1 — começa na frente da porta de uma sala, com as anteriores já
## resolvidas (mesmos saves das cenas de scenes/apresentacao/).
func open_presentation() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var box := UIStyle.modal(_overlay, 520.0)
	box.add_child(UIStyle.label("APRESENTAÇÃO", 26))
	box.add_child(UIStyle.label("Começar na frente da porta de:", 17, UIStyle.DIM))
	for item in [["room_1", "1. Português (Leitora)"], ["room_2", "2. Matemática"], ["room_3", "3. Ciências"],
			["room_4", "4. Geografia"], ["room_5", "5. Música (Maestro)"], ["final", "6. Saída e final"]]:
		var nome: String = item[0]
		box.add_child(UIStyle.button(item[1], func(): ApresentacaoSala.ir_para(get_tree(), nome)))
	var ov := _overlay
	box.add_child(UIStyle.button("Voltar", func(): ov.queue_free()))


func open_settings() -> void:
	var p := SettingsPanel.new()
	add_child(p)


func open_credits() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var box := UIStyle.modal(_overlay, 520.0)
	box.add_child(UIStyle.label("CRÉDITOS", 26))
	box.add_child(UIStyle.label("Variável Oculta — versão jogável provisória.", 17))
	box.add_child(UIStyle.label("Créditos finais da equipe: a definir.", 17, UIStyle.DIM))
	box.add_child(UIStyle.label("Feito com Godot Engine 4.", 17, UIStyle.DIM))
	var ov := _overlay
	box.add_child(UIStyle.button("Voltar", func(): ov.queue_free()))
