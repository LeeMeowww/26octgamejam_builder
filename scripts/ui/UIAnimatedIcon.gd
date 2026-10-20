class_name UIAnimatedIcon
extends TextureRect

var _texture: Texture2D
var _frames := 1
var _fps := 8.0
var _time := 0.0

func configure(path: String, frame_count: int = 1, fps: float = 8.0, tint: Color = Color.WHITE) -> void:
	_texture = load(path)
	_frames = maxi(frame_count, 1)
	_fps = maxf(fps, 0.01)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if tint != Color.WHITE:
		var material := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = "shader_type canvas_item; uniform vec4 tint : source_color; void fragment() { vec4 tex = texture(TEXTURE, UV); float value = max(max(tex.r, tex.g), tex.b); COLOR = vec4(tint.rgb * value, tex.a * tint.a); }"
		material.shader = shader
		material.set_shader_parameter("tint", tint)
		self.material = material
	_update_frame()

func _process(delta: float) -> void:
	if _texture == null or _frames <= 1:
		return
	_time += delta
	_update_frame()

func _update_frame() -> void:
	if _texture == null:
		return
	var frame_width := _texture.get_width() / _frames
	var atlas := AtlasTexture.new()
	atlas.atlas = _texture
	atlas.region = Rect2(int(_time * _fps) % _frames * frame_width, 0, frame_width, _texture.get_height())
	texture = atlas
