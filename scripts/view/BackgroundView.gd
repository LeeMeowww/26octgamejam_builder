class_name BackgroundView
extends Node2D

const CELL_SIZE := 64.0
const TILE_CELLS := 2

var _bounds := Rect2i(-2, -2, 4, 4)
var _textures: Dictionary = {}

func _ready() -> void:
	z_index = -10
	_load_textures()
	queue_redraw()

func set_bounds(world: GridWorld, build_area: Rect2i) -> void:
	var source: Rect2i = world.get_bounds() if world != null else Rect2i()
	if build_area.size != Vector2i.ZERO:
		source = source.merge(build_area)
	if source.size == Vector2i.ZERO:
		source = Rect2i(0, 0, 1, 1)
	var min_x := floori(float(source.position.x - TILE_CELLS) / TILE_CELLS) * TILE_CELLS
	var min_y := floori(float(source.position.y - TILE_CELLS) / TILE_CELLS) * TILE_CELLS
	var max_x := ceili(float(source.end.x + TILE_CELLS) / TILE_CELLS) * TILE_CELLS
	var max_y := ceili(float(source.end.y + TILE_CELLS) / TILE_CELLS) * TILE_CELLS
	_bounds = Rect2i(min_x, min_y, maxi(TILE_CELLS, max_x - min_x), maxi(TILE_CELLS, max_y - min_y))
	queue_redraw()

func _load_textures() -> void:
	var names := {
		"left_up": "left_up.png",
		"top": "horizontal edge_up.png",
		"right_up": "right_up.png",
		"left_low": "left_low.png",
		"bottom": "horizontal edge_low.png",
		"right_low": "right_low.png",
		"left": "Vertical edge_left.png",
		"mid": "mid.png",
		"right": "Vertical edge_right.png"
	}
	for key in names:
		_textures[key] = load("res://scenes/animation/background/" + names[key])

func _draw() -> void:
	var columns: int = int(_bounds.size.x / TILE_CELLS)
	var rows: int = int(_bounds.size.y / TILE_CELLS)
	for row in range(rows):
		for column in range(columns):
			var texture: Texture2D = _textures.get(_tile_key(column, row, columns, rows))
			if texture == null:
				continue
			var cell_pos := Vector2(_bounds.position.x + column * TILE_CELLS, _bounds.position.y + row * TILE_CELLS)
			draw_texture_rect(texture, Rect2(cell_pos * CELL_SIZE, Vector2.ONE * CELL_SIZE * TILE_CELLS), false)

func _tile_key(column: int, row: int, columns: int, rows: int) -> String:
	if columns == 1 or rows == 1:
		return "mid"
	var top := row == 0
	var bottom := row == rows - 1
	var left := column == 0
	var right := column == columns - 1
	if top and left: return "left_up"
	if top and right: return "right_up"
	if bottom and left: return "left_low"
	if bottom and right: return "right_low"
	if top: return "top"
	if bottom: return "bottom"
	if left: return "left"
	if right: return "right"
	return "mid"
