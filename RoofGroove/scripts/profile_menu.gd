extends Control

const UI: = preload("res://scripts/ui_kit.gd")
const SAFE_AREA: = preload("res://scripts/safe_area.gd")
const Layout: = preload("res://scripts/menu_layout.gd")
const AvatarFx: = preload("res://scripts/avatar_fx.gd")
const Fx: = preload("res://scripts/ui_fx.gd")

const AVATAR_SIZE: = 112
const GOLD: = Color("#ffd666")
const MUTED: = Color("#c5c8d8")

var _uid: String = ""
var _profile: Dictionary = {}
var _letter: OptionButton
var _color_index: int = 0
var _shape: int = 0
var _frame: int = 0
var _letter_color: int = 0
var _badge_choice: String = ""
var _owned: Array = []
var _bio_edit: LineEdit
var _avatar_holder: Control
var _status: Label
var _color_buttons: Array[Button] = []
var _frame_buttons: Array[Button] = []
var _letter_color_buttons: Array[Button] = []
var _shape_buttons: Array[Button] = []
var _badge_buttons: Array[Button] = []
var _badge_values: Array[String] = []
var _is_self: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: = ColorRect.new()
	bg.color = Color("#14141f")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe: = MarginContainer.new()
	safe.set_script(SAFE_AREA)
	add_child(safe)
	for side in ["left", "right", "top", "bottom"]:
		safe.add_theme_constant_override("margin_" + side, 16 + (Layout.SPACE if side == "top" else 0))
	var scroll: = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	safe.add_child(scroll)
	var center: = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var root: = VBoxContainer.new()
	root.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 44.0, 620.0), 0)
	root.add_theme_constant_override("separation", 12)
	center.add_child(root)
	_uid = str(Network.get_meta("profile_target_uid", ""))
	if _uid == "" and Network.cloud != null and Network.cloud.is_signed_in():
		_uid = Network.cloud.uid
	_is_self = Network.cloud != null and Network.cloud.is_signed_in() and _uid == Network.cloud.uid
	root.add_child(UI.label(tr("MY PROFILE" if _is_self else "PLAYER PROFILE"), 28))
	_status = UI.label(tr("Loading profile..."), 13, GOLD)
	root.add_child(_status)
	if _is_self:
		_profile = await FriendsSystem.refresh_own_profile()
	else:
		_profile = await FriendsSystem.fetch_profile(_uid)
	if _profile.is_empty():
		_status.text = tr("Could not load this profile. Sign in and try again.")
		root.add_child(_back_button())
		return
	_status.text = ""
	_build_profile(root)
	GameAudio.play_sfx("ui_open")
	Fx.fade_in(root, 0.0, 0.3)


func _section(root: VBoxContainer, title: String) -> void:
	root.add_child(HSeparator.new())
	root.add_child(UI.label(tr(title), 18, GOLD))


func _build_profile(root: VBoxContainer) -> void:
	_color_index = int(_profile.get("color", 0))
	_shape = int(_profile.get("shape", 0))
	_frame = int(_profile.get("frame", 0))
	_letter_color = int(_profile.get("letter_color", 0))
	_owned = Array(_profile.get("badges", []))
	_badge_choice = str(_profile.get("badge_choice", ""))

	var header: = HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root.add_child(header)
	_avatar_holder = Control.new()
	_avatar_holder.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	_avatar_holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(_avatar_holder)
	_refresh_preview()
	var identity: = VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity)
	identity.add_child(UI.label(str(_profile.get("name", "Player")), 22))
	identity.add_child(UI.label(tr("ID  #%s") % str(_profile.get("player_id", "—")), 14, MUTED))
	var badge: String = str(_profile.get("badge", ""))
	if badge != "":
		identity.add_child(UI.label("♛  " + tr(badge), 19, AvatarFx.badge_color(badge)))
	var online: bool = bool(_profile.get("online", false))
	identity.add_child(UI.label(tr("● ONLINE") if online else tr("○ OFFLINE"), 13, Color("#60e58a") if online else Color("#999baa")))
	var bio: String = str(_profile.get("bio", ""))
	if bio != "":
		var bio_label: = UI.label("“" + bio + "”", 13, Color("#e3e5f1"), 340.0)
		identity.add_child(bio_label)

	root.add_child(HSeparator.new())
	root.add_child(UI.label(tr("PLAYER STATISTICS"), 18, GOLD))
	var stats: = GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 12)
	stats.add_theme_constant_override("v_separation", 8)
	root.add_child(stats)
	_add_stat(stats, tr("Best checkpoint"), str(_profile.get("checkpoints", 0)))
	_add_stat(stats, tr("Current checkpoint"), str(_profile.get("checkpoint", 0)))
	_add_stat(stats, tr("Play time"), Network.format_time(float(_profile.get("best_time", 0.0))))
	_add_stat(stats, tr("Deaths"), str(_profile.get("deaths", 0)))
	_add_stat(stats, tr("Member since"), _date_text(int(_profile.get("member_since", 0))))
	if not _is_self and bool(Network.get_meta("profile_can_add", false)):
		var add: Button = UI.button(tr("SEND FRIEND REQUEST"), 15, 48.0)
		add.pressed.connect(_send_request)
		root.add_child(add)
	if _is_self:
		_build_editor(root)
	if _is_self and not FriendsSystem.inbox_events.is_empty():
		_section(root, "INBOX")
		for event in FriendsSystem.inbox_events:
			root.add_child(UI.label("• " + str(event.get("text", "")), 13, Color("#e3e5f1")))
	root.add_child(_back_button())


func _build_editor(root: VBoxContainer) -> void:
	# ---- letter + colour -------------------------------------------------------------------------
	_section(root, "PROFILE AVATAR")
	var edit_row: = HBoxContainer.new()
	root.add_child(edit_row)
	_letter = OptionButton.new()
	for i in 26:
		_letter.add_item(String.chr(65 + i))
	_letter.select(clampi(str(_profile.get("letter", "A")).unicode_at(0) - 65, 0, 25))
	_letter.item_selected.connect(func(_index): _refresh_preview())
	edit_row.add_child(_letter)
	root.add_child(UI.label(tr("Choose a color"), 13, MUTED))
	var palette: = _flow(root)
	for i in FriendsSystem.PROFILE_COLORS.size():
		var b: = _swatch(FriendsSystem.PROFILE_COLORS[i], i == _color_index)
		b.pressed.connect(_select_color.bind(i))
		palette.add_child(b)
		_color_buttons.append(b)

	# ---- shape -----------------------------------------------------------------------------------
	_section(root, "AVATAR SHAPE")
	var shape_row: = HBoxContainer.new()
	shape_row.add_theme_constant_override("separation", 8)
	root.add_child(shape_row)
	var shape_names: = ["ROUNDED", "CIRCLE", "SQUARE"]
	for i in shape_names.size():
		var sb: Button = UI.button(tr(shape_names[i]), 14, 44.0)
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.pressed.connect(_select_shape.bind(i))
		shape_row.add_child(sb)
		_shape_buttons.append(sb)
	_mark(_shape_buttons, _shape)

	# ---- frame colour ----------------------------------------------------------------------------
	_section(root, "FRAME COLOR")
	var frame_row: = _flow(root)
	for i in 9:
		var fb: = _swatch(AvatarFx.frame_color(i), i == _frame)
		fb.pressed.connect(_select_frame.bind(i))
		frame_row.add_child(fb)
		_frame_buttons.append(fb)
	root.add_child(UI.label(tr("VIP and DEV badges use their own golden / teal frame"), 11, Color("#9fa3b7"), 560.0))

	# ---- letter colour ---------------------------------------------------------------------------
	_section(root, "LETTER COLOR")
	var lc_row: = _flow(root)
	for i in AvatarFx.LETTER_COLORS.size():
		var lb: = _swatch(AvatarFx.LETTER_COLORS[i], i == _letter_color)
		lb.pressed.connect(_select_letter_color.bind(i))
		lc_row.add_child(lb)
		_letter_color_buttons.append(lb)

	# ---- status line -----------------------------------------------------------------------------
	_section(root, "STATUS LINE")
	_bio_edit = LineEdit.new()
	_bio_edit.max_length = FriendsSystem.BIO_MAX
	_bio_edit.placeholder_text = tr("Write something short...")
	_bio_edit.text = str(_profile.get("bio", ""))
	_bio_edit.add_theme_font_override("font", UI.FONT)
	_bio_edit.add_theme_font_size_override("font_size", 14)
	_bio_edit.custom_minimum_size = Vector2(0, 44)
	root.add_child(_bio_edit)

	# ---- badge -----------------------------------------------------------------------------------
	_section(root, "BADGE")
	if _owned.is_empty():
		root.add_child(UI.label(tr("You have no badges yet"), 13, MUTED, 560.0))
	else:
		root.add_child(UI.label(tr("Choose which badge people see, or hide it"), 12, MUTED, 560.0))
		var badge_row: = HBoxContainer.new()
		badge_row.add_theme_constant_override("separation", 8)
		root.add_child(badge_row)
		for owned_badge in _owned:
			_add_badge_button(badge_row, str(owned_badge), "♛ " + tr(str(owned_badge)))
		_add_badge_button(badge_row, "NONE", tr("NO BADGE"))
		_mark_badges()

	var save: Button = UI.button(tr("SAVE PROFILE"), 15, 48.0)
	save.pressed.connect(_save_profile)
	root.add_child(save)


func _flow(root: VBoxContainer) -> HFlowContainer:
	var flow: = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	root.add_child(flow)
	return flow


func _swatch(color: Color, selected: bool) -> Button:
	var b: Button = UI.button("", 14, 40.0)
	b.custom_minimum_size.x = 40
	_style_swatch(b, color, selected)
	return b


func _style_swatch(b: Button, color: Color, selected: bool) -> void:
	var style: = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color.WHITE if selected else Color("#313342")
	style.set_border_width_all(3 if selected else 1)
	style.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", style)
	b.add_theme_stylebox_override("pressed", style)


func _mark(buttons: Array[Button], selected: int) -> void:
	for i in buttons.size():
		buttons[i].modulate = Color(1.0, 0.85, 0.4) if i == selected else Color.WHITE


func _add_badge_button(row: HBoxContainer, value: String, text: String) -> void:
	var b: Button = UI.button(text, 14, 44.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(_select_badge.bind(value))
	row.add_child(b)
	_badge_buttons.append(b)
	_badge_values.append(value)


func _mark_badges() -> void:
	var shown: String = FriendsSystem.pick_badge(_owned, _badge_choice)
	for i in _badge_buttons.size():
		var value: String = _badge_values[i]
		var on: bool = (value == "NONE" and shown == "") or value == shown
		_badge_buttons[i].modulate = Color(1.0, 0.85, 0.4) if on else Color.WHITE


func _refresh_preview() -> void:
	if _avatar_holder == null:
		return
	for old in _avatar_holder.get_children():
		_avatar_holder.remove_child(old)
		old.queue_free()
	var letter: String = _letter.get_item_text(_letter.selected) if _letter != null else str(_profile.get("letter", "A"))
	var badge: String = FriendsSystem.pick_badge(_owned, _badge_choice) if _is_self else str(_profile.get("badge", ""))
	var extras: = {"shape": _shape, "frame": _frame, "letter_color": _letter_color}
	var avatar: Control = AvatarFx.build(letter, _color_index, float(AVATAR_SIZE), badge, extras)
	_avatar_holder.add_child(avatar)
	avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _pop_preview() -> void:
	if _avatar_holder == null:
		return
	_avatar_holder.pivot_offset = _avatar_holder.size * 0.5
	var tw: Tween = _avatar_holder.create_tween()
	tw.tween_property(_avatar_holder, "scale", Vector2(1.12, 1.12), 0.08)
	tw.tween_property(_avatar_holder, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _add_stat(grid: GridContainer, title: String, value: String) -> void:
	var panel: = PanelContainer.new()
	var style: = StyleBoxFlat.new()
	style.bg_color = Color("#20212e")
	style.border_color = Color("#38394c")
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	box.add_child(UI.label(title, 11, Color("#9fa3b7")))
	box.add_child(UI.label(value, 15, Color.WHITE))
	grid.add_child(panel)


func _select_color(index: int) -> void:
	_color_index = index
	for i in _color_buttons.size():
		_style_swatch(_color_buttons[i], FriendsSystem.PROFILE_COLORS[i], i == _color_index)
	_refresh_preview()
	_pop_preview()


func _select_shape(index: int) -> void:
	_shape = index
	_mark(_shape_buttons, _shape)
	_refresh_preview()
	_pop_preview()


func _select_frame(index: int) -> void:
	_frame = index
	for i in _frame_buttons.size():
		_style_swatch(_frame_buttons[i], AvatarFx.frame_color(i), i == _frame)
	_refresh_preview()
	_pop_preview()


func _select_letter_color(index: int) -> void:
	_letter_color = index
	for i in _letter_color_buttons.size():
		_style_swatch(_letter_color_buttons[i], AvatarFx.LETTER_COLORS[i], i == _letter_color)
	_refresh_preview()
	_pop_preview()


func _select_badge(value: String) -> void:
	_badge_choice = value
	_mark_badges()
	_refresh_preview()
	_pop_preview()


func _save_profile() -> void:
	if _letter == null:
		return
	_status.text = tr("Saving...")
	var extra: = {
		"shape": _shape,
		"frame": _frame,
		"letter_color": _letter_color,
		"bio": _bio_edit.text if _bio_edit != null else "",
		"badge_choice": _badge_choice,
	}
	var result: Dictionary = await FriendsSystem.save_profile(_letter.get_item_text(_letter.selected), _color_index, extra)
	_status.text = tr(str(result.get("message", "")))
	if result.get("ok", false):
		GameAudio.play_sfx("success")
		_refresh_preview()
		_pop_preview()
		if _avatar_holder != null:
			Fx.burst(self, _avatar_holder.global_position + _avatar_holder.size * 0.5, Color("#ffd447"), 18, 130.0)
	else:
		GameAudio.play_sfx("error")


func _send_request() -> void:
	_status.text = tr("Sending request...")
	var result: Dictionary = await FriendsSystem.send_friend_request(_profile)
	_status.text = tr(str(result.get("message", "")))
	GameAudio.play_sfx("success" if result.get("ok", false) else "error")


func _date_text(unix_time: int) -> String:
	if unix_time <= 0:
		return tr("Unknown")
	var date: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02d" % [date.year, date.month, date.day]


func _back_button() -> Button:
	var back: Button = UI.button(tr("BACK"), 16, 46.0)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://sence/friends_menu.tscn") if not _is_self else get_tree().change_scene_to_file("res://sence/account_hub.tscn"))
	return back
