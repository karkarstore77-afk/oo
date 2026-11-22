extends Node







signal time_changed(time_of_day: String)

enum TIME{SUNRISE, MORNING, SUNSET, NIGHT}

const LOBBY_PHASE_SECONDS: = 10.0
const GAME_PHASE_SECONDS: = 60.0

const GAME_SCENES: = ["world_generated", "world", "level_2", "LIVEL 3"]

const TIMES: = {
	TIME.SUNRISE: {"name": "Sunrise", "colors": {
		"sky_top": Color(0.38, 0.45, 0.78), 
		"sky_mid": Color(0.95, 0.62, 0.55), 
		"sky_low": Color(1.0, 0.82, 0.55), 
		"far_body": Color(0.66, 0.55, 0.68), 
		"near_body": Color(0.42, 0.38, 0.58), 
		"cloud_tint": Color(1.0, 0.9, 0.88), 
		"window": Color(1.0, 0.85, 0.6, 0.55), 
	}}, 
	TIME.MORNING: {"name": "Morning", "colors": {
		"sky_top": Color(0.34, 0.6, 0.93), 
		"sky_mid": Color(0.62, 0.82, 0.98), 
		"sky_low": Color(1.0, 0.94, 0.8), 
		"far_body": Color(0.64, 0.74, 0.9), 
		"near_body": Color(0.38, 0.49, 0.7), 
		"cloud_tint": Color(1.0, 1.0, 1.0), 
		"window": Color(0.86, 0.94, 1.0, 0.5), 
	}}, 
	TIME.SUNSET: {"name": "Sunset", "colors": {
		"sky_top": Color(0.99, 0.66, 0.55), 
		"sky_mid": Color(1.0, 0.8, 0.6), 
		"sky_low": Color(1.0, 0.92, 0.7), 
		"far_body": Color(0.7, 0.55, 0.5), 
		"near_body": Color(0.5, 0.4, 0.35), 
		"cloud_tint": Color(1.0, 0.84, 0.76), 
		"window": Color(1.0, 0.82, 0.5, 0.8), 
	}}, 
	TIME.NIGHT: {"name": "Night", "colors": {
		"sky_top": Color(0.08, 0.1, 0.25), 
		"sky_mid": Color(0.2, 0.22, 0.4), 
		"sky_low": Color(0.15, 0.18, 0.35), 
		"far_body": Color(0.15, 0.18, 0.3), 
		"near_body": Color(0.08, 0.1, 0.2), 
		"cloud_tint": Color(0.55, 0.6, 0.85), 
		"window": Color(1.0, 0.88, 0.5, 0.95), 
	}}, 
}

var current_time: int = TIME.MORNING
var _phase_timer: = 0.0

var frozen: = false


func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	current_time = randi() % 4
	_emit_change()


func _process(delta: float) -> void :
	if frozen:
		return
	_phase_timer += delta
	if _phase_timer >= _phase_length():
		_phase_timer = 0.0
		current_time = (current_time + 1) % 4
		_emit_change()



func _phase_length() -> float:
	var scene: = get_tree().current_scene
	if scene != null and scene.scene_file_path != "":
		var scene_name: = scene.scene_file_path.get_file().get_basename()
		if scene_name in GAME_SCENES:
			return GAME_PHASE_SECONDS
	return LOBBY_PHASE_SECONDS



func set_time_of_day(t: int) -> void :
	current_time = clampi(t, 0, 3)
	_phase_timer = 0.0
	_emit_change()


func get_colors() -> Dictionary:
	return TIMES[current_time]["colors"].duplicate()


func get_time_name() -> String:
	return TIMES[current_time]["name"]



func set_lobby_mode(_is_lobby: bool) -> void :
	pass


func _emit_change() -> void :
	time_changed.emit(get_time_name())
