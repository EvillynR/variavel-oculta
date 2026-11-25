extends Node
## Versão 5.4 — relógio de parede da Sala de Matemática: os ponteiros andam com
## a hora real do computador (o modelo traz os ponteiros soltos, com o eixo no
## centro do mostrador). Nos ponteiros: o mais longo é o dos segundos.

var _hands: Array = []   # [nó, rotação inicial, tipo]


func _ready() -> void:
	await get_tree().process_frame
	var list := []
	for n in get_parent().find_children("Ponteiro_*", "Node3D", true, false):
		var mi := n as Node3D
		var len := 0.0
		if mi is MeshInstance3D and (mi as MeshInstance3D).mesh:
			var a: AABB = (mi as MeshInstance3D).mesh.get_aabb()
			len = maxf(a.size.x, a.size.y)
		list.append([mi, len])
	list.sort_custom(func(a, b): return a[1] > b[1])
	var kinds := ["s", "m", "h"]
	for i in list.size():
		if i < 3 and list[i][1] > 0.01:
			_hands.append([list[i][0], (list[i][0] as Node3D).rotation, kinds[i]])


func _process(_delta: float) -> void:
	var t := Time.get_time_dict_from_system()
	var sec := float(t.second)
	var mins := float(t.minute) + sec / 60.0
	var hrs := fmod(float(t.hour), 12.0) + mins / 60.0
	for h in _hands:
		var frac := sec / 60.0 if h[2] == "s" else (mins / 60.0 if h[2] == "m" else hrs / 12.0)
		var n: Node3D = h[0]
		n.rotation = h[1]
		# o mostrador olha para +Z do modelo: sentido horário visto de frente
		n.rotate_object_local(Vector3(0, 0, 1), -frac * TAU)
