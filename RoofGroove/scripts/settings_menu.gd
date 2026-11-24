extends Control


const UI: = preload("res://scripts/ui_kit.gd")
const SAFE_AREA: = preload("res://scripts/safe_area.gd")
const MAIN_MENU: = "res://sence/main_menu.tscn"

var _music_check: CheckBox
var _music_slider: HSlider
var _music_value: Label
var _sfx_check: CheckBox
var _notif_check: CheckBox
var _motion_check: CheckBox
var _auto_update_check: CheckBox
var _update_btn: Button
var _update_status: Label


func _ready() -> void :
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg: = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var safe: = MarginContainer.new()
	safe.set_script(SAFE_AREA)
	add_child(safe)

	var scroll: = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	safe.add_child(scroll)

	var center: = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var col: = VBoxContainer.new()
	col.custom_minimum_size = Vector2(640, 0)
	col.add_theme_constant_override("separation", 8)
	center.add_child(col)

	col.add_child(UI.label("SETTINGS", 34))
	col.add_child(HSeparator.new())

	_music_check = _make_check("MUSIC")
	col.add_child(_music_check)
	var music_volume_row := HBoxContainer.new()
	music_volume_row.add_theme_constant_override("separation", 12)
	music_volume_row.add_child(UI.label("MUSIC VOLUME", 14, Color(0.8, 0.8, 0.85)))
	_music_slider = _make_slider()
	music_volume_row.add_child(_music_slider)
	_music_value = UI.label("12%", 14, Color(1.0, 0.85, 0.4), 52.0)
	music_volume_row.add_child(_music_value)
	col.add_child(music_volume_row)
	_sfx_check = _make_check("SOUND EFFECTS")
	col.add_child(_sfx_check)
	col.add_child(HSeparator.new())

	col.add_child(UI.label("LANGUAGE", 16, Color(0.8, 0.8, 0.85)))
	var lang_row: = HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 8)
	for lang_code in Loc.LANGS:
		var lang_btn: = UI.button(str(Loc.LANGS[lang_code]), 16, 44.0)
		lang_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if lang_code == Loc.current:
			lang_btn.modulate = Color(1, 0.85, 0.4)
		lang_btn.pressed.connect(_on_language_pressed.bind(lang_code))
		lang_row.add_child(lang_btn)
	col.add_child(lang_row)
	col.add_child(HSeparator.new())


	_notif_check = _make_check("NOTIFICATIONS (EVERY HOUR)")
	col.add_child(_notif_check)
	if not HourlyNotifier.is_supported():
		_notif_check.text = "NOTIFICATIONS (PHONE ONLY)"
		_notif_check.disabled = true

	_motion_check = _make_check("TILT MOTION EFFECT")
	col.add_child(_motion_check)

	col.add_child(HSeparator.new())


	var ver_label: = UI.label(tr("VERSION %s") % Updater.current_version(), 16, Color(0.8, 0.8, 0.85))
	ver_label.mouse_filter = Control.MOUSE_FILTER_STOP
	col.add_child(ver_label)
	_auto_update_check = _make_check("CHECK FOR UPDATES AUTOMATICALLY")
	col.add_child(_auto_update_check)
	_update_btn = UI.button("CHECK FOR UPDATES NOW", 18, 52.0)
	col.add_child(_update_btn)
	_update_status = UI.label("", 14, Color(1, 0.85, 0.4), 640.0)
	col.add_child(_update_status)

	var back: = UI.button("BACK", 20, 56.0)
	col.add_child(back)


	_music_check.set_pressed_no_signal(GameSettings.music_on)
	_music_slider.set_value_no_signal(GameSettings.music_volume)
	_music_value.text = "%d%%" % roundi(GameSettings.music_volume * 100.0)
	_sfx_check.set_pressed_no_signal(GameSettings.sfx_on)
	_notif_check.set_pressed_no_signal(GameSettings.notifications_on)
	_motion_check.set_pressed_no_signal(GameSettings.motion_on)
	_auto_update_check.set_pressed_no_signal(GameSettings.auto_update)

	_music_check.toggled.connect(_on_music_toggled)
	_music_slider.value_changed.connect(_on_music_volume_changed)
	_sfx_check.toggled.connect(_on_sfx_toggled)
	_notif_check.toggled.connect(_on_notif_toggled)
	_motion_check.toggled.connect(_on_motion_toggled)
	_auto_update_check.toggled.connect(_on_auto_update_toggled)
	_update_btn.pressed.connect(_on_check_pressed)
	back.pressed.connect(_go_back)
	Updater.check_finished.connect(_on_check_finished)

	_show_last_result()



func _exit_tree() -> void :
	GameSettings.save_settings()


func _make_check(text: String) -> CheckBox:
	var c: = CheckBox.new()
	c.text = text
	c.add_theme_font_override("font", UI.FONT)
	c.add_theme_font_size_override("font_size", 18)
	c.custom_minimum_size = Vector2(300, 44)
	return c


func _make_slider() -> HSlider:
	var s: = HSlider.new()
	s.min_value = 0.0
	s.max_value = 0.22
	s.step = 0.01
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(220, 36)
	return s


func _row(left: Control, right: Control) -> HBoxContainer:
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.add_child(left)
	row.add_child(right)
	return row


func _on_music_toggled(on: bool) -> void:
	GameSettings.music_on = on
	GameSettings.apply()


func _on_music_volume_changed(value: float) -> void:
	GameSettings.music_volume = clampf(value, 0.0, 0.22)
	_music_value.text = "%d%%" % roundi(GameSettings.music_volume * 100.0)
	GameSettings.apply()


func _on_sfx_toggled(on: bool) -> void :
	GameSettings.sfx_on = on
	GameSettings.apply()
	if on:
		GameAudio.play_sfx("success")


func _on_notif_toggled(on: bool) -> void :
	GameSettings.notifications_on = on
	GameSettings.apply()
	HourlyNotifier.refresh(on)


func _on_motion_toggled(on: bool) -> void :
	GameSettings.motion_on = on
	GameSettings.apply()


func _on_auto_update_toggled(on: bool) -> void :
	GameSettings.auto_update = on
	GameSettings.apply()


func _on_check_pressed() -> void :
	if Updater.checking:
		return
	_update_status.text = "Checking..."
	_update_btn.disabled = true
	Updater.check(true)


func _on_check_finished(info: Dictionary) -> void :
	_update_btn.disabled = false
	_show_result(info)


func _show_last_result() -> void :
	if not Updater.latest.is_empty():
		_show_result(Updater.latest)


func _show_result(info: Dictionary) -> void :
	if not bool(info.get("ok", false)):
		_update_status.text = str(info.get("error", "Could not check for updates"))
	elif bool(info.get("available", false)):
		_update_status.text = tr("New version %s is available!") % str(info["version"])
	else:
		_update_status.text = "You have the latest version"


func _on_language_pressed(lang_code: String) -> void :
	if lang_code == Loc.current:
		return
	Loc.set_language(lang_code)
	get_tree().reload_current_scene()


func _go_back() -> void :
	SceneTransition.go(MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()
