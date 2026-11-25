extends Node3D
## Lanterna de pedra japonesa (tōrō) com uma chama fraca dentro.

@export var escala := 1.6
@export var acesa := true


const MODELO := "res://assets/models/toro.glb"


func _ready() -> void:
	var k := escala
	# a lanterna inteira fica translúcida se ficar entre a câmera e a Yuko
	add_to_group("camera_fade")
	# Versão 5.4: o modelo da lanterna de pedra (farolillo) no lugar das caixas
	var altura := 2.45 * k
	if ResourceLoader.exists(MODELO):
		var m := ModeloProp.new()
		m.name = "Modelo"
		add_child(m)
		m.caixa = Vector3(3.2, altura, 3.2) * Vector3(k / 1.6, 1.0, k / 1.6)
		m.ajuste = 2
		m.modelo = load(MODELO)
	else:
		DecoUtil.box(self, Vector3(0.9, 0.25, 0.9) * k, Vector3(0, 0.125 * k, 0), "pedra")
		DecoUtil.cyl(self, 0.16 * k, 0.2 * k, 1.0 * k, Vector3(0, 0.75 * k, 0), "pedra", Vector3.ZERO, 8)
		DecoUtil.box(self, Vector3(0.55, 0.5, 0.55) * k, Vector3(0, 1.65 * k, 0), "pedra")
	if acesa:
		DecoUtil.box(self, Vector3(0.3, 0.28, 0.3) * k, Vector3(0, altura * 0.55, 0), "lampiao", Vector3.ZERO, false)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.62, 0.3)
		light.light_energy = 0.9
		light.omni_range = 5.5
		light.shadow_enabled = false
		light.position = Vector3(0, altura * 0.55, 0)
		add_child(light)
	DecoUtil.solid(self, Vector3(0.9, 2.5, 0.9) * Vector3(k, 1.0, k), Vector3(0, 1.25, 0))
	DecoUtil.merge(self)
