extends RefCounted

# Stable IDs keep routes independent of the editor's list ordering.
const CHAPTERS = [
	["枪", "枪械机制与远程火力", "探索自驱枪体与连续发射机制，实现远程精准打击。"],
	["获取", "营养核心回收", "搭建移动与抓取机构，将远处的营养宝藏安全运回建造区。"],
	["车", "载具与巡航构装", "利用刚体与推进器构建移动列车与作业车辆，应对动态作业环境。"],
	["计数器", "时间与状态的记忆", "利用细胞结构构建步进与循环计数器，实现复杂的时序逻辑控制。"]
]
const NODES = {
	# 第 1 章：枪 (Gun) - 3 关 (Chapter 0)
	"custom_level_80400": [0, "枪-1", 0, 0, false, 4, "自驱枪体 · 定向射击", "custom_level_81906"],
	"custom_level_81906": [0, "枪-2", 1, 0, false, 4, "连发机制 · 远距突破", "custom_level_33459"],
	"custom_level_33459": [0, "枪-3", 2, 0, false, 5, "火力矩阵 · 终极压制", "custom_level_78552"],

	# 第 2 章：获取 (Acquire) - 4 关 (Chapter 1)
	"custom_level_78552": [1, "获取-0", 0, 0, false, 3, "基础捕获 · 回收宝藏", "custom_level_78513"],
	"custom_level_78513": [1, "获取-1", 1, 0, false, 3, "长距推进 · 连续拾取", "custom_level_76724"],
	"custom_level_76724": [1, "获取-2", 2, 0, false, 3, "避障作业 · 复合回收", "custom_level_25312"],
	"custom_level_25312": [1, "获取-3", 3, 0, false, 4, "复合抓取 · 样本回收", "custom_level_27833"],

	# 第 3 章：车 (Vehicle) - 4 关 (Chapter 2)
	"custom_level_27833": [2, "车-0", 0, 0, false, 3, "巡航列车 · 协同驱动", "custom_level_21314"],
	"custom_level_21314": [2, "车-1", 1, 0, false, 4, "装甲列车 · 避障突破", "custom_level_28302"],
	"custom_level_28302": [2, "车-2", 2, 0, false, 4, "齿条列车 · 动量传递", "custom_level_49361"],
	"custom_level_49361": [2, "车-3", 3, 0, false, 5, "终极列车 · 复合作业", "custom_level_35377"],

	# 第 4 章：计数器 (Counter) - 3 关 (Chapter 3)
	"custom_level_35377": [3, "计数器-1", 0, 0, false, 4, "计数雏形 · 步进触发", "custom_level_33847"],
	"custom_level_33847": [3, "计数器-2", 1, 0, false, 5, "状态记忆 · 周期计数", "custom_level_80850"],
	"custom_level_80850": [3, "计数器-3", 2, 0, false, 5, "多阶时序 · 终极逻辑", ""]
}
const PROGRESS_PATH = "user://campaign_progress.cfg"
static var active_level := ""

static func info(id: String) -> Array:
	return NODES.get(id, [CHAPTERS.size(), "自选", 0, 0, false, 0, "", ""])

static func title(level: LevelData) -> String:
	return level.level_name.get_slice("：", 1) if level.level_name.contains("：") else level.level_name

static func completed() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(PROGRESS_PATH) != OK: return {}
	var value = config.get_value("campaign", "completed", {})
	return value if value is Dictionary else {}

static func mark_completed(id: String, ticks: int) -> void:
	var progress := completed()
	progress[id] = mini(int(progress.get(id, ticks)), ticks)
	var config := ConfigFile.new()
	config.set_value("campaign", "completed", progress)
	if config.save(PROGRESS_PATH) != OK: push_warning("无法保存通关记录")

static func next_index(id: String, levels: Array[LevelData]) -> int:
	var next_id: String = info(id)[7]
	var visited := {}
	while not next_id.is_empty() and not visited.has(next_id):
		visited[next_id] = true
		for i in range(levels.size()):
			if levels[i].level_id == next_id: return i
		next_id = info(next_id)[7]
	return -1
