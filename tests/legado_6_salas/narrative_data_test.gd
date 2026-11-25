extends SceneTree
## Etapa 5, Fase 1 — modelo de dados narrativo e validação cruzada.
## Usa um conjunto de dados de TESTE montado em memória (nada é salvo e
## nenhum .tres real é alterado). Cada regra de validação é verificada
## quebrando o conjunto válido de um jeito específico.
## Uso: godot --headless --path . --script res://tests/narrative_data_test.gd

var passed := 0
var failed := 0
const T := NarrativeEvent.TriggerType


func _initialize() -> void:
	print("--- dados existentes continuam válidos e inalterados")
	var real_db: PuzzleDatabase = GameData.get_instance().puzzle_db
	_check("PuzzleDatabase real sem erros", real_db.validate().is_empty(), str(real_db.validate()))
	var polvo: MonsterConfig = GameData.get_instance().get_monster(&"octopus")
	_check("Polvo: parâmetros antigos iguais",
		polvo.monster_id == &"octopus" and is_equal_approx(polvo.patrol_speed, 1.3) and is_equal_approx(polvo.investigate_speed, 1.6)
		and is_equal_approx(polvo.search_speed, 1.9) and is_equal_approx(polvo.chase_speed, 3.6) and is_equal_approx(polvo.eye_height, 2.9)
		and is_equal_approx(polvo.sight_fov_degrees, 120.0) and is_equal_approx(polvo.sight_distance, 12.0), "")
	# Fase 3: a audição do Polvo vem do perfil próprio (hearing_profile); o
	# campo antigo noise_sensitivity segue no padrão, só como compatibilidade.
	_check("Polvo: campos novos neutros (volta ao posto, todos os estados, sem modelo novo) e audição pelo perfil próprio",
		polvo.noise_sensitivity == 0.0 and polvo.hearing_profile != null and polvo.return_to_home and polvo.leash_radius == 0.0
		and polvo.allowed_states.is_empty() and polvo.visual_scene == null and polvo.animation_map.is_empty()
		and polvo.sound_bank.is_empty()
		and polvo.state_events == {"AWAKENING": &"teste_polvo_despertar"}, "")   # Fase 4: evento por estado já existente

	print("--- conjunto de dados de teste válido (6 salas, 6 monstros, 2 locais narrativos)")
	var base := _fixture()
	var errors: PackedStringArray = base[0].validate(base[1])
	_check("conjunto válido não tem erros", errors.is_empty(), "\n    ".join(errors))
	_check("seis salas de aula em ordem", base[0].get_classrooms().map(func(r): return r.subject) ==
		["Ciências", "Matemática", "Artes", "Português/Literatura", "Geografia", "Música"], "")
	_check("cada sala aponta para o enigma e o monstro certos",
		base[0].get_room_for_puzzle(&"p_ciencias").monster_id == &"octopus"
		and base[0].get_room_for_monster(&"maestro").id == &"room_6", "")
	_check("sala Artes documentada como nome técnico provisório",
		base[0].get_room(&"room_3").technical_name_provisional and base[0].get_room(&"room_3").scene_anchor == NodePath("School/Exit"), "")
	_check("Música é só ponto de integração (sem geometria simulada)",
		base[0].get_room(&"room_6").geometry_status == RoomData.GeometryStatus.INTEGRATION_POINT
		and base[0].get_room(&"room_6").scene_anchor.is_empty(), "")
	var call: NarrativeEvent = base[0].get_event(&"telefone_despertar")
	_check("ligação inicial cadastrada, desativada e sem disparo automático",
		call != null and not call.enabled and not call.can_auto_trigger() and call.disabled_reason.contains("Etapa 7"), "")
	_check("eventos procurados por gatilho", base[0].get_events_for_trigger(T.ROOM_COMPLETED, &"room_1").size() == 1, "")
	var warns: PackedStringArray = base[0].get_warnings(base[1])
	_check("aviso: depender de evento desativado", "\n".join(warns).contains("desativado"), "\n    ".join(warns))

	print("--- regras de validação (cada caso deve gerar o erro esperado)")
	_rule("id de sala duplicado", "duplicado", func(n, p): n.rooms[1].id = &"room_1")
	_rule("enigma inexistente", "enigma inexistente", func(n, p): n.rooms[0].puzzle_ids.append(&"nao_existe"))
	_rule("enigma com room_id de outra sala", "room_id", func(n, p): p.get_puzzle(&"p_matematica").room_id = &"room_5")
	_rule("enigma em duas salas", "já pertence", func(n, p): n.rooms[1].puzzle_ids.append(&"p_ciencias"))
	_rule("enigma aponta para outro monstro", "aponta para o monstro", func(n, p): p.get_puzzle(&"p_ciencias").monster_id = &"maestro")
	_rule("pista de outra sala", "pista p_pista_1 está com room_id", func(n, p): n.rooms[1].clue_ids.append(&"p_pista_1"))
	_rule("sala sem monstro", "sala sem monstro", func(n, p): n.rooms[0].monster_id = &"")
	_rule("monstro configurado para outra sala", "configurado para a sala", func(n, p): n.get_monster(&"angle").room_id = &"room_1")
	_rule("monstro sem sala", "não pertence a nenhuma sala", func(n, p):
		var extra := MonsterConfig.new(); extra.monster_id = &"sobra"; n.monsters.append(extra))
	_rule("sala sem gatilho de ativação", "gatilho de ativação", func(n, p): n.rooms[0].activation_interaction_ids.clear())
	_rule("saída não liberada pelos enigmas da sala", "libera a saída", func(n, p): n.rooms[0].exit_id = &"outra_saida")
	_rule("evento de saída inexistente", "evento inexistente", func(n, p): n.rooms[0].exit_event_id = &"sumiu")
	_rule("ordem repetida", "repetida", func(n, p): n.rooms[1].order = 1)
	_rule("ponto de integração com geometria", "não pode apontar para geometria", func(n, p): n.rooms[5].scene_anchor = NodePath("School/Room 4"))
	_rule("nome provisório sem documentação", "nome técnico provisório", func(n, p): n.rooms[2].technical_notes = "")
	_rule("sala física sem âncora", "sem scene_anchor", func(n, p): n.rooms[0].scene_anchor = NodePath(""))
	_rule("destino final numa sala de aula", "não pode ser uma sala de aula", func(n, p): n.final_destination_id = &"room_6")
	_rule("destino final na sala 'Exit' (nome provisório)", "nome técnico provisório", func(n, p):
		n.rooms[2].kind = RoomData.Kind.STORY_AREA; n.final_destination_id = &"room_3")
	_rule("sala FINAL usando enigma de teste", "sala FINAL usa enigma", func(n, p):
		n.rooms[0].content_status = RoomData.ContentStatus.FINAL; p.get_puzzle(&"p_ciencias").title = "[TESTE] Qual frasco?")
	_rule("evento FINAL com texto provisório", "marca de teste", func(n, p):
		var ev: NarrativeEvent = n.get_event(&"doc_ciencias"); ev.content_status = NarrativeEvent.CONTENT_FINAL; ev.lines = PackedStringArray(["[PROVISÓRIO] texto"]))
	_rule("evento desativado sem motivo", "sem disabled_reason", func(n, p): n.get_event(&"telefone_despertar").disabled_reason = "")
	_rule("gatilho em interação desconhecida", "interação desconhecida", func(n, p): n.get_event(&"doc_ciencias").trigger_id = &"room_1.fantasma")
	_rule("estado de monstro inválido", "estado de monstro inválido", func(n, p): n.get_event(&"despertar_polvo").trigger_state = &"DANCANDO")
	_rule("revelação no nível inicial", "revelação no nível inicial", func(n, p):
		var ev: NarrativeEvent = n.get_event(&"revelacao_vigilancia"); ev.tier = NarrativeEvent.Tier.INITIAL; ev.reveals.clear(); ev.room_id = &"")
	_rule("revelação que pode repetir", "precisa ser única", func(n, p): n.get_event(&"revelacao_vigilancia").once = false)
	_rule("segredo cedo demais (subsolo no nível 2)", "revela 'subsolo'", func(n, p): n.get_event(&"revelacao_vigilancia").reveals.append(&"subsolo"))
	_rule("evento final sem condição", "sem nenhuma condição", func(n, p): n.get_event(&"revelacao_gravacao").required_rooms_completed.clear())
	_rule("evento de nível alto em sala de nível baixo", "revela cedo demais", func(n, p): n.get_event(&"revelacao_vigilancia").room_id = &"room_1")
	_rule("dependência circular", "circular", func(n, p):
		n.get_event(&"doc_ciencias").required_events.append(&"saida_ciencias")
		n.get_event(&"saida_ciencias").required_events.append(&"doc_ciencias"))

	print("RESULTADO: %d/%d testes passaram" % [passed, passed + failed])
	quit(1 if failed > 0 else 0)


## Monta o conjunto válido, aplica a quebra e confere se o erro esperado aparece.
func _rule(name: String, expected: String, breaker: Callable) -> void:
	var f := _fixture()
	breaker.call(f[0], f[1])
	var errors: PackedStringArray = f[0].validate(f[1])
	var found := false
	for err in errors:
		if err.contains(expected):
			found = true
	_check(name, found, "" if found else "erros: %s" % str(errors))


# ------------------------------------------------------------ dados de teste

func _fixture() -> Array:
	var p := PuzzleDatabase.new()
	var n := NarrativeDatabase.new()
	var spec := [
		# id, ordem, matéria, monstro, âncora, nível
		[&"room_1", 1, "Ciências", &"octopus", "School/Room 1", 1, &"p_ciencias"],
		[&"room_2", 2, "Matemática", &"angle", "School/Room 2", 1, &"p_matematica"],
		[&"room_3", 3, "Artes", &"painter", "School/Exit", 2, &"p_artes"],
		[&"room_4", 4, "Português/Literatura", &"reader", "School/Room 3", 2, &"p_portugues"],
		[&"room_5", 5, "Geografia", &"cartographer", "School/Room 4", 2, &"p_geografia"],
		[&"room_6", 6, "Música", &"maestro", "", 3, &"p_musica"],
	]
	for s in spec:
		var puzzle := PuzzleData.new()
		puzzle.id = s[6]
		puzzle.room_id = s[0]
		puzzle.question_type = PuzzleData.QuestionType.DOOR_CODE
		puzzle.correct_answer = "1"
		puzzle.unlocks_exit = StringName(String(s[0]) + "_exit")
		p.puzzles.append(puzzle)

		var clue := ClueData.new()
		clue.id = StringName("p_pista_%d" % s[1])
		clue.room_id = s[0]
		clue.puzzle_id = s[6]
		clue.source_object_id = StringName("%s.objeto" % s[0])
		p.clues.append(clue)

		var m := MonsterConfig.new()
		m.monster_id = s[3]
		m.room_id = s[0]
		n.monsters.append(m)

		var room := RoomData.new()
		room.id = s[0]
		room.order = s[1]
		room.subject = s[2]
		room.monster_id = s[3]
		room.narrative_tier = s[5]
		room.puzzle_ids.append(s[6])
		room.clue_ids.append(clue.id)
		room.interaction_ids.append(clue.source_object_id)
		room.activation_interaction_ids.append(StringName("%s.gatilho" % s[0]))
		room.exit_id = puzzle.unlocks_exit
		room.exit_event_id = StringName("saida_%d" % s[1])
		if s[4] == "":
			room.geometry_status = RoomData.GeometryStatus.INTEGRATION_POINT
			room.technical_notes = "Sem geometria: ponto de integração no fim do Corredor 4."
		else:
			room.scene_anchor = NodePath(s[4])
		if s[0] == &"room_3":
			room.technical_name_provisional = true
			room.technical_notes = "Nó técnico 'Exit' é provisório; não é a saída da história."
		n.rooms.append(room)
		n.events.append(_event(room.exit_event_id, NarrativeEvent.EventType.ENVIRONMENT, s[5], s[0], T.ROOM_COMPLETED, s[0]))

	n.events[0].id = &"saida_ciencias"
	n.rooms[0].exit_event_id = &"saida_ciencias"

	for area in [[&"monitoramento", "Sala de monitoramento"], [&"subsolo", "Instalação subterrânea"]]:
		var a := RoomData.new()
		a.id = area[0]
		a.kind = RoomData.Kind.STORY_AREA
		a.display_name = area[1]
		a.narrative_tier = 3
		a.geometry_status = RoomData.GeometryStatus.INTEGRATION_POINT
		a.technical_notes = "Sem geometria nesta etapa."
		n.rooms.append(a)
	n.final_destination_id = &"monitoramento"

	var call := _event(&"telefone_despertar", NarrativeEvent.EventType.PHONE_CALL, 1, &"", T.MANUAL, &"")
	call.enabled = false
	call.disabled_reason = "Sequência de despertar — Etapa 7."
	call.speaker = "Voz desconhecida"
	n.events.append(call)
	var after_call := _event(&"telefone_instrucoes", NarrativeEvent.EventType.PHONE_CALL, 1, &"", T.EVENT_FINISHED, &"telefone_despertar")
	n.events.append(after_call)

	var doc := _event(&"doc_ciencias", NarrativeEvent.EventType.DOCUMENT, 1, &"room_1", T.INTERACTION, &"room_1.objeto")
	n.events.append(doc)
	var wake := _event(&"despertar_polvo", NarrativeEvent.EventType.CREATURE_AWAKENING, 1, &"room_1", T.MONSTER_STATE, &"octopus")
	wake.trigger_state = &"AWAKENING"
	n.events.append(wake)
	var reveal := _event(&"revelacao_vigilancia", NarrativeEvent.EventType.REVELATION, 2, &"room_3", T.PUZZLE_SOLVED, &"p_artes")
	reveal.reveals = [&"vigilancia"]
	reveal.required_rooms_completed = [&"room_1", &"room_2"]
	n.events.append(reveal)
	var final_reveal := _event(&"revelacao_gravacao", NarrativeEvent.EventType.REVELATION, 3, &"monitoramento", T.ROOM_ENTERED, &"monitoramento")
	final_reveal.reveals = [&"gravacao_previa", &"monitoramento"]
	final_reveal.required_rooms_completed = [&"room_6"]
	n.events.append(final_reveal)
	return [n, p]


func _event(id: StringName, type: int, tier: int, room: StringName, trigger: int, trigger_id: StringName) -> NarrativeEvent:
	var ev := NarrativeEvent.new()
	ev.id = id
	ev.type = type
	ev.tier = tier
	ev.room_id = room
	ev.trigger = trigger
	ev.trigger_id = trigger_id
	ev.title = "[TESTE] %s" % id
	ev.lines = PackedStringArray(["[TESTE] texto de teste"])
	return ev


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("%s %s  %s" % ["OK    " if ok else "FALHA ", name, detail])
