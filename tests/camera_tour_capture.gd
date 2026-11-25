extends SceneTree
## Captura real (Forward+) de cenários de câmera. Usa as ações do Input Map.
## Uso: xvfb-run godot --path . --rendering-driver vulkan --fixed-fps 60 --script res://tests/camera_tour_capture.gd -- --out=<pasta> [--tag=antes]
## Para cada cenário salva um PNG e imprime métricas: luminância média,
## fração de pixels quase pretos, posição da câmera, zona ativa e se a
## protagonista/o monstro aparecem no quadro.

var out_dir := "user://shots"
var tag := "run"
var main: Node
var player: CharacterBody3D
var controller: Node3D
var camera: Camera3D
var polvo: Node3D

const SCENARIOS := [
	# nome, posição inicial, ações, frames, ativar Polvo?
	["01_sala_inicial", Vector3(0, 0.05, 0), [], 30, false],
	["02_corredor_meio", Vector3(0, 0.05, -16), [], 30, false],
	["03_porta_room1_entrando", Vector3(-1.5, 0.05, -10.5), ["move_forward"], 70, false],
	["04_room1_centro", Vector3(-11, 0.05, -18.7), [], 40, false],
	["05_room1_aproxima_polvo", Vector3(-10, 0.05, -18.7), ["move_forward"], 75, false],
	["06_room1_parede_norte_andando", Vector3(-17, 0.05, -12), ["move_left"], 90, false],
	["07_room1_parede_sul_andando", Vector3(-17, 0.05, -25), ["move_right"], 90, false],
	["08_room1_canto_armario", Vector3(-6, 0.05, -26), ["move_right"], 60, false],
	["09_room1_canto_tabela", Vector3(-17, 0.05, -10), ["move_left"], 60, false],
	["10_room1_agachada_carteira", Vector3(-12, 0.05, -18.7), ["move_forward", "crouch"], 40, false],
	["11_room1_correndo_norte", Vector3(-9, 0.05, -20), ["move_left", "run"], 70, false],
	["12_room2_centro", Vector3(-13, 0.05, -48), [], 40, false],
	["13_room2_parede_sul", Vector3(-13, 0.05, -54), ["move_right"], 70, false],
	["14_saida_oeste", Vector3(-15, 0.05, -70), [], 40, false],
	["15_room3_centro", Vector3(-13, 0.05, -104), [], 40, false],
	["16_room4_parede_sul", Vector3(-13, 0.05, -134), ["move_right"], 70, false],
	["19_juncao_corredor1_2", Vector3(0, 0.05, -26), ["move_right"], 70, false],
	["20_sala_inicial_para_corredor", Vector3(0, 0.05, -2.5), ["move_right"], 60, false],
	["17_perseguicao_fugindo", Vector3(-15, 0.05, -18.7), ["move_back", "run"], 50, true],
	["18_perseguicao_parede_norte", Vector3(-14, 0.05, -11), ["move_left", "run"], 50, true],
]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.substr(6)
		if arg.begins_with("--tag="): tag = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	player = main.get_node("Player")
	controller = main.get_node("CameraController")
	camera = controller.get_node("Camera3D")
	polvo = main.get_node("Room1Gameplay/Polvo")
	RenderingServer.render_loop_enabled = false
	await _frames(20)

	print("cenario;lum_media;pct_preto;cam_x;cam_y;cam_z;zona;prota_no_quadro;polvo_no_quadro;sobreposicao_px")
	for s in SCENARIOS:
		await _run(s)
	quit()


func _run(s: Array) -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "run", "crouch"]:
		Input.action_release(a)
	if s[4] and polvo.state == 0:
		polvo.activate(&"teste_captura", polvo.global_position, true)
	player.velocity = Vector3.ZERO
	player.global_position = s[1]
	await _frames(3)
	controller.snap_to_target()
	for a in s[2]:
		Input.action_press(a)
	await _frames(s[3])
	for a in s[2]:
		Input.action_release(a)
	RenderingServer.render_loop_enabled = true
	await _render_frames(4)
	var img := root.get_texture().get_image()
	img.save_png("%s/%s_%s.png" % [out_dir, tag, s[0]])
	var m := _metrics(img)
	var zone: Node = controller.current_zone
	var p_rect := _screen_rect(player.global_position, 1.8)
	var m_rect := _screen_rect(polvo.global_position, 3.5)
	var overlap := 0
	if p_rect.has_area() and m_rect.has_area() and polvo.is_active():
		overlap = int(p_rect.intersection(m_rect).get_area())
	var c := camera.global_position
	RenderingServer.render_loop_enabled = false
	print("%s;%.3f;%.1f;%.2f;%.2f;%.2f;%s;%s;%s;%d" % [s[0], m.lum, m.dark * 100.0, c.x, c.y, c.z,
		zone.name if zone else "(padrao)", p_rect.has_area(), m_rect.has_area() and polvo.is_active(), overlap])


func _screen_rect(base: Vector3, height: float) -> Rect2:
	var vp := Rect2(Vector2.ZERO, Vector2(root.size))
	var pts := []
	for h in [0.0, height]:
		for o in [Vector3(-0.3, 0, 0), Vector3(0.3, 0, 0), Vector3(0, 0, -0.3), Vector3(0, 0, 0.3)]:
			var w: Vector3 = base + o + Vector3.UP * h
			if camera.is_position_behind(w):
				return Rect2()
			pts.append(camera.unproject_position(w))
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r.intersection(vp)


func _metrics(img: Image) -> Dictionary:
	var total := 0.0
	var dark := 0
	var n := 0
	for y in range(0, img.get_height(), 6):
		for x in range(0, img.get_width(), 6):
			var l := img.get_pixel(x, y).get_luminance()
			total += l
			if l < 0.02:
				dark += 1
			n += 1
	return {"lum": total / n, "dark": float(dark) / n}


## Desenha alguns quadros com a câmera parada (sombras e exposição estáveis).
func _render_frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _frames(n: int) -> void:
	for i in n:
		await process_frame
