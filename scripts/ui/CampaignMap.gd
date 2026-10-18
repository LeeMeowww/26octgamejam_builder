extends Control

var routes: Array = []

func _draw() -> void:
	for x in range(24, int(size.x), 32):
		for y in range(24, int(size.y), 32):
			draw_circle(Vector2(x, y), 1.0, Color("243743"))
	for route in routes:
		var a: Vector2 = route[0]
		var b: Vector2 = route[1]
		draw_line(a, b, Color("62bfae"), 4, true)
