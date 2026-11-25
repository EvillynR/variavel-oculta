extends SceneTree
## Caminhada roteirizada com capturas (diagnóstico de câmera).
## Uso: xvfb-run godot --path . --rendering-driver opengl3 --script res://tests/walk_capture.gd -- --out=<pasta> --route=<nome>
var out_dir := "/tmp/shots"
var route := "room1"
var main: Node
var player: CharacterBody3D
var controller: Node3D
var camera: Camera3D
const ROUTES := {
	"room1": [Vector3(0,0.05,0), Vector3(0,0.05,-10.5), Vector3(-5,0.05,-10.5), Vector3(-10,0.05,-14), Vector3(-16,0.05,-20), Vector3(-8,0.05,-26), Vector3(-5,0.05,-10.5), Vector3(0,0.05,-10.5)],
	"room2": [Vector3(0,0.05,-30), Vector3(0,0.05,-40.5), Vector3(-6,0.05,-40.5), Vector3(-13,0.05,-48), Vector3(-6,0.05,-40.5), Vector3(0,0.05,-40.5)],
	"room3": [Vector3(0,0.05,-85), Vector3(0,0.05,-95.5), Vector3(-6,0.05,-95.5), Vector3(-13,0.05,-104), Vector3(-6,0.05,-95.5), Vector3(0,0.05,-95.5)],
	"room4": [Vector3(0,0.05,-112), Vector3(0,0.05,-119.9), Vector3(-6,0.05,-119.9), Vector3(-13,0.05,-127), Vector3(-6,0.05,-119.9), Vector3(0,0.05,-119.9)],
	"fim": [Vector3(0,0.05,-125), Vector3(0,0.05,-188), Vector3(0,0.05,-196), Vector3(0,-6+0.05,-212), Vector3(0,-6+0.05,-219), Vector3(-6,-6+0.05,-219), Vector3(-12,-6+0.05,-219)],
}
var shot_every := 18
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.substr(6)
		if arg.begins_with("--route="): route = arg.substr(8)
		if arg.begins_with("--every="): shot_every = int(arg.substr(8))
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(960, 540)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	player = main.get_node("Player")
	controller = main.get_node("CameraController")
	camera = controller.get_node("Camera3D")
	await _frames(5)
	for d in get_nodes_in_group("door"):
		if d.has_method("open"): d.open(true, true)
	for m in main.find_children("*", "CharacterBody3D", true, false):
		if m != player: m.process_mode = Node.PROCESS_MODE_DISABLED
	var path: Array = ROUTES[route]
	player.set_physics_process(false)
	player.global_position = path[0]
	await _frames(2)
	controller.snap_to_target()
	RenderingServer.render_loop_enabled = false
	var speed := 3.5
	var i := 0
	var frame := 0
	var shot := 0
	var dt := 1.0 / 60.0
	while i < path.size() - 1:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var d := (b - player.global_position)
		var step := speed * dt
		if d.length() <= step:
			player.global_position = b
			i += 1
		else:
			player.velocity = d.normalized() * speed
			player.global_position += d.normalized() * step
		await physics_frame
		await process_frame
		frame += 1
		if frame % shot_every == 0:
			RenderingServer.render_loop_enabled = true
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			RenderingServer.render_loop_enabled = false
			var img := root.get_texture().get_image()
			img.save_png("%s/%s_%03d.png" % [out_dir, route, shot])
			var z: Node = controller.current_zone
			print("SHOT %s_%03d p=%s cam=%s zona=%s cortadas=%d" % [route, shot, player.global_position.snapped(Vector3.ONE*0.1), camera.global_position.snapped(Vector3.ONE*0.1), z.name if z else "-", controller._hidden_geometry.size()])
			shot += 1
	quit()
func _frames(n: int) -> void:
	for k in n: await process_frame
