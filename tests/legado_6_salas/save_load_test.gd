extends SceneTree
## Prompt 3 — checkpoint em user:// e restauração: progresso das salas,
## pistas, enigmas, interações, narrativa, portas, monstros, protagonista,
## telefone e objetivo. Também o "Tentar do checkpoint" do Game Over.
## Uso: godot --headless --fixed-fps 60 --path . --script res://tests/save_load_test.gd

const T := preload("res://tests/test_input.gd")
var main: Node
var s: GameSession
var passed := 0
var failed := 0


func _initialize() -> void:
	SaveSystem.save_path = "user://teste_save_load.json"
	SaveSystem.settings_path = "user://teste_save_load.cfg"
	SaveSystem.delete_save()
	await _load_main("")
	_check("sem save no início do teste", not SaveSystem.has_save(), "")
	var db := GameData.get_instance()
	var polvo: MonsterController = main.get_node("Room1Gameplay/Polvo")

	print("--- jogando: muda tudo o que o save precisa guardar")
	var clue_ids: Array[String] = []
	for c in db.puzzle_db.clues:
		if s.clues.discover(c.id):
			clue_ids.append(String(c.id))
	var puzzle: PuzzleData = null
	for p in db.puzzle_db.puzzles:
		if p.room_id == &"room_1":
			puzzle = p
			break
	s.puzzles._mark_solved(puzzle)
	s.puzzles.register_interaction(&"room_1.armario")
	s.narrative.trigger_manual(&"telefone_despertar")
	await _wait_until(func(): return s.phone.history.size() >= 1 and s.phone.state == "idle", 12.0)
	s.rooms._set_state(&"room_1", RoomData.RoomState.COMPLETED)
	await _phys(3)
	var d2: Door = main.get_node("School/Doors/PortaRoom2")
	d2.open()
	var dsub: Door = main.get_node("School/Doors/PortaSubsolo")
	dsub.unlock()
	polvo.activate(&"teste_save", polvo.global_position, true)
	await _phys(3)
	polvo.global_position = Vector3(-15.0, polvo.global_position.y, -20.0)
	s.player.global_position = Vector3(-8.0, 0.05, -15.0)
	await _phys(4)
	var expect := {
		"room_1": s.rooms.get_state_name(&"room_1"), "room_2": s.rooms.get_state_name(&"room_2"),
		"polvo": polvo.global_position, "player": s.player.global_position, "objective": s.hud.objective,
	}
	_check("pistas descobertas para o teste", clue_ids.size() >= 1, str(clue_ids))
	_check("telefone tocou e guardou a fala", s.phone.history.size() >= 1 and s.phone.history[0].text == "Não faça barulho. Eles ainda não sabem que você acordou.", str(s.phone.history))
	_check("objetivo na HUD veio do evento", s.hud.objective == "Saia da sala sem fazer barulho.", s.hud.objective)
	_check("checkpoint gravado em user://", s.save_checkpoint("teste") and SaveSystem.has_save(), SaveSystem.save_path)
	var raw := SaveSystem.read_save()
	_check("arquivo tem versão, salas, pistas, enigmas, narrativa, portas, monstros e telefone",
		int(raw.get("version", 0)) == 1 and ["rooms", "clues", "puzzles", "narrative", "doors", "monsters", "phone", "player", "objective"].all(func(k): return raw.has(k)), str(raw.keys()))

	print("--- carregando numa cena NOVA (Continuar)")
	main.queue_free()
	await _phys(3)
	await _load_main("continue")
	polvo = main.get_node("Room1Gameplay/Polvo")
	await _wait_until(func(): return s.ready_done, 5.0)
	await _phys(3)
	for id in clue_ids:
		_check("pista %s restaurada" % id, s.clues.is_discovered(StringName(id)), "")
	_check("enigma %s resolvido" % puzzle.id, s.puzzles.is_solved(puzzle.id), "")
	_check("interação registrada (room_1.armario)", s.puzzles.has_interaction(&"room_1.armario"), "")
	_check("narrativa: chamada já disparada e não repete", s.narrative.has_fired(&"telefone_despertar") and not s.narrative.trigger_manual(&"telefone_despertar"), "")
	_check("salas: room_1 %s, room_2 %s" % [expect.room_1, expect.room_2], s.rooms.get_state_name(&"room_1") == expect.room_1 and s.rooms.get_state_name(&"room_2") == expect.room_2,
		"%s / %s" % [s.rooms.get_state_name(&"room_1"), s.rooms.get_state_name(&"room_2")])
	_check("porta da room_2 aberta", (main.get_node("School/Doors/PortaRoom2") as Door).is_open(), "")
	_check("acesso ao subsolo destrancado (fechado)", (main.get_node("School/Doors/PortaSubsolo") as Door).get_state_name() == "CLOSED", (main.get_node("School/Doors/PortaSubsolo") as Door).get_state_name())
	_check("porta da Música continua fechada", not (main.get_node("School/Doors/PortaMusica") as Door).is_open(), "")
	_check("Polvo ativo, em vigia, na posição salva", polvo.is_active() and polvo.state == MonsterController.State.PATROLLING and _flat(polvo.global_position, expect.polvo) < 0.6,
		"%s %.2f m" % [polvo.get_state_name(), _flat(polvo.global_position, expect.polvo)])
	_check("protagonista na posição salva", _flat(s.player.global_position, expect.player) < 0.3, str(s.player.global_position))
	_check("histórico do telefone restaurado", s.phone.history.size() >= 1 and s.phone.history[0].speaker == "Desconhecido", str(s.phone.history))
	_check("objetivo restaurado", s.hud.objective == expect.objective, s.hud.objective)
	_check("o telefone não toca de novo ao carregar", s.phone.state == "idle", s.phone.state)

	print("--- checkpoint ao entrar em sala liberada")
	var before := s.last_checkpoint_reason
	s.rooms.room_entered.emit(&"room_2")
	await _phys(3)
	_check("entrar na room_2 (liberada) grava checkpoint", s.last_checkpoint_reason == "entrou em room_2", "%s → %s" % [before, s.last_checkpoint_reason])
	s.rooms.room_entered.emit(&"room_3")
	await _phys(3)
	_check("entrar na room_3 (anterior não concluída) não grava", s.last_checkpoint_reason == "entrou em room_2", s.last_checkpoint_reason)

	print("--- Game Over → Tentar do checkpoint (restaura de fato)")
	s.player.global_position = Vector3(-20.0, 0.05, -25.0)
	s.clues.load_save_data({})   # "perde" as pistas na memória
	await _phys(2)
	polvo.player_caught.emit()
	await _phys(2)
	var go = get_first_node_in_group("game_over_ui")
	_check("captura abre o Game Over e pausa", go.is_open() and paused, "")
	(go.find_child("TentarDoCheckpoint", true, false) as Button).pressed.emit()
	await _phys(6)
	_check("Tentar do checkpoint: despausa e fecha a tela", not paused and not go.is_open(), "")
	_check("Tentar do checkpoint: protagonista volta ao checkpoint", _flat(s.player.global_position, expect.player) < 0.3, str(s.player.global_position))
	_check("Tentar do checkpoint: pistas voltam", clue_ids.all(func(id): return s.clues.is_discovered(StringName(id))), "")
	SaveSystem.delete_save()
	print("RESULTADO: %d/%d testes passaram" % [passed, passed + failed])
	quit(1 if failed > 0 else 0)


func _load_main(action: String) -> void:
	SaveSystem.pending_action = action
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _phys(6)
	for m in get_nodes_in_group("monster"):
		if m.name != "Polvo":
			m.process_mode = Node.PROCESS_MODE_DISABLED
	s = get_first_node_in_group("game_session")
	for n in get_nodes_in_group("game_session"):
		if n.is_inside_tree() and n.get_parent() == main:
			s = n


func _wait_until(cond: Callable, seconds: float) -> void:
	var frames := int(seconds * 60)
	for i in frames:
		if cond.call():
			return
		await process_frame


func _phys(n: int) -> void:
	for i in n:
		await physics_frame


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _check(label: String, ok: bool, info: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("%s %s  %s" % ["OK    " if ok else "FALHA ", label, info])
