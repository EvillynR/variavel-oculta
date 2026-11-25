extends SceneTree
## Câmera fixa (estilo diorama, como em Little Nightmares) — padrão do jogo.
## A protagonista faz o percurso completo do Prompt 1 (sala inicial → 6 salas →
## subsolo → Sala de Monitoramento) só com o Input Map; a cada quadro mede:
##  - ângulo fixo: a orientação só muda na troca de cômodo, e devagar;
##  - sem cortes e sem saltos: passo da lente e giro por quadro pequenos;
##  - setas não giram a câmera;
##  - protagonista sempre no quadro e sem geometria visível na frente
##    (paredes recortadas pela maquete e móveis translúcidos são aceitos);
##  - luz acompanhando a protagonista.
## Uso: godot --headless --fixed-fps 60 --path . --script res://tests/camera_fixa_test.gd

const T := preload("res://tests/test_input.gd")
const ROUTE_SRC := preload("res://tests/legado_6_salas/percurso_completo_test.gd")
const MAX_STEP := 0.20        # m por quadro (12 m/s): acompanhamento, nunca salto
const MAX_TURN := 0.35        # graus por quadro
var main: Node
var player: CharacterBody3D
var ctl: Node3D
var cam: Camera3D
var passed := 0
var failed := 0


func _initialize() -> void:
	Door.testing_force_open = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _phys(6)
	for m in get_nodes_in_group("monster"):
		m.process_mode = Node.PROCESS_MODE_DISABLED
	for d in get_nodes_in_group("door"):
		d.unlock()
	player = main.get_node("Player")
	ctl = get_first_node_in_group("camera_controller")
	cam = ctl.camera
	_check("estilo padrão = câmera fixa", ctl.camera_style == 1, str(ctl.camera_style))
	player.global_position = Vector3(0, 0.05, 1.5)
	await _phys(5)
	ctl.snap_to_target()
	await process_frame

	print("--- setas não giram a câmera")
	var b0 := cam.global_basis
	for a in ["camera_rotate_left", "camera_rotate_right", "camera_rotate_up", "camera_rotate_down"]:
		if InputMap.has_action(a):
			Input.action_press(a)
	for i in 60:
		await process_frame
	for a in ["camera_rotate_left", "camera_rotate_right", "camera_rotate_up", "camera_rotate_down"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	_check("1 s segurando as setas: orientação idêntica", _angle(b0, cam.global_basis) < 0.01, "%.3f°" % _angle(b0, cam.global_basis))

	print("--- percurso completo com a câmera fixa")
	var cuts0: int = ctl.cut_count
	var max_step := 0.0
	var max_turn := 0.0
	var turn_frames := 0
	var frames := 0
	var off_frame := 0
	var blocked := 0
	var lens_inside := 0
	var light_bad := 0
	var zones := {}
	var worst := ""
	var prev_pos := cam.global_position
	var prev_basis := cam.global_basis
	var stuck := false
	for e in ROUTE_SRC.ROUTE:
		if e[0] == "E":
			# Chega bem perto da porta (este teste mede a câmera, não o alcance do E).
			var door: Node3D = null
			for d in get_nodes_in_group("door"):
				if door == null or d.global_position.distance_to(player.global_position) < door.global_position.distance_to(player.global_position):
					door = d
			for i in 40:
				var to: Vector3 = door.global_position - player.global_position
				to.y = 0.0
				if to.length() < 1.4:
					break
				T.press_world(player, to.normalized())
				await process_frame
			T.release_moves()
			Input.action_press("interact")
			await process_frame
			await process_frame
			Input.action_release("interact")
			for i in 35:
				await process_frame
				_sample()
			prev_pos = cam.global_position
			prev_basis = cam.global_basis
			continue
		if e[0] != "andar":
			continue
		var target: Vector3 = e[1]
		var ok := false
		for i in 2400:
			var to := target - player.global_position
			to.y = 0.0
			if to.length() < 0.35:
				ok = true
				break
			T.press_world(player, to.normalized())
			await process_frame
			var r := _sample()
			frames += 1
			var step := cam.global_position.distance_to(prev_pos)
			var turn := _angle(prev_basis, cam.global_basis)
			if step > max_step:
				max_step = step
				worst = "passo em %s" % player.global_position.snappedf(0.1)
			max_turn = maxf(max_turn, turn)
			if turn > 0.01:
				turn_frames += 1
			prev_pos = cam.global_position
			prev_basis = cam.global_basis
			off_frame += int(r.off)
			blocked += int(r.blocked != "")
			if r.blocked != "" and blocked <= 3:
				print("   bloqueio: ", r.blocked, " em ", player.global_position.snappedf(0.1))
			lens_inside += int(r.inside != "")
			if r.inside != "" and lens_inside <= 3:
				print("   lente dentro de: ", r.inside, " em ", player.global_position.snappedf(0.1))
			light_bad += int(r.light_bad)
			if ctl.current_zone != null:
				zones[ctl.current_zone.name] = true
		T.release_moves()
		if not ok:
			stuck = true
			break
	_check("percurso feito com a câmera fixa (controles estáveis)", not stuck, str(player.global_position))
	_check("nenhum corte em todo o percurso", ctl.cut_count == cuts0, str(ctl.cut_count - cuts0))
	_check("sem saltos: passo da lente ≤ %.2f m/quadro" % MAX_STEP, max_step <= MAX_STEP, "%.3f m (%s)" % [max_step, worst])
	_check("giro só suave: ≤ %.2f°/quadro" % MAX_TURN, max_turn <= MAX_TURN, "%.3f°" % max_turn)
	_check("ângulo fixo: a orientação fica parada em ≥ 97%% dos quadros", turn_frames <= frames * 0.03, "%d de %d quadros girando" % [turn_frames, frames])
	_check("passou por ≥ 12 zonas de câmera", zones.size() >= 12, str(zones.keys()))
	_check("protagonista sempre no quadro", off_frame == 0, "%d quadros fora" % off_frame)
	_check("nada visível tapando a protagonista", blocked == 0, "%d quadros" % blocked)
	_check("lente nunca dentro de geometria visível", lens_inside == 0, "%d quadros" % lens_inside)
	_check("luz acompanhando a protagonista (≤ 3 m, acesa)", light_bad == 0, "%d quadros" % light_bad)
	print("RESULTADO: %d/%d testes passaram" % [passed, passed + failed])
	quit(1 if failed > 0 else 0)


func _sample() -> Dictionary:
	var r := {"off": false, "blocked": "", "inside": "", "light_bad": false}
	# Posição que a câmera enquadrou no último quadro desenhado (o sinal
	# process_frame chega antes do _process; a física já andou um passo).
	var p: Vector3 = ctl.last_framed_position
	for h in [0.2, 1.0, 1.7]:
		var w: Vector3 = p + Vector3.UP * h
		if cam.is_position_behind(w) or not root.get_visible_rect().has_point(cam.unproject_position(w)):
			r.off = true
	var space := player.get_world_3d().direct_space_state
	for h in [0.4, 1.0, 1.6]:
		var exclude: Array[RID] = [player.get_rid()]
		for i in 10:
			var q := PhysicsRayQueryParameters3D.create(cam.global_position, p + Vector3.UP * h, 1, exclude)
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			exclude.append(hit.rid)
			var c: Object = T.fade_target(hit.collider)
			if _accepted(c):
				continue
			r.blocked = str(main.get_path_to(c))
			break
	# Lente dentro de algo visível com colisão?
	var s := SphereShape3D.new()
	s.radius = 0.05
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = s
	sq.transform = Transform3D(Basis(), cam.global_position)
	sq.collision_mask = 1
	for hit in space.intersect_shape(sq, 8):
		if not _accepted(hit.collider):
			r.inside = str(main.get_path_to(hit.collider))
	var light: OmniLight3D = ctl.get_node_or_null("LuzDaProtagonista")
	r.light_bad = light == null or not light.visible or light.light_energy <= 0.0 or light.global_position.distance_to(p) > 3.0
	return r


## Aceito no caminho da visão: personagens, peças recortadas pela maquete
## (só sombra), invisíveis (barreiras) e móveis/portas translúcidos.
func _accepted(c: Object) -> bool:
	if c is CharacterBody3D:
		return true
	if c is GeometryInstance3D:
		var g := c as GeometryInstance3D
		# Recortada pela maquete: só-sombra (estilo órbita) ou na camada de recorte
		# (câmera fixa: fora da câmera e das luzes).
		if not g.is_visible_in_tree() or g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or g.layers == (1 << 19):
			return true
		if g.is_in_group("camera_fade") and g.transparency >= 0.5:
			return true
		return false
	if c is Node and (c as Node).is_in_group("camera_fade"):
		for g in (c as Node).find_children("*", "GeometryInstance3D", true, false):
			if g.transparency < 0.5:
				return false
		return true
	return false


func _angle(a: Basis, b: Basis) -> float:
	return rad_to_deg(a.get_rotation_quaternion().angle_to(b.get_rotation_quaternion()))


func _phys(n: int) -> void:
	for i in n:
		await physics_frame


func _check(label: String, ok: bool, info: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("%s %s  %s" % ["OK    " if ok else "FALHA ", label, info])
