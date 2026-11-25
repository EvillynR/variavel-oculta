extends Node3D
## Versão 5.4 (desempenho): o pátio "dorme" quando a Yuko está longe dele.
## A luz do luar (com sombra, alcance de 48 m), as lanternas, a luz ambiente,
## as pétalas caindo e os enfeites custavam ~60% do quadro mesmo com o pátio
## fora da tela. Paredes e chão (CSG, com colisão) continuam sempre ativos.

## Faixa do corredor (z) em que o pátio aparece: o próprio pátio e a porta.
@export var z_min := -94.0
@export var z_max := -48.0
@export var check_every := 0.25

var _player: Node3D
var _awake := true
var _clock := 0.0


func _ready() -> void:
	# Versão 5.6: roda também com o jogo pausado (as cenas de filme pausam o
	# jogo — antes o pátio ficava "dormindo" e a abertura mostrava só parede).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_awake = true
	_clock = check_every


func _process(delta: float) -> void:
	_clock += delta
	if _clock < check_every:
		return
	_clock = 0.0
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	# acorda se a Yuko OU a câmera (de jogo ou de cinema) estiver perto
	var near := false
	if _player != null:
		near = _near(_player.global_position.z)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		near = near or _near(cam.global_position.z)
	_set_awake(near)


func _near(z: float) -> bool:
	return z > z_min and z < z_max


## Para as cenas de filme que mostram o pátio (abertura, mapa).
func wake() -> void:
	_set_awake(true)


func _set_awake(on: bool) -> void:
	_set_fog(on)
	if on == _awake:
		return
	_awake = on
	for c in get_children():
		if c is CSGShape3D or c is FogVolume:
			continue
		if c is Node3D:
			(c as Node3D).visible = on
	for p in find_children("*", "CPUParticles3D", true, false):
		(p as CPUParticles3D).emitting = on


## A névoa baixa do pátio (FogVolume) precisa da névoa volumétrica ligada; ela
## custa caro, então só fica ligada enquanto o pátio está acordado.
func _set_fog(on: bool) -> void:
	var we := get_tree().get_first_node_in_group("world_environment") as WorldEnvironment
	if we == null:
		for n in get_tree().current_scene.find_children("*", "WorldEnvironment", true, false) if get_tree().current_scene else []:
			we = n
			we.add_to_group("world_environment")
			break
	if we != null and we.environment != null and we.environment.volumetric_fog_enabled != on:
		we.environment.volumetric_fog_enabled = on
