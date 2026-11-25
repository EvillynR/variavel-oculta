extends SceneTree
## Comparação de iluminação da Room 1 (Forward+). A iluminação original fica
## intacta em main.tscn; a proposta é uma cena separada em scenes/proposals,
## instanciada só em tempo de execução por este script (nada é salvo).
## Uso: xvfb-run godot --path . --rendering-driver vulkan --fixed-fps 60 --script res://tests/lighting_compare_capture.gd -- --out=<pasta> --variant=original|p1|p2
## Métrica extra: contraste da protagonista (luminância dela ÷ entorno).
##
## (Base: camera_tour_capture.gd)
## Uso: xvfb-run godot --path . --rendering-driver vulkan --fixed-fps 60 --script res://tests/camera_tour_capture.gd -- --out=<pasta> [--tag=antes]
## Para cada cenário salva um PNG e imprime métricas: luminância média,
## fração de pixels quase pretos, posição da câmera, zona ativa e se a
## protagonista/o monstro aparecem no quadro.

var out_dir := "user://shots"
var tag := "original"
const PROPOSALS := {"p1": "res://scenes/proposals/room1_luz_p1_chao.tscn", "p2": "res://scenes/proposals/room1_luz_p2_parede.tscn"}
var main: Node
var player: CharacterBody3D
var controller: Node3D
var camera: Camera3D
var polvo: Node3D

const SCENARIOS := [
	["04_room1_centro", Vector3(-11, 0.05, -18.7), [], 40, false],
	["06_room1_parede_norte", Vector3(-17, 0.05, -12), ["move_left"], 90, false],
	["07_room1_parede_sul", Vector3(-17, 0.05, -25), ["move_right"], 90, false],
	["08_room1_canto_armario", Vector3(-6, 0.05, -26), ["move_right"], 60, false],
	["09_room1_canto_tabela", Vector3(-17, 0.05, -10), ["move_left"], 60, false],
	["10_room1_norte_leste", Vector3(-8, 0.05, -12), ["move_left"], 60, false],
	["18_perseguicao_parede_norte", Vector3(-14, 0.05, -11), ["move_left", "run"], 50, true],
	["21_perseguicao_parede_sul", Vector3(-14, 0.05, -26), ["move_right", "run"], 50, true],
]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.substr(6)
		if arg.begins_with("--variant="): tag = arg.substr(10)
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	if PROPOSALS.has(tag):
		main.add_child(load(PROPOSALS[tag]).instantiate())
	player = main.get_node("Player")
	controller = main.get_node("CameraController")
	camera = controller.get_node("Camera3D")
	polvo = main.get_node("Room1Gameplay/Polvo")
	RenderingServer.render_loop_enabled = false
	await _frames(20)

	print("cenario;lum_media;pct_preto;lum_prota;lum_entorno;contraste_prota")
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
	img.save_png("%s/luz_%s_%s.png" % [out_dir, tag, s[0]])
	var m := _metrics(img)
	var pr := _screen_rect(player.global_position, 1.8)
	var lp := _region_lum(img, pr, false)
	var le := _region_lum(img, pr, true)
	RenderingServer.render_loop_enabled = false
	print("%s;%.3f;%.1f;%.3f;%.3f;%.2f" % [s[0], m.lum, m.dark * 100.0, lp, le, lp / maxf(le, 0.001)])


## Luminância média dentro do retângulo da protagonista (ou num anel em volta).
func _region_lum(img: Image, r: Rect2, ring: bool) -> float:
	if not r.has_area():
		return 0.0
	var area := r.grow(r.size.x * 1.5) if ring else r
	area = area.intersection(Rect2(Vector2.ZERO, Vector2(img.get_size())))
	var total := 0.0
	var n := 0
	for y in range(int(area.position.y), int(area.end.y), 2):
		for x in range(int(area.position.x), int(area.end.x), 2):
			if ring and r.has_point(Vector2(x, y)):
				continue
			total += img.get_pixel(x, y).get_luminance()
			n += 1
	return total / maxf(n, 1)


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
