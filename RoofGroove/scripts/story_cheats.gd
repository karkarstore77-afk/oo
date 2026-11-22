extends RefCounted
## Story-mode cheat codes. Defaults live here; they can be added, changed or removed from Firebase:
## Firestore > app > cheats  (see CHEAT_CODES_AR.md).  Each field is   CODE : "action"  (or "action:number").

const Effects: = preload("res://scripts/story_effects.gd")

const CACHE_FILE: = "user://story_cheats.cfg"
const DEFAULT_CODES: = {
	"IMMORTAL": "god",
	"BLASTER": "gun",
	"TURBO": "speed",
	"SKYHIGH": "jump",
	"FEATHER": "float",
	"SHIELD": "shield:3",
	"GOLDRUSH": "tokens:50",
	"CLEAR": "clear",
}

static var god: = false
static var gun: = false
static var shield_charges: = 0
static var codes: Dictionary = {}
static var _used: Array = []
static var _loaded: = false


static func _ensure() -> void :
	if _loaded:
		return
	_loaded = true
	codes = DEFAULT_CODES.duplicate()
	var cfg: = ConfigFile.new()
	if cfg.load(CACHE_FILE) == OK:
		if cfg.has_section("codes"):
			codes.clear()
			for k in cfg.get_section_keys("codes"):
				codes[str(k)] = str(cfg.get_value("codes", k, ""))
		_used = Array(cfg.get_value("state", "used", []))


static func _save() -> void :
	var cfg: = ConfigFile.new()
	for k in codes:
		cfg.set_value("codes", str(k), str(codes[k]))
	cfg.set_value("state", "used", _used)
	cfg.save(CACHE_FILE)


## Firebase codes are added on top of the built-in ones. A value of "off" (or empty) removes a code.
static func set_codes(d: Dictionary) -> void :
	_ensure()
	codes = DEFAULT_CODES.duplicate()
	for k in d:
		var v: = str(d[k]).strip_edges().to_lower()
		if v == "" or v == "off":
			codes.erase(str(k).to_upper())
		else:
			codes[str(k).to_upper()] = v
	_save()


## Firebase switch: app/cheats > enabled = false turns every code off.
static func disable_all() -> void :
	_ensure()
	codes = {}
	clear_all()
	_save()


static func clear_all() -> void :
	god = false
	gun = false
	shield_charges = 0
	Effects.perma.clear()


static func _toggle_effect(kind: String, label: String) -> String:
	var on: = not bool(Effects.perma.get(kind, false))
	Effects.perma[kind] = on
	return "CHEAT: %s ON" % label if on else "CHEAT: %s OFF" % label


static func submit(text: String) -> String:
	_ensure()
	var typed: = text.strip_edges().to_upper()
	var raw: = str(codes.get(typed, "")).strip_edges().to_lower()
	if raw == "":
		return ""
	var action: = raw.get_slice(":", 0)
	var amount: = int(raw.get_slice(":", 1)) if raw.contains(":") else 0
	match action:
		"god":
			god = not god
			return "CHEAT: IMMORTAL ON" if god else "CHEAT: IMMORTAL OFF"
		"gun":
			gun = not gun
			return "CHEAT: BLASTER ON" if gun else "CHEAT: BLASTER OFF"
		"speed":
			return _toggle_effect("speed", "SPEED")
		"jump":
			return _toggle_effect("jump", "HIGH JUMP")
		"float":
			return _toggle_effect("float", "FLOAT")
		"shield":
			shield_charges = clampi(amount if amount > 0 else 3, 1, 99)
			return "CHEAT: SHIELD READY"
		"tokens":
			var key: = "tokens_" + typed
			if _used.has(key):
				return "CHEAT: ALREADY USED"
			_used.append(key)
			_save()
			Economy.add_tokens(clampi(amount if amount > 0 else 50, 1, 100000))
			return "CHEAT: TOKENS ADDED"
		"clear":
			clear_all()
			return "CHEAT: ALL OFF"
	return ""
