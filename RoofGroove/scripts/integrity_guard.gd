extends Node

const MANIFEST_PATH: String = "res://integrity_manifest.json"
const CHUNK_YIELD: int = 24
const PIXEL_FONT: Font = preload("res://fonts/PixelOperator8.ttf")

var _failed_files: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_verify.call_deferred()


func _verify() -> void:
	if OS.has_feature("editor"):
		return
	var manifest_file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if manifest_file == null:
		_failed_files.append("integrity_manifest.json")
		_show_error()
		return
	var parsed: Variant = JSON.parse_string(manifest_file.get_as_text())
	manifest_file.close()
	if not (parsed is Dictionary) or not (parsed.get("files", []) is Array):
		_failed_files.append("integrity_manifest.json")
		_show_error()
		return
	var checked: int = 0
	for item in parsed["files"]:
		if not (item is Dictionary):
			continue
		var path: String = str(item.get("path", ""))
		var expected: String = str(item.get("sha256", ""))
		if path == "" or expected == "":
			continue
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			_failed_files.append(path.get_file())
			continue
		var bytes: PackedByteArray = file.get_buffer(file.get_length())
		file.close()
		var context: = HashingContext.new()
		if context.start(HashingContext.HASH_SHA256) != OK or context.update(bytes) != OK:
			_failed_files.append(path.get_file())
			continue
		var actual: String = context.finish().hex_encode()
		checked += 1
		if actual != expected:
			_failed_files.append(path.get_file())
		if checked > 0 and checked % CHUNK_YIELD == 0:
			await get_tree().process_frame
	if checked == 0:
		_failed_files.append("game resources")
	if not _failed_files.is_empty():
		_show_error()


func _show_error() -> void:
	get_tree().paused = true
	var layer: = CanvasLayer.new()
	layer.layer = 250
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var shade: = ColorRect.new()
	shade.color = Color("#11111b")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: = CenterContainer.new()
	layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: = PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(get_viewport().get_visible_rect().size.x - 36.0, 600.0), 0.0)
	center.add_child(panel)
	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title: = Label.new()
	title.text = tr("GAME FILES CHANGED")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", PIXEL_FONT)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#ffd666"))
	box.add_child(title)
	var detail: = Label.new()
	detail.text = tr("Game files have changed or are damaged. Reinstall the game to continue.")
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_override("font", PIXEL_FONT)
	detail.add_theme_font_size_override("font_size", 16)
	box.add_child(detail)
	var quit: = Button.new()
	quit.text = tr("CLOSE GAME")
	quit.custom_minimum_size.y = 48.0
	quit.add_theme_font_override("font", PIXEL_FONT)
	quit.pressed.connect(func(): get_tree().quit())
	box.add_child(quit)
