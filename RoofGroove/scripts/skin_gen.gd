extends RefCounted





const COUNT: = 100
const MIN_PRICE: = 2500
const MAX_PRICE: = 100000
const SPECIES: = ["Robot", "Alien", "Frog", "Cat", "Bear", "Skeleton", "Mushroom", "Pumpkin", "Imp", "Penguin", 
	"Fox", "Owl", "Drake", "Ghost", "Slime", "Cactus", "Snowman", "Astronaut", "Zombie", "Cyclops"]
const VARIANTS: = ["", "Scout", "Hiker", "Dandy", "Golden"]
# Golden skins (variant 4) are bought with GEMS, which are only added from Firebase.
const GOLD_GEM_MIN: = 10
const GOLD_GEM_STEP: = 5


static func skin_id(i: int) -> String:
	return "g%03d" % (i + 1)


static func skin_name(i: int) -> String:
	var sp: String = SPECIES[i % 20]
	var v: = i / 20
	if v == 4:
		return "Golden " + sp
	return sp if v == 0 else sp + " " + VARIANTS[v]



static func price_for(i: int) -> int:
	var t: = float(i) / float(COUNT - 1)
	var p: = float(MIN_PRICE) * pow(float(MAX_PRICE) / float(MIN_PRICE), t)
	return int(round(p / 100.0) * 100.0)


static func catalog(_base_skins: Dictionary = {}) -> Dictionary:
	var out: = {}
	for i in COUNT:
		var info: = {
			"name": skin_name(i), 
			"price": price_for(i), 
			"group": "boy", 
			"sheet": "res://sprites/new_skins/%s.png" % skin_id(i), 
			"gen": true, 
		}
		if i / 20 == 4:
			info["price"] = 0
			info["gem_price"] = GOLD_GEM_MIN + (i - 80) * GOLD_GEM_STEP
		out[skin_id(i)] = info
	return out
