class_name Door
extends Node3D
## Porta física (Prompt 1 — Estrutura): batente, bandeira (painel acima das
## folhas), uma ou duas folhas com colisão, estados FECHADA / ABERTA / TRANCADA
## e interação pela tecla E (Interactable + InteractionRouter já existentes).
##
## Referencial local: a largura do vão fica no eixo X (centrado em 0), a
## espessura da parede no eixo Z e o chão em y = 0. Na cena, a porta é girada
## para ficar no plano da parede.
##
## Tranca (definida no JSON, objeto com o mesmo id, campo "door"):
##   "lock": "none"            -> nunca tranca
##   "lock": "room_available"  -> trancada enquanto a sala "room_id" estiver
##                                LOCKED no RoomProgressManager (ou seja, até a
##                                sala anterior ser concluída). Com
##                                "allow_if_previous_pending": true, a porta
##                                fica destrancada enquanto a sala anterior
##                                ainda for PENDING (sem conteúdo para concluir).
##   "lock": "manual"          -> trancada até um efeito {"type": "unlock_door"}.
## Navegação: os navmeshes das salas terminam na soleira. Cada porta tem um
## NavigationLink3D que só existe (enabled) com a porta ABERTA; fechada, a
## folha também entra no bake como obstáculo.

signal state_changed(door: Door, state: int)

enum State { CLOSED, OPEN, LOCKED }
enum LockMode { NONE, ROOM_AVAILABLE, MANUAL }

const LEAF_MATERIAL := preload("res://assets/materials/wall_lower_wood.tres")
const FRAME_MATERIAL := preload("res://assets/materials/wall_lower_wood.tres")
const TRANSOM_MATERIAL := preload("res://assets/materials/wall_upper_plaster.tres")

## Mesmo id do objeto em data/game_data.json (ex.: &"room_2.porta").
@export var door_id: StringName
@export var opening_width: float = 3.0
## Altura do vão na parede (as vergas existentes começam em y = 5).
@export var opening_height: float = 5.0
@export var leaf_height: float = 3.2
@export var wall_thickness: float = 0.2
@export var double_leaf: bool = true
@export var open_angle_degrees: float = 95.0
## Lado para onde as folhas giram: +1 = local +Z, -1 = local -Z.
@export var swing_sign: float = -1.0
@export var open_time: float = 0.45
@export var start_open: bool = false
@export_group("Navegação")
## Camadas (bitmask) do link de navegação criado quando a porta abre.
@export_flags_3d_navigation var link_layers: int = 0
@export var link_depth: float = 1.6

## Só para testes automatizados: toda porta criada abre já no _ready, ignorando
## a tranca (os testes antigos percorrem vãos que não tinham portas).
static var testing_force_open: bool = false

var state: int = State.CLOSED
var lock_mode: int = LockMode.NONE
var lock_room_id: StringName = &""
var allow_if_previous_pending: bool = false
var manually_unlocked: bool = false
## Tranca do roteiro (fluxo da sala): vence qualquer outra regra até unlock().
var story_locked: bool = false

var _leaves: Array[Node3D] = []           # dobradiças
var _leaf_shapes: Array[CollisionShape3D] = []
var _solid_rids: Array[RID] = []
var _interactable: Interactable
var _doorway: Area3D
var _swing: Area3D
var _collision_pending := false
var _link: NavigationLink3D
var _tween: Tween
var _rooms: Node = null
var _last_message: String = ""


func _ready() -> void:
	add_to_group("door")
	_read_definition()
	_build()
	if start_open or testing_force_open:
		_set_open(true, true)
	# O RoomProgressManager fica depois da escola na árvore: o _ready dele roda
	# depois do das portas. A tranca só é avaliada quando ele já existe.
	_connect_rooms.call_deferred()


func _connect_rooms() -> void:
	_rooms = get_tree().get_first_node_in_group("room_progress_manager")
	if _rooms != null and _rooms.has_signal("room_state_changed"):
		_rooms.room_state_changed.connect(func(_r, _a, _b): _refresh_lock())
	elif lock_mode == LockMode.ROOM_AVAILABLE:
		push_warning("%s: RoomProgressManager ausente; a tranca por progressão não é aplicada." % get_path())
	_refresh_lock()


# ------------------------------------------------------------ API pública

func is_open() -> bool:
	return state == State.OPEN


func is_locked() -> bool:
	return _compute_locked()


func get_state_name() -> String:
	return State.keys()[state]


## Abre a porta. force = ignora a tranca (testes / sequências de roteiro).
func open(force: bool = false, instant: bool = false) -> bool:
	if state == State.OPEN:
		return true
	if not force and _compute_locked():
		return false
	_set_open(true, instant)
	return true


func close(instant: bool = false) -> bool:
	if state != State.OPEN:
		return true
	if _doorway_blocked():
		return false
	_set_open(false, instant)
	return true


## Efeito "unlock_door" do JSON.
func unlock() -> void:
	manually_unlocked = true
	story_locked = false
	_refresh_lock()


## Fluxo da sala: tranca a porta (ela fecha atrás da Yuko). Fecha antes, se
## estiver aberta e o vão estiver livre; devolve false se não conseguiu fechar.
func lock(instant: bool = false) -> bool:
	story_locked = true
	var closed := close(instant)
	_refresh_lock()
	return closed


## Texto da última tentativa de uso (lido pelo InteractionRouter).
func consume_message() -> String:
	var m := _last_message
	_last_message = ""
	return m


# ------------------------------------------------------------ dados

func _read_definition() -> void:
	if door_id == &"":
		push_error("%s: door_id vazio." % get_path())
		return
	var def: InteractiveObjectData = GameData.get_instance().get_object(door_id)
	if def == null:
		push_error("%s: porta \"%s\" não está em data/game_data.json (objects)." % [get_path(), door_id])
		return
	var cfg: Dictionary = def.door
	match str(cfg.get("lock", "none")):
		"room_available":
			lock_mode = LockMode.ROOM_AVAILABLE
		"manual":
			lock_mode = LockMode.MANUAL
		_:
			lock_mode = LockMode.NONE
	lock_room_id = StringName(str(cfg.get("room_id", "")))
	allow_if_previous_pending = bool(cfg.get("allow_if_previous_pending", false))
	start_open = bool(cfg.get("start_open", start_open))


func _compute_locked() -> bool:
	if story_locked:
		return true
	match lock_mode:
		LockMode.MANUAL:
			return not manually_unlocked
		LockMode.ROOM_AVAILABLE:
			if manually_unlocked:
				return false
			if _rooms == null:
				return false
			if _rooms.get_room_state(lock_room_id) != RoomData.RoomState.LOCKED:
				return false
			if allow_if_previous_pending and _previous_room_pending():
				return false
			return true
	return false


func _previous_room_pending() -> bool:
	var db: NarrativeDatabase = GameData.get_instance().narrative_db
	var rooms := db.get_classrooms()
	for i in rooms.size():
		if rooms[i].id == lock_room_id:
			return i > 0 and rooms[i - 1].is_pending()
	return false


func _refresh_lock() -> void:
	if state == State.OPEN:
		_update_prompt()
		return
	var new_state := State.LOCKED if _compute_locked() else State.CLOSED
	if new_state != state:
		state = new_state
		state_changed.emit(self, state)
	_update_prompt()


# ------------------------------------------------------------ interação

func _on_interacted(_it: Interactable, _actor: Node3D) -> void:
	if _tween != null and _tween.is_running():
		_last_message = ""
		return
	match state:
		State.LOCKED:
			_last_message = "Trancada."
		State.CLOSED:
			_set_open(true, false)
			_last_message = ""
		State.OPEN:
			if _doorway_blocked():
				_last_message = "Algo está no caminho da porta."
			else:
				_set_open(false, false)
				_last_message = ""


func _update_prompt() -> void:
	if _interactable == null:
		return
	var text := "E  Abrir"
	match state:
		State.OPEN:
			text = "E  Fechar"
		State.LOCKED:
			text = "Trancada"
	_interactable.set_prompt_text(text)


# ------------------------------------------------------------ abrir / fechar

func _set_open(value: bool, instant: bool) -> void:
	_collision_pending = false
	if _tween != null:
		_tween.kill()
	state = State.OPEN if value else (State.LOCKED if _compute_locked() else State.CLOSED)
	# Colisão das folhas: desligada durante o movimento e com a porta aberta
	# (folha encostada na parede não pode prender ninguém). Volta ao fechar.
	_set_leaf_collision(false)
	var angle := deg_to_rad(open_angle_degrees) if value else 0.0
	if instant or open_time <= 0.0:
		for i in _leaves.size():
			_leaves[i].rotation.y = _leaf_target(i, angle)
		_after_motion(value)
	else:
		_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		for i in _leaves.size():
			_tween.tween_property(_leaves[i], "rotation:y", _leaf_target(i, angle), open_time)
		_tween.chain().tween_callback(_after_motion.bind(value))
	if _link != null:
		_link.enabled = value
	state_changed.emit(self, state)
	_update_prompt()


func _after_motion(opened: bool) -> void:
	if opened:
		_set_leaf_collision(false)
	elif _bodies_in(_swing):
		_collision_pending = true   # religa quando a área do giro esvaziar
	else:
		_set_leaf_collision(true)


func _physics_process(_delta: float) -> void:
	if _collision_pending and state != State.OPEN and not _bodies_in(_swing):
		_collision_pending = false
		_set_leaf_collision(true)


func _bodies_in(area: Area3D) -> bool:
	if area == null:
		return false
	for body in area.get_overlapping_bodies():
		if body.is_in_group("player") or body.is_in_group("monster"):
			return true
	return false


func _leaf_target(index: int, angle: float) -> float:
	# Dobradiça esquerda (índice 0) gira com -sinal; direita com +sinal.
	var side := -1.0 if index == 0 else 1.0
	return side * swing_sign * angle


func _set_leaf_collision(enabled: bool) -> void:
	for s in _leaf_shapes:
		s.set_deferred("disabled", not enabled)


func _doorway_blocked() -> bool:
	return _bodies_in(_doorway)


# ------------------------------------------------------------ construção

func _box(size: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	return mi


func _solid(parent: Node3D, name_: String, size: Vector3, pos: Vector3, material: Material) -> CollisionShape3D:
	var body := StaticBody3D.new()
	body.name = name_
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("camera_fade")   # fica translúcida se tapar a protagonista
	body.position = pos
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(_box(size, material))
	_solid_rids.append(body.get_rid())
	return shape


func _build() -> void:
	var w := opening_width
	var t := wall_thickness
	# Bandeira: fecha o vão entre o alto das folhas e a verga.
	var transom_h := opening_height - leaf_height
	if transom_h > 0.01:
		_solid(self, "Transom", Vector3(w, transom_h, t), Vector3(0, leaf_height + transom_h * 0.5, 0), TRANSOM_MATERIAL)
	# Batente: só visual. Com colisão, a moldura (mais espessa que a parede)
	# criava um degrau no canto do vão em que a protagonista enroscava.
	var jamb := 0.08
	for spec in [["JambLeft", Vector3(jamb, leaf_height, t + 0.06), Vector3(-w * 0.5 + jamb * 0.5, leaf_height * 0.5, 0)],
			["JambRight", Vector3(jamb, leaf_height, t + 0.06), Vector3(w * 0.5 - jamb * 0.5, leaf_height * 0.5, 0)],
			["Head", Vector3(w, 0.1, t + 0.06), Vector3(0, leaf_height - 0.05, 0)]]:
		var mi := _box(spec[1], FRAME_MATERIAL)
		mi.name = spec[0]
		mi.position = spec[2]
		add_child(mi)

	var clear := w - jamb * 2.0
	var count := 2 if double_leaf else 1
	var leaf_w := clear / count - 0.02
	var leaf_t := 0.07
	for i in count:
		var hinge := Node3D.new()
		hinge.name = "Hinge%d" % i
		var left := i == 0
		hinge.position = Vector3((-clear * 0.5) if left else (clear * 0.5), 0, 0)
		add_child(hinge)
		var dir := 1.0 if left else -1.0
		var shape := _solid(hinge, "Leaf", Vector3(leaf_w, leaf_height - 0.12, leaf_t), Vector3(dir * leaf_w * 0.5, (leaf_height - 0.12) * 0.5 + 0.02, 0), LEAF_MATERIAL)
		# Puxador (só visual).
		var handle := _box(Vector3(0.05, 0.25, leaf_t + 0.12), TRANSOM_MATERIAL)
		handle.position = Vector3(dir * (leaf_w - 0.18), 1.15, 0)
		hinge.add_child(handle)
		_leaves.append(hinge)
		_leaf_shapes.append(shape)

	# Área do vão: impede fechar a porta em cima de alguém.
	_doorway = Area3D.new()
	_doorway.name = "Doorway"
	_doorway.collision_layer = 0
	_doorway.collision_mask = 1 | 4
	_doorway.monitorable = false
	var dshape := CollisionShape3D.new()
	var dbox := BoxShape3D.new()
	# Pós-Prompt 3: só a SOLEIRA bloqueia o fechamento. Antes a área cobria todo
	# o giro das folhas (≈1,6 m de cada lado) e quem estava perto o bastante
	# para apertar E nunca conseguia fechar a porta.
	dbox.size = Vector3(w, 2.0, t + 0.6)
	dshape.shape = dbox
	dshape.position = Vector3(0, 1.0, 0)
	_doorway.add_child(dshape)
	add_child(_doorway)

	# Área do giro das folhas (lado para onde abrem): ao fechar com alguém ali, a
	# colisão das folhas só volta quando a área esvaziar (ninguém fica preso).
	_swing = Area3D.new()
	_swing.name = "Swing"
	_swing.collision_layer = 0
	_swing.collision_mask = 1 | 4
	_swing.monitorable = false
	var sshape := CollisionShape3D.new()
	var sbox := BoxShape3D.new()
	sbox.size = Vector3(w, 2.0, leaf_w + 0.3)
	sshape.shape = sbox
	sshape.position = Vector3(0, 1.0, swing_sign * (leaf_w + 0.3) * 0.5)
	_swing.add_child(sshape)
	add_child(_swing)

	# Interação (E) — o Interactable lê ação e texto do JSON pelo door_id.
	_interactable = Interactable.new()
	_interactable.name = "Interactable"
	_interactable.interaction_id = door_id
	_interactable.prompt_height = 2.0
	_interactable.line_of_sight_exclude = _solid_rids
	var ishape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(1.8, w * 0.6)
	ishape.shape = sphere
	ishape.position = Vector3(0, 0.9, 0)
	_interactable.add_child(ishape)
	add_child(_interactable)
	_interactable.interacted.connect(_on_interacted)

	# Link de navegação (só com a porta aberta).
	if link_layers != 0:
		_link = NavigationLink3D.new()
		_link.name = "NavLink"
		_link.bidirectional = true
		_link.navigation_layers = link_layers
		_link.start_position = Vector3(0, 0, -link_depth)
		_link.end_position = Vector3(0, 0, link_depth)
		_link.enabled = false
		add_child(_link)
