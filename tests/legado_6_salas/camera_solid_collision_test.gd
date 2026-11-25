extends SceneTree
## Prioridade 1 — colisão obrigatória da câmera e rotação pelas setas.
## Diferente dos testes antigos, aqui QUALQUER geometria conta: paredes visíveis,
## invisíveis e escondidas pelo corte de maquete, chão, teto, móveis (inclusive
## o armário) e peças visíveis sem colisão (vergas das portas).
## Verifica em todas as áreas do mapa:
##   A) lente dentro de geometria;  B) lente a menos de 0,1 m de geometria;
##   C) geometria entre a lente e a protagonista (peito e cabeça);
##   D) protagonista fora do quadro;  E) câmera inválida (NaN, FOV fora da faixa).
## E também: rotação pelas setas, recusa sem espaço, percursos andando (saltos,
## troca de lado) e retorno suave.
## Uso: godot --headless --fixed-fps 60 -s tests/camera_solid_collision_test.gd

const AREAS := {
	"InitialRoom": [Vector3(-5.5, 0, -3.5), Vector3(4.5, 0, 3.5)],
	"Corridor": [Vector3(-3.0, 0, -28.0), Vector3(2.5, 0, -4.5)],
	"Corridor2": [Vector3(-3.0, 0, -52.0), Vector3(2.5, 0, -29.0)],
	"Room 1": [Vector3(-23.0, 0, -29.5), Vector3(-4.0, 0, -8.0)],
	"Room 2": [Vector3(-23.0, 0, -58.0), Vector3(-4.0, 0, -38.0)],
	"Exit(Artes)": [Vector3(-23.0, 0, -83.0), Vector3(-4.0, 0, -59.0)],
	"ExitCorridor": [Vector3(-3.0, 0, -89.0), Vector3(2.5, 0, -53.5)],
	"Room 3": [Vector3(-23.0, 0, -115.5), Vector3(-4.0, 0, -93.0)],
	"Corridor3": [Vector3(-3.0, 0, -113.5), Vector3(2.5, 0, -90.0)],
	"Room 4": [Vector3(-23.0, 0, -137.5), Vector3(-4.0, 0, -117.5)],
	"Corridor4": [Vector3(-3.0, 0, -137.5), Vector3(2.5, 0, -114.5)],
}

var results := []
var main: Node
var player: CharacterBody3D
var controller: Node3D
var camera: Camera3D
var visual_boxes: Array[AABB] = []


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	preload("res://tests/test_input.gd").open_all_doors(self)  # Prompt 1: portas físicas
	preload("res://tests/test_input.gd").use_orbit_camera(self)  # mede o estilo de órbita (opcional)
	player = main.get_node("Player")
	controller = main.get_node("CameraController")
	camera = controller.get_node("Camera3D")
	await _phys(6)
	for n in main.find_children("*", "CSGShape3D", true, false):
		var c := n as CSGShape3D
		# Prompt 2: peças-filhas de um CSGCombiner (móveis) não são geometria
		# própria — a forma raiz, com colisão, é que conta (igual à câmera).
		# Pós-Prompt 3: móveis têm colisão em caixa à parte (StaticBody) — não são "peça sem colisão".
		if not c.use_collision and c.is_visible_in_tree() and c.is_root_shape() and not c.is_in_group("camera_fade"):
			visual_boxes.append(c.global_transform * c.get_aabb())

	await _sweep()
	await _orbit_tests()
	await _walk_tests()

	var ok := results.filter(func(r): return r).size()
	print("RESULTADO: %d/%d testes passaram" % [ok, results.size()])
	quit(0 if ok == results.size() else 1)


# ------------------------------------------------------------ varredura

func _sweep() -> void:
	print("--- varredura estática (todas as áreas, tensão 0 e 1)")
	player.can_move = false
	for area in AREAS:
		var a: Vector3 = AREAS[area][0]
		var b: Vector3 = AREAS[area][1]
		var fails := {"A": 0, "B": 0, "C": 0, "D": 0, "E": 0}
		var example := ""
		var samples := 0
		var min_d := INF
		var sum_d := 0.0
		for ix in 5:
			for iz in 6:
				var p := Vector3(lerpf(a.x, b.x, ix / 4.0), 0.05, lerpf(a.z, b.z, iz / 5.0))
				if not _reachable(p):
					continue
				for tension in [0.0, 1.0]:
					player.global_position = p
					player.velocity = Vector3.ZERO
					controller.set_tension(tension)
					controller.set("_tension", tension)
					await _phys(2)
					controller.snap_to_target()
					for i in 3:
						controller._process(1.0 / 60.0)
					samples += 1
					var r: Dictionary = _inspect(p)
					for k in r:
						if r[k] != "":
							fails[k] += 1
							example = "%s %s em p=%s cam=%s" % [k, r[k], p.snapped(Vector3.ONE * 0.1), camera.global_position.snapped(Vector3.ONE * 0.01)]
					var d := camera.global_position.distance_to(p + Vector3.UP * 1.2)
					min_d = minf(min_d, d)
					sum_d += d
		controller.set_tension(0.0)
		controller.set("_tension", 0.0)
		var bad := 0
		for k in fails:
			bad += fails[k]
		_check("%-13s amostras=%d dist média %.1f m, mín %.1f m" % [area, samples, sum_d / maxf(samples, 1), min_d], bad == 0,
			"" if bad == 0 else "A=%d B=%d C=%d D=%d E=%d | ex. %s" % [fails.A, fails.B, fails.C, fails.D, fails.E, example])
	player.can_move = true


## A..E para o quadro atual. Vazio = ok.
func _inspect(p: Vector3) -> Dictionary:
	var cam := camera.global_position
	var r := {"A": "", "B": "", "C": "", "D": "", "E": ""}
	if not cam.is_finite() or not camera.global_basis.is_finite() or camera.fov < 10.0 or camera.fov > 75.0:
		r.E = "câmera inválida fov=%.1f" % camera.fov
		return r
	r.A = _solid_at(cam, 0.02)
	if r.A == "":
		r.B = _solid_at(cam, 0.1)
	for h in [1.2, 1.7]:
		var o: String = _blocker(cam, p + Vector3.UP * float(h))
		if o != "":
			r.C = o
			break
	# O corpo inteiro (1,8 m) só cabe no quadro a partir de ~2 m da lente; mais perto
	# (espaços apertados) exige-se o tronco e a cabeça.
	var heights := [0.1, 1.0, 1.7] if cam.distance_to(p + Vector3.UP * 1.0) >= 2.0 else [1.0, 1.5]
	for h in heights:
		var w: Vector3 = p + Vector3.UP * float(h)
		if camera.is_position_behind(w) or not root.get_visible_rect().has_point(camera.unproject_position(w)):
			r.D = "ponto %.1f m fora do quadro (dist %.2f m, fov %.0f)" % [h, cam.distance_to(p + Vector3.UP * 1.0), camera.fov]
			break
	return r


func _solid_at(pos: Vector3, radius: float) -> String:
	var s := SphereShape3D.new()
	s.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = s
	q.transform = Transform3D(Basis(), pos)
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	for hit in player.get_world_3d().direct_space_state.intersect_shape(q, 8):
		if hit.collider is CharacterBody3D or hit.collider is RigidBody3D:
			continue
		return str(main.get_path_to(hit.collider))
	for box in visual_boxes:
		if box.grow(radius).has_point(pos):
			return "verga/peça sem colisão"
	return ""


func _blocker(from: Vector3, to: Vector3) -> String:
	var space := player.get_world_3d().direct_space_state
	var exclude: Array[RID] = [player.get_rid()]
	for i in 6:
		var q := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		if hit.collider is CharacterBody3D or hit.collider is RigidBody3D:
			exclude.append(hit.rid)
			continue
		# Prompt 2: móvel entre a lente e a protagonista só é aceito se a
		# câmera de fato o deixou translúcido (fade) — paredes continuam proibidas.
		var fc: Object = preload("res://tests/test_input.gd").fade_target(hit.collider)
		if fc is GeometryInstance3D and fc.is_in_group("camera_fade") and fc.transparency >= 0.5:
			exclude.append(hit.rid)
			continue
		return str(main.get_path_to(hit.collider))
	for box in visual_boxes:
		if box.intersects_segment(from, to):
			return "verga/peça sem colisão"
	return ""


func _reachable(p: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.26
	shape.height = 1.8
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), p + Vector3.UP * 0.95)
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


# ------------------------------------------------------------ setas

func _orbit_tests() -> void:
	print("--- rotação pelas setas")
	for a in ["camera_rotate_left", "camera_rotate_right", "camera_rotate_up", "camera_rotate_down"]:
		_check("ação %s existe e está nas setas" % a, InputMap.has_action(a) and _is_arrow(a), "")
	for a in ["move_forward", "move_back", "move_left", "move_right", "run", "crouch", "interact"]:
		var conflict := false
		for e in InputMap.action_get_events(a):
			if e is InputEventKey and (e as InputEventKey).physical_keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
				conflict = true
		_check("sem conflito: %s não usa as setas" % a, not conflict, "")

	# Centro da Room 1: espaço amplo.
	await _place(Vector3(-11, 0.05, -18.7))
	controller.reset_orbit()
	await _frames(30)
	var cam0 := camera.global_position
	var yaw0 := camera.global_rotation.y
	var worst: String = await _hold("camera_rotate_right", 50, Vector3(-11, 0.05, -18.7))
	var st: Dictionary = controller.get_orbit_state()
	_check("→ gira a câmera em volta da protagonista", absf(st.user_yaw) > 30.0 and absf(angle_difference(yaw0, camera.global_rotation.y)) > deg_to_rad(15.0),
		"giro do jogador %.0f°, yaw da câmera %.0f° → %.0f°" % [st.user_yaw, rad_to_deg(yaw0), rad_to_deg(camera.global_rotation.y)])
	_check("→ sem colisão/oclusão durante o giro", worst == "", worst)
	worst = await _hold("camera_rotate_left", 100, Vector3(-11, 0.05, -18.7))
	st = controller.get_orbit_state()
	_check("← gira para o outro lado", st.user_yaw < -20.0, "giro %.0f°" % st.user_yaw)
	_check("← sem colisão/oclusão durante o giro", worst == "", worst)
	_check("giro limitado a ±%.0f°" % controller.max_orbit_yaw_degrees, absf(st.user_yaw) <= controller.max_orbit_yaw_degrees + 0.01, "%.1f°" % st.user_yaw)
	controller.reset_orbit()
	await _frames(60)
	var e0: float = controller.get_orbit_state().orbit_elev
	worst = await _hold("camera_rotate_up", 40, Vector3(-11, 0.05, -18.7))
	var e1: float = controller.get_orbit_state().orbit_elev
	_check("↑ sobe a câmera (elevação maior)", e1 > e0 + 10.0, "%.0f° → %.0f°" % [e0, e1])
	_check("↑ sem colisão/oclusão (teto)", worst == "", worst)
	worst = await _hold("camera_rotate_down", 80, Vector3(-11, 0.05, -18.7))
	var e2: float = controller.get_orbit_state().orbit_elev
	_check("↓ desce a câmera", e2 < e1 - 10.0, "%.0f° → %.0f°" % [e1, e2])
	_check("↓ sem colisão/oclusão (chão)", worst == "", worst)
	_check("elevação dentro dos limites", e2 >= controller.min_elevation_degrees - 0.5, "%.1f°" % e2)
	controller.reset_orbit()

	# Segurar as setas por muito tempo junto a paredes e cantos nunca atravessa.
	for spot in [Vector3(-22.6, 0.05, -29.0), Vector3(-4.3, 0.05, -8.3), Vector3(2.6, 0.05, -20), Vector3(-3.0, 0.05, -28.0), Vector3(0, 0.05, -10.5)]:
		await _place(spot)
		var w: String = ""
		for k in ["camera_rotate_left", "camera_rotate_up", "camera_rotate_right", "camera_rotate_down"]:
			var r: String = await _hold(k, 70, spot)
			if r != "" and w == "":
				w = r
		_check("setas no canto/parede %s: nunca atravessa" % spot.snapped(Vector3.ONE * 0.1), w == "", w)
		controller.reset_orbit()

	# Sem espaço: a rotação é recusada em vez de enfiar a câmera na parede.
	await _place(Vector3(2.55, 0.05, -16))
	controller.reset_orbit()
	await _frames(40)
	await _hold("camera_rotate_left", 120, Vector3(2.55, 0.05, -16))
	st = controller.get_orbit_state()
	_check("sem espaço: giro recusado ou parado em ponto livre", st.free_distance >= 0.5,
		"giro %.0f°, distância livre %.2f m" % [st.user_yaw, st.free_distance])
	controller.reset_orbit()
	await _frames(30)


func _is_arrow(a: String) -> bool:
	for e in InputMap.action_get_events(a):
		if e is InputEventKey and (e as InputEventKey).physical_keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			return true
	return false


## Segura a ação por n quadros e devolve o primeiro problema A..E encontrado.
func _hold(action: String, n: int, p: Vector3) -> String:
	Input.action_press(action)
	var found := ""
	for i in n:
		await process_frame
		if found == "":
			var r: Dictionary = _inspect(player.global_position)
			for k in ["A", "B", "C", "E"]:
				if r[k] != "":
					found = "%s %s (cam %s)" % [k, r[k], camera.global_position.snapped(Vector3.ONE * 0.01)]
					break
	Input.action_release(action)
	return found


# ------------------------------------------------------------ percursos

func _walk_tests() -> void:
	print("--- percursos andando (portas, corredores, cantos)")
	var routes := [
		["sala inicial → corredor → Room 1", Vector3(0, 0.05, 1.5), [Vector3(0, 0, -10.5), Vector3(-12, 0, -10.5), Vector3(-12, 0, -26)]],
		["corredor 1 → corredor 2 → Room 2", Vector3(0, 0.05, -14), [Vector3(0, 0, -40.5), Vector3(-15, 0, -40.5), Vector3(-15, 0, -55)]],
		["corredor Exit → Artes → volta", Vector3(0, 0.05, -60), [Vector3(0, 0, -71), Vector3(-20, 0, -71), Vector3(-20, 0, -80), Vector3(-8, 0, -80), Vector3(-8, 0, -71), Vector3(0, 0, -71)]],  # Prompt 1: a Artes ganhou parede leste; a volta é pela porta (z −71)
		["corredor 3 → nó Room 3", Vector3(0, 0.05, -91), [Vector3(0, 0, -95.5), Vector3(-20, 0, -95.5), Vector3(-20, 0, -114)]],
		["corredor 4 → nó Room 4 → canto", Vector3(0, 0.05, -116), [Vector3(0, 0, -119.9), Vector3(-10, 0, -119.9), Vector3(-22.5, 0, -137)]],
	]
	for r in routes:
		await _place(r[1])
		var max_step := 0.0
		var max_rot := 0.0
		var flips := 0
		var last_side := 0.0
		var problem := ""
		var prev := camera.global_position
		var prev_basis := camera.global_basis
		var frames := 0
		var cuts := 0
		var cuts0: int = controller.cut_count
		var events: Array[String] = []
		for wp in r[2]:
			for i in 400:
				var to: Vector3 = wp - player.global_position
				to.y = 0.0
				if to.length() < 0.4:
					break
				_press_world(to.normalized())
				await process_frame
				frames += 1
				var is_cut: bool = controller.cut_count != cuts0
				cuts0 = controller.cut_count
				if is_cut:
					cuts += 1
				else:
					max_step = maxf(max_step, camera.global_position.distance_to(prev))
					max_rot = maxf(max_rot, rad_to_deg(prev_basis.get_rotation_quaternion().angle_to(camera.global_basis.get_rotation_quaternion())))
				prev = camera.global_position
				prev_basis = camera.global_basis
				var side := signf(controller.last_composition.x)
				if is_cut:
					events.append("corte em %s" % _short(player.global_position))
				if side != 0.0 and last_side != 0.0 and side != last_side and not is_cut:
					flips += 1
					events.append("troca de lado em %s" % _short(player.global_position))
				if side != 0.0:
					last_side = side
				if problem == "":
					var ins: Dictionary = _inspect(player.global_position)
					for k in ["A", "B", "C", "D", "E"]:
						if ins[k] != "":
							problem = "%s %s em %s" % [k, ins[k], player.global_position.snapped(Vector3.ONE * 0.1)]
							break
		_release_moves()
		var arrived: bool = player.global_position.distance_to((r[2] as Array).back()) < 1.0
		_check("%s: chegou" % r[0], arrived, "fim %s" % player.global_position.snapped(Vector3.ONE * 0.1))
		_check("%s: sem atravessar/ocultar/perder a protagonista" % r[0], problem == "", problem)
		_check("%s: sem saltos fora dos cortes (passo < 0,35 m/quadro, giro < 6°/quadro)" % r[0], max_step < 0.35 and max_rot < 6.0,
			"passo máx %.3f m, giro máx %.2f°, %d quadros" % [max_step, max_rot, frames])
		_check("%s: no máximo 1 corte por porta/esquina" % r[0], cuts <= (r[2] as Array).size() - 1, "%d corte(s) %s" % [cuts, events])
		_check("%s: no máximo 1 troca de lado sem corte" % r[0], flips <= 1, "%d trocas %s" % [flips, events])


func _short(p: Vector3) -> String:
	return "(%.1f, %.1f)" % [p.x, p.z]


func _press_world(dir: Vector3) -> void:
	var basis: Basis = player.get_control_basis()
	var right := Vector3(basis.x.x, 0, basis.x.z).normalized()
	var fwd := Vector3(-basis.z.x, 0, -basis.z.z).normalized()
	var lx := dir.dot(right)
	var ly := dir.dot(fwd)
	var m := maxf(absf(lx), absf(ly))
	lx /= m
	ly /= m
	for pair in [["move_right", lx], ["move_left", -lx], ["move_forward", ly], ["move_back", -ly]]:
		if pair[1] > 0.01:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])


func _release_moves() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "run"]:
		Input.action_release(a)


func _place(p: Vector3) -> void:
	_release_moves()
	player.velocity = Vector3.ZERO
	player.global_position = p
	await _phys(4)
	controller.snap_to_target()
	await _frames(2)


func _check(label: String, ok: bool, info: String) -> void:
	results.append(ok)
	print("%s %s  %s" % ["OK    " if ok else "FALHOU", label, info])


func _phys(n: int) -> void:
	for i in n:
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame
