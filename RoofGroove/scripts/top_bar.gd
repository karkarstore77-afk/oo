extends CanvasLayer
## Top toolbar shown on menu screens: avatar, account name, tokens and gems.
## Gems are READ-ONLY here: they are added from Firebase (players/{uid}.gems) only.
## It also adds the calm button hover effect and a soft fade-in to every menu screen.

const UI: = preload("res://scripts/ui_kit.gd")
const Fx: = preload("res://scripts/ui_fx.gd")
const Layout: = preload("res://scripts/menu_layout.gd")
const AvatarFx: = preload("res://scripts/avatar_fx.gd")

var _bar: PanelContainer
var _avatar_slot: Control
var _avatar_key: = ""
var _name_label: Label
var _sub_label: Label
var _tokens_label: Label
var _gems_label: Label
var _accum: = 0.0
var _gems_popup: Control
var _gems_popup_time: = 0

## Developer WhatsApp number (international format, digits only) used by the gems popup.
const DEV_WHATSAPP: = "201149818351"


func _ready() -> void :
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_bar.visible = false
	Economy.tokens_changed.connect(_refresh)
	get_viewport().size_changed.connect(_layout)
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_added.connect(_on_any_node_added)
	_refresh()
	_layout()


func _build() -> void :
	_bar = PanelContainer.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.09, 0.95)
	style.border_color = Color("#3b3f5c")
	style.border_width_bottom = 3
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_bar.add_theme_stylebox_override("panel", style)
	add_child(_bar)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE)
	_bar.custom_minimum_size = Vector2(0, Layout.BAR_HEIGHT)

	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_bar.add_child(row)

	_avatar_slot = Control.new()
	_avatar_slot.custom_minimum_size = Vector2(56, 56)
	_avatar_slot.mouse_filter = Control.MOUSE_FILTER_STOP
	_avatar_slot.gui_input.connect(_on_avatar_input)
	row.add_child(_avatar_slot)

	var names: = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 2)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(names)
	_name_label = UI.label("", 18)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_label.clip_text = true
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(_name_label)
	_sub_label = UI.label("", 11, Color("#a7a9b8"))
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_sub_label.clip_text = true
	_sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(_sub_label)

	var tokens_chip: = _chip(Color(1, 0.85, 0.4))
	_tokens_label = tokens_chip[1]
	row.add_child(tokens_chip[0])
	var gems_chip: = _chip(Color("#5fe3ff"))
	_gems_label = gems_chip[1]
	var gems_panel: PanelContainer = gems_chip[0]
	# An invisible button laid over the chip: it works for mouse and touch and opens the gems info popup.
	var gems_hit: = Button.new()
	gems_hit.flat = true
	gems_hit.focus_mode = Control.FOCUS_NONE
	gems_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	gems_hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		gems_hit.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	gems_hit.pressed.connect(_open_gems_popup)
	gems_panel.add_child(gems_hit)
	row.add_child(gems_panel)


func _chip(color: Color) -> Array:
	var panel: = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s: = StyleBoxFlat.new()
	s.bg_color = Color(color.r, color.g, color.b, 0.14)
	s.border_color = color
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", s)
	var label: = UI.label("", 16, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return [panel, label]


func _process(delta: float) -> void :
	_accum += delta
	if _accum < 0.4:
		return
	_accum = 0.0
	var scene: Node = get_tree().current_scene
	if scene != null and scene.scene_file_path != "":
		_set_bar_visible(Layout.is_menu_scene_path(scene.scene_file_path))
	if _bar.visible:
		_refresh()


func _on_node_added(node: Node) -> void :
	if node == self or node.get_parent() != get_tree().root or node.scene_file_path == "":
		return
	var is_menu: = Layout.is_menu_scene_path(node.scene_file_path)
	_set_bar_visible(is_menu)
	if is_menu and node is Control:
		Fx.fade_in(node as CanvasItem, 0.0, 0.3)


func _set_bar_visible(v: bool) -> void :
	if v == _bar.visible:
		return
	_bar.visible = v
	if v:
		_refresh()
		Fx.fade_in(_bar, 0.0, 0.35)


func _on_any_node_added(node: Node) -> void :
	if node is BaseButton and not node.has_meta("click_sfx"):
		node.set_meta("click_sfx", true)
		var toggle: bool = node is CheckBox or node is CheckButton
		(node as BaseButton).pressed.connect(func() -> void: GameAudio.play_sfx("ui_toggle" if toggle else "ui_click"))
	if node is BaseButton and not (node is CheckBox or node is CheckButton or node is OptionButton or node is MenuButton):
		Fx.attach_button_fx(node as BaseButton)


func _refresh() -> void :
	if _bar == null:
		return
	_name_label.text = Network.player_name
	var sub: = "#" + FriendsSystem.player_id
	if FriendsSystem.profile_badge != "":
		sub += "   " + FriendsSystem.profile_badge
	_sub_label.text = sub
	_tokens_label.text = "%s %d" % [tr("TOKENS"), Economy.balance()]
	_gems_label.text = "%s %d" % [tr("GEMS"), Economy.gem_balance()]
	var badge: String = str(FriendsSystem.profile_badge).to_upper()
	_name_label.add_theme_color_override("font_color", AvatarFx.badge_color(badge) if AvatarFx.is_special(badge) else Color.WHITE)
	var key: = "%s|%d|%s|%d|%d|%d" % [FriendsSystem.profile_letter, FriendsSystem.profile_color, badge, FriendsSystem.profile_shape, FriendsSystem.profile_frame, FriendsSystem.profile_letter_color]
	if key != _avatar_key:
		_avatar_key = key
		for old in _avatar_slot.get_children():
			_avatar_slot.remove_child(old)
			old.queue_free()
		var avatar: = AvatarFx.build(FriendsSystem.profile_letter, FriendsSystem.profile_color, 56.0, badge, AvatarFx.own_extras())
		_avatar_slot.add_child(avatar)
		avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _layout() -> void :
	if _bar == null:
		return
	var top: = 0.0
	if OS.has_feature("mobile"):
		var vp: = get_viewport().get_visible_rect().size
		var win: = Vector2(DisplayServer.window_get_size())
		var safe: = Rect2(DisplayServer.get_display_safe_area())
		if win.y > 0.0:
			top = maxf(0.0, safe.position.y) * vp.y / win.y
	_bar.offset_left = 0.0
	_bar.offset_right = 0.0
	_bar.offset_top = top
	_bar.offset_bottom = top + Layout.BAR_HEIGHT


func _on_avatar_input(event: InputEvent) -> void :
	var pressed: = false
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if not pressed:
		return
	var scene: Node = get_tree().current_scene
	if scene != null and scene.scene_file_path.get_file().get_basename() == "profile_menu":
		return
	if Network.cloud != null and Network.cloud.is_signed_in():
		Network.set_meta("profile_target_uid", Network.cloud.uid)
		Network.set_meta("profile_can_add", false)
	else:
		Network.set_meta("profile_target_uid", "")
	SceneTransition.go("res://sence/profile_menu.tscn")


func _close_gems_popup() -> void :
	if _gems_popup != null and is_instance_valid(_gems_popup):
		_gems_popup.queue_free()
	_gems_popup = null


## Explains how gems work and offers a button that opens WhatsApp with the developer.
func _open_gems_popup() -> void :
	if _gems_popup != null and is_instance_valid(_gems_popup):
		return
	var cyan: = Color("#5fe3ff")
	var vp: = get_viewport().get_visible_rect().size
	var width: = clampf(vp.x - 80.0, 240.0, 460.0)

	var root: = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gems_popup = root
	_gems_popup_time = Time.get_ticks_msec()

	var dim: = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent) -> void :
		# Ignore the tail of the very tap that opened the popup (touch also sends an emulated mouse click).
		if Time.get_ticks_msec() - _gems_popup_time < 400:
			return
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			_close_gems_popup())

	var center: = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel: = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.13, 1.0)
	style.border_color = cyan
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	box.add_child(UI.label(tr("GEMS"), 26, cyan))

	var body: = UI.label(tr("Gems can only be added in three ways: by buying them, by being a VIP, or by beating boss arenas in story mode (10 gems each). For buying or VIP, please send a message to the developer."), 16, Color.WHITE, width)
	body.text_direction = Control.TEXT_DIRECTION_AUTO
	box.add_child(body)

	var contact: = UI.label(tr("To message the developer and understand the details, tap the button below."), 14, Color("#a7a9b8"), width)
	contact.text_direction = Control.TEXT_DIRECTION_AUTO
	box.add_child(contact)

	var wa: = UI.button(tr("MESSAGE THE DEVELOPER ON WHATSAPP"), 16, 52.0)
	wa.theme_type_variation = "PrimaryButton"
	wa.pressed.connect(_open_developer_whatsapp)
	box.add_child(wa)

	var close: = UI.button(tr("CLOSE"), 16, 46.0)
	close.pressed.connect(_close_gems_popup)
	box.add_child(close)

	Fx.fade_in(panel, 0.0, 0.2)


func _open_developer_whatsapp() -> void :
	var msg: = tr("Hello, I would like details about gems in Roof Groove.")
	OS.shell_open("https://wa.me/%s?text=%s" % [DEV_WHATSAPP, msg.uri_encode()])
