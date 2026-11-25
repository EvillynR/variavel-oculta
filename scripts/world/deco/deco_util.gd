class_name DecoUtil
extends RefCounted
## Peças de cenário montadas em código (escola japonesa, versão 5).
## Assim a cena guarda só a posição de cada peça e o visual fica num lugar só.

static var _mats := {}
const WOOD := "res://assets/textures/walls/lower_wood/weathered_planks_diff_2k.jpg"


static func mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"madeira_escura":
			# versão 5.6: madeira gasta de verdade (mesma textura das paredes)
			m.albedo_texture = load(WOOD)
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.7, 0.7, 0.7)
			m.albedo_color = Color(0.3, 0.22, 0.16)
			m.roughness = 0.8
		"madeira":
			m.albedo_texture = load(WOOD)
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.7, 0.7, 0.7)
			m.albedo_color = Color(0.55, 0.4, 0.3)
			m.roughness = 0.85
		"vidro_lua":
			m.albedo_color = Color(0.04, 0.06, 0.1)
			m.roughness = 0.15
			m.emission_enabled = true
			m.emission = Color(0.32, 0.46, 0.72)
			m.emission_energy_multiplier = 0.55
		"vidro_escuro":
			m.albedo_color = Color(0.03, 0.04, 0.06)
			m.roughness = 0.1
			m.metallic = 0.3
		"vidro_quente":
			m.albedo_color = Color(0.2, 0.12, 0.05)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.62, 0.3)
			m.emission_energy_multiplier = 1.3
		"casca":
			m.albedo_color = Color(0.16, 0.11, 0.09)
			m.roughness = 0.95
		"sakura":
			m.albedo_color = Color(0.62, 0.36, 0.45)
			m.roughness = 1.0
			m.emission_enabled = true
			m.emission = Color(0.6, 0.3, 0.4)
			m.emission_energy_multiplier = 0.05
		"sakura_miolo":
			m.albedo_color = Color(0.36, 0.2, 0.27)
			m.roughness = 1.0
		"petala":
			m.albedo_color = Color(0.9, 0.6, 0.7)
			m.roughness = 0.9
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.emission_enabled = true
			m.emission = Color(0.8, 0.5, 0.6)
			m.emission_energy_multiplier = 0.1
		"pedra":
			m.albedo_color = Color(0.36, 0.36, 0.34)
			m.roughness = 0.95
		"telha":
			m.albedo_color = Color(0.1, 0.11, 0.13)
			m.roughness = 0.55
		"cupula":
			m.albedo_color = Color(0.85, 0.78, 0.66)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.86, 0.62)
			m.emission_energy_multiplier = 1.1
		"metal":
			m.albedo_color = Color(0.14, 0.15, 0.16)
			m.metallic = 0.6
			m.roughness = 0.5
		"poca":
			# poça rasa: deixa ver o chão e brilha um pouco com o luar
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.32, 0.38, 0.52, 0.45)
			m.roughness = 0.04
			m.metallic = 0.4
			m.metallic_specular = 1.0
		"lua":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.86, 0.9, 1.0)
		"lampiao":
			m.albedo_color = Color(0.3, 0.2, 0.1)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.65, 0.3)
			m.emission_energy_multiplier = 1.6
		"tecido":
			m.albedo_color = Color(0.32, 0.3, 0.27)
			m.roughness = 0.95
		_:
			m.albedo_color = Color(0.5, 0.5, 0.5)
	_mats[key] = m
	return m


static func box(parent: Node3D, size: Vector3, pos: Vector3, material: String, rot := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(material)
	mi.position = pos
	mi.rotation = rot
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func cyl(parent: Node3D, top: float, bottom: float, height: float, pos: Vector3, material: String, rot := Vector3.ZERO, seg := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = height
	cm.radial_segments = seg
	mi.mesh = cm
	mi.material_override = mat(material)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func sphere(parent: Node3D, radius: float, pos: Vector3, material: String, squash := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0 * squash
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = mat(material)
	mi.position = pos
	parent.add_child(mi)
	return mi


## Corpo físico simples (a Yuko e o monstro não atravessam).
static func solid(parent: Node3D, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.add_to_group("prop_body")
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.position = pos
	body.rotation = rot
	body.add_child(cs)
	parent.add_child(body)
	return body


## Versão 5.4 (desempenho): junta as peças de um enfeite em UMA malha por
## material (antes cada tábua, vidro e telha era desenhada separadamente — o
## corredor chegava a ~600 desenhos por quadro e o jogo perdia fluidez).
## Peças com filhos (ex.: o tronco que segura a colisão) ficam como estão.
## Peças no grupo camera_fade continuam somindo com a câmera (malha própria).
static func merge(root: Node3D) -> void:
	var groups := {}   # chave -> [material, fade, [MeshInstance3D]]
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.get_child_count() > 0 or m.skeleton != NodePath(""):
			continue
		# só as peças de código (material único por override); modelos 3D ficam
		if m.material_override == null:
			continue
		if m.mesh.get_surface_count() != 1:
			continue
		var fade := m.is_in_group("camera_fade")
		var key := "%d|%s" % [m.material_override.get_instance_id() if m.material_override else 0, fade]
		if not groups.has(key):
			groups[key] = [m.material_override, fade, []]
		groups[key][2].append(m)
	var inv := root.global_transform.affine_inverse()
	var n := 0
	for key in groups:
		var list: Array = groups[key][2]
		if list.size() < 2:
			continue
		var st := SurfaceTool.new()
		for m in list:
			st.append_from(m.mesh, 0, inv * (m as MeshInstance3D).global_transform)
		var merged := MeshInstance3D.new()
		merged.name = "Junto%d" % n
		n += 1
		merged.mesh = st.commit()
		merged.material_override = groups[key][0]
		if groups[key][1]:
			merged.add_to_group("camera_fade")
		root.add_child(merged)
		for m in list:
			m.get_parent().remove_child(m)
			m.queue_free()
