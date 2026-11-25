extends SceneTree
## Modelo animado da Yuko (YukoRig.glb): parada, andar, correr, agachar
## (andando e parada), velocidade da animação, loops sem pulo, pausa e
## esconderijo. Usa as teclas de verdade (Input.action_press).
## Uso: godot --headless --fixed-fps 60 --path . --script res://tests/yuko_animacao_test.gd

var passed := 0
var failed := 0
var player: CharacterBody3D
var yuko: YukoAnimator


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _phys(5)
	player = main.get_node("Player")
	yuko = player.get_node("Visual/Yuko")
	preload("res://tests/test_input.gd").open_all_doors(self)
	_check("modelo da Yuko no lugar da cápsula", yuko != null and yuko.anim != null and player.visual.find_children("*", "MeshInstance3D", true, false).size() >= 1)
	_check("biblioteca com 4 loops", yuko.anim.get_animation_list().has("yuko/andar") and yuko.anim.get_animation_list().has("yuko/correr") and yuko.anim.get_animation_list().has("yuko/agachar") and yuko.anim.get_animation_list().has("yuko/parada"))
	for n in ["parada", "andar", "correr", "agachar"]:
		var a: Animation = yuko.anim.get_animation("yuko/" + n)
		_check("loop '%s' fecha sem pulo" % n, a.loop_mode == Animation.LOOP_LINEAR and _loop_gap(a) < 0.01)
	_check("pés no chão (visual na base da cápsula)", absf(player.visual.position.y) < 0.001)
	# corredor livre e reto (direita da câmera = ao longo do corredor)
	player.global_position = Vector3(0, 0.05, -14.0)
	await _phys(20)
	_check("parada: animação de respiração", yuko.current == &"parada")
	# andar
	Input.action_press("move_right")
	await _phys(40)
	var spd := Vector2(player.velocity.x, player.velocity.z).length()
	_check("andar: anima 'andar' (%.1f m/s)" % spd, yuko.current == &"andar")
	_check("andar: animação acelera junto (escala %.2f)" % yuko.anim.speed_scale, yuko.anim.speed_scale > 1.5)
	var pose_a := _pose()
	await _phys(9)
	_check("andar: as pernas se mexem", _pose_diff(pose_a, _pose()) > 0.05)
	_check("vira para onde anda", absf(wrapf(player.visual.rotation.y - atan2(player.velocity.x, player.velocity.z), -PI, PI)) < 0.3)
	# correr
	Input.action_press("run")
	await _phys(30)
	_check("correr: anima 'correr'", yuko.current == &"correr")
	Input.action_release("run")
	# agachar andando
	Input.action_press("crouch")
	await _phys(30)
	_check("agachar andando: anima 'agachar'", yuko.current == &"agachar" and yuko.anim.speed_scale > 0.5)
	Input.action_release("move_right")
	await _phys(20)
	_check("agachada parada: segura a pose", yuko.current == &"agachar" and yuko.anim.speed_scale == 0.0)
	Input.action_release("crouch")
	await _phys(20)
	_check("levanta e volta para 'parada'", yuko.current == &"parada" and not player.is_crouching)
	# pausa (cena de filme, enigma, documento): respira parada e não congela
	Input.action_press("move_right")
	await _phys(20)
	paused = true
	await process_frame
	await process_frame
	_check("jogo pausado: volta para 'parada'", yuko.current == &"parada")
	var p0 := _pose()
	for i in 20:
		await process_frame
	_check("jogo pausado: continua respirando (não congela)", _pose_diff(p0, _pose()) > 0.0005)
	paused = false
	Input.action_release("move_right")
	await _phys(10)
	# esconderijo
	var spot: Node3D = null
	for n in get_nodes_in_group("hiding_spot"):
		spot = n
		break
	if spot != null:
		player.enter_hiding(spot)
		await _phys(3)
		_check("escondida: modelo some", not player.visual.is_visible_in_tree())
		player.leave_hiding()
		await _phys(3)
		_check("sai do esconderijo: modelo volta", player.visual.is_visible_in_tree())
	print("RESULTADO: %d ok, %d falhas" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _loop_gap(a: Animation) -> float:
	# compara a primeira e a última CHAVE de cada trilha (o que o loop junta)
	var gap := 0.0
	for t in a.get_track_count():
		if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			var n := a.track_get_key_count(t)
			var q0: Quaternion = a.track_get_key_value(t, 0)
			var q1: Quaternion = a.track_get_key_value(t, n - 1)
			gap = maxf(gap, q0.angle_to(q1))
	return gap


func _pose() -> Array:
	var sk: Skeleton3D = yuko.find_children("*", "Skeleton3D", true, false)[0]
	var out := []
	for b in sk.get_bone_count():
		out.append(sk.get_bone_pose_rotation(b))
	return out


func _pose_diff(a: Array, b: Array) -> float:
	var d := 0.0
	for i in a.size():
		d += a[i].angle_to(b[i])
	return d


func _phys(n: int) -> void:
	for i in n:
		await physics_frame


func _check(name: String, ok: bool) -> void:
	if not ok and player != null:
		print("    estado: anim=%s escala=%.2f vel=%.2f run=%s crouch=%s pos=%s" % [yuko.current, yuko.anim.speed_scale, Vector2(player.velocity.x, player.velocity.z).length(), player.is_running, player.is_crouching, player.global_position.snapped(Vector3.ONE * 0.1)])
	if ok:
		passed += 1
		print("  ok   ", name)
	else:
		failed += 1
		print("  FALHA ", name)
