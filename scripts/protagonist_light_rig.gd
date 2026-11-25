extends Node3D
## Iluminação de leitura da protagonista (Prioridade 1, item 1).
##
## Causa medida do "quase preta": todas as luzes do cenário são SpotLights no
## teto apontadas para baixo. O chão e o topo dos móveis recebem luz direta,
## mas o lado da protagonista voltado para a câmera (lateral, a ~9 m) tem normal
## horizontal: N·L ≈ 0, só recebe o ambiente (azul escuro × 0,45). Sombras não
## eram a causa (desligá-las não mudou a luminância medida).
##
## Solução (sem clarear a cena): luzes presas à protagonista que afetam SÓ a
## camada visual 11 (a protagonista é colocada também nessa camada):
##   - Key: preenchimento suave vindo do lado da câmera (revela volume e forma).
##   - Rim: contraluz fria por trás, destaca a silhueta contra o fundo escuro.
## E um halo local fraco (Aura) que ilumina o cenário só num raio curto em volta
## dela, para o chão, os obstáculos e os objetos próximos serem legíveis. A
## Aura projeta sombra para não vazar para o outro lado das paredes.
## As luzes originais do cenário, o ambiente e a exposição não foram alterados.

## Camada visual exclusiva da protagonista (1..20). As luzes do cenário usam
## light_cull_mask 0xFFFFFC01, que inclui a camada 11, então ela continua
## recebendo a luz original normalmente.
@export_range(1, 20) var protagonist_layer: int = 11
@export var target_path: NodePath = NodePath("../Visual")

@export_group("Key (lado da câmera)")
@export var key_color: Color = Color(0.96, 0.9, 0.82)
@export var key_energy: float = 1.6
@export var key_range: float = 3.2
@export var key_distance: float = 1.6
@export var key_height: float = 1.7
## Desvio lateral em relação à câmera (graus), dá modelado em vez de luz chapada.
@export var key_side_degrees: float = 35.0

@export_group("Rim (contraluz)")
@export var rim_color: Color = Color(0.62, 0.76, 1.0)
@export var rim_energy: float = 2.2
@export var rim_range: float = 2.6
@export var rim_distance: float = 1.1
@export var rim_height: float = 1.9

@export_group("Aura (cenário próximo)")
@export var aura_enabled: bool = true
@export var aura_color: Color = Color(0.7, 0.78, 0.92)
@export var aura_energy: float = 0.3
@export var aura_range: float = 3.6
@export var aura_height: float = 1.9
@export var aura_shadows: bool = true

var key_light: OmniLight3D
var rim_light: OmniLight3D
var aura_light: OmniLight3D


func _ready() -> void:
	var mask := 1 << (protagonist_layer - 1)
	var target := get_node_or_null(target_path) as VisualInstance3D
	if target != null:
		target.layers |= mask

	key_light = _make_light("KeyLight", key_color, key_energy, key_range, mask, false)
	rim_light = _make_light("RimLight", rim_color, rim_energy, rim_range, mask, false)
	if aura_enabled:
		# Mesma máscara das luzes do cenário: ilumina o que elas iluminam.
		aura_light = _make_light("AuraLight", aura_color, aura_energy, aura_range, 0xFFFFFC01, aura_shadows)
		aura_light.omni_attenuation = 2.2
		# Sem brilho especular: evita a mancha clara nas paredes encostadas.
		aura_light.light_specular = 0.0
		aura_light.position = Vector3(0.0, aura_height, 0.0)
	_place_lights()


func _process(_delta: float) -> void:
	_place_lights()


## Key e Rim acompanham a direção da câmera (vista horizontal).
func _place_lights() -> void:
	var camera := get_viewport().get_camera_3d()
	var to_camera := Vector3(0.0, 0.0, 1.0)
	if camera != null:
		to_camera = camera.global_position - global_position
		to_camera.y = 0.0
		if to_camera.length() < 0.01:
			to_camera = camera.global_basis.z
			to_camera.y = 0.0
		to_camera = to_camera.normalized()
	var key_dir := to_camera.rotated(Vector3.UP, deg_to_rad(key_side_degrees))
	key_light.global_position = global_position + key_dir * key_distance + Vector3.UP * key_height
	rim_light.global_position = global_position - to_camera * rim_distance + Vector3.UP * rim_height


func _make_light(light_name: String, color: Color, energy: float, light_range: float, cull: int, shadows: bool) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = light_name
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.light_cull_mask = cull
	light.shadow_enabled = shadows
	light.light_specular = 0.25
	add_child(light)
	return light
