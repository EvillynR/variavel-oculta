extends SceneTree
## Versão 6.2 — modelos novos da Ana (Yuko, Maestro e Leitora) e a captura nova.
##  - Yuko: "Levantando" (abertura) e a morte quando é pega;
##  - Leitora no lugar da cápsula do Leitor (Escrevendo / Andando / Correndo / Matando);
##  - Maestro: ouve → vira a cabeça → persegue devagar → faz a Yuko levitar;
##    dá para escapar; se não escapar, aparece a tela de game over (checkpoint).
## Uso: godot --headless --fixed-fps 60 --path . --script res://tests/modelos_v62_test.gd

var passed := 0
var failed := 0


func _initialize() -> void:
	SaveSystem.save_path = "user://teste_modelos_v62.json"
	SaveSystem.delete_save()
	SaveSystem.pending_action = ""
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 6:
		await physics_frame
	var director = get_first_node_in_group("story_director")
	if director != null:
		director.enabled = false
	print("   pausado no início: ", paused)
	paused = false
	for i in 30:
		await physics_frame
	var player: CharacterBody3D = main.get_node("Player")
	var yuko: YukoAnimator = null
	for c in player.find_children("*", "Node3D", true, false):
		if c is YukoAnimator:
			yuko = c
	_check("Yuko: animação de levantar importada", yuko != null and yuko.anim.has_animation("yuko/levantar"))
	_check("Yuko: animação de morrer pronta", yuko.anim.has_animation("yuko/morrer"))
	_check("Yuko: parada (nome novo \"Parada\")", yuko.anim.has_animation("yuko/parada"))

	# ---------------- Leitora
	var leitor: MonsterController = main.get_node("MonsterRoster/Leitor")
	var lv: MonsterAnimator = leitor.get_node_or_null("Visual")
	_check("Leitora: modelo animado no lugar da cápsula", lv != null and lv.anim != null and leitor.get_node_or_null("TemporaryVisual") == null)
	_check("Leitora: dormindo = Escrevendo", lv.anim.current_animation == "prof/idle" and lv.anim.get_animation("prof/idle") != null)
	var sk: Skeleton3D = lv.find_children("*", "Skeleton3D", true, false)[0]
	var top := -INF
	for b in sk.get_bone_count():
		top = maxf(top, (sk.global_transform * sk.get_bone_global_pose(b).origin).y - leitor.global_position.y)
	_check("Leitora: altura ~3,4 m (osso mais alto a %.2f m)" % top, top > 2.8 and top < 3.7)
	_check("Leitora: nome no jogo", String(leitor.resolve_config().display_name) == "A Leitora")
	leitor.activate(&"teste", leitor.global_position + Vector3(4, 0, 0), true)
	leitor.hunt(leitor.global_position + Vector3(8, 0, 0))
	for i in 40:
		await physics_frame
	_check("Leitora: perseguindo = Correndo (%s)" % lv.current, lv.current == &"chase")
	leitor.deactivate(true)

	# ---------------- Maestro: ouvir, perseguir devagar, levitar
	var m: MonsterController = main.get_node("MonsterRoster/Maestro")
	var mv: MonsterAnimator = m.get_node("Visual")
	_check("Maestro: persegue mais devagar (%.1f m/s)" % m.resolve_config().chase_speed, m.resolve_config().chase_speed <= 2.6)
	var home := m.global_position
	player.global_position = home + Vector3(7.0, 0.05, 0)
	await physics_frame
	m.activate(&"teste", player.global_position, true)
	m.hunt(player.global_position)
	for i in 8:
		await physics_frame
	_check("Maestro: ouviu e vira a cabeça antes de andar (%s)" % mv.current, mv.current == &"listen")
	var w := 0
	while not m.is_gripping() and w < 60 * 8:
		m.hunt(player.global_position)
		await physics_frame
		w += 1
	_check("Maestro: chegou perto e começou a levitar a Yuko", m.is_gripping())
	_check("Maestro: não encosta (%.1f m)" % _flat(m.global_position, player.global_position), _flat(m.global_position, player.global_position) > 1.6)
	for i in 40:
		await physics_frame
	_check("Yuko sobe (levitação %.2f, modelo a %.2f m)" % [player.levitation, player.visual.position.y], player.levitation > 0.2 and player.visual.position.y > 0.1)
	# Ela escapa: sai do alcance antes de completar
	var away := (player.global_position - m.global_position)
	away.y = 0
	player.global_position = m.global_position + away.normalized() * (m.levitate_release + 0.6) + Vector3(0, 0.05, 0)
	for i in 6:
		await physics_frame
	_check("escapou: ela cai e o Maestro solta", not m.is_gripping() and player.levitation == 0.0)
	_check("escapou: sem tela de captura", not get_first_node_in_group("game_over_ui").is_open())
	var stunned_pos := m.global_position
	for i in 30:
		m.hunt(player.global_position)
		await physics_frame
	_check("escapou: ele fica atordoado um instante (%.2f m)" % m.global_position.distance_to(stunned_pos), m.global_position.distance_to(stunned_pos) < 0.3)
	# Agora ela fica parada: ele a pega
	w = 0
	var gripped := false
	while not get_first_node_in_group("game_over_ui").dying and not get_first_node_in_group("game_over_ui").is_open() and w < 60 * 15:
		if not paused:
			m.hunt(player.global_position)
		gripped = gripped or m.is_gripping()
		await process_frame
		w += 1
	var go = get_first_node_in_group("game_over_ui")
	_check("não escapou: levitou e perdeu", gripped and (go.dying or go.is_open()))
	# versão 6.2.1: com o Maestro não tem a animação de morrer; a tela aparece
	# direto, com ela ainda no ar
	_check("Maestro: tela de game over direto (sem animação de morrer)", go.is_open() and not go.dying and yuko.current != &"morrer")
	_check("Yuko continua levitando atrás da tela (%.2f)" % player.levitation, player.levitation > 0.9)
	_check("Maestro: braço erguido segurando (%s)" % mv.current, mv.current == &"catch")
	go.dismiss()
	await physics_frame
	_check("tentar de novo: Yuko volta ao normal", yuko.current != &"morrer" and player.levitation == 0.0 and absf(player.visual.position.y) < 0.01)
	SaveSystem.delete_save()
	print("RESULTADO: %d ok, %d falhas" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _until(cond: Callable, max_frames: int) -> void:
	var n := 0
	while not cond.call() and n < max_frames:
		await process_frame
		n += 1


func _check(label: String, ok: bool) -> void:
	if ok:
		passed += 1
		print("  ok: ", label)
	else:
		failed += 1
		print("  FALHA: ", label)
