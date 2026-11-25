extends Node3D
## Beiral de telhado japonês (telhas escuras) no alto de uma fachada.
## Comprimento ao longo do X local; o beiral avança para o +Z local.

@export var comprimento := 20.0
@export var avanco := 1.6


func _ready() -> void:
	var slab := DecoUtil.box(self, Vector3(comprimento + 1.0, 0.25, avanco + 0.6), Vector3(0, 0, avanco * 0.5 - 0.3), "telha", Vector3(deg_to_rad(18), 0, 0))
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# telhas em fileiras (relevo)
	var n := int(comprimento / 0.45)
	for i in n:
		var x := -comprimento * 0.5 + (i + 0.5) * comprimento / n
		DecoUtil.cyl(self, 0.09, 0.09, avanco + 0.5, Vector3(x, 0.14, avanco * 0.5 - 0.3), "telha", Vector3(deg_to_rad(18) + PI * 0.5, 0, 0), 6)
	# viga de madeira embaixo
	DecoUtil.box(self, Vector3(comprimento, 0.35, 0.3), Vector3(0, -0.45, 0.1), "madeira_escura")
	DecoUtil.merge(self)
