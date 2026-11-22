extends Node

const MUSIC_PATH := "res://music/gameplay_calm.mp3"
const MUSIC_BUS := "Music"
const MUSIC_GAIN_LIMIT := 0.22

var _music_player: AudioStreamPlayer
var _ducked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_music_bus()
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "CalmMusic"
	_music_player.bus = MUSIC_BUS
	_music_player.volume_db = -24.0
	add_child(_music_player)
	if ResourceLoader.exists(MUSIC_PATH):
		var stream := load(MUSIC_PATH) as AudioStreamMP3
		if stream != null:
			stream.loop = true
			_music_player.stream = stream
	if not GameSettings.changed.is_connected(apply_settings):
		GameSettings.changed.connect(apply_settings)
	apply_settings()


func _ensure_music_bus() -> void:
	var index := AudioServer.get_bus_index(MUSIC_BUS)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, MUSIC_BUS)
		AudioServer.set_bus_send(index, "Master")


func apply_settings() -> void:
	if _music_player == null or not is_instance_valid(_music_player):
		return
	var index := AudioServer.get_bus_index(MUSIC_BUS)
	if index < 0:
		return
	var volume := clampf(float(GameSettings.music_volume), 0.0, MUSIC_GAIN_LIMIT)
	if _ducked:
		volume *= 0.28
	AudioServer.set_bus_mute(index, not GameSettings.music_on or volume <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	if GameSettings.music_on and volume > 0.001:
		play_music()
	else:
		_music_player.stop()


func play_music() -> void:
	if _music_player != null and _music_player.stream != null and not _music_player.playing and GameSettings.music_on:
		_music_player.play()


func duck(on: bool) -> void:
	_ducked = on
	apply_settings()


# ---- Sound effects ----------------------------------------------------------------------------
# Small retro sounds are generated in code (no audio files needed). They obey Settings > SOUND EFFECTS.
const SFX_RATE := 22050
const SFX_POOL := 8
const SFX_GAIN := 0.5

# name -> {notes: [[freq_start, freq_end, seconds], ...], wave: "sine"|"square"|"noise", vol: 0..1}
const SFX_DEFS := {
	"tap": {"notes": [[880.0, 700.0, 0.05]], "wave": "sine", "vol": 0.55},
	"ui_click": {"notes": [[940.0, 760.0, 0.05]], "wave": "sine", "vol": 0.5},
	"ui_open": {"notes": [[420.0, 640.0, 0.09]], "wave": "sine", "vol": 0.5},
	"ui_back": {"notes": [[620.0, 380.0, 0.08]], "wave": "sine", "vol": 0.5},
	"ui_toggle": {"notes": [[700.0, 900.0, 0.06]], "wave": "square", "vol": 0.28},
	"jump": {"notes": [[300.0, 640.0, 0.12]], "wave": "square", "vol": 0.22},
	"hurt": {"notes": [[260.0, 110.0, 0.2]], "wave": "square", "vol": 0.35},
	"explosion": {"notes": [[0.0, 0.0, 0.38]], "wave": "noise", "vol": 0.6},
	"power_up": {"notes": [[520.0, 520.0, 0.06], [660.0, 660.0, 0.06], [880.0, 880.0, 0.1]], "wave": "square", "vol": 0.3},
	"success": {"notes": [[660.0, 660.0, 0.07], [880.0, 880.0, 0.07], [1100.0, 1100.0, 0.07], [1320.0, 1320.0, 0.16]], "wave": "sine", "vol": 0.55},
	"error": {"notes": [[220.0, 220.0, 0.09], [160.0, 160.0, 0.16]], "wave": "square", "vol": 0.3},
	"sparkle": {"notes": [[1400.0, 1900.0, 0.07], [1800.0, 2400.0, 0.1]], "wave": "sine", "vol": 0.35},
}

var _sfx_cache: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []


func _sfx_ensure_pool() -> void:
	if not _sfx_players.is_empty():
		return
	for i in SFX_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)


func _sfx_build(sfx_name: String) -> AudioStreamWAV:
	if _sfx_cache.has(sfx_name):
		return _sfx_cache[sfx_name]
	if not SFX_DEFS.has(sfx_name):
		return null
	var def: Dictionary = SFX_DEFS[sfx_name]
	var wave: String = str(def["wave"])
	var data := PackedByteArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var phase := 0.0
	var low := 0.0
	for note in def["notes"]:
		var f0: float = float(note[0])
		var f1: float = float(note[1])
		var count := int(float(note[2]) * SFX_RATE)
		var chunk := PackedByteArray()
		chunk.resize(count * 2)
		for i in count:
			var u := float(i) / float(maxi(count - 1, 1))
			var env := pow(1.0 - u, 1.6) * minf(1.0, float(i) / 90.0)
			var sample := 0.0
			if wave == "noise":
				low += (rng.randf_range(-1.0, 1.0) - low) * 0.35
				sample = low * 2.0
			else:
				phase += TAU * lerpf(f0, f1, u) / SFX_RATE
				sample = sin(phase)
				if wave == "square":
					sample = 1.0 if sample >= 0.0 else -1.0
			chunk.encode_s16(i * 2, clampi(int(sample * env * float(def["vol"]) * 32000.0), -32768, 32767))
		data.append_array(chunk)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SFX_RATE
	stream.stereo = false
	stream.data = data
	_sfx_cache[sfx_name] = stream
	return stream


func play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	if not GameSettings.sfx_on or GameSettings.sfx_volume <= 0.001:
		return
	var stream := _sfx_build(sfx_name)
	if stream == null:
		return
	_sfx_ensure_pool()
	var player: AudioStreamPlayer = null
	for p in _sfx_players:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _sfx_players[0]
	player.stream = stream
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.volume_db = linear_to_db(clampf(GameSettings.sfx_volume * SFX_GAIN, 0.0001, 1.0))
	player.play()
