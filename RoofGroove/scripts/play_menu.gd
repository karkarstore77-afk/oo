extends Control


const UI: = preload("res://scripts/ui_kit.gd")
const Cutscene: = preload("res://scripts/cutscene.gd")
const StoryData: = preload("res://scripts/story_data.gd")
const StoryState: = preload("res://scripts/story_state.gd")


func _ready() -> void :
	# Story texts, tips and monsters belong to story mode only: leaving it resets the flag.
	StoryState.active = false
	StoryState.respawning = false
	Engine.time_scale = 1.0
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

	root.add_child(UI.label("PLAY", 28))

	var story: = UI.button("STORY MODE", 22, 72.0)
	story.theme_type_variation = &"GoldButton"
	story.pressed.connect(_start_story)
	root.add_child(story)

	var online: = UI.button("ONLINE / LAN", 20, 64.0)
	online.disabled = not Roles.allowed("online")
	online.pressed.connect( func(): SceneTransition.go("res://sence/online_menu.tscn"))
	root.add_child(online)

	var offline: = UI.button("OFFLINE", 20, 64.0)
	offline.pressed.connect( func(): SceneTransition.go("res://sence/change_level.tscn"))
	root.add_child(offline)

	var worlds: = UI.button("WORLDS", 20, 64.0)
	worlds.disabled = not Roles.allowed("worlds")
	worlds.pressed.connect( func(): SceneTransition.go("res://sence/worlds_menu.tscn"))
	root.add_child(worlds)

	var back: = UI.button("BACK")
	back.pressed.connect(_go_back)
	root.add_child(back)



func _start_story() -> void :
	StoryState.load_state()
	StoryState.active = true
	StoryState.respawning = false
	if not StoryState.intro_seen:
		StoryState.mark_intro_seen()
		Cutscene.play(get_tree(), StoryData.intro(), StoryData.WORLD_SCENE)
	else:
		SceneTransition.go(StoryData.WORLD_SCENE)


func _go_back() -> void :
	SceneTransition.go("res://sence/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()
