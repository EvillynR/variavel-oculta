extends Node3D
## Banco de madeira do pátio (escala Little Nightmares: o assento fica na
## altura do peito da Yuko). O mapa aparece em cima dele.

@export var comprimento := 4.2
@export var altura_assento := 1.35


func _ready() -> void:
	var h := altura_assento
	DecoUtil.box(self, Vector3(comprimento, 0.14, 1.1), Vector3(0, h, 0), "madeira")
	DecoUtil.box(self, Vector3(comprimento, 0.7, 0.12), Vector3(0, h + 0.55, -0.5), "madeira", Vector3(-0.12, 0, 0))
	for x in [-comprimento * 0.42, comprimento * 0.42]:
		DecoUtil.box(self, Vector3(0.14, h, 0.9), Vector3(x, h * 0.5, 0), "madeira_escura")
	DecoUtil.solid(self, Vector3(comprimento, h + 0.2, 1.1), Vector3(0, (h + 0.2) * 0.5, 0))
	DecoUtil.merge(self)
