extends SceneTree
## Etapa 4.5 — câmera, colisões e navegação (headless).
## Conduz a protagonista SOMENTE pelas ações do Input Map (os controles
## originais). A cada quadro monitora a câmera: salto por quadro, giro de
## yaw (direção dos controles), protagonista no quadro, oclusão por geometria
## visível, câmera dentro de geometria e disputa entre zonas.
## Uso: godot --headless --path . --script res://tests/etapa45_navigation_test.gd

var passed := 0
var failed := 0
var main: Node
var player: CharacterBody3D
var controller: Node3D
var camera: Camera3D
var polvo: MonsterController
var boxes: Array = []
var mon := {}


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	preload("res://tests/test_input.gd").open_all_doors(self)  # Prompt 1: portas físicas
	preload("res://tests/test_input.gd").use_orbit_camera(self)  # mede o estilo de órbita (opcional)
	player = main.get_node("Player")
	controller = main.get_node("CameraController")
	camera = controller.get_node("Camera3D")
	polvo = main.get_node("Room1Gameplay/Polvo")
	await _physics(10)
	for g in main.find_children("*", "CSGBox3D", true, false):
		boxes.append([g, g.global_transform * AABB(-g.size / 2.0, g.size)])
	while not polvo.is_navigation_ready():
		await _physics(1)

	await _section_rooms()
	await _section_player_collisions()
	await _section_camera_collision()
	await _section_monster()
	await _section_chase()

	print("RESULTADO: %d/%d testes passaram" % [passed, passed + failed])
	quit(1 if failed > 0 else 0)


# ======================================================== 4 e 7: salas e portas

func _section_rooms() -> void:
	print("--- entrada/saída de salas, corredores e portas (andando, correndo, agachada)")
	var routes := [
		# nome, início, direção no mundo, quadros, modificadores, condição de chegada
		["sala inicial → corredor (porta sul)", Vector3(0, 0.05, 1.5), Vector3.BACK * -1, 150, [], func(p): return p.z < -6.0],
		["corredor → Room 1 (porta oeste)", Vector3(0, 0.05, -10.5), Vector3.LEFT, 150, [], func(p): return p.x < -6.0],
		["Room 1 → corredor", Vector3(-8, 0.05, -10.5), Vector3.RIGHT, 150, [], func(p): return p.x > 0.0],
		["corredor → Room 1 correndo", Vector3(1, 0.05, -10.5), Vector3.LEFT, 90, ["run"], func(p): return p.x < -6.0],
		["corredor → Room 1 agachada", Vector3(0, 0.05, -10.5), Vector3.LEFT, 240, ["crouch"], func(p): return p.x < -6.0],
		["corredor 1 → corredor 2 (porta estreita)", Vector3(0, 0.05, -25), Vector3.FORWARD, 150, [], func(p): return p.z < -31.0],
		["corredor 2 → corredor 1 correndo", Vector3(0, 0.05, -32), Vector3.BACK, 90, ["run"], func(p): return p.z > -25.0],
		["corredor 2 → Room 2", Vector3(0, 0.05, -40.5), Vector3.LEFT, 150, [], func(p): return p.x < -6.0],
		["Room 2 → corredor 2 correndo", Vector3(-8, 0.05, -40.5), Vector3.RIGHT, 90, ["run"], func(p): return p.x > 0.0],
		["corredor de saída → sala de saída", Vector3(0, 0.05, -70), Vector3.LEFT, 150, [], func(p): return p.x < -8.0],
		["corredor 3 → Room 3", Vector3(0, 0.05, -95.5), Vector3.LEFT, 150, [], func(p): return p.x < -6.0],
		["corredor 4 → Room 4 agachada", Vector3(0, 0.05, -120), Vector3.LEFT, 260, ["crouch"], func(p): return p.x < -6.0],
		["virando no corredor (ida e volta)", Vector3(0, 0.05, -18), Vector3.FORWARD, 60, [], func(p): return true],
	]
	for r in routes:
		await _teleport(r[1])
		_reset_monitor()
		await _walk(r[2], r[3], r[4])
		if r[0].begins_with("virando"):
			await _walk(Vector3.BACK, 60, [])
			await _walk(Vector3.FORWARD, 30, ["run"])
		var arrived: bool = r[5].call(player.global_position)
		_check("%s: chegou" % r[0], arrived, "pos=%s" % player.global_position.snapped(Vector3.ONE * 0.01))
		_check_monitor(r[0])


# ======================================================== 5: colisões da protagonista

func _section_player_collisions() -> void:
	print("--- colisões da protagonista (carteiras, armário, paredes, porta)")
	var cases := [
		# nome, início, direção, eixo, limite (a protagonista não pode passar)
		["mesa do professor", Vector3(-17.0, 0.05, -18.7), Vector3.LEFT, "x", -18.88 + 0.2],
		["carteira 01", Vector3(-12.0, 0.05, -18.7), Vector3.LEFT, "x", -13.71 + 0.2],
		["carteira 02", Vector3(-12.0, 0.05, -13.0), Vector3.LEFT, "x", -13.70 + 0.2],
		["carteira 03 (pelo lado)", Vector3(-14.2, 0.05, -21.0), Vector3.FORWARD, "-z", -22.75 + 0.2],
		["armário", Vector3(-5.5, 0.05, -29.2), Vector3.LEFT, "x", -7.4 + 0.2],
		["parede oeste Room 1", Vector3(-21.0, 0.05, -12.0), Vector3.LEFT, "x", -23.4 + 0.2],
		["parede norte Room 1", Vector3(-17.0, 0.05, -10.0), Vector3.BACK, "+z", -7.6 - 0.2],
		["parede sul Room 1", Vector3(-17.0, 0.05, -27.5), Vector3.FORWARD, "-z", -29.9 + 0.2],
		["parede invisível leste do corredor", Vector3(1.0, 0.05, -16.0), Vector3.RIGHT, "+x", 2.9 - 0.2],
		["batente da porta corredor 1/2", Vector3(-2.8, 0.05, -26.0), Vector3.FORWARD, "-z", -28.3 + 0.2],
	]
	for c in cases:
		await _teleport(c[1])
		for mods in [["run"], ["crouch"]]:
			await _teleport(c[1])
			await _walk(c[2], 110, mods, false)
			var p := player.global_position
			var ok := true
			match c[3]:
				"x": ok = p.x >= c[4]
				"+x": ok = p.x <= c[4]
				"-z": ok = p.z >= c[4]
				"+z": ok = p.z <= c[4]
			_check("%s bloqueia (%s)" % [c[0], mods[0]], ok, "pos=%s limite %s %.2f" % [p.snapped(Vector3.ONE * 0.01), c[3], c[4]])
	# Passagem intencional: o espaço entre carteiras continua livre.
	await _teleport(Vector3(-12.0, 0.05, -16.0))
	await _walk(Vector3.LEFT, 150, [], false)
	_check("corredor entre carteiras continua livre", player.global_position.x < -16.5, "x=%.2f" % player.global_position.x)


# ======================================================== 3: colisão da câmera

func _section_camera_collision() -> void:
	print("--- colisão da câmera")
	await _teleport(Vector3(0, 0.05, -16))
	await _settle()
	# Prioridade 1: a câmera não fica mais atrás de paredes (nem invisíveis).
	_check("corredor: lente dentro do corredor (não passa da parede leste invisível)", camera.global_position.x < 2.9, "x %.2f (parede em 2,9)" % camera.global_position.x)
	await _teleport(Vector3(-12, 0.05, -18.7))
	await _settle()
	_check("Room 1: lente dentro da sala (não atravessa a parede do corredor)", camera.global_position.x < -3.6, "x %.2f (parede em -3,6)" % camera.global_position.x)
	var base_fraction: float = controller.last_collision_fraction
	var normal_distance := camera.global_position.distance_to(player.global_position)

	# Parede de teste visível entre a protagonista e a câmera.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(0.3, 8.0, 6.0)
	wall.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = shape.shape.size
	wall.add_child(mesh)
	main.add_child(wall)
	wall.global_position = Vector3(-7.0, 4.0, -18.7)
	_reset_monitor()
	var in_wall := 0
	var max_step := 0.0
	var hops := 0
	var max_hop := 0.0
	var prev := camera.global_position
	for i in 90:
		await process_frame
		var cx := camera.global_position.x
		if cx > -7.15 - 0.05 and cx < -6.85 + 0.05:
			in_wall += 1
		var st := camera.global_position.distance_to(prev)
		if st > 0.5:
			hops += 1
			max_hop = maxf(max_hop, st)
		else:
			max_step = maxf(max_step, st)
		prev = camera.global_position
	_check("obstáculo: lente nunca dentro da parede", in_wall == 0, "%d quadros" % in_wall)
	_check("obstáculo: aproximação suave (< 0,5 m/quadro)", max_step < 0.5, "passo máx %.3f" % max_step)
	# Para chegar ao lado da protagonista a lente precisa passar pela espessura
	# da parede; isso é feito num único pulo curto, nunca mostrando o interior.
	# Prioridade 1: uma parede que surge de repente entre as duas é resolvida com
	# um corte limpo (a lente nunca passa por dentro dela).
	_check("obstáculo: no máximo 1 corte/pulo para ficar à frente da parede", hops <= 1, "%d pulo(s), %.2f m" % [hops, max_hop])
	_check("obstáculo: câmera assenta antes da parede", camera.global_position.x < -7.15 - controller.collision_radius + 0.05, "x %.2f (parede em -7,15)" % camera.global_position.x)
	var close_distance := camera.global_position.distance_to(player.global_position)
	_check("obstáculo: câmera se aproxima da protagonista", close_distance < normal_distance - 1.0, "%.2f → %.2f m" % [normal_distance, close_distance])
	_check("obstáculo: protagonista continua no quadro", _on_screen(player.global_position, 1.0), "")

	# Parede exatamente onde a lente está: a aproximação tem de ser imediata.
	var lens_wall := wall.duplicate()
	main.add_child(lens_wall)
	lens_wall.global_position = Vector3(-4.0, 4.0, -18.7)
	wall.queue_free()
	await process_frame
	await process_frame
	_check("parede na posição da lente: câmera recua na hora", camera.global_position.x < -4.15 - 0.1, "x %.2f" % camera.global_position.x)
	lens_wall.queue_free()
	await process_frame
	max_step = 0.0
	var last := camera.global_position
	for i in 300:
		await process_frame
		max_step = maxf(max_step, camera.global_position.distance_to(last))
		last = camera.global_position
	var back := camera.global_position.distance_to(player.global_position)
	_check("obstáculo removido: volta suave (passo < 0,3 m/quadro)", max_step < 0.3, "passo máx %.3f" % max_step)
	_check("obstáculo removido: volta à distância normal", absf(back - normal_distance) < 0.3, "%.2f (normal %.2f)" % [back, normal_distance])

	# O monstro entre a câmera e a protagonista não empurra a câmera.
	var saved := polvo.global_position
	polvo.global_position = Vector3(-8.0, 0.0, -18.7)
	await _physics(3)
	controller.snap_to_target()
	await _physics(2)
	_check("monstro entre câmera e protagonista não puxa a câmera", absf(controller.last_collision_fraction - base_fraction) < 0.01, "fração %.3f (sem monstro %.3f)" % [controller.last_collision_fraction, base_fraction])
	polvo.global_position = saved
	await _physics(3)


# ======================================================== 6: colisões do monstro

func _section_monster() -> void:
	print("--- colisões e navegação do monstro")
	var map := polvo.agent.get_navigation_map()
	var armario := Vector3(-8.0, 0, -29.2)
	_check("armário é obstáculo no navmesh", _flat(NavigationServer3D.map_get_closest_point(map, armario), armario) > 0.5, "")
	_check("Polvo colide com o cenário (máscara inclui camada 1)", polvo.collision_mask & 1 != 0, "")
	_check("Polvo fora da camada do cenário (não bloqueia câmera/interação)", polvo.collision_layer & 1 == 0, "camada %d" % polvo.collision_layer)

	# Estímulos sonoros (API pública hear_stimulus) em pontos que obrigam a
	# contornar carteiras e armário.
	polvo.activate(&"teste_45", polvo.global_position, true)
	await _physics(2)
	var path_points := [Vector3(-6.5, 0, -27.0), Vector3(-10.0, 0, -28.7), Vector3(-16.0, 0, -12.0), Vector3(-20.0, 0, -26.0)]
	var inside_obstacle := 0
	var max_stuck := 0.0
	var visited := 0
	player.global_position = Vector3(0, 0.05, -40)   # longe e fora de vista
	await _physics(2)
	for target in path_points:
		polvo.hear_stimulus(target)
		var still := 0.0
		var last := polvo.global_position
		for i in 900:
			await physics_frame
			if _in_obstacle(polvo.global_position, 0.3):
				inside_obstacle += 1
			var moving: bool = polvo.state == MonsterController.State.INVESTIGATING and polvo._has_move_target
			if moving and polvo.global_position.distance_to(last) < 0.002:
				still += 1.0 / 60.0
			else:
				still = 0.0
			max_stuck = maxf(max_stuck, still)
			last = polvo.global_position
			if _flat(polvo.global_position, target) < 1.2:
				visited += 1
				break
		print("        estímulo %s -> Polvo em %s (%s)" % [target, polvo.global_position.snapped(Vector3.ONE * 0.01), polvo.get_state_name()])
	_check("monstro alcança pontos atrás de carteiras e armário", visited == path_points.size(), "%d/%d" % [visited, path_points.size()])
	_check("monstro nunca dentro de carteira/armário", inside_obstacle == 0, "%d quadros" % inside_obstacle)
	_check("monstro não fica preso (parado < 2 s em movimento)", max_stuck < 2.0, "%.2f s" % max_stuck)

	# Não empurra a protagonista ao alcançá-la.
	polvo._change_state(MonsterController.State.PATROLLING)
	await _teleport(Vector3(-15.0, 0.05, -18.7))
	polvo.global_position = Vector3(-20.0, polvo.global_position.y, -18.7)
	polvo.rotation.y = -PI / 2.0
	await _physics(2)
	print("        Polvo %s %s vê=%s" % [polvo.global_position.snapped(Vector3.ONE * 0.01), polvo.get_state_name(), polvo.perception.can_see(player)])
	var start := player.global_position
	var caught := [false]
	var conn := func(): caught[0] = true
	polvo.player_caught.connect(conn)
	for i in 300:
		await physics_frame
		if caught[0]:
			break
	for i in 60:
		await physics_frame
	_check("perseguição alcança a protagonista", caught[0], polvo.get_state_name())
	_check("monstro não empurra a protagonista parada", _flat(player.global_position, start) < 0.05, "deslocou %.3f m" % _flat(player.global_position, start))
	polvo.player_caught.disconnect(conn)

	# Pendência resolvida na Etapa 4.5b: a protagonista colide com o corpo do
	# monstro (máscara inclui a camada 3). Monstro parado numa área livre.
	polvo._change_state(MonsterController.State.INACTIVE)
	var mpos := Vector3(-10.0, polvo.global_position.y, -16.0)
	polvo.global_position = mpos
	await _teleport(Vector3(-7.0, 0.05, -16.0))
	await _walk(Vector3.LEFT, 90, [], false)
	_check("protagonista não atravessa nem empurra o monstro", player.global_position.x > mpos.x + 0.8 and _flat(polvo.global_position, mpos) < 0.02,
		"x=%.2f, Polvo deslocado %.3f m (máscara da protagonista = %d)" % [player.global_position.x, _flat(polvo.global_position, mpos), player.collision_mask])
	polvo.global_position = Vector3(-21.2, mpos.y, -18.7)
	polvo.activate(&"teste_45", polvo.global_position, true)
	polvo._change_state(MonsterController.State.RETURNING)
	await _physics(2)


# ======================================================== 8: perseguição

func _section_chase() -> void:
	print("--- perseguição com a protagonista andando e correndo")
	# Prompt 3: uma captura em seção anterior deixa o Game Over aberto e o jogo
	# pausado; a perseguição é medida com o jogo rodando.
	if paused:
		print("   (Game Over de uma seção anterior fechado antes da perseguição)")
	call_group("game_over_ui", "dismiss")
	for mode in [[], ["run"]]:
		call_group("game_over_ui", "dismiss")   # a volta anterior pode ter terminado em captura
		polvo.global_position = Vector3(-20.0, polvo.global_position.y, -18.7)
		polvo._change_state(MonsterController.State.PATROLLING)
		await _teleport(Vector3(-14.5, 0.05, -18.7))
		polvo.rotation.y = -PI / 2.0
		await _physics(30)
		_reset_monitor()
		var both := 0
		var frames := 0
		# Foge pela sala: sul, depois leste até o corredor.
		for leg in [[Vector3.FORWARD, 70], [Vector3.RIGHT, 110], [Vector3.BACK, 60]]:
			await _walk(leg[0], leg[1], mode)
		var label := "correndo" if mode.size() > 0 else "andando"
		_check("perseguição %s: Polvo entrou em CHASING" % label, mon["chased"], "")
		_check_monitor("perseguição " + label)
		_check("perseguição %s: Polvo visível no quadro em parte da fuga" % label, mon["monster_seen"] > 20, "%d quadros" % mon["monster_seen"])
		polvo._change_state(MonsterController.State.RETURNING)
		await _physics(5)


# ======================================================== monitor da câmera

func _reset_monitor() -> void:
	mon = {"frames": 0, "max_step": 0.0, "max_yaw_step": 0.0, "yaw_range": [INF, -INF], "off_screen": 0,
		"occluded": 0, "inside": 0, "zone_changes": 0, "last_zone": controller.current_zone,
		"last_pos": camera.global_position, "last_yaw": _control_yaw(), "first_yaw": _control_yaw(), "monster_seen": 0,
		"chased": false, "occ_example": "", "cuts": 0, "last_cuts": controller.cut_count}


func _monitor_frame() -> void:
	mon["frames"] += 1
	var pos := camera.global_position
	# Prioridade 1: ao passar por uma porta a câmera faz um CORTE limpo (ela não
	# atravessa mais paredes). Cortes são contados à parte; fora deles o
	# movimento tem de ser contínuo.
	if controller.cut_count != mon["last_cuts"]:
		mon["cuts"] += controller.cut_count - mon["last_cuts"]
		mon["last_cuts"] = controller.cut_count
	else:
		mon["max_step"] = maxf(mon["max_step"], pos.distance_to(mon["last_pos"]))
	mon["last_pos"] = pos
	# Direção dos controles: o referencial real da protagonista (antes era a
	# própria câmera; agora ela tem referencial travado enquanto a tecla é segurada).
	var yaw := _control_yaw()
	mon["max_yaw_step"] = maxf(mon["max_yaw_step"], absf(rad_to_deg(angle_difference(mon["last_yaw"], yaw))))
	mon["last_yaw"] = yaw
	var rel := rad_to_deg(angle_difference(mon["first_yaw"], yaw))
	mon["yaw_range"][0] = minf(mon["yaw_range"][0], rel)
	mon["yaw_range"][1] = maxf(mon["yaw_range"][1], rel)
	if not _on_screen(player.global_position, 0.9):
		mon["off_screen"] += 1
	var occ := _occluder(pos, player.global_position)
	if occ != "":
		mon["occluded"] += 1
		mon["occ_example"] = occ
	if _inside_visible(pos):
		mon["inside"] += 1
	if controller.current_zone != mon["last_zone"]:
		mon["zone_changes"] += 1
		mon["last_zone"] = controller.current_zone
	if polvo.state == MonsterController.State.CHASING:
		mon["chased"] = true
	if polvo.is_active() and _on_screen(polvo.global_position, 1.75):
		mon["monster_seen"] += 1


func _check_monitor(label: String) -> void:
	_check("%s: câmera sem saltos fora dos cortes (< 0,5 m/quadro)" % label, mon["max_step"] < 0.5, "%.3f m" % mon["max_step"])
	_check("%s: no máximo 1 corte (porta)" % label, mon["cuts"] <= 1, "%d corte(s)" % mon["cuts"])
	_check("%s: direção dos controles estável (yaw < 1°/quadro, faixa < 21°)" % label,
		mon["max_yaw_step"] < 1.0 and mon["yaw_range"][1] - mon["yaw_range"][0] < 21.0,
		"passo %.2f°, faixa %.1f°" % [mon["max_yaw_step"], mon["yaw_range"][1] - mon["yaw_range"][0]])
	_check("%s: protagonista sempre no quadro" % label, mon["off_screen"] == 0, "%d de %d quadros fora" % [mon["off_screen"], mon["frames"]])
	_check("%s: sem parede visível entre câmera e protagonista" % label, mon["occluded"] == 0, "%d quadros (%s)" % [mon["occluded"], mon["occ_example"]])
	_check("%s: câmera nunca dentro de geometria" % label, mon["inside"] == 0, "%d quadros" % mon["inside"])
	_check("%s: sem disputa de zonas (≤ 4 trocas)" % label, mon["zone_changes"] <= 4, "%d trocas" % mon["zone_changes"])


# ======================================================== utilidades

func _control_yaw() -> float:
	var b: Basis = player.get_control_basis()
	return atan2(b.z.x, b.z.z)


## Anda na direção do mundo mais próxima usando a ação de movimento cujo
## sentido (calculado como em player.gd, relativo à câmera) mais se aproxima.
func _walk(world_dir: Vector3, frames: int, modifiers: Array, monitor := true) -> void:
	for i in frames:
		preload("res://tests/test_input.gd").press_world(player, world_dir)
		for m in modifiers:
			Input.action_press(m)
		await physics_frame
		await process_frame
		if monitor:
			_monitor_frame()
	for a in ["move_forward", "move_back", "move_left", "move_right", "run", "crouch"]:
		Input.action_release(a)


func _action_for(world_dir: Vector3) -> String:
	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var options := {"move_right": right, "move_left": -right, "move_forward": forward, "move_back": -forward}
	var best := ""
	var best_dot := -INF
	for a in options:
		var d: float = options[a].dot(world_dir.normalized())
		if d > best_dot:
			best_dot = d
			best = a
	return best


func _teleport(p: Vector3) -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "run", "crouch"]:
		Input.action_release(a)
	player.velocity = Vector3.ZERO
	player.global_position = p
	await _physics(3)
	controller.snap_to_target()
	await _physics(2)


func _settle() -> void:
	for i in 90:
		await process_frame


## Ponto dentro do quadro 16:9 (FOV vertical da câmera), com 3% de margem.
## Calculado à mão: no modo headless o viewport não tem o tamanho real da janela.
func _on_screen(base: Vector3, h: float) -> bool:
	var local := camera.global_transform.affine_inverse() * (base + Vector3.UP * h)
	if local.z >= -0.05:
		return false
	var tan_v := tan(deg_to_rad(camera.fov) * 0.5) * 0.97
	var tan_h := tan_v * 16.0 / 9.0
	return absf(local.y / -local.z) <= tan_v and absf(local.x / -local.z) <= tan_h


func _is_visible_geo(n: Object) -> bool:
	if n is Node and n.is_in_group("camera_ignore"):
		return false
	if n is GeometryInstance3D:
		return n.is_visible_in_tree() and n.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	if n is CharacterBody3D:
		return false
	return n is Node3D and n.is_visible_in_tree()


func _occluder(cam: Vector3, p: Vector3) -> String:
	var space := camera.get_world_3d().direct_space_state
	var exclude: Array[RID] = [player.get_rid()]
	for i in 10:
		var r := space.intersect_ray(PhysicsRayQueryParameters3D.create(cam, p + Vector3.UP * 1.2, 1, exclude))
		if r.is_empty():
			return ""
		if _is_visible_geo(r.collider):
			return str(main.get_path_to(r.collider))
		exclude.append(r.rid)
	return ""


func _inside_visible(pos: Vector3) -> bool:
	for e in boxes:
		if _is_visible_geo(e[0]) and e[1].grow(0.05).has_point(pos):
			return true
	return false


func _in_obstacle(p: Vector3, margin: float) -> bool:
	for rect in [[-19.88, -18.88, -19.95, -17.45], [-14.71, -13.71, -19.95, -17.45], [-14.70, -13.70, -14.25, -11.75],
			[-14.70, -13.70, -25.25, -22.75], [-8.6, -7.4, -29.5, -28.9]]:
		if p.x > rect[0] - margin and p.x < rect[1] + margin and p.z > rect[2] - margin and p.z < rect[3] + margin:
			return true
	return false


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("%s %s  %s" % ["OK    " if ok else "FALHA ", name, detail])
