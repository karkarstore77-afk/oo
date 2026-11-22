extends Area2D

@onready var timer: Timer = $Timer
const StoryState: = preload("res://scripts/story_state.gd")
const StoryCheats: = preload("res://scripts/story_cheats.gd")
var _triggered: = false


func _ready() -> void :
	timer.one_shot = true


func _on_body_entered(_body: Node2D) -> void :
	if _triggered:
		return

	if StoryState.active and StoryCheats.god:
		var scene: = get_tree().current_scene
		if scene != null and scene.has_method("god_rescue"):
			scene.call("god_rescue")
			return
	_triggered = true
	StoryState.respawning = true
	GameAudio.play_sfx("explosion")
	timer.start()


func _on_timer_timeout() -> void :
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
