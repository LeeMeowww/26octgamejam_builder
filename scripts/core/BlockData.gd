class_name BlockData
extends RefCounted

enum Type {
	BASIC = 0,       # 普通方块 / 体细胞
	INHIBITOR = 1,   # 抑制器 / 突触神经元
	PUSHER = 2,      # 推动器 / 飞虫推进器
	REPLICATOR = 3,  # 复制器 / 有丝分裂器
	DESTROYER = 4,   # 摧毁器 / 溶酶噬菌体
	ROTATOR = 5,     # 转向器 / 纤毛旋转盘
	HARD = 6,        # 坚硬方块 / 几丁质重甲
	WANDERER = 7,    # 游荡怪物 / 异化游荡体
	TREASURE = 8,    # 宝藏 / 高能营养核
	POLLUTION = 9    # 污染源 / 坏疽病原体
}

enum Direction {
	RIGHT = 0, # +X (East)
	DOWN = 1,  # +Y (South)
	LEFT = 2,  # -X (West)
	UP = 3     # -Y (North)
}

const DIR_VECTORS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(0, -1)
]

const TYPE_NAMES: Dictionary = {
	Type.BASIC: "普通方块",
	Type.INHIBITOR: "抑制器",
	Type.PUSHER: "推动器",
	Type.REPLICATOR: "复制器",
	Type.DESTROYER: "摧毁器",
	Type.ROTATOR: "转向器",
	Type.HARD: "坚硬方块",
	Type.WANDERER: "游荡怪物",
	Type.TREASURE: "宝藏",
	Type.POLLUTION: "污染源"
}

const SHORT_NAMES: Dictionary = {
	Type.BASIC: "普通",
	Type.INHIBITOR: "抑制",
	Type.PUSHER: "推动",
	Type.REPLICATOR: "复制",
	Type.DESTROYER: "摧毁",
	Type.ROTATOR: "转向",
	Type.HARD: "坚硬",
	Type.WANDERER: "怪物",
	Type.TREASURE: "宝藏",
	Type.POLLUTION: "污染"
}

var block_id: int = 0
var block_type: int = Type.BASIC
var direction: int = Direction.RIGHT
var grid_pos: Vector2i = Vector2i.ZERO
var structure_id: int = 0
var sub_mode: int = 0 # For Rotator: 0 = CW, 1 = CCW
var texture_variant: int = 0
var hp: int = 2
var max_hp: int = 2
var is_inhibited: bool = false
var is_world_block: bool = false # Level placed vs player placed

static var _id_counter: int = 1

static func generate_new_id() -> int:
	var id := _id_counter
	_id_counter += 1
	return id

static func reset_id_counter(start_id: int = 1) -> void:
	_id_counter = start_id

func _init(p_type: int = Type.BASIC, p_pos: Vector2i = Vector2i.ZERO, p_dir: int = Direction.RIGHT) -> void:
	block_id = generate_new_id()
	block_type = p_type
	grid_pos = p_pos
	direction = posmod(p_dir, 4)
	hp = 2
	max_hp = 2

func get_forward_vec() -> Vector2i:
	return DIR_VECTORS[posmod(direction, 4)]

func get_backward_vec() -> Vector2i:
	return -get_forward_vec()

func rotate_cw() -> void:
	direction = posmod(direction + 1, 4)

func rotate_ccw() -> void:
	direction = posmod(direction + 3, 4)

func rotate_by_step(delta: int) -> void:
	direction = posmod(direction + delta, 4)

func is_player_block() -> bool:
	return block_type >= Type.BASIC and block_type <= Type.ROTATOR

func is_immune() -> bool:
	# 坚硬方块未被抑制时具有免疫性
	if block_type == Type.HARD and not is_inhibited:
		return true
	return false

func duplicate_block(new_id: bool = true) -> BlockData:
	var copy := BlockData.new(block_type, grid_pos, direction)
	if not new_id:
		copy.block_id = block_id
	copy.structure_id = structure_id
	copy.sub_mode = sub_mode
	copy.texture_variant = texture_variant
	copy.hp = hp
	copy.max_hp = max_hp
	copy.is_inhibited = is_inhibited
	copy.is_world_block = is_world_block
	return copy

func to_dict() -> Dictionary:
	return {
		"id": block_id,
		"type": block_type,
		"dir": direction,
		"pos_x": grid_pos.x,
		"pos_y": grid_pos.y,
		"structure_id": structure_id,
		"sub_mode": sub_mode,
		"texture_variant": texture_variant,
		"hp": hp,
		"max_hp": max_hp,
		"is_world_block": is_world_block
	}

static func from_dict(data: Dictionary) -> BlockData:
	var b := BlockData.new(
		int(data.get("type", Type.BASIC)),
		Vector2i(int(data.get("pos_x", 0)), int(data.get("pos_y", 0))),
		int(data.get("dir", Direction.RIGHT))
	)
	b.block_id = int(data.get("id", generate_new_id()))
	if b.block_id >= _id_counter:
		_id_counter = b.block_id + 1
	b.structure_id = int(data.get("structure_id", 0))
	b.sub_mode = int(data.get("sub_mode", 0))
	b.texture_variant = int(data.get("texture_variant", 0))
	b.hp = int(data.get("hp", 2))
	b.max_hp = int(data.get("max_hp", 2))
	b.is_world_block = bool(data.get("is_world_block", false))
	return b
