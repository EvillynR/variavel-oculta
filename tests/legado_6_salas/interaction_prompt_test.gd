extends SceneTree
## Testes do prompt de interação e dos textos de depuração (correções pós-Etapa 4).
## Usa a tecla física E (InputEventKey), o mesmo caminho de um teclado real.

var passed := 0
var failed := 0
var main: Node
var player: CharacterBody3D
var interactor: PlayerInteractor
var polvo: MonsterController
var objs := {}


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	preload("res://tests/test_input.gd").open_all_doors(self)  # Prompt 1: portas físicas
	await _physics(10)
	player = main.get_node("Player")
	interactor = main.get_node("Systems/PlayerInteractor")
	polvo = main.get_node("Room1Gameplay/Polvo")
	for n in ["Experimento", "CadernoLaboratorio", "TabelaPeriodica", "Armario"]:
		objs[n] = main.get_node("Room1Gameplay/Interactables/" + n)

	print("--- textos de depuração")
	var labels := polvo.find_children("*", "Label3D", true, false)
	_check("Polvo sem texto de depuração no jogo normal", labels.is_empty(), "%d Label3D" % labels.size())
	_check("router sem log por padrão", not main.get_node("Systems/InteractionRouter").debug_log, "")
	var debug_monster: MonsterController = load("res://scenes/monsters/monster.tscn").instantiate()
	debug_monster.debug_label = true
	debug_monster.config = MonsterConfig.new()
	root.add_child(debug_monster)
	var dbg_labels := debug_monster.find_children("*", "Label3D", true, false)
	_check("ativável manualmente (debug_label = true)", dbg_labels.size() == 1, "")
	_check("texto de depuração respeita paredes (no_depth_test = false)", dbg_labels.size() == 1 and not dbg_labels[0].no_depth_test, "")
	debug_monster.queue_free()

	print("--- prompt só perto de objeto válido")
	await _tp(Vector3(-12.0, 0.05, -18.7))
	_check("longe de tudo: nenhum prompt", _visible_prompts().is_empty(), str(_visible_prompts()))
	for case in [["Armario", Vector3(-8, 0.05, -27.6)], ["CadernoLaboratorio", Vector3(-13.2, 0.05, -13)],
			["TabelaPeriodica", Vector3(-18, 0.05, -9.2)], ["Experimento", Vector3(-13.2, 0.05, -24)]]:
		await _tp(case[1])
		_check("perto de %s: só o prompt dele" % case[0], _visible_prompts() == [case[0]], str(_visible_prompts()))
	await _tp(Vector3(-12.0, 0.05, -18.7))
	_check("ao se afastar, prompt some", _visible_prompts().is_empty(), str(_visible_prompts()))

	print("--- prompt não atravessa parede")
	# Do outro lado da parede norte da Room 1, a 1 m da tabela (dentro da área).
	player.global_position = Vector3(-18, 0.9, -6.9)
	player.velocity = Vector3.ZERO
	await _physics(2)
	_check("protagonista está dentro da área da tabela (teste não é vazio)", objs["TabelaPeriodica"] in interactor._candidates, "")
	_check("tabela não selecionável através da parede", interactor.get_current_target() == null and _visible_prompts().is_empty(), str(_visible_prompts()))

	print("--- objetos repetíveis continuam funcionando")
	await _tp(Vector3(-13.2, 0.05, -13))
	await _key_e()
	_check("caderno: E registra e prompt continua (pode reler)", main.get_node("Systems/PuzzleManager").has_interaction(&"room_1.caderno_laboratorio") and _visible_prompts() == ["CadernoLaboratorio"], str(_visible_prompts()))
	await _tp(Vector3(-8, 0.05, -27.6))
	await _key_e()
	_check("armário: E registra e prompt continua", main.get_node("Systems/PuzzleManager").has_interaction(&"room_1.armario") and _visible_prompts() == ["Armario"], "")
	objs["Armario"].set_enabled(false)
	_check("objeto desativado: prompt some na hora", not _prompt_visible(objs["Armario"]), "")
	await _physics(2)
	_check("objeto desativado: deixa de ser alvo", interactor.get_current_target() == null, "")
	objs["Armario"].set_enabled(true)
	await _physics(2)
	_check("reativado: prompt volta", _visible_prompts() == ["Armario"], str(_visible_prompts()))
	_check("objetos errados não ativaram o Polvo", polvo.state == MonsterController.State.INACTIVE, polvo.get_state_name())

	print("--- experimento: prompt some ao despertar o Polvo")
	await _tp(Vector3(-13.2, 0.05, -24))
	_check("prompt do experimento visível antes", _visible_prompts() == ["Experimento"], "")
	var hidden_on_wake := [null]
	polvo.activated.connect(func(_r): hidden_on_wake[0] = not _prompt_visible(objs["Experimento"]))
	await _key_e()
	_check("Polvo despertou com a tecla física E", polvo.state == MonsterController.State.AWAKENING, polvo.get_state_name())
	_check("prompt já oculto no instante do despertar", hidden_on_wake[0] == true, str(hidden_on_wake[0]))
	await _physics(30)
	_check("continua oculto com a protagonista parada ao lado", _visible_prompts().is_empty(), str(_visible_prompts()))
	var activations := [0]
	polvo.activated.connect(func(_r): activations[0] += 1)
	await _key_e()
	_check("E de novo não faz nada", activations[0] == 0 and interactor.get_current_target() == null, "")
	await _tp(Vector3(-12.0, 0.05, -18.7))
	await _tp(Vector3(-13.2, 0.05, -24))
	_check("sair e voltar: prompt do experimento não reaparece", _visible_prompts().is_empty(), str(_visible_prompts()))

	print("RESULTADO: %d/%d testes passaram" % [passed, passed + failed])
	quit(1 if failed > 0 else 0)


func _prompt_visible(obj: Interactable) -> bool:
	for child in obj.get_children():
		if child is Label3D and child.visible:
			return true
	return false


func _visible_prompts() -> Array:
	var result := []
	for n in objs:
		if _prompt_visible(objs[n]):
			result.append(n)
	return result


func _key_e() -> void:
	await physics_frame
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	await process_frame
	var up := InputEventKey.new()
	up.physical_keycode = KEY_E
	up.pressed = false
	Input.parse_input_event(up)
	await _physics(2)


func _tp(p: Vector3) -> void:
	player.global_position = p
	player.velocity = Vector3.ZERO
	await _physics(4)


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("%s  %s  %s" % ["OK   " if ok else "FALHA", name, detail if not ok else ""])
