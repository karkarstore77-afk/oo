extends RefCounted
## Abilities for every skin. Evolved variants are stronger and Golden skins are far stronger.
## The numbers only change the LOCAL player's physics (see player.gd).

const KINDS: = ["speed", "jump", "air_jump", "float", "coyote"]
# Power per variant tier: 0 = base, 1-3 = evolved (Scout / Hiker / Dandy), 4 = Golden.
const TIER_POWER: = [1.0, 1.6, 2.2, 2.8, 5.0]
const GOLDEN_SECONDARY_POWER: = 2.5

const BASE: = {
	"classic": [["coyote", 1.5]],
	"wizard": [["float", 2.0]],
	"pirate": [["speed", 2.0]],
	"viking": [["jump", 2.0]],
	"ninja": [["air_jump", 1.6]],
	"king": [["speed", 1.6], ["jump", 1.6]],
	"bunny": [["jump", 2.4]],
	"fairy": [["float", 2.0], ["air_jump", 1.6]],
	"princess": [["speed", 1.6], ["jump", 1.6], ["coyote", 2.0]],
	"dev": [["speed", 3.0], ["jump", 3.0], ["air_jump", 3.0], ["float", 3.0], ["coyote", 3.0]],
}


static func _empty() -> Dictionary:
	return {"speed": 1.0, "jump": 1.0, "gravity": 1.0, "air_jumps": 0, "air_jump_power": 0.0, "coyote": 0.0}


static func _add(out: Dictionary, kind: String, power: float) -> void :
	match kind:
		"speed":
			out["speed"] = float(out["speed"]) + 0.04 * power
		"jump":
			out["jump"] = float(out["jump"]) + 0.04 * power
		"float":
			out["gravity"] = maxf(0.5, float(out["gravity"]) - 0.04 * power)
		"air_jump":
			out["air_jumps"] = maxi(int(out["air_jumps"]), 2 if power >= 4.0 else 1)
			out["air_jump_power"] = maxf(float(out["air_jump_power"]), clampf(0.5 + 0.1 * power, 0.5, 1.0))
		"coyote":
			out["coyote"] = float(out["coyote"]) + 0.05 * power


static func tier_of(id: String) -> int:
	if id.length() == 4 and id.begins_with("g") and id.substr(1).is_valid_int():
		return clampi((int(id.substr(1)) - 1) / 20, 0, 4)
	return 0


static func is_golden(id: String) -> bool:
	return tier_of(id) == 4 and id.begins_with("g")


static func is_evolved(id: String) -> bool:
	var t: = tier_of(id)
	return id.begins_with("g") and t >= 1 and t <= 3


static func get_for(id: String) -> Dictionary:
	var out: = _empty()
	if BASE.has(id):
		for pair in BASE[id]:
			_add(out, str(pair[0]), float(pair[1]))
		return out
	if id.length() == 4 and id.begins_with("g") and id.substr(1).is_valid_int():
		var i: = clampi(int(id.substr(1)) - 1, 0, 99)
		var tier: = tier_of(id)
		var primary: String = KINDS[(i % 20) % KINDS.size()]
		var power: float = TIER_POWER[tier]
		if tier == 4:
			for k in KINDS:
				_add(out, k, power if k == primary else GOLDEN_SECONDARY_POWER)
		else:
			_add(out, primary, power)
	return out


static func describe(id: String) -> String:
	var a: = get_for(id)
	var parts: PackedStringArray = []
	if float(a["speed"]) > 1.0:
		parts.append("%s +%d%%" % [_t("SPEED"), roundi((float(a["speed"]) - 1.0) * 100.0)])
	if float(a["jump"]) > 1.0:
		parts.append("%s +%d%%" % [_t("JUMP"), roundi((float(a["jump"]) - 1.0) * 100.0)])
	if int(a["air_jumps"]) > 0:
		parts.append("%s x%d" % [_t("AIR JUMP"), int(a["air_jumps"])])
	if float(a["gravity"]) < 1.0:
		parts.append("%s %d%%" % [_t("FLOAT"), roundi((1.0 - float(a["gravity"])) * 100.0)])
	if float(a["coyote"]) > 0.0:
		parts.append("%s %dms" % [_t("COYOTE"), roundi(float(a["coyote"]) * 1000.0)])
	return " | ".join(parts)


static func tier_label(id: String) -> String:
	if is_golden(id):
		return _t("GOLDEN")
	if is_evolved(id):
		return _t("EVOLVED")
	return ""


static func _t(s: String) -> String:
	return TranslationServer.translate(s)
