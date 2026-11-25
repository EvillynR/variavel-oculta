extends SceneTree
## Testes headless do monstro piloto (O Polvo, Room 1) e do sistema de
## interação. Usa a cena real e simula as ações do Input Map.

var passed := 0
var failed := 0
var main: Node
var player: CharacterBody3D
var polvo: MonsterController
var interactor: PlayerInteractor
var puzzles: PuzzleManager
var clues: ClueManager
var counts := {"activated": 0, "experimento": 0, "caught": 0}
var transitions: Array = []
var max_x := -INF
var min_x := INF
var min_z := INF
var max_z := -INF
var in_desk := 0

const DESKS := [  # pegadas das carteiras (x, z, meia-largura x, meia-largura z)
	[-19.38, -18.7, 0.5, 1.25], [-14.21, -18.7, 0.5, 1.25],
	[-14.2, -13.0, 0.5, 1.25], [-14.2, -24.0, 0.5, 1.25],
]


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	preload("res://tests/test_input.gd").open_all_doors(self)  # Prompt 1: portas físicas
	await _physics(10)
	player = main.get_node("Player")
	polvo = main.get_node("Room1Gameplay/Polvo")
	interactor = main.get_node("Systems/PlayerInteractor")
	puzzles = main.get_node("Systems/PuzzleManager")
	clues = main.get_node("Systems/ClueManager")
	main.get_node("Systems/InteractionRouter").debug_log = false

	polvo.activated.connect(func(_r): counts["activated"] += 1)
	polvo.player_caught.connect(func(): counts["caught"] += 1)
	polvo.state_changed.connect(func(_a, b): transitions.append(MonsterController.State.keys()[b]))
	puzzles.interaction_registered.connect(func(i): if i == &"room_1.experimento": counts["experimento"] += 1)
	physics_frame.connect(_track_monster)

	var wait := 0
	while not polvo.is_navigation_ready() and wait < 300:
		await physics_frame
		wait += 1
	_check("navegação sincronizada", polvo.is_navigation_ready(), "%d frames" % wait)
	var home := polvo.global_position
	var placeholder: Node3D = main.get_node("School/Room 1/ProfessorPlaceholder")

	print("--- recursos")
	var map0 := polvo.agent.get_navigation_map()
	_check("posição inicial dentro do navmesh", _flat(NavigationServer3D.map_get_closest_point(map0, home), home) < 0.1, "")
	_check("Polvo começa voltado para a sala (+X)", (-polvo.global_basis.z).dot(Vector3.RIGHT) > 0.99, str(-polvo.global_basis.z))
	_check("ProfessorSpawn usado como origem", home.distance_to(Vector3(-21.2, home.y, -18.7)) < 0.05, str(home))
	_check("placeholder existente segue o corpo (RemoteTransform3D)", placeholder.global_position.distance_to(polvo.global_position + Vector3.UP * 1.75) < 0.05, "")
	var map := polvo.agent.get_navigation_map()
	_check("navmesh ativo na Room 1", _flat(NavigationServer3D.map_get_closest_point(map, Vector3(-12, 0, -18)), Vector3(-12, 0, -18)) < 0.1, "")
	_check("carteiras são obstáculos no navmesh", _flat(NavigationServer3D.map_get_closest_point(map, Vector3(-14.2, 0, -24)), Vector3(-14.2, 0, -24)) > 0.5, "")

	print("--- 1 e 6: entrar na sala e ficar à vista não ativam")
	await _teleport(Vector3(0, 0.05, -10.5))
	var x0 := player.global_position.x
	# A câmera agora gira/muda de composição: anda para -X (porta da Room 1)
	# pelas ações reais, no referencial de controle da protagonista.
	for i in 96:
		preload("res://tests/test_input.gd").press_world(player, Vector3.LEFT)
		await physics_frame
	preload("res://tests/test_input.gd").release_moves()
	await _physics(2)
	_check("protagonista entrou andando com os controles originais", player.global_position.x < -5.0 and player.global_position.x < x0 - 4.0, "x=%.2f" % player.global_position.x)
	await _teleport(Vector3(-15.5, 0.05, -18.7))   # 5,7 m à frente do Polvo, no campo de visão
	await _physics(120)
	_check("protagonista está de fato no campo de visão", polvo.perception.can_see(player), "")
	_check("monstro continua INACTIVE", polvo.state == MonsterController.State.INACTIVE, polvo.get_state_name())
	_check("monstro não se moveu antes do gatilho", polvo.global_position.distance_to(home) < 0.05, "")

	print("--- 2: aproximar sem pressionar E")
	await _teleport(Vector3(-13.2, 0.05, -24))
	await _physics(60)
	_check("experimento selecionado ao alcance", interactor.get_current_target() != null and interactor.get_current_target().name == "Experimento", str(interactor.get_current_target()))
	_check("sem E: nenhuma interação registrada", not puzzles.has_interaction(&"room_1.experimento") and polvo.state == MonsterController.State.INACTIVE, "")

	print("--- 4: objetos errados")
	await _teleport(Vector3(-8, 0.05, -27.5))
	await _press("interact")
	_check("armário registrado", puzzles.has_interaction(&"room_1.armario"), "")
	await _teleport(Vector3(-13.2, 0.05, -13))
	await _press("interact")
	_check("caderno registrado e pista revelada", puzzles.has_interaction(&"room_1.caderno_laboratorio") and clues.is_discovered(&"teste_pista_caderno"), "")
	_check("objetos errados não ativam o Polvo", polvo.state == MonsterController.State.INACTIVE and counts["activated"] == 0, "")
	_check("enigma da sala segue as regras da Etapa 3", puzzles.is_available(&"teste_ciencias_alternativa"), "")

	print("--- 3 e 5: E no objeto certo, depois repetido")
	await _teleport(Vector3(-13.2, 0.05, -24))
	await _physics(5)
	await _press("interact")
	_check("E no experimento ativa o Polvo", counts["activated"] == 1 and polvo.state == MonsterController.State.AWAKENING, polvo.get_state_name())
	for i in 4:
		await _press("interact")
	_check("repetir E não duplica evento nem ativação", counts["activated"] == 1 and counts["experimento"] == 1, "ativações=%d eventos=%d" % [counts["activated"], counts["experimento"]])

	print("--- 7: movimento após ativação (protagonista escondida no corredor)")
	await _teleport(Vector3(0, 0.05, -18))
	await _wait_state(MonsterController.State.INVESTIGATING, 3.0)
	_check("despertar → INVESTIGATING", polvo.state == MonsterController.State.INVESTIGATING, polvo.get_state_name())
	await _physics(240)
	var moved := polvo.global_position.distance_to(home)
	_check("monstro se moveu em direção ao experimento", moved > 3.0, "%.2f m" % moved)
	await _wait_state(MonsterController.State.PATROLLING, 20.0)
	_check("investiga, volta ao posto e vigia (sem perseguir sem ver)", transitions == ["AWAKENING", "INVESTIGATING", "RETURNING", "PATROLLING"], str(transitions))
	_check("voltou para perto da origem", polvo.global_position.distance_to(home) < 1.0, "%.2f m" % polvo.global_position.distance_to(home))

	print("--- 8: detecção e perseguição")
	await _wait_seconds(1.5)  # termina de girar para a direção de vigia
	await _teleport(Vector3(-23.0, 0.05, -21.5))   # atrás do Polvo (que olha para +X)
	await _wait_seconds(1.5)
	_check("não detecta pelas costas", polvo.state == MonsterController.State.PATROLLING, polvo.get_state_name())
	transitions.clear()
	await _teleport(Vector3(-11.0, 0.05, -18.7))   # à frente, 10 m, visão livre
	await _wait_state(MonsterController.State.CHASING, 2.0)
	_check("detecta e persegue", polvo.state == MonsterController.State.CHASING, polvo.get_state_name())
	var d0 := _flat_distance()
	await _wait_seconds(0.5)   # arrancada (aceleração de 8 m/s²)
	var p0 := polvo.global_position
	await _wait_seconds(1.0)
	var advanced := _flat(polvo.global_position, p0)
	_check("persegue em velocidade de perseguição e se aproxima", advanced > 3.0 and _flat_distance() < d0 - 2.0,
		"%.2f m/s (config 3,6), dist %.2f → %.2f m" % [advanced, d0, _flat_distance()])
	await _wait_seconds(4.0)
	_check("alcança e emite player_caught uma vez", counts["caught"] == 1, "caught=%d dist=%.2f" % [counts["caught"], _flat_distance()])
	_check("para ao alcançar (não empurra)", _flat_distance() > 0.8, "%.2f m" % _flat_distance())

	# Prompt 3: a captura abre o Game Over e PAUSA o jogo — antes, a busca
	# abaixo rodava com a árvore pausada e "falhava" sem o Polvo se mexer.
	# Captura e busca são testadas separadamente: confirma a pausa e fecha a tela.
	_check("captura abre o Game Over e pausa o jogo", paused and get_first_node_in_group("game_over_ui").is_open(), "")
	call_group("game_over_ui", "dismiss")
	_check("Game Over fechado: jogo volta a rodar", not paused, "")
	print("--- 9: perda de contato, busca e retorno")
	transitions.clear()
	await _teleport(Vector3(0, 0.05, -24))   # corredor: paredes bloqueiam a visão
	await _wait_state(MonsterController.State.SEARCHING, 3.0)
	_check("perde de vista → SEARCHING", polvo.state == MonsterController.State.SEARCHING, str(transitions))
	await _wait_state(MonsterController.State.PATROLLING, 25.0)
	_check("busca → retorno → vigia, sem oscilar", transitions == ["SEARCHING", "RETURNING", "PATROLLING"], str(transitions))

	print("--- alvo inalcançável (protagonista no corredor, visível pela porta)")
	transitions.clear()
	await _teleport(Vector3(-10.0, 0.05, -10.5))
	await _wait_state(MonsterController.State.CHASING, 2.0)
	await _teleport(Vector3(-1.5, 0.05, -10.5))
	await _wait_seconds(12.0)
	_check("não sai da área navegável nem entra em ciclo", transitions.size() <= 6, str(transitions))

	print("--- navegação durante todo o teste")
	_check("nunca atravessou paredes (x ∈ [-23.5, -3.5], z ∈ [-30, -7.5])", min_x > -23.5 and max_x < -3.5 and min_z > -30.0 and max_z < -7.5,
		"x[%.2f, %.2f] z[%.2f, %.2f]" % [min_x, max_x, min_z, max_z])
	_check("não passou por dentro das carteiras", in_desk == 0, "%d frames" % in_desk)

	print("RESULTADO: %d/%d testes passaram" % [passed, passed + failed])
	quit(1 if failed > 0 else 0)


func _track_monster() -> void:
	if polvo == null:
		return
	var p := polvo.global_position
	max_x = maxf(max_x, p.x); min_x = minf(min_x, p.x)
	max_z = maxf(max_z, p.z); min_z = minf(min_z, p.z)
	for d in DESKS:
		if absf(p.x - d[0]) < d[2] and absf(p.z - d[1]) < d[3]:
			in_desk += 1


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _flat_distance() -> float:
	return Vector2(polvo.global_position.x - player.global_position.x, polvo.global_position.z - player.global_position.z).length()


func _teleport(pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	await _physics(3)


func _press(action: String) -> void:
	Input.action_press(action)
	await process_frame
	await process_frame
	Input.action_release(action)
	await _physics(2)


func _hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await _wait_seconds(seconds)
	Input.action_release(action)
	await _physics(2)


func _wait_state(target: int, timeout: float) -> void:
	var t := 0.0
	while polvo.state != target and t < timeout:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second


func _wait_seconds(seconds: float) -> void:
	await _physics(int(seconds * Engine.physics_ticks_per_second))


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("%s  %s  %s" % ["OK   " if ok else "FALHA", name, detail])
