class_name EditorClipboard
extends RefCounted

static var _clipboard: Array[BlockData] = []

static func copy(blocks: Array[BlockData]) -> void:
	_clipboard.clear()
	for b in blocks:
		_clipboard.append(b.duplicate_block(false))

static func set_loaded_blocks(blocks: Array[BlockData]) -> void:
	_clipboard.clear()
	for b in blocks:
		_clipboard.append(b.duplicate_block(false))

static func has_blocks() -> bool:
	return not _clipboard.is_empty()

static func get_blocks() -> Array[BlockData]:
	var result: Array[BlockData] = []
	for b in _clipboard:
		result.append(b.duplicate_block(false))
	return result

static func clear() -> void:
	_clipboard.clear()
