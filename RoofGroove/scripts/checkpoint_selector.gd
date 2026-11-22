extends Control



const UI: = preload("res://scripts/ui_kit.gd")
const SAFE_AREA: = preload("res://scripts/safe_area.gd")

var selected_mode: = 0


func _ready() -> void :
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg: = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var safe: = MarginContainer.new()
	safe.set_script(SAFE_AREA)
	add_child(safe)

	var center: = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe.add_child(center)

	var col: = VBoxContainer.new()
	col.custom_minimum_size = Vector2(640, 0)
	col.add_theme_constant_override("separation", 20)
	center.add_child(col)

	col.add_child(UI.label("CHOOSE YOUR PATH", 36))
	col.add_child(UI.label(tr("LAST CHECKPOINT: %d  |  BEST: %d") % [Network.checkpoint, Network.best_checkpoint], 16, Color(0.8, 0.8, 0.85), 640.0))
	col.add_child(HSeparator.new())

	var opt1: = UI.button(tr("RESUME FROM CHECKPOINT %d") % Network.checkpoint, 20, 56.0)
	opt1.pressed.connect( func(): selected_mode = 0;_start_game())
	col.add_child(opt1)

	var opt2: = UI.button(tr("BEST CHECKPOINT %d") % Network.best_checkpoint, 20, 56.0)
	opt2.pressed.connect( func(): selected_mode = 1;_start_game())
	col.add_child(opt2)

	var opt3: = UI.button("NEW GAME", 20, 56.0)
	opt3.pressed.connect( func(): selected_mode = 2;_start_game())
	col.add_child(opt3)

	var back: = UI.button("BACK", 18, 48.0)
	back.pressed.connect(_go_back)
	col.add_child(back)


func _start_game() -> void :
	match selected_mode:
		0:
			pass
		1:
			Network.checkpoint = Network.best_checkpoint
			Network.checkpoint_seed = 0
		2:
			Network.checkpoint = 0
			Network.checkpoint_seed = 0
	Network.run_active = false
	Network.teleported_run = false
	get_tree().change_scene_to_file("res://sence/world_generated.tscn")


func _go_back() -> void :
	if Network.in_room():
		get_tree().change_scene_to_file("res://sence/lobby_preview.tscn")
	else:
		get_tree().change_scene_to_file("res://sence/online_menu.tscn")


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_cancel"):
		_go_back()
