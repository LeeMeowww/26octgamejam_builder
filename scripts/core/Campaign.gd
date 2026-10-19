extends RefCounted

# Stable IDs keep routes independent of the editor's list ordering.
const CHAPTERS = [
	["基础构装", "博士实验室", "跟着博士逐步探索；新的实验会沿着路线继续展开。"],
	["枪", "枪械机制与远程火力", "探索自驱枪体与连续发射机制，实现远程精准打击。"],
	["获取", "营养核心回收", "搭建移动与抓取机构，将远处的营养宝藏安全运回建造区。"],
	["车", "载具与巡航构装", "利用刚体与推进器构建移动列车与作业车辆，应对动态作业环境。"],
	["计数器", "时间与状态的记忆", "利用细胞结构构建步进与循环计数器，实现复杂的时序逻辑控制。"]
]
const NODES = {
	"tutorial_00": [0, "T01", 0, 0, false, 1, "普通", "tutorial_01"],
	"tutorial_03": [0, "T03", 2, 0, false, 1, "复制", "tutorial_04"],
	"tutorial_01": [0, "T02", 1, 0, false, 1, "删除", "tutorial_03"],
	"tutorial_04": [0, "T04", 0, 1, false, 1, "旋转", "tutorial_02"],
	"tutorial_02": [0, "T05", 1, 1, false, 1, "推进", "tutorial_06"],
	"tutorial_06": [0, "T06", 2, 1, false, 1, "组合", "tutorial_05"],
	"tutorial_05": [0, "T07", 0, 2, false, 1, "抑制器", ""],
	# 第 1 章：枪 (Gun) - 3 关 (Chapter 1)
	"custom_level_80400": [1, "枪-1", 0, 0, false, 4, "自驱枪体 · 定向射击", "custom_level_81906"],
	"custom_level_81906": [1, "枪-2", 1, 0, false, 4, "连发机制 · 远距突破", "custom_level_33459"],
	"custom_level_33459": [1, "枪-3", 2, 0, false, 5, "火力矩阵 · 终极压制", "custom_level_78552"],

	# 第 2 章：获取 (Acquire) - 4 关 (Chapter 2)
	"custom_level_78552": [2, "获取-0", 0, 0, false, 3, "基础捕获 · 回收宝藏", "custom_level_78513"],
	"custom_level_78513": [2, "获取-1", 1, 0, false, 3, "长距推进 · 连续拾取", "custom_level_76724"],
	"custom_level_76724": [2, "获取-2", 2, 0, false, 3, "避障作业 · 复合回收", "custom_level_25312"],
	"custom_level_25312": [2, "获取-3", 3, 0, false, 4, "复合抓取 · 样本回收", "custom_level_27833"],

	# 第 3 章：车 (Vehicle) - 4 关 (Chapter 3)
	"custom_level_27833": [3, "车-0", 0, 0, false, 3, "巡航列车 · 协同驱动", "custom_level_21314"],
	"custom_level_21314": [3, "车-1", 1, 0, false, 4, "装甲列车 · 避障突破", "custom_level_28302"],
	"custom_level_28302": [3, "车-2", 2, 0, false, 4, "齿条列车 · 动量传递", "custom_level_49361"],
	"custom_level_49361": [3, "车-3", 3, 0, false, 5, "终极列车 · 复合作业", "custom_level_35377"],

	# 第 4 章：计数器 (Counter) - 3 关 (Chapter 4)
	"custom_level_35377": [4, "计数器-1", 0, 0, false, 4, "计数雏形 · 步进触发", "custom_level_33847"],
	"custom_level_33847": [4, "计数器-2", 1, 0, false, 5, "状态记忆 · 周期计数", "custom_level_80850"],
	"custom_level_80850": [4, "计数器-3", 2, 0, false, 5, "多阶时序 · 终极逻辑", ""]
}
const PROGRESS_PATH = "user://campaign_progress.cfg"
const TUTORIAL_ORDER = ["tutorial_00", "tutorial_01", "tutorial_03", "tutorial_04", "tutorial_02", "tutorial_06", "tutorial_05"]
static var active_level := ""

static func is_unlocked(id: String) -> bool:
	var index := TUTORIAL_ORDER.find(id)
	if index < 0: return true
	var progress := completed()
	for i in range(index):
		if not progress.has(TUTORIAL_ORDER[i]): return false
	return true

static func unlock_description(id: String) -> String:
	var index := TUTORIAL_ORDER.find(id)
	if index < 0: return ""
	if is_unlocked(id): return "已解锁 · 可随时重玩教学"
	var level := SaveManager.load_level(TUTORIAL_ORDER[index - 1])
	return "完成「%s」后解锁" % level.level_name

static func info(id: String) -> Array:
	return NODES.get(id, [CHAPTERS.size(), "自选", 0, 0, false, 0, "", ""])

static func title(level: LevelData) -> String:
	return level.level_name.get_slice("：", 1) if level.level_name.contains("：") else level.level_name

static func completed() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(PROGRESS_PATH) != OK: return {}
	var value = config.get_value("campaign", "completed", {})
	var progress: Dictionary = value.duplicate() if value is Dictionary else {}
	# Rebuilt lessons have independent completion records; retain old saves on disk.
	for id in TUTORIAL_ORDER: progress.erase(id)
	var lessons = config.get_value("tutorial_rebuild_v1", "completed", {})
	if lessons is Dictionary: progress.merge(lessons, true)
	return progress

static func mark_completed(id: String, ticks: int) -> void:
	var config := ConfigFile.new()
	config.load(PROGRESS_PATH)
	var section := "tutorial_rebuild_v1" if id in TUTORIAL_ORDER else "campaign"
	var saved = config.get_value(section, "completed", {})
	var progress: Dictionary = saved if saved is Dictionary else {}
	progress[id] = mini(int(progress.get(id, ticks)), ticks)
	config.set_value(section, "completed", progress)
	if config.save(PROGRESS_PATH) != OK: push_warning("无法保存通关记录")

static func visible_tutorial_ids(levels: Array[LevelData]) -> Array[String]:
	var available := {}
	for level in levels: available[level.level_id] = true
	var result: Array[String] = []
	for id in TUTORIAL_ORDER:
		if available.has(id) and is_unlocked(id): result.append(id)
	return result

static func next_index(id: String, levels: Array[LevelData]) -> int:
	if id in TUTORIAL_ORDER:
		var visible := visible_tutorial_ids(levels)
		var at := visible.find(id)
		if at < 0 or at + 1 >= visible.size(): return -1
		for i in range(levels.size()):
			if levels[i].level_id == visible[at + 1]: return i
		return -1
	var next_id: String = info(id)[7]
	var visited := {}
	while not next_id.is_empty() and not visited.has(next_id):
		visited[next_id] = true
		if not is_unlocked(next_id): return -1
		for i in range(levels.size()):
			if levels[i].level_id == next_id: return i
		next_id = info(next_id)[7]
	return -1
