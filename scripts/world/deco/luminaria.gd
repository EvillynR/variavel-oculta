extends Node3D
## Luminária pendente (cúpula de vidro leitoso), como no corredor de referência.
## O nó fica no teto; a luz de verdade continua sendo o SpotLight do corredor.

@export var fio := 1.2
@export var acesa := true


func _ready() -> void:
	DecoUtil.cyl(self, 0.012, 0.012, fio, Vector3(0, -fio * 0.5, 0), "metal", Vector3.ZERO, 6)
	DecoUtil.cyl(self, 0.06, 0.06, 0.12, Vector3(0, -fio - 0.02, 0), "metal", Vector3.ZERO, 8)
	var shade := DecoUtil.sphere(self, 0.38, Vector3(0, -fio - 0.2, 0), "cupula" if acesa else "tecido", 0.55)
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	DecoUtil.merge(self)
