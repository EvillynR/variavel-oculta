extends SceneTree
## Etapa 5, Fase 2 — gera o banco narrativo MÍNIMO (só Room 1 / Polvo).
## Conteúdo de TESTE, claramente marcado; os dados das seis salas chegam na
## Fase 4 e os eventos narrativos reais na Fase 5.
## Não sobrescreve arquivos existentes, a menos que receba -- --force.
## ATENÇÃO (Fase 4): o banco agora tem as seis salas. NÃO use --force:
## regravaria narrative_database.tres e room_1.tres só com a Room 1.
## Uso: godot --headless --path . --script res://tools/build_narrative_minimal.gd

const T := NarrativeEvent.TriggerType
var force := false


func _initialize() -> void:
	push_error("OBSOLETO (Prompt 2): os dados agora ficam em data/game_data.json, carregado por GameData. Esta ferramenta gravava os .tres antigos (arquivados em docs/legado/legado_tres_pre_json.zip) e foi desativada para não criar um segundo banco.")
	quit(1)
	return
	force = "--force" in OS.get_cmdline_user_args()

	var room := RoomData.new()
	room.id = &"room_1"
	room.kind = RoomData.Kind.CLASSROOM
	room.order = 1
	room.subject = "Ciências"
	room.display_name = "Laboratório de Ciências"
	room.content_status = RoomData.ContentStatus.TEST
	room.geometry_status = RoomData.GeometryStatus.PHYSICAL
	room.scene_anchor = NodePath("School/Room 1")
	room.technical_notes = "Usa os enigmas de TESTE da Etapa 3 (teste_ciencias_*). Conteúdo real na Fase 5."
	room.puzzle_ids = [&"teste_ciencias_alternativa", &"teste_ciencias_codigo"]
	room.clue_ids = [&"teste_pista_caderno", &"teste_pista_tabela"]
	room.interaction_ids = [&"room_1.experimento", &"room_1.caderno_laboratorio", &"room_1.tabela_periodica", &"room_1.armario"]
	room.activation_interaction_ids = [&"room_1.experimento"]
	room.monster_id = &"octopus"
	room.exit_id = &"room_1_exit"
	room.exit_event_id = &"teste_room_1_saida"
	room.narrative_tier = 1
	room.narrative_event_ids = [&"teste_room_1_caderno", &"teste_polvo_despertar"]

	var events: Array[NarrativeEvent] = [
		_event(&"teste_room_1_caderno", NarrativeEvent.EventType.DOCUMENT, T.INTERACTION, &"room_1.caderno_laboratorio", &"",
			"[TESTE] Caderno lido", "[TESTE] Evento técnico: confirma que ler o caderno dispara um documento."),
		_event(&"teste_polvo_despertar", NarrativeEvent.EventType.CREATURE_AWAKENING, T.MONSTER_STATE, &"octopus", &"AWAKENING",
			"[TESTE] Polvo desperta", "[TESTE] Evento técnico: confirma o gatilho por estado do monstro."),
		_event(&"teste_room_1_saida", NarrativeEvent.EventType.ENVIRONMENT, T.ROOM_COMPLETED, &"room_1", &"",
			"[TESTE] Saída da Room 1", "[TESTE] Evento técnico: confirma o evento de saída da sala."),
	]

	var saved_events: Array[NarrativeEvent] = []
	for ev in events:
		saved_events.append(_save(ev, "res://data/narrative/test/%s.tres" % ev.id))
	var saved_room: RoomData = _save(room, "res://data/narrative/rooms/room_1.tres")

	var db := NarrativeDatabase.new()
	db.rooms = [saved_room]
	db.events = saved_events
	db.monsters = [load("res://data/monsters/polvo_config.tres")]
	var problems := db.validate(load("res://data/puzzle_database.tres"))
	print("validação: ", problems)
	_save(db, "res://data/narrative/narrative_database.tres")
	quit(0 if problems.is_empty() else 1)


func _event(id, type, trigger, trigger_id, state, title, line) -> NarrativeEvent:
	var ev := NarrativeEvent.new()
	ev.id = id
	ev.type = type
	ev.tier = NarrativeEvent.Tier.INITIAL
	ev.room_id = &"room_1"
	ev.content_status = NarrativeEvent.CONTENT_TEST
	ev.trigger = trigger
	ev.trigger_id = trigger_id
	ev.trigger_state = state
	ev.title = title
	ev.lines = PackedStringArray([line])
	return ev


func _save(res: Resource, path: String) -> Resource:
	if FileAccess.file_exists(path) and not force:
		print("mantido (já existe): ", path)
		return load(path)
	var err := ResourceSaver.save(res, path)
	assert(err == OK, "falha ao salvar " + path)
	print("salvo: ", path)
	return load(path)
