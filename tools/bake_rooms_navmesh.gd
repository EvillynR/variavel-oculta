extends SceneTree
## Etapa 5, Fase 4 — assa os navmeshes das salas que TÊM geometria e ainda
## não tinham navegação (Room 2, área oeste do nó Exit, Room 3, Room 4).
## Mesmos parâmetros do navmesh da Room 1 (bake_room1_navmesh.gd).
## - Só grava arquivos em data/navigation/; nenhuma cena é salva.
## - Não toca em room_1_navmesh.tres.
## - Não sobrescreve um navmesh existente sem -- --force.
## - Música não tem geometria: não recebe navmesh.
## Uso: godot --headless --path . --script res://tools/bake_rooms_navmesh.gd

const SOURCE_GROUP := &"navmesh_rooms_source"
## arquivo, piso da sala na cena (só para conferir), limites x/z do bake
const ROOMS := [
	["room_2_navmesh", "School/Room 2/Floor", Vector2(-23.5, -3.5), Vector2(-58.5, -37.5)],
	["room_4_navmesh", "School/Room 3/Floor", Vector2(-23.5, -3.5), Vector2(-116.1, -92.5)],
	["room_5_navmesh", "School/Room 4/Floor", Vector2(-23.5, -3.5), Vector2(-137.9, -117.0)],
]


func _initialize() -> void:
	var force := "--force" in OS.get_cmdline_user_args()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	main.get_node("School").add_to_group(SOURCE_GROUP)

	for spec in ROOMS:
		var path := "res://data/navigation/%s.tres" % spec[0]
		if FileAccess.file_exists(path) and not force:
			print("mantido (já existe): ", path)
			continue
		if main.get_node_or_null(spec[1]) == null:
			push_error("piso não encontrado na cena: %s — sala sem geometria não recebe navmesh." % spec[1])
			continue
		var nav := NavigationMesh.new()
		nav.agent_radius = 0.75
		nav.agent_height = 3.5
		nav.agent_max_climb = 0.25
		nav.cell_size = 0.25
		nav.cell_height = 0.25
		nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_BOTH
		nav.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
		nav.geometry_source_group_name = SOURCE_GROUP
		var x: Vector2 = spec[2]
		var z: Vector2 = spec[3]
		nav.filter_baking_aabb = AABB(Vector3(x.x, -1.0, z.x), Vector3(x.y - x.x, 4.0, z.y - z.x))
		var source := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(nav, source, main)
		NavigationServer3D.bake_from_source_geometry_data(nav, source)
		print("%s: vértices=%d polígonos=%d -> %s" % [spec[0], nav.get_vertices().size(), nav.get_polygon_count(), ResourceSaver.save(nav, path)])

	main.queue_free()
	await process_frame
	quit()
