class_name TecladoPorta
extends StaticBody3D
## Versão 5.7 — teclado numérico ao lado da porta (enigma da melodia da Música).
##
## Só a parte visível: um pedestal de ferro com 12 teclas, um visor e uma luz
## (vermelha = trancado, verde = aberto). A digitação acontece no painel do
## enigma (PuzzleUI, mesmo sistema de todas as salas) e aparece aqui no visor;
## quem valida é o PuzzleManager. O ponto de interação é o "room_5.teclado"
## (Gameplay/Musica/Teclado), gerado por tools/build_story.py.

@export var puzzle_id: StringName = &"mus_teclado"
@export var altura_painel := 1.25

var texto := ""
var _visor: Label3D
var _led_mat: StandardMaterial3D
var _flash := 0.0
var _resolvido := false
var _tamanho := 4

const VERMELHO := Color(1.0, 0.16, 0.12)
const VERDE := Color(0.25, 1.0, 0.45)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("teclado_porta")
	_build()
	_connect.call_deferred()


func _connect() -> void:
	var ui := get_tree().get_first_node_in_group("puzzle_ui")
	if ui != null and ui.has_signal("entrada_mudou"):
		ui.entrada_mudou.connect(_on_entrada)
	var pm := get_tree().get_first_node_in_group("puzzle_manager")
	if pm != null:
		pm.answer_submitted.connect(_on_answer)
		if pm.has_method("is_solved") and pm.is_solved(puzzle_id):
			_set_resolvido()
		var p: PuzzleData = pm.database.get_puzzle(puzzle_id) if pm.database != null else null
		if p != null and p.correct_answer.length() > 0:
			_tamanho = p.correct_answer.length()
	_mostra()


func _build() -> void:
	var ferro := StandardMaterial3D.new()
	ferro.albedo_color = Color(0.16, 0.15, 0.14)
	ferro.metallic = 0.7
	ferro.roughness = 0.55
	var latao := StandardMaterial3D.new()
	latao.albedo_color = Color(0.55, 0.45, 0.25)
	latao.metallic = 0.8
	latao.roughness = 0.45
	var tecla := StandardMaterial3D.new()
	tecla.albedo_color = Color(0.82, 0.78, 0.68)
	tecla.roughness = 0.8
	# pé e haste
	_mesh(_box(Vector3(0.5, 0.06, 0.4)), ferro, Vector3(0, 0.03, 0))
	_mesh(_box(Vector3(0.1, altura_painel - 0.2, 0.1)), ferro, Vector3(0, (altura_painel - 0.2) * 0.5 + 0.06, 0))
	# o painel, inclinado para quem está na frente (+Z)
	var painel := Node3D.new()
	painel.name = "Painel"
	painel.position = Vector3(0, altura_painel, 0)
	painel.rotation.x = deg_to_rad(-28.0)
	add_child(painel)
	_mesh(_box(Vector3(0.44, 0.6, 0.07)), latao, Vector3.ZERO, painel)
	_mesh(_box(Vector3(0.38, 0.12, 0.02)), _escuro(), Vector3(0, 0.2, 0.04), painel)
	_visor = Label3D.new()
	_visor.name = "Visor"
	_visor.font_size = 64
	_visor.pixel_size = 0.0022
	_visor.position = Vector3(0, 0.2, 0.052)
	_visor.modulate = VERMELHO
	_visor.outline_size = 0
	_visor.shaded = false
	painel.add_child(_visor)
	var keys := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0", "OK"]
	for i in keys.size():
		var col := i % 3
		var row := i / 3
		var pos := Vector3(-0.12 + col * 0.12, 0.06 - row * 0.09, 0.045)
		_mesh(_box(Vector3(0.095, 0.07, 0.025)), tecla, pos, painel)
		var l := Label3D.new()
		l.text = keys[i]
		l.font_size = 40 if keys[i].length() == 1 else 26
		l.pixel_size = 0.0018
		l.modulate = Color(0.12, 0.1, 0.08)
		l.outline_size = 0
		l.position = pos + Vector3(0, 0, 0.014)
		painel.add_child(l)
	# a luz (vermelha/verde) em cima do painel
	_led_mat = StandardMaterial3D.new()
	_led_mat.albedo_color = VERMELHO
	_led_mat.emission_enabled = true
	_led_mat.emission = VERMELHO
	_led_mat.emission_energy_multiplier = 2.5
	var esf := SphereMesh.new()
	esf.radius = 0.03
	esf.height = 0.06
	_mesh(esf, _led_mat, Vector3(0.17, 0.27, 0.04), painel)
	# colisão do pedestal (ela não atravessa)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, altura_painel + 0.3, 0.45)
	cs.shape = shape
	cs.position = Vector3(0, (altura_painel + 0.3) * 0.5, 0)
	add_child(cs)


func _escuro() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.04, 0.03)
	m.roughness = 0.3
	return m


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _mesh(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _on_entrada(pid: StringName, t: String) -> void:
	if pid != puzzle_id or _resolvido:
		return
	texto = t
	_mostra()


func _on_answer(puzzle: PuzzleData, correct: bool) -> void:
	if puzzle == null or puzzle.id != puzzle_id:
		return
	if correct:
		_set_resolvido()
	else:
		_flash = 1.2
		_visor.text = "ERRO"
		_visor.modulate = VERMELHO


func _set_resolvido() -> void:
	_resolvido = true
	texto = ""
	_visor.text = "ABERTO"
	_visor.modulate = VERDE
	_led_mat.albedo_color = VERDE
	_led_mat.emission = VERDE


func _mostra() -> void:
	if _resolvido or _visor == null:
		return
	var s := ""
	for i in _tamanho:
		s += (texto[i] if i < texto.length() else "_") + (" " if i < _tamanho - 1 else "")
	_visor.text = s
	_visor.modulate = VERMELHO.lerp(Color(1, 0.75, 0.3), 0.6)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta if delta > 0.0 else 1.0 / 60.0
		_led_mat.emission_energy_multiplier = 2.5 + 4.0 * absf(sin(_flash * 18.0))
		if _flash <= 0.0:
			_led_mat.emission_energy_multiplier = 2.5
			texto = ""
			_mostra()
