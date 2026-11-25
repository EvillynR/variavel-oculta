extends SceneTree
## Prompt 2 — banco JSON (data/game_data.json) como fonte principal.
## Verifica: carregamento sem erros; as seis salas e o mapeamento real para os nós
## da cena; coerência cena <-> JSON dos objetos interativos; Polvo e seu gatilho
## vindos do JSON; condições de objeto em jogo; nenhum .tres de dados em uso; e
## que JSON com problemas gera mensagens compreensíveis.
## Uso: godot --headless -s tests/game_data_test.gd

var results := []


func _initialize() -> void:
	var db := GameData.get_instance()
	print("--- banco real")
	_check("JSON carrega sem erros", db.is_valid(), "\n    ".join(db.errors))
	# Prompt 1: +2 locais narrativos (STORY_AREA: sala_inicial e sala_monitoramento);
	# continuam exatamente seis salas de aula.
	_check("contagens", db.narrative_db.rooms.size() == 8 and db.narrative_db.get_classrooms().size() == 6 and db.narrative_db.monsters.size() == 6
		and db.puzzle_db.puzzles.size() == 8 and db.puzzle_db.clues.size() == 3 and db.narrative_db.events.size() == 15,  # Prompt 3: + chamada do despertar e alerta do Polvo
		"%d salas, %d monstros, %d enigmas, %d pistas, %d eventos, %d objetos" % [db.narrative_db.rooms.size(),
		db.narrative_db.monsters.size(), db.puzzle_db.puzzles.size(), db.puzzle_db.clues.size(),
		db.narrative_db.events.size(), db.objects.size()])

	print("--- seis salas (id -> matéria, monstro, nó da cena)")
	var expected := [
		[&"room_1", "Ciências", &"octopus", "School/Room 1"],
		[&"room_2", "Matemática", &"angle", "School/Room 2"],
		[&"room_3", "Artes", &"painter", "School/Exit"],
		[&"room_4", "Português/Literatura", &"reader", "School/Room 3"],
		[&"room_5", "Geografia", &"cartographer", "School/Room 4"],
		[&"room_6", "Música", &"maestro", "School/MusicRoom"],  # Prompt 1: sala física
	]
	var classrooms := db.narrative_db.get_classrooms()
	for i in expected.size():
		var e: Array = expected[i]
		var r: RoomData = classrooms[i] if i < classrooms.size() else null
		var monster := db.get_monster(e[2])
		_check("%s = %s / %s / %s" % [e[0], e[1], e[2], e[3] if e[3] != "" else "(sem nó)"],
			r != null and r.id == e[0] and r.order == i + 1 and r.subject == e[1] and r.monster_id == e[2]
			and str(r.scene_anchor) == e[3] and monster != null and monster.room_id == r.id,
			"" if r == null else "%s %s %s %s" % [r.id, r.subject, r.monster_id, r.scene_anchor])
	var r6 := db.narrative_db.get_room(&"room_6")
	# Prompt 1: a Música ganhou cenário ligado à escola (Corredor 5) e navegação na camada 6.
	_check("Música física: âncora, camada 6, navmesh, região e pendências de conteúdo",
		r6.geometry_status == RoomData.GeometryStatus.PHYSICAL and r6.navigation_layer == 6 and r6.navigation_mesh != null
		and str(r6.navigation_region_path) == "Navigation/MusicNavigation" and r6.is_pending() and r6.pending_items.size() > 0, "")
	_check("destino final = Sala de Monitoramento (local narrativo)", db.narrative_db.final_destination_id == &"sala_monitoramento"
		and not db.narrative_db.get_room(&"sala_monitoramento").is_classroom(), str(db.narrative_db.final_destination_id))
	var r3 := db.narrative_db.get_room(&"room_3")
	var r3_text := " ".join(r3.pending_items)
	# Prompt 1: a parede leste com porta foi construída e os vãos oeste fechados;
	# as pendências de cenário saíram da lista e a conexão documenta a porta.
	_check("Artes: nó com nome provisório; parede leste com porta documentada, sem pendência de cenário",
		r3.technical_name_provisional and r3.connection_notes.contains("parede leste") and not r3_text.contains("Cenário:"), "")
	for r in db.narrative_db.rooms:
		_check("%s: estado de implementação registrado" % r.id, r.content_status == RoomData.ContentStatus.TEST or (r.is_pending() and r.pending_items.size() > 0)
			or (not r.is_classroom() and r.content_status == RoomData.ContentStatus.PROVISIONAL),
			RoomData.ContentStatus.find_key(r.content_status))

	print("--- cena principal <-> JSON")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	preload("res://tests/test_input.gd").open_all_doors(self)  # Prompt 1: portas físicas
	await process_frame
	await process_frame
	for r in db.narrative_db.rooms:
		if r.geometry_status == RoomData.GeometryStatus.PHYSICAL:
			_check("%s: âncora %s existe na cena" % [r.id, r.scene_anchor], main.get_node_or_null(r.scene_anchor) != null, "")
	var scene_ids := {}
	for node in main.find_children("*", "Area3D", true, false):
		if node is Interactable:
			var it: Interactable = node
			scene_ids[it.interaction_id] = true
			var o := db.get_object(it.interaction_id)
			_check("cena: %s cadastrado como FUNCTIONAL no caminho certo" % it.interaction_id,
				o != null and o.is_functional() and o.scene_node == main.get_path_to(it), "")
			# Prompt 1: portas trocam o texto em jogo (Abrir / Fechar / Trancada).
			var prompt_ok: bool = it.prompt_text == o.prompt_text if o != null else false
			if o != null and o.is_door():
				prompt_ok = it.prompt_text in ["E  Abrir", "E  Fechar", "Trancada"]
			_check("cena: %s recebeu ação/texto/uso único do JSON" % it.interaction_id,
				o != null and it.definition == o and it.action_id == o.action_id and prompt_ok and it.one_shot == o.one_shot,
				"%s \"%s\" one_shot=%s" % [it.action_id, it.prompt_text, it.one_shot])
	for o in db.objects:
		if o.is_functional():
			var n := main.get_node_or_null(o.scene_node)
			_check("JSON: objeto FUNCTIONAL %s existe na cena" % o.id, n is Interactable and n.interaction_id == o.id, str(o.scene_node))
		else:
			_check("JSON: objeto %s (%s) não está na cena" % [o.id, InteractiveObjectData.Implementation.find_key(o.implementation)],
				not scene_ids.has(o.id), "")

	print("--- Polvo e gatilho vindos do JSON")
	var polvo: MonsterController = main.get_node("Room1Gameplay/Polvo")
	_check("Polvo usa o MonsterConfig do JSON", polvo.config == db.get_monster(&"octopus") and polvo.config.hearing_profile == db.get_hearing_profile(&"polvo_audicao"), "")
	var trigger: MonsterTrigger = polvo.get_node("Trigger")
	_check("gatilho do Polvo = objetos com efeito activate_monster", trigger.activation_interaction_ids == ([&"room_1.experimento"] as Array[StringName]), str(trigger.activation_interaction_ids))
	_check("pistas ligadas aos objetos pelos efeitos reveal_clue",
		db.puzzle_db.get_clue(&"teste_pista_caderno").source_object_id == &"room_1.caderno_laboratorio"
		and db.puzzle_db.get_clue(&"teste_pista_tabela").source_object_id == &"room_1.tabela_periodica", "")
	# Prompt 1: + a porta da sala (room_1.porta); Prompt 2: + 2 esconderijos.
	_check("objetos da Room 1 derivados (7 funcionais, ordem do JSON)", db.narrative_db.get_room(&"room_1").interaction_ids
		== ([&"room_1.experimento", &"room_1.caderno_laboratorio", &"room_1.tabela_periodica", &"room_1.armario", &"room_1.porta", &"room_1.esconderijo_armario", &"room_1.esconderijo_mesa"] as Array[StringName]), str(db.narrative_db.get_room(&"room_1").interaction_ids))
	_check("referências narrativas do caderno derivadas", db.get_object(&"room_1.caderno_laboratorio").narrative_event_ids.has(&"teste_room_1_caderno"), "")

	print("--- condições de objeto em jogo (sistema de interação existente)")
	var armario: Interactable = main.get_node("Room1Gameplay/Interactables/Armario")
	var before := armario.can_interact()
	armario.definition.required_clues = [&"teste_pista_caderno"] as Array[StringName]
	var blocked := not armario.can_interact()
	main.get_node("Systems/ClueManager").discover_from_object(&"room_1.caderno_laboratorio")
	var released := armario.can_interact()
	armario.definition.required_clues = [] as Array[StringName]
	_check("sem condições: interação livre (como antes)", before, "")
	_check("condição de pista bloqueia e libera a interação", blocked and released, "bloqueou=%s liberou=%s" % [blocked, released])
	main.queue_free()

	print("--- nenhum .tres de dados em uso")
	var scene_text := FileAccess.get_file_as_string("res://scenes/main.tscn")
	_check("cena não referencia os .tres antigos", not (scene_text.contains("puzzle_database.tres") or scene_text.contains("narrative_database.tres") or scene_text.contains("_config.tres")), "")

	print("--- mensagens de erro (JSON com problemas)")
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameData.DEFAULT_PATH))
	_expect_error("sintaxe", "{ \"format_version\": 1, \"rooms\": [ }", "linha")
	_expect_error("campo desconhecido", _mut(base, func(d): d.rooms[1]["corredor"] = "x"), "rooms[1] \"room_2\": campo desconhecido \"corredor\"")
	_expect_error("enum inválido", _mut(base, func(d): d.rooms[0].kind = "SALA"), "aceitos: CLASSROOM, STORY_AREA")
	_expect_error("tipo errado", _mut(base, func(d): d.rooms[0].order = "um"), "\"order\" deveria ser um número inteiro")
	_expect_error("id repetido", _mut(base, func(d): d.rooms[1].id = "room_1"), "id \"room_1\" repetido")
	_expect_error("pista inexistente", _mut(base, func(d): d.objects[1].effects[0].clue_id = "nao_existe"), "pista \"nao_existe\" não existe")
	_expect_error("objeto planejado com efeito", _mut(base, func(d): _find(d.objects, "room_2.gatilho_monstro").effects = [{"type": "activate_monster", "monster_id": "angle"}]), "PLANNED não pode ter efeitos")
	# Prompt 1: a Música agora é física; a regra continua testada transformando-a
	# (só nesta cópia) de volta em ponto de integração.
	_expect_error("objeto funcional em sala sem cenário", _mut(base, func(d):
		var r6m: Dictionary = _find(d.rooms, "room_6")
		r6m.geometry_status = "INTEGRATION_POINT"
		for k in ["scene_anchor", "navigation_layer", "navigation_mesh", "navigation_region_path", "connected_area_paths"]:
			r6m.erase(k)
		for od in d.objects:
			if od.get("room_id") == "room_6" and od.get("implementation") == "FUNCTIONAL":
				od.implementation = "PLANNED"; od.erase("scene_node"); od.erase("door")
		var o: Dictionary = _find(d.objects, "room_6.gatilho_monstro")
		o.implementation = "FUNCTIONAL"
		o.scene_node = "School/Musica/Gatilho"), "sem cenário físico")
	_expect_error("porta com tranca inválida", _mut(base, func(d): _find(d.objects, "room_2.porta").door.lock = "chave"), "door.lock \"chave\" inválido")
	_expect_error("porta presa a sala inexistente", _mut(base, func(d): _find(d.objects, "room_2.porta").door.room_id = "room_9"), "door.room_id \"room_9\" não existe")
	_expect_error("unlock_door para algo que não é porta", _mut(base, func(d): _find(d.objects, "room_1.armario").effects = [{"type": "unlock_door", "door_id": "room_1.caderno_laboratorio"}]), "não existe em objects (objeto com campo \"door\")")
	_expect_error("campo derivado escrito", _mut(base, func(d): d.clues[0].source_object_id = "room_1.armario"), "calculado pelo carregador")
	_expect_error("perfil de audição inexistente", _mut(base, func(d): d.monsters[0].hearing_profile = "nenhum"), "perfil de audição \"nenhum\" não existe")
	_expect_error("efeito desconhecido", _mut(base, func(d): d.objects[0].effects.append({"type": "teleportar"})), "tipo de efeito \"teleportar\" desconhecido")
	_expect_error("evento ativo dependendo de objeto planejado", _mut(base, func(d):
		var e: Dictionary = _find(d.events, "angulo_despertar")
		e.enabled = true
		e.erase("disabled_reason")
		e.trigger = "INTERACTION"
		e.trigger_id = "room_2.gatilho_monstro"), "depende do objeto PLANNED")
	_expect_error("enigma sem sala (validação existente reaproveitada)", _mut(base, func(d): d.puzzles[0].room_id = "room_99"), "está com room_id 'room_99'")

	var ok := results.filter(func(r): return r).size()
	print("RESULTADO: %d/%d testes passaram" % [ok, results.size()])
	quit(0 if ok == results.size() else 1)


func _expect_error(label: String, text: String, fragment: String) -> void:
	var db := GameData.load_text(text, "teste")
	var hit := ""
	for e in db.errors:
		if e.contains(fragment):
			hit = e
	_check("erro legível: %s" % label, hit != "", hit if hit != "" else "esperado trecho «%s»; erros: %s" % [fragment, db.errors])


func _mut(base: Dictionary, change: Callable) -> String:
	var d: Dictionary = base.duplicate(true)
	change.call(d)
	return JSON.stringify(d)


func _find(list: Array, id: String) -> Dictionary:
	for e in list:
		if e.get("id") == id:
			return e
	return {}


func _check(label: String, ok: bool, info: String) -> void:
	results.append(ok)
	print("%s %s  %s" % ["OK    " if ok else "FALHOU", label, info])
