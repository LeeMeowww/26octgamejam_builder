class_name LevelSelect
extends Control
const UI = preload("res://scripts/ui/UIStyle.gd")

const Campaign = preload("res://scripts/core/Campaign.gd")

const MapScript = preload("res://scripts/ui/CampaignMap.gd")
var levels: Array[LevelData] = []
var chapter_buttons: Array[Button] = []
var node_buttons: Dictionary = {}
var chapter := 0
var selected_index := -1
var map: Control
var chapter_title: Label
var chapter_description: Label
var detail_title: Label
var detail_body: RichTextLabel
var author_label: Label
var enter_button: Button
var map_scroll: ScrollContainer

func _ready() -> void:
	theme = UI.get_theme()
	if map != null: return
	levels = SaveManager.get_all_levels()
	_build_ui()
	var previous := -1
	for i in range(levels.size()):
		if levels[i].level_id == Campaign.active_level: previous = i
	_show_chapter(Campaign.info(levels[previous].level_id)[0] if previous >= 0 else 0)
	if previous >= 0: _select_level(previous)

func _label(parent: Node, text: String, font_size: int, color := Color("ddebe9")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0c171e")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var heading := _label(header, "格式塔  /  构装群岛", 28, Color("91e6c8"))
	heading.size_flags_horizontal = SIZE_EXPAND_FILL
	var back := Button.new()
	back.text = "返回主菜单"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))
	header.add_child(back)
	var chapter_scroll := ScrollContainer.new()
	chapter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(chapter_scroll)
	var chapter_bar := HBoxContainer.new()
	chapter_bar.add_theme_constant_override("separation", 10)
	chapter_scroll.add_child(chapter_bar)
	for i in range(5):
		if i == 4 and not _has_custom_levels(): continue
		var button := Button.new()
		button.text = ("%02d  %s" % [i, Campaign.CHAPTERS[i][0]]) if i < 4 else "自由工坊"
		button.custom_minimum_size = Vector2(170, 46)
		button.pressed.connect(_show_chapter.bind(i))
		chapter_bar.add_child(button)
		chapter_buttons.append(button)
	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	layout.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(left)
	chapter_title = _label(left, "", 24)
	chapter_description = _label(left, "", 15, Color("96b0b8"))
	chapter_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_scroll = ScrollContainer.new()
	map_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	left.add_child(map_scroll)
	map = MapScript.new()
	map.custom_minimum_size = Vector2(750, 350)
	map_scroll.add_child(map)
	_label(left, "实线：主线    虚线：可选支线    ✓：已通关\n点击节点查看详情 · 所有关卡可自由探索 · 地图可滚动", 14, Color("96b0b8"))
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 330
	panel.add_theme_stylebox_override("panel", _style(Color("152630"), Color("35545c")))
	body.add_child(panel)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 18)
	panel.add_child(details)
	_label(details, "关卡档案", 14, Color("91e6c8"))
	detail_title = _label(details, "选择一个节点", 24)
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_body = RichTextLabel.new()
	detail_body.size_flags_vertical = SIZE_EXPAND_FILL
	detail_body.bbcode_enabled = false
	detail_body.add_theme_font_size_override("normal_font_size", 16)
	details.add_child(detail_body)
	author_label = _label(details, "", 17, Color("a8bec5"))
	author_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	author_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var author_font := SystemFont.new()
	author_font.font_names = PackedStringArray(["KaiTi", "STKaiti", "Noto Serif CJK SC", "serif"])
	author_font.fallbacks = [UI.get_theme().default_font]
	author_label.add_theme_font_override("font", author_font)
	author_label.hide()
	enter_button = Button.new()
	enter_button.text = "进入关卡 →"
	UI.primary(enter_button)
	enter_button.custom_minimum_size.y = 52
	enter_button.disabled = true
	enter_button.pressed.connect(func(): _enter_level(selected_index))
	details.add_child(enter_button)

func _has_custom_levels() -> bool:
	for level in levels:
		if not Campaign.NODES.has(level.level_id): return true
	return false

func _show_chapter(index: int) -> void:
	chapter = index
	selected_index = -1
	enter_button.disabled = true
	detail_title.text = "选择一个节点"
	detail_body.text = "点击地图上的关卡，查看目标与核心机制。\n\n主线帮助你逐步掌握构装，支线可以随时尝试。"
	author_label.hide()
	chapter_title.text = Campaign.CHAPTERS[index][1] if index < 4 else "自由工坊"
	chapter_description.text = Campaign.CHAPTERS[index][2] if index < 4 else "未编入章节的自制关卡也会保留在这里。"
	for i in range(chapter_buttons.size()):
		chapter_buttons[i].modulate = Color("91e6c8") if i == index else Color.WHITE
	for child in map.get_children():
		map.remove_child(child)
		child.queue_free()
	node_buttons.clear()
	map.routes.clear()
	var positions := {}
	var progress := Campaign.completed()
	var count := 0
	var completed_count := 0
	for i in range(levels.size()):
		var level := levels[i]
		var data := Campaign.info(level.level_id)
		if data[0] != index: continue
		if progress.has(level.level_id): completed_count += 1
		var column: int = data[2] if index < 4 else count % 4
		var row: int = data[3] if index < 4 else count / 4
		var position := Vector2(20 + column * 145, 60 + row * 170)
		var button := Button.new()
		button.toggle_mode = true
		button.position = position
		button.size = Vector2(130, 98)
		button.text = "%s %s\n%s" % [data[1], "✓" if progress.has(level.level_id) else "", Campaign.title(level)]
		button.add_theme_font_size_override("font_size", 15)
		var accent := Color("d9ad72") if data[4] else Color("62bfae")
		button.add_theme_stylebox_override("normal", _style(Color("19303a"), accent))
		button.add_theme_stylebox_override("focus", _style(Color("294751"), Color("efffe8")))
		button.add_theme_stylebox_override("hover", _style(Color("294751"), accent))
		button.add_theme_stylebox_override("pressed", _style(Color("31534e"), Color("b2f0cd")))
		button.pressed.connect(_select_level.bind(i))
		map.add_child(button)
		node_buttons[level.level_id] = button
		positions[level.level_id] = position + button.size * 0.5
		count += 1
	map.custom_minimum_size = Vector2(750, maxf(350, ceilf(count / 4.0) * 170 + 100) if index == 4 else 350)
	for id in positions:
		var next: String = Campaign.info(id)[7]
		if positions.has(next): map.routes.append([positions[id], positions[next], false])
	for edge in Campaign.BRANCHES:
		if positions.has(edge[0]) and positions.has(edge[1]): map.routes.append([positions[edge[0]], positions[edge[1]], true])
	if count == 0: detail_body.text = "此章节暂无可用关卡。可切换章节或在关卡管理中添加内容。"
	chapter_description.text += "   ·   已完成 %d / %d" % [completed_count, count]
	map.queue_redraw()
	map_scroll.scroll_horizontal = 0
	map_scroll.scroll_vertical = 0

func _select_level(index: int) -> void:
	selected_index = index
	var level := levels[index]
	for id in node_buttons: node_buttons[id].set_pressed_no_signal(id == level.level_id)
	var data := Campaign.info(level.level_id)
	detail_title.text = "%s  %s" % [data[1], Campaign.title(level)]
	var status := "已通关" if Campaign.completed().has(level.level_id) else "未通关"
	var goal := level.description
	if level.level_id in ["level_04", "custom_level_81605"]: goal = "清除所有污染源。怪物是障碍，不要求全部消灭。"
	detail_body.clear()
	detail_body.add_text("%s  ·  %s\n\n" % ["支线" if data[4] else "主线", status])
	for section in [["目标", goal], ["核心机制", data[6]]]:
		detail_body.push_font_size(18)
		detail_body.push_color(Color("b2e9d6"))
		detail_body.add_text(str(section[0]))
		detail_body.pop()
		detail_body.pop()
		detail_body.add_text("\n" + str(section[1]) + "\n\n")
	author_label.text = "作者  " + (level.author if not level.author.is_empty() else "佚名")
	author_label.show()
	enter_button.disabled = false
	node_buttons[level.level_id].grab_focus()

func _enter_level(index: int) -> void:
	if index < 0 or index >= levels.size(): return
	var selected_id := levels[index].level_id
	var player: LevelPlayer = load("res://scenes/ui/LevelPlayer.tscn").instantiate()
	get_tree().root.add_child(player)
	for i in range(player.all_levels.size()):
		if player.all_levels[i].level_id == selected_id:
			player.load_level_by_index(i)
			get_tree().current_scene = player
			queue_free()
			return
	player.queue_free()
	levels = SaveManager.get_all_levels()
	_show_chapter(chapter)
