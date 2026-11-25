extends SceneTree
## Etapa 5, Fase 3 — audição dos monstros, com a cena real e o Polvo real.
## Uso: godot --headless --path . --script res://tests/monster_hearing_test.gd
## Nenhuma fonte de som é adicionada à cena: as fontes usadas aqui são
## criadas em memória e removidas no fim de cada verificação.

const S := MonsterController.State
const R := SoundStimulus.Reaction
const HOME := Vector3(-21.2, 0, -18.7)
const FAR := Vector3(0, 0.05, -40)          # protagonista longe e fora de vista
const P_IN := Vector3(-17.0, 0, -21.5)      # ~5 m do posto: investiga
const P_WEAK := Vector3(-14.5, 0, -21.5)    # ~7,3 m: ouvido, mas irrelevante
const P_OUT := Vector3(-11.2, 0, -18.7)     # 10 m: fora do alcance
const P_WALL := Vector3(-1.5, 0, -18.7)     # corredor, atrás da parede leste
const ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "run", "crouch", "interact", "pause"]
const DESKS := [[-19.38, -18.7, 0.5, 1.25], [-14.21, -18.7, 0.5, 1.25],
	[-14.2, -13.0, 0.5, 1.25], [-14.2, -24.0, 0.5, 1.25]]

var passed := 0
var failed := 0
var main: Node
var player: CharacterBody3D
var polvo: MonsterController
var puzzles: PuzzleManager
var narrative: NarrativeManager
var camera_controller: Node
var log := {"perceived": [], "states": [], "causes": [], "narr": [], "activated": 0}


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	preload("res://tests/test_input.gd").open_all_doors(self)  # Prompt 1: portas físicas
	await _physics(10)
	player = main.get_node("Player")
	polvo = main.get_node("Room1Gameplay/Polvo")
	puzzles = main.get_node("Systems/PuzzleManager")
	narrative = main.get_node("Systems/NarrativeManager")
	narrative.log_to_console = false
	main.get_node("Systems/RoomProgressManager").log_to_console = false
	main.get_node("Systems/InteractionRouter").debug_log = false
	camera_controller = main.get_tree().get_first_node_in_group("camera_controller")

	polvo.sound_perceived.connect(func(s, r): log["perceived"].append([s.id, r]))
	polvo.state_changed.connect(func(_a, b):
		log["states"].append(S.keys()[b])
		log["causes"].append(polvo.last_state_cause))
	polvo.activated.connect(func(_r): log["activated"] += 1)
	narrative.event_triggered.connect(func(e): log["narr"].append(e.id))
	_add_test_events()

	var wait := 0
	while not polvo.is_navigation_ready() and wait < 300:
		await physics_frame
		wait += 1

	await _structure()
	await _inactive_and_awakening()
	await _range_and_threshold()
	await _sensitivity()
	await _investigation()
	await _duplicates()
	await _source_component()
	await _walls()
	await _chase_compat()
	await _narrative()
	await _preservation()

	print("RESULTADO: %d/%d testes passaram" % [passed, passed + failed])
	quit(1 if failed > 0 else 0)


# ------------------------------------------------------------ seções

func _structure() -> void:
	print("--- estrutura")
	var cfg := polvo.config
	_check("Polvo tem perfil de audição próprio", cfg.hearing_profile != null and cfg.hearing_profile.resource_name == "polvo_audicao", cfg.hearing_profile.resource_name if cfg.hearing_profile else "")
	_check("Polvo é ouvinte do grupo de som", polvo.is_in_group(SoundStimulus.LISTENER_GROUP), "")
	_check("parâmetros antigos do Polvo iguais", is_equal_approx(cfg.patrol_speed, 1.3) and is_equal_approx(cfg.investigate_speed, 1.6)
		and is_equal_approx(cfg.chase_speed, 3.6) and is_equal_approx(cfg.sight_fov_degrees, 120.0), "")
	var legacy := MonsterConfig.new()
	_check("config sem perfil usa campos antigos (surdo por padrão)", legacy.get_hearing().sensitivity == 0.0 and legacy.get_hearing().hearing_radius == 8.0, "")
	var names := ["perfil_padrao", "perfil_baixa_audicao", "perfil_alta_sensibilidade", "perfil_somente_roteiro"]
	var radii := {}
	for n in names:
		var p: HearingProfile = GameData.get_instance().get_hearing_profile(StringName(n))
		radii[n] = p.hearing_radius * p.sensitivity if p != null else -1.0
	_check("4 perfis genéricos carregam e diferem", not radii.values().has(-1.0) and radii.values().size() == 4
		and radii["perfil_alta_sensibilidade"] > radii["perfil_padrao"] and radii["perfil_padrao"] > radii["perfil_baixa_audicao"]
		and radii["perfil_somente_roteiro"] == 0.0, str(radii))
	var using_generic := []
	for m in narrative.database.monsters:
		if m.hearing_profile != null and m.hearing_profile.resource_path.get_file().begins_with("perfil_"):
			using_generic.append(m.monster_id)
	_check("perfis genéricos não são de nenhum monstro do banco", using_generic.is_empty(), str(using_generic))


func _inactive_and_awakening() -> void:
	print("--- INACTIVE/AWAKENING: som não desperta")
	await _teleport(FAR)
	var r := polvo.hear_stimulus(P_IN, 3.0, SoundStimulus.KIND_OBJECT_DROP, &"teste")
	var r2 := polvo.hear_stimulus(P_IN)   # nem a ordem de roteiro desperta
	await _physics(30)
	_check("INACTIVE ignora som válido e alto", r == R.IGNORED_STATE and r2 == R.IGNORED_STATE and polvo.state == S.INACTIVE and log["activated"] == 0,
		"%s/%s %s" % [SoundStimulus.reaction_name(r), SoundStimulus.reaction_name(r2), polvo.get_state_name()])
	puzzles.register_interaction(&"room_1.experimento")   # gatilho atual
	await _physics(2)
	_check("gatilho atual continua despertando", polvo.state == S.AWAKENING and log["activated"] == 1, polvo.get_state_name())
	r = polvo.hear_stimulus(P_IN, 3.0)
	_check("AWAKENING ignora som", r == R.IGNORED_STATE and polvo.state == S.AWAKENING, SoundStimulus.reaction_name(r))
	_check("sequência original: AWAKENING -> INVESTIGATING", await _wait_state(S.INVESTIGATING, 200), polvo.get_state_name())
	_check("e depois volta ao posto (PATROLLING)", await _wait_patrolling_home(1500), "%s %s" % [polvo.get_state_name(), polvo.global_position.snapped(Vector3.ONE * 0.01)])


func _range_and_threshold() -> void:
	print("--- alcance e limiar")
	var start := polvo.global_position
	var n_states: int = log["states"].size()
	var r_out := polvo.hear_stimulus(P_OUT, 1.0)
	var r_weak := polvo.hear_stimulus(P_WEAK, 1.0)
	await _physics(30)
	_check("fora do alcance (10 m, intensidade 1): sem reação", r_out == R.OUT_OF_RANGE, SoundStimulus.reaction_name(r_out))
	_check("dentro do alcance mas fraco (7,3 m): irrelevante", r_weak == R.BELOW_THRESHOLD, SoundStimulus.reaction_name(r_weak))
	_check("nenhuma mudança de estado nem movimento", log["states"].size() == n_states and polvo.state == S.PATROLLING and _flat(polvo.global_position, start) < 0.05, "")
	var loud := polvo.perception.evaluate_sound(SoundStimulus.new(P_OUT, 2.0))
	_check("mesmo ponto com intensidade 2: justifica investigação", loud["reaction"] == R.INVESTIGATE, "nível %.2f, alcance %.1f m" % [loud["level"], loud["range"]])


func _sensitivity() -> void:
	print("--- sensibilidade por perfil (mesmo som a 7,3 m)")
	var original := polvo.config.hearing_profile
	var expected := {"perfil_alta_sensibilidade": R.INVESTIGATE, "perfil_padrao": R.BELOW_THRESHOLD,
		"perfil_baixa_audicao": R.OUT_OF_RANGE, "perfil_somente_roteiro": R.DEAF}
	for n in expected:
		polvo.config.hearing_profile = GameData.get_instance().get_hearing_profile(StringName(n))
		var res := polvo.perception.evaluate_sound(SoundStimulus.new(P_WEAK, 1.0))
		_check("%s -> %s" % [n, SoundStimulus.reaction_name(expected[n])], res["reaction"] == expected[n], SoundStimulus.reaction_name(res["reaction"]))
	polvo.config.hearing_profile = GameData.get_instance().get_hearing_profile(&"perfil_somente_roteiro")
	_check("perfil surdo ainda aceita ordem de roteiro", polvo.perception.evaluate_sound(SoundStimulus.scripted_at(P_WEAK))["reaction"] == R.INVESTIGATE, "")
	var ignoring: HearingProfile = GameData.get_instance().get_hearing_profile(&"perfil_padrao").duplicate()
	ignoring.ignored_kinds = [SoundStimulus.KIND_RUN]
	ignoring.kind_weights = {SoundStimulus.KIND_DOOR: 2.0}
	polvo.config.hearing_profile = ignoring
	_check("tipo ignorado pelo perfil", polvo.perception.evaluate_sound(SoundStimulus.new(P_IN, 1.0, SoundStimulus.KIND_RUN))["reaction"] == R.IGNORED_KIND, "")
	_check("peso por tipo amplia o alcance", polvo.perception.evaluate_sound(SoundStimulus.new(P_OUT, 1.0, SoundStimulus.KIND_DOOR))["reaction"] == R.INVESTIGATE, "")
	polvo.config.hearing_profile = original


func _investigation() -> void:
	print("--- investigação da posição do som")
	var stim := SoundStimulus.new(P_IN, 1.0, SoundStimulus.KIND_OBJECT_DROP, &"teste.queda")
	var r := polvo.receive_sound_stimulus(stim)
	await _physics(1)
	_check("som válido leva a INVESTIGATING", r == R.INVESTIGATE and polvo.state == S.INVESTIGATING, polvo.get_state_name())
	_check("causa registrada: som", polvo.last_state_cause == &"som", String(polvo.last_state_cause))
	_check("posição do som registrada", _flat(polvo.get_last_heard_position(), P_IN) < 0.3, str(polvo.get_last_heard_position()))
	var target := polvo._move_target
	await _teleport(Vector3(-2.0, 0.05, -40.0))   # protagonista se move (fora de vista)
	await _physics(20)
	_check("destino é o som, não a protagonista", polvo._move_target.distance_to(target) < 0.01, "")
	var in_desk := 0
	var reached := false
	for i in 900:
		await physics_frame
		if _in_desk(polvo.global_position):
			in_desk += 1
		if _flat(polvo.global_position, P_IN) < 1.0:
			reached = true
			break
	_check("chega ao local do som", reached, str(polvo.global_position.snapped(Vector3.ONE * 0.01)))
	_check("não atravessa carteiras no caminho", in_desk == 0, "%d quadros" % in_desk)
	_check("olha em volta e volta ao posto", await _wait_patrolling_home(1500), polvo.get_state_name())


func _duplicates() -> void:
	print("--- estímulos duplicados")
	var stim := SoundStimulus.new(P_IN, 1.0)
	var n0: int = log["states"].size()
	var r1 := polvo.receive_sound_stimulus(stim)
	var r2 := polvo.receive_sound_stimulus(stim)
	_check("mesmo estímulo entregue 2x: uma reação", r1 == R.INVESTIGATE and r2 == R.DUPLICATE, "%s/%s" % [SoundStimulus.reaction_name(r1), SoundStimulus.reaction_name(r2)])
	var r3 := polvo.hear_stimulus(P_IN + Vector3(0.6, 0, 0.4), 1.0)
	var r4 := polvo.hear_stimulus(P_IN + Vector3(-0.5, 0, 0), 1.0)
	_check("sons repetidos no mesmo local: fundidos", r3 == R.MERGED and r4 == R.MERGED, "%s/%s" % [SoundStimulus.reaction_name(r3), SoundStimulus.reaction_name(r4)])
	_check("uma única entrada em INVESTIGATING", log["states"].slice(n0).count("INVESTIGATING") == 1, str(log["states"].slice(n0)))
	var other := P_IN + Vector3(0, 0, 4.0)   # outro ponto: atualiza o destino sem reemitir estado
	var r5 := polvo.hear_stimulus(other, 1.0)
	await _physics(1)
	_check("som em outro ponto atualiza o destino", r5 == R.INVESTIGATE and _flat(polvo._move_target, other) < 0.5, SoundStimulus.reaction_name(r5))
	_check("atualização não reemite state_changed", log["states"].size() == n0 + 1, str(log["states"].slice(n0)))
	await _wait_patrolling_home(1500)

	# Ponto recém-investigado absorve repetição dentro de merge_time.
	var original := polvo.config.hearing_profile
	var long_merge: HearingProfile = original.duplicate()
	long_merge.merge_time = 60.0
	polvo.config.hearing_profile = long_merge
	var r6 := polvo.hear_stimulus(other, 1.0)
	_check("repetição no ponto recém-investigado: fundida", r6 == R.MERGED, SoundStimulus.reaction_name(r6))
	long_merge.merge_time = 0.0
	var near_home := HOME + Vector3(3.0, 0, -2.5)
	polvo._last_heard_position = near_home   # simula: este ponto já foi investigado
	var r7 := polvo.hear_stimulus(near_home, 1.0)
	_check("passada a janela, o mesmo ponto é um som novo", r7 == R.INVESTIGATE, SoundStimulus.reaction_name(r7))
	polvo.config.hearing_profile = original
	await _wait_patrolling_home(1500)


func _source_component() -> void:
	print("--- fonte de som reutilizável (sem áudio)")
	var holder := Node3D.new()
	main.add_child(holder)
	var source := SoundStimulusSource.new()
	source.source_id = &"teste.fonte"
	source.kind = SoundStimulus.KIND_MECHANISM
	source.min_interval = 0.5
	holder.add_child(source)
	source.global_position = P_IN
	var emitted: Array = []
	source.stimulus_emitted.connect(func(s): emitted.append(s))
	var n0: int = log["perceived"].size()
	var s1 := source.emit_stimulus()
	var s2 := source.emit_stimulus()   # mesmo quadro: bloqueado pelo intervalo
	await _physics(1)
	_check("fonte emite e o Polvo recebe pelo grupo", s1 != null and log["perceived"].size() == n0 + 1 and polvo.state == S.INVESTIGATING, polvo.get_state_name())
	_check("intervalo mínimo bloqueia emissão em rajada", s2 == null and emitted.size() == 1, "")
	source.enabled = false
	source.reset_interval()
	_check("fonte desativada não emite", source.emit_stimulus() == null, "")
	_check("nenhum AudioStreamPlayer na cena nem no banco de sons", _count_audio(root) == 0 and polvo.config.sound_bank.is_empty(), "%d players" % _count_audio(root))

	# Fonte móvel emitindo todo quadro: o monstro só conhece pontos discretos.
	source.enabled = true
	source.reset_interval()
	var targets := {}
	for i in 120:
		source.global_position = P_IN + Vector3(0, 0, -2.0 + 4.0 * i / 120.0)
		source.emit_stimulus()
		await physics_frame
		targets[polvo._move_target.snapped(Vector3.ONE * 0.1)] = true
	_check("fonte contínua não vira rastreador (≤ 1 emissão / 0,5 s)", source.emitted_count <= 1 + 5, "%d emissões em 2 s" % source.emitted_count)
	_check("destinos distintos ≤ emissões", targets.size() <= source.emitted_count + 1, "%d destinos" % targets.size())
	holder.queue_free()
	await _wait_patrolling_home(1500)


func _walls() -> void:
	print("--- paredes")
	var inside := polvo.perception.evaluate_sound(SoundStimulus.new(Vector3(-6.0, 0, -18.7), 1.0))
	var outside := polvo.perception.evaluate_sound(SoundStimulus.new(P_WALL, 1.0))
	_check("som dentro da sala: sem obstrução", not inside["occluded"], "")
	_check("som no corredor: parede detectada", outside["occluded"], "")
	var r := polvo.hear_stimulus(P_WALL, 4.0)
	_check("som forte atrás da parede ainda fora do alcance (abafado)", r == R.OUT_OF_RANGE, SoundStimulus.reaction_name(r))
	r = polvo.hear_stimulus(P_WALL, 10.0)
	_check("som muito forte atrás da parede: investiga", r == R.INVESTIGATE, SoundStimulus.reaction_name(r))
	_check("destino ajustado ao navmesh (dentro da sala)", polvo._move_target.x <= -3.5, "x=%.2f" % polvo._move_target.x)
	var max_x := -INF
	for i in 900:
		await physics_frame
		max_x = maxf(max_x, polvo.global_position.x)
		if polvo.state != S.INVESTIGATING:
			break
	_check("não atravessa a parede para chegar ao som", max_x <= -3.5, "x máx %.2f" % max_x)
	await _wait_patrolling_home(1500)


func _chase_compat() -> void:
	print("--- compatibilidade com perseguição, busca e retorno")
	await _teleport(Vector3(-15.5, 0.05, -18.7))   # à vista
	_check("protagonista à vista: CHASING", await _wait_state(S.CHASING, 180), polvo.get_state_name())
	var r := polvo.hear_stimulus(Vector3(-20.0, 0, -26.0), 3.0)
	await _physics(5)
	_check("som durante perseguição é ignorado", r == R.IGNORED_STATE and polvo.state == S.CHASING, SoundStimulus.reaction_name(r))
	_check("perseguição continua seguindo a visão (não o som)", _flat(polvo._last_known_position, player.global_position) < 0.5, str(polvo._last_known_position.snapped(Vector3.ONE * 0.01)))
	await _teleport(FAR)   # foge para fora da sala
	_check("protagonista escapa: SEARCHING", await _wait_state(S.SEARCHING, 300), polvo.get_state_name())
	r = polvo.hear_stimulus(Vector3(-18.0, 0, -12.0), 1.5)
	await _physics(1)
	_check("som durante a busca: INVESTIGATING (transição existente)", r == R.INVESTIGATE and polvo.state == S.INVESTIGATING, SoundStimulus.reaction_name(r))
	_check("termina em RETURNING -> PATROLLING, sem voltar a perseguir", await _wait_patrolling_home(1800) and not polvo.state == S.CHASING, polvo.get_state_name())


func _narrative() -> void:
	print("--- integração narrativa")
	var into_inv: int = log["states"].count("INVESTIGATING")
	var fired: int = log["narr"].count(&"teste_audicao_investigar")
	_check("NarrativeManager recebe cada entrada real em INVESTIGATING", fired == into_inv, "%d eventos / %d entradas" % [fired, into_inv])
	_check("estímulos recebidos >> eventos (sem disparo contínuo)", log["perceived"].size() > fired, "%d estímulos" % log["perceived"].size())
	_check("evento once dispara uma única vez", log["narr"].count(&"teste_audicao_once") == 1, "")
	var sound_causes := 0
	for i in log["states"].size():
		if log["states"][i] == "INVESTIGATING" and log["causes"][i] == &"som":
			sound_causes += 1
	_check("transições pela audição marcadas com causa 'som'", sound_causes >= 5 and sound_causes < into_inv, "%d de %d" % [sound_causes, into_inv])


func _preservation() -> void:
	print("--- preservação")
	_check("protagonista: collision_mask = 5", player.collision_mask == 5, str(player.collision_mask))
	_check("protagonista: camada 1", player.collision_layer == 1, str(player.collision_layer))
	var missing: Array = []
	for a in ACTIONS:
		if not InputMap.has_action(a):
			missing.append(a)
	_check("ações de controle intactas", missing.is_empty(), str(missing))
	_check("câmera ativa e no grupo", camera_controller != null and camera_controller.get_node("Camera3D").current, "")
	_check("Polvo: camada 3, máscara 1", polvo.collision_layer == 4 and polvo.collision_mask == 1, "%d/%d" % [polvo.collision_layer, polvo.collision_mask])


# ------------------------------------------------------------ apoio

func _add_test_events() -> void:
	for spec in [[&"teste_audicao_investigar", false], [&"teste_audicao_once", true]]:
		var e := NarrativeEvent.new()
		e.id = spec[0]
		e.room_id = &"room_1"
		e.title = "[TESTE] audição"
		e.trigger = NarrativeEvent.TriggerType.MONSTER_STATE
		e.trigger_id = &"octopus"
		e.trigger_state = &"INVESTIGATING"
		e.once = spec[1]
		narrative.database.events.append(e)   # só em memória


func _wait_state(s: int, frames: int) -> bool:
	for i in frames:
		if polvo.state == s:
			return true
		await physics_frame
	return polvo.state == s


func _wait_patrolling_home(frames: int) -> bool:
	for i in frames:
		if polvo.state == S.PATROLLING and _flat(polvo.global_position, polvo._home_position) < 0.9 and not polvo._has_move_target:
			await _physics(30)   # termina de virar para a sala
			return true
		await physics_frame
	return false


func _teleport(p: Vector3) -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "run", "crouch"]:
		Input.action_release(a)
	player.velocity = Vector3.ZERO
	player.global_position = p
	await _physics(3)


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _in_desk(p: Vector3) -> bool:
	for d in DESKS:
		if absf(p.x - d[0]) < d[2] and absf(p.z - d[1]) < d[3]:
			return true
	return false


func _count_audio(node: Node) -> int:
	var n := 1 if (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D) else 0
	for c in node.get_children():
		n += _count_audio(c)
	return n


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("%s %s  %s" % ["OK    " if ok else "FALHA ", name, detail])
