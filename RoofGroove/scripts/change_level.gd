extends Node2D


func _ready() -> void :
	_style_buttons()
	%Endless.pressed.connect(_on_hard_2_pressed)
	%Hard.pressed.connect(_on_hard_pressed)
	%Back.pressed.connect(_on_back_pressed)


func _style_buttons() -> void :
	var ui: = preload("res://scripts/ui_kit.gd")
	ui.style_button( %Endless, 36, 90.0)
	ui.style_button( %Easy, 30, 90.0)
	ui.style_button( %Normal, 30, 90.0)
	ui.style_button( %Hard, 30, 90.0)
	ui.style_button( %Back, 22, 60.0)


func _on_hard_pressed() -> void :
	SceneTransition.go("res://sence/world.tscn")


func _on_hard_2_pressed() -> void :
	SceneTransition.go("res://sence/world_generated.tscn")


func _on_back_pressed() -> void :
	SceneTransition.go("res://sence/play_menu.tscn")


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()
