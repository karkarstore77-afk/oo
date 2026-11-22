extends RefCounted




const DEFS: = {
	"jump": {"dur": 15.0, "good": true, "jump": 1.35}, 
	"speed": {"dur": 12.0, "good": true, "speed": 1.4}, 
	"float": {"dur": 5.0, "good": true, "grav": 0.45}, 
	"slow": {"dur": 10.0, "good": false, "speed": 0.6}, 
	"weak": {"dur": 10.0, "good": false, "jump": 0.85}, 
	"heavy": {"dur": 8.0, "good": false, "grav": 1.3}, 
}


static var active: Dictionary = {}
## Effects switched on by cheat codes: they stay on until the code is entered again (or CLEAR).
static var perma: Dictionary = {}


static func apply(kind: String) -> void :
	if DEFS.has(kind):
		active[kind] = float(DEFS[kind]["dur"])


static func tick(delta: float) -> void :
	for k in active.keys():
		active[k] = float(active[k]) - delta
		if float(active[k]) <= 0.0:
			active.erase(k)


static func clear() -> void :
	active.clear()


static func _mult(key: String) -> float:
	var m: = 1.0
	for k in active:
		m *= float(DEFS[k].get(key, 1.0))
	for k in perma:
		if bool(perma[k]) and DEFS.has(k):
			m *= float(DEFS[k].get(key, 1.0))
	return m


static func speed_mult() -> float:
	return _mult("speed")


static func jump_mult() -> float:
	return _mult("jump")


static func gravity_mult() -> float:
	return _mult("grav")
