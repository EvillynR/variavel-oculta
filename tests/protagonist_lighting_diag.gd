extends SceneTree
## Diagnóstico da protagonista escura (Prioridade 1). Nada é salvo nas cenas:
## cada variante é aplicada só em memória, para isolar a causa.
## Uso: xvfb-run godot --path . --rendering-driver vulkan --fixed-fps 60 --script res://tests/protagonist_lighting_diag.gd -- --out=<pasta>

var out_dir := "user://diag"
var main: Node
var player: CharacterBody3D
var controller: Node3D
var camera: Camera3D

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	print("variante;lum_prota;lum_entorno;visual_y;base_mesh;topo_mesh")
	for v in ["base", "sem_sombra_luzes", "sem_autosombra", "ambiente_x3", "luz_lateral"]:
		await _run(v)
	quit()

func _run(v: String) -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	player = main.get_node("Player")
	controller = main.get_node("CameraController")
	camera = controller.get_node("Camera3D")
	RenderingServer.render_loop_enabled = false
	await _frames(10)
	player.global_position = Vector3(-11, 0.05, -18.7)
	await _frames(20)
	controller.snap_to_target()
	await _frames(10)
	var vis: MeshInstance3D = player.get_node("Visual")
	match v:
		"sem_sombra_luzes":
			for l in main.find_children("*", "Light3D", true, false):
				l.shadow_enabled = false
		"sem_autosombra":
			vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"ambiente_x3":
			main.get_node("WorldEnvironment").environment.ambient_light_energy *= 3.0
		"luz_lateral":
			var o := OmniLight3D.new()
			player.add_child(o)
			o.position = Vector3(1.2, 1.4, 0)
			o.light_energy = 0.8
			o.omni_range = 3.0
	RenderingServer.render_loop_enabled = true
	for i in 6:
		await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/diag_%s.png" % [out_dir, v])
	var r := _screen_rect(player.global_position, 1.8)
	var mesh_h: float = (vis.mesh as CapsuleMesh).height * vis.scale.y
	print("%s;%.3f;%.3f;%.2f;%.2f;%.2f" % [v, _region_lum(img, r, false), _region_lum(img, r, true),
		vis.position.y, vis.global_position.y - mesh_h * 0.5 - player.global_position.y, vis.global_position.y + mesh_h * 0.5 - player.global_position.y])
	RenderingServer.render_loop_enabled = false
	main.queue_free()
	await _frames(3)

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
		for o in [Vector3(-0.2, 0, 0), Vector3(0.2, 0, 0), Vector3(0, 0, -0.2), Vector3(0, 0, 0.2)]:
			var w: Vector3 = base + o + Vector3.UP * h
			if camera.is_position_behind(w):
				return Rect2()
			pts.append(camera.unproject_position(w))
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r.intersection(vp)

func _frames(n: int) -> void:
	for i in n:
		await process_frame
