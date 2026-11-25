class_name RoomVolume
extends Area3D
## Volume de detecção de sala (Etapa 5, Fase 2). Independente das zonas de
## câmera: só informa ao RoomProgressManager quando a protagonista começa
## ou deixa de sobrepor este volume. Não decide a sala atual (isso tem
## histerese no gerenciador) e não altera câmera, controles ou movimento.
## Só existe para salas com geometria; pontos de integração não têm volume.

@export var room_id: StringName


func _ready() -> void:
	add_to_group("room_volume")
	# Detecta a protagonista (camada 1) e não é detectável por nada:
	# raios de câmera, linha de visada e zonas não a enxergam.
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	if room_id == &"":
		push_error("%s: RoomVolume sem room_id." % get_path())
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var manager := get_tree().get_first_node_in_group("room_progress_manager")
		if manager != null:
			manager.notify_volume_entered(self)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		var manager := get_tree().get_first_node_in_group("room_progress_manager")
		if manager != null:
			manager.notify_volume_exited(self)
