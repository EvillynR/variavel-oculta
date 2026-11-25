extends SceneTree
## Versão 5.1 — "ela não sai pelo pátio": a porta do pátio fica do lado da
## câmera (não aparece na tela), então ela abre sozinha no fim da cena do mapa.
## Aqui a Yuko ANDA de verdade (teclas, sem teleporte e sem apertar E) do banco
## até o corredor e segue até a porta de Português.
## Uso: godot --headless --fixed-fps 60 --path . --script res://tests/saida_patio_test.gd

var passed := 0
var failed := 0


func _initialize() -> void:
	SaveSystem.save_path = "user://teste_saida_patio.json"
	SaveSystem.delete_save()
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var session: GameSession = get_first_node_in_group("game_session")
	await _until(func(): return session.ready_done, 600)
	await _until(func(): return session.story.cutscenes.playing, 300)
	await _until(func(): return not session.story.is_busy(), 6000)
	var p: Node3D = session.player
	var door: Door = null
	for d in get_nodes_in_group("door"):
		if String(d.door_id) == "patio.porta":
			door = d
	_check("antes do mapa a porta do pátio está trancada", door.is_locked())
	# pega o mapa no banco
	var interactor: PlayerInteractor = get_first_node_in_group("player_interactor")
	p.global_position = Vector3(-11.0, 0.05, -76.3)
	for i in 8:
		await physics_frame
	interactor.try_interact()
	await _until(func(): return session.story.cutscenes.playing, 300)
	await _until(func(): return not session.story.is_busy(), 8000)
	for i in 60:
		await physics_frame
	_check("depois do mapa a porta do pátio abriu sozinha", door.is_open() and not door.is_locked())
	_check("aviso na tela de que a porta abriu", session.story._toast.text.contains("porta do pátio se abriu"))
	# anda até o corredor só com as teclas
	await _walk("move_left", func(): return p.global_position.z >= -71.0, 300)
	await _walk("move_back", func(): return p.global_position.x >= 1.0, 400)
	_check("andando, ela chegou ao corredor (x=%.1f)" % p.global_position.x, p.global_position.x >= 1.0)
	await _walk("move_forward", func(): return p.global_position.x <= 0.0, 120)   # meio do corredor (desvia do entulho)
	await _walk("move_left", func(): return p.global_position.z >= -14.0, 60 * 30)
	_check("e seguiu pelo corredor até a porta de Português (z=%.1f)" % p.global_position.z, p.global_position.z >= -14.0)
	print("RESULTADO: %d ok, %d falhas" % [passed, failed])
	SaveSystem.delete_save()
	quit(1 if failed > 0 else 0)


func _walk(a: String, c: Callable, n: int) -> void:
	Input.action_press(a)
	var k := 0
	while not c.call() and k < n:
		await physics_frame
		k += 1
	Input.action_release(a)
	for i in 5:
		await physics_frame


func _until(c: Callable, n: int) -> void:
	var k := 0
	while not c.call() and k < n:
		await process_frame
		k += 1


func _check(label: String, ok: bool) -> void:
	if ok:
		passed += 1
		print("  ok: ", label)
	else:
		failed += 1
		print("  FALHA: ", label)
