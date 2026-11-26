extends Control


const UI: = preload("res://scripts/ui_kit.gd")
const Fx: = preload("res://scripts/ui_fx.gd")


func _ready() -> void :
	var bg: = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 88.0

	var root: = VBoxContainer.new()
	root.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 40.0, 480.0), 0)
	root.add_theme_constant_override("separation", 12)
	center.add_child(root)

	root.add_child(UI.label(tr("ACCOUNT"), 28))
	root.add_child(UI.label(tr("Tokens: %d") % Economy.balance(), 14, Color(1, 0.85, 0.4)))
	root.add_child(UI.label(tr("Gems: %d") % Economy.gem_balance(), 14, Color("#5fe3ff")))

	_add(root, "ACCOUNT", "res://sence/account_menu.tscn")
	var profile: Button = UI.button(tr("PROFILE"), 20, 60.0)
	profile.pressed.connect(_open_profile)
	root.add_child(profile)
	var rank: = UI.button(tr("RANKING"), 20, 60.0)
	rank.pressed.connect( func():
		Network.set_meta("open_ranking", true)
		SceneTransition.go("res://sence/account_menu.tscn"))
	root.add_child(rank)
	_add(root, "SKINS", "res://sence/shop_menu.tscn")
	_add(root, "FRIENDS", "res://sence/friends_menu.tscn")

	var back: = UI.button(tr("BACK"))
	back.pressed.connect(_go_back)
	root.add_child(back)
	var fade_index: = 0
	for child in root.get_children():
		if child is CanvasItem:
			Fx.fade_in(child, minf(float(fade_index) * 0.05, 0.4), 0.3)
		fade_index += 1


func _add(root: Control, text: String, scene: String) -> void :
	var b: = UI.button(tr(text), 20, 60.0)
	if text == "SKINS" and not Roles.allowed("skins"):
		b.disabled = true
	b.pressed.connect( func(): SceneTransition.go(scene))
	root.add_child(b)


func _go_back() -> void :
	SceneTransition.go("res://sence/main_menu.tscn")


func _open_profile() -> void:
	if Network.cloud != null and Network.cloud.is_signed_in():
		Network.set_meta("profile_target_uid", Network.cloud.uid)
		Network.set_meta("profile_can_add", false)
	else:
		Network.set_meta("profile_target_uid", "")
	SceneTransition.go("res://sence/profile_menu.tscn")


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()
