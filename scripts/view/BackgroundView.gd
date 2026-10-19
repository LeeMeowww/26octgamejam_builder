class_name BackgroundView
extends Node2D

const CELL_SIZE := 64.0
const MAP_MARGIN := 2
var _world: GridWorld
var _build_area := Rect2i()
var _tiles: Dictionary = {}

func _ready() -> void:
	z_index = -20
	for tile_name in [
		"mid", "horizontal edge_up", "horizontal edge_low",
		"Vertical edge_left", "Vertical edge_right",
		"left_up", "right_up", "left_low", "right_low"
	]:
		_tiles[tile_name] = load("res://scenes/animation/background/%s.png" % tile_name)

func set_world(world: GridWorld, build_area: Rect2i) -> void:
	_world = world
	_build_area = build_area
	queue_redraw()

func set_build_area(build_area: Rect2i) -> void:
	if _build_area == build_area:
		return
	_build_area = build_area
	queue_redraw()

func _draw() -> void:
	var bounds := _get_bounds()
	draw_rect(Rect2(Vector2(bounds.position) * CELL_SIZE, Vector2(bounds.size) * CELL_SIZE), Color("09151d"), true)
	if _tiles.is_empty():
		return
	var min_x := bounds.position.x
	var min_y := bounds.position.y
	var max_x := bounds.end.x
	var max_y := bounds.end.y
	for y in range(min_y, max_y, 2):
		for x in range(min_x, max_x, 2):
			var at_left := x == min_x
			var at_right := x + 2 >= max_x
			var at_top := y == min_y
			var at_bottom := y + 2 >= max_y
			var tile_name := "mid"
			if at_left and at_top:
				tile_name = "left_up"
			elif at_right and at_top:
				tile_name = "right_up"
			elif at_left and at_bottom:
				tile_name = "left_low"
			elif at_right and at_bottom:
				tile_name = "right_low"
			elif at_top:
				tile_name = "horizontal edge_up"
			elif at_bottom:
				tile_name = "horizontal edge_low"
			elif at_left:
				tile_name = "Vertical edge_left"
			elif at_right:
				tile_name = "Vertical edge_right"
			var tile: Texture2D = _tiles.get(tile_name)
			if tile != null:
				draw_texture_rect(tile, Rect2(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE * 2.0, CELL_SIZE * 2.0), false)

func _get_bounds() -> Rect2i:
	var points: Array[Vector2i] = []
	if _world != null:
		for block in _world.get_all_blocks():
			points.append(block.grid_pos)
	if _build_area.size != Vector2i.ZERO:
		points.append(_build_area.position)
		points.append(_build_area.end - Vector2i.ONE)
	if points.is_empty():
		return Rect2i(-MAP_MARGIN, -MAP_MARGIN, 16 + MAP_MARGIN * 2, 10 + MAP_MARGIN * 2)
	var min_pos := points[0]
	var max_pos := points[0]
	for point in points:
		min_pos = Vector2i(mini(min_pos.x, point.x), mini(min_pos.y, point.y))
		max_pos = Vector2i(maxi(max_pos.x, point.x), maxi(max_pos.y, point.y))
	min_pos -= Vector2i.ONE * MAP_MARGIN
	max_pos += Vector2i.ONE * MAP_MARGIN
	return Rect2i(min_pos, max_pos - min_pos + Vector2i.ONE)
