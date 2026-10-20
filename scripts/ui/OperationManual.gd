extends Node
## Global reference: opening it freezes the scene without resetting the experiment.
const UI = preload("res://scripts/ui/UIStyle.gd")
var dialog: AcceptDialog
var tabs: TabContainer
var was_paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dialog = AcceptDialog.new()
	dialog.title = "博士的操作手册 · F1"
	dialog.theme = UI.get_game_theme()
	dialog.ok_button_text = "返回游戏"
	dialog.min_size = Vector2i(680, 460)
	add_child(dialog)
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(660, 420)
	dialog.add_child(tabs)
	dialog.visibility_changed.connect(func():
		if not dialog.visible: get_tree().paused = was_paused
	)
	dialog.window_input.connect(func(event):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
			dialog.hide()
	)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		get_viewport().set_input_as_handled()
		open()

func open() -> void:
	if dialog.visible: return
	_rebuild()
	was_paused = get_tree().paused
	get_tree().paused = true
	dialog.popup_centered(Vector2i(880, 560))

func key(action: String) -> String:
	return KeybindManager.get_action_display_name(action)

func _page(title: String, contents: String) -> void:
	var page := RichTextLabel.new()
	page.name = title
	page.bbcode_enabled = true
	page.text = contents
	page.add_theme_font_size_override("normal_font_size", 18)
	page.add_theme_font_size_override("bold_font_size", 21)
	page.add_theme_constant_override("line_separation", 9)
	page.selection_enabled = true
	tabs.add_child(page)

func _rebuild() -> void:
	var previous := tabs.current_tab
	for child in tabs.get_children():
		tabs.remove_child(child)
		child.queue_free()
	_page("选择与移动", "[b]先选中，再操作[/b]\n%s：退出放置工具。左键点自己的方块选中；空白处拖框多选。\nShift + 左键：追加 / 取消选中；Shift + 拖框：追加多选。\n已有选择时，先点空白取消，再从空白处拖框。\n\n[b]复制与粘贴 · 单块、多块都适用[/b]\n%s：复制选中方块，原件保留。\n%s：显示粘贴预览；移动鼠标，左键确认。每次粘贴后需再次按粘贴键。\n预览中可旋转 / 镜像；右键或 Esc 取消。红色预览表示位置冲突。\n\n[b]整体移动[/b]\n选中 → %s 剪切 → 移动鼠标 → 左键放到新位置。\n剪切会直接进入预览，无需再按粘贴；支持框选后批量移动。\n剪切立刻移除原件。取消预览不会恢复原件，按 %s 撤销。\n右键拖动移动的是镜头，不是方块。\n\n复制粘贴是编辑工具；复制器是运行时的机械，两者不同。" % [key("cancel_tool"),key("copy"),key("paste"),key("cut"),key("undo")])
	_page("搭建与变换", "[b]放置与擦除[/b]\n工具栏选择方块后：左键放置 / 按住拖动连续放置；右键擦除 / 拖动连续擦除。\n数字 1—6：普通、沉默、推进、复制、删除、旋转。\nCtrl + 滚轮：切换方块工具。仅能使用本关开放的器材。\n\n[b]旋转、镜像与编组[/b]\n%s / %s：逆 / 顺时针旋转 90°。对选区或粘贴预览整体生效；放置时调整新方块朝向。\n%s / %s：选区或粘贴预览水平 / 垂直镜像。\n放置旋转器时，%s 切换顺 / 逆时针模式。\n%s：选中方块编组；同一完整结构再次操作可解组。\n只有上下左右连接的方块组成同一结构；不相连部分分别编组。\n\n[b]修改与恢复[/b]\n%s：删除选中方块。默认设置下 Delete / Backspace 也可删除。\n%s：撤销；%s：重做。选择模式下右键点击可打开编辑菜单。\n预设世界方块不可编辑；教程粘贴仍受建造区和器材配额限制。" % [key("rotate_ccw"),key("rotate_cw"),key("flip_h"),key("flip_v"),key("flip_h"),key("group_structure"),key("delete"),key("undo"),key("redo")])
	_page("模拟与视角", "[b]搭建 → 观察 → 改进[/b]\n%s：开始 / 暂停模拟。点击“单步”逐拍观察；速度滑条调整速度。\n%s：重置模拟，恢复运行前构装并回到可编辑状态。\n暂停用于观察，不能继续编辑；需要先重置。\n“清空构装”删除自建方块；教程“重来当前幕”恢复该幕预设。\n\n[b]移动视角[/b]\n上 %s · 下 %s · 左 %s · 右 %s\n滚轮：以鼠标位置为中心缩放。\n中键拖动：平移视角；选择模式下右键拖动也可平移。\nHome：关内查看全景。双指触摸支持平移 / 缩放。\n\n[b]讲解与手册[/b]\n博士对话：点击文字或 Enter / Space 展开、继续；Esc 跳过。\n右侧“重听博士讲解”可重看当前幕介绍。\nF1 随时打开本手册。阅读时游戏冻结，关闭后保持原来的运行 / 暂停状态。\n手册中的可配置按键来自当前设置；可在主菜单“系统设置”修改。" % [key("toggle_sim"),key("reset_sim"),key("move_up"),key("move_down"),key("move_left"),key("move_right")])
	_page("蓝图与工坊", "[b]保存与复用[/b]\n关内“保存构装”保存当前设计；“载入构装”进入预览后左键放置。\n教程为保证练习流程，禁用载入构装；复制粘贴仍可使用。\n\n[b]关卡编辑器专用[/b]\n1—9、0、减号：选择普通、沉默、推进、复制、删除、旋转、坚硬、怪物、宝藏、污染、保护方块。\n编辑器也支持选择、复制、剪切移动、粘贴、旋转、镜像、编组和撤销 / 重做。\n通过编辑器界面设置建造区、保存关卡、试运行；地图和正式关卡中不能修改预设世界方块。\n\n[b]常见问题[/b]\n无法粘贴：检查目标是否占用、是否越界、器材是否已用完，以及是否仍处于模拟状态。\n框选没反应：先退出放置工具；从空白格开始拖动。\n移动后原件消失：剪切就是移动；若取消了预览，可撤销恢复。\n选区一起变换但不一起运动：编辑多选不等于编组，整体运动需要编组。")
	tabs.current_tab = clampi(previous, 0, tabs.get_tab_count() - 1)
