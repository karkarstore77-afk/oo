extends Node

signal status_changed(key: String)
## Fired whenever the microphone really starts or stops transmitting.
signal mic_state_changed(on: bool)

const SAMPLE_RATE := 16000
const FRAME_SAMPLES := 320 # 20 ms at 16 kHz
const FRAME_BYTES := FRAME_SAMPLES * 2
const SILENCE_GATE := 0.003
const ANDROID_MIC_PERMISSION := "android.permission.RECORD_AUDIO"

var _capture: AudioEffectCapture
var _mic_player: AudioStreamPlayer
var _sending := false
var _was_in_room := false
var _outputs: Dictionary = {}
# The mic is a toggle: the player taps once to open it and once to close it.
# _mic_wanted is the player's choice; it survives the app going to the background.
var _mic_wanted := false
var _waiting_permission := false
var _permission_deadline := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("VoiceCapture")
	_ensure_bus("VoiceOutput")
	var capture_bus := AudioServer.get_bus_index("VoiceCapture")
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 0.5
	AudioServer.add_bus_effect(capture_bus, _capture)
	# Silence local microphone monitoring after the capture tap.
	var silent_monitor := AudioEffectAmplify.new()
	silent_monitor.volume_db = -80.0
	AudioServer.add_bus_effect(capture_bus, silent_monitor)
	var output_bus := AudioServer.get_bus_index("VoiceOutput")
	AudioServer.set_bus_volume_db(output_bus, -6.0)
	_mic_player = AudioStreamPlayer.new()
	_mic_player.name = "MicrophoneInput"
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = "VoiceCapture"
	add_child(_mic_player)
	if not Network.voice_packet_received.is_connected(_on_voice_packet):
		Network.voice_packet_received.connect(_on_voice_packet)
	if not Network.peer_left.is_connected(_on_peer_left):
		Network.peer_left.connect(_on_peer_left)
	if not Network.disconnected.is_connected(_on_disconnected):
		Network.disconnected.connect(_on_disconnected)


func _ensure_bus(bus_name: String) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		return
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func is_mic_on() -> bool:
	return _sending


func toggle_mic() -> void:
	set_mic(not _mic_wanted)


func set_mic(on: bool) -> void:
	if not on:
		_mic_wanted = false
		_waiting_permission = false
		var was_sending := _sending
		_stop_transmitting()
		if not was_sending:
			status_changed.emit("MIC OFF")
		return
	_mic_wanted = true
	_start_transmitting()


func _start_transmitting() -> void:
	if _sending:
		return
	if not Network.in_room():
		_give_up("VOICE REQUIRES A MULTIPLAYER ROOM")
		return
	if Network.members.size() > Network.VOICE_MAX_MEMBERS:
		_give_up("VOICE CHAT SUPPORTS UP TO 16 PLAYERS")
		return
	if OS.has_feature("android") and not OS.get_granted_permissions().has(ANDROID_MIC_PERMISSION):
		if not _waiting_permission:
			_waiting_permission = true
			_permission_deadline = Time.get_ticks_msec() + 60000
			OS.request_permission(ANDROID_MIC_PERMISSION)
			status_changed.emit("ALLOW MICROPHONE ACCESS")
		return
	_waiting_permission = false
	_capture.clear_buffer()
	_mic_player.play()
	_sending = true
	_was_in_room = true
	status_changed.emit("MIC ON - TAP TO MUTE")
	mic_state_changed.emit(true)


func _give_up(key: String) -> void:
	_mic_wanted = false
	_waiting_permission = false
	status_changed.emit(key)
	mic_state_changed.emit(false)


func _stop_transmitting() -> void:
	var was_sending := _sending
	_sending = false
	if _mic_player != null and _mic_player.playing:
		_mic_player.stop()
	if _capture != null:
		_capture.clear_buffer()
	if was_sending:
		status_changed.emit("MIC OFF")
		mic_state_changed.emit(false)


func _process(_delta: float) -> void:
	if not Network.in_room() and (_was_in_room or _sending or _mic_wanted or not _outputs.is_empty()):
		_was_in_room = false
		_mic_wanted = false
		_waiting_permission = false
		_stop_transmitting()
		_clear_outputs()
	if _waiting_permission:
		if OS.get_granted_permissions().has(ANDROID_MIC_PERMISSION):
			_start_transmitting()
		elif Time.get_ticks_msec() > _permission_deadline:
			_give_up("MICROPHONE PERMISSION DENIED")
	if not _sending or _capture == null or not _mic_player.playing:
		return
	if Network.members.size() > Network.VOICE_MAX_MEMBERS:
		_mic_wanted = false
		_stop_transmitting()
		status_changed.emit("VOICE CHAT SUPPORTS UP TO 16 PLAYERS")
		return
	var mix_rate := AudioServer.get_mix_rate()
	if mix_rate <= 0:
		return
	var input_frames_needed := maxi(1, roundi(float(FRAME_SAMPLES) * float(mix_rate) / float(SAMPLE_RATE)))
	if _capture.get_frames_available() < input_frames_needed:
		return
	var input_frames: PackedVector2Array = _capture.get_buffer(input_frames_needed)
	if input_frames.is_empty():
		return
	var packet := PackedByteArray()
	packet.resize(FRAME_BYTES)
	var stride := float(mix_rate) / float(SAMPLE_RATE)
	for i in FRAME_SAMPLES:
		var source_index := clampi(roundi(float(i) * stride), 0, input_frames.size() - 1)
		var sample := (input_frames[source_index].x + input_frames[source_index].y) * 0.5
		if absf(sample) < SILENCE_GATE:
			sample = 0.0
		packet.encode_s16(i * 2, clampi(roundi(sample * 30000.0), -32768, 32767))
	Network.send_voice_packet(packet)


func _on_voice_packet(peer_id: int, packet: PackedByteArray) -> void:
	if not Network.in_room() or peer_id == multiplayer.get_unique_id() or packet.size() != FRAME_BYTES:
		return
	var playback: AudioStreamGeneratorPlayback
	if not _outputs.has(peer_id) or not is_instance_valid(_outputs[peer_id]["player"]):
		var stream := AudioStreamGenerator.new()
		stream.mix_rate = SAMPLE_RATE
		stream.buffer_length = 0.25
		var player := AudioStreamPlayer.new()
		player.name = "RemoteVoice_%d" % peer_id
		player.bus = "VoiceOutput"
		player.stream = stream
		add_child(player)
		player.play()
		_outputs[peer_id] = {"player": player, "last_packet": Time.get_ticks_msec()}
		call_deferred("_push_voice_packet", peer_id, packet)
		return
	_outputs[peer_id]["last_packet"] = Time.get_ticks_msec()
	playback = _outputs[peer_id]["player"].get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	_push_decoded_frame(playback, packet)


func _push_voice_packet(peer_id: int, packet: PackedByteArray) -> void:
	if not _outputs.has(peer_id) or packet.size() != FRAME_BYTES:
		return
	var playback := _outputs[peer_id]["player"].get_stream_playback() as AudioStreamGeneratorPlayback
	if playback != null:
		_push_decoded_frame(playback, packet)


func _push_decoded_frame(playback: AudioStreamGeneratorPlayback, packet: PackedByteArray) -> void:
	var frame := PackedVector2Array()
	frame.resize(FRAME_SAMPLES)
	for i in FRAME_SAMPLES:
		var sample := float(packet.decode_s16(i * 2)) / 32768.0
		frame[i] = Vector2(sample, sample)
	playback.push_buffer(frame)


func _on_peer_left(peer_id: int) -> void:
	if not _outputs.has(peer_id):
		return
	var player: AudioStreamPlayer = _outputs[peer_id]["player"]
	if is_instance_valid(player):
		player.queue_free()
	_outputs.erase(peer_id)


func _on_disconnected() -> void:
	_was_in_room = false
	_mic_wanted = false
	_waiting_permission = false
	_stop_transmitting()
	_clear_outputs()


func _clear_outputs() -> void:
	for peer_id in _outputs.keys():
		_on_peer_left(int(peer_id))


func _notification(what: int) -> void:
	# The OS does not let apps record in the background: pause the mic and
	# bring it back by itself if the player had it open.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_stop_transmitting()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _mic_wanted and not _sending and Network.in_room():
			_start_transmitting()
