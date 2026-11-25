extends Area3D
## Zona que troca o perfil da câmera enquanto a protagonista está dentro dela.
## A zona de maior camera_priority vence quando várias se sobrepõem.

@export var camera_priority: int = 0
@export var camera_offset: Vector3 = Vector3(8.0, 2.6, 0.0)
@export var camera_fov: float = 32.0
@export var blend_speed: float = 2.5

@export_group("Limites em Z")
@export var use_z_limits: bool = true
@export var minimum_camera_z: float = 0.0
@export var maximum_camera_z: float = 0.0

@export_group("Limites em X")
## Desligado por padrão: as zonas que já existem continuam iguais.
@export var use_x_limits: bool = false
@export var minimum_camera_x: float = 0.0
@export var maximum_camera_x: float = 0.0

@export_group("Palco (câmera fixa)")
## AUTO: caixa funda (> 8 m no eixo da visão) = cômodo; rasa = corredor.
## ROOM: a câmera fica presa dentro do cômodo (não mostra o lado de fora).
## CORRIDOR: a câmera corre livre ao longo do corredor.
enum StageMode { AUTO, ROOM, CORRIDOR }
@export var stage_mode: StageMode = StageMode.AUTO
## Folga (m) além das paredes laterais que ainda pode aparecer no quadro.
@export var stage_side_margin: float = 0.4

@export_group("Corte de maquete")
## Paredes/objetos entre a câmera e a protagonista que devem sumir da imagem
## enquanto esta zona estiver ativa (continuam com colisão e sombra).
@export var occluder_paths: Array[NodePath] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func get_occluding_geometry() -> Array[GeometryInstance3D]:
	var result: Array[GeometryInstance3D] = []

	for path in occluder_paths:
		var node := get_node_or_null(path)
		if node is GeometryInstance3D:
			result.append(node)
		else:
			push_warning("%s: occluder inválido ou ausente: %s" % [name, path])

	return result


## Caixa global da zona (usada como "palco" pela câmera fixa).
func get_stage_box() -> AABB:
	for c in get_children():
		if c is CollisionShape3D and c.shape is BoxShape3D:
			var size: Vector3 = (c.shape as BoxShape3D).size
			return (c as Node3D).global_transform * AABB(-size * 0.5, size)
	return AABB(global_position - Vector3.ONE, Vector3.ONE * 2.0)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	var controller = get_tree().get_first_node_in_group("camera_controller")
	if controller != null:
		controller.register_zone(self)


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	var controller = get_tree().get_first_node_in_group("camera_controller")
	if controller != null:
		controller.unregister_zone(self)
