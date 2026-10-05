class_name BlockView
extends Node2D

const CELL_SIZE: float = 64.0
const HALF_CELL: float = CELL_SIZE * 0.5

var block_data: BlockData
var grid_world: GridWorld
var is_selected: bool = false

# Visual nodes
var inner_sprite: Sprite2D
var inhibited_sprite: Sprite2D
var border_node: Node2D

var _current_tween: Tween

# Textures cache
static var _texture_cache: Dictionary = {}

func _init(p_block: BlockData, p_world: GridWorld) -> void:
	block_data = p_block
	grid_world = p_world
	position = Vector2(block_data.grid_pos.x * CELL_SIZE + HALF_CELL, block_data.grid_pos.y * CELL_SIZE + HALF_CELL)

	# 1. Custom border node
	border_node = Node2D.new()
	border_node.name = "Border"
	border_node.draw.connect(_on_border_draw)
	add_child(border_node)

	# 2. Inner organelle sprite
	inner_sprite = Sprite2D.new()
	inner_sprite.name = "Inner"
	inner_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(inner_sprite)

	# 3. Inhibited overlay sprite
	inhibited_sprite = Sprite2D.new()
	inhibited_sprite.name = "Inhibited"
	inhibited_sprite.texture = _get_cached_texture("res://assets/textures/blocks/inhibited_overlay.svg")
	inhibited_sprite.visible = block_data.is_inhibited
	add_child(inhibited_sprite)

func _ready() -> void:
	update_appearance()

func update_appearance() -> void:
	if block_data == null:
		return

	# Load texture for inner sprite
	var tex_path := _get_texture_path()
	var tex := _get_cached_texture(tex_path)
	if tex != null:
		inner_sprite.texture = tex
		# Scale to fit cell neatly (leaving border margin)
		var scale_factor := (CELL_SIZE - 4.0) / tex.get_width()
		inner_sprite.scale = Vector2(scale_factor, scale_factor)

	# Rotation: direction * 90 degrees
	inner_sprite.rotation = block_data.direction * (PI / 2.0)

	# Inhibited state
	if inhibited_sprite != null:
		inhibited_sprite.visible = block_data.is_inhibited
		if inhibited_sprite.texture != null:
			var scale_factor := (CELL_SIZE) / inhibited_sprite.texture.get_width()
			inhibited_sprite.scale = Vector2(scale_factor, scale_factor)

	# Redraw custom borders
	if border_node != null:
		border_node.queue_redraw()
	queue_redraw()

func _get_texture_path() -> String:
	var btype := block_data.block_type
	var var_idx := posmod(block_data.texture_variant, 3)

	match btype:
		BlockData.Type.BASIC:
			return "res://assets/textures/blocks/basic_%d.svg" % var_idx
		BlockData.Type.INHIBITOR:
			return "res://assets/textures/blocks/inhibitor_%d.svg" % var_idx
		BlockData.Type.PUSHER:
			return "res://assets/textures/blocks/pusher_%d.svg" % var_idx
		BlockData.Type.REPLICATOR:
			return "res://assets/textures/blocks/replicator_%d.svg" % var_idx
		BlockData.Type.DESTROYER:
			return "res://assets/textures/blocks/destroyer_%d.svg" % var_idx
		BlockData.Type.ROTATOR:
			var rot_type := "rotator_cw" if block_data.sub_mode == 0 else "rotator_ccw"
			return "res://assets/textures/blocks/%s_%d.svg" % [rot_type, var_idx]
		BlockData.Type.HARD:
			return "res://assets/textures/blocks/hard_%d.svg" % var_idx
		BlockData.Type.WANDERER:
			return "res://assets/textures/blocks/wanderer_%d.svg" % var_idx
		BlockData.Type.TREASURE:
			return "res://assets/textures/blocks/treasure_%d.svg" % var_idx
		BlockData.Type.POLLUTION:
			return "res://assets/textures/blocks/pollution_%d.svg" % var_idx
		BlockData.Type.PROTECTED:
			return "res://assets/textures/blocks/protected_%d.svg" % var_idx
		_:
			return "res://assets/textures/blocks/basic_0.svg"

static func _get_cached_texture(path: String) -> Texture2D:
	if not _texture_cache.has(path):
		if ResourceLoader.exists(path):
			_texture_cache[path] = load(path)
		else:
			return null
	return _texture_cache[path]

# -------------------------------------------------------------
# Neighbor-Aware Cellular Border Drawing:
# Erases borders between connected blocks in the same structure!
# -------------------------------------------------------------
func _on_border_draw() -> void:
	if block_data == null:
		return

	var sid := block_data.structure_id
	var half := HALF_CELL - 2.0
	var border_color := Color(0.2, 0.7, 0.9, 0.85) if sid > 0 else Color(0.3, 0.4, 0.5, 0.6)
	var bg_color := Color(0.12, 0.18, 0.24, 0.35) if sid > 0 else Color(0.08, 0.1, 0.14, 0.2)
	var width := 3.0 if sid > 0 else 2.0

	# Fill background
	border_node.draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), bg_color, true)

	# Check 4 neighbors
	var right_connected := _is_connected_neighbor(Vector2i(1, 0))
	var down_connected := _is_connected_neighbor(Vector2i(0, 1))
	var left_connected := _is_connected_neighbor(Vector2i(-1, 0))
	var up_connected := _is_connected_neighbor(Vector2i(0, -1))

	# Draw Top border if not connected to up neighbor
	if not up_connected:
		border_node.draw_line(Vector2(-half, -half), Vector2(half, -half), border_color, width)
	# Draw Bottom border if not connected to down neighbor
	if not down_connected:
		border_node.draw_line(Vector2(-half, half), Vector2(half, half), border_color, width)
	# Draw Left border if not connected to left neighbor
	if not left_connected:
		border_node.draw_line(Vector2(-half, -half), Vector2(-half, half), border_color, width)
	# Draw Right border if not connected to right neighbor
	if not right_connected:
		border_node.draw_line(Vector2(half, -half), Vector2(half, half), border_color, width)

func _is_connected_neighbor(offset: Vector2i) -> bool:
	if block_data.structure_id <= 0 or grid_world == null:
		return false
	var neighbor := grid_world.get_block(block_data.grid_pos + offset)
	return neighbor != null and neighbor.structure_id == block_data.structure_id

# -------------------------------------------------------------
# Selection & HP pip drawing
# -------------------------------------------------------------
func _draw() -> void:
	var half := HALF_CELL - 1.0

	# Draw selection highlight
	if is_selected:
		var sel_color := Color(1.0, 0.85, 0.2, 0.9)
		draw_rect(Rect2(-half - 2, -half - 2, (half + 2) * 2, (half + 2) * 2), sel_color, false, 2.5)

	# Draw HP pips if damaged
	if block_data != null and block_data.hp < block_data.max_hp and block_data.hp > 0:
		var pip_radius := 3.0
		var pip_color := Color(0.9, 0.2, 0.2, 0.9)
		draw_circle(Vector2(0, half - 6), pip_radius, pip_color)

# -------------------------------------------------------------
# Smooth Tween Animations for Ticks
# -------------------------------------------------------------
func animate_to_pos(new_grid_pos: Vector2i, duration: float) -> void:
	var target_pos := Vector2(new_grid_pos.x * CELL_SIZE + HALF_CELL, new_grid_pos.y * CELL_SIZE + HALF_CELL)
	if _current_tween != null and _current_tween.is_valid():
		_current_tween.kill()
	_current_tween = create_tween()
	_current_tween.tween_property(self, "position", target_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func animate_rotation(new_dir: int, duration: float) -> void:
	var target_angle := new_dir * (PI / 2.0)
	var current_angle := inner_sprite.rotation
	# Handle wrap-around gracefully
	var diff := wrapf(target_angle - current_angle, -PI, PI)
	var end_angle := current_angle + diff

	var t := create_tween()
	t.tween_property(inner_sprite, "rotation", end_angle, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		inner_sprite.rotation = posmod(new_dir, 4) * (PI / 2.0)
	)

func animate_spawn(duration: float) -> void:
	scale = Vector2(0.1, 0.1)
	modulate = Color(1.5, 2.0, 2.5, 0.0) # Holographic cyan flash
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate", Color.WHITE, duration * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func animate_destroy(duration: float, on_complete: Callable) -> void:
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(0.1, 0.1), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate", Color(2.5, 0.4, 0.4, 0.0), duration)
	t.chain().tween_callback(on_complete)

func animate_damage(duration: float) -> void:
	var t := create_tween()
	t.tween_property(inner_sprite, "modulate", Color(2.5, 0.3, 0.3, 1.0), duration * 0.3)
	t.tween_property(inner_sprite, "modulate", Color.WHITE, duration * 0.7)
	queue_redraw()
