extends RefCounted

const BG := Color("6b5d69")
const PANEL := Color("bdbebe")
const BORDER := Color("111111")
const TEXT := Color("151515")
const MUTED := Color("4b4b4b")
const ACCENT := Color("202020")
static var shared_theme: Theme

static func box(fill: Color, border := BORDER, radius := 0, padding := 10) -> StyleBoxFlat:
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
	shared_theme.set_stylebox("normal", "Button", box(Color("b7b8b8"), BORDER, 0, 10))
	shared_theme.set_stylebox("hover", "Button", box(Color("d1d2d2"), BORDER, 0, 10))
	shared_theme.set_stylebox("pressed", "Button", box(Color("8d8e8e"), BORDER, 0, 10))
	shared_theme.set_stylebox("disabled", "Button", box(Color("969797"), Color("454545"), 0, 10))
	shared_theme.set_color("font_disabled_color", "Button", Color("5a5a5a"))
	shared_theme.set_color("font_hover_color", "Button", TEXT)
	shared_theme.set_color("font_pressed_color", "Button", TEXT)
	var focus := box(Color.TRANSPARENT, BORDER, 0, 10)
	focus.set_border_width_all(2)
	shared_theme.set_stylebox("focus", "Button", focus)
	for type in ["PanelContainer", "PopupPanel", "PopupMenu", "AcceptDialog"]:
		shared_theme.set_stylebox("panel", type, box(PANEL))
	for type in ["LineEdit", "TextEdit", "ItemList"]:
		shared_theme.set_stylebox("normal", type, box(BG))
		shared_theme.set_stylebox("focus", type, focus)
	shared_theme.set_stylebox("panel", "TooltipPanel", box(PANEL, BORDER, 0))
	shared_theme.set_color("font_color", "TooltipLabel", TEXT)
	shared_theme.set_font_size("font_size", "TooltipLabel", 15)
	
	# TabBar & TabContainer
	shared_theme.set_color("font_selected_color", "TabBar", ACCENT)
	shared_theme.set_color("font_unselected_color", "TabBar", MUTED)
	shared_theme.set_color("font_hovered_color", "TabBar", TEXT)
	shared_theme.set_stylebox("tab_selected", "TabBar", box(Color("d0d1d1"), BORDER, 0, 16))
	shared_theme.set_stylebox("tab_unselected", "TabBar", box(Color("a4a5a5"), BORDER, 0, 16))
	shared_theme.set_stylebox("tab_hovered", "TabBar", box(Color("c4c5c5"), BORDER, 0, 16))
	shared_theme.set_stylebox("panel", "TabContainer", box(PANEL, BORDER, 0, 16))
	return shared_theme

static func primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", box(Color("d0d1d1"), BORDER, 0))
	button.add_theme_stylebox_override("hover", box(Color("e0e1e1"), BORDER, 0))
	button.add_theme_stylebox_override("pressed", box(Color("969797"), BORDER, 0))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, TEXT)

static func label(parent: Node, text: String, size := 16, color := TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node
