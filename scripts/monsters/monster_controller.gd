class_name MonsterController
extends CharacterBody3D
## Máquina de estados compartilhada pelos monstros. O comportamento de cada
## criatura vem do seu MonsterConfig (e, no futuro, de subclasses pequenas).
## Não contém conteúdo de enigmas: o despertar chega pelo MonsterTrigger.

signal state_changed(previous: State, current: State)
signal activated(reason: StringName)
signal awakening_started
signal player_detected
signal player_lost
signal player_caught
## Etapa 5, Fase 3: todo estímulo recebido e a reação (SoundStimulus.Reaction).
## A narrativa NÃO usa este sinal (dispararia a cada som): ela recebe só a
## mudança real de estado por state_changed, com last_state_cause = &"som".
signal sound_perceived(stimulus: SoundStimulus, reaction: int)
## Pistas mecánicas sin depender de audio o modelos finales.
signal mechanic_cue(monster_id: StringName, cue: StringName, world_position: Vector3)
signal false_voice_emitted(world_position: Vector3, clue: String)
## Versão 6.2: começou a perseguir depois de ouvir (o modelo vira a cabeça).
signal listening_started
## Versão 6.2 (Maestro): começou a levitar a Yuko / ela escapou.
signal grip_started
signal grip_released

enum State { INACTIVE, AWAKENING, INVESTIGATING, PATROLLING, CHASING, SEARCHING, RETURNING }

@export var config: MonsterConfig
## Prompt 2: id do monstro em data/game_data.json ("monsters"). Usado quando
## config não é atribuído diretamente (testes ainda podem atribuir um config).
@export var config_id: StringName
## Ponto de origem (usa o ProfessorSpawn existente na cena).
@export var home_marker: Node3D
## Pontos de patrulha opcionais. Vazio = vigia parado na posição inicial.
@export var patrol_points: Array[Node3D] = []
@export var gravity: float = 20.0
## Texto de depuração (nome + estado) acima do monstro. Desligado no jogo
## normal. Para testes: marque aqui no Inspector ou rode o jogo com
## o argumento de usuário --debug-monsters (ex.: godot -- --debug-monsters).
@export var debug_label: bool = false
@export_group("Versão 6.2")
## Ao começar a perseguir, para e escuta por este tempo (s) antes de andar
## (o modelo vira a cabeça). 0 = parte direto.
@export var listen_pause: float = 0.0
## Em vez de encostar, faz a Yuko levitar quando chega perto. Ela ainda
## escapa se sair de levitate_release antes de levitate_time.
@export var levitate_catch: bool = false
@export var levitate_range: float = 2.6
@export var levitate_release: float = 3.6
@export var levitate_time: float = 1.9
## Depois que ela escapa, ele fica parado (atordoado) por este tempo (s).
@export var levitate_stun: float = 1.6

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var perception: MonsterPerception = $Perception

var state: State = State.INACTIVE
var activation_reason: StringName = &""

var _player: Node3D
var _home_position: Vector3
var _home_yaw: float
var _state_time: float = 0.0
var _sight_meter: float = 0.0
var _unseen_time: float = 0.0
var _last_known_position: Vector3
var _stimulus_position: Vector3
var _caught_this_chase: bool = false

var _search_points: Array[Vector3] = []
var _search_wait: float = 0.0
var _patrol_index: int = 0

var _move_target: Vector3
var _has_move_target: bool = false
var _stuck_timer: float = 0.0
var _stuck_origin: Vector3
var _look_yaw_target = null
var _look_base_yaw = null

var _label: Label3D
var _home_snapped: bool = false

## Motivo da última troca de estado (&"som" quando veio da audição; vazio nas
## demais). Lido por quem escuta state_changed, sem mudar a assinatura dele.
var last_state_cause: StringName = &""

# Audição (Fase 3)
var _last_heard_position: Vector3
var _last_heard_id: int = 0
var _last_heard_msec: int = -1000000
var _processed_ids: Dictionary = {}   # id do estímulo -> msec
var _archetype: StringName = &"octopus"
var _cue_cooldown: float = 0.0
var _last_cue_state: State = State.INACTIVE
var _listen_left: float = 0.0
## < 0 = não está levitando ninguém; >= 0 = segundos de levitação.
var _grip_time: float = -1.0
var _stun_left: float = 0.0


## Busca o MonsterConfig no banco JSON pelo config_id. Pode ser chamado antes do
## _ready (o MonsterTrigger, filho, fica pronto antes do monstro).
func resolve_config() -> MonsterConfig:
	if config == null and config_id != &"":
		config = GameData.get_instance().get_monster(config_id)
	return config


func _ready() -> void:
	add_to_group("monster")
	add_to_group(SoundStimulus.LISTENER_GROUP)
	resolve_config()
	if config == null:
		push_error("%s: MonsterConfig não atribuído (config_id \"%s\" não encontrado em data/game_data.json)." % [name, config_id])
		config = MonsterConfig.new()

	if home_marker != null:
		global_position = Vector3(home_marker.global_position.x, global_position.y, home_marker.global_position.z)
	_home_position = global_position
	_home_yaw = rotation.y

	_archetype = config_id if config_id != &"" else config.monster_id
	perception.config = config
	perception.body = self
	perception.position.y = config.eye_height
	agent.navigation_layers = config.navigation_layers
	_setup_visual()

	if debug_label or "--debug-monsters" in OS.get_cmdline_user_args():
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		# Respeita a profundidade: nunca aparece através de paredes.
		_label.no_depth_test = false
		_label.font_size = 40
		_label.position.y = config.eye_height + 1.2
		add_child(_label)
	_update_label()


# ------------------------------------------------------------ API pública

## Desperta o monstro. Só tem efeito a partir de INACTIVE, então chamadas
## repetidas não duplicam a ativação. skip_awakening é usado ao carregar save.
func activate(reason: StringName, stimulus_position: Vector3, skip_awakening: bool = false) -> bool:
	if state != State.INACTIVE:
		return false
	activation_reason = reason
	_stimulus_position = stimulus_position
	activated.emit(reason)
	if skip_awakening:
		_change_state(State.PATROLLING)
	else:
		_change_state(State.AWAKENING)
	return true


func is_active() -> bool:
	return state != State.INACTIVE


## Fluxo da sala (StoryDirector): o professor "se acalma" e volta a dormir.
## to_home = reaparece no posto (usado quando a Yuko já saiu da sala).
## Depois disso activate() funciona de novo (a resposta certa o acorda).
func deactivate(to_home: bool = false) -> void:
	_listen_left = 0.0
	_stun_left = 0.0
	if to_home:
		global_position = _home_position
		rotation.y = _home_yaw
		velocity = Vector3.ZERO
	_change_state(State.INACTIVE)
	_set_camera_tension(0.0)


func get_home_position() -> Vector3:
	return _home_position


## Fluxo da sala (StoryDirector): o professor "sabe" onde ela está e corre
## atrás (ouviu, farejou). Chamado de tempos em tempos durante os primeiros
## 30 s de perseguição; enquanto ela não se esconde ele não desiste.
func hunt(target: Vector3) -> void:
	if state == State.INACTIVE or state == State.AWAKENING:
		return
	_last_known_position = target
	_unseen_time = 0.0
	if state != State.CHASING:
		_change_state(State.CHASING, &"perseguicao")


## Ela sumiu (escondida): ele para de correr direto para ela e procura em
## volta do último lugar onde a ouviu.
func lose_track() -> void:
	if state == State.CHASING:
		_change_state(State.SEARCHING, &"perdeu_rastro")


## Procurar mais um pouco em volta de um ponto (usado enquanto ela está
## escondida e ainda não deu o tempo mínimo da perseguição).
func prowl(around: Vector3) -> void:
	if state == State.INACTIVE or state == State.AWAKENING or state == State.CHASING:
		return
	_last_known_position = around
	if state == State.SEARCHING:
		_state_time = 0.0
		_has_move_target = false
		_build_search_points()
	else:
		_change_state(State.SEARCHING, &"rondando")


## Desiste e volta para o posto (depois o roteiro diz "ele se acalmou").
func give_up() -> void:
	if state != State.INACTIVE and state != State.RETURNING and state != State.PATROLLING:
		_change_state(State.RETURNING, &"desistiu")


## Estímulo sonoro (Etapa 5, Fase 3). Entrada única da audição.
## - hear_stimulus(posição): ordem direta de roteiro/teste — investiga sem
##   conferir alcance (comportamento anterior; respeita estados e duplicatas).
## - hear_stimulus(posição, intensidade, tipo, fonte) ou
##   receive_sound_stimulus(SoundStimulus): som "de verdade", avaliado pelo
##   MonsterPerception com o HearingProfile do MonsterConfig.
## Retorna SoundStimulus.Reaction.
func hear_stimulus(position: Vector3, loudness: float = -1.0, kind: StringName = SoundStimulus.KIND_GENERIC, source_id: StringName = &"") -> int:
	var stimulus: SoundStimulus
	if loudness < 0.0:
		stimulus = SoundStimulus.scripted_at(position, source_id if source_id != &"" else &"roteiro")
	else:
		stimulus = SoundStimulus.new(position, loudness, kind, source_id)
	return receive_sound_stimulus(stimulus)


## Contrato do grupo SoundStimulus.LISTENER_GROUP (usado pelas fontes de som).
func receive_sound_stimulus(stimulus: SoundStimulus) -> int:
	var reaction := _evaluate_stimulus(stimulus)
	if reaction == SoundStimulus.Reaction.INVESTIGATE:
		_investigate_sound(stimulus)
	sound_perceived.emit(stimulus, reaction)
	return reaction


## Último som que levou (ou manteve) uma investigação. Não é a posição da
## protagonista: é onde o som aconteceu, congelado no momento do estímulo.
func get_last_heard_position() -> Vector3:
	return _last_heard_position


func has_heard_sound() -> bool:
	return _last_heard_id != 0


## true quando o mapa de navegação já foi sincronizado com a região da sala.
func is_navigation_ready() -> bool:
	return _home_snapped


func get_state_name() -> String:
	return State.keys()[state]


# ------------------------------------------------------------ ciclo

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	_state_time += delta
	_cue_cooldown = maxf(0.0, _cue_cooldown - delta)
	if not _home_snapped:
		_snap_home_to_navmesh()
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D

	if state != State.INACTIVE and state != State.AWAKENING:
		_update_perception(delta)

	match state:
		State.INACTIVE:
			_stop()
		State.AWAKENING:
			_stop()
			if _state_time >= config.awakening_duration:
				_change_state(State.INVESTIGATING)
		State.INVESTIGATING:
			_process_investigating()
		State.PATROLLING:
			_process_patrolling()
		State.CHASING:
			_process_chasing()
		State.SEARCHING:
			_process_searching(delta)
		State.RETURNING:
			if _move_step(config.patrol_speed, delta) == &"arrived":
				_change_state(State.PATROLLING)

	if state in [State.INVESTIGATING, State.PATROLLING, State.CHASING, State.SEARCHING]:
		_move_step(_speed_for_state(), delta)

	_apply_rotation(delta)
	move_and_slide()


# ------------------------------------------------------------ estados

func _change_state(new_state: State, cause: StringName = &"") -> void:
	if new_state == state:
		return
	var previous := state
	if previous == State.CHASING and _grip_time >= 0.0:
		_release_grip(false)
	state = new_state
	last_state_cause = cause
	_state_time = 0.0
	_has_move_target = false
	_look_yaw_target = null
	_look_base_yaw = null
	agent.target_position = global_position

	match new_state:
		State.AWAKENING:
			awakening_started.emit()
		State.INVESTIGATING:
			_set_move_target(_stimulus_position)
		State.PATROLLING:
			_patrol_index = 0
		State.CHASING:
			_caught_this_chase = false
			_unseen_time = 0.0
			if listen_pause > 0.0:
				_listen_left = listen_pause
				listening_started.emit()
			player_detected.emit()
		State.SEARCHING:
			_build_search_points()
			player_lost.emit()
		State.RETURNING:
			_set_move_target(_home_position)

	_set_camera_tension(config.chase_camera_tension if new_state == State.CHASING else 0.0)
	# Cada criatura comunica uma pista própria; sem depender de áudio/modelos.
	if new_state == State.CHASING and _archetype == &"painter":
		mechanic_cue.emit(_archetype, &"pintura_antecipa_perigo", _last_known_position)
	elif new_state == State.INVESTIGATING and _archetype == &"reader":
		false_voice_emitted.emit(_stimulus_position, "A voz pode imitar a protagonista. Confirme a mensagem por uma pista física.")
	_update_label()
	_play_state_animation()
	state_changed.emit(previous, new_state)


func _process_investigating() -> void:
	if not _has_move_target:
		# Chegou: olha em volta e depois volta ao posto.
		_look_around()
		if _state_time >= config.investigate_look_time:
			_change_state(State.RETURNING)


func _process_patrolling() -> void:
	if patrol_points.is_empty():
		if global_position.distance_to(_home_position) > 0.8 and not _has_move_target:
			_set_move_target(_home_position)
		elif not _has_move_target:
			_look_yaw_target = _home_yaw
		return
	if not _has_move_target:
		var point := patrol_points[_patrol_index % patrol_points.size()]
		_patrol_index += 1
		if point != null:
			_set_move_target(point.global_position)


func _process_chasing() -> void:
	if _player == null:
		_change_state(State.SEARCHING)
		return

	if _unseen_time > config.lose_sight_time:
		_change_state(State.SEARCHING)
		return

	var player_point := _player_point()
	var flat_distance := Vector2(global_position.x - player_point.x,
		global_position.z - player_point.z).length()
	var dt := get_physics_process_delta_time()

	# Versão 6.2: ouviu → para, vira a cabeça e só então persegue.
	if _listen_left > 0.0:
		_listen_left -= dt
		_has_move_target = false
		_look_at_point(_player.global_position)
		return
	if levitate_catch:
		_process_levitation(flat_distance, dt)
		return

	if flat_distance <= config.catch_distance and _unseen_time == 0.0:
		_has_move_target = false
		_look_at_point(_player.global_position)
		if not _caught_this_chase:
			_caught_this_chase = true
			player_caught.emit()
		return

	var chase_target := _last_known_position
	# O Ângulo tenta cortar a rota por pontos laterais, obrigando a observar
	# cantos e corredores; a NavigationAgent continua respeitando obstáculos.
	if _archetype == &"angle":
		var to_player := _last_known_position - global_position
		to_player.y = 0.0
		if to_player.length() > 0.1:
			var side := Vector3(-to_player.z, 0.0, to_player.x).normalized()
			chase_target = _closest_navigable(_last_known_position + side * 1.6)
	# O Cartógrafo procura o último ponto conhecido por mais tempo e em área maior.
	if _archetype == &"cartographer" and _state_time < 1.0:
		chase_target = _closest_navigable(_last_known_position)
	_set_move_target(chase_target)
	if not _has_move_target or agent.is_navigation_finished():
		# Alvo fora da área navegável: para no ponto mais próximo e encara.
		_look_at_point(_player.global_position)


## Versão 6.2 (Maestro): em vez de encostar, para a uns 2,6 m e faz a Yuko
## levitar. Enquanto ela sobe ainda dá para fugir (cada vez mais devagar): se
## passar de levitate_release, ela cai e ele fica atordoado um instante. Se
## completar levitate_time, ela perde (player_caught).
func _process_levitation(flat_distance: float, dt: float) -> void:
	if _stun_left > 0.0:
		_stun_left -= dt
		_has_move_target = false
		return
	if _grip_time >= 0.0:
		_has_move_target = false
		_look_at_point(_player.global_position)
		if flat_distance > levitate_release or (_player.has_method("is_hidden") and _player.is_hidden()):
			_release_grip(true)
			return
		_grip_time += dt
		_set_player_levitation(clampf(_grip_time / maxf(levitate_time, 0.01), 0.0, 1.0))
		if _grip_time >= levitate_time and not _caught_this_chase:
			_caught_this_chase = true
			player_caught.emit()
		return
	if flat_distance <= levitate_range and _unseen_time == 0.0 and not _caught_this_chase:
		_grip_time = 0.0
		_has_move_target = false
		_look_at_point(_player.global_position)
		grip_started.emit()
		return
	_set_move_target(_last_known_position)
	if not _has_move_target or agent.is_navigation_finished():
		_look_at_point(_player.global_position)


func _release_grip(stun: bool) -> void:
	_grip_time = -1.0
	_set_player_levitation(0.0)
	if stun:
		_stun_left = levitate_stun
	grip_released.emit()


func _set_player_levitation(amount: float) -> void:
	if _player != null and _player.has_method("set_levitation"):
		_player.set_levitation(amount)


func is_gripping() -> bool:
	return _grip_time >= 0.0


func _process_searching(delta: float) -> void:
	if _state_time >= config.search_duration:
		_change_state(State.RETURNING)
		return
	if _has_move_target:
		return
	if _search_wait > 0.0:
		_search_wait -= delta
		_look_around()
		return
	if _search_points.is_empty():
		_look_around()
		return
	_set_move_target(_search_points.pop_front())
	_search_wait = config.search_point_wait


func _build_search_points() -> void:
	_search_points.clear()
	_search_points.append(_last_known_position)
	var count := config.search_points
	var radius := config.search_radius
	if _archetype == &"cartographer":
		count += 3
		radius *= 1.8
	elif _archetype == &"painter":
		count = maxi(2, count - 1)
	elif _archetype == &"angle":
		radius *= 0.7
	for i in count:
		var angle := TAU * float(i) / maxf(1.0, float(count)) + randf() * 0.6
		var candidate := _last_known_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
		_search_points.append(_closest_navigable(candidate))


# ------------------------------------------------------------ audição

func _evaluate_stimulus(stimulus: SoundStimulus) -> int:
	if stimulus == null:
		return SoundStimulus.Reaction.OUT_OF_RANGE
	var now := Time.get_ticks_msec()
	var hearing := config.get_hearing()
	var memory_msec := int(maxf(hearing.merge_time, 1.0) * 1000.0) * 4
	for key in _processed_ids.keys():
		if now - int(_processed_ids[key]) > memory_msec:
			_processed_ids.erase(key)
	# O mesmo estímulo entregue duas vezes nunca gera duas reações.
	if _processed_ids.has(stimulus.id):
		return SoundStimulus.Reaction.DUPLICATE
	_processed_ids[stimulus.id] = now

	if state == State.INACTIVE or state == State.AWAKENING:
		return SoundStimulus.Reaction.IGNORED_STATE   # despertar só pelos gatilhos
	if not hearing.reacts_in(get_state_name()):
		return SoundStimulus.Reaction.IGNORED_STATE
	if not config.allowed_states.is_empty() and not "INVESTIGATING" in config.allowed_states:
		return SoundStimulus.Reaction.IGNORED_STATE

	var reaction: int = perception.evaluate_sound(stimulus)["reaction"]
	if reaction != SoundStimulus.Reaction.INVESTIGATE:
		return reaction

	# Mesmo local da investigação em curso, ou de uma que acabou há pouco:
	# é o mesmo som (ex.: fonte repetindo), não uma nova investigação.
	var target := _sound_target(stimulus.position)
	if _last_heard_id != 0 and _flat(target, _last_heard_position) <= hearing.merge_radius:
		if state == State.INVESTIGATING:
			return SoundStimulus.Reaction.MERGED
		if now - _last_heard_msec <= int(hearing.merge_time * 1000.0):
			return SoundStimulus.Reaction.MERGED
	return reaction


func _investigate_sound(stimulus: SoundStimulus) -> void:
	var target := _sound_target(stimulus.position)
	_last_heard_position = target
	_last_heard_id = stimulus.id
	_last_heard_msec = Time.get_ticks_msec()
	_stimulus_position = target
	if state == State.INVESTIGATING:
		# Correção (Etapa 4.5): um novo som durante a investigação era
		# ignorado, porque _change_state não troca para o mesmo estado.
		# Não reemite state_changed: a narrativa não dispara de novo.
		_state_time = 0.0
		_look_base_yaw = null
		_set_move_target(target)
	else:
		_change_state(State.INVESTIGATING, &"som")


## Ponto navegável mais próximo do som: o monstro vai até onde consegue
## chegar pelo navmesh, nunca através de paredes.
func _sound_target(position: Vector3) -> Vector3:
	if not is_navigation_ready():
		return position
	var closest := _closest_navigable(position)
	return Vector3(closest.x, position.y, closest.z)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ------------------------------------------------------------ percepção

## Prompt 2: escondida, a protagonista é procurada na frente do esconderijo.
func _player_point() -> Vector3:
	if _player != null and _player.has_method("get_chase_point"):
		return _player.get_chase_point()
	return _player.global_position if _player != null else global_position


func _update_perception(delta: float) -> void:
	# O Maestro é guiado por som: visão não inicia perseguição. Ele só reage
	# quando um SoundStimulus válido chega pelo sistema de audição existente.
	if _archetype == &"maestro":
		return
	var sees := perception.can_see(_player)

	if state == State.CHASING:
		if sees:
			_unseen_time = 0.0
			_last_known_position = _player_point()
		else:
			_unseen_time += delta
		return

	if sees:
		var reaction := config.reaction_time
		if _archetype == &"painter":
			reaction *= 1.7 # percebe mais devagar, mas a pista visual antecipa o perigo
		elif _archetype == &"angle":
			reaction *= 0.8
		_sight_meter += delta / maxf(reaction, 0.01)
		_last_known_position = _player_point()
		if _sight_meter >= 1.0:
			_sight_meter = 0.0
			_change_state(State.CHASING)
	else:
		_sight_meter = maxf(0.0, _sight_meter - delta / maxf(config.reaction_time, 0.01))


# ------------------------------------------------------------ navegação

## Garante que o posto de vigia esteja na área navegável; senão o monstro
## tentaria voltar para um ponto inalcançável indefinidamente.
func _snap_home_to_navmesh() -> void:
	var map := agent.get_navigation_map()
	# Só confia na consulta depois que alguma região foi sincronizada no mapa;
	# antes disso o servidor devolve a origem do mundo.
	if NavigationServer3D.map_get_iteration_id(map) == 0 or NavigationServer3D.map_get_regions(map).is_empty():
		return
	# Prontidão igual à de antes: espera o MAPA responder (a consulta por
	# região responde antes da sincronização do mapa, quando as rotas ainda
	# não funcionam). O ponto em si respeita a camada do monstro (Fase 4).
	if NavigationServer3D.map_get_closest_point(map, _home_position) == Vector3.ZERO and _state_time < 2.0:
		return
	var closest := _closest_navigable(_home_position)
	_home_snapped = true
	var flat_gap := Vector2(closest.x - _home_position.x, closest.z - _home_position.z).length()
	if flat_gap > 0.3:
		push_warning("%s: posição inicial fora do navmesh (%.2f m); usando o ponto navegável mais próximo." % [name, flat_gap])
		_home_position = Vector3(closest.x, _home_position.y, closest.z)


## Ponto navegável mais próximo, considerando só as regiões das camadas do
## monstro (Fase 4): com várias salas no mesmo mapa, um monstro nunca mira
## um ponto de outra sala. Com uma única região equivale a map_get_closest_point.
func _closest_navigable(point: Vector3) -> Vector3:
	var map := agent.get_navigation_map()
	var best := Vector3.ZERO
	var best_distance := INF
	for region in NavigationServer3D.map_get_regions(map):
		if not NavigationServer3D.region_get_enabled(region):
			continue
		if NavigationServer3D.region_get_navigation_layers(region) & agent.navigation_layers == 0:
			continue
		var candidate := NavigationServer3D.region_get_closest_point(region, point)
		var d := candidate.distance_squared_to(point)
		if d < best_distance:
			best_distance = d
			best = candidate
	if best_distance == INF:
		return NavigationServer3D.map_get_closest_point(map, point)
	return best


func _set_move_target(target: Vector3) -> void:
	if _has_move_target and target.distance_to(_move_target) < config.repath_distance:
		return
	_move_target = target
	_has_move_target = true
	agent.target_position = target
	_stuck_timer = 0.0
	_stuck_origin = global_position


## Retorna &"moving", &"arrived", &"idle" ou &"stuck".
func _move_step(speed: float, delta: float) -> StringName:
	if not _has_move_target:
		_brake(delta)
		return &"idle"

	if not is_navigation_ready():
		_brake(delta)
		return &"idle"

	if agent.is_navigation_finished():
		_has_move_target = false
		_brake(delta)
		return &"arrived"

	var next := agent.get_next_path_position()
	var direction := next - global_position
	direction.y = 0.0
	if direction.length() < 0.01:
		_brake(delta)
		return &"moving"

	direction = direction.normalized()
	var desired := direction * speed
	velocity.x = move_toward(velocity.x, desired.x, config.acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, config.acceleration * delta)
	_look_yaw_target = atan2(-direction.x, -direction.z)
	_look_base_yaw = null

	_stuck_timer += delta
	if _stuck_timer >= config.stuck_timeout:
		var progressed := global_position.distance_to(_stuck_origin)
		_stuck_timer = 0.0
		_stuck_origin = global_position
		if progressed < config.stuck_min_progress:
			_on_stuck()
			return &"stuck"
	return &"moving"


## Sem progresso: desiste do alvo atual sem repetir a mesma tentativa.
func _on_stuck() -> void:
	_has_move_target = false
	agent.target_position = global_position
	match state:
		State.CHASING:
			_change_state(State.SEARCHING)
		State.INVESTIGATING, State.RETURNING:
			_change_state(State.PATROLLING)
		State.PATROLLING:
			_home_position = global_position  # posto atual passa a ser o ponto de vigia


func _speed_for_state() -> float:
	match state:
		State.CHASING:
			# O Polvo corre diretamente; O Leitor acelera após uma voz falsa,
			# enquanto a Pintora é lenta e previsível.
			if _archetype == &"painter":
				return config.chase_speed * 0.78
			if _archetype == &"reader":
				return config.chase_speed * 1.08
			if _archetype == &"angle":
				return config.chase_speed * 0.92
			return config.chase_speed
		State.SEARCHING:
			return config.search_speed * (1.2 if _archetype == &"cartographer" else 1.0)
		State.INVESTIGATING:
			return config.investigate_speed * (0.75 if _archetype == &"painter" else 1.0)
	return config.patrol_speed


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _brake(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, config.acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, config.acceleration * delta)


# ------------------------------------------------------------ orientação

## Olha para os lados em torno da direção em que parou (±70°).
func _look_around() -> void:
	if _look_base_yaw == null:
		_look_base_yaw = rotation.y
	_look_yaw_target = float(_look_base_yaw) + sin(_state_time * 1.5) * deg_to_rad(70.0)


func _look_at_point(point: Vector3) -> void:
	var d := point - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		_look_yaw_target = atan2(-d.x, -d.z)


func _apply_rotation(delta: float) -> void:
	if _look_yaw_target == null:
		return
	var max_step := deg_to_rad(config.turn_speed_degrees) * delta
	var diff := angle_difference(rotation.y, float(_look_yaw_target))
	rotation.y += clampf(diff, -max_step, max_step)


func _set_camera_tension(amount: float) -> void:
	var camera_controller := get_tree().get_first_node_in_group("camera_controller")
	if camera_controller != null and camera_controller.has_method("set_tension"):
		camera_controller.set_tension(amount)


func _update_label() -> void:
	if _label != null:
		_label.text = "%s\n%s" % [config.display_name, get_state_name()]


# ------------------------------------------------------------ modelo visual (Fase 4)

var visual_model: Node3D
var _animation_player: AnimationPlayer


## Encaixe do modelo substituível. Sem config.visual_scene nada muda: o
## placeholder existente continua seguindo o corpo pelo VisualLink. Com um
## modelo, ele é instanciado como filho "VisualModel" e o placeholder antigo
## é escondido — controlador, percepção e narrativa não mudam.
func _setup_visual() -> void:
	if config.visual_scene == null:
		return
	var instance := config.visual_scene.instantiate()
	if not instance is Node3D:
		push_error("%s: visual_scene precisa ter um Node3D na raiz." % name)
		instance.free()
		return
	visual_model = instance
	visual_model.name = "VisualModel"
	visual_model.position = config.visual_offset
	add_child(visual_model)
	var link := get_node_or_null("VisualLink") as RemoteTransform3D
	if link != null and not link.remote_path.is_empty():
		var old_placeholder := link.get_node_or_null(link.remote_path) as Node3D
		link.remote_path = NodePath()
		if old_placeholder != null:
			old_placeholder.visible = false
	var players := visual_model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_animation_player = players[0]
	_play_state_animation()


## Toca a animação mapeada para o estado atual (animation_map), se houver.
## Animação ou AnimationPlayer ausente é ignorado (nenhuma animação nesta fase).
func _play_state_animation() -> void:
	if _animation_player == null:
		return
	var anim := StringName(config.animation_map.get(get_state_name(), ""))
	if anim != &"" and _animation_player.has_animation(anim):
		_animation_player.play(anim)
