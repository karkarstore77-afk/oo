extends Node

const UI := preload("res://scripts/ui_kit.gd")
const IconButton := preload("res://scripts/hud_icon_button.gd")
const FONT: Font = preload("res://fonts/PixelOperator8.ttf")
const MAX_VISIBLE_MESSAGES := 8

# ---- Look & position of the two round buttons (change these to restyle them) -------------------
const BTN_SIZE := 46.0          # diameter of each round button
const BTN_GAP := 8.0            # space between the mic and the chat button
const TOOLBAR_RIGHT := 70.0     # distance from the right edge of the screen
const TOOLBAR_TOP := 58.0       # distance from the top of the screen
const TOAST_SECONDS := 1.8      # how long the small mic/chat message stays visible
# -------------------------------------------------------------------------------------------------

var _panel: PanelContainer
var _feed: Label
var _entry: LineEdit
var _toast: Label
var _mic_button: IconButton
var _chat_button: IconButton
var _toast_tween: Tween
var _messages: Array[String] = []


func _ready() -> void:
	if not Network.in_room():
		queue_free()
		return
	_build_overlay()
	if not Network.chat_received.is_connected(_on_chat_received):
		Network.chat_received.connect(_on_chat_received)
	if not VoiceChat.status_changed.is_connected(_on_voice_status):
		VoiceChat.status_changed.connect(_on_voice_status)
	if not VoiceChat.mic_state_changed.is_connected(_on_mic_state):
		VoiceChat.mic_state_changed.connect(_on_mic_state)
	if not Network.disconnected.is_connected(_on_disconnected):
		Network.disconnected.connect(_on_disconnected)
	_on_mic_state(VoiceChat.is_mic_on())


func _exit_tree() -> void:
	if VoiceChat.status_changed.is_connected(_on_voice_status):
		VoiceChat.status_changed.disconnect(_on_voice_status)
	if VoiceChat.mic_state_changed.is_connected(_on_mic_state):
		VoiceChat.mic_state_changed.disconnect(_on_mic_state)
	if Network.chat_received.is_connected(_on_chat_received):
		Network.chat_received.disconnect(_on_chat_received)
	if Network.disconnected.is_connected(_on_disconnected):
		Network.disconnected.disconnect(_on_disconnected)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 35
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Two small round buttons: microphone (stays on / stays off) and chat.
	var toolbar := HBoxContainer.new()
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toolbar.offset_right = -TOOLBAR_RIGHT
	toolbar.offset_left = -(TOOLBAR_RIGHT + BTN_SIZE * 2.0 + BTN_GAP)
	toolbar.offset_top = TOOLBAR_TOP
	toolbar.offset_bottom = TOOLBAR_TOP + BTN_SIZE
	toolbar.add_theme_constant_override("separation", int(BTN_GAP))
	toolbar.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(toolbar)

	_mic_button = IconButton.new("mic", BTN_SIZE)
	_mic_button.pressed.connect(func() -> void: VoiceChat.toggle_mic())
	_mic_button.disabled = not (GameSettings.voice_on and Roles.allowed("voice"))
	toolbar.add_child(_mic_button)

	_chat_button = IconButton.new("chat", BTN_SIZE)
	_chat_button.pressed.connect(_toggle_chat)
	_chat_button.disabled = not Roles.allowed("chat")
	toolbar.add_child(_chat_button)

	# Small message under the buttons ("MIC ON", "MIC OFF", new chat...). It fades by itself.
	_toast = UI.label("", 11, Color(0.86, 0.87, 0.93), 240.0)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_toast.offset_left = -(TOOLBAR_RIGHT + 240.0)
	_toast.offset_right = -TOOLBAR_RIGHT
	_toast.offset_top = TOOLBAR_TOP + BTN_SIZE + 4.0
	_toast.offset_bottom = TOOLBAR_TOP + BTN_SIZE + 26.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	root.add_child(_toast)

	var panel_top: float = TOOLBAR_TOP + BTN_SIZE + 30.0
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -(TOOLBAR_RIGHT + 252.0)
	_panel.offset_right = -12.0
	_panel.offset_top = panel_top
	_panel.offset_bottom = panel_top + 272.0
	_panel.custom_minimum_size = Vector2(300, 250)
	_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.065, 0.11, 0.94)
	panel_style.border_color = Color(0.45, 0.39, 0.72, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var heading_row := HBoxContainer.new()
	column.add_child(heading_row)
	var heading := UI.label(tr("CHAT"), 16, Color(1.0, 0.84, 0.37))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(heading)
	var close_button := UI.button(tr("CLOSE"), 10, 32.0)
	close_button.pressed.connect(_toggle_chat)
	heading_row.add_child(close_button)

	_feed = Label.new()
	_feed.add_theme_font_override("font", FONT)
	_feed.add_theme_font_size_override("font_size", 13)
	_feed.add_theme_color_override("font_color", Color(0.94, 0.95, 1.0))
	_feed.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.8))
	_feed.add_theme_constant_override("outline_size", 2)
	_feed.custom_minimum_size = Vector2(275, 150)
	_feed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_feed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feed.text_direction = Control.TEXT_DIRECTION_AUTO
	column.add_child(_feed)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 6)
	column.add_child(input_row)
	_entry = LineEdit.new()
	_entry.placeholder_text = tr("TYPE A MESSAGE")
	_entry.max_length = Network.CHAT_MAX_CHARS
	_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry.add_theme_font_override("font", FONT)
	_entry.add_theme_font_size_override("font_size", 13)
	_entry.text_submitted.connect(_send_message)
	input_row.add_child(_entry)
	var send_button := UI.button(tr("SEND"), 11, 38.0)
	send_button.pressed.connect(func() -> void: _send_message(_entry.text))
	input_row.add_child(send_button)


func _toggle_chat() -> void:
	_panel.visible = not _panel.visible
	_chat_button.active = _panel.visible
	if _panel.visible:
		_chat_button.badge = false
		_entry.grab_focus()
	else:
		_entry.release_focus()


func _send_message(raw: String) -> void:
	var message := raw.strip_edges().strip_escapes().replace("\n", " ").replace("\r", " ").left(Network.CHAT_MAX_CHARS)
	if message.is_empty():
		return
	Network.send_chat_message(message)
	_entry.clear()
	_entry.release_focus()


func _on_chat_received(_peer_id: int, player_name: String, message: String) -> void:
	_messages.append("%s: %s" % [player_name.left(Network.NAME_MAX), message.left(Network.CHAT_MAX_CHARS)])
	while _messages.size() > MAX_VISIBLE_MESSAGES:
		_messages.pop_front()
	_feed.text = "\n".join(_messages)
	if not _panel.visible:
		_chat_button.badge = true
		_show_toast(tr("CHAT") + "  •  " + player_name.left(Network.NAME_MAX))


func _on_voice_status(key: String) -> void:
	_show_toast(tr(key))


func _on_mic_state(on: bool) -> void:
	if _mic_button != null:
		_mic_button.active = on


func _show_toast(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func _on_disconnected() -> void:
	queue_free()


func _input(event: InputEvent) -> void:
	# Keyboard shortcut: V opens / closes the microphone (same as tapping the button).
	if event is InputEventKey and event.keycode == KEY_V and event.pressed and not event.echo:
		if _entry == null or not _entry.has_focus():
			if GameSettings.voice_on and Roles.allowed("voice"):
				VoiceChat.toggle_mic()
