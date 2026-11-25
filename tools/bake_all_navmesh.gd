extends SceneTree
## Prompt 1 — assa TODOS os navmeshes (4 salas desde a versão da história de Yuko) depois das mudanças de estrutura:
## as seis salas, o subsolo/Sala de Monitoramento e os corredores.
## Mesmos parâmetros do navmesh original da Room 1 (agente 0,75 m × 3,5 m).
## As portas entram no bake FECHADAS (folhas = obstáculos); com a porta aberta
## a passagem é feita pelo NavigationLink3D de cada porta.
## - Só grava arquivos em data/navigation/; nenhuma cena é salva.
## - Não sobrescreve um navmesh existente sem -- --force.
## Uso: godot --headless --path . --script res://tools/bake_all_navmesh.gd -- --force

const SOURCE_GROUP := &"navmesh_all_source"
## arquivo, piso de conferência, limites x, y, z do bake
const AREAS := [
	["room_1_navmesh", "School/Room 1/Floor", Vector2(-23.5, -3.5), Vector2(-1.0, 3.0), Vector2(-29.9, -7.5)],
	["room_2_navmesh", "School/Room 2/Floor", Vector2(-23.5, -3.5), Vector2(-1.0, 3.0), Vector2(-58.5, -37.5)],
	["room_4_navmesh", "School/Room 3/Floor", Vector2(-23.5, -3.5), Vector2(-1.0, 3.0), Vector2(-116.1, -92.5)],
	["room_5_navmesh", "School/Room 4/Floor", Vector2(-23.5, -3.5), Vector2(-1.0, 3.0), Vector2(-137.9, -117.0)],
	["corridors_navmesh", "School/Corridor/Floor", Vector2(-3.5, 3.5), Vector2(-1.0, 3.0), Vector2(-190.0, -3.95)],
	["initial_navmesh", "School/SalaMonitores/Floor", Vector2(-6.0, 6.0), Vector2(-1.0, 3.0), Vector2(-198.0, -190.0)],
	["music_room_navmesh", "School/MusicRoom/MusicFloor", Vector2(-23.5, -3.5), Vector2(-1.0, 3.0), Vector2(-185.0, -165.0)],
]


func _initialize() -> void:
	var force := "--force" in OS.get_cmdline_user_args()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await physics_frame
	main.get_node("School").add_to_group(SOURCE_GROUP)
	# Móveis e objetos de jogo com corpo estático ficam fora de School
	# (ex.: o armário da Room 1 em Room1Gameplay).
	for extra in []:
		if main.has_node(extra):
			main.get_node(extra).add_to_group(SOURCE_GROUP)

	for spec in AREAS:
		var path := "res://data/navigation/%s.tres" % spec[0]
		if FileAccess.file_exists(path) and not force:
			print("mantido (já existe): ", path)
			continue
		if main.get_node_or_null(spec[1]) == null:
			push_error("piso não encontrado na cena: %s" % spec[1])
			continue
		var nav := NavigationMesh.new()
		nav.agent_radius = 0.75
		nav.agent_height = 3.5
		nav.agent_max_climb = 0.25
		nav.agent_max_slope = 30.0
		nav.cell_size = 0.25
		nav.cell_height = 0.25
		# Só colisores estáticos: malhas visuais sem colisão (ex.: o boneco provisório
		# do professor) não podem virar obstáculo.
		nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
		nav.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
		nav.geometry_source_group_name = SOURCE_GROUP
		var x: Vector2 = spec[2]
		var y: Vector2 = spec[3]
		var z: Vector2 = spec[4]
		nav.filter_baking_aabb = AABB(Vector3(x.x, y.x, z.x), Vector3(x.y - x.x, y.y - y.x, z.y - z.x))
		var source := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(nav, source, main)
		NavigationServer3D.bake_from_source_geometry_data(nav, source)
		print("%s: vértices=%d polígonos=%d -> %s" % [spec[0], nav.get_vertices().size(), nav.get_polygon_count(), error_string(ResourceSaver.save(nav, path))])

	main.queue_free()
	await process_frame
	quit()
