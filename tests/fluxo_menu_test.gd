extends SceneTree
## Prompt 3 — fluxo completo de produto, com as cenas reais trocadas pelo
## SceneTree (como no jogo): menu → configurações → novo jogo → telefone do
## despertar → HUD → diário → pausa → voltar ao checkpoint → menu principal.
## História de Yuko: a abertura é uma cena de filme e a voz do telefone só liga
## quando ela pega o mapa (cena_mapa) — o teste segue esse caminho.
## Conta erros do motor durante tudo (Logger) — precisa terminar com zero.
## Uso: godot --headless --fixed-fps 60 --path . --script res://tests/fluxo_menu_test.gd

const LORE := "NÃO FAÇA BARULHO."
var log_errors := preload("res://tests/test_errors.gd").new()
var passed := 0
var failed := 0
var phone_rang := false


func _initialize() -> void:
	OS.add_logger(log_errors)
	SaveSystem.save_path = "user://teste_fluxo.json"
	SaveSystem.settings_path = "user://teste_fluxo.cfg"
	SaveSystem.delete_save()
	if FileAccess.file_exists(SaveSystem.settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.settings_path))
	_check("cena inicial do projeto = menu principal", ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/ui/main_menu.tscn", str(ProjectSettings.get_setting("application/run/main_scene")))

	print("--- menu principal")
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await _frames(5)
	var menu = current_scene
	_check("menu aberto", menu != null and menu.name == "MainMenu", str(menu))
	_check("Novo jogo, Configurações, Créditos e Sair presentes", ["novo", "config", "creditos", "sair"].all(func(k): return menu.buttons.has(k) and menu.buttons[k].visible), "")
	_check("Continuar escondido sem save", not menu.continue_button.visible, "")
	menu.open_credits()
	await _frames(2)
	_check("créditos abrem", menu._overlay != null and menu._overlay.is_inside_tree(), "")
	menu._overlay.queue_free()

	print("--- configurações (persistidas em user://)")
	menu.open_settings()
	await _frames(2)
	var panel: SettingsPanel = menu.find_children("*", "SettingsPanel", true, false)[0]
	panel._apply_setting("volume", 0.4)
	panel._apply_setting("brightness", 1.3)
	panel._apply_setting("subtitle_size", 28)
	panel._apply_setting("camera_sensitivity", 1.5)
	SaveSystem.remap_action("diario", KEY_K)
	SaveSystem.settings = {}
	SaveSystem.load_settings()
	_check("configurações gravadas e relidas do arquivo", FileAccess.file_exists(SaveSystem.settings_path) and is_equal_approx(float(SaveSystem.settings.volume), 0.4)
		and is_equal_approx(float(SaveSystem.settings.brightness), 1.3) and int(SaveSystem.settings.subtitle_size) == 28, str(SaveSystem.settings))
	_check("volume aplicado no barramento Master", is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.4), "")
	_check("remapeamento: Diário na tecla K (e persistido)", SaveSystem.key_name("diario") == "K" and int(SaveSystem.keys.get("diario", 0)) == KEY_K, SaveSystem.key_name("diario"))
	panel.close()
	await _frames(2)

	print("--- novo jogo")
	menu.new_game()
	await _frames(8)
	var session: GameSession = get_first_node_in_group("game_session")
	_check("cena do jogo carregada", current_scene != null and current_scene.name == "Main" and session != null, str(current_scene))
	await _wait_until(func(): return session.ready_done, 3.0)
	# versão 5.9: o "Brilho" multiplica a base escura (0,85)
	_check("brilho aplicado no ambiente do jogo", is_equal_approx(current_scene.get_node("WorldEnvironment").environment.adjustment_brightness, 1.3 * 0.85), "")
	await _wait_until(func(): return session.story.cutscenes.playing, 5.0)
	_check("abertura (cena de filme) toca no jogo novo", session.story.cutscenes.playing, "")
	await _wait_until(func(): return not session.story.is_busy(), 90.0)
	_check("HUD: objetivo da abertura", session.hud.objective_label.text == "Objetivo: Examine o banco do pátio.", session.hud.objective_label.text)
	# Pega o mapa: a "voz" aparece escrita no mapa, dentro da cena do mapa.
	var interactor: PlayerInteractor = get_first_node_in_group("player_interactor")
	session.player.global_position = Vector3(-11.0, 0.05, -76.3)
	await _frames(8)
	interactor.try_interact()
	await _wait_until(func(): return session.story.cutscenes.playing, 5.0)
	await _wait_until(func(): return not session.story.is_busy(), 120.0)
	phone_rang = session.story.map.notes.any(func(n): return String(n.text).begins_with(LORE))
	_check("a voz aparece escrita no mapa quando ela pega o mapa", phone_rang, "")
	_check("nada pelo telefone", session.phone.history.is_empty(), str(session.phone.history))
	_check("legenda usa o tamanho configurado", session.story.cutscenes._sub_text.get_theme_font_size("font_size") == 30, "")
	_check("HUD: objetivo atual", session.hud.objective_label.text.begins_with("Objetivo: Vá até a Sala de Português"), session.hud.objective_label.text)
	await _frames(3)
	_check("checkpoint gravado depois do mapa", SaveSystem.has_save() and session.last_checkpoint_reason == "mapa", session.last_checkpoint_reason)
	_press("telefone")
	await _frames(2)
	_check("tecla do telefone não abre mais nada", not session.phone.is_history_open(), "")
	_press("mapa")
	await _frames(2)
	_check("tecla do mapa abre o mapa (com os escritos)", session.story.map.is_open() and paused, "")
	_press("mapa")
	await _frames(2)
	_check("tecla do mapa fecha o mapa", not session.story.map.is_open() and not paused, "")

	print("--- HUD e diário")
	Input.action_press("crouch")
	for i in 4:
		await physics_frame
	await _frames(1)
	_check("HUD: indicador AGACHADA", session.hud.status_label.text == "AGACHADA", session.hud.status_label.text)
	Input.action_release("crouch")
	for i in 4:
		await physics_frame
	var clue: ClueData = GameData.get_instance().puzzle_db.clues[0]
	session.clues.discover(clue.id)
	_press("diario")
	await _frames(2)
	_check("diário abre (tecla remapeada) e lista a pista descoberta", session.journal.is_open() and session.journal.listed_titles().has(clue.title), str(session.journal.listed_titles()))
	_press("diario")
	await _frames(2)

	print("--- enigma + pausa convivendo")
	session.player.global_position = Vector3(-12.0, 0.05, -18.0)
	for i in 40:
		await physics_frame
	await _wait_until(func(): return not session.story.is_busy(), 60.0)   # cena de entrada da sala
	var pz: PuzzleUI = current_scene.get_node("PuzzleUI")
	_check("PuzzleUI achou os managers (antes do Prompt 3 nunca achava)", pz.puzzle_manager != null and pz.clue_manager != null, "")
	for c in [&"port_quadro", &"port_frase", &"port_classes"]:
		session.clues.discover(c)
	pz.open_by_id(&"port_gaveta")   # o que o cadeado da gaveta faz (efeito open_puzzle)
	await _frames(3)
	_check("o cadeado da gaveta (Sala 1) abre a pergunta e pausa", pz.is_open() and paused, "")
	_press("pause")
	await _frames(2)
	_check("Esc com o enigma aberto não abre a pausa por cima", not session.pause_menu.is_open(), "")
	_press("ui_cancel")
	await _frames(2)
	_check("enigma fechado: jogo volta a rodar", not pz.is_open() and not paused, "")

	print("--- pausa")
	var saved: Dictionary = SaveSystem.read_save()
	var start_pos := Vector3(saved.player.pos[0], saved.player.pos[1], saved.player.pos[2])
	print("   último checkpoint: ", saved.get("reason", ""), " em ", start_pos)
	session.player.global_position = Vector3(0, 0.05, -12.0)
	await _frames(3)
	_press("pause")
	await _frames(2)
	_check("Esc abre a pausa e pausa o jogo", session.pause_menu.is_open() and paused, "")
	_check("pausa: Continuar, Configurações, Checkpoint e Menu", ["continuar", "config", "checkpoint", "menu"].all(func(k): return session.pause_menu.buttons.has(k)), "")
	_press("pause")
	await _frames(2)
	_check("Esc de novo fecha e despausa", not session.pause_menu.is_open() and not paused, "")
	_press("pause")
	await _frames(2)
	(session.pause_menu.buttons["checkpoint"] as Button).pressed.emit()
	await _frames(10)
	session = get_first_node_in_group("game_session")
	await _wait_until(func(): return session != null and session.ready_done, 3.0)
	await _frames(4)
	_check("Voltar ao checkpoint: cena recarregada e despausada", session != null and not paused and current_scene.name == "Main", "")
	_check("Voltar ao checkpoint: protagonista no ponto salvo", Vector2(session.player.global_position.x - start_pos.x, session.player.global_position.z - start_pos.z).length() < 0.5, str(session.player.global_position))
	_check("Voltar ao checkpoint: histórico do telefone mantido, sem tocar de novo", session.phone.history.size() == saved.get("phone", []).size() and session.phone.state == "idle" and not session.story.cutscenes.playing, str(session.phone.history.size()))

	print("--- menu principal")
	_press("pause")
	await _frames(2)
	(session.pause_menu.buttons["menu"] as Button).pressed.emit()
	await _frames(6)
	_check("voltou ao menu principal, despausado", current_scene != null and current_scene.name == "MainMenu" and not paused, str(current_scene))
	_check("Continuar aparece com o save", current_scene.continue_button.visible, "")

	SaveSystem.reset_keys()
	SaveSystem.delete_save()
	_check("nenhum erro do motor em todo o fluxo", log_errors.errors.is_empty(), "\n   ".join(log_errors.errors.slice(0, 8)))
	print("RESULTADO: %d/%d testes passaram" % [passed, passed + failed])
	quit(1 if failed > 0 else 0)


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)


func _wait_until(cond: Callable, seconds: float) -> void:
	for i in int(seconds * 60):
		if cond.call():
			return
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(label: String, ok: bool, info: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("%s %s  %s" % ["OK    " if ok else "FALHA ", label, info])
