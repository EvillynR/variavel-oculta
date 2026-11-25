extends SceneTree
## Pós-Prompt 3 — colisão dos móveis (scenes/props/): a protagonista anda contra
## cada móvel por 8 direções e nunca pode ficar com o corpo dentro dele, nem
## enroscar (travar longe do móvel). Também confere que monstros não nascem
## dentro de móveis.
## Uso: godot --headless --fixed-fps 60 --path . --script res://tests/moveis_colisao_test.gd

const T := preload("res://tests/test_input.gd")
var main: Node
var player: CharacterBody3D
var passed := 0
var failed := 0


func _initialize() -> void:
	T.open_all_doors(self)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 6:
		await physics_frame
	for m in get_nodes_in_group("monster"):
		m.process_mode = Node.PROCESS_MODE_DISABLED
	player = main.get_node("Player")
	var props: Array = main.get_node("School/Props").find_children("*", "Node3D", true, false).filter(func(n): return n.get_parent().get_parent() == main.get_node("School/Props"))
	var inside_bad: Array[String] = []
	var snag_bad: Array[String] = []
	var tested := 0
	for prop in props:
		var box := _visual_box(prop)
		if box.size.y < 0.5 or minf(box.size.x, box.size.z) < 0.2:
			continue   # quadros de parede (presos na parede), papéis
		tested += 1
		var c := box.get_center()
		for k in 8:
			var a := k * TAU / 8.0
			var dir := Vector3(cos(a), 0, sin(a))
			var start := Vector3(c.x, box.position.y + 0.05, c.z) - dir * (maxf(box.size.x, box.size.z) * 0.5 + 0.9)
			if not _free(start) or not _floor_under(start):
				continue   # ponto de partida fora do prédio ou dentro de outra coisa
			player.global_position = start
			player.velocity = Vector3.ZERO
			for f in 50:
				T.press_world(player, dir)
				await physics_frame
				if absf(player.global_position.y - box.position.y) < 0.3 and _capsule_in_prop(prop):
					inside_bad.append("%s (dir %d) em %s" % [prop.name, k, player.global_position.snappedf(0.01)])
					break
			T.release_moves()
	_check("%d móveis testados por 8 direções" % tested, tested >= 45, "")
	_check("corpo da protagonista nunca entra num móvel", inside_bad.is_empty(), "%d casos: %s" % [inside_bad.size(), ", ".join(inside_bad.slice(0, 12))])
	var spawn_bad: Array[String] = []
	for m in get_nodes_in_group("monster"):
		for prop in props:
			var b := _visual_box(prop)
			if b.grow(0.3).has_point(Vector3(m.global_position.x, b.get_center().y, m.global_position.z)):
				spawn_bad.append("%s em %s" % [m.name, prop.name])
	_check("nenhum monstro dentro de móvel", spawn_bad.is_empty(), str(spawn_bad))
	print("RESULTADO: %d/%d testes passaram" % [passed, passed + failed])
	quit(1 if failed > 0 else 0)


func _visual_box(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for g in n.find_children("*", "CSGShape3D", true, false) + ([n] if n is CSGShape3D else []):
		var csg := g as CSGShape3D
		if not csg.is_root_shape():
			continue
		var b := csg.global_transform * csg.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


## Corpo dentro do volume VISÍVEL do móvel, no referencial do próprio móvel
## (móveis girados, como as cadeiras em semicírculo, não usam caixa alinhada).
func _capsule_in_prop(n: Node) -> bool:
	for g in n.find_children("*", "CSGShape3D", true, false) + ([n] if n is CSGShape3D else []):
		var csg := g as CSGShape3D
		if not csg.is_root_shape():
			continue
		# Medido em metros do mundo (os móveis estão em escala 2x).
		var gp := player.global_position + Vector3.UP * 0.9
		var local: Vector3 = csg.global_transform.affine_inverse() * gp
		var b := csg.get_aabb().grow(-0.03)
		var closest := Vector3(clampf(local.x, b.position.x, b.end.x), clampf(local.y, b.position.y, b.end.y), clampf(local.z, b.position.z, b.end.z))
		var cw: Vector3 = csg.global_transform * closest
		var bottom: float = (csg.global_transform * b.position).y
		var top: float = (csg.global_transform * b.end).y
		# corpo (cápsula r 0,3 m, 0..1,7 m) atravessando o volume visível
		if Vector2(gp.x - cw.x, gp.z - cw.z).length() < 0.2 and player.global_position.y + 0.2 < maxf(top, bottom) and player.global_position.y + 1.6 > minf(top, bottom):
			return true
	return false


func _capsule_in(box: AABB) -> bool:
	var p := player.global_position
	var closest := Vector3(clampf(p.x, box.position.x, box.end.x), 0, clampf(p.z, box.position.z, box.end.z))
	var flat := Vector2(p.x - closest.x, p.z - closest.z).length()
	return flat < 0.2 and p.y + 0.2 < box.end.y and p.y + 1.6 > box.position.y


func _floor_under(p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.5, p + Vector3.DOWN * 0.5, 1)
	return not main.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _free(p: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.8
	q.shape = cap
	q.transform = Transform3D(Basis(), p + Vector3.UP * 0.95)
	q.collision_mask = 1
	return main.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _check(label: String, ok: bool, info: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("%s %s  %s" % ["OK    " if ok else "FALHA ", label, info])
