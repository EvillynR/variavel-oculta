extends MeshInstance3D
## Marcador de pista preso a um móvel: fica tão transparente quanto o móvel
## e some junto quando a câmera corta o móvel.
## Sem isto, quando a câmera deixa o móvel translúcido (ele fica na frente da
## Yuko) o papel/livro em cima dele parecia flutuar sozinho.

@export var follow: NodePath
var _src: GeometryInstance3D
var _own_layers := 1
## Camada usada pela câmera para "cortar" o que fica na frente da sala
## (CameraController.CUT_LAYER).
const CUT_LAYER := 1 << 19


func _ready() -> void:
	_own_layers = layers
	var n := get_node_or_null(follow)
	if n is GeometryInstance3D and n.is_in_group("camera_fade"):
		_src = n
	elif n != null:
		for c in n.find_children("*", "GeometryInstance3D", true, false):
			if c.is_in_group("camera_fade"):
				_src = c
				break


func _process(_delta: float) -> void:
	if _src != null and is_instance_valid(_src):
		transparency = _src.transparency
		# Móvel cortado pela câmera (fica entre a lente e a sala): o objeto
		# em cima dele some junto, senão parece flutuar no alto da tela.
		layers = CUT_LAYER if _src.layers == CUT_LAYER or not _src.is_visible_in_tree() else _own_layers
