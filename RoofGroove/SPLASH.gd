extends Control


const SCREENS: = [
	"res://sprites/splash_studio.png", 
	"res://sprites/splash_game.png", 
]
const LoginMenu: = preload("res://scripts/login_menu.gd")
const FADE: = 0.5
const HOLD: = [1.8, 2.3]

var _done: = false


func _ready() -> void :
	var bg: = ColorRect.new()
	bg.color = Color.BLACK
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var tween: = create_tween()
	for i in SCREENS.size():
		var tex: = load(SCREENS[i]) as Texture2D
		if tex == null:
			continue
		var rect: = TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.modulate.a = 0.0
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tween.tween_property(rect, "modulate:a", 1.0, FADE)
		tween.tween_interval(HOLD[i])
		tween.tween_property(rect, "modulate:a", 0.0, FADE)
	tween.tween_callback(_go)


func _input(event: InputEvent) -> void :
	if _done:
		return
	if (event is InputEventScreenTouch and event.pressed)\
	or (event is InputEventMouseButton and event.pressed)\
	or (event is InputEventKey and event.pressed and not event.echo):
		_go()


func _go() -> void :
	if _done:
		return
	_done = true
	# Not signed in yet (and did not choose "play without account") -> show the sign in screen first.
	var target: = "res://sence/main_menu.tscn"
	var c: Node = Network.cloud
	if c != null and c.is_configured() and not c.is_signed_in() and not c.banned and not LoginMenu.guest_chosen():
		target = "res://sence/login_menu.tscn"
	get_tree().change_scene_to_file(target)
