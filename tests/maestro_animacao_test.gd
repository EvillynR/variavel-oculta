extends SceneTree
## Versão 5.3 — o Maestro (assets/characters/maestro/MaestroRig.glb) no lugar
## da cápsula: altura, direção e animação de cada estado.
## Uso: godot --headless --fixed-fps 60 --path . --script res://tests/maestro_animacao_test.gd

var passed := 0
var failed := 0


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await physics_frame
	var m: MonsterController = main.get_node("MonsterRoster/Maestro")
	var v: MonsterAnimator = m.get_node_or_null("Visual")
	_check("Maestro usa o modelo animado (sem cápsula provisória)", v != null and v.anim != null and m.get_node_or_null("TemporaryVisual") == null)
	var sk: Skeleton3D = v.find_children("*", "Skeleton3D", true, false)[0]
	var top := -INF
	for b in sk.get_bone_count():
		top = maxf(top, (sk.global_transform * sk.get_bone_global_pose(b).origin).y - m.global_position.y)
	_check("altura de ~4,2 m (osso mais alto a %.2f m)" % top, top > 3.6 and top < 4.4)
	var face := -m.global_basis.z
	_check("no posto, olha para a frente da sala/câmera (+X)", face.x > 0.9)
	var model_front: Vector3 = v._model_root.global_basis.z.normalized()   # o GLB olha para +Z local
	_check("o modelo olha para onde o monstro anda", model_front.dot(face) > 0.95)
	_check("dormindo no posto: Tocando", v.current == &"idle" and v.anim.current_animation == "prof/idle")
	_check("luz própria para aparecer no escuro", v.get_node_or_null("LuzPropria") != null)
	m.activate(&"teste", m.global_position + Vector3(4, 0, 0))
	for i in 10:
		await physics_frame
	_check("acordando: Erro", v.current == &"awaken")
	var w := 0
	while m.state == MonsterController.State.AWAKENING and w < 600:
		await physics_frame
		w += 1
	m.hunt(m.global_position + Vector3(12, 0, 0))
	for i in 10:
		await physics_frame
	_check("ouviu: para e vira a cabeça (Atento) antes de perseguir (%s, %.2f m/s)" % [v.current, m.velocity.length()],
		v.current == &"listen" and m.velocity.length() < 0.5)
	for i in 100:
		await physics_frame
	_check("perseguindo devagar: Andando no ritmo da velocidade (%.2f m/s, ritmo %.2f)" % [m.velocity.length(), v.anim.speed_scale],
		v.current == &"chase" and m.velocity.length() > 2.0 and m.velocity.length() < 2.7 and v.anim.speed_scale > 0.8)
	m.player_caught.emit()
	await physics_frame
	_check("pegou a Yuko: Atacando", v.current == &"catch")
	paused = false   # a tela "VOCÊ FOI ENCONTRADA" pausa o jogo; aqui seguimos
	m.deactivate(true)
	var n := 0
	while (m.is_active() or v.current != &"idle") and n < 60 * 20:
		await physics_frame
		n += 1
	_check("de volta ao posto dormindo: Tocando (%s, %s)" % [m.get_state_name(), v.current], v.current == &"idle")
	print("RESULTADO: %d ok, %d falhas" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(label: String, ok: bool) -> void:
	if ok:
		passed += 1
		print("  ok: ", label)
	else:
		failed += 1
		print("  FALHA: ", label)
