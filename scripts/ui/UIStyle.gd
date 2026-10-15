extends RefCounted

const BG := Color("0b151d")
const PANEL := Color("132530")
const BORDER := Color("35515e")
const TEXT := Color("e5f1ee")
const MUTED := Color("a1bac3")
const ACCENT := Color("8ce2be")
static var shared_theme: Theme

static func box(fill: Color, border := BORDER, radius := 8, padding := 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func get_theme() -> Theme:
	if shared_theme != null: return shared_theme
	shared_theme = Theme.new()
	shared_theme.default_font = load("res://assets/fonts/font.ttf")
	shared_theme.default_font_size = 16
	for type in ["Label", "Button", "LineEdit", "TextEdit", "RichTextLabel", "CheckButton", "ItemList"]:
		shared_theme.set_color("font_color", type, TEXT)
	shared_theme.set_stylebox("normal", "Button", box(Color("1a303c")))
	shared_theme.set_stylebox("hover", "Button", box(Color("294653"), ACCENT))
	shared_theme.set_stylebox("pressed", "Button", box(Color("315b55"), ACCENT))
	shared_theme.set_stylebox("disabled", "Button", box(Color("15232d"), Color("263d49")))
	shared_theme.set_color("font_disabled_color", "Button", Color("728992"))
	shared_theme.set_color("font_hover_color", "Button", Color.WHITE)
	shared_theme.set_color("font_pressed_color", "Button", Color.WHITE)
	var focus := box(Color.TRANSPARENT, Color("dcfba9"))
	focus.set_border_width_all(2)
	shared_theme.set_stylebox("focus", "Button", focus)
	for type in ["PanelContainer", "PopupPanel", "PopupMenu", "AcceptDialog"]:
		shared_theme.set_stylebox("panel", type, box(PANEL))
	for type in ["LineEdit", "TextEdit", "ItemList"]:
		shared_theme.set_stylebox("normal", type, box(BG))
		shared_theme.set_stylebox("focus", type, focus)
	shared_theme.set_stylebox("panel", "TooltipPanel", box(Color("243c47"), ACCENT))
	shared_theme.set_color("font_color", "TooltipLabel", TEXT)
	shared_theme.set_font_size("font_size", "TooltipLabel", 15)
	
	# TabBar & TabContainer
	shared_theme.set_color("font_selected_color", "TabBar", ACCENT)
	shared_theme.set_color("font_unselected_color", "TabBar", MUTED)
	shared_theme.set_color("font_hovered_color", "TabBar", TEXT)
	shared_theme.set_stylebox("tab_selected", "TabBar", box(Color("223b49"), ACCENT, 6, 16))
	shared_theme.set_stylebox("tab_unselected", "TabBar", box(Color("132530"), BORDER, 6, 16))
	shared_theme.set_stylebox("tab_hovered", "TabBar", box(Color("1a3240"), ACCENT, 6, 16))
	shared_theme.set_stylebox("panel", "TabContainer", box(Color("0e1c24"), BORDER, 8, 16))
	return shared_theme

static func primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", box(ACCENT, ACCENT))
	button.add_theme_stylebox_override("hover", box(Color("b3f4d5"), ACCENT))
	button.add_theme_stylebox_override("pressed", box(Color("64bea1"), ACCENT))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, BG)

static func label(parent: Node, text: String, size := 16, color := TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node
