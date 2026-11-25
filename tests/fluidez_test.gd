extends SceneTree
## Versão 5.4 — "ela não está andando fluida".
## A física roda a 60 Hz; o monitor pode desenhar a 144 Hz. Sem interpolação, a
## Yuko (e a câmera atrás dela) andam aos saltos: alguns quadros ela anda um
## passo inteiro, outros fica parada. Mede, quadro a quadro na tela, quanto ela
## anda e quanto a câmera anda; com interpolação os passos ficam regulares.
## Uso: godot --headless --path . --script res://tests/fluidez_test.gd   (sem --fixed-fps)

var passed := 0
var failed := 0


func _initialize() -> void:
	Engine.max_fps = 144
	_check("interpolação de física ligada no projeto", ProjectSettings.get_setting("physics/common/physics_interpolation", false))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 10:
		await process_frame
	var d = get_first_node_in_group("story_director")
	var n := 0
	while d.is_busy() and n < 3000:
		await process_frame
		n += 1
	d.enabled = false
	var player: Node3D = main.get_node("Player")
	var visual: Node3D = player.get_node("Visual")
	player.global_position = Vector3(0, 0.05, -20)
	player.reset_physics_interpolation()
	for i in 30:
		await process_frame
	var cam := root.get_camera_3d()
	var ti = preload("res://tests/test_input.gd")
	paused = false
	ti.press_world(player, Vector3(0, 0, -1))   # anda pelo corredor
	var start := player.global_position
	for i in 40:
		await process_frame
	var steps: Array[float] = []
	var cam_steps: Array[float] = []
	var last := visual.get_global_transform_interpolated().origin
	var last_cam := cam.global_position
	var last_t := Time.get_ticks_usec()
	for i in 150:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last_t) / 1e6
		last_t = now
		var p := visual.get_global_transform_interpolated().origin
		steps.append(p.distance_to(last) / maxf(dt, 0.0001))
		cam_steps.append(cam.global_position.distance_to(last_cam) / maxf(dt, 0.0001))
		last = p
		last_cam = cam.global_position
	ti.release_moves()
	print("andou de ", start, " até ", player.global_position)
	var r := _jitter(steps)
	var rc := _jitter(cam_steps)
	print("velocidade na tela: média %.2f m/s, variação %.0f%%, quadros parados %d de %d" % [r.mean, r.cv * 100.0, r.still, steps.size()])
	print("câmera: média %.2f m/s, variação %.0f%%" % [rc.mean, rc.cv * 100.0])
	_check("ela anda (%.2f m/s)" % r.mean, r.mean > 1.0)
	_check("sem quadros parados no meio da caminhada (%d)" % r.still, r.still <= 3)
	_check("passo regular na tela (variação %.0f%% < 35%%)" % (r.cv * 100.0), r.cv < 0.35)
	print("RESULTADO: %d ok, %d falhas" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _jitter(v: Array[float]) -> Dictionary:
	var s := 0.0
	for x in v: s += x
	var mean := s / v.size()
	var q := 0.0
	var still := 0
	for x in v:
		q += (x - mean) * (x - mean)
		if x < mean * 0.15: still += 1
	return {"mean": mean, "cv": sqrt(q / v.size()) / maxf(mean, 0.0001), "still": still}


func _check(label: String, ok: bool) -> void:
	if ok:
		passed += 1
		print("  ok: ", label)
	else:
		failed += 1
		print("  FALHA: ", label)
