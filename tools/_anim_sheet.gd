extends SceneTree
func _initialize():
	root.size = Vector2i(320, 400)
	var env := WorldEnvironment.new()
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.25,0.25,0.3); e.ambient_light_color = Color(0.6,0.6,0.6); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 30, 0); root.add_child(sun)
	var scn = load("res://assets/characters/yuko/YukoRig.glb").instantiate()
	root.add_child(scn)
	var ap: AnimationPlayer = scn.get_node("AnimationPlayer")
	var cam := Camera3D.new(); root.add_child(cam); cam.current = true; cam.fov = 40
	var out := OS.get_cmdline_user_args()[0]
	for name in ap.get_animation_list():
		var a := ap.get_animation(name)
		for view in ["lado", "frente"]:
			if view == "lado":
				cam.look_at_from_position(Vector3(4.0, 0.9, 0), Vector3(0, 0.85, 0))
			else:
				cam.look_at_from_position(Vector3(0, 0.9, 4.0), Vector3(0, 0.85, 0))
			for i in 6:
				ap.play(name); ap.seek(a.length * i / 6.0, true); ap.pause()
				for k in 2: await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("%s/%s_%s_%d.png" % [out, name, view, i])
	quit()
