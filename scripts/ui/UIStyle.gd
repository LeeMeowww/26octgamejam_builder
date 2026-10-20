extends RefCounted

const BG := Color("6b5d69")
const PANEL := Color("bdbebe")
const BORDER := Color("111111")
const TEXT := Color("151515")
const MUTED := Color("4b4b4b")
const ACCENT := Color("202020")
static var shared_theme: Theme
static var game_theme: Theme

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

# 无背景图的按钮一律无边框，仅靠背景色区分状态（normal/hover/pressed/disabled）。
static func flat(fill: Color, radius := 0, padding := 10) -> StyleBoxFlat:
	var style := box(fill, Color.TRANSPARENT, radius, padding)
	style.set_border_width_all(0)
	return style

static func get_theme() -> Theme:
	if shared_theme != null: return shared_theme
	shared_theme = Theme.new()
	shared_theme.default_font = load("res://assets/fonts/font.ttf")
	shared_theme.default_font_size = 16
	for type in ["Label", "Button", "LineEdit", "TextEdit", "RichTextLabel", "CheckButton", "ItemList"]:
		shared_theme.set_color("font_color", type, TEXT)
	shared_theme.set_stylebox("normal", "Button", flat(Color("b7b8b8"), 0, 10))
	shared_theme.set_stylebox("hover", "Button", flat(Color("d1d2d2"), 0, 10))
	shared_theme.set_stylebox("pressed", "Button", flat(Color("8d8e8e"), 0, 10))
	shared_theme.set_stylebox("disabled", "Button", flat(Color("969797"), 0, 10))
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
	shared_theme.set_stylebox("tab_selected", "TabBar", flat(Color("d0d1d1"), 0, 16))
	shared_theme.set_stylebox("tab_unselected", "TabBar", flat(Color("a4a5a5"), 0, 16))
	shared_theme.set_stylebox("tab_hovered", "TabBar", flat(Color("c4c5c5"), 0, 16))
	shared_theme.set_stylebox("panel", "TabContainer", box(PANEL, BORDER, 0, 16))
	return shared_theme

static func get_game_theme() -> Theme:
	if game_theme != null: return game_theme
	game_theme = Theme.new()
	game_theme.default_font = load("res://assets/fonts/font.ttf")
	game_theme.default_font_size = 16
	var game_text := Color("d8edf0")
	for type in ["Label", "Button", "LineEdit", "TextEdit", "RichTextLabel", "CheckButton", "ItemList"]:
		game_theme.set_color("font_color", type, game_text)
	game_theme.set_stylebox("normal", "Button", flat(Color("17333d"), 4, 10))
	game_theme.set_stylebox("hover", "Button", flat(Color("245263"), 4, 10))
	game_theme.set_stylebox("pressed", "Button", flat(Color("0f252d"), 4, 10))
	game_theme.set_stylebox("disabled", "Button", flat(Color("21343a"), 4, 10))
	game_theme.set_color("font_disabled_color", "Button", Color("759197"))
	game_theme.set_color("font_hover_color", "Button", game_text)
	game_theme.set_color("font_pressed_color", "Button", Color.WHITE)
	var focus := box(Color.TRANSPARENT, Color("80ffd7"), 4, 10)
	focus.set_border_width_all(2)
	game_theme.set_stylebox("focus", "Button", focus)
	for type in ["PanelContainer", "PopupPanel", "PopupMenu", "AcceptDialog"]:
		game_theme.set_stylebox("panel", type, box(Color("102a35"), Color("2f7380"), 4))
	for type in ["LineEdit", "TextEdit", "ItemList"]:
		game_theme.set_stylebox("normal", type, box(Color("102a35"), Color("2f7380"), 4))
		game_theme.set_stylebox("focus", type, focus)
	game_theme.set_color("font_color", "TooltipLabel", game_text)
	game_theme.set_stylebox("panel", "TooltipPanel", box(Color("102a35"), Color("2f7380"), 4))
	# TabBar：与按钮一致的无边框标签页（设置菜单、操作手册使用）
	game_theme.set_color("font_selected_color", "TabBar", game_text)
	game_theme.set_color("font_unselected_color", "TabBar", Color("7fa3ad"))
	game_theme.set_color("font_hovered_color", "TabBar", game_text)
	game_theme.set_stylebox("tab_selected", "TabBar", flat(Color("1f4a58"), 6, 16))
	game_theme.set_stylebox("tab_unselected", "TabBar", flat(Color("132b34"), 6, 16))
	game_theme.set_stylebox("tab_hovered", "TabBar", flat(Color("17333d"), 6, 16))
	game_theme.set_stylebox("panel", "TabContainer", box(Color("102a35"), Color("2f7380"), 4, 16))
	return game_theme

static func primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", flat(Color("d0d1d1"), 0))
	button.add_theme_stylebox_override("hover", flat(Color("e0e1e1"), 0))
	button.add_theme_stylebox_override("pressed", flat(Color("969797"), 0))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, TEXT)

static func game_primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", flat(Color("245263"), 4))
	button.add_theme_stylebox_override("hover", flat(Color("357083"), 4))
	button.add_theme_stylebox_override("pressed", flat(Color("173b48"), 4))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color("e9ffff"))

static func label(parent: Node, text: String, size := 16, color := TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node
