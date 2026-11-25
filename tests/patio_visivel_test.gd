extends SceneTree
## Versão 5.6 — "cadê a cerejeira, as janelas e os elementos visuais".
## O pátio "dorme" longe da Yuko (desempenho), mas tem que estar acordado em
## qualquer cena que o mostre — inclusive com o jogo pausado (cenas de filme).
## Uso: godot --headless --fixed-fps 60 --path . --script res://tests/patio_visivel_test.gd

var passed := 0
var failed := 0


func _initialize() -> void:
	SaveSystem.save_path = "user://teste_patio_visivel.json"
	SaveSystem.delete_save()
	SaveSystem.pending_action = "new"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var director = null
	for i in 10:
		await process_frame
	director = get_first_node_in_group("story_director")
	var n := 0
	while not director.cutscenes.playing and n < 300:
		await process_frame
		n += 1
	for i in 120:
		await process_frame
	var patio := main.get_node("School/Patio")
	_check("abertura tocando com o jogo pausado", director.cutscenes.playing and paused)
	for nm in ["Cerejeira", "ToroNorte", "ToroSul", "Lua", "Banco", "Entulho", "JanelaOesteT0", "JanelaNorteA0", "TelhadoNorte", "Luar"]:
		var nd := patio.get_node_or_null(nm) as Node3D
		_check("na abertura: %s visível" % nm, nd != null and nd.is_visible_in_tree())
	var copa := patio.get_node("Cerejeira").find_child("Copa", true, false) as MeshInstance3D
	_check("a copa da cerejeira tem flores (malha de tufos)", copa != null and copa.mesh != null and copa.mesh.get_faces().size() > 300)
	_check("névoa do pátio ligada na abertura", main.get_node("WorldEnvironment").environment.volumetric_fog_enabled)
	# a Yuko longe (Música): o pátio dorme e a névoa desliga
	while director.is_busy() and n < 8000:
		await process_frame
		n += 1
	main.get_node("Player").global_position = Vector3(-8, 0.05, -175)
	for i in 60:
		await process_frame
	_check("longe do pátio: enfeites dormindo", not patio.get_node("Cerejeira").visible)
	_check("longe do pátio: névoa desligada", not main.get_node("WorldEnvironment").environment.volumetric_fog_enabled)
	_check("longe do pátio: paredes e chão continuam (colisão)", patio.get_node("Piso").visible and patio.get_node("ParedeOeste_Lower").visible)
	main.get_node("Player").global_position = Vector3(-12, 0.05, -70)
	for i in 60:
		await process_frame
	_check("de volta ao pátio: tudo visível de novo", patio.get_node("Cerejeira").visible and patio.get_node("JanelaOesteT0").visible)
	print("RESULTADO: %d ok, %d falhas" % [passed, failed])
	SaveSystem.delete_save()
	quit(1 if failed > 0 else 0)


func _check(label: String, ok: bool) -> void:
	if ok:
		passed += 1
		print("  ok: ", label)
	else:
		failed += 1
		print("  FALHA: ", label)
