class_name LousaNotas
extends Node3D
## Versão 5.7 — a lousa de música do Maestro (enigma da melodia).
##
## Fica na frente do quadro negro da sala (o +Z local aponta para a sala).
## Sempre mostra a pauta (5 linhas em giz). Em apresentar(), cada nota aparece
## SOZINHA na pauta, na altura certa (clave de sol), com o nome e o número ao
## lado, toca o som do piano e some. No fim a lousa fica vazia: a sequência não
## pode ser consultada de novo.
##
## Separação pedida: aqui só a APRESENTAÇÃO. A memorização é do jogador e a
## validação é do PuzzleManager (pergunta "mus_teclado"); quem decide quando
## apresentar é o StoryDirector (data/story.json → "music_sequences").

signal nota_mostrada(indice: int, nome: String, numero: int)
signal apresentacao_terminada

@export var room_id := "room_5"
## Largura da pauta (m).
@export var largura := 4.4
## Centro da pauta (x local): ela fica à esquerda; o nome e o número da nota
## aparecem à direita, fora das linhas (embaixo a mesa do professor tapa).
@export var pauta_x := -1.6
## Distância entre duas linhas da pauta (m).
@export var espaco := 0.34
## Altura (local) da 1ª linha da pauta (Mi).
@export var primeira_linha := -0.3
## Onde a nota aparece na pauta (x local; o +X local é a direita de quem olha).
@export var nota_x := -1.2
@export var cor_giz := Color(0.93, 0.93, 0.88)

var apresentando := false
## Nota visível agora ({} = lousa vazia). Para os testes.
var nota_atual: Dictionary = {}

var _giz: StandardMaterial3D
var _giz_nota: StandardMaterial3D
var _nota: Node3D
var _rotulo: Label3D
var _luz: OmniLight3D
var _som: AudioStreamPlayer


func _ready() -> void:
	add_to_group("lousa_notas")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_giz = _material(0.85)
	_giz_nota = _material(1.0)
	_giz_nota.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# a pauta (fica sempre)
	var pauta := Node3D.new()
	pauta.name = "Pauta"
	add_child(pauta)
	for i in 5:
		var linha := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(largura, 0.022, 0.006)
		linha.mesh = m
		linha.material_override = _giz
		linha.position = Vector3(pauta_x, primeira_linha + i * espaco, 0.012)
		linha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pauta.add_child(linha)
	# barras do começo e do fim
	for x in [pauta_x - largura * 0.5, pauta_x + largura * 0.5]:
		var barra := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.025, espaco * 4.0 + 0.02, 0.006)
		barra.mesh = b
		barra.material_override = _giz
		barra.position = Vector3(x, primeira_linha + espaco * 2.0, 0.012)
		barra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pauta.add_child(barra)
	var clave := _label("CLAVE DE SOL", 46, Color(cor_giz, 0.75))
	clave.position = Vector3(pauta_x - largura * 0.5 + 0.75, primeira_linha + espaco * 4.0 + 0.28, 0.014)
	pauta.add_child(clave)
	# a nota (cabeça + haste + linha suplementar) e o rótulo "DÓ = 3"
	_nota = Node3D.new()
	_nota.name = "Nota"
	_nota.visible = false
	add_child(_nota)
	_rotulo = _label("", 170, cor_giz)
	_rotulo.name = "Rotulo"
	_rotulo.visible = false
	# contorno da cor da lousa: as linhas da pauta não cortam o texto
	_rotulo.outline_size = 22
	_rotulo.outline_modulate = Color(0.06, 0.1, 0.08)
	add_child(_rotulo)
	_luz = OmniLight3D.new()
	_luz.name = "Brilho"
	_luz.light_color = Color(0.75, 0.85, 1.0)
	_luz.light_energy = 0.0
	_luz.omni_range = 4.5
	_luz.shadow_enabled = false
	_luz.position = Vector3(0.3, primeira_linha + espaco * 2.0, 1.6)
	add_child(_luz)
	_som = AudioStreamPlayer.new()
	_som.name = "Piano"
	_som.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_som)


func _material(alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(cor_giz, alpha)
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = cor_giz
	m.emission_energy_multiplier = 0.35
	return m


func _label(text: String, size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return l


## Altura (local) de uma nota: meios-espaços a partir da 1ª linha (Mi = 0).
func altura_y(altura: int) -> float:
	return primeira_linha + altura * espaco * 0.5


## Mostra as notas uma de cada vez. `notas` = [{nome, numero, som, altura}].
func apresentar(notas: Array, intervalo: float = 2.4, pausa: float = 0.5) -> void:
	apresentando = true
	limpar()
	await _espera(0.4)
	for i in notas.size():
		var n: Dictionary = notas[i]
		if i > 0:
			await _espera(pausa)
		_mostrar(n)
		nota_mostrada.emit(i, String(n.get("nome", "")), int(n.get("numero", 0)))
		await _fade(0.0, 1.0, 0.22)
		await _espera(maxf(intervalo - 0.5, 0.3))
		await _fade(1.0, 0.0, 0.28)
		limpar()
	apresentando = false
	apresentacao_terminada.emit()


## Lousa vazia (só a pauta).
func limpar() -> void:
	nota_atual = {}
	_nota.visible = false
	_rotulo.visible = false
	_luz.light_energy = 0.0
	for c in _nota.get_children():
		_nota.remove_child(c)
		c.queue_free()


func _mostrar(n: Dictionary) -> void:
	limpar()
	nota_atual = n
	var alt := int(n.get("altura", 0))
	var y := altura_y(alt)
	# cabeça da nota (oval inclinado)
	var cabeca := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.5
	esf.height = 1.0
	esf.radial_segments = 20
	esf.rings = 10
	cabeca.mesh = esf
	cabeca.material_override = _giz_nota
	cabeca.scale = Vector3(espaco * 1.25, espaco * 0.85, 0.02)
	cabeca.rotation.z = deg_to_rad(-22.0)
	cabeca.position = Vector3(nota_x, y, 0.016)
	_nota.add_child(cabeca)
	# haste: para cima (à direita) até o Si; do Si para cima, para baixo (à esquerda)
	var haste := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.028, espaco * 3.4, 0.006)
	haste.mesh = hb
	haste.material_override = _giz_nota
	var para_cima := alt < 4
	var hx := nota_x + (espaco * 0.58 if para_cima else -espaco * 0.58)
	haste.position = Vector3(hx, y + (espaco * 1.7 if para_cima else -espaco * 1.7), 0.016)
	_nota.add_child(haste)
	# linhas suplementares (abaixo do Mi ou acima do Fá de cima)
	var sup: Array[int] = []
	var a := -2
	while a >= alt:
		sup.append(a)
		a -= 2
	a = 10
	while a <= alt:
		sup.append(a)
		a += 2
	for s in sup:
		var l := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(espaco * 2.1, 0.022, 0.006)
		l.mesh = lb
		l.material_override = _giz_nota
		l.position = Vector3(nota_x, altura_y(s), 0.014)
		_nota.add_child(l)
	_nota.visible = true
	# o nome e o número, à direita da pauta (sem linhas cortando o texto)
	_rotulo.text = "%s = %d" % [String(n.get("nome", "")).to_upper(), int(n.get("numero", 0))]
	_rotulo.position = Vector3(pauta_x + largura * 0.5 + 1.55, primeira_linha + espaco * 2.0, 0.02)
	_rotulo.visible = true
	_luz.position = Vector3(pauta_x + largura * 0.5, primeira_linha + espaco * 2.0, 1.6)
	# o som da nota (piano velho)
	var path := String(n.get("som", ""))
	if path != "" and ResourceLoader.exists(path):
		_som.stream = load(path)
		_som.volume_db = -3.0
		_som.play()


func _fade(de: float, para: float, tempo: float) -> void:
	var t := 0.0
	while t < tempo and is_inside_tree():
		await get_tree().process_frame
		t += _dt()
		_aplica_alpha(lerpf(de, para, clampf(t / tempo, 0.0, 1.0)))
	_aplica_alpha(para)


func _aplica_alpha(a: float) -> void:
	_giz_nota.albedo_color.a = a
	_rotulo.modulate.a = a
	_rotulo.outline_modulate.a = a
	_luz.light_energy = 0.9 * a


func _espera(s: float) -> void:
	var t := 0.0
	while t < s and is_inside_tree():
		await get_tree().process_frame
		t += _dt()


func _dt() -> float:
	var d := get_process_delta_time()
	return d if d > 0.0 else 1.0 / 60.0
