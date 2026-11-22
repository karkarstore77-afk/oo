class_name UsernamePrompt
extends CanvasLayer



const UI: = preload("res://scripts/ui_kit.gd")

signal finished

var _edit: LineEdit
var _status: Label
var _btn: Button
var _confirming: = false


static func show_if_needed(parent: Node) -> void :
	if Network.username_locked:
		return
	parent.add_child(UsernamePrompt.new())


func _ready() -> void :
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS

	var dim: = ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.06, 0.96)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box: = VBoxContainer.new()
	box.custom_minimum_size = Vector2(460, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	box.add_child(UI.label("CHOOSE YOUR USERNAME", 26, Color(1, 0.85, 0.4), 460.0))
	box.add_child(UI.label("You can only choose it once. It can NOT be changed later.", 14, Color(0.85, 0.85, 0.9), 460.0))

	_edit = LineEdit.new()
	_edit.max_length = Network.NAME_MAX
	_edit.placeholder_text = "Username"
	_edit.custom_minimum_size = Vector2(460, 48)
	_edit.add_theme_font_override("font", UI.FONT)
	_edit.add_theme_font_size_override("font_size", 18)

	var cur: = Network.player_name
	var def_rx: = RegEx.new()
	def_rx.compile("^Player\\d*$")
	if def_rx.search(cur) == null:
		_edit.text = cur
	_edit.text_changed.connect( func(_t): _reset_confirm())
	_edit.text_submitted.connect( func(_t): _on_pressed())
	box.add_child(_edit)

	_status = UI.label("", 14, Color(1, 0.5, 0.5), 460.0)
	box.add_child(_status)

	_btn = UI.button("CONTINUE", 20, 56.0)
	_btn.pressed.connect(_on_pressed)
	box.add_child(_btn)

	_edit.grab_focus.call_deferred()


func _reset_confirm() -> void :
	_confirming = false
	_btn.text = tr("CONTINUE")
	_status.text = ""


func _on_pressed() -> void :
	var text: = _edit.text.strip_edges()
	if not _confirming:

		var why: = _validate(text)
		if why != "":
			_status.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
			_status.text = tr(why)
			return
		_confirming = true
		_status.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
		_status.text = tr("Your username will be \"%s\" forever. Press CONFIRM to save it.") % text
		_btn.text = tr("CONFIRM")
		return
	var err: = Network.register_username(text)
	if err != "":
		_reset_confirm()
		_status.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
		_status.text = tr(err)
		return
	if Network.cloud != null and Network.cloud.is_signed_in():
		Network.cloud.push_now()
	finished.emit()
	queue_free()



func _validate(text: String) -> String:
	if text.length() < Network.USERNAME_MIN:
		return "Username is too short (min 3 letters)"
	var rx: = RegEx.new()
	rx.compile("^[A-Za-z0-9_\\x{0600}-\\x{06FF}]+$")
	if rx.search(text) == null:
		return "Use letters, numbers and _ only"
	return ""
