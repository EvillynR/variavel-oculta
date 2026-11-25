extends Node3D
## Versão 5.4 — aranha do Laboratório de Ciências (só ambientação, não ataca):
## anda devagar entre dois pontos, para um pouco, vira e volta.

@export var ponto_a := Vector3.ZERO
@export var ponto_b := Vector3(0, 0, 6)
@export var velocidade := 0.9
@export var pausa := 2.5

var _anim: AnimationPlayer
var _alvo := 1
var _parada := 0.0


func _ready() -> void:
	var list := find_children("*", "AnimationPlayer", true, false)
	if not list.is_empty():
		_anim = list[0]
		for a in _anim.get_animation_list():
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		if _anim.has_animation("walk cycle"):
			_anim.play("walk cycle")
	global_position = ponto_a


func _physics_process(delta: float) -> void:
	var alvo := ponto_b if _alvo == 1 else ponto_a
	if _parada > 0.0:
		_parada -= delta
		if _anim:
			_anim.speed_scale = 0.0
		return
	var d := alvo - global_position
	d.y = 0.0
	if d.length() < 0.1:
		_alvo = 1 - _alvo
		_parada = pausa
		return
	if _anim:
		_anim.speed_scale = 1.0
	var dir := d.normalized()
	# vira de frente para onde anda (o modelo olha para +Z)
	var want := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, want, minf(delta * 4.0, 1.0))
	global_position += dir * minf(velocidade * delta, d.length())
