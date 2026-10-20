class_name UIAnimatedIcon
extends TextureRect

var _texture: Texture2D
var _frames := 1
var _columns := 1
var _rows := 1
var _fps := 8.0
var _time := 0.0

# columns > 1 把帧按网格排列（先横向后纵向），用于帧序列总宽超过
# WebGL MAX_TEXTURE_SIZE（常见 8192/16384）的大图集，避免纹理上传失败变黑块。
func configure(path: String, frame_count: int = 1, fps: float = 8.0, tint: Color = Color.WHITE, columns: int = 1) -> void:
	_texture = load(path)
	_frames = maxi(frame_count, 1)
	_columns = maxi(columns, 1)
	_rows = ceili(float(_frames) / float(_columns))
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
	# 单行布局保持原始逻辑：帧宽 = 图宽 / 帧数。
	# 网格布局（columns>1）：帧宽 = 图宽 / 列数，帧高 = 图高 / 行数。
	var frame_width: float
	var frame_height: float
	var row := 0
	var column: int
	if _columns <= 1:
		frame_width = _texture.get_width() / float(_frames)
		frame_height = _texture.get_height()
		column = int(_time * _fps) % _frames
	else:
		frame_width = _texture.get_width() / float(_columns)
		frame_height = _texture.get_height() / float(_rows)
		var frame := int(_time * _fps) % _frames
		row = frame / _columns
		column = frame % _columns
	var atlas := AtlasTexture.new()
	atlas.atlas = _texture
	atlas.region = Rect2(column * frame_width, row * frame_height, frame_width, frame_height)
	texture = atlas
