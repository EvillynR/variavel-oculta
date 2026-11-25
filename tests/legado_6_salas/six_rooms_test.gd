extends SceneTree
## Etapa 5, Fase 4 — seis salas, seis monstros, navegação e encaixe visual.
## Uso: godot --headless --path . --script res://tests/six_rooms_test.gd
## Tudo que é criado aqui (monstros de teste, modelos) fica só em memória.

const S := MonsterController.State
const RS := RoomData.RoomState
## Planejamento: sala, matéria, monster_id, nome do monstro.
const PLAN := [
	[&"room_1", "Ciências", &"octopus", "O Polvo"],
	[&"room_2", "Matemática", &"angle", "O Ângulo"],
	[&"room_3", "Artes", &"painter", "A Pintora"],
	[&"room_4", "Português/Literatura", &"reader", "O Leitor"],
	[&"room_5", "Geografia", &"cartographer", "O Cartógrafo"],
	[&"room_6", "Música", &"maestro", "O Maestro"],
]
## Pisos medidos no mapa (x mín, x máx, z mín, z máx).
const FLOORS := {
	&"room_1": [-23.5, -3.5, -29.9, -7.5], &"room_2": [-23.5, -3.5, -58.5, -37.5],
	&"room_3": [-23.5, -3.5, -83.5, -58.5], &"room_4": [-23.5, -3.5, -116.1, -92.5],
	&"room_5": [-23.5, -3.5, -137.9, -117.0],
	# Prompt 1: Música ganhou cenário; locais narrativos físicos.
	&"room_6": [-23.5, -3.5, -185.0, -165.0],
	&"sala_inicial": [-6.0, 5.0, -4.0, 4.0], &"sala_monitoramento": [-17.5, -3.5, -226.0, -212.0],
}
## Filhos de School antes desta fase: nenhuma geometria nova.
## Prompt 1: + MusicRoom (já existia antes do Prompt 1), Corredor 5, subsolo,
## Sala de Monitoramento e o nó das portas — geometria nova pedida no Prompt 1.
## Prompt 2: + Props (móveis provisórios de scenes/props/).
## Pós-Prompt 3: + Exterior (chão de fora e preenchimento sob a rampa, só
## visuais, para a câmera fixa não mostrar o vazio).
const SCHOOL_CHILDREN := ["InitialRoom", "Corridor", "Corridor2", "Room 1", "Room 2", "Exit", "Room 3", "Room 4", "Corridor3", "Corridor4", "MusicRoom", "Corridor5", "Subsolo", "SalaMonitoramento", "Doors", "Props", "Exterior"]

var passed := 0
var failed := 0
var db: NarrativeDatabase
var pdb: PuzzleDatabase
var main: Node
var player: CharacterBody3D
var polvo: MonsterController
var rooms: RoomProgressManager


func _initialize() -> void:
	db = GameData.get_instance().narrative_db
	pdb = GameData.get_instance().puzzle_db
	_data()
	_validation_rules()

	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	preload("res://tests/test_input.gd").open_all_doors(self)  # Prompt 1: portas físicas
	await _physics(10)
	player = main.get_node("Player")
	polvo = main.get_node("Room1Gameplay/Polvo")
	rooms = main.get_node("Systems/RoomProgressManager")
	rooms.log_to_console = false
	main.get_node("Systems/NarrativeManager").log_to_console = false
	main.get_node("Systems/InteractionRouter").debug_log = false
	var wait := 0
	while not polvo.is_navigation_ready() and wait < 300:
		await physics_frame
		wait += 1
	player.global_position = Vector3(0, 0.05, 0)   # sala inicial, longe de tudo
	await _physics(5)

	_scene_geometry()
	_doors()
	_navigation()
	await _polvo_reference()
	await _other_room_monster()
	await _visual_slot()
	await _progression()

	print("RESULTADO: %d/%d testes passaram" % [passed, passed + failed])
	quit(1 if failed > 0 else 0)


# ------------------------------------------------------------ dados

func _data() -> void:
	print("--- dados das seis salas e dos seis monstros")
	var errors := db.validate(pdb)
	_check("banco válido", errors.is_empty(), str(errors))
	var warnings := db.get_warnings(pdb)
	var only_pending := true
	for w in warnings:
		if not w.contains("sala pendente"):
			only_pending = false
	_check("avisos são só as 5 salas pendentes", warnings.size() == 5 and only_pending, "\n    ".join(warnings))

	var ids := {}
	var orders := {}
	# Prompt 1: o banco tem também 2 locais narrativos (STORY_AREA); a regra das
	# seis salas vale para as salas de aula.
	for r in db.get_classrooms():
		ids[r.id] = true
		orders[r.order] = true
	_check("6 salas, ids únicos", db.get_classrooms().size() == 6 and ids.size() == 6, str(ids.keys()))
	_check("ordens 1..6 únicas", orders.size() == 6 and orders.has(1) and orders.has(6), "")
	var mids := {}
	for m in db.monsters:
		mids[m.monster_id] = true
	_check("6 monstros, ids únicos, nenhum sétimo", db.monsters.size() == 6 and mids.size() == 6, str(mids.keys()))
	var plan_ok := true
	var detail := ""
	for p in PLAN:
		var room := db.get_room(p[0])
		var m := db.get_monster(p[2])
		if room == null or m == null or room.subject != p[1] or room.monster_id != p[2] or m.room_id != p[0] or m.display_name != p[3]:
			plan_ok = false
			detail += "%s " % p[0]
		elif db.get_room_for_monster(p[2]) != room:
			plan_ok = false
			detail += "%s(dono) " % p[0]
	_check("matéria, monstro e nome conforme o planejamento", plan_ok, detail)

	var r1 := db.get_room(&"room_1")
	var r1_puzzles: Array[StringName] = [&"teste_ciencias_alternativa", &"teste_ciencias_codigo"]
	var r1_trigger: Array[StringName] = [&"room_1.experimento"]
	_check("Room 1 continua com o Polvo e os enigmas existentes", r1.monster_id == &"octopus" and not r1.is_pending()
		and r1.content_status == RoomData.ContentStatus.TEST and r1.puzzle_ids == r1_puzzles
		and r1.exit_id == &"room_1_exit" and r1.activation_interaction_ids == r1_trigger, "")
	_check("Room 1: navegação = navmesh original, camada 1", r1.navigation_layer == 1 and r1.navigation_mesh.resource_path.ends_with("room_1_navmesh.tres"), "")

	var pending_ok := true
	var events_ok := true
	for i in range(1, 6):
		var room: RoomData = db.get_room(PLAN[i][0])
		if not room.is_pending() or room.pending_items.is_empty() or room.planned_interaction_ids.size() != 3 or room.theme == "":
			pending_ok = false
		for evid in [room.exit_event_id] + Array(room.narrative_event_ids):
			var ev := db.get_event(evid)
			if ev == null or ev.enabled or ev.disabled_reason == "" or ev.room_id != room.id:
				events_ok = false
	_check("salas 2–6 pendentes, com o que falta e pontos de integração", pending_ok, "")
	_check("eventos previstos existem, da própria sala, desativados com motivo", events_ok, "")

	var configs_ok := true
	detail = ""
	for m in db.monsters:
		var room := db.get_room(m.room_id)
		for st in m.state_events:
			var ev := db.get_event(m.state_events[st])
			if ev == null or ev.trigger != NarrativeEvent.TriggerType.MONSTER_STATE or ev.trigger_id != m.monster_id or String(ev.trigger_state) != st:
				configs_ok = false
				detail += "%s/%s " % [m.monster_id, st]
		if m.hearing_profile == null or m.placeholder_notes == "" or m.state_events.is_empty():
			configs_ok = false
			detail += "%s(campos) " % m.monster_id
		if m.navigation_layers != room.navigation_layer_bit():
			configs_ok = false
			detail += "%s(nav) " % m.monster_id
	_check("cada config: sala, audição, eventos por estado, notas e camada da sala", configs_ok, detail)
	var hearing := {}
	for m in db.monsters:
		hearing[m.hearing_profile.resource_name] = true  # Prompt 2: id do perfil no JSON
	_check("audição individual (um perfil por monstro)", hearing.size() == 6, "%d perfis" % hearing.size())
	# Prompt 1: a Música tem cenário e navmesh na camada 6 (bit 32).
	_check("Maestro usa a camada da Música (6 → bit 32)", db.get_monster(&"maestro").navigation_layers == 32, "")


func _validation_rules() -> void:
	print("--- regras de validação da Fase 4 (cópias em memória)")
	_rule("sala pendente sem lista do que falta", "sem pending_items", func(d): d.get_room(&"room_2").pending_items = PackedStringArray())
	# Prompt 1: a Música deixou de ser ponto de integração; as regras continuam
	# testadas transformando-a (só na cópia) de volta em ponto de integração.
	_rule("ponto de integração com navegação", "não pode ter navegação", func(d): _as_integration_point(d.get_room(&"room_6")); d.get_room(&"room_6").navigation_layer = 9)
	_rule("ponto de integração com conexão física", "conexões físicas", func(d): _as_integration_point(d.get_room(&"room_6")); d.get_room(&"room_6").connected_area_paths = [NodePath("School/Corridor4")] as Array[NodePath])
	_rule("camada de navegação repetida", "já usada", func(d): d.get_room(&"room_3").navigation_layer = 2)
	_rule("monstro fora da camada da sala", "não usa a camada", func(d): d.get_monster(&"angle").navigation_layers = 1)
	_rule("evento de estado de outro monstro", "não é disparado por", func(d): d.get_monster(&"angle").state_events = {"AWAKENING": &"pintora_despertar"})
	_rule("estado permitido inválido", "estado permitido inválido", func(d): d.get_monster(&"reader").allowed_states = PackedStringArray(["VOANDO"]))
	_rule("ponto previsto que já é interação real", "já é uma interação real", func(d): d.get_room(&"room_2").planned_interaction_ids = [&"room_2.x"] as Array[StringName]; d.get_room(&"room_2").interaction_ids = [&"room_2.x"] as Array[StringName])
	_rule("entrada dependendo de sala posterior", "vem depois", func(d): d.get_room(&"room_2").entry_required_rooms = [&"room_5"] as Array[StringName])
	_rule("sala não pendente sem enigma", "sala sem enigma", func(d): d.get_room(&"room_4").content_status = RoomData.ContentStatus.PROVISIONAL)


# ------------------------------------------------------------ cena

func _scene_geometry() -> void:
	print("--- cena: só geometria existente")
	var names := []
	for c in main.get_node("School").get_children():
		names.append(String(c.name))
	_check("School tem exatamente as mesmas áreas de antes", names == SCHOOL_CHILDREN, str(names))
	var anchors_ok := true
	for r in db.rooms:
		if r.geometry_status == RoomData.GeometryStatus.PHYSICAL:
			var node := main.get_node_or_null(r.scene_anchor)
			if node == null or (node.get_node_or_null("Floor") == null and node.get_node_or_null("MusicFloor") == null):
				anchors_ok = false
	_check("toda sala física aponta para um nó real com piso", anchors_ok, "")
	var music := db.get_room(&"room_6")
	_check("Música é sala física com âncora e navegação (Prompt 1)", music.geometry_status == RoomData.GeometryStatus.PHYSICAL
		and str(music.scene_anchor) == "School/MusicRoom" and music.navigation_mesh != null and music.navigation_layer == 6, "")

	var volumes := main.get_tree().get_nodes_in_group("room_volume")
	var by_room := {}
	var inside := true
	for v in volumes:
		by_room[v.room_id] = by_room.get(v.room_id, 0) + 1
		var shape: BoxShape3D = v.get_node("CollisionShape3D").shape
		var c: Vector3 = v.global_position
		var f: Array = FLOORS.get(v.room_id, [0, 0, 0, 0])
		if c.x - shape.size.x / 2.0 < f[0] or c.x + shape.size.x / 2.0 > f[1] or c.z - shape.size.z / 2.0 < f[2] or c.z + shape.size.z / 2.0 > f[3]:
			inside = false
	# Prompt 1: seis salas de aula + Sala de Monitoramento (a sala inicial não tem volume).
	_check("um volume por sala física (6 salas + Monitoramento)", volumes.size() == 7 and by_room.keys().size() == 7 and by_room.values().all(func(n): return n == 1) and not by_room.has(&"sala_inicial"), str(by_room))
	_check("cada volume cabe no piso real da sua sala", inside, "")
	_check("volumes novos invisíveis a raios (camada 0, não monitoráveis)", volumes.all(func(v): return v.collision_layer == 0 and not v.monitorable), "")


func _doors() -> void:
	print("--- conexões: portas reais (raios na parede leste)")
	var space := main.get_viewport().world_3d.direct_space_state
	for r in db.get_classrooms():  # Prompt 1: portas dos locais narrativos têm teste próprio (door_test)
		if r.geometry_status != RoomData.GeometryStatus.PHYSICAL:
			continue
		var f: Array = FLOORS[r.id]
		var area: Node = main.get_node(r.connected_area_paths[0])
		var open_over_area := 0
		var z: float = f[2] + 0.25
		while z < f[3]:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-6.0, 1.0, z), Vector3(0.0, 1.0, z), 1))
			if hit.is_empty() and _over_floor(area, Vector3(0.0, 0.0, z)):
				open_over_area += 1
			z += 0.25
		_check("%s: abertura real para %s" % [r.id, r.connected_area_paths[0]], open_over_area >= 8, "%.1f m livres" % (open_over_area * 0.25))


func _navigation() -> void:
	print("--- navegação só onde há cenário")
	var regions := main.get_node("Navigation").get_children()
	# Prompt 1: 6 salas + corredores + sala inicial + subsolo/Monitoramento.
	_check("9 regiões (6 salas, corredores, sala inicial, subsolo)", regions.size() == 9, "%d" % regions.size())
	for r in db.get_classrooms():
		if r.geometry_status != RoomData.GeometryStatus.PHYSICAL:
			continue
		var region := main.get_node_or_null(r.navigation_region_path) as NavigationRegion3D
		var ok := region != null and region.navigation_mesh == r.navigation_mesh and region.navigation_layers == r.navigation_layer_bit()
		var f: Array = FLOORS[r.id]
		var verts_inside := true
		for v in r.navigation_mesh.get_vertices():
			if v.x < f[0] + 0.5 or v.x > f[1] - 0.5 or v.z < f[2] + 0.5 or v.z > f[3] - 0.5:
				verts_inside = false
		_check("%s: região na camada %d, navmesh dentro do piso (sem corredor)" % [r.id, r.navigation_layer], ok and verts_inside, "")
		# pontos aleatórios do navmesh: corpo do monstro (r 0,6) não encosta em parede/móvel
		var blocked := 0
		var shape := SphereShape3D.new()
		shape.radius = 0.6
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.collision_mask = 1
		var space := main.get_viewport().world_3d.direct_space_state
		for i in 60:
			var p := NavigationServer3D.region_get_random_point(region.get_rid(), r.navigation_layer_bit(), false)
			params.transform = Transform3D(Basis(), p + Vector3.UP * 1.75)
			if not space.intersect_shape(params, 1).is_empty():
				blocked += 1
		_check("%s: 60 pontos navegáveis sem parede/móvel no corpo" % r.id, blocked == 0, "%d bloqueados" % blocked)

	var map := polvo.agent.get_navigation_map()
	# Prompt 1: com as portas ABERTAS, os links de navegação ligam sala ↔ corredor
	# (camada 7). Um monstro só navega nas camadas do próprio agente: com a máscara
	# do Ângulo (bit 2) não há rota até a Room 1; com sala + corredores, há.
	var cross := NavigationServer3D.map_get_path(map, Vector3(-13.5, 0, -48.0), Vector3(-13.5, 0, -18.7), true, 2)
	_check("salas não se ligam para o monstro (máscara do Ângulo: sem rota Room 2 → Room 1)", cross.is_empty() or _flat(cross[cross.size() - 1], Vector3(-13.5, 0, -18.7)) > 5.0, "")
	var via := NavigationServer3D.map_get_path(map, Vector3(-13.5, 0, -48.0), Vector3(-13.5, 0, -18.7), true, 1 | 2 | 64)
	_check("portas abertas ligam sala → corredor → sala (links, camadas 1|2|7)", not via.is_empty() and _flat(via[via.size() - 1], Vector3(-13.5, 0, -18.7)) < 1.0, "%d pontos" % via.size())


func _polvo_reference() -> void:
	print("--- Polvo: implementação de referência")
	var cfg := polvo.config
	_check("Polvo: mesmos parâmetros de comportamento", is_equal_approx(cfg.patrol_speed, 1.3) and is_equal_approx(cfg.investigate_speed, 1.6)
		and is_equal_approx(cfg.search_speed, 1.9) and is_equal_approx(cfg.chase_speed, 3.6) and is_equal_approx(cfg.sight_fov_degrees, 120.0)
		and cfg.allowed_states.is_empty() and cfg.return_to_home and cfg.visual_scene == null, "")
	_check("Polvo: camada de navegação 1 no agente", polvo.agent.navigation_layers == 1, str(polvo.agent.navigation_layers))
	var link := polvo.get_node("VisualLink") as RemoteTransform3D
	var placeholder: Node3D = main.get_node("School/Room 1/ProfessorPlaceholder")
	_check("Polvo: placeholder existente continua ligado e visível", not link.remote_path.is_empty() and placeholder.visible and polvo.visual_model == null, "")
	var corridor := Vector3(0, 0, -40.0)   # corredor junto à porta da Room 2
	var any := NavigationServer3D.map_get_closest_point(polvo.agent.get_navigation_map(), corridor)
	var own := polvo._closest_navigable(corridor)
	_check("consulta do mapa inteiro cairia na Room 2 (risco real)", any.z < -37.5, str(any.snapped(Vector3.ONE * 0.01)))
	_check("Polvo só considera a Room 1", own.z > -29.9 and own.z < -7.5 and own.x < -3.5, str(own.snapped(Vector3.ONE * 0.01)))
	var home := polvo.global_position
	_check("Polvo segue INACTIVE no posto", polvo.state == S.INACTIVE and _flat(home, Vector3(-21.2, 0, -18.7)) < 0.05, polvo.get_state_name())


func _other_room_monster() -> void:
	print("--- config de outra sala funciona no controlador real (instância só de teste)")
	var m: MonsterController = load("res://scenes/monsters/monster.tscn").instantiate()
	m.config = GameData.get_instance().get_monster(&"angle")
	_drop_trigger(m)   # sem gatilho nesta verificação
	m.position = Vector3(-13.5, 0, -48.0)   # main está na origem
	main.add_child(m)
	var wait := 0
	while not m.is_navigation_ready() and wait < 300:
		await physics_frame
		wait += 1
	_check("Ângulo: agente na camada 2", m.agent.navigation_layers == 2, "")
	m.activate(&"teste_fase4", m.global_position, true)
	await _physics(2)
	var targets := [Vector3(-21.0, 0, -40.0), Vector3(-6.0, 0, -56.0), Vector3(0, 0, -40.0)]   # o último fica no corredor
	var f: Array = FLOORS[&"room_2"]
	var outside := 0
	var reached := 0
	for t in targets:
		m.hear_stimulus(t)
		for i in 900:
			await physics_frame
			var p := m.global_position
			if p.x < f[0] or p.x > f[1] or p.z < f[2] or p.z > f[3]:
				outside += 1
			if not m._has_move_target:
				reached += 1
				break
	_check("Ângulo navega pela Room 2 e chega aos destinos", reached == targets.size(), "%d/%d" % [reached, targets.size()])
	_check("Ângulo nunca sai do piso da Room 2 (nem pelo som no corredor)", outside == 0, "%d quadros fora" % outside)
	_check("Polvo não foi afetado", polvo.state == S.INACTIVE, polvo.get_state_name())
	m.queue_free()
	await _physics(2)


func _visual_slot() -> void:
	print("--- modelo substituível sem mudar controlador")
	var model := Node3D.new()
	model.name = "ModeloTeste"
	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	var lib := AnimationLibrary.new()
	var walk := Animation.new()
	walk.length = 1.0
	lib.add_animation(&"andar", walk)
	anim_player.add_animation_library(&"", lib)
	model.add_child(anim_player)
	anim_player.owner = model
	var packed := PackedScene.new()
	packed.pack(model)
	model.free()

	var cfg: MonsterConfig = GameData.get_instance().get_monster(&"reader").duplicate()
	cfg.visual_scene = packed
	cfg.visual_offset = Vector3(0, 0.1, 0)
	cfg.animation_map = {"PATROLLING": "andar", "CHASING": "inexistente"}
	var placeholder := MeshInstance3D.new()
	main.add_child(placeholder)
	var m: MonsterController = load("res://scenes/monsters/monster.tscn").instantiate()
	m.config = cfg
	_drop_trigger(m)
	m.get_node("VisualLink").remote_path = NodePath("../../" + String(placeholder.name))
	m.position = Vector3(-13.5, 0, -104.3)
	main.add_child(m)
	await _physics(3)
	_check("modelo instanciado como VisualModel com deslocamento", m.visual_model != null and m.visual_model.name == "VisualModel" and m.visual_model.position.is_equal_approx(Vector3(0, 0.1, 0)), "")
	_check("placeholder antigo escondido e desligado", not placeholder.visible and m.get_node("VisualLink").remote_path.is_empty(), "")
	m.activate(&"teste_visual", m.global_position, true)
	await _physics(2)
	var ap: AnimationPlayer = m.visual_model.get_node("AnimationPlayer")
	_check("animação mapeada toca no estado", m.state == S.PATROLLING and ap.current_animation == "andar", ap.current_animation)
	m._change_state(S.CHASING)
	await _physics(1)
	_check("animação ausente é ignorada sem erro", m.state == S.CHASING, "")
	_check("percepção e controlador intactos", m.perception.config == cfg and m.is_in_group("monster") and m.is_in_group(SoundStimulus.LISTENER_GROUP), "")
	m.queue_free()
	placeholder.queue_free()
	await _physics(2)


func _progression() -> void:
	print("--- progressão com salas pendentes")
	rooms._refresh_solved()
	var none_solved := true
	for i in range(1, 6):
		if rooms.get_room_state(PLAN[i][0]) in [RS.SOLVED, RS.COMPLETED]:
			none_solved = false
	_check("sala pendente nunca é dada como resolvida", none_solved, "")
	_check("Room 2 bloqueada até concluir a Room 1", rooms.get_state_name(&"room_2") == "LOCKED", rooms.get_state_name(&"room_2"))
	rooms._set_state(&"room_1", RS.COMPLETED)   # simula a conclusão da Room 1
	_check("concluir a Room 1 libera a Room 2", rooms.get_state_name(&"room_2") == "AVAILABLE", rooms.get_state_name(&"room_2"))
	_check("e só ela", rooms.get_state_name(&"room_3") == "LOCKED", rooms.get_state_name(&"room_3"))
	player.global_position = Vector3(-13.5, 0.05, -48.0)
	await _physics(40)
	_check("entrar na Room 2 real: sala atual e ACTIVE", rooms.current_room == &"room_2" and rooms.get_state_name(&"room_2") == "ACTIVE", "%s %s" % [rooms.current_room, rooms.get_state_name(&"room_2")])
	rooms._refresh_solved()
	_check("Room 2 ativa continua não resolvida", rooms.get_state_name(&"room_2") == "ACTIVE", "")
	var r3: RoomData = db.get_room(&"room_3")
	r3.entry_required_rooms = [&"room_5"] as Array[StringName]
	_check("condição de entrada extra é respeitada", not rooms._entry_conditions_met(r3), "")
	r3.entry_required_rooms = [] as Array[StringName]


# ------------------------------------------------------------ apoio

func _rule(name: String, expected: String, breaker: Callable) -> void:
	var copy := _copy_db()
	breaker.call(copy)
	var errors := copy.validate(pdb)
	var found := false
	for e in errors:
		if e.contains(expected):
			found = true
	_check(name, found, "" if found else str(errors))


## Cópia independente (duplicate(true) não copia recursos externos no 4.7).
func _copy_db() -> NarrativeDatabase:
	var c := NarrativeDatabase.new()
	for r in db.rooms:
		c.rooms.append(r.duplicate())
	for e in db.events:
		c.events.append(e.duplicate())
	for m in db.monsters:
		c.monsters.append(m.duplicate())
	c.final_destination_id = db.final_destination_id
	return c


func _drop_trigger(m: Node) -> void:
	var t := m.get_node("Trigger")
	m.remove_child(t)
	t.free()


func _over_floor(area: Node, p: Vector3) -> bool:
	for c in area.get_children():
		if c is CSGBox3D and String(c.name).begins_with("Floor"):
			var a: AABB = c.global_transform * AABB(-c.size / 2.0, c.size)
			if p.x >= a.position.x and p.x <= a.end.x and p.z >= a.position.z and p.z <= a.end.z:
				return true
	return false


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("%s %s  %s" % ["OK    " if ok else "FALHA ", name, detail])


## Prompt 1: devolve a Música (só na cópia) ao estado de ponto de integração.
func _as_integration_point(r: RoomData) -> void:
	r.geometry_status = RoomData.GeometryStatus.INTEGRATION_POINT
	r.scene_anchor = NodePath()
	r.navigation_layer = 0
	r.navigation_mesh = null
	r.navigation_region_path = NodePath()
	r.connected_area_paths = [] as Array[NodePath]
