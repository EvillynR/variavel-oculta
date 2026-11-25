extends Node3D
## Lua cheia bem longe, atrás da fachada do pátio.

@export var raio := 6.0


func _ready() -> void:
	var m := DecoUtil.sphere(self, raio, Vector3.ZERO, "lua")
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(raio * 6.0, raio * 6.0)
	halo.mesh = q
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.7, 0.8, 1.0, 0.35), Color(0.5, 0.6, 0.9, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	hm.albedo_texture = gt
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
