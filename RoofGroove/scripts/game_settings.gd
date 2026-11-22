extends Node



signal changed

const PATH: = "user://settings.cfg"

var music_on: = true
var sfx_on: = true
var voice_on: = true
var music_volume: = 0.12
var sfx_volume: = 1.0
var notifications_on: = true
var motion_on: = true
var auto_update: = true
var language: = ""


func _ready() -> void :
	load_settings()


func load_settings() -> void :
	var cfg: = ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	music_on = bool(cfg.get_value("audio", "music_on", music_on))
	sfx_on = bool(cfg.get_value("audio", "sfx_on", sfx_on))
	voice_on = bool(cfg.get_value("audio", "voice_on", voice_on))
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 0.22)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	notifications_on = bool(cfg.get_value("game", "notifications_on", notifications_on))
	motion_on = bool(cfg.get_value("game", "motion_on", motion_on))
	auto_update = bool(cfg.get_value("game", "auto_update", auto_update))
	language = str(cfg.get_value("game", "language", language))
	changed.emit()



func apply() -> void :
	changed.emit()


func save_settings() -> void :
	var cfg: = ConfigFile.new()
	cfg.set_value("audio", "music_on", music_on)
	cfg.set_value("audio", "sfx_on", sfx_on)
	cfg.set_value("audio", "voice_on", voice_on)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("game", "notifications_on", notifications_on)
	cfg.set_value("game", "motion_on", motion_on)
	cfg.set_value("game", "auto_update", auto_update)
	cfg.set_value("game", "language", language)
	cfg.save(PATH)
