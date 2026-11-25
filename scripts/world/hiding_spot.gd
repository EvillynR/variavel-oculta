class_name HidingSpot
extends Node3D
## Prompt 2 — esconderijo (armário alto ou embaixo da mesa do professor).
## A tecla E (Interactable + InteractionRouter já existentes) esconde a
## protagonista; dentro, E de novo a faz sair pela frente do móvel.
## Enquanto escondida, nenhum monstro a enxerga — exceto os que a VIRAM entrar
## (testemunhas, registradas pela protagonista no momento de se esconder).
## O móvel é a cena-mãe (scenes/props/armarioalto.tscn, mesaprofessor.tscn):
## frente para +Z local, chão em y = 0.

const HUD_NAME := "HidingHUD"

## Mesmo id do objeto em data/game_data.json (ex.: &"room_2.esconderijo_mesa").
@export var spot_id: StringName
## Onde a protagonista fica escondida (local).
@export var hide_offset: Vector3 = Vector3(0, 0.05, 0)
## Ponto de saída e alcance dos monstros (local, fora do móvel, navegável).
@export var front_offset: Vector3 = Vector3(0, 0.05, 1.15)
@export var label_text: String = "escondida"

var occupant: Node3D = null
var _interactable: Interactable
var _entered_frame: int = -100
var _marker: Label3D


func _ready() -> void:
	add_to_group("hiding_spot")
	if spot_id == &"":
		push_error("%s: spot_id vazio." % get_path())
		return
	_interactable = Interactable.new()
	_interactable.name = "Interactable"
	_interactable.interaction_id = spot_id
	_interactable.prompt_height = 1.6
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	shape.shape = sphere
	shape.position = Vector3(0, 0.9, 0)
	_interactable.add_child(shape)
	_interactable.position = front_offset - Vector3(0, front_offset.y, 0)
	add_child(_interactable)
	# Os móveis estão em escala Little Nightmares (3x): sem isto a área de
	# interação e o texto "E Esconder-se" também ficavam 3x maiores (o aviso
	# aparecia longe e enorme).
	var k := global_transform.basis.get_scale()
	var inv := Vector3(1.0 / maxf(k.x, 0.01), 1.0 / maxf(k.y, 0.01), 1.0 / maxf(k.z, 0.01))
	_interactable.scale = inv
	_interactable.interacted.connect(_on_interacted)
	_marker = Label3D.new()
	_marker.text = "[ %s ]" % label_text
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.font_size = 28
	_marker.modulate = Color(0.75, 0.9, 1.0, 0.9)
	_marker.position = Vector3(0, 2.7, 0)
	_marker.visible = false
	add_child(_marker)
	_marker.scale = inv
	_marker.position = Vector3(0, 2.7 * inv.y, 0)


func get_hide_position() -> Vector3:
	return to_global(hide_offset)


func get_front_position() -> Vector3:
	return to_global(front_offset)


func is_occupied() -> bool:
	return occupant != null


func _on_interacted(_it: Interactable, actor: Node3D) -> void:
	if occupant == null and actor != null and actor.has_method("enter_hiding"):
		enter(actor)


func enter(actor: Node3D) -> void:
	occupant = actor
	_entered_frame = Engine.get_process_frames()
	actor.enter_hiding(self)
	_interactable.set_enabled(false)
	_marker.visible = true
	_set_hud(true)


func leave() -> void:
	if occupant == null:
		return
	var actor := occupant
	occupant = null
	actor.leave_hiding()
	_interactable.set_enabled(true)
	_marker.visible = false
	_set_hud(false)


func _process(_delta: float) -> void:
	# Dentro do esconderijo a protagonista não tem colisão e sai da área do
	# Interactable; a saída é lida aqui (E de novo), nunca no mesmo quadro da entrada.
	if occupant != null and Engine.get_process_frames() > _entered_frame + 1 and Input.is_action_just_pressed("interact"):
		leave()


func _set_hud(on: bool) -> void:
	# A HUD fica na cena principal (o ancestral logo abaixo da raiz da árvore).
	var scene: Node = self
	while scene.get_parent() != null and scene.get_parent() != get_tree().root:
		scene = scene.get_parent()
	var hud := scene.get_node_or_null(HUD_NAME) as CanvasLayer
	if hud == null:
		hud = CanvasLayer.new()
		hud.name = HUD_NAME
		hud.layer = 15
		var shade := ColorRect.new()
		shade.name = "Vinheta"
		shade.color = Color(0.0, 0.02, 0.05, 0.42)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hud.add_child(shade)
		var label := Label.new()
		label.name = "Texto"
		label.text = "ESCONDIDA  —  E para sair"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24)
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		label.offset_top = -80.0
		label.offset_left = -300.0
		label.offset_right = 300.0
		hud.add_child(label)
		scene.add_child(hud)
	hud.visible = on
