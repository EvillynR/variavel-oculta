class_name UIStyle
extends RefCounted
## Prompt 3 — estilo sóbrio de terror só com a UI do Godot (sem arte externa).

const BG := Color(0.02, 0.02, 0.025, 0.96)
const PANEL := Color(0.05, 0.05, 0.06, 0.94)
const TEXT := Color(0.78, 0.76, 0.72)
const DIM := Color(0.48, 0.47, 0.45)
const ACCENT := Color(0.62, 0.12, 0.1)


static func panel_box(border: Color = Color(0.22, 0.2, 0.2)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(18)
	return sb


static func button(text: String, callback: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(300, 40)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color(0.95, 0.9, 0.85))
	b.add_theme_color_override("font_focus_color", Color(0.95, 0.9, 0.85))
	b.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.3))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.set_content_margin_all(8)
	normal.content_margin_left = 16
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.12, 0.03, 0.03, 0.9)
	hover.border_color = ACCENT
	hover.border_width_left = 3
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", normal)
	if callback.is_valid():
		b.pressed.connect(callback)
	return b


static func label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Painel centralizado sobre um fundo escurecido; devolve a VBox de conteúdo.
static func modal(parent: Node, width: float = 520.0, shade_alpha: float = 0.75) -> VBoxContainer:
	var shade := ColorRect.new()
	shade.name = "Fundo"
	shade.color = Color(0, 0, 0, shade_alpha)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.add_theme_stylebox_override("panel", panel_box())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return box
