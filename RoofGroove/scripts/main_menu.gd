extends Control

const UI: = preload("res://scripts/ui_kit.gd")
const StoryState: = preload("res://scripts/story_state.gd")
const CheatUI: = preload("res://scripts/story_cheat_ui.gd")

var _title_taps: = 0
var _title_t: = 0.0

var _update_btn: Button


func _ready() -> void :

	Engine.time_scale = 1.0
	get_tree().paused = false


	StoryState.active = false
	StoryState.respawning = false
	Network.leave()
	Network.reset_run()

	var knight: = UI.make_knight(10.0)
	knight.position = Vector2(180, 180)
	Economy.bind(knight)
	%KnightHolder.add_child(knight)
	GyroTilt.attach(knight, 26.0)
	GyroTilt.attach($Safe, 9.0)
	%Version.text = "V" + Updater.current_version()

	UsernamePrompt.show_if_needed(self)

	var menu: VBoxContainer = %Menu
	var play: Button = %PLAY
	var info: Button = %information
	var quit: Button = %QUTE

	var account: = UI.button("ACCOUNT")
	var settings: = UI.button("SETTINGS")
	menu.add_child(account)
	menu.add_child(settings)

	menu.move_child(account, play.get_index() + 1)
	menu.move_child(settings, info.get_index() + 1)
	play.text = "PLAY"
	play.theme_type_variation = &"PrimaryButton"
	quit.theme_type_variation = &"DangerButton"

	for b in [play, info, quit]:
		UI.style_button(b)


	var title: = get_node_or_null("Safe/Center/Row/Menu/Title") as Label
	if title != null:
		title.mouse_filter = Control.MOUSE_FILTER_STOP
		title.gui_input.connect(_on_title_input)

	play.pressed.connect(_on_play_pressed)
	account.pressed.connect(_on_account_pressed)
	settings.pressed.connect(_on_settings_pressed)
	info.pressed.connect(_on_information_pressed)
	quit.pressed.connect(_on_qute_pressed)


	_update_btn = UI.button("UPDATE AVAILABLE")
	_update_btn.modulate = Color(1, 0.85, 0.4)
	_update_btn.visible = false
	menu.add_child(_update_btn)
	menu.move_child(_update_btn, 1)
	_update_btn.pressed.connect(Updater.show_update_dialog)
	Updater.check_finished.connect(_on_update_checked)
	if Network.cloud != null and Network.cloud.has_method("pull_story"):
		Network.cloud.pull_story()
	_refresh_update_btn()


func _on_title_input(event: InputEvent) -> void :
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var now: = Time.get_ticks_msec() / 1000.0
		_title_taps = _title_taps + 1 if now - _title_t < 1.5 else 1
		_title_t = now
		if _title_taps >= 7:
			_title_taps = 0
			CheatUI.open(self)


func _on_update_checked(_info: Dictionary) -> void :
	_refresh_update_btn()


func _refresh_update_btn() -> void :
	_update_btn.visible = bool(Updater.latest.get("available", false))




func _on_play_pressed() -> void :
	SceneTransition.go("res://sence/play_menu.tscn")


func _on_account_pressed() -> void :
	SceneTransition.go("res://sence/account_hub.tscn")


func _on_settings_pressed() -> void :
	SceneTransition.go("res://sence/settings_menu.tscn")


func _on_information_pressed() -> void :
	SceneTransition.go("res://sence/information.tscn")


func _on_qute_pressed() -> void :
	get_tree().quit()
