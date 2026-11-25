extends Node3D
## Entulho espalhado: tábuas, carteiras quebradas tombadas, cadeira caída,
## papéis molhados e poças d'água.

@export var semente := 3
@export var raio := 6.0
@export var tabuas := 14
@export var papeis := 26
@export var pocas := 4


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	for i in tabuas:
		var p := Vector3(rng.randf_range(-raio, raio), 0.06, rng.randf_range(-raio, raio))
		DecoUtil.box(self, Vector3(rng.randf_range(1.2, 2.8), 0.08, rng.randf_range(0.18, 0.3)), p, "madeira",
			Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU, rng.randf_range(-0.1, 0.1)))
	for i in papeis:
		var p2 := Vector3(rng.randf_range(-raio, raio), 0.012, rng.randf_range(-raio, raio))
		DecoUtil.box(self, Vector3(0.32, 0.005, 0.24), p2, "tecido", Vector3(0, rng.randf() * TAU, 0), false)
	for i in pocas:
		var p3 := Vector3(rng.randf_range(-raio, raio), 0.006, rng.randf_range(-raio, raio))
		DecoUtil.cyl(self, rng.randf_range(0.8, 1.8), rng.randf_range(0.8, 1.8), 0.01, p3, "poca", Vector3.ZERO, 20)
	# carteira quebrada tombada (escala 3x)
	var desk := Node3D.new()
	desk.position = Vector3(raio * 0.4, 0, -raio * 0.3)
	desk.rotation = Vector3(0, 0.7, deg_to_rad(78))
	add_child(desk)
	DecoUtil.box(desk, Vector3(3.0, 0.12, 1.8), Vector3(0, 2.2, 0), "madeira")
	for x in [-1.3, 1.3]:
		for z in [-0.7, 0.7]:
			DecoUtil.box(desk, Vector3(0.1, 2.2, 0.1), Vector3(x, 1.1, z), "metal")
	DecoUtil.solid(self, Vector3(2.4, 1.4, 3.2), desk.position + Vector3(0, 0.7, 0), Vector3(0, 0.7, 0))
	DecoUtil.merge(self)
