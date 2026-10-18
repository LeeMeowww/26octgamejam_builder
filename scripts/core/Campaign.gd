extends RefCounted

# Stable IDs keep routes independent of the editor's list ordering.
const CHAPTERS = [
	["基础构装", "从第一块方块开始", "认识六种方块，让简单结构动起来。"],
	["拾取", "营养核心回收", "搭建移动与抓取机构，将远处的营养宝藏安全运回建造区。"],
	["枪", "枪械机制与远程火力", "探索自驱枪体与连续发射机制，实现远程精准打击。"],
	["计数器", "时间与状态的记忆", "利用细胞结构构建步进与循环计数器，实现复杂的时序逻辑控制。"]
]
const NODES = {
	"tutorial_01": [0, "0-1", 0, 0, false, 1, "放置摧毁器", "tutorial_02"],
	"tutorial_02": [0, "0-2", 1, 0, false, 1, "推进与编组", "tutorial_03"],
	"tutorial_03": [0, "0-3", 2, 0, false, 1, "复制与朝向", "tutorial_04"],
	"tutorial_04": [0, "0-4", 3, 0, false, 1, "改变方向", "tutorial_05"],
	"tutorial_05": [0, "0-5", 4, 0, false, 1, "抑制与破甲", "custom_level_78552"],
	"custom_level_78552": [1, "1-1", 0, 0, false, 3, "基础捕获 · 回收宝藏", "custom_level_78513"],
	"custom_level_78513": [1, "1-2", 1, 0, false, 3, "长距推进 · 连续拾取", "custom_level_76724"],
	"custom_level_76724": [1, "1-3", 2, 0, false, 3, "避障作业 · 复合回收", "custom_level_80400"],
	"custom_level_80400": [2, "2-1", 0, 0, false, 4, "自驱枪体 · 定向射击", "custom_level_81906"],
	"custom_level_81906": [2, "2-2", 1, 0, false, 4, "连发机制 · 远距突破", "custom_level_33459"],
	"custom_level_33459": [2, "2-3", 2, 0, false, 5, "火力矩阵 · 终极压制", "custom_level_35377"],
	"custom_level_86910": [2, "2-A", 1, 1, true, 4, "迎面碰撞 · 突破炮台", ""],
	"custom_level_35377": [3, "3-1", 0, 0, false, 4, "计数雏形 · 步进触发", "custom_level_33847"],
	"custom_level_33847": [3, "3-2", 1, 0, false, 5, "状态记忆 · 周期计数", "custom_level_80850"],
	"custom_level_80850": [3, "3-3", 2, 0, false, 5, "多阶时序 · 终极逻辑", ""]
}
const BRANCHES = [["custom_level_81906", "custom_level_86910"]]
const PROGRESS_PATH = "user://campaign_progress.cfg"
static var active_level := ""

static func info(id: String) -> Array:
	return NODES.get(id, [CHAPTERS.size(), "自选", 0, 0, true, 0, "自由构装", ""])

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
