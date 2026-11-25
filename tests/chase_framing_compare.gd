extends SceneTree
## Compara enquadramentos da Room 1 (aplicados só em tempo de execução, nada é
## salvo) em duas situações: aproximação do Polvo e fuga em perseguição.
## Mede, quadro a quadro, a sobreposição entre protagonista e monstro na tela,
## se ambos estão no quadro e a distância da câmera.
## Uso: godot --headless --path . --script res://tests/chase_framing_compare.gd

const CONFIGS := {
	"A_original": {"offset": Vector3(9.5, 3.2, 0), "fov": 38.0},
	"B_atual": {"offset": Vector3(9.0, 5.6, 0), "fov": 38.0},
	"B_mais_alta": {"offset": Vector3(9.0, 6.3, 0), "fov": 38.0},
	"B_mais_longe": {"offset": Vector3(10.5, 5.6, 0), "fov": 38.0},
	"B_alta_aberta": {"offset": Vector3(8.5, 6.2, 0), "fov": 42.0},
}

var main: Node
var player: CharacterBody3D
var controller: Node3D
var camera: Camera3D
var polvo: MonsterController
var zone: Node


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _physics(10)
	player = main.get_node("Player")
	controller = main.get_node("CameraController")
	camera = controller.get_node("Camera3D")
	polvo = main.get_node("Room1Gameplay/Polvo")
	zone = main.get_node("Room1Camera")
	while not polvo.is_navigation_ready():
		await _physics(1)
	var home := polvo.global_position

	print("config;cena;quadros;sobreposicao_media_%;quadros_sobrepostos_%;prota_no_quadro_%;polvo_no_quadro_%;polvo_maior_que_prota_%")
	for key in CONFIGS:
		zone.camera_offset = CONFIGS[key]["offset"]
		zone.camera_fov = CONFIGS[key]["fov"]
		controller.refresh_camera_profile()

		# 1) aproximação: Polvo parado no posto, protagonista anda da porta até ele.
		polvo._change_state(MonsterController.State.INACTIVE)
		polvo.global_position = home
		polvo.rotation.y = -PI / 2.0
		await _teleport(Vector3(-4.5, 0.05, -18.7))
		var m := _new_metrics()
		for i in 230:
			await _step("move_forward", [])
			_measure(m)
		_report(key, "aproximacao", m)

		# 2) perseguição: Polvo acordado, protagonista foge (andando e correndo).
		for mode in [[], ["run"]]:
			polvo.global_position = Vector3(-20.0, home.y, -18.7)
			polvo.rotation.y = -PI / 2.0
			polvo._change_state(MonsterController.State.PATROLLING)
			await _teleport(Vector3(-14.5, 0.05, -18.7))
			await _physics(40)
			m = _new_metrics()
			for leg in [["move_right", 70], ["move_back", 110], ["move_left", 60]]:
				for i in leg[1]:
					await _step(leg[0], mode)
					_measure(m)
			_report(key, "fuga_" + ("correndo" if mode.size() > 0 else "andando"), m)
	quit()


func _new_metrics() -> Dictionary:
	return {"n": 0, "overlap_sum": 0.0, "overlap_frames": 0, "player_in": 0, "monster_in": 0, "monster_bigger": 0}


func _measure(m: Dictionary) -> void:
	m["n"] += 1
	var pr := _rect(player.global_position, 1.8, 0.3)
	var mr := _rect(polvo.global_position, 3.5, 0.6)
	if pr.has_area() and _inside(pr):
		m["player_in"] += 1
	if mr.has_area() and _inside(mr):
		m["monster_in"] += 1
	if pr.has_area() and mr.has_area():
		var ov := pr.intersection(mr).get_area() / pr.get_area()
		m["overlap_sum"] += ov
		if ov > 0.25:
			m["overlap_frames"] += 1
		if mr.get_area() > pr.get_area():
			m["monster_bigger"] += 1


func _report(key: String, scene: String, m: Dictionary) -> void:
	var n: float = maxf(m["n"], 1)
	print("%s;%s;%d;%.1f;%.1f;%.1f;%.1f;%.1f" % [key, scene, m["n"], 100.0 * m["overlap_sum"] / n,
		100.0 * m["overlap_frames"] / n, 100.0 * m["player_in"] / n, 100.0 * m["monster_in"] / n, 100.0 * m["monster_bigger"] / n])


## Retângulo na tela normalizada (-1..1) de uma cápsula, por projeção manual.
func _rect(base: Vector3, height: float, radius: float) -> Rect2:
	var inv := camera.global_transform.affine_inverse()
	var tan_v := tan(deg_to_rad(camera.fov) * 0.5)
	var tan_h := tan_v * 16.0 / 9.0
	var r := Rect2()
	var first := true
	for h in [0.0, height]:
		for o in [Vector3(-radius, 0, 0), Vector3(radius, 0, 0), Vector3(0, 0, -radius), Vector3(0, 0, radius)]:
			var l: Vector3 = inv * (base + o + Vector3.UP * h)
			if l.z >= -0.05:
				return Rect2()
			var s := Vector2(l.x / -l.z / tan_h, l.y / -l.z / tan_v)
			if first:
				r = Rect2(s, Vector2.ZERO)
				first = false
			else:
				r = r.expand(s)
	return r


func _inside(r: Rect2) -> bool:
	return Rect2(-1, -1, 2, 2).encloses(r)


func _step(action: String, mods: Array) -> void:
	Input.action_press(action)
	for a in mods:
		Input.action_press(a)
	await physics_frame
	await process_frame
	Input.action_release(action)


func _teleport(p: Vector3) -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "run", "crouch"]:
		Input.action_release(a)
	player.velocity = Vector3.ZERO
	player.global_position = p
	await _physics(3)
	controller.snap_to_target()
	await _physics(2)


func _physics(n: int) -> void:
	for i in n:
		await physics_frame
