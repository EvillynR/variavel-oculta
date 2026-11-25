extends Node3D
## Câmera cinematográfica 2.5D (linguagem visual inspirada em Little Nightmares II).
##
## Prioridade 1 — reescrita do posicionamento, mantendo a API pública:
##   register_zone(zone) / unregister_zone(zone)  -> chamados por camera_zone.gd
##   refresh_camera_profile()
##   set_tension(valor 0..1)                      -> perseguições (monstros)
##   snap_to_target()                             -> teleportes / cortes de cena
##   get_control_basis()                          -> referencial de controle da protagonista
##   reset_orbit()                                -> volta ao enquadramento da zona
##
## Como funciona
## 1. As zonas (camera_zone.gd) definem o enquadramento-base: camera_offset (lado,
##    altura e distância), FOV e velocidade. Fora de zonas vale o perfil padrão.
## 2. O enquadramento é tratado como uma ÓRBITA em volta da protagonista:
##    desvio de yaw (horizontal), elevação (vertical) e distância.
##    As setas somam um desvio do jogador: ←/→ giram, ↑/↓ sobem/descem a câmera.
##    A rotação só avança se ainda houver espaço livre naquela direção.
## 3. Colisão obrigatória: a lente é uma esfera (collision_radius) lançada do peito
##    da protagonista até o ponto desejado. TODA geometria sólida da camada de
##    cenário bloqueia — paredes (inclusive as invisíveis e as do corte de
##    maquete), chão, teto e móveis — e também peças visíveis sem colisão
##    (vergas de porta). A câmera fica sempre no mesmo espaço livre da
##    protagonista: nunca atravessa nem fica atrás de geometria.
## 4. Quando a direção desejada não tem espaço, a câmera procura uma composição
##    alternativa segura (mais alta e/ou girada) entre candidatos fixos, com
##    histerese: não troca de lado por pequenas diferenças e não oscila.
## 5. Aproximação imediata quando bloqueia (nunca atravessa); afastamento suave.
##    Quando fica mais perto que o planejado, o FOV abre para manter o
##    enquadramento (limitado a maximum_fov).

@export var player: CharacterBody3D

## Estilo de câmera. FIXED (padrão desde o pedido pós-Prompt 2): câmera de
## diorama, como em Little Nightmares — ângulo fixo por cômodo, sem giro pelas
## setas, acompanha a protagonista com suavidade e troca de cômodo deslizando
## (sem cortes). ORBIT: o sistema anterior (órbita + composições), mantido
## como opção e usado pelos testes antigos de câmera.
enum Style { ORBIT, FIXED }
@export var camera_style: Style = Style.FIXED
## Só para testes: força o estilo de todo controlador criado (−1 = não força).
static var testing_force_style: int = -1

@export_group("Câmera fixa (estilo diorama)")
## Distância da lente ao ponto de mira (m) = |camera_offset da zona| × este fator.
@export var fixed_distance_scale: float = 1.25
@export var fixed_min_distance: float = 9.0
@export var fixed_max_distance: float = 16.0
## Inclinação para baixo (graus) — mais baixa que a da órbita: visão de lado.
@export_range(5.0, 45.0, 0.5) var fixed_pitch_degrees: float = 17.0
## FOV estreito (teleobjetiva): perspectiva achatada de maquete.
@export var fixed_fov: float = 30.0
@export var fixed_pivot_height: float = 1.0
## Zona morta lateral: pequenos passos não movem a câmera.
@export var fixed_dead_zone: float = 0.6
## Antecipação lateral na direção do movimento.
@export var fixed_lead: float = 0.9
## Tempo de suavização normal (s) e durante a troca de cômodo (s).
@export var fixed_smooth_time: float = 0.55
@export var fixed_transition_smooth_time: float = 0.7
@export var fixed_transition_time: float = 1.0
## Luz que acompanha a protagonista (ilumina por onde ela anda).
@export var follow_light_enabled: bool = true
@export var follow_light_energy: float = 2.3   # versão 5.8: escola mais escura, ela continua à vista
@export var follow_light_range: float = 8.5
@export var follow_light_color: Color = Color(1.0, 0.86, 0.7)

@export_group("Perfil padrão (fora de zonas)")
@export var default_offset: Vector3 = Vector3(10.0, 2.8, 0.0)
@export var default_fov: float = 36.0
@export var default_follow_speed: float = 2.5

@export_group("Enquadramento")
## Altura (a partir dos pés) para onde a câmera olha quando está na distância normal.
@export var look_height: float = 0.65
## Altura do foco quando a câmera está muito perto (mantém a protagonista no quadro).
@export var close_look_height: float = 1.0
## Distância que a protagonista pode andar no eixo Z antes de a câmera acompanhar.
@export var horizontal_dead_zone: float = 1.5
## Quanto a câmera antecipa a direção do movimento (metros no eixo Z).
@export var look_ahead_distance: float = 1.2
## Velocidade com que a antecipação entra e sai.
@export var look_ahead_speed: float = 1.5
## Mantido por compatibilidade (testes antigos): desvio máximo do OLHAR em relação
## à direção da órbita. A órbita em si é limitada por max_orbit_yaw_degrees.
@export_range(0.0, 45.0, 0.5) var max_yaw_degrees: float = 10.0
## Velocidade da suavização de rotação.
@export var rotation_follow_speed: float = 8.0
## FOV mínimo aceito, para nenhum perfil mal configurado quebrar a imagem.
@export var minimum_fov: float = 15.0
## FOV máximo usado para compensar quando a câmera precisa ficar mais perto.
@export var maximum_fov: float = 60.0
## Abre o FOV quando a câmera fica mais perto que o planejado.
@export var keep_framing_with_fov: bool = true
## Distância a partir da qual o enquadramento é considerado confortável (m).
@export var comfortable_distance: float = 6.5

@export_group("Rotação pelas setas")
@export var orbit_enabled: bool = true
@export var orbit_yaw_speed_degrees: float = 75.0
@export var orbit_pitch_speed_degrees: float = 40.0
## Quanto o jogador pode girar em relação ao enquadramento da zona.
@export_range(0.0, 180.0, 1.0) var max_orbit_yaw_degrees: float = 80.0
@export_range(0.0, 89.0, 1.0) var min_elevation_degrees: float = 8.0
@export_range(0.0, 89.0, 1.0) var max_elevation_degrees: float = 68.0
## A rotação pedida só é aceita se deixar pelo menos esta distância livre.
@export var orbit_min_free_distance: float = 2.2
## Suavização da órbita (troca de composição, rotação do jogador).
@export var orbit_blend_speed: float = 3.0
## Prompt 1: velocidade linear máxima (m/s) da lente durante uma troca
## AUTOMÁTICA de composição. Sem este limite, girar 90° numa órbita de ~10 m
## movia a lente mais de 0,5 m num único quadro (salto visível).
@export var composition_max_linear_speed: float = 9.0

@export_group("Balanço de câmera na mão")
@export var handheld_enabled: bool = true
## Amplitude em graus. Mantenha sutil (0.2 a 0.6).
@export var handheld_amplitude_degrees: float = 0.35
@export var handheld_frequency: float = 0.12

@export_group("Tensão / perseguição")
## Graus somados ao FOV com tensão máxima (abre o quadro na perseguição).
@export var tension_fov_add: float = 6.0
## Metros somados à distância da câmera com tensão máxima.
@export var tension_distance_add: float = 2.0
## Multiplicador da velocidade de acompanhamento com tensão máxima.
@export var tension_follow_multiplier: float = 1.8
@export var tension_blend_speed: float = 1.5

@export_group("Colisão da câmera")
## Mantido por compatibilidade. A prevenção de obstrução é obrigatória e não é
## desligada por esta opção (Prioridade 1, item 3).
@export var collision_enabled: bool = true
## Camada 1 = cenário. A protagonista é excluída pelo RID; monstros (camada 3)
## ficam fora da máscara e não empurram a câmera.
@export_flags_3d_physics var collision_mask: int = 1
## Raio da esfera da lente. Menor que o raio da cápsula da protagonista (0,25)
## para que a esfera nunca comece encostada numa parede ao lado dela.
@export var collision_radius: float = 0.2
## Altura (a partir dos pés) de onde a esfera parte: o peito da protagonista.
@export var collision_pivot_height: float = 1.2
## Folga mínima garantida no fim (rede de segurança) entre a lente e qualquer
## superfície (m).
@export var lens_clearance: float = 0.28
## Folga extra entre a lente e o obstáculo (metros).
@export var collision_margin: float = 0.12
## Velocidade de retorno à distância normal depois que o obstáculo sai do caminho.
@export var collision_return_speed: float = 2.0
## Vantagem exigida para trocar de composição (histerese, evita oscilação).
@export var composition_switch_margin: float = 0.2
## Preferência por ficar atrás do movimento (mostra para onde ela vai e evita a
## troca de lado ao chegar numa porta).
@export var behind_motion_bonus: float = 0.12
## Tempo mínimo (s) numa composição antes de uma troca voluntária.
@export var composition_hold_time: float = 1.5
## Abaixo desta distância livre (m) a troca é de emergência (ignora o tempo).
@export var composition_emergency_distance: float = 2.0
## Previsão (s): testa também onde a protagonista estará daqui a pouco e começa a
## aproximar a câmera ANTES do bloqueio, para não haver recuo brusco.
@export var collision_prediction_time: float = 0.4
## Aproximação antecipada no posicionamento (desligada: os cortes limpos cuidam
## das oclusões repentinas; a previsão continua pesando na escolha de composição).
@export var predictive_pull: bool = false
## Velocidade da aproximação antecipada (suave).
@export var collision_pull_speed: float = 6.0
## Se o caminho for bloqueado de repente (ex.: a protagonista vira a esquina de
## uma porta) e o recuo obrigatório passar disto, a câmera faz um CORTE limpo
## para uma composição segura, em vez de um tranco no meio do caminho.
@export var cut_distance: float = 0.6
## A lente só fica em pontos com teto acima (dentro do prédio).
@export var require_ceiling_cover: bool = true
@export var ceiling_probe_height: float = 8.0
## A lente fica dentro das zonas de câmera ativas (o cômodo da protagonista).
@export var contain_in_zones: bool = true
## Folga (m) em volta da zona; negativo = mais para dentro.
@export var zone_containment_margin: float = 0.0
## Tolerância para decidir em que zona ela está (as caixas das zonas deixam um
## vão do tamanho da espessura da parede nas portas).
@export var zone_membership_tolerance: float = 0.3
## A contenção só vale depois que a protagonista entrou isto (m) no cômodo.
@export var zone_entry_depth: float = 1.0
## Distância mínima lente–protagonista; abaixo disso, mantém a posição anterior
## se ela continuar segura e com visão livre.
@export var minimum_camera_distance: float = 0.9

## Candidatos de composição: (desvio de yaw em graus, desvio de elevação em graus).
## O primeiro é o enquadramento pedido; os outros são alternativas seguras.
const COMPOSITIONS: Array[Vector2] = [
	Vector2(0, 0), Vector2(0, 15), Vector2(0, 28),
	Vector2(30, 0), Vector2(-30, 0), Vector2(30, 15), Vector2(-30, 15),
	Vector2(60, 0), Vector2(-60, 0), Vector2(60, 15), Vector2(-60, 15),
	Vector2(90, 10), Vector2(-90, 10),
]

@onready var camera: Camera3D = $Camera3D

var camera_track_z: float = 0.0

var target_offset: Vector3
var target_fov: float
var target_follow_speed: float

var active_zones: Array = []
var current_zone: Node = null

var use_z_limits: bool = false
var minimum_camera_z: float = 0.0
var maximum_camera_z: float = 0.0
var use_x_limits: bool = false
var minimum_camera_x: float = 0.0
var maximum_camera_x: float = 0.0

var _look_ahead: float = 0.0
var _tension_target: float = 0.0
var _tension: float = 0.0
var _noise_time: float = 0.0
var _noise := FastNoiseLite.new()

## Geometria escondida pelo corte de maquete: GeometryInstance3D -> cast_shadow original.
var _hidden_geometry: Dictionary = {}
var _cutaway_timer: float = 0.0

## Órbita: desvio do jogador (setas) e da composição escolhida.
var _user_yaw: float = 0.0
var _user_pitch: float = 0.0
var _composition: int = 0
var _orbit_yaw: float = 0.0      ## graus, desvio total em relação à base (jogador + composição)
var _orbit_elev: float = 0.0     ## graus, elevação absoluta
var _comp_yaw: float = 0.0       ## parte automática (composição), suavizada
var _comp_elev: float = 0.0
var _choose_timer: float = 0.0
var _hold_left: float = 0.0
var _all_zones: Array = []
var _rig_position: Vector3
var _collision_fraction: float = 1.0
var _cast_shape := SphereShape3D.new()
var _visual_solids: Array[AABB] = []
var _control_yaw: float = 0.0
var _focus: Vector3

## Diagnóstico (lido pelos testes).
var cut_count: int = 0
var last_collision_fraction: float = 1.0
var last_free_distance: float = 0.0
var last_composition: Vector2 = Vector2.ZERO


func _ready() -> void:
	if testing_force_style >= 0:
		camera_style = testing_force_style as Style
	add_to_group("camera_controller")
	# Versão 5.4: o projeto usa interpolação de física (a Yuko anda suave em
	# qualquer monitor). A câmera se move a cada quadro (_process) e já segue a
	# posição interpolada dela, então ela mesma fica fora da interpolação.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.current = true
	_rig_position = camera.global_position
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = 1337
	refresh_camera_profile()
	_orbit_elev = _base_elevation()
	_collect_visual_solids.call_deferred()
	_setup_cut_layer.call_deferred()

	if player != null:
		camera_track_z = _player_position().z
		await get_tree().physics_frame
		snap_to_target()


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if camera_style == Style.FIXED:
		_process_fixed(delta)
		return
	var player_position := _player_position()

	_tension = _damp(_tension, _tension_target, tension_blend_speed, delta)
	_update_track(player_position, delta)
	_read_orbit_input(player_position, delta)

	var pivot := _pivot(player_position)
	_hold_left -= delta
	_choose_timer -= delta
	if _choose_timer <= 0.0:
		_choose_timer = 0.05
		var before := COMPOSITIONS[_composition]
		_choose_composition(player_position, pivot)
		var after := COMPOSITIONS[_composition]
		# Prompt 1: troca para o LADO OPOSTO (ex.: +60° → −60°) vira corte limpo.
		# Antes, o recuo em degraus da colisão disparava um corte por acaso; com o
		# recuo contínuo, a lente atravessava o quadro girando por trás da
		# protagonista ("troca de lado"), o que a linguagem da câmera evita.
		if before.x * after.x < 0.0 and delta > 0.0 and delta < 1.0:
			_cut(player_position)
			return
	var goal := COMPOSITIONS[_composition]
	# Trocas automáticas de composição: suaves. Giro do jogador (setas): direto.
	var max_deg := rad_to_deg(composition_max_linear_speed * delta / maxf(_base_distance(), 1.0))
	var prev_yaw := _comp_yaw
	var prev_elev := _comp_elev
	_comp_yaw = _damp_angle_deg(_comp_yaw, goal.x, orbit_blend_speed, delta)
	_comp_elev = _damp(_comp_elev, goal.y, orbit_blend_speed, delta)
	_comp_yaw = prev_yaw + clampf(_comp_yaw - prev_yaw, -max_deg, max_deg)
	_comp_elev = prev_elev + clampf(_comp_elev - prev_elev, -max_deg, max_deg)
	_orbit_yaw = _user_yaw + _comp_yaw
	_orbit_elev = _clamp_elev(_base_elevation() + _user_pitch + _comp_elev)

	var follow_speed := target_follow_speed * lerpf(1.0, tension_follow_multiplier, _tension)
	var ideal := _ideal_position(player_position, _orbit_yaw, _orbit_elev)
	_rig_position = _rig_position.lerp(ideal, _damp_weight(follow_speed, delta))

	var previous := camera.global_position
	var camera_position := _solve_collision(pivot, _rig_position, delta, _predicted_pivot(pivot) if predictive_pull else Vector3.INF)
	if delta > 0.0 and camera_position.distance_to(pivot) < minimum_camera_distance \
			and previous.distance_to(pivot) >= minimum_camera_distance and _view_is_clear(previous, pivot):
		camera_position = previous
	if delta > 0.0 and delta < 1.0 and camera_position.distance_to(previous) > cut_distance:
		_cut(player_position)
		return
	camera.global_position = camera_position

	var basis_goal := _look_basis(player_position, camera_position, delta)
	camera.global_basis = Basis(camera.global_basis.get_rotation_quaternion().slerp(
		basis_goal.get_rotation_quaternion(), _damp_weight(rotation_follow_speed, delta)))

	camera.fov = _damp(camera.fov, _fov_goal(camera_position), follow_speed, delta)
	# Se a suavização da rotação deixou pés ou cabeça fora do quadro, alcança o alvo.
	if not _body_in_frame(player_position):
		camera.global_basis = Basis(camera.global_basis.get_rotation_quaternion().slerp(
			basis_goal.get_rotation_quaternion(), 0.35))
	_update_cutaway(player_position, delta)
	_update_prop_fade(player_position, delta)
	_update_follow_light(player_position)


func _fits(focus: Vector3, from: Vector3, feet: Vector3, head: Vector3, half: float) -> bool:
	var fdir := (focus - from).normalized()
	return fdir.angle_to((feet - from).normalized()) <= half and fdir.angle_to((head - from).normalized()) <= half


func _body_in_frame(player_position: Vector3) -> bool:
	var rect := get_viewport().get_visible_rect()
	for h in [0.1, 1.0, 1.75]:
		var w: Vector3 = player_position + Vector3.UP * float(h)
		if camera.is_position_behind(w) or not rect.has_point(camera.unproject_position(w)):
			return false
	return true


# ---------------------------------------------------------------- API pública

## Coloca a câmera imediatamente no enquadramento correto.
func snap_to_target() -> void:
	if player == null or not is_instance_valid(player):
		return
	if camera_style == Style.FIXED:
		_snap_fixed()
		return
	var player_position := _player_position()
	camera_track_z = player_position.z
	_look_ahead = 0.0
	var pivot := _pivot(player_position)
	_choose_composition(player_position, pivot, true)
	var goal := COMPOSITIONS[_composition]
	_comp_yaw = goal.x
	_comp_elev = goal.y
	_orbit_yaw = _user_yaw + goal.x
	_orbit_elev = _clamp_elev(_base_elevation() + _user_pitch + goal.y)
	_rig_position = _ideal_position(player_position, _orbit_yaw, _orbit_elev)
	_collision_fraction = 1.0
	var camera_position := _solve_collision(pivot, _rig_position, 0.0)
	camera.global_position = camera_position
	_look_basis(player_position, camera_position, 0.0)
	camera.fov = _fov_goal(camera_position)
	camera.global_basis = _look_basis(player_position, camera_position, 0.0)
	_update_cutaway(player_position, 1.0)
	_update_prop_fade(player_position, 0.0)


## Corte cinematográfico: mantém o giro do jogador, escolhe a melhor composição
## segura para a posição atual e enquadra direto (sem atravessar nada).
func _cut(player_position: Vector3) -> void:
	cut_count += 1
	var pivot := _pivot(player_position)
	# No corte, já enquadra a partir do cômodo para onde ela está indo (zona
	# atual, sem a folga da soleira), se houver espaço lá; senão, regra normal.
	var saved_depth := zone_entry_depth
	zone_entry_depth = 0.0
	_choose_composition(player_position, pivot, true)
	zone_entry_depth = saved_depth
	if last_free_distance < 1.0:
		_choose_composition(player_position, pivot, true)
	var goal := COMPOSITIONS[_composition]
	_comp_yaw = goal.x
	_comp_elev = goal.y
	_orbit_yaw = _user_yaw + goal.x
	_orbit_elev = _clamp_elev(_base_elevation() + _user_pitch + goal.y)
	_rig_position = _ideal_position(player_position, _orbit_yaw, _orbit_elev)
	zone_entry_depth = 0.0
	var camera_position := _solve_collision(pivot, _rig_position, 0.0, _predicted_pivot(pivot))
	zone_entry_depth = saved_depth
	if camera_position.distance_to(pivot) < 1.0:
		camera_position = _solve_collision(pivot, _rig_position, 0.0, _predicted_pivot(pivot))
	camera.global_position = camera_position
	_look_basis(player_position, camera_position, 0.0)  # atualiza o foco
	camera.fov = _fov_goal(camera_position)
	camera.global_basis = _look_basis(player_position, camera_position, 0.0)


## 0 = exploração, 1 = perseguição.
func set_tension(amount: float) -> void:
	_tension_target = clampf(amount, 0.0, 1.0)


## Referencial de controle (só yaw, sem balanço de mão). A protagonista usa isto
## para converter as teclas de movimento em direção no mundo.
func get_control_basis() -> Basis:
	return Basis(Vector3.UP, _control_yaw)


## Volta ao enquadramento definido pela zona (desfaz a rotação das setas).
func reset_orbit() -> void:
	_user_yaw = 0.0
	_user_pitch = 0.0


func get_orbit_state() -> Dictionary:
	return {"user_yaw": _user_yaw, "user_pitch": _user_pitch, "orbit_yaw": _orbit_yaw,
		"orbit_elev": _orbit_elev, "composition": COMPOSITIONS[_composition],
		"free_distance": last_free_distance}


func register_zone(zone: Node) -> void:
	if not active_zones.has(zone):
		active_zones.append(zone)
	refresh_camera_profile()


func unregister_zone(zone: Node) -> void:
	active_zones.erase(zone)
	refresh_camera_profile()


func refresh_camera_profile() -> void:
	var best_zone: Node = null
	var best_priority: int = -999999
	for zone in active_zones:
		if not is_instance_valid(zone):
			continue
		var zone_priority: int = int(_zone_value(zone, "camera_priority", 0))
		if zone_priority > best_priority:
			best_priority = zone_priority
			best_zone = zone

	if best_zone != current_zone:
		# Câmera fixa: o recorte é refeito a cada quadro; restaurar tudo na troca
		# de zona faria a parede piscar por um quadro.
		if camera_style == Style.ORBIT:
			_restore_cutaway()
		if best_zone != null and current_zone != null:
			_fixed_transition_left = fixed_transition_time
	current_zone = best_zone
	if best_zone != null:
		_fixed_last_zone = best_zone

	if best_zone == null:
		target_offset = default_offset
		target_fov = default_fov
		target_follow_speed = default_follow_speed
		use_z_limits = false
		use_x_limits = false
		return

	target_offset = _zone_value(best_zone, "camera_offset", default_offset)
	target_fov = float(_zone_value(best_zone, "camera_fov", default_fov))
	target_follow_speed = float(_zone_value(best_zone, "blend_speed", default_follow_speed))
	use_z_limits = bool(_zone_value(best_zone, "use_z_limits", false))
	minimum_camera_z = float(_zone_value(best_zone, "minimum_camera_z", 0.0))
	maximum_camera_z = float(_zone_value(best_zone, "maximum_camera_z", 0.0))
	use_x_limits = bool(_zone_value(best_zone, "use_x_limits", false))
	minimum_camera_x = float(_zone_value(best_zone, "minimum_camera_x", 0.0))
	maximum_camera_x = float(_zone_value(best_zone, "maximum_camera_x", 0.0))


# ------------------------------------------------------------ órbita / composição

func _base_elevation() -> float:
	var h := Vector2(target_offset.x, target_offset.z).length()
	return rad_to_deg(atan2(target_offset.y, maxf(h, 0.001)))


func _base_distance() -> float:
	return target_offset.length() + tension_distance_add * _tension


func _clamp_elev(e: float) -> float:
	return clampf(e, min_elevation_degrees, max_elevation_degrees)


## Ponto desejado da lente para um desvio de yaw e uma elevação (graus).
func _ideal_position(player_position: Vector3, yaw_dev: float, elev: float) -> Vector3:
	var base_dir := Vector3(target_offset.x, 0.0, target_offset.z)
	base_dir = base_dir.normalized() if base_dir.length() > 0.001 else Vector3.BACK
	var dir_h := base_dir.rotated(Vector3.UP, deg_to_rad(yaw_dev))
	var e := deg_to_rad(elev)
	var d := _base_distance()
	var anchor := Vector3(player_position.x, player_position.y, camera_track_z + _look_ahead)
	# Os limites da zona agora valem para o TRILHO (o ponto que a câmera segue),
	# não para a lente: antes eles puxavam de uma vez a câmera que vinha por trás
	# ao trocar de zona. A lente é contida pela colisão e pelo teto.
	if use_z_limits:
		anchor.z = clampf(anchor.z, minimum_camera_z, maximum_camera_z)
	if use_x_limits:
		anchor.x = clampf(anchor.x, minimum_camera_x, maximum_camera_x)
	return anchor + dir_h * cos(e) * d + Vector3.UP * sin(e) * d


func _pivot(player_position: Vector3) -> Vector3:
	var h := collision_pivot_height
	var shape_node := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		h = minf(h, (shape_node.shape as CapsuleShape3D).height * 0.7)
	return player_position + Vector3.UP * h


## Distância livre (m) do pivô até o ponto desejado.
func _free_distance(pivot: Vector3, target: Vector3) -> float:
	return _free_fraction(pivot, target) * pivot.distance_to(target)


## Escolhe a composição (candidato) com histerese.
func _choose_composition(player_position: Vector3, pivot: Vector3, force: bool = false) -> void:
	var wanted := _base_distance()
	var scores: Array[float] = []
	var distances: Array[float] = []
	var moving := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var predicted := pivot if force else _predicted_pivot(pivot)
	for i in COMPOSITIONS.size():
		var c := COMPOSITIONS[i]
		# Prompt 1: com o jogador girando pelas setas, composições que giram para
		# o lado contrário anulariam o giro; ficam como último recurso (o
		# fallback de emergência continua valendo se nada mais tiver espaço).
		var against_user := absf(_user_yaw) > 5.0 and c.x != 0.0 and signf(c.x) != signf(_user_yaw)
		var elev := _clamp_elev(_base_elevation() + _user_pitch + c.y)
		var target := _ideal_position(player_position, _user_yaw + c.x, elev)
		var d := _free_distance(pivot, target)
		distances.append(d)
		var quality := minf(d / minf(comfortable_distance, wanted), 1.0)
		if predicted != pivot:
			# O que vai bloquear em breve pesa metade (evita trocas nervosas).
			var soon := _free_distance(predicted, target + (predicted - pivot))
			quality = lerpf(quality, minf(quality, minf(soon / minf(comfortable_distance, wanted), 1.0)), 0.5)
		var score := quality - absf(c.x) / 90.0 * 0.4 - absf(c.y) / 30.0 * 0.3
		if against_user:
			score -= 1.0
		if moving.length() > 0.5 and c.x != 0.0:
			# Prefere ficar atrás do movimento (mostra para onde ela vai).
			var arm := target - player_position
			if Vector3(arm.x, 0.0, arm.z).dot(moving) < 0.0:
				score += behind_motion_bonus
		scores.append(score)

	var best := 0
	for i in scores.size():
		if scores[i] > scores[best]:
			best = i
	var emergency := distances[_composition] < composition_emergency_distance
	if force:
		# Corte/encaixe: só abandona a composição atual se ela não servir.
		if emergency or scores[best] > scores[_composition] + composition_switch_margin:
			_composition = best
		_hold_left = composition_hold_time
	elif best != _composition and (emergency or _hold_left <= 0.0):
		var margin := composition_switch_margin
		# Trocar para o lado oposto exige vantagem bem maior (evita "pular de lado"),
		# a menos que a composição atual já esteja ruim (sem espaço).
		var current_quality := distances[_composition] / minf(comfortable_distance, wanted)
		if signf(COMPOSITIONS[best].x) * signf(COMPOSITIONS[_composition].x) < 0.0 and current_quality >= 0.6:
			margin += 0.3
		if emergency or scores[best] > scores[_composition] + margin:
			_composition = best
			_hold_left = composition_hold_time
	last_composition = COMPOSITIONS[_composition]
	last_free_distance = distances[_composition]


func _read_orbit_input(player_position: Vector3, delta: float) -> void:
	if not orbit_enabled or delta <= 0.0 or delta > 1.0:
		return
	var yaw_in := Input.get_axis("camera_rotate_left", "camera_rotate_right") if InputMap.has_action("camera_rotate_left") else 0.0
	var pitch_in := Input.get_axis("camera_rotate_down", "camera_rotate_up") if InputMap.has_action("camera_rotate_up") else 0.0
	if yaw_in == 0.0 and pitch_in == 0.0:
		return
	var pivot := _pivot(player_position)
	var base_elev := _base_elevation()
	var current_free := _free_distance(pivot, _ideal_position(player_position, _user_yaw, _clamp_elev(base_elev + _user_pitch)))

	if yaw_in != 0.0:
		var new_yaw := clampf(_user_yaw + yaw_in * orbit_yaw_speed_degrees * delta, -max_orbit_yaw_degrees, max_orbit_yaw_degrees)
		var free := _free_distance(pivot, _ideal_position(player_position, new_yaw, _clamp_elev(base_elev + _user_pitch)))
		if free >= orbit_min_free_distance or free >= current_free:
			# Prompt 1: o giro do jogador é direto — a lente gira junto em volta
			# da protagonista, em vez de esperar o acompanhamento lento da zona
			# (blend 0,8 nas salas fazia 60° de giro parecerem 13°).
			var turn := deg_to_rad(new_yaw - _user_yaw)
			var center := Vector3(player_position.x, _rig_position.y, player_position.z)
			_rig_position = center + (_rig_position - center).rotated(Vector3.UP, turn)
			_user_yaw = new_yaw
	if pitch_in != 0.0:
		var new_pitch := _user_pitch + pitch_in * orbit_pitch_speed_degrees * delta
		new_pitch = clampf(new_pitch, min_elevation_degrees - base_elev, max_elevation_degrees - base_elev)
		var free := _free_distance(pivot, _ideal_position(player_position, _user_yaw, _clamp_elev(base_elev + new_pitch)))
		if free >= orbit_min_free_distance or free >= current_free:
			_user_pitch = new_pitch


# ------------------------------------------------------------ acompanhamento

func _update_track(player_position: Vector3, delta: float) -> void:
	var distance_from_track := player_position.z - camera_track_z
	if distance_from_track > horizontal_dead_zone:
		camera_track_z = player_position.z - horizontal_dead_zone
	elif distance_from_track < -horizontal_dead_zone:
		camera_track_z = player_position.z + horizontal_dead_zone

	var speed_reference := 3.5
	if "walking_speed" in player:
		speed_reference = maxf(float(player.get("walking_speed")), 0.01)
	var lead_goal := clampf(player.velocity.z / speed_reference, -1.0, 1.0) * look_ahead_distance
	_look_ahead = _damp(_look_ahead, lead_goal, look_ahead_speed, delta)


func _look_basis(player_position: Vector3, camera_position: Vector3, delta: float) -> Basis:
	var dist := camera_position.distance_to(_pivot(player_position))
	var t := clampf((dist - 1.5) / maxf(comfortable_distance - 1.5, 0.1), 0.0, 1.0)
	var focus_h := lerpf(close_look_height, look_height, t)
	# O foco acompanha o trilho (zona morta + antecipação) só na distância normal;
	# perto, olha para a protagonista para ela não sair do quadro.
	var rail_z := camera_track_z + _look_ahead
	_focus = Vector3(player_position.x, player_position.y + focus_h, lerpf(player_position.z, rail_z, t))
	# Mantém pés e cabeça dentro do quadro: procura (busca binária) o menor
	# deslocamento do foco em direção ao meio do corpo que faça os dois caberem
	# em 75% do meio-FOV.
	var half := deg_to_rad(maxf(camera.fov, minimum_fov)) * 0.5 * 0.75
	var feet := player_position + Vector3.UP * 0.05
	var head := player_position + Vector3.UP * 1.8
	var mid := (feet + head) * 0.5
	var original := _focus
	if not _fits(original, camera_position, feet, head, half):
		var lo := 0.0
		var hi := 1.0
		for i in 12:
			var m := (lo + hi) * 0.5
			if _fits(original.lerp(mid, m), camera_position, feet, head, half):
				hi = m
			else:
				lo = m
		_focus = original.lerp(mid, hi)

	var direction := _focus - camera_position
	if direction.length() < 0.001:
		return camera.global_basis
	var yaw := atan2(-direction.x, -direction.z)
	var pitch := atan2(direction.y, Vector2(direction.x, direction.z).length())
	_control_yaw = yaw if delta <= 0.0 else lerp_angle(_control_yaw, yaw, _damp_weight(rotation_follow_speed, delta))

	var roll := 0.0
	if handheld_enabled and delta > 0.0:
		_noise_time += delta * handheld_frequency * 100.0
		var amplitude := deg_to_rad(handheld_amplitude_degrees)
		yaw += _noise.get_noise_2d(_noise_time, 0.0) * amplitude
		pitch += _noise.get_noise_2d(0.0, _noise_time) * amplitude
		roll = _noise.get_noise_2d(_noise_time, _noise_time) * amplitude * 0.5
	return Basis.from_euler(Vector3(pitch, yaw, roll))


func _fov_goal(camera_position: Vector3) -> float:
	var fov := maxf(target_fov + tension_fov_add * _tension, minimum_fov)
	if not keep_framing_with_fov:
		return fov
	var planned := minf(_base_distance(), comfortable_distance + tension_distance_add * _tension)
	var actual := maxf(camera_position.distance_to(_focus if _focus != Vector3.ZERO else camera_position + Vector3.FORWARD), 0.5)
	if actual >= planned:
		return fov
	var widened := rad_to_deg(2.0 * atan(tan(deg_to_rad(fov) * 0.5) * planned / actual))
	return clampf(widened, fov, maxf(maximum_fov, fov))


# ------------------------------------------------------------ colisão

## Coloca a lente entre o pivô e o ponto do trilho, sempre antes de qualquer
## obstáculo. Regra dura: se o caminho atual bloqueia, aproxima na hora (nunca
## atravessa). Regra suave: se o caminho vai bloquear em breve (posição prevista
## da protagonista), aproxima com suavidade antes. O afastamento é sempre suave.
func _solve_collision(pivot: Vector3, rig_position: Vector3, delta: float, predicted: Vector3 = Vector3.INF) -> Vector3:
	var allowed := _free_fraction(pivot, rig_position)
	last_collision_fraction = allowed
	var goal := allowed
	if predicted != Vector3.INF and predicted.distance_to(pivot) > 0.05:
		var soon := _free_fraction(predicted, rig_position + (predicted - pivot))
		goal = minf(goal, soon)
	if delta <= 0.0:
		_collision_fraction = goal
	elif allowed < _collision_fraction:
		_collision_fraction = allowed
	elif goal < _collision_fraction:
		var arm := maxf((rig_position - pivot).length(), 0.01)
		var step := collision_pull_speed * delta / arm
		_collision_fraction = maxf(_collision_fraction - step * maxf(1.0, (_collision_fraction - goal) * 4.0), goal)
	else:
		_collision_fraction = minf(_damp(_collision_fraction, goal, collision_return_speed, delta), allowed)
	var result := pivot + (rig_position - pivot) * _collision_fraction
	# Rede de segurança: se por qualquer motivo (quinas, emendas) a lente ainda
	# encostar em algo, recua em direção ao pivô até ficar livre.
	# Prompt 1: o recuo era feito em passos fixos de 6% do braço (≈0,55 m num
	# braço de 9 m), o que aparecia como salto. Agora a busca binária acha o
	# MAIOR ponto livre: o recuo é só o necessário e varia de forma contínua.
	if _collision_fraction > 0.0 and _lens_touches(result):
		var lo := 0.0
		var hi := _collision_fraction
		for i in 10:
			var mid := (lo + hi) * 0.5
			if _lens_touches(pivot + (rig_position - pivot) * mid):
				hi = mid
			else:
				lo = mid
		_collision_fraction = lo
		result = pivot + (rig_position - pivot) * _collision_fraction
	return result


## Posição ainda segura (lente livre) e com visão livre até o pivô.
func _view_is_clear(point: Vector3, pivot: Vector3) -> bool:
	if _lens_touches(point):
		return false
	return _free_fraction(pivot, point) >= 0.98


func _lens_touches(point: Vector3) -> bool:
	_cast_shape.radius = lens_clearance
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _cast_shape
	q.transform = Transform3D(Basis(), point)
	q.collision_mask = collision_mask
	if player is CollisionObject3D:
		q.exclude = [player.get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 4):
		if _is_camera_obstacle(hit.collider):
			return true
	for box in _visual_solids:
		if box.grow(lens_clearance).has_point(point):
			return true
	_cast_shape.radius = collision_radius
	return false


## Pivô previsto pela velocidade atual, limitado ao espaço livre.
func _predicted_pivot(pivot: Vector3) -> Vector3:
	var v := Vector3(player.velocity.x, 0.0, player.velocity.z) * collision_prediction_time
	if v.length() < 0.05:
		return pivot
	var f := _free_fraction(pivot, pivot + v)
	return pivot + v * f


## Fração (0..1) do caminho pivô -> destino que a esfera da lente percorre sem
## tocar em geometria sólida (física) nem em peças visíveis sem colisão.
func _free_fraction(from: Vector3, to: Vector3) -> float:
	var motion := to - from
	var length := motion.length()
	if length < 0.01:
		return 1.0
	var space := get_world_3d().direct_space_state
	_cast_shape.radius = collision_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _cast_shape
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var exclude: Array[RID] = []
	if player is CollisionObject3D:
		exclude.append(player.get_rid())

	var fraction := 1.0
	for attempt in 6:
		query.exclude = exclude
		query.transform = Transform3D(Basis(), from)
		query.motion = motion
		var result := space.cast_motion(query)
		if result.is_empty() or result[1] >= 1.0:
			break
		# Personagens e corpos dinâmicos não são cenário: atravessa e continua.
		query.transform = Transform3D(Basis(), from + motion * result[1])
		query.motion = Vector3.ZERO
		var blocking := false
		var added := false
		for hit in space.intersect_shape(query, 8):
			if _is_camera_obstacle(hit.collider):
				blocking = true
			elif not exclude.has(hit.rid):
				exclude.append(hit.rid)
				added = true
		if blocking:
			fraction = clampf(result[0] - collision_margin / length, 0.0, 1.0)
			break
		if not added:
			break

	for box in _visual_solids:
		var t := _segment_enters_aabb(from, to, box.grow(collision_radius + collision_margin))
		if t >= 0.0:
			fraction = minf(fraction, t)

	# Contenção: a lente fica dentro do volume da escola (sob o teto). Sem isto ela
	# escapava pela fresta entre o topo das paredes invisíveis (4,5 m) e o teto
	# (6,9 m) e depois era cortada de uma vez pela parede da porta seguinte.
	# Contenção por cômodo: a lente fica dentro (em planta) das zonas de câmera em
	# que a protagonista está — nunca num cômodo vizinho espiando pela porta.
	if (require_ceiling_cover or contain_in_zones) and fraction > 0.0:
		var steps := 10
		var rects := _zone_rects(from) if contain_in_zones else []
		for i in range(1, steps + 1):
			var t := fraction * float(i) / steps
			var point := from + motion * t
			var ok := true
			if require_ceiling_cover and not _covered(point, space, exclude):
				ok = false
			elif not rects.is_empty() and t * length > 0.8 and not _inside_rects(point, rects):
				# (os primeiros 0,8 m partem da protagonista, que pode estar na soleira)
				ok = false
			if not ok:
				# Refina entre a última amostra boa e a ruim (bissecção).
				var lo := fraction * float(i - 1) / steps
				var hi := t
				for k in 4:
					var mid := (lo + hi) * 0.5
					var mp := from + motion * mid
					var good := (not require_ceiling_cover or _covered(mp, space, exclude)) and (rects.is_empty() or mid * length <= 0.8 or _inside_rects(mp, rects))
					if good:
						lo = mid
					else:
						hi = mid
				fraction = lo
				break
	return fraction


## Retângulo (em planta, XZ) do cômodo da protagonista: a zona ativa de maior
## prioridade que contém o pivô. Vazio = sem contenção (ex.: fora de zonas).
func _zone_rects(pivot: Vector3) -> Array:
	var best: Rect2
	var best_priority := -999999
	var found := false
	if _all_zones.is_empty():
		_collect_zones()
	for zone in _all_zones:
		if not is_instance_valid(zone) or not zone.monitoring:
			continue
		for child in zone.get_children():
			var cs := child as CollisionShape3D
			if cs == null or not (cs.shape is BoxShape3D):
				continue
			var size: Vector3 = (cs.shape as BoxShape3D).size
			var box: AABB = cs.global_transform * AABB(-size * 0.5, size)
			var r := Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(zone_containment_margin)
			var prio := int(_zone_value(zone, "camera_priority", 0))
			# Na soleira (menos de 1 m dentro) ainda não prende: evita lente sem espaço.
			if r.grow(zone_membership_tolerance - zone_entry_depth).has_point(Vector2(pivot.x, pivot.z)) and prio > best_priority:
				best = r
				best_priority = prio
				found = true
	return [best] if found else []


## Todas as zonas de câmera da cena (consultadas pela geometria, sem esperar o
## sinal body_entered, que chega com um quadro de atraso na soleira).
func _collect_zones() -> void:
	_all_zones.clear()
	var scene_root := get_parent()
	if scene_root == null:
		return
	for node in scene_root.find_children("*", "Area3D", true, false):
		if node.has_method("get_occluding_geometry"):
			_all_zones.append(node)


func _inside_rects(point: Vector3, rects: Array) -> bool:
	for r in rects:
		if (r as Rect2).has_point(Vector2(point.x, point.z)):
			return true
	return false


## true se há teto (cenário) acima do ponto.
func _covered(point: Vector3, space: PhysicsDirectSpaceState3D, exclude: Array[RID]) -> bool:
	var q := PhysicsRayQueryParameters3D.create(point, point + Vector3.UP * ceiling_probe_height, collision_mask, exclude)
	return not space.intersect_ray(q).is_empty()


## Bloqueia tudo o que é cenário estático. Só personagens e corpos dinâmicos
## (protagonista, monstros) ficam de fora.
func _is_camera_obstacle(collider: Object) -> bool:
	if collider == null or collider == player:
		return false
	if collider is CharacterBody3D or collider is RigidBody3D:
		return false
	# Prompt 2: móveis não empurram a lente (pulos/cortes entre estantes);
	# quando ficam entre a lente e a protagonista, o fade os deixa translúcidos.
	# (Só móveis CSG; portas também ficam translúcidas, mas continuam sólidas para a lente.)
	if collider is CSGShape3D and (collider as Node).is_in_group("camera_fade"):
		return false
	if collider is Node and (collider as Node).is_in_group("prop_body"):
		return false
	return true


## Peças visíveis sem colisão (ex.: vergas sobre as portas): a lente também não
## pode entrar nelas.
var _visual_solid_nodes: Array = []


func _collect_visual_solids() -> void:
	_visual_solids.clear()
	_visual_solid_nodes.clear()
	var scene_root := get_parent()
	if scene_root == null:
		return
	for node in scene_root.find_children("*", "CSGShape3D", true, false):
		var csg := node as CSGShape3D
		if csg.use_collision or not csg.is_visible_in_tree() or not csg.is_root_shape():
			continue
		# Móveis: a colisão é uma caixa à parte (StaticBody) e eles têm fade.
		if csg.is_in_group("camera_fade"):
			continue
		_visual_solids.append(csg.global_transform * csg.get_aabb())
		_visual_solid_nodes.append(csg)


## t (0..1) em que o segmento entra na caixa; -1 se não entra ou se começa dentro.
func _segment_enters_aabb(from: Vector3, to: Vector3, box: AABB) -> float:
	if box.has_point(from):
		return -1.0
	var d := to - from
	var t_min := 0.0
	var t_max := 1.0
	for axis in 3:
		var o := from[axis]
		var v := d[axis]
		var lo := box.position[axis]
		var hi := box.end[axis]
		if absf(v) < 0.000001:
			if o < lo or o > hi:
				return -1.0
		else:
			var t1 := (lo - o) / v
			var t2 := (hi - o) / v
			if t1 > t2:
				var tmp := t1
				t1 = t2
				t2 = tmp
			t_min = maxf(t_min, t1)
			t_max = minf(t_max, t2)
			if t_min > t_max:
				return -1.0
	return t_min


# ------------------------------------------------------------ corte de maquete

## A geometria listada na zona só some da imagem se estiver realmente entre a
## lente e a protagonista (continua com colisão e sombra). Como a câmera agora
## nunca fica atrás de paredes, isto só age em peças baixas/vazadas.
func _update_cutaway(player_position: Vector3, delta: float) -> void:
	_cutaway_timer -= delta
	if _cutaway_timer > 0.0:
		return
	_cutaway_timer = 0.1 if camera_style == Style.ORBIT else 0.0
	var candidates: Array = []
	var dynamic_walls: Array = []
	var zone_walls: Array = []
	if camera_style == Style.FIXED:
		# Maquete de verdade: paredes de TODAS as zonas ativas (a protagonista
		# pode estar na soleira entre duas) + qualquer parede atingida pela visão.
		var seen := {}
		for z in active_zones + [_fixed_last_zone]:
			if z != null and is_instance_valid(z) and z.has_method("get_occluding_geometry") and not seen.has(z):
				seen[z] = true
				zone_walls.append_array(z.get_occluding_geometry())
		candidates.append_array(zone_walls)
		dynamic_walls = _walls_in_view(player_position)
		if player is CharacterBody3D:
			# Antecipa ~0,25 s: a parede some antes de a protagonista passar atrás dela.
			dynamic_walls.append_array(_walls_in_view(player_position + player.velocity * 0.25))
		dynamic_walls.append_array(_front_walls(player_position))
		candidates.append_array(dynamic_walls)
	elif current_zone != null and current_zone.has_method("get_occluding_geometry"):
		candidates = current_zone.get_occluding_geometry()
	if candidates.is_empty():
		_restore_cutaway()
		return
	var cam := camera.global_position
	var still_hidden := {}
	for geometry in candidates:
		var box: AABB = geometry.global_transform * geometry.get_aabb()
		# Câmera fixa: as paredes de corte da zona (a "frente" da maquete) somem
		# sempre, não só quando tapam o corpo — o cômodo fica aberto para a lente.
		var blocks: bool = geometry in dynamic_walls or (camera_style == Style.FIXED and geometry in zone_walls and _is_front_wall(geometry, box, player_position))
		if box.grow(0.3).has_point(cam):
			blocks = true
		for h in [0.3, 1.0, 1.6]:
			if blocks:
				break
			if _segment_enters_aabb(cam, player_position + Vector3.UP * h, box) >= 0.0:
				blocks = true
				break
		if blocks:
			still_hidden[geometry] = true
			if not _hidden_geometry.has(geometry):
				_cut_geometry(geometry)
	# Câmera fixa: a porta instalada numa parede recortada é recortada junto
	# (senão sobra o batente/bandeira "flutuando" na frente do cômodo aberto).
	if camera_style == Style.FIXED and not still_hidden.is_empty():
		for door in get_tree().get_nodes_in_group("door"):
			var dp: Vector3 = (door as Node3D).global_position + Vector3.UP * 1.5
			var in_cut := false
			for geom in still_hidden:
				if not is_instance_valid(geom) or (geom as Node).is_ancestor_of(door):
					continue
				var gb: AABB = geom.global_transform * geom.get_aabb()
				var f := -camera.global_basis.z
				# Só paredes de frente (finas no eixo da visão) levam a porta junto.
				if absf(f.x) * gb.size.x + absf(f.z) * gb.size.z < 0.8 and gb.grow(1.7).has_point(dp):
					in_cut = true
					break
			if in_cut:
				for g in (door as Node).find_children("*", "GeometryInstance3D", true, false):
					still_hidden[g] = true
					if not _hidden_geometry.has(g):
						_cut_geometry(g)
	for geometry in _hidden_geometry.keys():
		if not still_hidden.has(geometry) and is_instance_valid(geometry):
			_uncut_geometry(geometry)
			_hidden_geometry.erase(geometry)


func _restore_cutaway() -> void:
	for geometry in _hidden_geometry.keys():
		if is_instance_valid(geometry):
			_uncut_geometry(geometry)
	_hidden_geometry.clear()


## Camada de render das peças recortadas na câmera fixa: fora da câmera E fora
## das luzes — a parede some por inteiro, sem deixar a sombra dela no chão
## (antes ficava uma faixa escura onde a protagonista andava).
const CUT_LAYER := 1 << 19


func _cut_geometry(g: GeometryInstance3D) -> void:
	if camera_style == Style.FIXED:
		var original_layers: int = int(_stage_hidden[g].layers) if _stage_hidden.has(g) else g.layers
		_hidden_geometry[g] = {"layers": original_layers, "shadow": g.cast_shadow}
		g.layers = CUT_LAYER
	else:
		_hidden_geometry[g] = {"shadow": g.cast_shadow}
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


func _uncut_geometry(g: GeometryInstance3D) -> void:
	if _stage_hidden.has(g):
		# Continua fora do palco: o corte de palco é quem decide.
		return
	var saved: Dictionary = _hidden_geometry.get(g, {})
	if saved.has("layers"):
		g.layers = int(saved.layers)
	if saved.has("shadow"):
		g.cast_shadow = saved.shadow


## Câmera fixa: só some sempre a parede "da frente" da maquete — fina no eixo
## da visão e entre a lente e a protagonista. Paredes de lado (ex.: o fim do
## corredor) ficam, a menos que tapem o corpo de fato.
func _is_front_wall(_g: GeometryInstance3D, box: AABB, player_position: Vector3) -> bool:
	var fwd := -camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var thickness := absf(fwd.x) * box.size.x + absf(fwd.z) * box.size.z
	var toward_cam := (box.get_center() - player_position).dot(-fwd)
	if thickness < 0.8 and toward_cam > 0.2:
		return true
	# Peça inteira à frente do plano da protagonista (ex.: a ponta de uma parede
	# de junção vista de quina): só poderia atrapalhar — sai também.
	# Só pontas curtas (ex.: o pedaço de parede de uma junção de corredor, que
	# aparecia como uma barra vertical). Paredes de fundo mais longas, como a do
	# fim do corredor com a porta do subsolo, continuam no lugar.
	if thickness > 1.3:
		return false
	var nearest := INF
	for i in 8:
		nearest = minf(nearest, (box.get_endpoint(i) - player_position).dot(-fwd))
	return nearest > 0.4


## As luzes e a câmera ignoram a camada de recorte.
func _setup_cut_layer() -> void:
	camera.cull_mask &= ~CUT_LAYER
	for l in get_tree().root.find_children("*", "Light3D", true, false):
		(l as Light3D).light_cull_mask &= ~CUT_LAYER


# ------------------------------------------------------------ utilidades

func _player_position() -> Vector3:
	# Prompt 2: escondida, a câmera enquadra a frente do esconderijo (o pivô
	# dentro do móvel faria a lente colapsar contra as paredes dele).
	if player.has_method("is_hidden") and player.is_hidden():
		return player.get_chase_point()
	return player.get_global_transform_interpolated().origin


func _zone_value(zone: Node, property: String, fallback: Variant) -> Variant:
	if property in zone:
		var value: Variant = zone.get(property)
		if value != null:
			return value
	return fallback


func _damp_weight(speed: float, delta: float) -> float:
	return 1.0 - exp(-speed * delta)


func _damp(from: float, to: float, speed: float, delta: float) -> float:
	return lerpf(from, to, _damp_weight(speed, delta))


func _damp_angle_deg(from: float, to: float, speed: float, delta: float) -> float:
	return from + (to - from) * _damp_weight(speed, delta)


# ------------------------------------------------------------ Prompt 2: móveis

## Móveis (grupo "camera_fade", scenes/props/) entre a lente e a protagonista
## ficam translúcidos — a colisão continua valendo. Quem sai da frente volta
## ao normal suavemente. delta = 0: aplica na hora (snap/corte).
## Meio transparente: o móvel continua lá (antes sumia quase todo).
## Versão 5.8: 0,5 deixava móveis escuros e altos como uma mancha preta que
## engolia a Yuko; mais transparente, ela continua visível atrás deles.
const PROP_FADE_ALPHA := 0.75
## Distância mínima entre a lente e as paredes laterais do cômodo (m).
@export var stage_wall_clearance: float = 2.6
var _faded_props: Dictionary = {}   # GeometryInstance3D -> true


## Versão 5.7: cenas de filme mostram os móveis inteiros (a translucidez é só
## para a câmera de jogo enxergar a protagonista). Chamado pelo CutscenePlayer.
func clear_prop_fade() -> void:
	for g in _faded_props.keys():
		if is_instance_valid(g):
			(g as GeometryInstance3D).transparency = 0.0
	_faded_props.clear()


func _update_prop_fade(_player_pos: Vector3, delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var hit_now := {}
	# Posição física (não interpolada): depois de um teleporte/esconderijo a
	# interpolada ainda aponta para o lugar antigo.
	var player_position: Vector3 = player.get_chase_point() if player.has_method("is_hidden") and player.is_hidden() else player.global_position
	# Margem lateral de 0,35 m: o móvel some um pouco ANTES de cobrir o corpo.
	var side := camera.global_basis.x
	side.y = 0.0
	side = side.normalized() * 0.35
	var targets: Array[Vector3] = []
	for h in [0.1, 0.4, 0.7, 1.0, 1.2, 1.45, 1.7, 1.85]:
		targets.append(player_position + Vector3.UP * h)
	for h in [0.5, 1.3]:
		targets.append(player_position + Vector3.UP * h + side)
		targets.append(player_position + Vector3.UP * h - side)
	for target in targets:
		var exclude: Array[RID] = []
		if player is CollisionObject3D:
			exclude.append(player.get_rid())
		for i in 4:
			var q := PhysicsRayQueryParameters3D.create(camera.global_position, target, collision_mask, exclude)
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			exclude.append(hit.rid)
			var c: Object = hit.collider
			# Móveis: a colisão é uma caixa (StaticBody) filha do CSG visível.
			if c is CollisionObject3D and (c as Node).is_in_group("prop_body") and ((c as Node).get_parent() is GeometryInstance3D or (c as Node).get_parent().is_in_group("camera_fade")):
				c = (c as Node).get_parent()
			if c is Node and (c as Node).is_in_group("camera_fade"):
				if c is GeometryInstance3D:
					hit_now[c] = true
				else:
					for g in (c as Node).find_children("*", "GeometryInstance3D", true, false):
						hit_now[g] = true
	# Palco: qualquer móvel/porta/esconderijo mais perto da lente que ela e que
	# cubra o corpo dela NA TELA (não só no raio) fica translúcido.
	if camera_style == Style.FIXED:
		_screen_fade(player_position, hit_now)
	for g in hit_now.keys():
		if _stage_hidden.has(g) or _stage_fading.has(g):
			hit_now.erase(g)
	for g in hit_now:
		# Entra na hora (a protagonista nunca fica escondida atrás de um móvel);
		# sai devagar, para não piscar.
		(g as GeometryInstance3D).transparency = PROP_FADE_ALPHA
		_faded_props[g] = true
	for g in _faded_props.keys():
		if not is_instance_valid(g):
			_faded_props.erase(g)
		elif _stage_hidden.has(g) or _stage_fading.has(g):
			# O corte de palco assumiu esta peça (não disputar a transparência).
			_faded_props.erase(g)
		elif not hit_now.has(g):
			var gi := g as GeometryInstance3D
			gi.transparency = 0.0 if delta <= 0.0 else move_toward(gi.transparency, 0.0, delta * 2.0)
			if gi.transparency <= 0.0:
				_faded_props.erase(g)


# ================================================================ câmera fixa
# Estilo diorama (Little Nightmares): orientação FIXA por cômodo (vinda do
# camera_offset da zona: direção e altura), sem colisão (as paredes entre a
# lente e a protagonista somem pelo corte de maquete; móveis ficam
# translúcidos), acompanhamento suave com zona morta e troca de cômodo por
# deslizamento — nada de cortes.

var _fixed_last_zone: Node = null
var _fixed_transition_left: float = 0.0
var _fixed_target: Vector3            ## ponto de mira suavizado (sem zona morta)
var _fixed_aim: Vector3               ## ponto de mira com zona morta
var _fixed_vel := Vector3.ZERO
var _fixed_yaw: float = 0.0           ## graus
var _fixed_pitch: float = 17.0
var _fixed_distance: float = 13.0
var _fixed_fov: float = 30.0
var _fixed_lead_now: float = 0.0
var _follow_light: OmniLight3D


func _fixed_zone_params() -> Dictionary:
	var zone: Node = _stage_zone if _stage_zone != null else (current_zone if current_zone != null else _fixed_last_zone)
	var offset: Vector3 = default_offset if zone == null else _zone_value(zone, "camera_offset", default_offset)
	var flat := Vector2(offset.x, offset.z)
	var yaw := rad_to_deg(atan2(flat.x, flat.y)) if flat.length() > 0.01 else 90.0
	var dist := clampf(offset.length() * fixed_distance_scale, fixed_min_distance, fixed_max_distance)
	var r := {"yaw": yaw, "pitch": fixed_pitch_degrees, "distance": dist, "fov": fixed_fov,
		"zlim": false, "zmin": 0.0, "zmax": 0.0}
	r.zone = zone
	if zone != null and _is_room_stage(zone):
		# Cômodo: os limites vêm da própria caixa do palco (ver _stage_clamp).
		return r
	if zone != null and bool(_zone_value(zone, "use_z_limits", false)):
		r.zlim = true
		r.zmin = float(_zone_value(zone, "minimum_camera_z", 0.0))
		r.zmax = float(_zone_value(zone, "maximum_camera_z", 0.0))
	return r


func _fixed_goal(player_position: Vector3, params: Dictionary) -> Vector3:
	var aim := player_position + Vector3.UP * fixed_pivot_height
	if params.zlim:
		aim.z = clampf(aim.z, minf(params.zmin, params.zmax), maxf(params.zmin, params.zmax))
	return aim


func _fixed_basis() -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(-_fixed_pitch), deg_to_rad(_fixed_yaw), 0.0))


func _snap_fixed() -> void:
	var p := _player_position()
	_update_stage_zone(p, true)
	var params := _fixed_zone_params()
	_fixed_yaw = params.yaw
	_fixed_pitch = params.pitch
	_fixed_distance = params.distance
	_fixed_fov = params.fov
	_fixed_target = _stage_clamp(_fixed_goal(p, params), p, params)
	_fixed_aim = _fixed_target
	_fixed_vel = Vector3.ZERO
	_fixed_lead_now = 0.0
	_fixed_transition_left = 0.0
	_apply_fixed(p, 0.0)
	_update_stage_cut(p, 0.0)
	_update_cutaway(p, 1.0)
	_update_prop_fade(p, 0.0)


func _process_fixed(delta: float) -> void:
	var p := _player_position()
	_update_stage_zone(p, false)
	var params := _fixed_zone_params()
	_tension = _damp(_tension, _tension_target, tension_blend_speed, delta)
	_fixed_transition_left = maxf(0.0, _fixed_transition_left - delta)
	var in_transition := _fixed_transition_left > 0.0
	# Ângulo, distância e FOV da zona: mudam devagar (ficam iguais entre a
	# maioria dos cômodos; a troca é um deslizamento, não um giro).
	var param_speed := 1.6 if in_transition else 2.5
	_fixed_yaw = _damp_angle_deg(_fixed_yaw, params.yaw, param_speed, delta)
	_fixed_pitch = _damp(_fixed_pitch, params.pitch, param_speed, delta)
	_fixed_distance = _damp(_fixed_distance, params.distance + tension_distance_add * 0.5 * _tension, param_speed, delta)
	_fixed_fov = _damp(_fixed_fov, params.fov + tension_fov_add * 0.5 * _tension, param_speed, delta)

	# Antecipação lateral (no eixo da tela) na direção do movimento.
	var right := _fixed_basis().x
	right.y = 0.0
	right = right.normalized()
	var vel: Vector3 = player.velocity if "velocity" in player else Vector3.ZERO
	var lateral := vel.dot(right)
	var lead_goal := clampf(lateral / 3.0, -1.0, 1.0) * fixed_lead
	_fixed_lead_now = _damp(_fixed_lead_now, lead_goal, 1.2, delta)
	var goal := _fixed_goal(p, params) + right * _fixed_lead_now
	if params.zlim:
		goal.z = clampf(goal.z, minf(params.zmin, params.zmax), maxf(params.zmin, params.zmax))
	goal = _stage_clamp(goal, p, params)

	# Zona morta: só no eixo lateral da tela; profundidade e altura acompanham.
	var to_goal := goal - _fixed_aim
	var side := to_goal.dot(right)
	var excess := signf(side) * maxf(absf(side) - fixed_dead_zone, 0.0)
	var aim_goal := _fixed_aim + right * excess + (to_goal - right * side)
	var smooth := lerpf(fixed_smooth_time, fixed_transition_smooth_time, clampf(_fixed_transition_left / maxf(fixed_transition_time, 0.01), 0.0, 1.0))
	smooth /= (1.0 + (tension_follow_multiplier - 1.0) * _tension)
	_fixed_aim = _smooth_damp(_fixed_aim, aim_goal, smooth, delta)
	# Garantia: por mais suave que seja a troca de cômodo, a protagonista nunca
	# sai do quadro (no máximo 70% da meia-largura visível, conforme a tela).
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0) if vp.y > 0.0 else 1.0
	var half_w := tan(deg_to_rad(_fixed_fov) * 0.5) * minf(aspect, 1.78) * _fixed_distance * 0.7
	var lat := (p - _fixed_aim).dot(right)
	if absf(lat) > half_w:
		_fixed_aim += right * (lat - signf(lat) * half_w)
	_apply_fixed(p, delta)
	_update_stage_cut(p, delta)
	_update_cutaway(p, delta)
	_update_prop_fade(p, delta)


## Diagnóstico: posição da protagonista usada no último quadro (testes).
var last_framed_position: Vector3


func _apply_fixed(player_position: Vector3, _delta: float) -> void:
	last_framed_position = player_position
	var b := _fixed_basis()
	camera.global_position = _fixed_aim + b.z * _fixed_distance
	camera.global_basis = b
	camera.fov = _fixed_fov
	_control_yaw = deg_to_rad(_fixed_yaw)
	_rig_position = camera.global_position
	last_composition = Vector2.ZERO
	_update_follow_light(player_position)


## Amortecimento crítico (estilo SmoothDamp): sem tranco, sem passar do alvo.
func _smooth_damp(current: Vector3, target: Vector3, smooth_time: float, delta: float) -> Vector3:
	if delta <= 0.0:
		return target
	var omega := 2.0 / maxf(smooth_time, 0.0001)
	var x := omega * delta
	var k := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := current - target
	var temp := (_fixed_vel + omega * change) * delta
	_fixed_vel = (_fixed_vel - omega * temp) * k
	return target + (change + temp) * k


## Luz suave que acompanha a protagonista (do lado da câmera, um pouco acima):
## o caminho por onde ela anda fica sempre legível, o resto continua escuro.
func _update_follow_light(player_position: Vector3) -> void:
	if not follow_light_enabled:
		if _follow_light != null:
			_follow_light.visible = false
		return
	if _follow_light == null:
		_follow_light = OmniLight3D.new()
		_follow_light.name = "LuzDaProtagonista"
		_follow_light.light_color = follow_light_color
		_follow_light.shadow_enabled = true
		_follow_light.omni_attenuation = 1.4
		_follow_light.light_cull_mask &= ~CUT_LAYER
		add_child(_follow_light)
	_follow_light.visible = true
	_follow_light.light_energy = follow_light_energy
	_follow_light.omni_range = follow_light_range
	var toward_cam := camera.global_position - player_position
	toward_cam.y = 0.0
	toward_cam = toward_cam.normalized() if toward_cam.length() > 0.01 else Vector3.RIGHT
	_follow_light.global_position = player_position + Vector3.UP * 2.6 + toward_cam * 1.1


## Câmera fixa: paredes (peças CSG da escola) entre a lente e a protagonista.
## Esconde a parede inteira (rodapé, friso e reboco do mesmo trecho).
func _walls_in_view(player_position: Vector3) -> Array:
	var found := {}
	var space := get_world_3d().direct_space_state
	for h in [0.2, 0.4, 0.7, 1.0, 1.3, 1.6, 2.0, 2.6]:
		var exclude: Array[RID] = []
		if player is CollisionObject3D:
			exclude.append(player.get_rid())
		for i in 6:
			var q := PhysicsRayQueryParameters3D.create(camera.global_position, player_position + Vector3.UP * h, collision_mask, exclude)
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			exclude.append(hit.rid)
			var c: Object = hit.collider
			if c is CSGShape3D and not (c as Node).is_in_group("camera_fade"):
				var csg := c as CSGShape3D
				var box := csg.global_transform * csg.get_aabb()
				if box.size.y >= 0.1 and box.size.y < 9.0 and not (box.size.y < 0.5 and (box.size.x > 3.0 and box.size.z > 3.0)):
					found[csg] = true
					var stem := String(csg.name).get_slice("_", 0)
					for sib in csg.get_parent().get_children():
						if sib is GeometryInstance3D and String(sib.name).get_slice("_", 0) == stem:
							found[sib] = true
	# Vergas (peças visuais sem colisão) no caminho da visão.
	for node in _visual_solid_nodes:
		if is_instance_valid(node):
			var vb: AABB = node.global_transform * node.get_aabb()
			for h in [1.0, 1.6]:
				if _segment_enters_aabb(camera.global_position, player_position + Vector3.UP * h, vb) >= 0.0 or vb.grow(0.3).has_point(camera.global_position):
					found[node] = true
					break
	return found.keys()


# Câmera fixa: TODA parede da frente da maquete (fina no eixo da visão, entre
# a lente e a protagonista, dentro do quadro) sai — não só as da lista da zona.
# Sem isso sobravam "lâminas" de parede no primeiro plano ao passar por portas.
var _wall_cache: Array = []


func _front_walls(player_position: Vector3) -> Array:
	if _wall_cache.is_empty():
		var school := get_parent().get_node_or_null("School")
		if school == null:
			return []
		for n in school.find_children("*", "CSGShape3D", true, false):
			var csg := n as CSGShape3D
			if not csg.is_root_shape() or csg.is_in_group("camera_fade") or not csg.visible:
				continue
			var b := csg.global_transform * csg.get_aabb()
			if b.size.y >= 1.0 and minf(b.size.x, b.size.z) < 0.5 and maxf(b.size.x, b.size.z) > 0.4:
				_wall_cache.append(csg)
	var fwd := -camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var cam := camera.global_position
	var cam_depth := (cam - player_position).dot(-fwd)
	var cam_lat := cam.dot(right)
	var out: Array = []
	for csg in _wall_cache:
		if not is_instance_valid(csg):
			continue
		var b: AABB = csg.global_transform * csg.get_aabb()
		if absf(fwd.x) * b.size.x + absf(fwd.z) * b.size.z > 0.8:
			continue
		var depth := (b.get_center() - player_position).dot(-fwd)
		if depth < 0.25 or depth > cam_depth:
			continue
		if b.end.y < player_position.y - 0.5 or b.position.y > player_position.y + 9.0:
			continue
		var lat0 := INF
		var lat1 := -INF
		for i in 8:
			var l := b.get_endpoint(i).dot(right)
			lat0 = minf(lat0, l)
			lat1 = maxf(lat1, l)
		if lat1 < cam_lat - 14.0 or lat0 > cam_lat + 14.0:
			continue
		out.append(csg)
	return out


# ================================================================ palco (câmera fixa)
# Correção do bug "parede do corredor aparece quando a protagonista entra na
# sala". Cada zona de câmera é um PALCO (a caixa da zona). Como numa maquete de
# verdade:
#  1. tudo o que está inteiro entre a lente e a frente do palco some (corredor,
#     parede da frente da sala, folhas de porta, móveis do corredor) — com um
#     fade curto, sem piscar; chão fica (senão a base do quadro vira um buraco);
#  2. num cômodo, a mira fica presa dentro do palco: o quadro não passa das
#     paredes laterais, então o vazio de fora e as paredes vizinhas não aparecem;
#  3. a zona ativa é a que CONTÉM a protagonista (com histerese na soleira),
#     não a primeira que registrou — acabou a troca de palco no meio da porta.

## Fração da profundidade que a mira acompanha num cômodo (0 = centro fixo do
## palco, 1 = segue a protagonista inteira). Mais baixo = mais "diorama".
@export var stage_depth_follow: float = 0.45
## Duração (s) do fade das peças que saem/voltam ao palco.
@export var stage_fade_time: float = 0.22

var _stage_zone: Node = null
var _stage_hidden: Dictionary = {}      # GeometryInstance3D -> {"layers", "alpha"}
var _stage_fading: Dictionary = {}      # GeometryInstance3D -> alvo de transparência
var _stage_cache: Array = []            # [GeometryInstance3D, AABB, dinâmico?]


func _zone_box(zone: Node) -> AABB:
	if zone != null and zone.has_method("get_stage_box"):
		return zone.get_stage_box()
	return AABB()


func _is_room_stage(zone: Node) -> bool:
	if zone == null or not zone.has_method("get_stage_box"):
		return false
	var mode := int(_zone_value(zone, "stage_mode", 0))
	if mode == 1:
		return true
	if mode == 2:
		return false
	var box: AABB = zone.get_stage_box()
	var fwd := _stage_forward(zone)
	return absf(fwd.x) * box.size.x + absf(fwd.z) * box.size.z > 8.0


## Direção horizontal da visão definida pela zona (para dentro do palco).
func _stage_forward(zone: Node) -> Vector3:
	var offset: Vector3 = default_offset if zone == null else _zone_value(zone, "camera_offset", default_offset)
	var f := Vector3(-offset.x, 0.0, -offset.z)
	return f.normalized() if f.length() > 0.01 else Vector3.LEFT


func _update_stage_zone(p: Vector3, force: bool) -> void:
	var candidates: Array = []
	for z in _all_stage_zones():
		var box := _zone_box(z)
		if box.grow(0.05).has_point(Vector3(p.x, box.get_center().y, p.z)) and p.y > box.position.y - 1.0 and p.y < box.end.y + 1.0:
			candidates.append(z)
	if candidates.is_empty():
		if _stage_zone == null:
			_stage_zone = current_zone
		return
	if not force and _stage_zone in candidates:
		# Histerese: só troca quando ela entra ≥ 0,6 m no outro palco.
		var keep := true
		for z in candidates:
			if z != _stage_zone and _zone_box(z).grow(-0.6).has_point(Vector3(p.x, _zone_box(z).get_center().y, p.z)):
				keep = false
		if keep:
			return
	var best: Node = null
	var best_prio := -999999
	var best_depth := -INF
	for z in candidates:
		if z == _stage_zone and candidates.size() > 1 and not force:
			continue
		var prio := int(_zone_value(z, "camera_priority", 0))
		var box := _zone_box(z)
		# Mais "dentro" = maior distância até a borda da caixa.
		var inside := minf(minf(p.x - box.position.x, box.end.x - p.x), minf(p.z - box.position.z, box.end.z - p.z))
		if prio > best_prio or (prio == best_prio and inside > best_depth):
			best = z
			best_prio = prio
			best_depth = inside
	if best != null and best != _stage_zone:
		if _stage_zone != null:
			_fixed_transition_left = fixed_transition_time
		_stage_zone = best
		_fixed_last_zone = best
		# Recalcula a lista de peças (móveis e portas podem ter sido criados
		# depois do primeiro quadro, ou mudado de lugar).
		_stage_cache.clear()


var _stage_zone_list: Array = []


func _all_stage_zones() -> Array:
	if _stage_zone_list.is_empty():
		for n in get_tree().root.find_children("*", "Area3D", true, false):
			if n.has_method("get_stage_box") and n.is_inside_tree() and (n as Area3D).monitoring:
				_stage_zone_list.append(n)
	return _stage_zone_list


## Num cômodo: mantém o quadro dentro das paredes do palco.
func _stage_clamp(goal: Vector3, p: Vector3, params: Dictionary) -> Vector3:
	var zone: Node = params.get("zone", null)
	if zone == null or not _is_room_stage(zone):
		return goal
	var box := _zone_box(zone)
	var fwd := _stage_forward(zone)
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	# Profundidade: entre o centro do palco e a protagonista.
	var center_depth := box.get_center().dot(fwd)
	var depth_now := goal.dot(fwd)
	var depth_goal := lerpf(center_depth, depth_now, clampf(stage_depth_follow, 0.0, 1.0))
	# Perto da parede da frente a mira não pode ficar muito "atrás" dela, senão
	# os pés saem pela base do quadro.
	depth_goal = minf(depth_goal, depth_now + 1.4)
	goal += fwd * (depth_goal - depth_now)
	# Lateral: o quadro (na profundidade da protagonista) não passa das paredes.
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0) if vp.y > 0.0 else 1.78
	var dist_to_player := float(params.distance) + (p.dot(fwd) - depth_goal)
	var half_vis := tan(deg_to_rad(float(params.fov)) * 0.5) * aspect * maxf(dist_to_player, 1.0)
	var margin := float(_zone_value(zone, "stage_side_margin", 0.4))
	var lat0 := INF
	var lat1 := -INF
	for i in 8:
		var l := box.get_endpoint(i).dot(right)
		lat0 = minf(lat0, l)
		lat1 = maxf(lat1, l)
	var lo := lat0 - margin + half_vis
	var hi := lat1 + margin - half_vis
	var lat := goal.dot(right)
	var clamped := (lo + hi) * 0.5 if lo > hi else clampf(lat, lo, hi)
	# A lente nunca encosta nas paredes laterais: lá ficam estantes e armários
	# altos (móveis 3x); a câmera entrava neles.
	var clear := stage_wall_clearance
	if lat0 + clear < lat1 - clear:
		clamped = clampf(clamped, lat0 + clear, lat1 - clear)
	goal += right * (clamped - lat)
	return goal


func _build_stage_cache() -> void:
	_stage_cache.clear()
	var main := get_parent()
	for g in main.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if gi == null or not gi.is_inside_tree():
			continue
		if gi is CSGShape3D and not (gi as CSGShape3D).is_root_shape():
			continue
		if player.is_ancestor_of(gi) or is_ancestor_of(gi):
			continue
		var skip := false
		var n: Node = gi.get_parent()
		var dynamic := false
		while n != null and n != main:
			if n is CharacterBody3D or n is CanvasLayer or String(n.name) == "Exterior":
				skip = true
				break
			if n.is_in_group("door"):
				dynamic = true
			n = n.get_parent()
		if skip:
			continue
		var fadeable := dynamic
		n = gi
		while n != null and n != main and not fadeable:
			if n.is_in_group("camera_fade") or n.is_in_group("hiding_spot") or n.is_in_group("interactable") or String(n.name) == "Props":
				fadeable = true
			n = n.get_parent()
		_stage_cache.append([gi, gi.global_transform * gi.get_aabb(), dynamic, fadeable])


func _update_stage_cut(p: Vector3, delta: float) -> void:
	if _stage_cache.is_empty():
		_build_stage_cache()
	var zone := _stage_zone
	var cut_now := {}
	if zone != null:
		var box := _zone_box(zone)
		var fwd := _stage_forward(zone)
		var front := INF
		for i in 8:
			front = minf(front, box.get_endpoint(i).dot(fwd))
		var floor_y := box.position.y
		for entry in _stage_cache:
			var g: GeometryInstance3D = entry[0]
			if not is_instance_valid(g):
				continue
			var b: AABB = g.global_transform * g.get_aabb() if entry[2] else entry[1]
			# Chão/tapetes ficam (só o que tem altura sai).
			if b.end.y < floor_y + 0.35 and b.size.y < 0.5:
				continue
			var far := -INF
			for i in 8:
				far = maxf(far, b.get_endpoint(i).dot(fwd))
			# Inteira na frente do palco (a parede da frente, na borda, também sai).
			if far < front + 0.35:
				cut_now[g] = true
	# Entram no corte: fade de saída e depois a camada de recorte.
	for g in cut_now:
		if not _stage_hidden.has(g):
			_stage_hidden[g] = {"layers": g.layers if not _hidden_geometry.has(g) else int(_hidden_geometry[g].get("layers", g.layers)), "alpha": g.transparency}
			if delta <= 0.0:
				g.layers = CUT_LAYER
			else:
				_stage_fading[g] = 1.0
	# Saem do corte: volta a camada e faz fade de entrada.
	for g in _stage_hidden.keys():
		if cut_now.has(g):
			continue
		var saved: Dictionary = _stage_hidden[g]
		_stage_hidden.erase(g)
		if not is_instance_valid(g):
			_stage_fading.erase(g)
			continue
		if _hidden_geometry.has(g):
			continue
		g.layers = int(saved.layers)
		if delta <= 0.0:
			g.transparency = float(saved.alpha)
			_stage_fading.erase(g)
		else:
			if g.layers != CUT_LAYER and g.transparency < 0.99 and not _stage_fading.has(g):
				g.transparency = 1.0
			_stage_fading[g] = float(saved.alpha)
	# Anda os fades.
	var step := 1.0 if delta <= 0.0 else delta / maxf(stage_fade_time, 0.01)
	for g in _stage_fading.keys():
		if not is_instance_valid(g):
			_stage_fading.erase(g)
			continue
		var target: float = _stage_fading[g]
		g.transparency = move_toward(g.transparency, target, step)
		if is_equal_approx(g.transparency, target):
			_stage_fading.erase(g)
			if _stage_hidden.has(g):
				g.layers = CUT_LAYER
				g.transparency = float(_stage_hidden[g].alpha)


## Diagnóstico (testes): palco atual e quantas peças estão fora dele.
func get_stage_state() -> Dictionary:
	return {"zone": _stage_zone.name if _stage_zone else "", "cut": _stage_hidden.size()}


func _screen_rect_of(b: AABB) -> Rect2:
	var r := Rect2()
	var first := true
	for i in 8:
		var w := b.get_endpoint(i)
		if camera.is_position_behind(w):
			return Rect2()
		var sp := camera.unproject_position(w)
		if first:
			r = Rect2(sp, Vector2.ZERO)
			first = false
		else:
			r = r.expand(sp)
	return r


func _screen_fade(player_position: Vector3, hit_now: Dictionary) -> void:
	if _stage_cache.is_empty():
		return
	var body := AABB(player_position + Vector3(-0.35, 0.0, -0.35), Vector3(0.7, 1.85, 0.7))
	var body_rect := _screen_rect_of(body)
	if not body_rect.has_area():
		return
	body_rect = body_rect.grow(6.0)
	var fwd := -camera.global_basis.z
	var cam := camera.global_position
	var player_depth := (player_position - cam).dot(fwd)
	for entry in _stage_cache:
		if entry.size() < 4 or not entry[3]:
			continue
		var g: GeometryInstance3D = entry[0]
		if not is_instance_valid(g) or _stage_hidden.has(g) or g.layers == CUT_LAYER:
			continue
		var b: AABB = g.global_transform * g.get_aabb() if entry[2] else entry[1]
		if b.size.y < 0.6:
			continue
		var near := INF
		var far := -INF
		for i in 8:
			var d := (b.get_endpoint(i) - cam).dot(fwd)
			near = minf(near, d)
			far = maxf(far, d)
		# Precisa estar inteiro na frente dela (não ao lado nem atrás).
		if far > player_depth - 0.2 or far < 0.0:
			continue
		var r := _screen_rect_of(b)
		# Folhas de porta abertas viradas para a lente: somem se estiverem perto
		# dela na tela (eram o "bloco preto" na saída da sala inicial).
		var rect := body_rect.grow(get_viewport().get_visible_rect().size.x * 0.18) if entry[2] else body_rect
		if r.has_area() and r.intersects(rect):
			hit_now[g] = true
