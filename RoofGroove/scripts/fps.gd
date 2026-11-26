extends Label

func _ready() -> void :
	visible = GameSettings.show_fps
	if not GameSettings.changed.is_connected(_on_settings_changed):
		GameSettings.changed.connect(_on_settings_changed)


func _on_settings_changed() -> void :
	visible = GameSettings.show_fps


func _process(_delta: float) -> void :
	if visible:
		text = "FPS: %d" % Engine.get_frames_per_second()
