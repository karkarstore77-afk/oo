extends CanvasLayer
## Optional "send feedback" dialog. Everything is voluntary: the player can close it at any time,
## the email address and the device info are optional. The message goes to OUR server
## (vercel_discord_auth/api/feedback.js) which emails it to the developer; no secret lives in the game.

const UI: = preload("res://scripts/ui_kit.gd")
const Glass: = preload("res://scripts/ui_glass.gd")
const Fx: = preload("res://scripts/ui_fx.gd")

const FEEDBACK_URL: = "https://roofgroove-discord-auth.vercel.app/api/feedback"
const MAX_LEN: = 1000
const MIN_LEN: = 5
const COOLDOWN_SEC: = 30.0

const GOLD: = Color("#ffd666")
const MUTED: = Color(0.8, 0.8, 0.9)

static var _last_sent_at: float = -1000.0

var _category: OptionButton
var _message: TextEdit
var _email: LineEdit
var _device_check: CheckBox
var _send_btn: Button
var _status: Label
var _counter: Label
var _http: HTTPRequest
var _busy: = false


## Opens the dialog on top of whatever is on screen.
static func open(from: Node) -> void :
	var dlg: Node = (load("res://scripts/feedback_dialog.gd") as GDScript).new()
	from.get_tree().root.add_child(dlg)


func _ready() -> void :
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS

	var dim: = ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.08, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center: = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel: = Control.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	if not (OS.has_feature("mobile") or OS.has_feature("web")):
		var glass: = Glass.make_background(28.0)
		panel.add_child(glass)
		glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		var flat: = Panel.new()
		flat.add_theme_stylebox_override("panel", Glass.glass_box(Color(0.12, 0.18, 0.42), 0.86, 0.8, Vector4(0, 0, 0, 0), 1.1, 24))
		panel.add_child(flat)
		flat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: = MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.theme = Glass.dialog_theme()
	panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.minimum_size_changed.connect(func() -> void :
		panel.custom_minimum_size = margin.get_combined_minimum_size())

	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(504, 0)
	margin.add_child(col)

	col.add_child(UI.label("SEND FEEDBACK", 26, GOLD))
	col.add_child(UI.label("OPTIONAL - tell the developer what you think", 13, MUTED, 500.0))

	_category = OptionButton.new()
	_category.add_theme_font_override("font", UI.FONT)
	_category.add_theme_font_size_override("font_size", 16)
	_category.add_item(tr("IDEA"), 0)
	_category.add_item(tr("BUG"), 1)
	_category.add_item(tr("OTHER"), 2)
	_category.custom_minimum_size = Vector2(0, 44)
	col.add_child(_category)

	_message = TextEdit.new()
	_message.custom_minimum_size = Vector2(0, 150)
	_message.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_message.placeholder_text = tr("Write your feedback here")
	_message.add_theme_font_size_override("font_size", 18)
	_message.add_theme_stylebox_override("normal", Glass.field_style())
	_message.add_theme_stylebox_override("focus", Glass.field_style(0.4))
	_message.text_changed.connect(_on_text_changed)
	col.add_child(_message)
	_counter = UI.label("0 / %d" % MAX_LEN, 12, MUTED)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_counter)

	_email = LineEdit.new()
	_email.placeholder_text = tr("Your email (optional, only if you want a reply)")
	_email.max_length = 120
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_email.add_theme_font_size_override("font_size", 16)
	_email.add_theme_stylebox_override("normal", Glass.field_style())
	_email.add_theme_stylebox_override("focus", Glass.field_style(0.4))
	_email.custom_minimum_size = Vector2(0, 44)
	col.add_child(_email)

	_device_check = CheckBox.new()
	_device_check.text = tr("Include game version and device (helps fix bugs)")
	_device_check.button_pressed = true
	_device_check.add_theme_font_override("font", UI.FONT)
	_device_check.add_theme_font_size_override("font_size", 13)
	col.add_child(_device_check)

	_status = UI.label("", 14, GOLD, 500.0)
	col.add_child(_status)

	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var cancel: = UI.button("CANCEL", 18, 50.0)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	_send_btn = UI.button("SEND", 18, 50.0)
	_send_btn.theme_type_variation = &"PrimaryButton"
	_send_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_send_btn)

	cancel.pressed.connect(queue_free)
	_send_btn.pressed.connect(_on_send)

	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_done)

	Fx.fade_in(panel)
	_message.grab_focus()


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_cancel") and not _busy:
		get_viewport().set_input_as_handled()
		queue_free()


func _on_text_changed() -> void :
	if _message.text.length() > MAX_LEN:
		_message.text = _message.text.substr(0, MAX_LEN)
		_message.set_caret_column(MAX_LEN)
	_counter.text = "%d / %d" % [_message.text.length(), MAX_LEN]


func _on_send() -> void :
	if _busy:
		return
	var text: = _message.text.strip_edges()
	if text.length() < MIN_LEN:
		_status.text = tr("Please write a little more")
		return
	var wait: = COOLDOWN_SEC - (Time.get_ticks_msec() / 1000.0 - _last_sent_at)
	if wait > 0.0:
		_status.text = tr("Please wait a moment before sending again")
		return
	var email: = _email.text.strip_edges()
	if email != "" and not email.contains("@"):
		_status.text = tr("That email does not look right")
		return

	var payload: = {
		"category": ["idea", "bug", "other"][_category.selected],
		"message": text,
		"contact": email,
		"lang": Loc.current,
	}
	if _device_check.button_pressed:
		payload["version"] = AppVersion.current()
		payload["build"] = AppVersion.BUILD
		payload["platform"] = OS.get_name()
	_busy = true
	_send_btn.disabled = true
	_status.text = tr("Sending ...")
	var err: = _http.request(FEEDBACK_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_fail()


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void :
	if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
		_last_sent_at = Time.get_ticks_msec() / 1000.0
		_status.text = tr("Thank you! Your feedback was sent")
		await get_tree().create_timer(1.4).timeout
		queue_free()
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		match result:
			HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR:
				_fail(tr("No internet connection. Check it and try again"))
			HTTPRequest.RESULT_TIMEOUT:
				_fail(tr("The connection timed out. Try again"))
			_:
				_fail(tr("Could not send. Check your internet and try again") + " (E%d)" % result)
		return
	var info: Dictionary = {}
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Dictionary:
		info = parsed
	match code:
		404:
			_fail(tr("Feedback service is not installed on the server yet (404)"))
		503:
			_fail(tr("Feedback is not available yet"))
		429:
			_fail(tr("Please wait a moment before sending again"))
		400:
			_fail(tr("The server did not accept the message (400)"))
		502:
			var detail: = str(info.get("detail", "")).left(60)
			var tail: = " (%s %s%s)" % [str(info.get("provider", "mail")), str(info.get("provider_status", "")), (": " + detail) if detail != "" else ""]
			_fail(tr("The server could not send the email. The developer must check the mail settings") + tail)
		_:
			_fail(tr("Server error, try again later") + " (%d)" % code)


func _fail(msg: String = "") -> void :
	_busy = false
	_send_btn.disabled = false
	_status.text = msg if msg != "" else tr("Could not send. Check your internet and try again")
