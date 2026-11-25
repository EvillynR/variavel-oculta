class_name MapUI
extends CanvasLayer
## O mapa que Yuko encontra na sala onde acorda (tecla M).
##
## Visual (pedido da equipe, inspirado em mapa ilustrado de tabuleiro):
## pergaminho com bordas queimadas e manchas, moldura dupla vermelha, rosa dos
## ventos, cartela de título, salas desenhadas a nanquim com ícones de cada
## matéria e selos numerados.
##
## Ele também é a "voz": tudo o que antes era dito pelo telefone aparece
## ESCRITO no mapa, numa letra que não é da Yuko (write_note). Com o mapa
## fechado, o escrito surge num pedaço de pergaminho no alto da tela.
##
## - Só existe depois da cena do mapa (map_obtained).
## - Mostra onde ela está, o próximo objetivo (círculo vermelho) e as salas
##   concluídas (riscadas).
## - A saída só aparece depois de Geografia (reveal("saida")).
## A planta (retângulos em metros) vem de data/story.json → "map".

signal note_written(area: String, text: String)

const FONT_HAND := preload("res://assets/fonts/Caveat-SemiBold.ttf")
const FONT_TITLE := preload("res://assets/fonts/IMFellEnglish-Regular.ttf")
const FONT_TITLE_IT := preload("res://assets/fonts/IMFellEnglish-Italic.ttf")

const PAPER := Color(0.87, 0.79, 0.61)
const PAPER_DARK := Color(0.74, 0.63, 0.43)
const BURN := Color(0.33, 0.2, 0.09)
const INK := Color(0.2, 0.13, 0.08)
const RED := Color(0.62, 0.1, 0.07)
const NOTE_INK := Color(0.42, 0.04, 0.03)
const ROOM_FILL := Color(0.8, 0.71, 0.52)

## Colunas de escritos na ordem em que os lugares aparecem no mapa.
const NOTE_COLUMNS := ["room_1", "room_2", "patio", "room_3", "room_4", "room_5", "sala_saida"]
const NOTES_PER_COLUMN := 3

var director: Node
var areas: Array = []
var targets: Array = []
var obtained := false
var revealed: Dictionary = {}   # requisito (ex.: "saida") -> true
## Escritos que apareceram no mapa: [{"area": "room_1", "text": "..."}]
var notes: Array = []

var _root: Control
var _canvas: Control
var _hint: Label
var _open := false
var _was_paused := false
var _time := 0.0
var _unread := false
# escrito sendo "escrito à mão" agora (índice em notes e progresso 0..1)
var _writing := -1
var _write_progress := 1.0
# pedaço de pergaminho no alto da tela (mapa fechado)
var _scrap: Control
var _scrap_text := ""
var _scrap_progress := 0.0
var _scrap_alpha := 0.0
var _scrap_queue: Array = []
var _scrap_running := false

# Limites da planta (metros): z da escola vira a largura; x vira a altura.
const WORLD_Z0 := 8.0
const WORLD_Z1 := -200.0
const WORLD_X0 := -26.0
const WORLD_X1 := 7.0


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.015, 0.01, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_map)
	_root.add_child(_canvas)
	_hint = UIStyle.label("", 15, Color(0.82, 0.74, 0.6, 0.9))
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.offset_left = -420
	_hint.offset_right = -24
	_hint.offset_top = 22
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_hint)
	_scrap = Control.new()
	_scrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrap.draw.connect(_draw_scrap)
	add_child(_scrap)


func set_obtained(value: bool) -> void:
	obtained = value
	_update_hint()


func reveal(requirement: String) -> void:
	revealed[requirement] = true
	if _open:
		_canvas.queue_redraw()


func is_open() -> bool:
	return _open


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	if _open:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	_open = true
	_unread = false
	_update_hint()
	_root.visible = true
	_canvas.queue_redraw()


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	if is_inside_tree():
		get_tree().paused = _was_paused


## Algo aparece escrito no mapa. Com o mapa aberto, a frase se escreve
## sozinha na coluna do lugar; fechado, aparece no pedaço de pergaminho no
## alto da tela (e o aviso "[M]" pisca). Com `await`, espera o tempo de
## escrever + ler (usado nas cenas); sem `await`, não bloqueia o jogo.
func write_note(area: String, text: String, read_time: float = -1.0) -> void:
	notes.append({"area": area, "text": text})
	note_written.emit(area, text)
	var write_time := clampf(text.length() * 0.045, 0.6, 2.6)
	if read_time < 0.0:
		read_time = clampf(1.2 + text.length() * 0.05, 2.0, 6.0)
	if _open:
		_writing = notes.size() - 1
		_write_progress = 0.0
		var t := 0.0
		while t < write_time and is_inside_tree():
			await _next_frame()
			t += _dt()
			_write_progress = clampf(t / write_time, 0.0, 1.0)
		_write_progress = 1.0
		_writing = -1
		await _wait(read_time)
	else:
		_unread = obtained
		_update_hint()
		_scrap_queue.append([text, write_time, read_time])
		if not _scrap_running:
			_run_scraps()
		# quem espera (cena) espera este escrito terminar de aparecer e ser lido
		await _wait(write_time + read_time)


func get_save_data() -> Array:
	return notes.duplicate(true)


func load_notes(saved: Array) -> void:
	notes = []
	for n in saved:
		if typeof(n) == TYPE_DICTIONARY:
			notes.append({"area": String(n.get("area", "")), "text": String(n.get("text", ""))})


func _update_hint() -> void:
	if not obtained:
		_hint.text = ""
	elif _unread:
		_hint.text = "[M]  Mapa  ·  algo novo foi escrito"
	else:
		_hint.text = "[M]  Mapa"


func _process(delta: float) -> void:
	_time += delta if delta > 0.0 else 1.0 / 60.0
	if _open:
		_canvas.queue_redraw()
	if _unread and obtained:
		_hint.modulate.a = 0.55 + 0.45 * sin(_time * 4.0)
	else:
		_hint.modulate.a = 1.0
	if _scrap_alpha > 0.0:
		_scrap.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mapa"):
		if _open:
			close()
		elif _can_open():
			open()
		get_viewport().set_input_as_handled()
	elif _open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


func _can_open() -> bool:
	if get_tree().paused:
		return false
	if director != null and director.has_method("is_busy") and director.is_busy():
		return false
	if not obtained:
		if director != null and director.has_method("toast"):
			director.toast("Você ainda não tem um mapa.")
		return false
	return true


# ================================================================ pedaço de pergaminho (mapa fechado)

func _run_scraps() -> void:
	_scrap_running = true
	while not _scrap_queue.is_empty() and is_inside_tree():
		var job: Array = _scrap_queue.pop_front()
		_scrap_text = String(job[0])
		var write_time := float(job[1])
		var read_time := float(job[2])
		_scrap_progress = 0.0
		var t := 0.0
		while t < 0.35 and is_inside_tree():
			await _next_frame()
			t += _dt()
			_scrap_alpha = clampf(t / 0.35, 0.0, 1.0)
		t = 0.0
		while t < write_time and is_inside_tree():
			await _next_frame()
			t += _dt()
			_scrap_progress = clampf(t / write_time, 0.0, 1.0)
		_scrap_progress = 1.0
		await _wait(read_time)
		t = 0.0
		while t < 0.8 and is_inside_tree():
			await _next_frame()
			t += _dt()
			_scrap_alpha = 1.0 - clampf(t / 0.8, 0.0, 1.0)
		_scrap_alpha = 0.0
		_scrap.queue_redraw()
	_scrap_running = false


func _draw_scrap() -> void:
	if _scrap_alpha <= 0.0 or _scrap_text == "":
		return
	var vp := _scrap.size
	var lines := _scrap_text.split("\n")
	var size := 34
	var w := 0.0
	for l in lines:
		w = maxf(w, FONT_HAND.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	w += 90.0
	var h := lines.size() * (size + 6) + 46.0
	var rect := Rect2(Vector2((vp.x - w) * 0.5, vp.y * 0.13), Vector2(w, h))
	var a := _scrap_alpha
	var poly := _ragged(rect, 7.0, 3.1)
	_canvas_fill(_scrap, poly, Color(PAPER, 0.96 * a))
	_scrap.draw_polyline(_closed(poly), Color(BURN, 0.55 * a), 5.0)
	_scrap.draw_polyline(_closed(poly), Color(BURN, 0.85 * a), 1.6)
	for i in 5:
		var c := rect.position + Vector2((_n(i * 3.1 + 0.5) * 0.5 + 0.5) * rect.size.x, (_n(i * 7.7) * 0.5 + 0.5) * rect.size.y)
		_scrap.draw_circle(c, 6.0 + 10.0 * (_n(i * 1.9) * 0.5 + 0.5), Color(PAPER_DARK, 0.25 * a))
	_draw_handwriting(_scrap, Vector2(rect.position.x + 45, rect.position.y + 24 + size), lines, size, NOTE_INK, a, _scrap_progress, -0.02)


# ================================================================ desenho do mapa

func _visible(area: Dictionary) -> bool:
	var req := String(area.get("requires", "map"))
	return obtained if req == "map" else revealed.has(req)


func _xf(rect: Rect2) -> Callable:
	# metros -> pixels: z (profundidade) vira X na tela; x da escola vira Y.
	# Escalas diferentes nos dois eixos: é um mapa esquemático desenhado à mão.
	var sx := rect.size.x / (WORLD_Z0 - WORLD_Z1)
	var sy := rect.size.y / (WORLD_X1 - WORLD_X0)
	var origin := rect.position
	return func(x: float, z: float) -> Vector2:
		return origin + Vector2((WORLD_Z0 - z) * sx, (x - WORLD_X0) * sy)


func _draw_map() -> void:
	var vp := _canvas.size
	var paper := Rect2(Vector2(vp.x * 0.045, vp.y * 0.115), Vector2(vp.x * 0.91, vp.y * 0.74))
	_draw_parchment(paper)
	var frame := paper.grow(-26)
	_canvas.draw_rect(frame, Color(RED, 0.9), false, 3.0)
	_canvas.draw_rect(frame.grow(-6), Color(RED, 0.75), false, 1.2)
	for c in [frame.position, Vector2(frame.end.x, frame.position.y), frame.end, Vector2(frame.position.x, frame.end.y)]:
		_canvas.draw_circle(c, 5.0, Color(RED, 0.9))
	var inner := frame.grow(-18)
	# cartela do título
	var title := "A ESCOLA"
	var tsz := 30
	var tw := FONT_TITLE.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	var cart := Rect2(Vector2(inner.position.x + 6, inner.position.y), Vector2(tw + 70, 64))
	_canvas.draw_rect(cart, Color(PAPER.lightened(0.06), 0.95))
	_canvas.draw_rect(cart, INK, false, 2.0)
	_canvas.draw_rect(cart.grow(-4), Color(INK, 0.6), false, 1.0)
	_canvas.draw_string(FONT_TITLE, Vector2(cart.position.x + 35, cart.position.y + 34), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, INK)
	_canvas.draw_string(FONT_TITLE_IT, Vector2(cart.position.x + 35, cart.position.y + 54), "planta desenhada por mão desconhecida", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(INK, 0.8))
	# planta: 62% de cima; escritos: faixa de baixo
	var plan := Rect2(Vector2(inner.position.x, inner.position.y + 70), Vector2(inner.size.x, inner.size.y * 0.5))
	var band := Rect2(Vector2(inner.position.x, plan.end.y + 30), Vector2(inner.size.x, inner.end.y - plan.end.y - 30))
	var to := _xf(plan)
	var completed := _completed_rooms()
	var area_boxes := {}
	for area in areas:
		if not _visible(area):
			continue
		var r: Array = area.rect
		var a: Vector2 = to.call(float(r[0]), float(r[3]))
		var b: Vector2 = to.call(float(r[2]), float(r[1]))
		var box := Rect2(a, Vector2.ZERO).expand(b)
		area_boxes[String(area.id)] = box
		var kind := String(area.get("kind", "room"))
		var seed := float(String(area.id).hash() % 997)
		match kind:
			"corridor":
				_canvas.draw_rect(box, Color(PAPER_DARK, 0.35))
				_ink_line(box.position, Vector2(box.end.x, box.position.y), 2.0, INK, seed)
				_ink_line(Vector2(box.position.x, box.end.y), box.end, 2.0, INK, seed + 3.0)
				# piso do corredor: tracejado no meio
				var y := box.get_center().y
				var x := box.position.x + 8
				while x < box.end.x - 8:
					_canvas.draw_line(Vector2(x, y), Vector2(minf(x + 9, box.end.x), y), Color(INK, 0.35), 1.0)
					x += 18
			"patio":
				# pátio a céu aberto: piso de pedra (quadriculado leve), sem hachura de parede
				_canvas.draw_rect(box, Color(0.72, 0.7, 0.62, 0.75))
				var gx := box.position.x + 7.0
				while gx < box.end.x:
					_canvas.draw_line(Vector2(gx, box.position.y + 2), Vector2(gx, box.end.y - 2), Color(INK, 0.12), 1.0)
					gx += 9.0
				var gy := box.position.y + 7.0
				while gy < box.end.y:
					_canvas.draw_line(Vector2(box.position.x + 2, gy), Vector2(box.end.x - 2, gy), Color(INK, 0.12), 1.0)
					gy += 9.0
				_ink_rect(box, 2.6, INK, seed)
				_draw_icon(String(area.get("icon", "")), box.get_center() + Vector2(0, -8), minf(box.size.y * 0.24, 22.0))
			"blocked":
				_canvas.draw_rect(box, Color(PAPER_DARK, 0.45))
				var i := 0.0
				while i < box.size.x + box.size.y:
					var p0 := Vector2(box.position.x + i, box.position.y)
					var p1 := Vector2(box.position.x + i - box.size.y, box.end.y)
					var seg := _clip_segment(p0, p1, box)
					if seg.size() == 2:
						_canvas.draw_line(seg[0], seg[1], Color(INK, 0.35), 1.2)
					i += 11.0
				_ink_rect(box, 2.0, INK, seed)
				_canvas.draw_string(FONT_TITLE_IT, box.get_center() + Vector2(-34, 6), "interditado", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(INK, 0.75))
			_:
				var fill := ROOM_FILL if area.id != "sala_saida" else Color(0.72, 0.55, 0.42)
				_canvas.draw_rect(box, Color(fill, 0.85))
				# sombreado a nanquim na parede do fundo (hachura)
				var hx := box.position.x
				while hx < box.end.x:
					_canvas.draw_line(Vector2(hx, box.position.y + 1), Vector2(hx + 6, box.position.y + 7), Color(INK, 0.3), 1.0)
					hx += 6.0
				_ink_rect(box, 2.6, INK, seed)
				_draw_icon(String(area.get("icon", "")), box.get_center() + Vector2(0, -6), minf(box.size.y * 0.22, 20.0))
		_draw_area_label(area, box, kind)
		if completed.has(String(area.id)):
			var pad := 9.0
			_ink_line(box.position + Vector2(pad, pad), box.end - Vector2(pad, pad), 3.4, Color(RED, 0.85), seed + 11.0, 2.2)
			_ink_line(Vector2(box.end.x - pad, box.position.y + pad), Vector2(box.position.x + pad, box.end.y - pad), 3.4, Color(RED, 0.85), seed + 17.0, 2.2)
		if area.has("door"):
			var d: Array = area.door
			var dp: Vector2 = to.call(float(d[0]), float(d[1]))
			_canvas.draw_rect(Rect2(dp - Vector2(8, 3), Vector2(16, 6)), PAPER)
			_canvas.draw_line(dp + Vector2(-8, 0), dp + Vector2(8, 0), Color(INK, 0.6), 1.0)
			_canvas.draw_arc(dp + Vector2(-8, 0), 14.0, -PI * 0.5, 0.0, 10, Color(INK, 0.55), 1.0)
	# rosa dos ventos (canto inferior direito da planta)
	# no vão entre Geografia e a saída, na altura das salas
	_draw_compass(to.call(-14.0, -151.5), minf(40.0, plan.size.y * 0.16))
	# objetivo: círculo vermelho feito à mão
	var target := _current_target()
	if not target.is_empty():
		var tp: Vector2 = to.call(float(target.target[0]), float(target.target[1]))
		var pulse := 1.0 + 0.08 * sin(_time * 3.0)
		_hand_ellipse(tp, Vector2(30, 21) * pulse, Color(RED, 0.95), 3.0)
		_hand_ellipse(tp, Vector2(36, 26) * pulse, Color(RED, 0.35), 1.6)
	# Yuko
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		var p := player.global_position
		var pp: Vector2 = to.call(p.x, p.z)
		var yaw := 0.0
		if "visual" in player and player.visual != null:
			yaw = player.visual.global_rotation.y
		var fwd3 := Vector3(sin(yaw), 0, cos(yaw))
		var dir := Vector2(-fwd3.z, fwd3.x).normalized()
		var side := Vector2(-dir.y, dir.x)
		var tip := pp + dir * 13.0
		_canvas.draw_colored_polygon(PackedVector2Array([tip, pp - dir * 7.0 + side * 7.0, pp - dir * 3.0, pp - dir * 7.0 - side * 7.0]), Color(0.1, 0.17, 0.32))
		_canvas.draw_string(FONT_HAND, pp + Vector2(11, -11), "você", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.1, 0.17, 0.32))
	# escritos (a "voz")
	_draw_notes(band, area_boxes)
	# legenda fora do papel
	var legend_y := paper.end.y + 34
	var objective := "Objetivo: " + (String(target.get("text", "")) if not target.is_empty() else "—")
	_canvas.draw_string(FONT_TITLE, Vector2(paper.position.x + 6, legend_y), objective, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.93, 0.88, 0.78))
	_canvas.draw_string(FONT_TITLE_IT, Vector2(paper.end.x - 120, legend_y), "[M] fechar", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.75, 0.7, 0.62))


func _draw_parchment(r: Rect2) -> void:
	var poly := _ragged(r, 12.0, 1.0)
	# sombra
	var shadow := PackedVector2Array()
	for p in poly:
		shadow.append(p + Vector2(6, 8))
	_canvas_fill(_canvas, shadow, Color(0, 0, 0, 0.45))
	_canvas_fill(_canvas, poly, PAPER)
	# escurece para as bordas (camadas)
	for i in 6:
		var k := float(i + 1)
		var inset := _ragged(r.grow(-6.0 * k), 8.0, 1.0 + k)
		_canvas.draw_polyline(_closed(inset), Color(PAPER_DARK, 0.11), 12.0)
	# manchas
	for i in 14:
		var c := r.position + Vector2((_n(i * 2.31 + 0.7) * 0.5 + 0.5) * r.size.x, (_n(i * 5.17 + 1.3) * 0.5 + 0.5) * r.size.y)
		var rad := 10.0 + 38.0 * (_n(i * 3.7) * 0.5 + 0.5)
		_canvas.draw_circle(c, rad, Color(PAPER_DARK, 0.12))
		_canvas.draw_arc(c, rad, 0, TAU, 28, Color(BURN, 0.08), 2.0)
	# borda queimada
	_canvas.draw_polyline(_closed(poly), Color(BURN, 0.45), 9.0)
	_canvas.draw_polyline(_closed(poly), Color(0.12, 0.07, 0.03, 0.9), 2.2)


func _draw_area_label(area: Dictionary, box: Rect2, kind: String) -> void:
	var label := String(area.get("label", ""))
	if label == "" or kind in ["corridor", "blocked"]:
		return
	var parts := label.split(" · ")
	if kind == "patio":
		var pw := FONT_TITLE.get_string_size(parts[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		_canvas.draw_string(FONT_TITLE, Vector2(box.get_center().x - pw * 0.5, box.end.y - 10), parts[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, INK)
		if parts.size() > 1:
			var sw := FONT_HAND.get_string_size(parts[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			_canvas.draw_string(FONT_HAND, Vector2(box.get_center().x - sw * 0.5, box.position.y + 17), parts[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(NOTE_INK, 0.85))
		return
	if area.id == "sala_saida":
		var ew := FONT_TITLE.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		_canvas.draw_string(FONT_TITLE, Vector2(box.get_center().x - ew * 0.5, box.end.y + 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, RED)
		return
	if parts.size() == 2:
		# selo vermelho numerado + nome
		var seal := Vector2(box.position.x + 16, box.position.y + 17)
		_canvas.draw_circle(seal, 12.0, RED)
		_canvas.draw_arc(seal, 12.0, 0, TAU, 24, Color(0.35, 0.03, 0.02), 1.5)
		var num := parts[0]
		var nw := FONT_TITLE.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		_canvas.draw_string(FONT_TITLE, seal + Vector2(-nw * 0.5, 6), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PAPER.lightened(0.2))
		var rname := parts[1]
		var sz := 19
		var w := FONT_TITLE.get_string_size(rname, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		while w > box.size.x - 8 and sz > 12:
			sz -= 1
			w = FONT_TITLE.get_string_size(rname, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		_canvas.draw_string(FONT_TITLE, Vector2(box.get_center().x - w * 0.5, box.end.y - 10), rname, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(RED if area.id == "sala_saida" else INK))
	else:
		# cômodo pequeno (onde acordou): nome em cima, à mão
		var y := box.position.y - 30
		for part in label.split(" ", false, 1):
			var w2 := FONT_HAND.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			_canvas.draw_string(FONT_HAND, Vector2(box.get_center().x - w2 * 0.5, y), part, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
			y += 18


func _draw_notes(band: Rect2, boxes: Dictionary) -> void:
	if notes.is_empty():
		return
	var cols := NOTE_COLUMNS.size()
	var cw := band.size.x / cols
	var by_area := {}
	for i in notes.size():
		var a := String(notes[i].area)
		if not by_area.has(a):
			by_area[a] = []
		by_area[a].append(i)
	for c in cols:
		var area: String = NOTE_COLUMNS[c]
		if not by_area.has(area):
			continue
		var idxs: Array = by_area[area]
		var x := band.position.x + cw * c + 8
		var width := cw - 16
		# coluna vizinha vazia: o escrito se espalha por ela
		if c + 1 < cols and not by_area.has(NOTE_COLUMNS[c + 1]):
			width = cw * 2.0 - 24
		elif c == cols - 1 and not by_area.has(NOTE_COLUMNS[c - 1]):
			x -= cw * 0.9
			width = cw * 1.9 - 16
		var top := band.position.y + 4
		# Cabe de baixo para cima: o escrito mais novo sempre aparece inteiro.
		var size := 19
		var blocks: Array = []
		var h := 0.0
		for j in range(idxs.size() - 1, maxi(-1, idxs.size() - 1 - NOTES_PER_COLUMN), -1):
			var i: int = idxs[j]
			var lines := _wrap(String(notes[i].text), width, size)
			var bh := lines.size() * (size + 2) + 8.0
			if h + bh > band.size.y - 6 and not blocks.is_empty():
				break
			h += bh
			blocks.push_front([i, lines, j == idxs.size() - 1])
		# fio de tinta até o lugar no mapa
		if boxes.has(area):
			var box: Rect2 = boxes[area]
			var from := Vector2(x + minf(width, cw) * 0.3, top - 2)
			var to := Vector2(box.get_center().x, box.end.y + 2)
			var mid := (from + to) * 0.5 + Vector2(16, 0)
			var pts := PackedVector2Array()
			for k in 13:
				var t := k / 12.0
				pts.append(from.lerp(mid, t).lerp(mid.lerp(to, t), t))
			_canvas.draw_polyline(pts, Color(NOTE_INK, 0.3), 1.2)
			_canvas.draw_circle(to, 2.5, Color(NOTE_INK, 0.55))
		var y := top + size
		for b in blocks:
			var i: int = b[0]
			var progress := _write_progress if i == _writing else 1.0
			_draw_handwriting(_canvas, Vector2(x, y), b[1], size, NOTE_INK, 1.0 if b[2] else 0.42, progress, -0.02 + 0.008 * _n(i * 1.7))
			y += (b[1] as PackedStringArray).size() * (size + 2) + 8.0


## Texto "à mão": cada letra com leve tremor; `progress` revela aos poucos e a
## letra recém-escrita fica mais escura (tinta molhada).
func _draw_handwriting(ci: CanvasItem, origin: Vector2, lines: PackedStringArray, size: int, color: Color, alpha: float, progress: float, slant: float) -> void:
	var total := 0
	for l in lines:
		total += l.length()
	var shown_chars := int(round(total * progress))
	var count := 0
	var y := origin.y
	for li in lines.size():
		var line: String = lines[li]
		var x := origin.x
		for ch_i in line.length():
			if count >= shown_chars:
				return
			var ch := line.substr(ch_i, 1)
			var jitter := Vector2(_n(count * 1.37 + li) * 0.8, _n(count * 2.11 + li * 3.0) * 1.2 + (x - origin.x) * slant)
			var wet := clampf(1.0 - float(shown_chars - count) / 6.0, 0.0, 1.0) if progress < 1.0 else 0.0
			var col := Color(color.darkened(0.35 * wet), color.a * alpha)
			ci.draw_char(FONT_HAND, Vector2(x, y) + jitter, ch, size, col)
			x += FONT_HAND.get_char_size(ch.unicode_at(0), size).x
			count += 1
		y += size + 2


func _wrap(text: String, width: float, size: int) -> PackedStringArray:
	var out := PackedStringArray()
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" ", false):
			var test := word if line == "" else line + " " + word
			if FONT_HAND.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
				out.append(line)
				line = word
			else:
				line = test
		out.append(line)
	return out


func _draw_icon(icon: String, c: Vector2, s: float) -> void:
	var col := Color(INK, 0.85)
	match icon:
		"livro":
			var l := PackedVector2Array([c + Vector2(0, -s * 0.5), c + Vector2(-s, -s * 0.75), c + Vector2(-s, s * 0.45), c + Vector2(0, s * 0.7)])
			var r := PackedVector2Array([c + Vector2(0, -s * 0.5), c + Vector2(s, -s * 0.75), c + Vector2(s, s * 0.45), c + Vector2(0, s * 0.7)])
			_canvas.draw_colored_polygon(l, Color(PAPER.lightened(0.1), 0.9))
			_canvas.draw_colored_polygon(r, Color(PAPER.lightened(0.1), 0.9))
			_canvas.draw_polyline(_closed(l), col, 1.6)
			_canvas.draw_polyline(_closed(r), col, 1.6)
			for k in 3:
				var yy := -s * 0.3 + k * s * 0.3
				_canvas.draw_line(c + Vector2(-s * 0.8, yy - s * 0.1), c + Vector2(-s * 0.15, yy + s * 0.05), Color(col, 0.5), 1.0)
				_canvas.draw_line(c + Vector2(s * 0.15, yy + s * 0.05), c + Vector2(s * 0.8, yy - s * 0.1), Color(col, 0.5), 1.0)
		"angulo":
			_canvas.draw_arc(c + Vector2(0, s * 0.5), s, PI, TAU, 24, col, 1.8)
			_canvas.draw_line(c + Vector2(-s, s * 0.5), c + Vector2(s, s * 0.5), col, 1.8)
			for k in 9:
				var a := PI + k * PI / 8.0
				var d := Vector2(cos(a), sin(a))
				_canvas.draw_line(c + Vector2(0, s * 0.5) + d * s * 0.82, c + Vector2(0, s * 0.5) + d * s, col, 1.0)
			_canvas.draw_line(c + Vector2(0, s * 0.5), c + Vector2(0, s * 0.5) + Vector2(cos(PI * 1.3), sin(PI * 1.3)) * s * 0.9, Color(RED, 0.9), 1.6)
		"frasco":
			var f := PackedVector2Array([c + Vector2(-s * 0.22, -s), c + Vector2(s * 0.22, -s), c + Vector2(s * 0.22, -s * 0.3),
				c + Vector2(s * 0.8, s * 0.8), c + Vector2(-s * 0.8, s * 0.8), c + Vector2(-s * 0.22, -s * 0.3)])
			_canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.5, s * 0.25), c + Vector2(s * 0.5, s * 0.25), c + Vector2(s * 0.8, s * 0.8), c + Vector2(-s * 0.8, s * 0.8)]), Color(0.32, 0.45, 0.32, 0.6))
			_canvas.draw_polyline(_closed(f), col, 1.8)
			_canvas.draw_circle(c + Vector2(s * 0.1, s * 0.5), s * 0.08, Color(PAPER, 0.8))
		"globo":
			_canvas.draw_circle(c, s * 0.8, Color(0.45, 0.55, 0.5, 0.35))
			_canvas.draw_arc(c, s * 0.8, 0, TAU, 28, col, 1.8)
			_canvas.draw_line(c + Vector2(-s * 0.8, 0), c + Vector2(s * 0.8, 0), Color(col, 0.7), 1.0)
			_draw_ellipse_arc(c, Vector2(s * 0.35, s * 0.8), Color(col, 0.7), 1.0)
			_canvas.draw_line(c + Vector2(0, s * 0.8), c + Vector2(0, s * 1.05), col, 1.6)
			_canvas.draw_line(c + Vector2(-s * 0.4, s * 1.05), c + Vector2(s * 0.4, s * 1.05), col, 1.6)
		"olho":
			var pts := PackedVector2Array()
			for k in 17:
				var t := float(k) / 16.0 * PI
				pts.append(c + Vector2(-cos(t) * s, -sin(t) * s * 0.5))
			for k in 17:
				var t := float(k) / 16.0 * PI
				pts.append(c + Vector2(cos(t) * s, sin(t) * s * 0.5))
			_canvas.draw_polyline(_closed(pts), Color(RED, 0.95), 1.8)
			_canvas.draw_circle(c, s * 0.3, Color(RED, 0.8))
			_canvas.draw_circle(c, s * 0.12, Color(0.1, 0.02, 0.01))
		"arvore":
			# cerejeira: tronco a nanquim e copa de manchas rosadas
			_canvas.draw_line(c + Vector2(0, s * 1.0), c + Vector2(-s * 0.1, -s * 0.1), col, 2.4)
			_canvas.draw_line(c + Vector2(-s * 0.05, s * 0.2), c + Vector2(s * 0.45, -s * 0.25), col, 1.6)
			_canvas.draw_line(c + Vector2(-s * 0.08, s * 0.1), c + Vector2(-s * 0.5, -s * 0.3), col, 1.6)
			for k in 7:
				var a := TAU * k / 7.0
				_canvas.draw_circle(c + Vector2(cos(a) * s * 0.55, sin(a) * s * 0.35 - s * 0.45), s * 0.32, Color(0.8, 0.45, 0.55, 0.55))
		"nota":
			# colcheia: cabeça inclinada, haste e bandeirola
			var head := c + Vector2(-s * 0.25, s * 0.55)
			var pts := PackedVector2Array()
			for k in 16:
				var t := TAU * k / 15.0
				pts.append(head + Vector2(cos(t) * s * 0.32, sin(t) * s * 0.22).rotated(-0.4))
			_canvas.draw_colored_polygon(pts, col)
			_canvas.draw_line(head + Vector2(s * 0.29, -s * 0.05), head + Vector2(s * 0.29, -s * 1.35), col, 2.0)
			_canvas.draw_line(head + Vector2(s * 0.29, -s * 1.35), head + Vector2(s * 0.75, -s * 0.85), col, 2.0)
		"cama":
			_ink_line(c + Vector2(-s * 0.4, -s * 0.4), c + Vector2(s * 0.4, s * 0.4), 2.4, Color(RED, 0.9), 3.0)
			_ink_line(c + Vector2(s * 0.4, -s * 0.4), c + Vector2(-s * 0.4, s * 0.4), 2.4, Color(RED, 0.9), 5.0)


func _draw_compass(c: Vector2, r: float) -> void:
	_canvas.draw_circle(c, r * 0.62, Color(PAPER.lightened(0.05), 0.8))
	_canvas.draw_arc(c, r * 0.62, 0, TAU, 32, Color(INK, 0.8), 1.4)
	_canvas.draw_arc(c, r * 0.56, 0, TAU, 32, Color(INK, 0.5), 0.8)
	for k in 8:
		var a := -PI * 0.5 + k * PI / 4.0
		var long := k % 2 == 0
		var ln := r if long else r * 0.55
		var tip := c + Vector2(cos(a), sin(a)) * ln
		var w := r * (0.16 if long else 0.1)
		var side := Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5)) * w
		var dark := Color(RED, 0.95) if k == 0 else INK
		_canvas.draw_colored_polygon(PackedVector2Array([c, c + side, tip]), dark)
		_canvas.draw_colored_polygon(PackedVector2Array([c, tip, c - side]), Color(PAPER.lightened(0.15), 1))
		_canvas.draw_polyline(PackedVector2Array([c + side, tip, c - side]), INK, 1.0)
	_canvas.draw_circle(c, 3.0, INK)
	_canvas.draw_string(FONT_TITLE, c + Vector2(-6, -r - 6), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, RED)


# ================================================================ traço à mão

func _ink_line(a: Vector2, b: Vector2, width: float, color: Color, seed: float, wobble: float = 1.1) -> void:
	var n := maxi(2, int(a.distance_to(b) / 14.0))
	var dir := (b - a).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array()
	# passa um pouco das quinas, como em desenho de arquiteto
	var a2 := a - dir * 3.0
	var b2 := b + dir * 3.0
	for i in n + 1:
		var t := float(i) / n
		pts.append(a2.lerp(b2, t) + perp * _n(seed + i * 0.73) * wobble)
	_canvas.draw_polyline(pts, color, width)


func _ink_rect(box: Rect2, width: float, color: Color, seed: float) -> void:
	_ink_line(box.position, Vector2(box.end.x, box.position.y), width, color, seed)
	_ink_line(Vector2(box.end.x, box.position.y), box.end, width, color, seed + 1.0)
	_ink_line(box.end, Vector2(box.position.x, box.end.y), width, color, seed + 2.0)
	_ink_line(Vector2(box.position.x, box.end.y), box.position, width, color, seed + 3.0)


func _hand_ellipse(c: Vector2, r: Vector2, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 38:
		var t := float(i) / 34.0 * TAU   # dá mais de uma volta: traço de caneta
		var wob := 1.0 + 0.06 * _n(i * 0.9 + 4.0)
		pts.append(c + Vector2(cos(t) * r.x, sin(t) * r.y) * wob)
	_canvas.draw_polyline(pts, color, width)


func _draw_ellipse_arc(c: Vector2, r: Vector2, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var t := float(i) / 24.0 * TAU
		pts.append(c + Vector2(cos(t) * r.x, sin(t) * r.y))
	_canvas.draw_polyline(pts, color, width)


func _ragged(r: Rect2, depth: float, seed: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var step := 16.0
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for e in 4:
		var a: Vector2 = corners[e]
		var b: Vector2 = corners[(e + 1) % 4]
		var n := maxi(2, int(a.distance_to(b) / step))
		var dir := (b - a).normalized()
		var inward := Vector2(-dir.y, dir.x)   # sentido horário: dentro fica à direita
		for i in n:
			var t := float(i) / n
			var off := (_n(seed * 13.0 + e * 101.0 + i * 1.37) * 0.5 + 0.5) * depth
			pts.append(a.lerp(b, t) + inward * off)
	return pts


func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var c := p.duplicate()
	if c.size() > 0:
		c.append(c[0])
	return c


func _canvas_fill(ci: CanvasItem, poly: PackedVector2Array, color: Color) -> void:
	# polígonos quase convexos: triangula para não falhar com bordas serrilhadas
	var tris := Geometry2D.triangulate_polygon(poly)
	if tris.is_empty():
		ci.draw_colored_polygon(poly, color)
		return
	var colors := PackedColorArray()
	colors.resize(poly.size())
	colors.fill(color)
	ci.draw_polygon(poly, colors)


func _clip_segment(a: Vector2, b: Vector2, box: Rect2) -> Array:
	# recorte simples (hachura dentro do retângulo)
	var pts := []
	for t in [0.0, 1.0]:
		var p: Vector2 = a.lerp(b, t)
		pts.append(p)
	var out := []
	var n := 24
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		if box.has_point(p):
			out.append(p)
	if out.size() < 2:
		return []
	return [out[0], out[out.size() - 1]]


static func _n(x: float) -> float:
	var v := sin(x * 12.9898 + 78.233) * 43758.5453
	return (v - floor(v)) * 2.0 - 1.0


func _completed_rooms() -> Dictionary:
	var out := {}
	var rooms := get_tree().get_first_node_in_group("room_progress_manager")
	if rooms != null:
		for id in ["room_1", "room_2", "room_3", "room_4", "room_5"]:
			if rooms.is_completed(StringName(id)):
				out[id] = true
	return out


func _current_target() -> Dictionary:
	var rooms := get_tree().get_first_node_in_group("room_progress_manager")
	for t in targets:
		if String(t.get("needs", "")) == "no_map":
			if not obtained:
				return t
			continue
		var until := String(t.get("until_room_completed", ""))
		if until == "" or rooms == null or not rooms.is_completed(StringName(until)):
			return t
	return {}


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds and is_inside_tree():
		await _next_frame()
		t += _dt()


func _dt() -> float:
	var d := get_process_delta_time()
	return d if d > 0.0 else 1.0 / 60.0


func _next_frame() -> void:
	if is_inside_tree():
		await get_tree().process_frame
	else:
		await (Engine.get_main_loop() as SceneTree).process_frame
