extends Control


const SCREENS: = [
	"res://sprites/splash_studio.png", 
	"res://sprites/splash_game.png", 
]
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
	# Loading screen (loads all resources), then login screen or main menu.
	SceneTransition.go("res://sence/loading_screen.tscn")
