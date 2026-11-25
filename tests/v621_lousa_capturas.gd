extends SceneTree
## Versão 6.2.1 — a Leitora escrevendo na lousa e a mesa no canto (prints).
## Uso: xvfb-run godot --path . --rendering-driver vulkan --fixed-fps 60 --script res://tests/v621_lousa_capturas.gd -- --out=<pasta>

var out_dir := "user://v621"
var main: Node
var player: CharacterBody3D
var shots := 0
var _cam: Camera3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	SaveSystem.save_path = "user://teste_v621_capturas.json"
	SaveSystem.delete_save()
	SaveSystem.write_save(JSON.parse_string(FileAccess.get_file_as_string("res://data/apresentacao/room_1.json")))
	SaveSystem.pending_action = "continue"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _phys(4)
	player = main.get_node("Player")
	var director = get_first_node_in_group("story_director")
	await _phys(60)
	await _until(func(): return not director.cutscenes.playing, 3000)
	director.enabled = false
	await _phys(10)
	paused = false
	var leitor: Node3D = main.get_node("MonsterRoster/Leitor")
	# Yuko perto da porta da sala, olhando para a lousa
	player.global_position = Vector3(-9.0, 0.05, -14.0)
	player.velocity = Vector3.ZERO
	var d := leitor.global_position - player.global_position
	player.visual.rotation.y = atan2(d.x, d.z)
	var gc := get_first_node_in_group("camera_controller")
	if gc != null and gc.has_method("snap_to_target"):
		gc.snap_to_target()
	await _phys(40)
	await _shot("camera_do_jogo")
	if gc != null:
		gc.process_mode = Node.PROCESS_MODE_DISABLED
	_cam = Camera3D.new()
	_cam.fov = 42.0
	main.add_child(_cam)
	_cam.make_current()
	# luz extra só para os prints (o jogo é bem mais escuro)
	var fill := OmniLight3D.new()
	fill.light_energy = 1.6
	fill.omni_range = 12.0
	fill.light_color = Color(0.9, 0.88, 1.0)
	main.add_child(fill)
	fill.global_position = Vector3(-16.0, 5.0, -18.0)
	var p := leitor.global_position
	# mesmo enquadramento da cena de entrada (cena_portugues)
	_cam.global_position = Vector3(-10.0, 5.2, -21.0)
	_cam.look_at(p + Vector3(0, 2.6, 0), Vector3.UP)
	await _wait(1.0)
	await _shot("cena_entrada")
	_cam.fov = 40.0
	_cam.global_position = p + Vector3(5.5, 3.2, 3.4)
	_cam.look_at(p + Vector3(0, 2.8, 0), Vector3.UP)
	await _wait(1.0)
	await _shot("cena_perto")
	# visão geral: lousa + mesa no canto
	_cam.fov = 55.0
	_cam.global_position = Vector3(-6.0, 6.0, -11.0)
	_cam.look_at(Vector3(-20.0, 1.0, -22.0), Vector3.UP)
	await _wait(0.5)
	await _shot("sala_geral")
	print("capturas: ", shots)
	quit(0)


func _shot(name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%02d_%s.png" % [out_dir, shots, name])
	print("captura ", name)
	shots += 1


func _until(cond: Callable, max_frames: int) -> void:
	var n := 0
	while not cond.call() and n < max_frames:
		await process_frame
		n += 1


func _wait(s: float) -> void:
	for i in int(s * 60.0):
		await process_frame


func _phys(n: int) -> void:
	for i in n:
		await physics_frame
