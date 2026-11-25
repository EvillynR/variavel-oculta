extends Node3D
## Cerejeira (sakura) do pátio: tronco torto, galhos, copa rosada, pétalas no
## chão e algumas caindo devagar.

@export var semente := 7
@export var altura := 6.5
@export var raio_petalas := 7.0
@export var petalas_chao := 380


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var tilt := Vector3(0, 0, deg_to_rad(6))
	var trunk := DecoUtil.cyl(self, 0.32, 0.55, altura, Vector3(0, altura * 0.5, 0), "casca", tilt, 10)
	# o tronco também fica translúcido se ficar entre a câmera e a Yuko
	trunk.add_to_group("camera_fade")
	var body := DecoUtil.solid(trunk, Vector3(1.0, altura, 1.0), Vector3.ZERO)
	body.rotation = -tilt
	var crown := Vector3(-altura * sin(deg_to_rad(6)), altura, 0)
	var tips: Array[Vector3] = []
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf_range(-0.3, 0.3)
		var length := rng.randf_range(2.4, 3.6)
		var dir := Vector3(cos(a), rng.randf_range(0.35, 0.8), sin(a)).normalized()
		var mid := crown + dir * length * 0.5 - Vector3(0, 0.6, 0)
		var branch := DecoUtil.cyl(self, 0.07, 0.18, length, mid, "casca", Vector3.ZERO, 6)
		branch.look_at_from_position(mid, mid + dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
		branch.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
		tips.append(crown + dir * length - Vector3(0, 0.6, 0))
	# copa (versão 5.6): tufos de flores — folhas cruzadas com textura de
	# flores gerada aqui (de perto lê como sakura, não como bolas) e um miolo
	# escuro de poucas esferas para dar volume.
	var centers: Array[Vector3] = []
	for tip in tips:
		for j in 26:
			centers.append(tip + Vector3(rng.randf_range(-1.7, 1.7), rng.randf_range(-0.7, 1.0), rng.randf_range(-1.7, 1.7)))
	for j in 26:
		centers.append(crown + Vector3(rng.randf_range(-1.9, 1.9), rng.randf_range(0.0, 1.6), rng.randf_range(-1.9, 1.9)))
	var copa := _flower_clusters(rng, centers)
	copa.add_to_group("camera_fade")
	add_child(copa)
	for j in 12:
		var tip2: Vector3 = tips[j % tips.size()]
		var miolo := DecoUtil.sphere(self, rng.randf_range(0.6, 0.95), (tip2 + crown) * 0.5 + Vector3(rng.randf_range(-0.6, 0.6), 0.2, rng.randf_range(-0.6, 0.6)), "sakura_miolo", 0.7)
		miolo.add_to_group("camera_fade")
	_petals_on_ground(rng)
	_falling_petals()
	DecoUtil.merge(self)

func _petals_on_ground(rng: RandomNumberGenerator) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.07)
	mm.mesh = q
	mm.instance_count = petalas_chao
	for i in petalas_chao:
		var r := sqrt(rng.randf()) * raio_petalas
		var a := rng.randf() * TAU
		var b := Basis(Vector3.RIGHT, -PI * 0.5).rotated(Vector3.UP, rng.randf() * TAU)
		mm.set_instance_transform(i, Transform3D(b, Vector3(cos(a) * r, 0.015, sin(a) * r)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = DecoUtil.mat("petala")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _falling_petals() -> void:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 9.0
	p.preprocess = 9.0
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.07)
	q.material = DecoUtil.mat("petala")
	p.mesh = q
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(3.5, 0.5, 3.5)
	p.position = Vector3(0, altura + 1.0, 0)
	p.direction = Vector3(1, -0.2, 0.3)
	p.spread = 40.0
	p.gravity = Vector3(0.15, -0.45, 0.05)
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.3
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.particle_flag_align_y = false
	add_child(p)


static var _flower_mat: StandardMaterial3D


## Uma malha só com ~200 tufos (3 folhas cruzadas cada) e textura de flores.
func _flower_clusters(rng: RandomNumberGenerator, centers: Array[Vector3]) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in centers:
		var size := rng.randf_range(1.1, 1.9)
		var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		for axis in 3:
			var u: Vector3 = basis[(axis + 1) % 3] * size * 0.5
			var v: Vector3 = basis[(axis + 2) % 3] * size * 0.5
			var n: Vector3 = basis[axis]
			var p0 := c - u - v
			var p1 := c + u - v
			var p2 := c + u + v
			var p3 := c - u + v
			for tri in [[p0, Vector2(0, 1), p1, Vector2(1, 1), p2, Vector2(1, 0)], [p0, Vector2(0, 1), p2, Vector2(1, 0), p3, Vector2(0, 0)]]:
				for k in 3:
					st.set_normal(n)
					st.set_uv(tri[k * 2 + 1])
					st.add_vertex(tri[k * 2])
	var mi := MeshInstance3D.new()
	mi.name = "Copa"
	mi.mesh = st.commit()
	mi.material_override = _flowers()
	return mi


static func _flowers() -> StandardMaterial3D:
	if _flower_mat != null:
		return _flower_mat
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in 520:
		# mais flores no meio do tufo, poucas na borda
		var r := sqrt(rng.randf()) * 118.0
		var a := rng.randf() * TAU
		var cx := 128.0 + cos(a) * r
		var cy := 128.0 + sin(a) * r
		var rad := rng.randf_range(3.0, 8.0)
		var tone := rng.randf()
		var col := Color(0.93, 0.66, 0.76).lerp(Color(0.62, 0.32, 0.46), tone * 0.8)
		if rng.randf() < 0.12:
			col = Color(0.98, 0.86, 0.9)   # flor mais clara
		for y in range(int(cy - rad), int(cy + rad) + 1):
			for x in range(int(cx - rad), int(cx + rad) + 1):
				if x < 0 or y < 0 or x > 255 or y > 255:
					continue
				var d := Vector2(x - cx, y - cy).length() / rad
				if d <= 1.0:
					# 5 pétalas: borda recortada
					var ang := atan2(y - cy, x - cx)
					var petal := 0.78 + 0.22 * cos(ang * 5.0)
					if d <= petal:
						var c := col.darkened(0.25 * d)
						c.a = 1.0
						img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.albedo_color = Color(0.86, 0.74, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission_texture = m.albedo_texture
	m.emission = Color(0.5, 0.32, 0.42)
	m.emission_energy_multiplier = 0.22
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_flower_mat = m
	return m
