extends SceneTree
## Versão 6.2 — capturas dos modelos novos (renderização real).
## Uso: xvfb-run godot --path . --rendering-driver vulkan --fixed-fps 60 --script res://tests/v62_capturas.gd -- --out=<pasta>

var out_dir := "user://v62"
var main: Node
var player: CharacterBody3D
var director
var shots := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	SaveSystem.save_path = "user://teste_v62_capturas.json"
	SaveSystem.delete_save()
	# começa como o atalho de apresentação da Sala 1 (sem a abertura)
	SaveSystem.write_save(JSON.parse_string(FileAccess.get_file_as_string("res://data/apresentacao/room_1.json")))
	SaveSystem.pending_action = "continue"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _phys(4)
	player = main.get_node("Player")
	director = get_first_node_in_group("story_director")
	var gom := get_first_node_in_group("game_over_ui")
	await _phys(60)
	await _until(func(): return not director.cutscenes.playing, 3000)
	director.enabled = false
	await _phys(10)
	paused = false
	var ui := get_first_node_in_group("cutscene_player")
	# --- Leitora na sala de Português
	var leitor: MonsterController = main.get_node("MonsterRoster/Leitor")
	var lf := -leitor.global_basis.z
	await _place(leitor.global_position - lf * 5.5, leitor.global_position)
	_frame(leitor)
	await _phys(5)
	await _shot("leitora_escrevendo")
	leitor.activate(&"teste", player.global_position, true)
	for i in 50:
		leitor.hunt(player.global_position)
		await physics_frame
	await _shot("leitora_perseguindo")
	var w := 0
	while not gom.dying and w < 600:
		leitor.hunt(player.global_position)
		await physics_frame
		w += 1
	await _wait(0.5)
	await _shot("leitora_matando_yuko_morrendo")
	await _wait(1.2)
	await _shot("yuko_morta")
	gom.dismiss()
	leitor.deactivate(true)
	await _phys(10)
	# --- Maestro
	var m: MonsterController = main.get_node("MonsterRoster/Maestro")
	m.deactivate(true)
	var mf := -m.global_basis.z
	await _place(m.global_position + mf * 6.5, m.global_position)
	_frame(m)
	m.activate(&"teste", player.global_position, true)
	m.hunt(player.global_position)
	await _wait(0.5)
	await _shot("maestro_ouve_vira_cabeca")
	w = 0
	while not m.is_gripping() and w < 900:
		m.hunt(player.global_position)
		await physics_frame
		w += 1
	await _wait(1.0)
	await _shot("maestro_levitando_yuko")
	await _until(func(): return gom.dying, 600)
	await _wait(0.9)
	await _shot("maestro_yuko_morrendo_no_ar")
	print("capturas: ", shots)
	quit(0)


func _place(pos: Vector3, look: Vector3) -> void:
	player.global_position = pos + Vector3(0, 0.05, 0)
	player.velocity = Vector3.ZERO
	var d := look - pos
	player.visual.rotation.y = atan2(d.x, d.z)
	await _phys(6)
	var gc := get_first_node_in_group("camera_controller")
	if gc != null and gc.has_method("snap_to_target"):
		gc.snap_to_target()
	await _phys(30)


var _cam: Camera3D
var _cam_target: Node3D
var _cam_side := 1.0
## Luz extra só para os prints (o jogo é bem mais escuro).
var _fill: OmniLight3D


## Câmera própria para os prints: na frente do professor, enquadrando ele e a Yuko.
func _frame(monster: Node3D, dist: float = 7.5, height: float = 3.4) -> void:
	var gc := get_first_node_in_group("camera_controller")
	if gc != null:
		gc.process_mode = Node.PROCESS_MODE_DISABLED
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 55.0
		main.add_child(_cam)
	_cam_target = monster
	if _fill == null:
		_fill = OmniLight3D.new()
		_fill.light_energy = 2.2
		_fill.omni_range = 14.0
		_fill.light_color = Color(0.9, 0.88, 1.0)
		main.add_child(_fill)
	_aim()
	_cam.make_current()


func _aim() -> void:
	if _cam == null or _cam_target == null:
		return
	var p := _cam_target.global_position
	var mid := (p + player.global_position) * 0.5
	var fwd := player.global_position - p
	fwd.y = 0
	fwd = fwd.normalized() if fwd.length() > 0.2 else -_cam_target.global_basis.z
	var side := fwd.cross(Vector3.UP).normalized()
	_cam.global_position = mid + fwd * 6.5 + side * 2.0 * _cam_side + Vector3(0, 4.6, 0)
	if _fill != null:
		_fill.global_position = mid + fwd * 2.5 + Vector3(0, 4.5, 0)
	_cam.look_at(mid + Vector3(0, 1.3, 0), Vector3.UP)


func _shot(name: String) -> void:
	_aim()
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
