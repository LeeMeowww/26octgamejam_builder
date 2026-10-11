extends RefCounted

# Stable IDs keep routes independent of the editor's list ordering.
const CHAPTERS = [
	["基础构装", "从第一块方块开始", "认识六种方块，让简单结构动起来。"],
	["机械工坊", "让零件一起工作", "主线练习编组与空间配合，支线尝试避敌路线。"],
	["自动化前线", "从一发到源源不断", "先补全发射器，再独立搭建生产线；决斗是可选试炼。"],
	["隔离站", "让不同系统协同", "用复制保存样本，用火力守住未来。"]
]
const NODES = {
	"tutorial_01": [0, "0-1", 0, 0, false, 1, "放置摧毁器", "tutorial_02"],
	"tutorial_02": [0, "0-2", 1, 0, false, 1, "推进与编组", "tutorial_03"],
	"tutorial_03": [0, "0-3", 2, 0, false, 1, "复制与朝向", "tutorial_04"],
	"tutorial_04": [0, "0-4", 3, 0, false, 1, "改变方向", "tutorial_05"],
	"tutorial_05": [0, "0-5", 4, 0, false, 1, "抑制与破甲", "level_05"],
	"level_05": [1, "1-1", 1, 0, false, 3, "编组 · 错位抑制 · 双路清理", "custom_level_relay"],
	"level_04": [1, "1-A", 2, 1, true, 2, "路径选择 · 避敌清污", ""],
	"custom_level_relay": [2, "2-1", 0, 0, false, 3, "弹丸模板 · 同步复制 · 周期发射", "custom_level_81605"],
	"custom_level_81605": [2, "2-2", 2, 0, false, 4, "独立构装 · 持续生产", "custom_level_quarantine_backup"],
	"custom_level_86910": [2, "2-A", 3, 1, true, 4, "迎面碰撞 · 突破炮台", ""],
	"custom_level_quarantine_backup": [3, "3-1", 1, 0, false, 4, "双源回收 · 核心保护 · 并行系统", ""]
}
const BRANCHES = [["level_05", "level_04"], ["custom_level_81605", "custom_level_86910"]]
const PROGRESS_PATH = "user://campaign_progress.cfg"
static var active_level := ""

static func info(id: String) -> Array:
	return NODES.get(id, [4, "自选", 0, 0, true, 0, "自由构装", ""])

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
