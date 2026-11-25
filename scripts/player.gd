extends CharacterBody3D
## Protagonista. Prioridade 1: correções pontuais de movimento, colisão e
## posicionamento — o modelo (cápsula placeholder) e os controles foram mantidos.
##
## Ações usadas (project.godot): move_forward/back/left/right (WASD), run (Shift),
## crouch (Ctrl). "interact" (E) é lido por PlayerInteractor. "Jump" e "pause"
## existem no mapa de entrada mas AINDA NÃO têm comportamento implementado.

signal move_state_changed(previous: int, current: int)
## Prompt 2: esconderijo e ruído dos passos.
signal hidden_changed(hidden: bool)
signal noise_emitted(stimulus: SoundStimulus)

enum MoveState { IDLE, WALK, RUN, CROUCH }

@export var walking_speed: float = 3.5
@export var running_speed: float = 6.0
@export var crouching_speed: float = 2.0
@export var gravity: float = 20.0

@export_group("Colisão e deslizamento")
## Altura da cápsula em pé / agachada (o modelo acompanha a colisão).
@export var standing_height: float = 1.8
@export var crouching_height: float = 1.1
## Ao encostar numa parede/batente quase de frente, garante pelo menos esta
## fração da velocidade ao longo da superfície (evita "grudar" nos batentes).
@export_range(0.0, 1.0, 0.05) var wall_slide_min_ratio: float = 0.55
## Abaixo deste ângulo (graus) entre o input e a normal da parede, é "de frente":
## não desliza (empurrar reto contra a parede continua parando).
@export var wall_slide_dead_angle: float = 4.0

@export_group("Referencial de controle")
## Enquanto uma tecla de movimento fica pressionada, mudanças AUTOMÁTICAS da
## câmera (troca de composição, corte ao entrar numa sala) não giram o controle:
## a direção fica travada até soltar a tecla (0 = trava total). O giro feito
## pelo jogador com as setas vale na hora. Valor > 0 realinha devagar (rad/s).
@export var control_realign_speed: float = 0.0

## Visual da protagonista: um Node3D com o modelo animado da Yuko
## (scenes/player/yuko_model.tscn, pés na origem). Se for uma malha (cápsula
## provisória antiga), o comportamento antigo de esticar a cápsula continua.
@onready var visual: Node3D = $Visual
@onready var collision: CollisionShape3D = $CollisionShape3D

var can_move: bool = true
var is_crouching: bool = false
var is_running: bool = false
var move_state: int = MoveState.IDLE

var _control_yaw: float = 0.0
var _held_yaw: float = 0.0
var _held_user_yaw: float = 0.0
var _holding: bool = false
var _mesh_height: float = 1.1

# Prompt 2 — esconderijo
var hiding_spot: Node3D = null
var _hide_witnesses: Array = []
## Distância (m) em que o monstro, vendo ela se esconder, ainda sabe onde ela está.
const WITNESS_DISTANCE := 3.5
var _saved_layer: int = 1
var _saved_mask: int = 1

# Prompt 2 — ruído (valores em data/game_data.json, seção "player_noise")
const NOISE_DEFAULTS := {
	"walk": {"loudness": 0.55, "interval": 0.5},
	"run": {"loudness": 1.0, "interval": 0.35},
	"crouch": {"loudness": 0.15, "interval": 0.7},
}
var noise_enabled: bool = true
## Versão 6.2: o Maestro faz a Yuko levitar (0 = no chão, 1 = presa no ar).
## Enquanto sobe ela ainda consegue se mexer, cada vez mais devagar.
var levitation: float = 0.0
## Altura máxima da levitação (m) e quanto da velocidade sobra no fim.
@export var levitation_height: float = 1.3
@export var levitation_min_speed: float = 0.35
var _noise_timer: float = 0.0
var _noise_cfg: Dictionary = {}


func _ready() -> void:
	add_to_group("player")
	# wall_min_slide_angle fica no padrão do Godot (15°): contra o Polvo ela é
	# bloqueada de frente, como antes. Nos batentes/paredes (cenário estático)
	# o assistente _assist_wall_slide garante o deslizamento em ângulos pequenos.
	if visual is MeshInstance3D and (visual as MeshInstance3D).mesh is CapsuleMesh:
		_mesh_height = ((visual as MeshInstance3D).mesh as CapsuleMesh).height
	_apply_height(standing_height)


func _physics_process(delta: float) -> void:
	if hiding_spot != null:
		velocity = Vector3.ZERO
		_set_state(MoveState.IDLE)
		return
	if not is_on_floor():
		velocity.y -= gravity * delta

	if not can_move:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_set_state(MoveState.IDLE)
		return

	update_crouch()

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_update_control_yaw(input_vector, delta)

	var basis := get_control_basis()
	var forward := -basis.z
	var right := basis.x
	forward.y = 0.0
	right.y = 0.0
	var direction := (right.normalized() * input_vector.x + forward.normalized() * -input_vector.y)
	if direction.length() > 1.0:
		direction = direction.normalized()

	var current_speed := walking_speed
	is_running = false
	if is_crouching:
		current_speed = crouching_speed
	elif Input.is_action_pressed("run"):
		current_speed = running_speed
		is_running = direction != Vector3.ZERO

	if levitation > 0.0:
		current_speed *= lerpf(1.0, levitation_min_speed, clampf(levitation, 0.0, 1.0))
	if direction != Vector3.ZERO:
		var horizontal := _assist_wall_slide(direction * current_speed, current_speed)
		velocity.x = horizontal.x
		velocity.z = horizontal.z
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), 10.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)

	move_and_slide()

	_update_noise(delta, direction != Vector3.ZERO)

	if is_crouching:
		_set_state(MoveState.CROUCH)
	elif direction == Vector3.ZERO:
		_set_state(MoveState.IDLE)
	elif is_running:
		_set_state(MoveState.RUN)
	else:
		_set_state(MoveState.WALK)


## Versão 6.2: levitação do Maestro. Só o modelo sobe (a colisão fica no
## chão), com um leve balanço.
func set_levitation(amount: float) -> void:
	levitation = clampf(amount, 0.0, 1.0)
	if visual == null or visual is MeshInstance3D:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var h := levitation_height * levitation * levitation * (3.0 - 2.0 * levitation)
	visual.position.y = h + (sin(t * 5.0) * 0.04 * levitation)


## Referencial (só yaw) usado para converter as teclas em direção no mundo.
func get_control_basis() -> Basis:
	return Basis(Vector3.UP, _control_yaw)


func update_crouch() -> void:
	var wants := Input.is_action_pressed("crouch")
	if wants:
		is_crouching = true
	elif is_crouching and _can_stand():
		is_crouching = false
	_apply_height(crouching_height if is_crouching else standing_height)


# ------------------------------------------------------------ internos

## Ajusta colisão e modelo à mesma altura, com a base do modelo no chão.
## (Antes o modelo de 1,1 m era centrado a 0,9 m e flutuava 0,35 m.)
func _apply_height(height: float) -> void:
	var capsule := collision.shape as CapsuleShape3D
	if capsule != null and not is_equal_approx(capsule.height, height):
		capsule.height = height
	collision.position.y = height * 0.5
	if visual is MeshInstance3D:
		visual.position.y = height * 0.5
		visual.scale.y = height / maxf(_mesh_height, 0.01)
	else:
		# Modelo animado: pés no chão; agachar é a animação, não esticar a malha.
		visual.position.y = 0.0
		visual.scale = Vector3.ONE


## Posição do visual em pé (usada pelas cenas de filme ao levantar).
func visual_standing_position() -> Vector3:
	return Vector3(0, standing_height * 0.5 if visual is MeshInstance3D else 0.0, 0)


## Pose deitada (abertura): de lado, com o corpo centrado na posição dela.
func visual_lying_position() -> Vector3:
	return Vector3(0, 0.28, 0) if visual is MeshInstance3D else Vector3(0.85, 0.12, 0)


## Só levanta se a cápsula em pé couber (não atravessa nada acima).
func _can_stand() -> bool:
	var capsule := collision.shape as CapsuleShape3D
	var shape := CapsuleShape3D.new()
	shape.radius = (capsule.radius if capsule else 0.25) * 0.95
	shape.height = standing_height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position + Vector3.UP * (standing_height * 0.5 + 0.03))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## Batentes de porta e quinas: quando o input empurra contra a parede num ângulo
## pequeno, o CharacterBody3D quase não andava. Mantém o empurrão contra a
## parede (continua sem atravessar) e garante velocidade mínima ao longo dela.
func _assist_wall_slide(horizontal: Vector3, speed: float) -> Vector3:
	if not is_on_wall():
		return horizontal
	# Só cenário estático (paredes, batentes, móveis). Contra personagens (Polvo)
	# o comportamento original é mantido: ela é bloqueada, não contorna.
	var n := Vector3.ZERO
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var other := c.get_collider()
		if other is CharacterBody3D or other is RigidBody3D:
			continue
		var cn := c.get_normal()
		cn.y = 0.0
		if cn.length() > 0.7:
			n = cn
			break
	if n.length() < 0.1:
		return horizontal
	n = n.normalized()
	var into := horizontal.dot(n)
	if into >= 0.0:
		return horizontal
	var tangent := horizontal - n * into
	var t_len := tangent.length()
	if t_len < speed * sin(deg_to_rad(wall_slide_dead_angle)):
		return horizontal
	var target := maxf(t_len, speed * wall_slide_min_ratio)
	return tangent / t_len * target + n * into


func _update_control_yaw(input_vector: Vector2, delta: float) -> void:
	var controller := get_tree().get_first_node_in_group("camera_controller")
	var cam_yaw := _control_yaw
	var user_yaw := 0.0
	if controller != null and controller.has_method("get_control_basis"):
		var b: Basis = controller.get_control_basis()
		cam_yaw = atan2(b.z.x, b.z.z)
		if controller.has_method("get_orbit_state"):
			user_yaw = deg_to_rad(float(controller.get_orbit_state().get("user_yaw", 0.0)))
	else:
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			var z := camera.global_basis.z
			cam_yaw = atan2(z.x, z.z)

	if input_vector == Vector2.ZERO or not _holding:
		_holding = input_vector != Vector2.ZERO
		_held_yaw = cam_yaw
		_held_user_yaw = user_yaw
		_control_yaw = cam_yaw
		return
	# Tecla segurada: rotações feitas pelo jogador (setas) valem na hora;
	# mudanças automáticas da câmera entram devagar.
	_held_yaw += user_yaw - _held_user_yaw
	_held_user_yaw = user_yaw
	var step := control_realign_speed * delta
	_held_yaw += clampf(angle_difference(_held_yaw, cam_yaw), -step, step)
	_control_yaw = _held_yaw


func _set_state(state: int) -> void:
	if state == move_state:
		return
	var previous := move_state
	move_state = state
	move_state_changed.emit(previous, state)


# ------------------------------------------------------------ Prompt 2: ruído

## Passos viram SoundStimulus (sistema de audição existente) em intervalos de
## tempo de JOGO: correr = alto, andar = médio, agachada = mínimo.
func _update_noise(delta: float, moving: bool) -> void:
	if not noise_enabled or not moving or not is_on_floor():
		_noise_timer = 0.0
		return
	var key := "crouch" if is_crouching else ("run" if is_running else "walk")
	var cfg: Dictionary = _noise_config().get(key, NOISE_DEFAULTS[key])
	_noise_timer += delta
	if _noise_timer < float(cfg.get("interval", 0.5)):
		return
	_noise_timer = 0.0
	var kind := SoundStimulus.KIND_RUN if key == "run" else StringName("passos_" + ("agachada" if key == "crouch" else "andando"))
	var stimulus := SoundStimulus.new(global_position, float(cfg.get("loudness", 0.5)), kind, &"protagonista")
	stimulus.source_body = self
	noise_emitted.emit(stimulus)
	SoundStimulus.broadcast(get_tree(), stimulus)


func _noise_config() -> Dictionary:
	if _noise_cfg.is_empty():
		var data := GameData.get_instance()
		_noise_cfg = data.player_noise if not data.player_noise.is_empty() else NOISE_DEFAULTS
	return _noise_cfg


# ------------------------------------------------------- Prompt 2: esconderijo

func is_hidden() -> bool:
	return hiding_spot != null


## Monstro que viu a protagonista entrar no esconderijo continua sabendo onde ela está.
func is_witness(monster: Node) -> bool:
	return monster in _hide_witnesses


## Onde os monstros (e a câmera) procuram a protagonista: escondida, é a frente
## do móvel (ponto navegável); fora, a própria posição.
func get_chase_point() -> Vector3:
	if hiding_spot != null and hiding_spot.has_method("get_front_position"):
		return hiding_spot.get_front_position()
	return global_position


func enter_hiding(spot: Node3D) -> void:
	_hide_witnesses.clear()
	for m in get_tree().get_nodes_in_group("monster"):
		# Versão 5.2: só conta como "viu entrar" quem está colado nela (pega no
		# flagra). Com qualquer folga, esconder-se funciona e ele perde o rastro.
		if m.has_method("is_active") and m.is_active() and m.get("perception") != null and m.perception.can_see(self) \
				and Vector2(m.global_position.x - global_position.x, m.global_position.z - global_position.z).length() <= WITNESS_DISTANCE:
			_hide_witnesses.append(m)
	hiding_spot = spot
	_saved_layer = collision_layer
	_saved_mask = collision_mask
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	global_position = spot.get_hide_position()
	reset_physics_interpolation()
	visual.visible = false   # o modelo não muda; só fica oculto dentro do móvel
	_set_state(MoveState.IDLE)
	hidden_changed.emit(true)


func leave_hiding() -> void:
	if hiding_spot == null:
		return
	var front: Vector3 = hiding_spot.get_front_position()
	hiding_spot = null
	_hide_witnesses.clear()
	global_position = front
	reset_physics_interpolation()
	collision_layer = _saved_layer
	collision_mask = _saved_mask
	visual.visible = true
	hidden_changed.emit(false)
