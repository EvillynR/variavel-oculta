extends SceneTree
## Prompt 1 — varredura de piso: em toda a área caminhável, a cada 0,5 m, um
## raio vertical precisa encontrar piso na altura certa (nunca o FallSafety,
## nunca vazio). Também confere as soleiras de todas as portas e a rampa.
## Uso: godot --headless --path . --script res://tests/floor_sweep_test.gd

## nome, x0, x1, z0, z1, altura do piso
const AREAS := [
	["sala inicial", -5.7, 4.7, -3.7, 3.7, 0.0],
	["corredores 1–5", -3.3, 2.7, -189.8, -4.2, 0.0],
	["Room 1", -23.2, -3.8, -29.6, -7.8, 0.0],
	["Room 2", -23.2, -3.8, -58.2, -37.8, 0.0],
	["Artes (Exit)", -23.2, -3.8, -83.2, -58.8, 0.0],
	["Room 3", -23.2, -3.8, -115.8, -92.8, 0.0],
	["Room 4", -23.2, -3.8, -137.6, -117.2, 0.0],
	["Música", -23.2, -3.8, -184.7, -165.3, 0.0],
	["patamar do subsolo", -3.3, 2.7, -191.9, -190.2, 0.0],
	["corredor subterrâneo", -3.3, 2.7, -227.7, -210.3, -6.0],
	["Sala de Monitoramento", -17.2, -3.8, -225.7, -212.3, -6.0],
]
const THRESHOLDS := [
	Vector3(0, 0, -4.0), Vector3(-3.5, 0, -10.5), Vector3(-3.5, 0, -40.5), Vector3(-3.5, 0, -71.0), Vector3(-3.5, 0, -95.5),
	Vector3(-3.5, 0, -119.9), Vector3(-3.5, 0, -175.0), Vector3(0, 0, -190.0), Vector3(-3.5, -6, -219.0),
	Vector3(0, 0, -28.4), Vector3(0, 0, -52.9), Vector3(0, 0, -89.6), Vector3(0, 0, -114.1), Vector3(0, 0, -138.0),
]

var passed := 0
var failed := 0
var space: PhysicsDirectSpaceState3D


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 4:
		await physics_frame
	space = main.get_world_3d().direct_space_state
	for a in AREAS:
		var holes: Array[String] = []
		var n := 0
		var x: float = a[1]
		while x <= a[2] + 0.001:
			var z: float = a[3]
			while z <= a[4] + 0.001:
				n += 1
				var why := _probe(Vector3(x, a[5], z))
				if why != "" and holes.size() < 6:
					holes.append("(%.1f, %.1f) %s" % [x, z, why])
				elif why != "":
					holes.append("…")
				z += 0.5
			x += 0.5
		_check("%s: %d pontos com piso na altura certa" % [a[0], n], holes.is_empty(), ", ".join(holes.slice(0, 7)))
	var bad: Array[String] = []
	for t in THRESHOLDS:
		for off in [-0.3, 0.0, 0.3]:
			var p: Vector3 = t + (Vector3(off, 0, 0) if absf(t.x + 3.5) < 0.01 else Vector3(0, 0, off))
			var why := _probe(p)
			if why != "":
				bad.append("(%.1f, %.1f) %s" % [p.x, p.z, why])
	_check("14 soleiras/passagens com piso contínuo", bad.is_empty(), ", ".join(bad))
	var ramp_bad: Array[String] = []
	var zz := -192.2
	while zz >= -209.8:
		var expected := -6.0 * (-192.0 - zz) / 18.0
		for xx in [-3.0, 0.0, 2.5]:
			var why := _probe(Vector3(xx, expected, zz), 0.08)
			if why != "":
				ramp_bad.append("(%.1f, %.1f) %s" % [xx, zz, why])
		zz -= 0.5
	_check("rampa: piso contínuo, inclinação 18,4° (0 → −6 m)", ramp_bad.is_empty(), ", ".join(ramp_bad.slice(0, 6)))
	print("RESULTADO: %d/%d testes passaram" % [passed, passed + failed])
	quit(1 if failed > 0 else 0)


func _probe(p: Vector3, tol: float = 0.05) -> String:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p + Vector3.DOWN * 2.0, 1)
	var hit := space.intersect_ray(q)
	# Móveis (mesa, carteiras): o raio ignora o que estiver acima do piso e
	# continua descendo — o que importa é existir piso por baixo.
	var skip: Array[RID] = []
	while not hit.is_empty() and hit.position.y > p.y + tol and skip.size() < 4:
		skip.append(hit.rid)
		q.exclude = skip
		hit = space.intersect_ray(q)
	if hit.is_empty():
		return "sem piso"
	if hit.collider is Node and String(hit.collider.name) == "FallSafety":
		return "só o FallSafety"
	if absf(hit.position.y - p.y) > tol:
		return "piso em y=%.2f" % hit.position.y
	return ""


func _check(label: String, ok: bool, info: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("%s %s  %s" % ["OK    " if ok else "FALHA ", label, info])
