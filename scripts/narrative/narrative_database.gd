class_name NarrativeDatabase
extends Resource
## Conjunto de salas, locais narrativos, eventos e configurações de monstros
## (Etapa 5, Fase 1). Só dados e consultas, como o PuzzleDatabase.
## validate() cruza as referências com o PuzzleDatabase existente, sem
## alterá-lo: enigmas e pistas continuam sendo a fonte de verdade.

## Nível mínimo em que cada segredo pode aparecer ("não revele tudo no começo").
const SECRET_MIN_TIER := {
	&"voz_ajuda": 1,
	&"origem_criaturas": 2,
	&"voz_inconsistente": 2,
	&"vigilancia": 2,
	&"yuko_aluna": 1,       # a lista de chamada já mostra que ela estudou ali
	&"voz_telefone": 3,     # quem é a voz: só no final
	&"instalacao_pesquisa": 2,
	&"subsolo": 3,
	&"monitoramento": 3,
	&"gravacao_previa": 3,
	&"acidente_provocado": 3,
	&"visita_anterior": 3,
}
## Marcas de conteúdo que não pode aparecer como definitivo.
const NON_FINAL_MARKERS := ["[TESTE]", "[PROVISÓRIO]", "[PROVISORIO]"]

@export var rooms: Array[RoomData] = []
@export var events: Array[NarrativeEvent] = []
@export var monsters: Array[MonsterConfig] = []
## Local onde termina a história (sala de monitoramento). Precisa ser STORY_AREA.
@export var final_destination_id: StringName


# ------------------------------------------------------------ consultas

func get_room(room_id: StringName) -> RoomData:
	for room in rooms:
		if room != null and room.id == room_id:
			return room
	return null


func get_event(event_id: StringName) -> NarrativeEvent:
	for event in events:
		if event != null and event.id == event_id:
			return event
	return null


func get_monster(monster_id: StringName) -> MonsterConfig:
	for monster in monsters:
		if monster != null and monster.monster_id == monster_id:
			return monster
	return null


func get_classrooms() -> Array[RoomData]:
	var result: Array[RoomData] = []
	for room in rooms:
		if room != null and room.is_classroom():
			result.append(room)
	result.sort_custom(func(a, b): return a.order < b.order)
	return result


func get_room_for_puzzle(puzzle_id: StringName) -> RoomData:
	for room in rooms:
		if room != null and puzzle_id in room.puzzle_ids:
			return room
	return null


func get_room_for_monster(monster_id: StringName) -> RoomData:
	for room in rooms:
		if room != null and room.monster_id == monster_id:
			return room
	return null


func get_events_for_trigger(trigger: NarrativeEvent.TriggerType, trigger_id: StringName) -> Array[NarrativeEvent]:
	var result: Array[NarrativeEvent] = []
	for event in events:
		if event != null and event.trigger == trigger and event.trigger_id == trigger_id:
			result.append(event)
	return result


# ------------------------------------------------------------ validação

## Erros que impedem o uso dos dados (vazio = ok).
func validate(puzzle_db: PuzzleDatabase) -> PackedStringArray:
	return _run(puzzle_db)[0]


## Avisos que não impedem o uso (conteúdo de teste, eventos inalcançáveis...).
func get_warnings(puzzle_db: PuzzleDatabase) -> PackedStringArray:
	return _run(puzzle_db)[1]


func _run(puzzle_db: PuzzleDatabase) -> Array:
	var e: PackedStringArray = []
	var w: PackedStringArray = []
	if puzzle_db == null:
		e.append("PuzzleDatabase ausente: não é possível validar referências.")
		return [e, w]

	var room_ids := {}
	var event_ids := {}
	var monster_ids := {}
	var interaction_ids := {}
	var puzzle_owner := {}
	var monster_owner := {}
	var orders := {}

	for m in monsters:
		if m == null:
			e.append("Configuração de monstro nula.")
			continue
		if m.monster_id == &"":
			e.append("Monstro sem monster_id ('%s')." % m.display_name)
		elif monster_ids.has(m.monster_id):
			e.append("monster_id duplicado: %s." % m.monster_id)
		monster_ids[m.monster_id] = m

	for ev in events:
		if ev == null:
			e.append("Evento nulo.")
			continue
		if ev.id == &"":
			e.append("Evento sem id ('%s')." % ev.title)
		elif event_ids.has(ev.id):
			e.append("Id de evento duplicado: %s." % ev.id)
		event_ids[ev.id] = ev

	# ---------------- salas
	for room in rooms:
		if room == null:
			e.append("Sala nula.")
			continue
		if room.id == &"":
			e.append("Sala sem id ('%s')." % room.display_name)
			continue
		if room_ids.has(room.id):
			e.append("Id de sala duplicado: %s." % room.id)
		room_ids[room.id] = room
		for i in room.interaction_ids + room.activation_interaction_ids:
			interaction_ids[i] = room.id

	for room in rooms:
		if room == null or room.id == &"":
			continue
		var r := String(room.id)

		# cena
		if room.geometry_status == RoomData.GeometryStatus.PHYSICAL and room.scene_anchor.is_empty():
			e.append("%s: sala física sem scene_anchor." % r)
		if room.geometry_status == RoomData.GeometryStatus.INTEGRATION_POINT:
			if not room.scene_anchor.is_empty():
				e.append("%s: ponto de integração não pode apontar para geometria (%s)." % [r, room.scene_anchor])
			if room.technical_notes.strip_edges() == "":
				e.append("%s: ponto de integração sem technical_notes explicando o que falta." % r)
		if room.technical_name_provisional and room.technical_notes.strip_edges() == "":
			e.append("%s: nome técnico provisório sem documentação em technical_notes." % r)

		# sala de aula: campos obrigatórios
		if room.is_classroom():
			if room.subject.strip_edges() == "":
				e.append("%s: sala sem matéria." % r)
			if room.is_pending():
				# Fase 4: sala preparada sem conteúdo jogável. Pode ficar sem
				# enigma/gatilho, mas precisa dizer o que falta.
				if room.pending_items.is_empty():
					e.append("%s: sala pendente sem pending_items." % r)
				if room.puzzle_ids.is_empty() or (room.activation_interaction_ids.is_empty() and room.activation_puzzle_ids.is_empty() and room.activation_story_ids.is_empty()):
					w.append("%s: sala pendente (sem enigma/gatilho reais)." % r)
			else:
				if room.puzzle_ids.is_empty():
					e.append("%s: sala sem enigma." % r)
				# Versão 5: só Português e Música têm professor. Sala sem
				# monstro é válida (pistas + pergunta, sem perseguição).
				if room.monster_id != &"" and room.activation_interaction_ids.is_empty() and room.activation_puzzle_ids.is_empty() and room.activation_story_ids.is_empty():
					e.append("%s: sala sem gatilho de ativação do monstro." % r)
			if room.exit_event_id == &"":
				e.append("%s: sala sem evento de saída." % r)
			if room.order <= 0:
				e.append("%s: ordem inválida (%d)." % [r, room.order])
			elif orders.has(room.order):
				e.append("%s: ordem %d repetida (%s)." % [r, room.order, orders[room.order]])
			orders[room.order] = r

		# enigmas
		for pid in room.puzzle_ids:
			var puzzle := puzzle_db.get_puzzle(pid)
			if puzzle == null:
				e.append("%s: enigma inexistente: %s." % [r, pid])
				continue
			if puzzle_owner.has(pid):
				e.append("%s: enigma %s já pertence a %s." % [r, pid, puzzle_owner[pid]])
			puzzle_owner[pid] = r
			if puzzle.room_id != room.id:
				e.append("%s: enigma %s está com room_id '%s'." % [r, pid, puzzle.room_id])
			if puzzle.monster_id != &"" and room.monster_id != &"" and puzzle.monster_id != room.monster_id:
				e.append("%s: enigma %s aponta para o monstro '%s', a sala para '%s'." % [r, pid, puzzle.monster_id, room.monster_id])
			if room.content_status == RoomData.ContentStatus.FINAL and _is_marked(puzzle.title + " " + puzzle.description):
				e.append("%s: sala FINAL usa enigma de teste/provisório: %s." % [r, pid])
			elif room.content_status != RoomData.ContentStatus.TEST and pid.begins_with("teste_"):
				w.append("%s: usa o enigma de teste %s." % [r, pid])
		for pid in room.get_required_puzzles():
			if not pid in room.puzzle_ids:
				e.append("%s: enigma exigido %s não está em puzzle_ids." % [r, pid])
		for pid in room.activation_puzzle_ids:
			if puzzle_db.get_puzzle(pid) == null:
				e.append("%s: gatilho aponta para enigma inexistente: %s." % [r, pid])

		# pistas
		for cid in room.clue_ids:
			var clue := puzzle_db.get_clue(cid)
			if clue == null:
				e.append("%s: pista inexistente: %s." % [r, cid])
			elif clue.room_id != room.id:
				e.append("%s: pista %s está com room_id '%s'." % [r, cid, clue.room_id])

		# monstro
		if room.monster_id != &"":
			var monster: MonsterConfig = monster_ids.get(room.monster_id)
			if monster == null:
				e.append("%s: monstro sem configuração: %s." % [r, room.monster_id])
			else:
				if monster.room_id != room.id:
					e.append("%s: monstro %s está configurado para a sala '%s'." % [r, room.monster_id, monster.room_id])
				if monster_owner.has(room.monster_id):
					e.append("%s: monstro %s já pertence a %s." % [r, room.monster_id, monster_owner[room.monster_id]])
				monster_owner[room.monster_id] = r

		# saída
		if room.exit_id != &"":
			var opens := false
			for p in puzzle_db.get_puzzles_for_exit(room.exit_id):
				if p.id in room.get_required_puzzles():
					opens = true
				if not p.id in room.puzzle_ids:
					e.append("%s: saída %s também depende do enigma %s, de outra sala." % [r, room.exit_id, p.id])
			if not opens:
				e.append("%s: nenhum enigma da sala libera a saída %s." % [r, room.exit_id])

		# eventos
		for evid in [room.exit_event_id] + Array(room.narrative_event_ids):
			if evid != &"" and not event_ids.has(evid):
				e.append("%s: evento inexistente: %s." % [r, evid])

		_check_room_phase4(room, r, room_ids, interaction_ids, e, w)

	for m in monsters:
		if m != null and m.monster_id != &"" and not monster_owner.has(m.monster_id):
			e.append("Monstro %s não pertence a nenhuma sala." % m.monster_id)
	for m in monsters:
		if m != null and m.monster_id != &"":
			_check_monster_phase4(m, room_ids, event_ids, e, w)
	var layer_owner := {}
	for room in rooms:
		if room != null and room.navigation_layer > 0:
			if layer_owner.has(room.navigation_layer):
				e.append("%s: camada de navegação %d já usada por %s." % [room.id, room.navigation_layer, layer_owner[room.navigation_layer]])
			layer_owner[room.navigation_layer] = room.id

	# ---------------- destino final
	if final_destination_id != &"":
		var dest: RoomData = room_ids.get(final_destination_id)
		if dest == null:
			e.append("Destino final inexistente: %s." % final_destination_id)
		elif dest.is_classroom():
			e.append("Destino final (%s) não pode ser uma sala de aula." % final_destination_id)
		elif dest.technical_name_provisional:
			e.append("Destino final (%s) não pode usar uma sala de nome técnico provisório." % final_destination_id)

	# ---------------- eventos
	for ev in events:
		if ev == null or ev.id == &"":
			continue
		var x := String(ev.id)
		if not ev.enabled and ev.disabled_reason.strip_edges() == "":
			e.append("%s: evento desativado sem disabled_reason." % x)
		if ev.room_id != &"" and not room_ids.has(ev.room_id):
			e.append("%s: sala inexistente: %s." % [x, ev.room_id])
		if ev.lines.is_empty() and ev.title.strip_edges() == "":
			e.append("%s: evento sem texto." % x)
		if ev.content_status == NarrativeEvent.CONTENT_FINAL and _is_marked(ev.title + " " + " ".join(ev.lines)):
			e.append("%s: evento FINAL contém marca de teste/provisório." % x)

		# gatilho
		var tid := ev.trigger_id
		match ev.trigger:
			NarrativeEvent.TriggerType.INTERACTION:
				if not interaction_ids.has(tid):
					e.append("%s: gatilho em interação desconhecida: %s." % [x, tid])
			NarrativeEvent.TriggerType.CLUE_DISCOVERED:
				if puzzle_db.get_clue(tid) == null:
					e.append("%s: gatilho em pista inexistente: %s." % [x, tid])
			NarrativeEvent.TriggerType.PUZZLE_SOLVED:
				if puzzle_db.get_puzzle(tid) == null:
					e.append("%s: gatilho em enigma inexistente: %s." % [x, tid])
			NarrativeEvent.TriggerType.ROOM_ENTERED, NarrativeEvent.TriggerType.ROOM_COMPLETED:
				if not room_ids.has(tid):
					e.append("%s: gatilho em sala inexistente: %s." % [x, tid])
			NarrativeEvent.TriggerType.MONSTER_STATE:
				if not monster_ids.has(tid):
					e.append("%s: gatilho em monstro inexistente: %s." % [x, tid])
				if not String(ev.trigger_state) in MonsterController.State.keys():
					e.append("%s: estado de monstro inválido: '%s'." % [x, ev.trigger_state])
			NarrativeEvent.TriggerType.EVENT_FINISHED:
				if tid == ev.id:
					e.append("%s: gatilho no próprio evento." % x)
				elif not event_ids.has(tid):
					e.append("%s: gatilho em evento inexistente: %s." % [x, tid])
			NarrativeEvent.TriggerType.MANUAL:
				pass

		# condições
		for cid in ev.required_clues:
			if puzzle_db.get_clue(cid) == null:
				e.append("%s: condição com pista inexistente: %s." % [x, cid])
		for pid in ev.required_puzzles_solved:
			if puzzle_db.get_puzzle(pid) == null:
				e.append("%s: condição com enigma inexistente: %s." % [x, pid])
		for rid in ev.required_rooms_completed:
			if not room_ids.has(rid):
				e.append("%s: condição com sala inexistente: %s." % [x, rid])
		for iid in ev.required_interactions:
			if not interaction_ids.has(iid):
				e.append("%s: condição com interação desconhecida: %s." % [x, iid])
		for oid in ev.required_events + ev.blocked_by_events:
			if oid == ev.id:
				e.append("%s: condição no próprio evento." % x)
			elif not event_ids.has(oid):
				e.append("%s: condição com evento inexistente: %s." % [x, oid])
			elif oid in ev.required_events and not event_ids[oid].enabled and ev.enabled:
				w.append("%s: depende de %s, que está desativado (inalcançável por enquanto)." % [x, oid])

		# progressão dos segredos
		for tag in ev.reveals:
			if not SECRET_MIN_TIER.has(tag):
				w.append("%s: segredo sem nível mínimo cadastrado: %s." % [x, tag])
			elif ev.tier < SECRET_MIN_TIER[tag]:
				e.append("%s: revela '%s' no nível %d (mínimo %d)." % [x, tag, ev.tier, SECRET_MIN_TIER[tag]])
		if ev.type == NarrativeEvent.EventType.REVELATION:
			if ev.tier == NarrativeEvent.Tier.INITIAL:
				e.append("%s: revelação no nível inicial." % x)
			if not ev.once:
				e.append("%s: revelação precisa ser única (once = true)." % x)
		# Concluir sala, resolver enigma ou seguir outro evento já são portões de
		# progressão; entrar num local, interagir etc. precisam de condição explícita.
		var gated_trigger := ev.trigger in [NarrativeEvent.TriggerType.MANUAL, NarrativeEvent.TriggerType.ROOM_COMPLETED,
			NarrativeEvent.TriggerType.PUZZLE_SOLVED, NarrativeEvent.TriggerType.EVENT_FINISHED]
		if ev.tier == NarrativeEvent.Tier.FINAL and ev.enabled and not gated_trigger and not ev.has_conditions():
			e.append("%s: evento do nível final sem nenhuma condição." % x)
		if ev.room_id != &"" and room_ids.has(ev.room_id) and ev.tier > room_ids[ev.room_id].narrative_tier:
			e.append("%s: nível %d em sala de nível %d (revela cedo demais)." % [x, ev.tier, room_ids[ev.room_id].narrative_tier])

	# ---------------- ciclos em required_events / EVENT_FINISHED
	for ev in events:
		if ev != null and ev.id != &"" and _has_cycle(ev.id, event_ids, {}):
			e.append("%s: dependência circular entre eventos." % ev.id)

	return [e, w]


func _has_cycle(start: StringName, event_ids: Dictionary, visiting: Dictionary) -> bool:
	if visiting.has(start):
		return true
	var ev: NarrativeEvent = event_ids.get(start)
	if ev == null:
		return false
	visiting[start] = true
	var deps: Array = Array(ev.required_events)
	if ev.trigger == NarrativeEvent.TriggerType.EVENT_FINISHED:
		deps.append(ev.trigger_id)
	for dep in deps:
		if _has_cycle(dep, event_ids, visiting):
			return true
	visiting.erase(start)
	return false


func _is_marked(text: String) -> bool:
	var upper := text.to_upper()
	for marker in NON_FINAL_MARKERS:
		if upper.contains(marker):
			return true
	return false


# ------------------------------------------------ regras da Fase 4

func _check_room_phase4(room: RoomData, r: String, room_ids: Dictionary, interaction_ids: Dictionary, e: PackedStringArray, w: PackedStringArray) -> void:
	var physical := room.geometry_status == RoomData.GeometryStatus.PHYSICAL
	# entrada
	for rid in room.entry_required_rooms:
		if rid == room.id:
			e.append("%s: entrada depende da própria sala." % r)
		elif not room_ids.has(rid):
			e.append("%s: entrada depende de sala inexistente: %s." % [r, rid])
		elif room.is_classroom() and room_ids[rid].is_classroom() and room_ids[rid].order >= room.order:
			e.append("%s: entrada depende de %s, que vem depois no percurso." % [r, rid])
	# conexões: só salas com geometria podem apontar para a cena
	if not physical and not room.connected_area_paths.is_empty():
		e.append("%s: ponto de integração não pode ter conexões físicas na cena." % r)
	if not physical and room.connection_notes.strip_edges() == "" and room.is_classroom():
		w.append("%s: ponto de integração sem connection_notes (onde se ligará)." % r)
	# objetos e mecanismos previstos
	var seen := {}
	for pid in room.planned_interaction_ids:
		if not String(pid).begins_with(r + "."):
			e.append("%s: ponto de integração '%s' fora do formato %s.nome." % [r, pid, r])
		if seen.has(pid):
			e.append("%s: ponto de integração repetido: %s." % [r, pid])
		seen[pid] = true
		if interaction_ids.has(pid):
			e.append("%s: '%s' é previsto, mas já é uma interação real." % [r, pid])
	# navegação: só onde há cenário
	if not physical:
		if room.navigation_layer != 0 or room.navigation_mesh != null or not room.navigation_region_path.is_empty():
			e.append("%s: ponto de integração não pode ter navegação." % r)
	elif room.navigation_layer > 0 and (room.navigation_mesh == null or room.navigation_region_path.is_empty()):
		e.append("%s: camada de navegação sem navmesh ou sem região na cena." % r)
	elif room.navigation_mesh != null and room.navigation_layer == 0:
		e.append("%s: navmesh sem camada de navegação." % r)


func _check_monster_phase4(m: MonsterConfig, room_ids: Dictionary, event_ids: Dictionary, e: PackedStringArray, w: PackedStringArray) -> void:
	var x := String(m.monster_id)
	var states: Array = MonsterController.State.keys()
	for st in m.allowed_states:
		if not st in states:
			e.append("%s: estado permitido inválido: '%s'." % [x, st])
	for st in m.state_events:
		if not String(st) in states:
			e.append("%s: state_events com estado inválido: '%s'." % [x, st])
			continue
		if not m.allowed_states.is_empty() and not String(st) in m.allowed_states:
			e.append("%s: evento para o estado %s, que não é permitido." % [x, st])
		var evid := StringName(m.state_events[st])
		var ev: NarrativeEvent = event_ids.get(evid)
		if ev == null:
			e.append("%s: state_events aponta para evento inexistente: %s." % [x, evid])
		elif ev.trigger != NarrativeEvent.TriggerType.MONSTER_STATE or ev.trigger_id != m.monster_id or String(ev.trigger_state) != String(st):
			e.append("%s: evento %s não é disparado por %s em %s." % [x, evid, x, st])
	for key in m.animation_map:
		if not String(key) in states:
			e.append("%s: animation_map com estado inválido: '%s'." % [x, key])
	if m.hearing_profile == null:
		w.append("%s: sem hearing_profile (usa os campos antigos de audição)." % x)
	var room: RoomData = room_ids.get(m.room_id)
	if room != null and room.navigation_layer > 0 and m.navigation_layers & room.navigation_layer_bit() == 0:
		e.append("%s: não usa a camada de navegação da sua sala (%d)." % [x, room.navigation_layer])
	if room != null and room.is_pending() and m.placeholder_notes.strip_edges() == "":
		e.append("%s: monstro de sala pendente sem placeholder_notes." % x)
