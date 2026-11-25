extends SceneTree
## Compara configurações da câmera da Room 1 nos mesmos momentos.
## Uso: godot --path . --rendering-driver opengl3 --script res://tests/camera_compare_capture.gd -- --cfg=A --out=<pasta>
## A/B/C são aplicadas em tempo de execução só na zona Room1Camera (nada é salvo).

const CONFIGS := {
	"A": {"name": "atual", "offset": Vector3(9.5, 3.2, 0.0), "fov": 38.0, "z_limits": false},
	"B": {"name": "mais_alta", "offset": Vector3(9.0, 5.6, 0.0), "fov": 38.0, "z_limits": false},
	"C": {"name": "diagonal_alta", "offset": Vector3(7.5, 5.2, 5.0), "fov": 40.0, "z_limits": true, "zmin": -29.3, "zmax": -8.0},
	# D/E: câmera ao sul, com corte da parede sul da Room 1 (z = -30).
	"D": {"name": "lateral_90", "offset": Vector3(0.0, 5.0, -10.5), "fov": 40.0, "z_limits": true, "zmin": -36.0, "zmax": -12.0, "cut_south": true},
	"E": {"name": "diagonal_60", "offset": Vector3(5.0, 5.0, -9.0), "fov": 40.0, "z_limits": true, "zmin": -36.0, "zmax": -12.0, "cut_south": true},
}
const SOUTH_WALL := ["../School/Room 1/WallNorthRight_Upper", "../School/Room 1/WallNorthRight_Trim", "../School/Room 1/WallNorthRight_Lower"]

var main: Node
var player: CharacterBody3D
var polvo: MonsterController
var camera: Camera3D
var out_dir := "/home/claude/work/shots_cmp"
var key := "A"
var caught := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cfg="): key = arg.substr(6)
		if arg.begins_with("--out="): out_dir = arg.substr(6)
	var render := DisplayServer.get_name() != "headless"
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	if render:
		RenderingServer.render_loop_enabled = false
	player = main.get_node("Player")
	polvo = main.get_node("Room1Gameplay/Polvo")
	camera = main.get_node("CameraController/Camera3D")
	polvo.player_caught.connect(func(): caught = true)

	var cfg: Dictionary = CONFIGS[key]
	var zone = main.get_node("Room1Camera")
	zone.camera_offset = cfg.offset
	zone.camera_fov = cfg.fov
	zone.use_z_limits = cfg.z_limits
	if cfg.z_limits:
		zone.minimum_camera_z = cfg.zmin
		zone.maximum_camera_z = cfg.zmax
	if cfg.get("cut_south", false):
		var paths: Array[NodePath] = zone.occluder_paths.duplicate()
		for path in SOUTH_WALL:
			paths.append(NodePath(path))
		zone.occluder_paths = paths
	await _wait(0.5)

	# Oclusão por paredes nesta configuração (grade da Room 1).
	var blocked := 0
	var samples := 0
	for ix in 4:
		for iz in 5:
			var p := Vector3(lerpf(-22.5, -4.5, ix / 3.0), 0.05, lerpf(-29.0, -8.5, iz / 4.0))
			await _tp(p)
			samples += 1
			for h in [0.4, 1.0]:
				if not _clear(camera.global_position, p + Vector3.UP * h):
					blocked += 1
	print("[%s] oclusão por paredes na Room 1: %d bloqueios em %d pontos" % [key, blocked, samples])

	# 1. Antes da ativação
	await _tp(Vector3(-9.0, 0.05, -18.0)); await _wait(1.5)
	await _shot("1_antes_da_ativacao")
	# Ativação pelo experimento (tecla física E)
	await _tp(Vector3(-13.2, 0.05, -24.0)); await _wait(0.5)
	await _key_e()
	await _tp(Vector3(-9.0, 0.05, -18.0))
	# 2. Aproximação (primeira vez a ≤ 6 m)
	var t := 0.0
	while _dist() > 6.0 and t < 15.0:
		await physics_frame; t += 1.0 / 60.0
	await _shot("2_aproximacao")
	# 3. Alcance
	t = 0.0
	while not caught and t < 10.0:
		await physics_frame; t += 1.0 / 60.0
	await _wait(0.3)
	await _shot("3_alcance")
	# 4. Procura no corredor
	await _tp(Vector3(0.0, 0.05, -12.0)); await _wait(2.5)
	await _shot("4_procura_no_corredor")
	quit()


func _shot(moment: String) -> void:
	var overlap := _screen_overlap()
	var line := "[%s] %-22s estado=%-9s dist=%4.1f m  sobreposição=%3d%%  separação=%4.2f  monstro_na_frente=%s" % [
		key, moment, polvo.get_state_name(), _dist(), int(overlap.ratio * 100.0), overlap.separation, overlap.monster_in_front]
	print(line)
	if DisplayServer.get_name() == "headless":
		return
	RenderingServer.render_loop_enabled = true
	for i in 3:
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s_%s_%s.png" % [out_dir, key, CONFIGS[key].name, moment])
	RenderingServer.render_loop_enabled = false


## Fração do retângulo da protagonista na tela coberta pelo retângulo do Polvo.
func _screen_overlap() -> Dictionary:
	var pr := _rect(player.global_position, 0.25, 0.35, 2.15)
	var mr := _rect(polvo.global_position, 0.6, 0.0, 3.5)
	var inter := pr.intersection(mr)
	var ratio := 0.0
	if pr.get_area() > 0.0 and inter.size.x > 0.0 and inter.size.y > 0.0:
		ratio = inter.get_area() / pr.get_area()
	var cam := camera.global_position
	# Separação horizontal dos centros / soma das meias-larguras (>= 1: silhuetas não se cruzam).
	var separation := absf(pr.get_center().x - mr.get_center().x) / maxf(1.0, (pr.size.x + mr.size.x) * 0.5)
	return {"ratio": ratio, "separation": separation, "monster_in_front": cam.distance_to(polvo.global_position) < cam.distance_to(player.global_position)}


func _rect(base: Vector3, radius: float, y0: float, y1: float) -> Rect2:
	var pts := []
	for dx in [-radius, radius]:
		for dz in [-radius, radius]:
			for y in [y0, y1]:
				pts.append(camera.unproject_position(base + Vector3(dx, y, dz)))
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


func _clear(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [player.get_rid()]
	var space := player.get_world_3d().direct_space_state
	for i in 10:
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return true
		var c = hit.collider
		if c is GeometryInstance3D and (not c.is_visible_in_tree() or c.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY):
			q.exclude = q.exclude + [hit.rid]
			continue
		return false
	return true


func _dist() -> float:
	return Vector2(polvo.global_position.x - player.global_position.x, polvo.global_position.z - player.global_position.z).length()


func _tp(p: Vector3) -> void:
	player.global_position = p
	player.velocity = Vector3.ZERO
	await physics_frame; await physics_frame
	main.get_node("CameraController").snap_to_target()
	await physics_frame


func _key_e() -> void:
	await physics_frame
	var ev := InputEventKey.new(); ev.physical_keycode = KEY_E; ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame; await process_frame
	var up := InputEventKey.new(); up.physical_keycode = KEY_E; up.pressed = false
	Input.parse_input_event(up)
	await physics_frame


func _wait(s: float) -> void:
	for i in int(s * 60): await physics_frame
