class_name MonsterAnimator
extends Node3D
## Modelo animado de um professor (ex.: assets/characters/maestro/MaestroRig.glb)
## no lugar da cápsula provisória. Fica como filho do MonsterController e
## escolhe a animação pelo estado dele:
##   dormindo no posto → idle_clip   ·  acordando → awaken_clip (uma vez)
##   andando/procurando → move_clip (mais devagar)  ·  perseguindo → move_clip
##   procurando parado → search_clip  ·  parado depois de desistir → rest_clip
##   pegou a Yuko → catch_clip (uma vez)
## As animações do GLB são "no lugar" (sem deslocamento do osso raiz); a
## velocidade do passo acompanha a velocidade real do monstro.

@export var model: PackedScene
## Altura final do modelo (m). O colisor do professor tem 4,2 m.
@export var target_height: float = 4.2
## O GLB do Blender olha para +Z; o monstro anda para -Z.
@export var face_back: bool = true
@export_group("Animações (nomes no GLB)")
@export var idle_clip: StringName = &"Tocando"
@export var awaken_clip: StringName = &"Erro"
@export var move_clip: StringName = &"Correndo"
@export var search_clip: StringName = &"Atento_longe"
@export var rest_clip: StringName = &"Tocando_longe"
@export var catch_clip: StringName = &"Atacando"
## Versão 6.2: perseguindo usa esta (vazio = move_clip).
@export var chase_clip: StringName = &""
## Versão 6.2: uma vez, quando ouve e começa a perseguir (vira a cabeça).
@export var listen_clip: StringName = &""
## Versão 6.2: velocidade natural da chase_clip (0 = natural_speed).
@export var chase_natural_speed: float = 0.0
@export_group("Ritmo")
## Velocidade (m/s) em que move_clip tem o passo "natural" (speed_scale 1).
@export var natural_speed: float = 3.0
@export var min_speed_scale: float = 0.55
@export var max_speed_scale: float = 1.6
@export var blend_time: float = 0.25
@export_group("Luz própria")
## Luz fraca que acompanha o professor: sem ela, o modelo escuro some na sala
## escura (a câmera fica alta e longe). 0 desliga.
@export var glow_energy: float = 0.9
@export var glow_color: Color = Color(1.0, 0.56, 0.5)
@export var glow_range: float = 5.0

const LIBRARY := &"prof"
const LOOPED := ["idle", "move", "search", "rest", "chase"]
## Sem a animação no GLB, usa outra no lugar (vazio = não toca nada).
const FALLBACK := {&"search": &"idle", &"rest": &"idle", &"chase": &"move", &"awaken": &"", &"listen": &"", &"catch": &""}

var anim: AnimationPlayer
var monster: MonsterController
var current: StringName = &""
var _one_shot_left := 0.0
var _model_root: Node3D


func _ready() -> void:
	monster = get_parent() as MonsterController
	if model == null:
		push_warning("%s: sem modelo." % get_path())
		return
	_model_root = model.instantiate()
	_model_root.name = "Modelo"
	add_child(_model_root)
	if face_back:
		_model_root.rotation.y = PI
	_fit_height()
	var players := _model_root.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_warning("%s: o modelo não tem AnimationPlayer." % get_path())
		return
	anim = players[0]
	# anima também durante as cenas de filme (o jogo fica pausado nelas)
	anim.process_mode = Node.PROCESS_MODE_ALWAYS
	_build_library()
	for mi in _model_root.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if glow_energy > 0.0:
		var glow := OmniLight3D.new()
		glow.name = "LuzPropria"
		glow.light_color = glow_color
		glow.light_energy = glow_energy
		glow.omni_range = glow_range
		glow.omni_attenuation = 1.4
		glow.shadow_enabled = false
		# na frente do rosto (o monstro olha para -Z)
		glow.position = Vector3(0, target_height * 0.8, -1.4)
		add_child(glow)
	if monster != null:
		monster.player_caught.connect(_on_caught)
		monster.state_changed.connect(_on_state_changed)
		monster.listening_started.connect(func(): _one_shot(&"listen"))
		monster.grip_started.connect(_on_grip)
		monster.grip_released.connect(_on_release)
	_play(&"idle", 0.0)


func _fit_height() -> void:
	# mede a altura real pela pose de repouso dos ossos (o AABB da malha com
	# pele não acompanha a escala da armação)
	var sk_list := _model_root.find_children("*", "Skeleton3D", true, false)
	if sk_list.is_empty():
		return
	var sk: Skeleton3D = sk_list[0]
	var top := 0.0
	for b in sk.get_bone_count():
		var p: Vector3 = (_model_root.global_transform.affine_inverse() * sk.global_transform) * sk.get_bone_global_rest(b).origin
		top = maxf(top, p.y)
	if top > 0.1:
		# o topo da cabeça fica um pouco acima do último osso
		var k := target_height / (top * 1.04)
		_model_root.scale = Vector3.ONE * k


func _build_library() -> void:
	var lib := AnimationLibrary.new()
	var map := {&"idle": idle_clip, &"awaken": awaken_clip, &"move": move_clip,
		&"search": search_clip, &"rest": rest_clip, &"catch": catch_clip,
		&"chase": chase_clip, &"listen": listen_clip}
	for key in map:
		var src_name := String(map[key])
		if src_name == "":
			continue
		if not anim.has_animation(src_name):
			push_warning("MonsterAnimator: animação %s não está no GLB." % src_name)
			continue
		var src := anim.get_animation(src_name)
		var a: Animation
		if String(key) in LOOPED:
			a = YukoAnimator._make_loop(src, 0.0, src.length)
		else:
			a = src.duplicate()
			a.loop_mode = Animation.LOOP_NONE
		lib.add_animation(key, a)
	anim.add_animation_library(LIBRARY, lib)


func _resolve(key: StringName) -> StringName:
	var k := key
	for i in 3:
		if anim.has_animation(String(LIBRARY) + "/" + String(k)):
			return k
		k = FALLBACK.get(k, &"")
		if k == &"":
			return &""
	return &""


func _play(key: StringName, blend: float = -1.0) -> void:
	if anim == null:
		return
	key = _resolve(key)
	if key == &"" or key == current:
		return
	var full := String(LIBRARY) + "/" + String(key)
	current = key
	anim.play(full, blend_time if blend < 0.0 else blend)


func _on_state_changed(_previous: int, now: int) -> void:
	if now == MonsterController.State.AWAKENING:
		_one_shot(&"awaken")


func _on_caught() -> void:
	if _hold_left:
		return   # já está com o braço erguido (levitação)
	_one_shot(&"catch")


## Versão 6.2 (Maestro): ergue o braço e segura a pose enquanto ela levita.
var _hold_left := false


func _on_grip() -> void:
	_one_shot(&"catch")
	_hold_left = true


func _on_release() -> void:
	_hold_left = false
	current = &""
	if anim != null:
		anim.speed_scale = 1.0


## Versão 5.7: pose de cena (funciona com o jogo pausado; a animação roda
## sempre). Ex.: "search" = para e escuta, "catch" = avança ameaçador.
func pose(key: StringName) -> void:
	_one_shot(key)


func _one_shot(key: StringName) -> void:
	if anim == null:
		return
	var k := _resolve(key)
	if k == &"":
		return
	current = &""
	_play(k, 0.12)
	anim.speed_scale = 1.0
	_one_shot_left = anim.get_animation(String(LIBRARY) + "/" + String(k)).length


func _process(delta: float) -> void:
	if anim == null or monster == null:
		return
	var v := monster.velocity
	var speed := Vector2(v.x, v.z).length()
	var moving := speed > 0.3
	if _hold_left:
		# segurando a Yuko no ar: congela no fim do gesto
		if _one_shot_left > 0.0:
			_one_shot_left -= delta
		else:
			anim.speed_scale = 0.0
		return
	if _one_shot_left > 0.0:
		_one_shot_left -= delta * maxf(anim.speed_scale, 0.01)
		# o susto (Erro) termina assim que ele começa a andar: sem deslizar
		if not (current == &"awaken" and moving):
			return
		_one_shot_left = 0.0
	match monster.state:
		MonsterController.State.INACTIVE:
			_play(&"idle")
			anim.speed_scale = 1.0
		MonsterController.State.AWAKENING:
			_play(&"search")
			anim.speed_scale = 1.0
		_:
			if moving:
				var chasing := monster.state == MonsterController.State.CHASING
				_play(&"chase" if chasing else &"move")
				var nat := chase_natural_speed if chasing and chase_natural_speed > 0.0 else natural_speed
				anim.speed_scale = clampf(speed / nat, min_speed_scale, max_speed_scale)
			elif monster.state in [MonsterController.State.SEARCHING, MonsterController.State.INVESTIGATING, MonsterController.State.CHASING]:
				_play(&"search")
				anim.speed_scale = 1.0
			else:
				_play(&"rest")
				anim.speed_scale = 1.0
