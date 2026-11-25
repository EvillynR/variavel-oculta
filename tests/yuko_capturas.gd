extends SceneTree
## Capturas da Yuko animada no jogo (câmera de jogo): parada, andar, correr,
## agachar, dentro de uma sala, e a abertura (deitada → de pé).
## Uso: xvfb-run godot --path . --rendering-driver vulkan --fixed-fps 60 --script res://tests/yuko_capturas.gd -- --out=<pasta>

var out_dir := "user://yuko"
var shots := 0
var player: CharacterBody3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	# 1) Jogo novo de verdade: abertura (deitada → levanta)
	SaveSystem.save_path = "user://teste_yuko_save.json"
	SaveSystem.delete_save()
	SaveSystem.pending_action = "new"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	RenderingServer.render_loop_enabled = false
	await _phys(4)
	player = main.get_node("Player")
	var director: StoryDirector = get_first_node_in_group("story_director")
	for t in [6.0, 9.0, 14.5, 17.0]:
		await _until_time(t)
		await _shot("abertura_%04.1f" % t)
	await _until(func(): return not director.is_busy(), 6000)
	await _wait(1.0)
	await _shot("parada_sala_inicial")
	# 2) Movimentos no corredor (direita da câmera = ao longo do corredor)
	director.enabled = false
	player.global_position = Vector3(0, 0.05, -12.0)
	await _wait(1.0)
	Input.action_press("move_right")
	await _wait(0.9)
	await _shot("andar_a")
	await _wait(0.25)
	await _shot("andar_b")
	Input.action_press("run")
	await _wait(0.8)
	await _shot("correr_a")
	await _wait(0.2)
	await _shot("correr_b")
	Input.action_release("run")
	Input.action_press("crouch")
	await _wait(0.8)
	await _shot("agachar_andando")
	Input.action_release("move_right")
	await _wait(0.6)
	await _shot("agachar_parada")
	Input.action_release("crouch")
	# 3) Dentro de uma sala, andando para o fundo
	player.global_position = Vector3(-8.0, 0.05, -44.0)
	await _wait(1.2)
	Input.action_press("move_forward")
	await _wait(0.8)
	await _shot("sala_andando_fundo")
	Input.action_release("move_forward")
	Input.action_press("move_back")
	await _wait(0.9)
	await _shot("sala_andando_frente")
	Input.action_release("move_back")
	await _wait(0.8)
	await _shot("sala_parada")
	SaveSystem.delete_save()
	quit()


var _clock := 0.0


func _until_time(t: float) -> void:
	while _clock < t:
		await process_frame
		_clock += 1.0 / 60.0


func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await physics_frame
		t += 1.0 / 60.0
		_clock += 1.0 / 60.0


func _until(cond: Callable, max_frames: int) -> void:
	var n := 0
	while not cond.call() and n < max_frames:
		await process_frame
		_clock += 1.0 / 60.0
		n += 1


func _phys(n: int) -> void:
	for i in n:
		await physics_frame
		_clock += 1.0 / 60.0


func _shot(name: String) -> void:
	RenderingServer.render_loop_enabled = true
	for i in 3:
		await RenderingServer.frame_post_draw
	RenderingServer.render_loop_enabled = false
	root.get_texture().get_image().save_png("%s/%02d_%s.png" % [out_dir, shots, name])
	print("captura ", name)
	shots += 1
