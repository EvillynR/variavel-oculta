class_name GameHUD
extends CanvasLayer
## Prompt 3 — HUD mínima: objetivo atual (eventos narrativos com "objective"),
## estado da protagonista (agachada / escondida) e prompt de interação.

var objective: String = ""
var objective_label: Label
var status_label: Label
var prompt_label: Label
var player: Node
var interactor: Node


func _ready() -> void:
	layer = 10
	objective_label = UIStyle.label("", 18)
	objective_label.position = Vector2(28, 22)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(objective_label)
	status_label = UIStyle.label("", 18, Color(0.7, 0.85, 1.0))
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF   # com quebra automática saía uma letra por linha
	status_label.anchor_top = 1.0
	status_label.anchor_bottom = 1.0
	status_label.offset_left = 28
	status_label.offset_top = -60
	add_child(status_label)
	prompt_label = UIStyle.label("", 20)
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_top = 1.0
	prompt_label.anchor_bottom = 1.0
	prompt_label.offset_left = -200
	prompt_label.offset_right = 200
	prompt_label.offset_top = -210
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(prompt_label)
	player = get_tree().get_first_node_in_group("player")
	interactor = get_tree().get_first_node_in_group("player_interactor")
	var nm := get_tree().get_first_node_in_group("narrative_manager")
	if nm != null:
		nm.event_triggered.connect(func(e: NarrativeEvent): if e.objective != "": set_objective(e.objective))
	set_objective("")


func set_objective(text: String) -> void:
	objective = text
	objective_label.text = ("Objetivo: " + text) if text != "" else ""


func _process(_delta: float) -> void:
	var status := ""
	if player != null:
		if player.has_method("is_hidden") and player.is_hidden():
			status = "ESCONDIDA"
		elif player.get("is_crouching"):
			status = "AGACHADA"
	status_label.text = status
	# O prompt de interação é o rótulo no mundo, junto do objeto (o mesmo texto
	# repetido na HUD aparecia duplicado na tela).
	prompt_label.text = ""
