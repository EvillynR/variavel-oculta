extends SceneTree
## Varredura headless da câmera contra a geometria do cenário.
## Para cada área, coloca a protagonista numa grade de pontos e, em cada ponto,
## força os piores casos de acompanhamento (zona morta para os dois lados,
## antecipação de corrida e tensão de perseguição 0 e 1). Verifica:
##   A) câmera dentro de geometria visível (caixa CSG / corpo estático);
##   B) geometria visível a menos de 0,25 m da lente (enche a tela);
##   C) geometria visível entre a lente e a protagonista (peito e cabeça).
## Objetos de cena no grupo "camera_ignore" (ex.: armário) não empurram a câmera;
## quando ficam na frente são contados à parte ("objeto à frente"), sem falha.
## Pontos onde a protagonista não cabe (dentro de móveis) são pulados.
## Uso: godot --headless --path . --script res://tests/legado_orbita/camera_geometry_sweep_test.gd

const AREAS := {
	"InitialRoom": [Vector3(-5.5, 0, -3.5), Vector3(4.5, 0, 3.5)],
	"Corridor": [Vector3(-3.0, 0, -28.0), Vector3(2.5, 0, -4.5)],
	"Corridor2": [Vector3(-3.0, 0, -52.0), Vector3(2.5, 0, -29.0)],
	"Room 1": [Vector3(-23.0, 0, -29.5), Vector3(-4.0, 0, -8.0)],
	"Room 2": [Vector3(-23.0, 0, -58.0), Vector3(-4.0, 0, -38.0)],
	"Exit": [Vector3(-23.0, 0, -83.0), Vector3(-4.0, 0, -59.0)],
	"ExitCorridor": [Vector3(-3.0, 0, -89.0), Vector3(2.5, 0, -53.5)],
	"Room 3": [Vector3(-23.0, 0, -115.5), Vector3(-4.0, 0, -93.0)],
	"Corridor3": [Vector3(-3.0, 0, -113.5), Vector3(2.5, 0, -90.0)],
	"Room 4": [Vector3(-23.0, 0, -137.5), Vector3(-4.0, 0, -117.5)],
	"Corridor4": [Vector3(-3.0, 0, -137.5), Vector3(2.5, 0, -114.5)],
}

var main: Node
var player: CharacterBody3D
var controller: Node3D
var camera: Camera3D
var boxes: Array = []   # [CSGShape3D/MeshInstance3D, AABB global]
var total_fail := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	preload("res://tests/test_input.gd").open_all_doors(self)  # Prompt 1: portas físicas
	preload("res://tests/test_input.gd").use_orbit_camera(self)  # mede o estilo de órbita (opcional)
	await _physics(5)
	player = main.get_node("Player")
	controller = main.get_node("CameraController")
	camera = controller.get_node("Camera3D")
	player.can_move = false
	for g in main.find_children("*", "CSGBox3D", true, false):
		boxes.append([g, g.global_transform * AABB(-g.size / 2.0, g.size)])

	for area in AREAS:
		var a: Vector3 = AREAS[area][0]
		var b: Vector3 = AREAS[area][1]
		var fails := {"A_dentro": 0, "B_rente": 0, "C_oclusao": 0}
		var prop_occlusion := 0
		var skipped := 0
		var examples := {}
		var samples := 0
		var min_dist := INF
		for ix in 5:
			for iz in 7:
				var p := Vector3(lerpf(a.x, b.x, ix / 4.0), 0.05, lerpf(a.z, b.z, iz / 6.0))
				if not _reachable(p):
					skipped += 1
					continue
				player.global_position = p
				player.velocity = Vector3.ZERO
				await _physics(2)
				for dz in [-2.0, 0.0, 2.0]:
					for vz in [-6.0, 0.0, 6.0]:
						for tension in [0.0, 1.0]:
							_pose(p, dz, vz, tension)
							samples += 1
							var cam := camera.global_position
							min_dist = minf(min_dist, cam.distance_to(p + Vector3.UP * 1.2))
							var inside := _inside_visible_box(cam)
							if inside != "":
								fails["A_dentro"] += 1
								examples["A_dentro"] = "%s cam=%s em %s" % [p, cam.snapped(Vector3.ONE * 0.01), inside]
							var near := _visible_near(cam, 0.25)
							if near != "" and inside == "":
								fails["B_rente"] += 1
								examples["B_rente"] = "%s cam=%s rente a %s" % [p, cam.snapped(Vector3.ONE * 0.01), near]
							var occ := _occluder(cam, p)
							if occ.begins_with("PROP:"):
								prop_occlusion += 1
							elif occ != "":
								fails["C_oclusao"] += 1
								examples["C_oclusao"] = "%s cam=%s atrás de %s" % [p, cam.snapped(Vector3.ONE * 0.01), occ]
		var bad := 0
		for k in fails:
			bad += fails[k]
		total_fail += bad
		var zone: String = controller.current_zone.name if controller.current_zone else "(padrão)"
		print("%s %-12s zona=%-18s amostras=%d dist.mín=%.2f m  dentro=%d rente=%d oclusão=%d | objeto à frente=%d pontos inalcançáveis=%d" % [
			"OK   " if bad == 0 else "FALHA", area, zone, samples, min_dist, fails["A_dentro"], fails["B_rente"], fails["C_oclusao"], prop_occlusion, skipped])
		for k in examples:
			print("        ex. %s: %s" % [k, examples[k]])
	print("RESULTADO: %s" % ("SEM PROBLEMAS" if total_fail == 0 else "%d amostras com problema" % total_fail))
	quit(1 if total_fail > 0 else 0)


## Coloca a câmera no estado estável para um caso de acompanhamento.
func _pose(p: Vector3, dz: float, vz: float, tension: float) -> void:
	controller.snap_to_target()
	controller.set_tension(tension)
	controller.set("_tension", tension)
	controller.camera_track_z = p.z + dz
	player.velocity = Vector3(0, 0, vz)
	for i in 4:
		controller._process(2.0)
	player.velocity = Vector3.ZERO


## Ponto onde a cápsula da protagonista (r 0,25, 1,8 m) cabe sem tocar em nada.
func _reachable(p: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.25
	shape.height = 1.8
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), p + Vector3.UP * 0.95)
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	return camera.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _is_visible_geo(n: Object) -> bool:
	if n is GeometryInstance3D:
		return n.is_visible_in_tree() and n.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	if n is CharacterBody3D:
		return false
	return n is Node3D and n.is_visible_in_tree()


func _inside_visible_box(pos: Vector3) -> String:
	for entry in boxes:
		if _is_visible_geo(entry[0]) and entry[1].grow(0.05).has_point(pos):
			return str(main.get_path_to(entry[0]))
	return ""


func _visible_near(pos: Vector3, radius: float) -> String:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), pos)
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	for hit in camera.get_world_3d().direct_space_state.intersect_shape(q, 8):
		if _is_visible_geo(hit.collider):
			return str(main.get_path_to(hit.collider))
	# Geometria sem colisão (ex.: vergas de porta) também enche a tela.
	for entry in boxes:
		if _is_visible_geo(entry[0]) and not entry[0].use_collision and not entry[0].is_in_group("camera_fade") and entry[1].grow(radius).has_point(pos):
			return str(main.get_path_to(entry[0]))
	return ""


func _occluder(cam: Vector3, p: Vector3) -> String:
	var space := camera.get_world_3d().direct_space_state
	for h in [1.0, 1.6]:
		var exclude: Array[RID] = [player.get_rid()]
		for i in 10:
			var q := PhysicsRayQueryParameters3D.create(cam, p + Vector3.UP * h, 1, exclude)
			var r := space.intersect_ray(q)
			if r.is_empty():
				break
			if r.collider is Node and r.collider.is_in_group("camera_ignore"):
				return "PROP:" + str(main.get_path_to(r.collider))
			# Prompt 2: móvel só é aceito à frente se estiver de fato translúcido (fade).
			var fc: Object = preload("res://tests/test_input.gd").fade_target(r.collider)
			if fc is GeometryInstance3D and fc.is_in_group("camera_fade") and fc.transparency >= 0.5:
				exclude.append(r.rid)
				continue
			if _is_visible_geo(r.collider):
				return str(main.get_path_to(r.collider))
			exclude.append(r.rid)
	return ""


func _physics(n: int) -> void:
	for i in n:
		await physics_frame
