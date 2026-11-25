@tool
class_name ModeloProp
extends Node3D
## Versão 5.4 — encaixa um modelo 3D (assets/models/*.glb) dentro da "caixa"
## de um móvel: gira (correção do arquivo), escala para o tamanho certo e põe a
## base no chão, centrada. Assim os móveis do jogo (medidas em
## tools/layout_moveis.py) trocam o visual sem mudar colisão nem pistas.

@export var modelo: PackedScene:
	set(v):
		modelo = v
		_rebuild()
## Correção de rotação do arquivo (graus).
@export var rotacao := Vector3.ZERO:
	set(v):
		rotacao = v
		_rebuild()
## Tamanho alvo (m) em x (largura), y (altura), z (profundidade).
@export var caixa := Vector3.ONE:
	set(v):
		caixa = v
		_rebuild()
## cabe: escala igual nos 3 eixos para caber na caixa · caixa: estica para
## preencher exatamente · altura: escala igual pela altura.
@export_enum("cabe", "caixa", "altura") var ajuste := 0:
	set(v):
		ajuste = v
		_rebuild()
## Onde fica o centro da base do modelo (local).
@export var base := Vector3.ZERO:
	set(v):
		base = v
		_rebuild()

var instancia: Node3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c.name == "Ajuste":
			remove_child(c)
			c.queue_free()
	instancia = null
	if modelo == null:
		return
	var ajuste_node := Node3D.new()
	ajuste_node.name = "Ajuste"
	add_child(ajuste_node)
	instancia = modelo.instantiate()
	ajuste_node.add_child(instancia)
	instancia.rotation_degrees = rotacao
	# medidas do modelo já girado, no espaço do Ajuste
	var b := _aabb(ajuste_node)
	if b.size.length() < 0.0001:
		return
	var s := Vector3.ONE
	match ajuste:
		0:
			var k := minf(minf(caixa.x / maxf(b.size.x, 0.0001), caixa.y / maxf(b.size.y, 0.0001)), caixa.z / maxf(b.size.z, 0.0001))
			s = Vector3.ONE * k
		1:
			s = Vector3(caixa.x / maxf(b.size.x, 0.0001), caixa.y / maxf(b.size.y, 0.0001), caixa.z / maxf(b.size.z, 0.0001))
		2:
			s = Vector3.ONE * (caixa.y / maxf(b.size.y, 0.0001))
	ajuste_node.scale = s
	var c := b.get_center()
	ajuste_node.position = base - Vector3(c.x * s.x, b.position.y * s.y, c.z * s.z)


func _aabb(ref: Node3D) -> AABB:
	var inv := ref.global_transform.affine_inverse()
	var out := AABB()
	var first := true
	for vi in ref.find_children("*", "VisualInstance3D", true, false):
		var v := vi as VisualInstance3D
		var a := v.get_aabb()
		if a.size.length() < 0.00001:
			continue
		# malha com esqueleto: os vértices já vêm no espaço do modelo (o nó da
		# malha pode ter uma escala que o esqueleto desfaz — ex.: a aranha)
		var w := inv * v.global_transform * a
		if v is MeshInstance3D and (v as MeshInstance3D).skin != null and instancia != null:
			w = inv * instancia.global_transform * a
		out = w if first else out.merge(w)
		first = false
	return out
