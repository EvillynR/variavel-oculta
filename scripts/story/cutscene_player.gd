class_name CutscenePlayer
extends CanvasLayer
## Cenas de filme dentro do jogo (pedido: "a história contada como um filme").
##
## - Barras pretas (letterbox), legendas com o nome de quem fala, cartelas de
##   título e fades — tudo desenhado aqui.
## - Uma câmera própria (CineCamera) que viaja entre enquadramentos com
##   suavização; a câmera de jogo volta exatamente para onde estava no fim.
## - O jogo fica PAUSADO durante a cena (monstros e protagonista congelados);
##   este nó e a câmera rodam com PROCESS_MODE_ALWAYS.
## - As cenas NÃO podem ser puladas (decisão da equipe).
##
## O roteiro de cada cena vem de data/story.json (gerado por
## tools/build_story.py a partir de tools/story_content.py).

signal line_shown(speaker: String, text: String)

const SPEAKER_COLORS := {
	"Yuko": Color(1.0, 0.86, 0.72),
	"Ficha": Color(0.85, 0.85, 0.8),
}
const MONSTER_COLOR := Color(0.95, 0.45, 0.4)
const BAR_RATIO := 0.11

var protagonist_name := "Yuko"
## Quem "fala" escrevendo no mapa (não é legenda: a frase se escreve no mapa).
var map_speaker := "Mapa"
var playing := false

var _bars_top: ColorRect
var _bars_bottom: ColorRect
var _fade: ColorRect
var _title: Label
var _sub_panel: PanelContainer
var _sub_speaker: Label
var _sub_text: Label
var _phone_tag: Label
var _rig: Node3D
var _cam: Camera3D
## Luz de cinema: uma "lanterna" suave presa à câmera + uma luz de recorte
## sobre o ponto em foco. Sem ela as salas (e os monstros escuros) somem na
## tela: no jogo, a luz que segue a Yuko ilumina só em volta dela.
var _key: SpotLight3D
var _fill: OmniLight3D
var _game_cam: Camera3D
var _bars := 0.0
var _cam_look := Vector3.ZERO


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	_bars_top = ColorRect.new()
	_bars_top.color = Color.BLACK
	_bars_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	add_child(_bars_top)
	_bars_bottom = ColorRect.new()
	_bars_bottom.color = Color.BLACK
	_bars_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	add_child(_bars_bottom)
	_set_bars(0.0)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)

	_title = Label.new()
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78))
	_title.add_theme_constant_override("outline_size", 0)
	_title.modulate.a = 0.0
	add_child(_title)

	_sub_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.0)
	sb.set_content_margin_all(6)
	_sub_panel.add_theme_stylebox_override("panel", sb)
	_sub_panel.anchor_left = 0.12
	_sub_panel.anchor_right = 0.88
	_sub_panel.anchor_top = 1.0 - BAR_RATIO - 0.02
	_sub_panel.anchor_bottom = 1.0 - BAR_RATIO - 0.02
	_sub_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sub_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sub_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 2)
	_sub_panel.add_child(box)
	_phone_tag = UIStyle.label("", 15, Color(0.55, 0.85, 1.0, 0.85))
	_phone_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_phone_tag)
	_sub_speaker = UIStyle.label("", 18)
	_sub_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_sub_speaker)
	_sub_text = UIStyle.label("", 24)
	_sub_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_text.add_theme_constant_override("outline_size", 6)
	_sub_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	box.add_child(_sub_text)
	_sub_panel.visible = false


func apply_subtitle_size(size: int) -> void:
	if _sub_text != null:
		_sub_text.add_theme_font_size_override("font_size", maxi(size + 2, 18))


# ================================================================ execução

## Toca uma cena do roteiro. `ctx` resolve âncoras ("player", "monster:<id>")
## e aplica poses e o toque do celular (fornecido pelo StoryDirector).
func play(cutscene: Dictionary, ctx: Object) -> void:
	playing = true
	var tree := get_tree()
	var was_paused := tree.paused
	tree.paused = true
	_game_cam = get_viewport().get_camera_3d()
	_ensure_rig()
	if _game_cam != null:
		_cam.global_transform = _game_cam.global_transform
		_cam.fov = _game_cam.fov
		_cam.cull_mask = _game_cam.cull_mask
		_cam_look = _game_cam.global_position - _game_cam.global_basis.z * 10.0
	_cam.current = true
	_set_cine_lights(true)
	var gcc := tree.get_first_node_in_group("camera_controller")
	if gcc != null and gcc.has_method("clear_prop_fade"):
		gcc.clear_prop_fade()
	# versão 5.6: cada cena escolhe a força da luz de recorte ("luz", 1 = normal);
	# salas que já têm luz própria (monitores) ficam mais escuras e tensas
	var luz := float(cutscene.get("luz", 1.0))
	_key.light_energy = 2.2 * luz
	_fill.light_energy = 1.4 * luz
	# Rótulos "E ..." dos objetos não aparecem na cena (o interactor está pausado).
	for it in tree.get_nodes_in_group("interactable"):
		if it.has_method("set_highlighted"):
			it.set_highlighted(false)
	_tween_bars(1.0, 0.6)
	for step in cutscene.get("steps", []):
		if not is_inside_tree():
			playing = false
			return
		await _run_step(step, ctx)
	if not is_inside_tree():
		playing = false
		return
	_hide_subtitle()
	# Volta para o jogo: barras saem, fade de entrada se a cena terminou no preto.
	_tween_bars(0.0, 0.5)
	_set_cine_lights(false)
	if _game_cam != null and is_instance_valid(_game_cam):
		_game_cam.current = true
	var gc := tree.get_first_node_in_group("camera_controller")
	if gc != null and gc.has_method("snap_to_target"):
		gc.snap_to_target()
	if _fade.color.a > 0.01 and not bool(cutscene.get("keep_black", false)):
		await _fade_to(0.0, 0.8)
	await _wait(0.5)
	tree.paused = was_paused
	playing = false


func _run_step(step: Dictionary, ctx: Object) -> void:
	if step.has("fade"):
		match String(step.fade):
			"black":
				_fade.color.a = 1.0
			"in":
				_fade_to(0.0, float(step.get("fade_time", 1.6)))   # corre junto com o resto do passo
			"out":
				await _fade_to(1.0, float(step.get("fade_time", 1.4)))
	# versão 5.7: efeitos no meio da cena (depois do fade, antes da câmera):
	# pôr o professor no piano, a Yuko no lugar, uma pose, um som...
	if step.has("effects") and ctx != null and ctx.has_method("cutscene_effects"):
		await ctx.cutscene_effects(step.effects)
	if step.has("map_open") and ctx != null and ctx.has_method("cutscene_map"):
		_hide_subtitle()
		ctx.cutscene_map(true)
		await _wait(0.6)
	if step.has("map_close") and ctx != null and ctx.has_method("cutscene_map"):
		await _wait(0.3)
		ctx.cutscene_map(false)
	if step.has("pose") and ctx != null and ctx.has_method("cutscene_pose"):
		ctx.cutscene_pose(String(step.pose), float(step.get("pose_time", 1.2)))
	var parallel: Array = []
	if step.has("cam"):
		parallel.append(_move_camera(step.cam, ctx))
	if step.has("title"):
		await _show_title(String(step.title), float(step.get("wait", 3.0)))
	# versão 5.7: a lousa mostra a melodia nota a nota (sem legenda por cima)
	if step.has("sequencia") and ctx != null and ctx.has_method("cutscene_sequence"):
		_hide_subtitle()
		await ctx.cutscene_sequence(String(step.sequencia))
	if step.has("ring") and ctx != null and ctx.has_method("cutscene_ring"):
		ctx.cutscene_ring(float(step.ring))
		_phone_tag.text = "(o celular vibra)"
		_sub_panel.visible = true
		_sub_speaker.text = ""
		_sub_text.text = ""
		await _wait(float(step.ring))
		_phone_tag.text = ""
	if step.has("lines"):
		for line in step.lines:
			await _say(String(line[0]), String(line[1]), ctx)
	elif step.has("wait") and not step.has("title"):
		await _wait(float(step.wait))
	# Espera a câmera terminar o movimento do passo.
	for job in parallel:
		while job.running and is_inside_tree():
			await _next_frame()


func _say(speaker: String, text: String, ctx: Object) -> void:
	if speaker == map_speaker and ctx != null and ctx.has_method("cutscene_map_write"):
		# A "voz" não fala: a frase aparece escrita no mapa (ou num pedaço de
		# pergaminho, se o mapa estiver fechado).
		_hide_subtitle()
		line_shown.emit(speaker, text)
		await ctx.cutscene_map_write(text)
		return
	_phone_tag.text = ""
	_sub_speaker.text = speaker.to_upper()
	var color: Color = SPEAKER_COLORS.get(speaker, MONSTER_COLOR if speaker.begins_with("O ") or speaker.begins_with("A ") else Color(0.85, 0.85, 0.8))
	_sub_speaker.add_theme_color_override("font_color", color)
	_sub_text.add_theme_color_override("font_color", Color(0.95, 0.94, 0.9) if speaker != protagonist_name else Color(1.0, 0.93, 0.85))
	_sub_text.text = text
	_sub_panel.visible = true
	_sub_text.visible_ratio = 0.0
	line_shown.emit(speaker, text)
	if ctx != null and ctx.has_method("cutscene_line"):
		ctx.cutscene_line(speaker, text)
	# Máquina de escrever rápida + tempo de leitura (sem pular).
	var reveal := clampf(text.length() * 0.018, 0.25, 1.2)
	var t := 0.0
	while t < reveal and is_inside_tree():
		await _next_frame()
		t += _dt()
		_sub_text.visible_ratio = clampf(t / reveal, 0.0, 1.0)
	_sub_text.visible_ratio = 1.0
	await _wait(clampf(1.4 + text.length() * 0.055, 2.2, 7.5))


func _hide_subtitle() -> void:
	_sub_panel.visible = false
	_phone_tag.text = ""


## Legenda avulsa fora de cena (ex.: Yuko comentando um documento).
func say_outside(speaker: String, text: String, ctx: Object = null) -> void:
	_sub_panel.visible = true
	await _say(speaker, text, ctx)
	_hide_subtitle()


func _show_title(text: String, seconds: float) -> void:
	_title.text = text
	var t := 0.0
	while t < 0.8 and is_inside_tree():
		await _next_frame()
		t += _dt()
		_title.modulate.a = clampf(t / 0.8, 0.0, 1.0)
	await _wait(maxf(seconds - 1.6, 0.4))
	t = 0.0
	while t < 0.8 and is_inside_tree():
		await _next_frame()
		t += _dt()
		_title.modulate.a = 1.0 - clampf(t / 0.8, 0.0, 1.0)
	_title.modulate.a = 0.0


# ================================================================ câmera

class CamJob:
	var running := true
	func is_valid() -> bool:
		return true


func _ensure_rig() -> void:
	if _rig != null and is_instance_valid(_rig):
		return
	_rig = Node3D.new()
	_rig.name = "CineRig"
	_rig.process_mode = Node.PROCESS_MODE_ALWAYS
	var scene_root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	var main := get_tree().get_first_node_in_group("player")
	if main != null:
		scene_root = main.get_parent()
	scene_root.add_child(_rig)
	# a câmera de cinema anda a cada quadro: fora da interpolação de física
	_rig.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_cam = Camera3D.new()
	_cam.name = "CineCamera"
	_cam.near = 0.05
	_rig.add_child(_cam)
	const CUT_LAYER := 1 << 19   # mesma camada de recorte da câmera de jogo
	_key = SpotLight3D.new()
	_key.light_color = Color(0.78, 0.84, 1.0)
	_key.light_energy = 2.2
	_key.spot_range = 26.0
	_key.spot_angle = 30.0
	_key.spot_attenuation = 0.6
	_key.shadow_enabled = true
	_key.light_cull_mask &= ~CUT_LAYER
	_cam.add_child(_key)
	_key.position = Vector3(0.6, 0.4, 0.0)
	_fill = OmniLight3D.new()
	_fill.light_color = Color(1.0, 0.82, 0.62)
	_fill.light_energy = 1.4
	_fill.omni_range = 6.0
	_fill.light_cull_mask &= ~CUT_LAYER
	_rig.add_child(_fill)
	_set_cine_lights(false)


func _set_cine_lights(on: bool) -> void:
	if _key != null:
		_key.visible = on
		_fill.visible = on


func _resolve(spec: Variant, ctx: Object) -> Vector3:
	if typeof(spec) == TYPE_ARRAY and spec.size() == 3:
		return Vector3(float(spec[0]), float(spec[1]), float(spec[2]))
	if typeof(spec) == TYPE_DICTIONARY and ctx != null and ctx.has_method("cutscene_anchor"):
		var base: Vector3 = ctx.cutscene_anchor(String(spec.get("anchor", "player")))
		var off: Array = spec.get("offset", [0, 0, 0])
		return base + Vector3(float(off[0]), float(off[1]), float(off[2]))
	return Vector3.ZERO


func _move_camera(cam: Dictionary, ctx: Object) -> CamJob:
	var job := CamJob.new()
	_run_camera(cam, ctx, job)
	return job


func _run_camera(cam: Dictionary, ctx: Object, job: CamJob) -> void:
	if not _cam.is_inside_tree():
		job.running = false
		return
	var from_pos := _cam.global_position
	var from_look := _cam_look
	if cam.has("from"):
		from_pos = _resolve(cam.from.pos, ctx)
		from_look = _resolve(cam.from.look, ctx)
	var to: Dictionary = cam.get("to", cam.get("from", {}))
	var to_pos := _resolve(to.get("pos", [from_pos.x, from_pos.y, from_pos.z]), ctx)
	var to_look := _resolve(to.get("look", [from_look.x, from_look.y, from_look.z]), ctx)
	var dur := maxf(float(cam.get("time", 2.0)), 0.01)
	var fov_from := float(cam.get("fov_from", 38.0))
	var fov_to := float(cam.get("fov", 34.0))
	var t := 0.0
	_place(from_pos, from_look, fov_from)
	while t < dur and is_inside_tree():
		await _next_frame()
		t += _dt()
		var k := _ease(clampf(t / dur, 0.0, 1.0))
		_place(from_pos.lerp(to_pos, k), from_look.lerp(to_look, k), lerpf(fov_from, fov_to, k))
	_place(to_pos, to_look, fov_to)
	job.running = false


func _place(pos: Vector3, look: Vector3, fov: float) -> void:
	if _cam == null or not _cam.is_inside_tree():
		return
	_cam.global_position = pos
	_cam_look = look
	if _fill != null:
		# luz de recorte um pouco acima e à frente do que está em foco
		_fill.global_position = look + Vector3.UP * 1.6 + (pos - look).normalized() * 1.2
	if pos.distance_to(look) > 0.01:
		var up := Vector3.UP if absf((look - pos).normalized().dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
		_cam.look_at(look, up)
	_cam.fov = fov


func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


# ================================================================ utilidades

func _set_bars(v: float) -> void:
	_bars = v
	var h := get_viewport().get_visible_rect().size.y * BAR_RATIO * v if is_inside_tree() else 0.0
	_bars_top.offset_top = 0
	_bars_top.offset_bottom = h
	_bars_bottom.offset_top = -h
	_bars_bottom.offset_bottom = 0


func _tween_bars(target: float, seconds: float) -> void:
	var start := _bars
	var t := 0.0
	while t < seconds and is_inside_tree():
		await _next_frame()
		t += _dt()
		_set_bars(lerpf(start, target, clampf(t / seconds, 0.0, 1.0)))
	_set_bars(target)


func _fade_to(alpha: float, seconds: float) -> void:
	var start := _fade.color.a
	var t := 0.0
	while t < seconds and is_inside_tree():
		await _next_frame()
		t += _dt()
		_fade.color.a = lerpf(start, alpha, clampf(t / seconds, 0.0, 1.0))
	_fade.color.a = alpha


## Tela preta imediata (ex.: abertura antes da primeira cena).
func set_black(alpha: float) -> void:
	_fade.color.a = alpha


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds and is_inside_tree():
		await _next_frame()
		t += _dt()


func _dt() -> float:
	var d := get_process_delta_time()
	return d if d > 0.0 else 1.0 / 60.0


## Próximo quadro sem quebrar quando a cena é trocada no meio (voltar ao menu,
## recarregar o checkpoint): fora da árvore, usa o laço principal do jogo.
func _next_frame() -> void:
	if is_inside_tree():
		await get_tree().process_frame
	else:
		await (Engine.get_main_loop() as SceneTree).process_frame
