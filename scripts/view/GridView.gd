class_name GridView
extends Node2D

const CELL_SIZE: float = 64.0
const HALF_CELL: float = CELL_SIZE * 0.5

var grid_world: GridWorld
var player_build_area: Rect2i = Rect2i(0, 0, 0, 0)
var is_level_editor_mode: bool = false # If true, can place anywhere regardless of build area
var tutorial_target: Dictionary = {}

# BlockView mapping: block_id -> BlockView
var _views: Dictionary = {}

# Ghost preview for placing
var preview_active: bool = false
var preview_type: int = BlockData.Type.BASIC
var preview_dir: int = BlockData.Direction.RIGHT
var preview_variant: int = 0
var preview_sub_mode: int = 0
var preview_grid_pos: Vector2i = Vector2i.ZERO

# Box selection rectangle (in world coords)
var is_box_selecting: bool = false
var box_select_start: Vector2 = Vector2.ZERO
var box_select_current: Vector2 = Vector2.ZERO

var preview_sprite: Sprite2D

func _ready() -> void:
	preview_sprite = Sprite2D.new()
	preview_sprite.modulate = Color(1.0, 1.0, 1.0, 0.5)
	preview_sprite.z_index = 10
	preview_sprite.visible = false
	add_child(preview_sprite)

func set_world(p_world: GridWorld) -> void:
	if grid_world != null:
		grid_world.block_added.disconnect(_on_block_added)
		grid_world.block_removed.disconnect(_on_block_removed)
		grid_world.structure_changed.disconnect(_on_structure_changed)
		if grid_world.block_moved.is_connected(_on_block_moved):
			grid_world.block_moved.disconnect(_on_block_moved)

	grid_world = p_world
	_clear_all_views()

	if grid_world != null:
		grid_world.block_added.connect(_on_block_added)
		grid_world.block_removed.connect(_on_block_removed)
		grid_world.structure_changed.connect(_on_structure_changed)
		grid_world.block_moved.connect(_on_block_moved)
		for b in grid_world.get_all_blocks():
			_create_view_for_block(b)

	queue_redraw()

func _on_block_moved(b: BlockData, old_pos: Vector2i, new_pos: Vector2i) -> void:
	var v := get_view(b.block_id)
	if v != null:
		v.position = grid_to_world(new_pos)
		v.update_appearance()
	_refresh_neighbor_borders(old_pos)
	_refresh_neighbor_borders(new_pos)

func _clear_all_views() -> void:
	for child in get_children():
		if child is BlockView:
			child.queue_free()
	_views.clear()

func _create_view_for_block(b: BlockData) -> BlockView:
	var view := BlockView.new(b, grid_world)
	_views[b.block_id] = view
	add_child(view)
	return view

func _on_block_added(b: BlockData) -> void:
	if not _views.has(b.block_id):
		_create_view_for_block(b)
	_refresh_neighbor_borders(b.grid_pos)

func _on_block_removed(b: BlockData) -> void:
	if _views.has(b.block_id):
		var v: BlockView = _views[b.block_id]
		_views.erase(b.block_id)
		v.queue_free()
	_refresh_neighbor_borders(b.grid_pos)

func _on_structure_changed(_sid: int) -> void:
	for v: BlockView in _views.values():
		v.update_appearance()

func _refresh_neighbor_borders(pos: Vector2i) -> void:
	for offset in BlockData.DIR_VECTORS:
		var n := grid_world.get_block(pos + offset)
		if n != null and _views.has(n.block_id):
			var nv: BlockView = _views[n.block_id]
			nv.update_appearance()

func get_view(block_id: int) -> BlockView:
	return _views.get(block_id, null)

# Coordinate conversion
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / CELL_SIZE)),
		int(floor(world_pos.y / CELL_SIZE))
	)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * CELL_SIZE + HALF_CELL, grid_pos.y * CELL_SIZE + HALF_CELL)

func is_in_build_area(grid_pos: Vector2i) -> bool:
	if is_level_editor_mode:
		return true
	if player_build_area.size == Vector2i.ZERO:
		return true # Unrestricted
	return player_build_area.has_point(grid_pos)

# -------------------------------------------------------------
# Drawing Grid & Build Area & Selection
# -------------------------------------------------------------
func _draw() -> void:
	# Subtle grid lines around the visible area
	var grid_range := 40
	var line_color := Color(0.12, 0.16, 0.22, 0.4)
	var origin_color := Color(0.2, 0.35, 0.5, 0.7)

	for x in range(-grid_range, grid_range + 1):
		var start := Vector2(x * CELL_SIZE, -grid_range * CELL_SIZE)
		var end := Vector2(x * CELL_SIZE, grid_range * CELL_SIZE)
		var col := origin_color if x == 0 else line_color
		var width := 1.5 if x == 0 else 1.0
		draw_line(start, end, col, width)

	for y in range(-grid_range, grid_range + 1):
		var start := Vector2(-grid_range * CELL_SIZE, y * CELL_SIZE)
		var end := Vector2(grid_range * CELL_SIZE, y * CELL_SIZE)
		var col := origin_color if y == 0 else line_color
		var width := 1.5 if y == 0 else 1.0
		draw_line(start, end, col, width)

	# Draw player build area (if active)
	if player_build_area.size != Vector2i.ZERO:
		var area_rect := Rect2(
			player_build_area.position.x * CELL_SIZE,
			player_build_area.position.y * CELL_SIZE,
			player_build_area.size.x * CELL_SIZE,
			player_build_area.size.y * CELL_SIZE
		)
		# Soft green/cyan tinted zone
		draw_rect(area_rect, Color(0.0, 0.8, 0.5, 0.08), true)
		draw_rect(area_rect, Color(0.0, 0.9, 0.6, 0.6), false, 2.5)

	# Draw Drag Selection Box
	if not tutorial_target.is_empty():
		var target_pos := Vector2i(int(tutorial_target.x), int(tutorial_target.y))
		var target_rect := Rect2(Vector2(target_pos) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
		draw_rect(target_rect.grow(-3), Color(0.4, 1.0, 0.8, 0.2), true)
		draw_rect(target_rect.grow(-3), Color("#80ffd7"), false, 3.0)
		draw_string(ThemeDB.fallback_font, target_rect.position + Vector2(8, -8),
			str(tutorial_target.get("marker", "A")), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#80ffd7"))

	if is_box_selecting:
		var r := Rect2(box_select_start, box_select_current - box_select_start).abs()
		draw_rect(r, Color(0.2, 0.6, 1.0, 0.2), true)
		draw_rect(r, Color(0.4, 0.8, 1.0, 0.8), false, 1.5)

func update_preview(active: bool, btype: int, dir: int, variant: int, sub_mode: int, grid_pos: Vector2i) -> void:
	preview_active = active
	preview_type = btype
	preview_dir = dir
	preview_variant = variant
	preview_sub_mode = sub_mode
	preview_grid_pos = grid_pos

	if not active or preview_sprite == null:
		if preview_sprite != null:
			preview_sprite.visible = false
		return

	preview_sprite.visible = true
	preview_sprite.position = grid_to_world(grid_pos)
	preview_sprite.rotation = dir * (PI / 2.0)

	var tex_path := _get_preview_texture_path(btype, variant, sub_mode)
	var tex := BlockView._get_cached_texture(tex_path)
	if tex != null:
		preview_sprite.texture = tex
		var scale_factor := (CELL_SIZE - 4.0) / tex.get_width()
		preview_sprite.scale = Vector2(scale_factor, scale_factor)

	var can_build := is_in_build_area(grid_pos)
	preview_sprite.modulate = Color(1.0, 1.0, 1.0, 0.6) if can_build else Color(1.0, 0.3, 0.3, 0.6)

func _get_preview_texture_path(btype: int, var_idx: int, sub_mode: int) -> String:
	var v := posmod(var_idx, 3)
	match btype:
		BlockData.Type.BASIC: return "res://assets/textures/blocks/basic_%d.svg" % v
		BlockData.Type.INHIBITOR: return "res://assets/textures/blocks/inhibitor_%d.svg" % v
		BlockData.Type.PUSHER: return "res://assets/textures/blocks/pusher_%d.svg" % v
		BlockData.Type.REPLICATOR: return "res://assets/textures/blocks/replicator_%d.svg" % v
		BlockData.Type.DESTROYER: return "res://assets/textures/blocks/destroyer_%d.svg" % v
		BlockData.Type.ROTATOR:
			var mode_str := "rotator_cw" if sub_mode == 0 else "rotator_ccw"
			return "res://assets/textures/blocks/%s_%d.svg" % [mode_str, v]
		BlockData.Type.HARD: return "res://assets/textures/blocks/hard_%d.svg" % v
		BlockData.Type.WANDERER: return "res://assets/textures/blocks/wanderer_%d.svg" % v
		BlockData.Type.TREASURE: return "res://assets/textures/blocks/treasure_%d.svg" % v
		BlockData.Type.POLLUTION: return "res://assets/textures/blocks/pollution_%d.svg" % v
		_: return "res://assets/textures/blocks/basic_0.svg"

# -------------------------------------------------------------
# Tick Animation Player
# -------------------------------------------------------------
func play_tick_animation(result: SimulationEngine.TickResult, duration: float, on_finish: Callable) -> void:
	# 1. Rotations
	for rot in result.rotated_blocks:
		var v := get_view(rot["id"])
		if v != null:
			v.animate_rotation(rot["new_dir"], duration)

	# 2. Movements
	for mov in result.moved_blocks:
		var v := get_view(mov["id"])
		if v != null:
			v.animate_to_pos(mov["new_pos"], duration)

	# 3. Damages
	for dmg in result.damaged_blocks:
		var v := get_view(dmg["id"])
		if v != null:
			v.animate_damage(duration)

	# 4. Inhibitions
	for v in _views.values():
		v.inhibited_sprite.visible = v.block_data.is_inhibited

	# 5. Spawns
	for spawned_block in result.spawned_blocks:
		var v := get_view(spawned_block.block_id)
		if v == null:
			v = _create_view_for_block(spawned_block)
		v.animate_spawn(duration)

	# 6. Destructions & Collections
	for dest_block in result.destroyed_blocks:
		var v := get_view(dest_block.block_id)
		if v != null:
			v.animate_destroy(duration * 0.8, func():
				if is_instance_valid(v):
					v.queue_free()
			)
			_views.erase(dest_block.block_id)

	for tr_block in result.collected_treasures:
		var v := get_view(tr_block.block_id)
		if v != null:
			v.animate_destroy(duration * 0.8, func():
				if is_instance_valid(v):
					v.queue_free()
			)
			_views.erase(tr_block.block_id)

	# Wait duration then call on_finish
	var t := create_tween()
	t.tween_interval(duration)
	t.tween_callback(func():
		# Refresh borders after animations complete
		for v: BlockView in _views.values():
			v.border_node.queue_redraw()
		on_finish.call()
	)
