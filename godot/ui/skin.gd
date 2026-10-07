extends RefCounted
const INK = Color("142c32")
const BRASS = Color("d4aa61")
const PAPER = Color("f4e7cb")

static func box(color: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	return style

static func make_theme() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font = load("res://assets/fonts/DoHyeon-Regular.ttf")
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", PAPER)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.7))
	theme.set_constant("shadow_offset_y", "Label", 1)
	for kind in ["Button", "PrimaryButton"]:
		if kind == "PrimaryButton": theme.set_type_variation(kind, "Button")
		var primary: bool = kind == "PrimaryButton"
		var material: String = "brass" if primary else "teal"
		for state in ["normal", "hover", "pressed", "disabled"]:
			var skin: StyleBoxTexture = StyleBoxTexture.new()
			skin.texture = load("res://assets/art/ui/%s-%s.svg" % [material, "normal" if state == "hover" else state])
			for edge in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: skin.set_texture_margin(edge, 20)
			skin.content_margin_left = 8
			skin.content_margin_right = 8
			skin.content_margin_top = 5
			skin.content_margin_bottom = 5
			theme.set_stylebox(state, kind, skin)
		var focus: StyleBoxFlat = box(Color(0, 0, 0, 0), Color("fff3d1"))
		focus.shadow_size = 0
		theme.set_stylebox("focus", kind, focus)
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			theme.set_color(state, kind, INK if primary else PAPER)
		theme.set_color("font_disabled_color", kind, Color("829698"))
	theme.set_stylebox("panel", "AcceptDialog", box(INK, BRASS, 12))
	theme.set_stylebox("panel", "PanelContainer", box(Color("18363b"), Color("71898a"), 12))
	theme.set_color("title_color", "Window", PAPER)
	theme.set_stylebox("embedded_border", "Window", box(INK, BRASS, 12))
	theme.set_stylebox("embedded_unfocused_border", "Window", box(INK, BRASS, 12))
	return theme
