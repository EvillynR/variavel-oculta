class_name YukoAnimator
extends Node3D
## Modelo da Yuko (assets/characters/yuko/YukoRig.glb) + escolha da animação.
##
## O GLB traz animações "no lugar" (sem deslocamento do osso raiz), mas com
## o primeiro quadro fora do ciclo e o fim sem encaixar no começo. Aqui elas
## viram loops perfeitos, recortados num ciclo exato (medido no arquivo):
##   parada   ← "Parada"       0,000 s + 2,5 s  (respiração)
##   andar    ← "Andandoofc"   0,133 s + 1,2 s
##   correr   ← "Correndoofc"  0,233 s + 0,8 s
##   agachar  ← "Agachada"     0,033 s + 2,4 s  (andar agachada; parada = pose congelada)
## "Andando.lan.ofc" é idêntica a "Andandoofc" e "Andando.001" (1 s) não fecha
## ciclo: não são usadas.
##
## A velocidade de cada animação acompanha a velocidade real da protagonista
## (pé não "patina"): velocidade natural medida no apoio do pé.

const CLIPS := {
	&"parada": {"src": ["Parada", "_Parada_"], "start": 0.0, "length": 2.5, "speed": 0.0},
	&"andar": {"src": "Andandoofc", "start": 0.133, "length": 1.2, "speed": 1.42},
	&"correr": {"src": "Correndoofc", "start": 0.233, "length": 0.8, "speed": 2.8},
	&"agachar": {"src": "Agachada", "start": 0.033, "length": 2.4, "speed": 1.25},
}
const LIBRARY := &"yuko"
## Versão 6.2: animações de uma vez só, feitas pela Ana no Blender.
##   levantar ← "Levantando" (deitada → de joelhos; a abertura termina em pé)
##   morrer   ← "Morrend" quando tiver movimento; se vier vazia (exportada sem
##              chaves), usa "Levantando" de trás para frente: ela cai e fica
##              deitada.
const WAKE_SRC := ["Levantando"]
const DEATH_SRC := ["Morrend", "Morrendo"]
## Duração da queda quando a morte usa "Levantando" ao contrário (s).
const DEATH_FALLBACK_TIME := 1.6

## Transição entre animações (s).
@export var blend_time: float = 0.18
## Limites do ajuste de velocidade da animação (evita pernas frenéticas).
@export var min_speed_scale: float = 0.6
@export var max_speed_scale: float = 2.6
## Abaixo disso (m/s) ela está parada.
@export var idle_threshold: float = 0.25

var player: CharacterBody3D
var anim: AnimationPlayer
var current: StringName = &""
## Pose controlada pelo roteiro (deitada / levantando): o _process não mexe.
var scripted := false

## Levantar (abertura). Chaves: [fração do tempo, quanto ela está deitada de
## lado (graus de rolagem), pose, quanto o corpo "encolhe" (0 = esticada,
## 1 = encolhida)]. Ela começa deitada DE LADO, encolhida e com o rosto para a
## câmera; apoia no braço, fica de joelhos/cócoras recuperando o fôlego e só
## então fica de pé. (De bruços o rosto ficava enterrado no chão.)
const WAKE_KEYS := [
	[0.00, 80.0, &"agachar", 1.0],
	[0.18, 80.0, &"agachar", 1.0],
	[0.46, 32.0, &"agachar", 1.0],
	[0.62, 0.0, &"agachar", 1.0],
	[0.82, 0.0, &"agachar", 1.0],
	[1.00, 0.0, &"parada", 0.0],
]
## Meio comprimento do corpo deitado (o pivô do modelo fica nos pés).
const BODY_HALF := 0.85
const CROUCH_HALF := 0.45


func _ready() -> void:
	# Continua respirando nas cenas de filme e na pausa (o resto do jogo para).
	process_mode = Node.PROCESS_MODE_ALWAYS
	anim = find_children("*", "AnimationPlayer", true, false)[0] if not find_children("*", "AnimationPlayer", true, false).is_empty() else null
	if anim == null:
		push_error("YukoAnimator: o modelo não tem AnimationPlayer.")
		return
	anim.process_mode = Node.PROCESS_MODE_ALWAYS
	_build_library()
	var n: Node = get_parent()
	while n != null and not (n is CharacterBody3D):
		n = n.get_parent()
	player = n as CharacterBody3D
	play_state(&"parada", 0.0)


func _build_library() -> void:
	if anim.has_animation_library(LIBRARY):
		return
	var lib := AnimationLibrary.new()
	for clip_name in CLIPS:
		var c: Dictionary = CLIPS[clip_name]
		var src := _find_src(c.src)
		if src == null:
			push_warning("YukoAnimator: animação %s não encontrada no GLB." % str(c.src))
			continue
		lib.add_animation(clip_name, _make_loop(src, float(c.start), float(c.length)))
	var wake := _find_src(WAKE_SRC)
	if wake != null:
		var w := wake.duplicate() as Animation
		w.loop_mode = Animation.LOOP_NONE
		lib.add_animation(&"levantar", w)
	var death := _find_src(DEATH_SRC)
	if death != null and _has_motion(death):
		var d := death.duplicate() as Animation
		d.loop_mode = Animation.LOOP_NONE
		lib.add_animation(&"morrer", d)
	elif wake != null:
		lib.add_animation(&"morrer", _make_reversed(wake, DEATH_FALLBACK_TIME))
	anim.add_animation_library(LIBRARY, lib)


func _find_src(names) -> Animation:
	var list: Array = names if names is Array else [names]
	for n in list:
		if anim.has_animation(String(n)):
			return anim.get_animation(String(n))
	return null


## A animação mexe algum osso? (o Godot apaga as trilhas paradas na importação)
static func _has_motion(a: Animation) -> bool:
	for t in a.get_track_count():
		if a.track_get_key_count(t) > 1:
			return true
	return false


## A animação de trás para frente, comprimida em `length` segundos.
static func _make_reversed(src: Animation, length: float, fps: float = 30.0) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_NONE
	var frames := maxi(int(round(length * fps)), 1)
	for t in src.get_track_count():
		var type := src.track_get_type(t)
		if type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var nt := a.add_track(type)
		a.track_set_path(nt, src.track_get_path(t))
		a.track_set_interpolation_type(nt, Animation.INTERPOLATION_LINEAR)
		for i in frames + 1:
			var u := float(i) / frames
			# começa devagar (ainda de pé) e cai mais rápido no fim
			var st := src.length * (1.0 - u * u * (3.0 - 2.0 * u))
			var time := length * u
			match type:
				Animation.TYPE_POSITION_3D:
					a.position_track_insert_key(nt, time, src.position_track_interpolate(t, st))
				Animation.TYPE_ROTATION_3D:
					a.rotation_track_insert_key(nt, time, src.rotation_track_interpolate(t, st))
				Animation.TYPE_SCALE_3D:
					a.scale_track_insert_key(nt, time, src.scale_track_interpolate(t, st))
	return a


## Recorta [start, start + length] e fecha o loop com o último quadro igual ao
## primeiro (sem "pulo" na volta).
static func _make_loop(src: Animation, start: float, length: float, fps: float = 30.0) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR
	var frames := maxi(int(round(length * fps)), 1)
	for t in src.get_track_count():
		var type := src.track_get_type(t)
		if type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var nt := a.add_track(type)
		a.track_set_path(nt, src.track_get_path(t))
		a.track_set_interpolation_type(nt, Animation.INTERPOLATION_LINEAR)
		for i in frames + 1:
			var time := length * i / frames
			var st := start + (0.0 if i == frames else time)
			match type:
				Animation.TYPE_POSITION_3D:
					a.position_track_insert_key(nt, time, src.position_track_interpolate(t, st))
				Animation.TYPE_ROTATION_3D:
					a.rotation_track_insert_key(nt, time, src.rotation_track_interpolate(t, st))
				Animation.TYPE_SCALE_3D:
					a.scale_track_insert_key(nt, time, src.scale_track_interpolate(t, st))
	return a


func play_state(state: StringName, blend: float = -1.0) -> void:
	if anim == null or state == current:
		return
	current = state
	anim.play(String(LIBRARY) + "/" + String(state), blend_time if blend < 0.0 else blend)


## Deitada de lado, encolhida, virada para a câmera (abertura).
func pose_lying(face_point: Vector3 = Vector3.INF) -> void:
	scripted = true
	var visual := get_parent() as Node3D
	if face_point == Vector3.INF and is_inside_tree() and get_viewport().get_camera_3d() != null:
		face_point = get_viewport().get_camera_3d().global_position
	if visual != null and face_point != Vector3.INF:
		var d := face_point - visual.global_position
		visual.global_rotation.y = atan2(d.x, d.z)
	if _has_clip(&"levantar"):
		# versão 6.2: a pose deitada é o primeiro quadro de "Levantando"
		rotation = Vector3.ZERO
		position = Vector3.ZERO
		current = &"levantar"
		anim.play(String(LIBRARY) + "/levantar", 0.0)
		anim.seek(0.0, true)
		anim.speed_scale = 0.0
		return
	_hold(&"agachar", 0.0)
	_apply_roll(float(WAKE_KEYS[0][1]), 1.0)


## Levanta em `seconds` (a cena de abertura espera).
func wake_up(seconds: float = 3.4) -> void:
	scripted = true
	if _has_clip(&"levantar"):
		await _wake_up_clip(seconds)
		return
	var t := 0.0
	var pose: StringName = current
	while t < seconds and is_inside_tree():
		await get_tree().process_frame
		var d := get_process_delta_time()
		t += d if d > 0.0 else 1.0 / 60.0
		var f := clampf(t / seconds, 0.0, 1.0)
		var k := 0
		while k < WAKE_KEYS.size() - 2 and f > float(WAKE_KEYS[k + 1][0]):
			k += 1
		var a: Array = WAKE_KEYS[k]
		var b: Array = WAKE_KEYS[k + 1]
		var u := clampf((f - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001), 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		var want: StringName = b[2] if u > 0.0 else a[2]
		if want != pose:
			pose = want
			if pose == &"parada":
				anim.speed_scale = 1.0
				current = &""
				play_state(&"parada", 0.5)
			else:
				_hold(pose, 0.35)
		elif pose == &"agachar" and anim.speed_scale == 0.0 and f > 0.18:
			anim.speed_scale = 0.12   # começa a se mexer
		# respiração ofegante: leve balanço enquanto está de joelhos
		var sway := sin(t * 7.0) * 2.0 * (1.0 if f > 0.62 and f < 0.82 else 0.0)
		_apply_roll(lerpf(float(a[1]), float(b[1]), u), lerpf(float(a[3]), float(b[3]), u), sway)
	rotation = Vector3.ZERO
	position = Vector3.ZERO
	scripted = false


func _has_clip(key: StringName) -> bool:
	return anim != null and anim.has_animation(String(LIBRARY) + "/" + String(key))


## Versão 6.2: levanta com a animação "Levantando" (deitada → de joelhos) e
## termina em pé, respirando. `seconds` = tempo total da cena.
func _wake_up_clip(seconds: float) -> void:
	rotation = Vector3.ZERO
	position = Vector3.ZERO
	var clip_len := anim.get_animation(String(LIBRARY) + "/levantar").length
	var stand := 0.6
	current = &"levantar"
	anim.play(String(LIBRARY) + "/levantar", 0.0)
	anim.seek(0.0, true)
	anim.speed_scale = clip_len / maxf(seconds - stand, 0.5)
	var t := 0.0
	while t < seconds - stand and is_inside_tree():
		await get_tree().process_frame
		var d := get_process_delta_time()
		t += d if d > 0.0 else 1.0 / 60.0
	anim.speed_scale = 1.0
	current = &""
	play_state(&"parada", stand)
	t = 0.0
	while t < stand and is_inside_tree():
		await get_tree().process_frame
		var d2 := get_process_delta_time()
		t += d2 if d2 > 0.0 else 1.0 / 60.0
	scripted = false


## Versão 6.2: pega por um professor. Toca "morrer" uma vez e fica no último
## quadro (o jogo está pausado; o modelo anima mesmo assim).
func die() -> float:
	scripted = true
	if not _has_clip(&"morrer"):
		return 0.0
	current = &"morrer"
	anim.speed_scale = 1.0
	anim.play(String(LIBRARY) + "/morrer", 0.15)
	return anim.get_animation(String(LIBRARY) + "/morrer").length


## Volta ao normal (checkpoint depois da captura).
func revive() -> void:
	scripted = false
	rotation = Vector3.ZERO
	position = Vector3.ZERO
	current = &""
	if anim != null:
		anim.speed_scale = 1.0
	play_state(&"parada", 0.0)


func _apply_roll(deg: float, crouch: float, lean_deg: float = 0.0) -> void:
	# Rola para o lado em volta dos pés e desloca o pivô para o corpo ficar
	# centrado na posição da protagonista; sobe um pouco (largura do quadril).
	var r := deg_to_rad(deg)
	var half := lerpf(BODY_HALF, CROUCH_HALF, crouch)
	rotation = Vector3(deg_to_rad(lean_deg), 0, r)
	position = Vector3(half * sin(r), 0.16 * sin(r), 0)


func _hold(state: StringName, blend: float) -> void:
	if anim == null:
		return
	current = state
	anim.play(String(LIBRARY) + "/" + String(state), blend)
	anim.seek(0.0 if state == &"parada" else 0.4, true)
	# Com velocidade zero a mistura entre poses não anda; bem devagar ela
	# acontece e as pernas mal se mexem (esforço para levantar).
	anim.speed_scale = 0.0 if blend <= 0.0 else 0.12


func _process(_delta: float) -> void:
	if anim == null or player == null or scripted:
		return
	# Jogo pausado (cena de filme, enigma, documento, pausa): respira parada.
	if get_tree().paused or not is_visible_in_tree():
		play_state(&"parada")
		anim.speed_scale = 1.0
		return
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var crouching: bool = player.get("is_crouching") == true
	var running: bool = player.get("is_running") == true
	var state: StringName
	if crouching:
		state = &"agachar"
	elif speed < idle_threshold:
		state = &"parada"
	elif running:
		state = &"correr"
	else:
		state = &"andar"
	play_state(state)
	var natural := float(CLIPS[state].speed)
	if natural <= 0.0:
		anim.speed_scale = 1.0
	elif crouching and speed < idle_threshold:
		anim.speed_scale = 0.0   # agachada e parada: segura a pose
	else:
		anim.speed_scale = clampf(speed / natural, min_speed_scale, max_speed_scale)
