extends SceneTree
## Teste headless: teleporta a protagonista por pontos de cada área,
## posiciona a câmera e verifica se alguma geometria VISÍVEL bloqueia a visão.
## Uso: godot --headless --path <projeto> --script res://tests/camera_occlusion_test.gd

const AREAS := {
	"Corridor": [Vector3(-2.5, 0, -27.0), Vector3(2.5, 0, -5.0)],
	"Room 1": [Vector3(-22.5, 0, -29.0), Vector3(-4.5, 0, -8.5)],
	"Room 2": [Vector3(-22.5, 0, -57.5), Vector3(-4.5, 0, -38.5)],
	"Pátio": [Vector3(-22.0, 0, -82.0), Vector3(-5.0, 0, -60.0)],
	"Room 3": [Vector3(-22.5, 0, -115.0), Vector3(-4.5, 0, -93.5)],
	"Room 4": [Vector3(-22.5, 0, -137.0), Vector3(-4.5, 0, -118.0)],
	# Prompt 2: áreas criadas no Prompt 1, agora mobiliadas.
	"Música": [Vector3(-22.5, 0, -184.0), Vector3(-4.5, 0, -166.0)],
	"Corredor 5": [Vector3(-2.5, 0, -188.0), Vector3(2.5, 0, -140.0)],
	# Versão 5: a salinha virou a sala dos monitores, no fim do corredor.
	"Sala dos monitores": [Vector3(-1.5, 0, -196.5), Vector3(4.5, 0, -191.5)],
}

var failures := 0

func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	preload("res://tests/test_input.gd").open_all_doors(self)  # Prompt 1: portas físicas
	await _frames(5)

	var player: CharacterBody3D = main.get_node("Player")
	var controller: Node3D = main.get_node("CameraController")
	var camera: Camera3D = controller.get_node("Camera3D")
	player.can_move = false

	for area_name in AREAS:
		var a: Vector3 = AREAS[area_name][0]
		var b: Vector3 = AREAS[area_name][1]
		var blocked := {}
		var samples := 0
		for ix in 4:
			for iz in 5:
				var p := Vector3(lerpf(a.x, b.x, ix / 3.0), 0.05, lerpf(a.z, b.z, iz / 4.0))
				player.global_position = p
				player.velocity = Vector3.ZERO
				await _frames(3)
				controller.snap_to_target()
				samples += 1
				# Prompt 2: com móveis, um ponto da grade pode cair dentro de um
				# deles e a física empurra a protagonista para fora; o que importa é
				# a visão até onde ela REALMENTE está.
				var actual := player.global_position
				for target_h in [0.4, 1.0]:
					for hit in _blockers(main, camera.global_position, actual + Vector3(0, target_h, 0), player):
						blocked[hit] = blocked.get(hit, 0) + 1
				_check_camera(camera, area_name, p)
		var zone_name: String = controller.current_zone.name if controller.current_zone else "(padrão)"
		if blocked.is_empty():
			print("OK    %-12s zona=%-18s amostras=%d" % [area_name, zone_name, samples])
		else:
			failures += 1
			print("FALHA %-12s zona=%-18s bloqueios: %s" % [area_name, zone_name, blocked])

	print("RESULTADO: %s" % ("SEM BLOQUEIOS" if failures == 0 else "%d áreas com bloqueio" % failures))
	quit(1 if failures > 0 else 0)


func _blockers(main: Node, from: Vector3, to: Vector3, player: CharacterBody3D) -> Array:
	var space := player.get_world_3d().direct_space_state
	var exclude: Array[RID] = [player.get_rid()]
	var found := []
	for i in 12:
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.collision_mask = 1  # camada 1 = cenário; monstros (camada 3) se movem e não são oclusão de nível
		q.exclude = exclude
		var r := space.intersect_ray(q)
		if r.is_empty():
			break
		var c: Object = preload("res://tests/test_input.gd").fade_target(r.collider)
		exclude.append(r.rid)
		var visible_geo := true
		# Móveis no grupo camera_ignore (ex.: armário) podem ficar à frente dos
		# pés por instantes; não são oclusão de nível (Etapa 4.5).
		if c is Node and c.is_in_group("camera_ignore"):
			visible_geo = false
		# Prompt 2: móvel na frente da protagonista só é aceito se a câmera
		# realmente o deixou translúcido (fade) — não é uma isenção geral.
		elif c is GeometryInstance3D and c.is_in_group("camera_fade") and c.transparency >= 0.5:
			visible_geo = false
		elif c is Node3D and not (c is GeometryInstance3D) and c.is_in_group("camera_fade"):
			visible_geo = (c as Node).find_children("*", "GeometryInstance3D", true, false).any(func(g): return g.transparency < 0.5)
		elif c is GeometryInstance3D:
			visible_geo = c.is_visible_in_tree() and c.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and c.layers != (1 << 19)
		if visible_geo:
			found.append(str(main.get_path_to(c)) if c is Node else str(c))
	return found


func _check_camera(camera: Camera3D, area: String, p: Vector3) -> void:
	var t := camera.global_transform
	if not t.origin.is_finite() or not t.basis.is_finite() or camera.fov < 10.0:
		failures += 1
		print("FALHA %s: câmera inválida em %s (fov %.1f)" % [area, p, camera.fov])


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
