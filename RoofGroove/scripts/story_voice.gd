extends RefCounted


# Voice audio and text-to-speech are intentionally disabled for the whole game.
static var last_length: float = 0.0


static func speak(_who: String, _text: String) -> bool:
	last_length = 0.0
	return false


static func stop() -> void:
	pass


static func pitch_for(_who: String) -> float:
	return 1.0
