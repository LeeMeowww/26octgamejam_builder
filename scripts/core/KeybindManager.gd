class_name KeybindManager
extends RefCounted

const SETTINGS_PATH = "user://keybindings.json"

# Signal for when keybindings are updated
# (Since KeybindManager is a RefCounted, callers can listen to KeybindManager or re-query)
static var keybindings_changed_callbacks: Array[Callable] = []

static func register_change_callback(cb: Callable) -> void:
	if cb not in keybindings_changed_callbacks:
		keybindings_changed_callbacks.append(cb)

static func unregister_change_callback(cb: Callable) -> void:
	keybindings_changed_callbacks.erase(cb)

static func _notify_changed() -> void:
	for cb in keybindings_changed_callbacks:
		if cb.is_valid():
			cb.call()

# Default actions definition
# Each action: { "label": String, "category": String, "key": int, "ctrl": bool, "shift": bool, "alt": bool }
static func get_default_bindings() -> Dictionary:
	return {
		# 编辑操作
		"undo": {
			"label": "撤销",
			"category": "编辑操作",
			"key": KEY_Z,
			"ctrl": true,
			"shift": false,
			"alt": false
		},
		"redo": {
			"label": "重做",
			"category": "编辑操作",
			"key": KEY_R,
			"ctrl": true,
			"shift": false,
			"alt": false
		},
		"copy": {
			"label": "复制",
			"category": "编辑操作",
			"key": KEY_C,
			"ctrl": true,
			"shift": false,
			"alt": false
		},
		"cut": {
			"label": "剪切",
			"category": "编辑操作",
			"key": KEY_X,
			"ctrl": true,
			"shift": false,
			"alt": false
		},
		"paste": {
			"label": "粘贴",
			"category": "编辑操作",
			"key": KEY_V,
			"ctrl": true,
			"shift": false,
			"alt": false
		},
		"delete": {
			"label": "删除",
			"category": "编辑操作",
			"key": KEY_X, # 用户明确要求：删除键默认为x
			"ctrl": false,
			"shift": false,
			"alt": false
		},
		"rotate_cw": {
			"label": "顺时针旋转90°",
			"category": "编辑操作",
			"key": KEY_E,
			"ctrl": false,
			"shift": false,
			"alt": false
		},
		"rotate_ccw": {
			"label": "逆时针旋转90°",
			"category": "编辑操作",
			"key": KEY_Q,
			"ctrl": false,
			"shift": false,
			"alt": false
		},
		"flip_h": {
			"label": "水平翻转",
			"category": "编辑操作",
			"key": KEY_F,
			"ctrl": false,
			"shift": false,
			"alt": false
		},
		"flip_v": {
			"label": "垂直翻转",
			"category": "编辑操作",
			"key": KEY_H,
			"ctrl": false,
			"shift": false,
			"alt": false
		},
		"group_structure": {
			"label": "结构编组/解组",
			"category": "编辑操作",
			"key": KEY_G,
			"ctrl": false,
			"shift": false,
			"alt": false
		},
		"cancel_tool": {
			"label": "取消工具/选择",
			"category": "编辑操作",
			"key": KEY_ESCAPE,
			"ctrl": false,
			"shift": false,
			"alt": false
		},

		# 视角与模拟
		"move_up": {
			"label": "向上平移视角",
			"category": "视角与模拟",
			"key": KEY_W,
			"ctrl": false,
			"shift": false,
			"alt": false
		},
		"move_down": {
			"label": "向下平移视角",
			"category": "视角与模拟",
			"key": KEY_S,
			"ctrl": false,
			"shift": false,
			"alt": false
		},
		"move_left": {
			"label": "向左平移视角",
			"category": "视角与模拟",
			"key": KEY_A,
			"ctrl": false,
			"shift": false,
			"alt": false
		},
		"move_right": {
			"label": "向右平移视角",
			"category": "视角与模拟",
			"key": KEY_D,
			"ctrl": false,
			"shift": false,
			"alt": false
		},
		"toggle_sim": {
			"label": "开始/暂停模拟",
			"category": "视角与模拟",
			"key": KEY_SPACE,
			"ctrl": false,
			"shift": false,
			"alt": false
		},
		"reset_sim": {
			"label": "重置模拟",
			"category": "视角与模拟",
			"key": KEY_R,
			"ctrl": false,
			"shift": false,
			"alt": false
		},

		# 快捷方块工具
		"tool_1": {
			"label": "方块: 普通方块",
			"category": "快捷方块",
			"key": KEY_1,
			"ctrl": false,
			"shift": false,
			"alt": false
		},
		"tool_2": {
			"label": "方块: 抑制器",
			"category": "快捷方块",
			"key": KEY_2,
			"ctrl": false,
			"shift": false,
			"alt": false
		},
		"tool_3": {
			"label": "方块: 推动器",
			"category": "快捷方块",
			"key": KEY_3,
			"ctrl": false,
			"shift": false,
			"alt": false
		},
		"tool_4": {
			"label": "方块: 复制器",
			"category": "快捷方块",
			"key": KEY_4,
			"ctrl": false,
			"shift": false,
			"alt": false
		},
		"tool_5": {
			"label": "方块: 摧毁器",
			"category": "快捷方块",
			"key": KEY_5,
			"ctrl": false,
			"shift": false,
			"alt": false
		},
		"tool_6": {
			"label": "方块: 转向器",
			"category": "快捷方块",
			"key": KEY_6,
			"ctrl": false,
			"shift": false,
			"alt": false
		},
		"tool_7": {
			"label": "方块: 坚硬方块",
			"category": "快捷方块",
			"key": KEY_7,
			"ctrl": false,
			"shift": false,
			"alt": false
		},
		"tool_8": {
			"label": "方块: 游荡怪物",
			"category": "快捷方块",
			"key": KEY_8,
			"ctrl": false,
			"shift": false,
			"alt": false
		},
		"tool_9": {
			"label": "方块: 宝藏",
			"category": "快捷方块",
			"key": KEY_9,
			"ctrl": false,
			"shift": false,
			"alt": false
		},
		"tool_0": {
			"label": "方块: 污染源",
			"category": "快捷方块",
			"key": KEY_0,
			"ctrl": false,
			"shift": false,
			"alt": false
		}
	}

static var _bindings: Dictionary = {}
static var _initialized: bool = false

static func init_keybinds() -> void:
	if _initialized:
		return
	_initialized = true
	_load_bindings()
	_apply_to_input_map()

static func _load_bindings() -> void:
	_bindings = get_default_bindings()
	if FileAccess.file_exists(SETTINGS_PATH):
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file != null:
			var text := file.get_as_text()
			file.close()
			var json = JSON.parse_string(text)
			if json is Dictionary:
				for action in json.keys():
					if _bindings.has(action) and json[action] is Dictionary:
						var d: Dictionary = json[action]
						_bindings[action]["key"] = int(d.get("key", _bindings[action]["key"]))
						_bindings[action]["ctrl"] = bool(d.get("ctrl", false))
						_bindings[action]["shift"] = bool(d.get("shift", false))
						_bindings[action]["alt"] = bool(d.get("alt", false))

static func save_bindings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_bindings, "  "))
		file.close()
	_apply_to_input_map()
	_notify_changed()

static func reset_to_defaults() -> void:
	_bindings = get_default_bindings()
	save_bindings()

static func _apply_to_input_map() -> void:
	# Synchronize known actions to Godot's InputMap
	for action in _bindings.keys():
		var b: Dictionary = _bindings[action]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = b["key"]
		ev.keycode = b["key"]
		ev.ctrl_pressed = b["ctrl"]
		ev.shift_pressed = b["shift"]
		ev.alt_pressed = b["alt"]
		InputMap.action_add_event(action, ev)

static func get_bindings() -> Dictionary:
	init_keybinds()
	return _bindings

static func get_binding(action_id: String) -> Dictionary:
	init_keybinds()
	return _bindings.get(action_id, {})

static func find_conflicting_action(action_id: String, keycode: int, ctrl: bool = false, shift: bool = false, alt: bool = false) -> String:
	init_keybinds()
	for act in _bindings.keys():
		if act == action_id:
			continue
		var b: Dictionary = _bindings[act]
		if b.get("key", 0) == keycode and b.get("ctrl", false) == ctrl and b.get("shift", false) == shift and b.get("alt", false) == alt:
			return act
	return ""

static func has_conflict(action_id: String, keycode: int, ctrl: bool = false, shift: bool = false, alt: bool = false) -> bool:
	return find_conflicting_action(action_id, keycode, ctrl, shift, alt) != ""

static func set_binding(action_id: String, keycode: int, ctrl: bool = false, shift: bool = false, alt: bool = false) -> bool:
	init_keybinds()
	if not _bindings.has(action_id):
		return false
	if has_conflict(action_id, keycode, ctrl, shift, alt):
		return false
	_bindings[action_id]["key"] = keycode
	_bindings[action_id]["ctrl"] = ctrl
	_bindings[action_id]["shift"] = shift
	_bindings[action_id]["alt"] = alt
	save_bindings()
	return true

static func get_action_display_name(action_id: String) -> String:
	init_keybinds()
	if not _bindings.has(action_id):
		return ""
	var b: Dictionary = _bindings[action_id]
	return format_shortcut_string(b.get("key", 0), b.get("ctrl", false), b.get("shift", false), b.get("alt", false))

static func format_shortcut_string(key: int, ctrl: bool, shift: bool, alt: bool) -> String:
	if key == 0:
		return "无"
	var parts: Array[String] = []
	if ctrl:
		parts.append("Ctrl")
	if alt:
		parts.append("Alt")
	if shift:
		parts.append("Shift")

	var key_name := OS.get_keycode_string(key)
	match key:
		KEY_ESCAPE: key_name = "Esc"
		KEY_SPACE: key_name = "Space"
		KEY_DELETE: key_name = "Del"
		KEY_BACKSPACE: key_name = "Backspace"
		KEY_UP: key_name = "↑"
		KEY_DOWN: key_name = "↓"
		KEY_LEFT: key_name = "←"
		KEY_RIGHT: key_name = "→"

	parts.append(key_name)
	return "+".join(parts)

static func is_action_just_pressed(event: InputEvent, action_id: String) -> bool:
	init_keybinds()
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false

	var b: Dictionary = _bindings.get(action_id, {})
	if b.is_empty():
		return false

	var event_key: int = key_event.keycode if key_event.keycode != 0 else key_event.physical_keycode
	var target_key: int = b.get("key", 0)

	if event_key != target_key:
		# Fallback: if delete action, also allow standard KEY_DELETE if not rebound
		if action_id == "delete" and target_key == KEY_X and (event_key == KEY_DELETE or event_key == KEY_BACKSPACE) and not key_event.ctrl_pressed and not key_event.alt_pressed:
			return true
		return false

	var need_ctrl: bool = b.get("ctrl", false)
	var need_shift: bool = b.get("shift", false)
	var need_alt: bool = b.get("alt", false)

	if key_event.ctrl_pressed != need_ctrl:
		return false
	if key_event.shift_pressed != need_shift:
		return false
	if key_event.alt_pressed != need_alt:
		return false

	return true
