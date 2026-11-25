extends SceneTree
## Captura só do mapa (rápida): escritos de exemplo, salas concluídas e saída.
## Uso: xvfb-run godot --path . --rendering-driver vulkan --script res://tests/mapa_captura.gd -- --out=<pasta>

func _initialize() -> void:
	var out := "user://"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	root.size = Vector2i(1280, 720)
	var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
	var map := MapUI.new()
	map.areas = story.map.areas
	map.targets = story.map.targets
	root.add_child(map)
	await process_frame
	map.set_obtained(true)
	var flow: Dictionary = story.room_flow
	for t in ["NÃO FAÇA BARULHO.\nELES AINDA NÃO SABEM QUE VOCÊ ACORDOU.", "AS PORTAS SÓ ABREM NA ORDEM DO MAPA.", "EM CADA SALA HÁ UMA PERGUNTA.\nEM DUAS DELAS HÁ ALGUÉM.", "SE OUVIR PASSOS, ESCONDA-SE.\nEU VOU TE AJUDAR A SAIR DAÍ."]:
		map.notes.append({"area": "patio", "text": t})
	for k in ["enter", "awake", "calm", "open", "done"]:
		map.notes.append({"area": "room_1", "text": flow.room_1.notes[k]})
	for k in ["enter", "open"]:
		map.notes.append({"area": "room_2", "text": flow.room_2.notes[k]})
	map.open()
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/mapa_a.png")
	map.reveal("saida")
	map.notes.append({"area": "sala_saida", "text": "OS TESTES ACABARAM, PARTICIPANTE 07.\nAGORA COMEÇA A PARTE INTERESSANTE."})
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/mapa_b.png")
	quit()
