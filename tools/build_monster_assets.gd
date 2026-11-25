extends SceneTree
## Gera a cena genérica de monstro, a configuração do Polvo e o navmesh
## da Room 1 (assado a partir da geometria real da escola).

func _initialize() -> void:
	push_error("OBSOLETO (Prompt 2): os dados agora ficam em data/game_data.json, carregado por GameData. Esta ferramenta gravava os .tres antigos (arquivados em docs/legado/legado_tres_pre_json.zip) e foi desativada para não criar um segundo banco.")
	quit(1)
	return
	DirAccess.make_dir_recursive_absolute("res://scenes/monsters")
	DirAccess.make_dir_recursive_absolute("res://data/monsters")
	DirAccess.make_dir_recursive_absolute("res://data/navigation")

	# ---------- cena genérica do monstro
	var monster := CharacterBody3D.new()
	monster.name = "Monster"
	monster.set_script(load("res://scripts/monsters/monster_controller.gd"))
	monster.collision_layer = 4   # camada 3: monstros
	monster.collision_mask = 1    # colide com o cenário e com a protagonista

	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.6
	capsule.height = 3.5
	shape.shape = capsule
	shape.position.y = 1.75
	monster.add_child(shape)

	var agent := NavigationAgent3D.new()
	agent.name = "NavigationAgent3D"
	agent.radius = 0.6
	agent.height = 3.5
	agent.path_desired_distance = 0.5
	agent.target_desired_distance = 0.6
	agent.path_max_distance = 2.0
	# O navmesh assado fica 0,5 m acima do piso (arredondamento de voxel).
	agent.path_height_offset = 0.5
	monster.add_child(agent)

	var perception := Node3D.new()
	perception.name = "Perception"
	perception.set_script(load("res://scripts/monsters/monster_perception.gd"))
	monster.add_child(perception)

	var trigger := Node.new()
	trigger.name = "Trigger"
	trigger.set_script(load("res://scripts/monsters/monster_trigger.gd"))
	monster.add_child(trigger)

	var link := RemoteTransform3D.new()
	link.name = "VisualLink"
	link.position.y = 1.75
	link.update_scale = false
	monster.add_child(link)

	for child in monster.get_children():
		child.owner = monster
	var packed := PackedScene.new()
	packed.pack(monster)
	print("monster.tscn: ", ResourceSaver.save(packed, "res://scenes/monsters/monster.tscn"))

	# ---------- configuração do Polvo
	var cfg := MonsterConfig.new()
	cfg.monster_id = &"octopus"
	cfg.display_name = "O Polvo"
	cfg.patrol_speed = 1.3
	cfg.investigate_speed = 1.6
	cfg.search_speed = 1.9
	cfg.chase_speed = 3.6
	cfg.eye_height = 2.9
	cfg.sight_distance = 12.0
	cfg.sight_fov_degrees = 120.0
	print("polvo_config.tres: ", ResourceSaver.save(cfg, "res://data/monsters/polvo_config.tres"))

	# ---------- navmesh da Room 1
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
	nav.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	# Somente a área interna da Room 1 (paredes em x = -23,5 / -3,5 e z = -7,5 / -30).
	nav.filter_baking_aabb = AABB(Vector3(-23.5, -1.0, -30.0), Vector3(20.0, 4.0, 22.5))

	# O placeholder do professor se move em jogo: não pode virar obstáculo fixo.
	var placeholder := main.get_node("School/Room 1/ProfessorPlaceholder")
	placeholder.get_parent().remove_child(placeholder)
	placeholder.free()

	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav, source, main.get_node("School"))
	NavigationServer3D.bake_from_source_geometry_data(nav, source)
	print("navmesh: vértices=%d polígonos=%d" % [nav.get_vertices().size(), nav.get_polygon_count()])
	print("room_1_navmesh.tres: ", ResourceSaver.save(nav, "res://data/navigation/room_1_navmesh.tres"))
	main.queue_free()
	await process_frame
	quit()
