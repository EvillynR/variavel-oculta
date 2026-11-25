extends SceneTree
## Assa somente o navmesh da Room 1 (Etapa 4.5), sem recriar a cena do
## monstro nem a configuração do Polvo (diferente de build_monster_assets.gd).
## Inclui a geometria da escola e os corpos estáticos dos móveis interativos
## (ex.: armário), para que a rota do monstro desvie deles.
## Uso: godot --headless --path . --script res://tools/bake_room1_navmesh.gd

const SOURCE_GROUP := &"navmesh_room1_source"


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var nav := NavigationMesh.new()
	nav.agent_radius = 0.75
	nav.agent_height = 3.5
	nav.agent_max_climb = 0.25
	nav.cell_size = 0.25
	nav.cell_height = 0.25
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_BOTH
	nav.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav.geometry_source_group_name = SOURCE_GROUP
	nav.filter_baking_aabb = AABB(Vector3(-23.5, -1.0, -30.0), Vector3(20.0, 4.0, 22.5))

	# O placeholder do professor se move em jogo: não pode virar obstáculo fixo.
	var placeholder := main.get_node("School/Room 1/ProfessorPlaceholder")
	placeholder.get_parent().remove_child(placeholder)
	placeholder.free()

	main.get_node("School").add_to_group(SOURCE_GROUP)
	for body in main.get_node("Room1Gameplay/Interactables").find_children("*", "StaticBody3D", true, false):
		body.add_to_group(SOURCE_GROUP)
		print("obstáculo incluído: ", main.get_path_to(body))

	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav, source, main)
	NavigationServer3D.bake_from_source_geometry_data(nav, source)
	print("navmesh: vértices=%d polígonos=%d" % [nav.get_vertices().size(), nav.get_polygon_count()])
	print("room_1_navmesh.tres: ", ResourceSaver.save(nav, "res://data/navigation/room_1_navmesh.tres"))
	main.queue_free()
	await process_frame
	quit()
