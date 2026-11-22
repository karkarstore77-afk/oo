extends Node







signal tokens_changed
signal skin_changed(skin_id: String)
signal skin_unlocked(skin_id: String)
signal dev_welcome

const SAVE_FILE: = "user://economy.cfg"
const TOKENS_PER_CHECKPOINT: = 10
const DEV_SKIN: = "dev"
const SkinGen: = preload("res://scripts/skin_gen.gd")


const BASE_SKINS: = {
	"classic": {"name": "Knight", "price": 0, "group": "boy", "sheet": "res://sprites/knight.png"}, 
	"wizard": {"name": "Wizard", "price": 50, "group": "boy", "sheet": "res://sprites/skins/wizard.png"}, 
	"pirate": {"name": "Pirate", "price": 100, "group": "boy", "sheet": "res://sprites/skins/pirate.png"}, 
	"viking": {"name": "Viking", "price": 150, "group": "boy", "sheet": "res://sprites/skins/viking.png"}, 
	"ninja": {"name": "Ninja", "price": 250, "group": "boy", "sheet": "res://sprites/skins/ninja.png"}, 
	"king": {"name": "King", "price": 400, "group": "boy", "sheet": "res://sprites/skins/king.png"}, 
	"bunny": {"name": "Bunny Girl", "price": 100, "group": "girl", "sheet": "res://sprites/skins/bunny.png"}, 
	"fairy": {"name": "Fairy", "price": 150, "group": "girl", "sheet": "res://sprites/skins/fairy.png"}, 
	"princess": {"name": "Princess", "price": 300, "group": "girl", "sheet": "res://sprites/skins/princess.png"}, 
	"dev": {"name": "Developers", "price": -1, "group": "dev", "sheet": "res://sprites/skins/dev.png"}, 
}


var SKINS: Dictionary = {}

var earned: = 0
var bonus: = 0
var gems_granted: = 0  # set ONLY from Firebase (players/{uid}.gems); never written by the game
var used_codes: Array = []
var owned: Array = ["classic"]
var equipped: = "classic"
var _frames_cache: = {}


func _init() -> void :
	SKINS = BASE_SKINS.duplicate()
	SKINS.merge(SkinGen.catalog(BASE_SKINS))


func _ready() -> void :
	_load()





func spent() -> int:
	var total: = 0
	for id in owned:
		if SKINS.has(id):
			total += maxi(0, int(SKINS[id]["price"]))
	return total


func balance() -> int:
	return maxi(0, earned + bonus - spent())


func gem_spent() -> int:
	var total: = 0
	for id in owned:
		if SKINS.has(id):
			total += maxi(0, int(SKINS[id].get("gem_price", 0)))
	return total


func gem_balance() -> int:
	return maxi(0, gems_granted - gem_spent())


func add_tokens(n: int) -> void :
	if n <= 0:
		return
	earned += n
	_save()
	tokens_changed.emit()
	_push()





func owns(id: String) -> bool:
	return owned.has(id)


func can_buy(id: String) -> bool:
	if not SKINS.has(id) or owns(id):
		return false
	if SKINS[id].has("gem_price"):
		return gem_balance() >= int(SKINS[id]["gem_price"])
	var price: int = SKINS[id]["price"]
	return price >= 0 and balance() >= price


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	owned.append(id)
	_save()
	tokens_changed.emit()
	skin_unlocked.emit(id)
	_push()
	return true


func equip(id: String) -> bool:
	if not owns(id):
		return false
	equipped = id
	_save()
	skin_changed.emit(id)
	_push()
	return true




func apply_reward(code: String, skin_id: String, tokens: int) -> String:
	var gave_skin: = false
	if skin_id != "" and SKINS.has(skin_id) and not owns(skin_id):
		owned.append(skin_id)
		gave_skin = true
	if not gave_skin and tokens <= 0:
		return "already" if SKINS.has(skin_id) else "invalid"
	if tokens > 0:
		earned += tokens
	used_codes.append(code)
	_save()
	tokens_changed.emit()
	if gave_skin:
		skin_unlocked.emit(skin_id)
		equip(skin_id)
		if skin_id == DEV_SKIN:
			dev_welcome.emit()
	_push()
	return "ok"




func frames_for(id: String, preview: bool = false) -> SpriteFrames:
	if not SKINS.has(id):
		id = "classic"
	if _frames_cache.has(id):
		return _frames_cache[id]
	var ckey: = id + "|p"
	if preview and _frames_cache.has(ckey):
		return _frames_cache[ckey]
	var info: Dictionary = SKINS[id]
	var tex: Texture2D = load(info["sheet"])
	var sf: = SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	var idle_cells: Array = []
	for i in 4:
		idle_cells.append(Vector2i(i * 32, 0))
	_add_anim(sf, &"idle", tex, idle_cells)
	if not preview:
		var run_cells: Array = []
		for i in 8:
			run_cells.append(Vector2i(i * 32, 64))
		for i in 8:
			run_cells.append(Vector2i(i * 32, 96))
		var jump_cells: Array = []
		for i in 8:
			jump_cells.append(Vector2i(i * 32, 160))
		_add_anim(sf, &"run", tex, run_cells)
		_add_anim(sf, &"jump", tex, jump_cells)
	_frames_cache[ckey if preview else id] = sf
	return sf


func _add_anim(sf: SpriteFrames, anim_name: StringName, tex: Texture2D, cells: Array) -> void :
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, 10.0)
	sf.set_animation_loop(anim_name, true)
	for c in cells:
		var at: = AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(c.x, c.y, 32, 32)
		sf.add_frame(anim_name, at)



func set_skin(node: AnimatedSprite2D, id: String, preview: bool = false) -> void :
	var was: StringName = node.animation
	var was_playing: = node.is_playing()
	node.sprite_frames = frames_for(id, preview)
	var f: SpriteFrames = node.sprite_frames
	if was == &"default":
		node.speed_scale = 0.5
	node.animation = was if f.has_animation(was) else &"idle"
	if was_playing or node.animation == &"idle":
		node.play()



func bind(node: AnimatedSprite2D) -> void :
	set_skin(node, equipped)
	var cb: = func(_id: String) -> void :
		if is_instance_valid(node):
			set_skin(node, equipped)
	skin_changed.connect(cb)
	node.tree_exiting.connect( func() -> void :
		if skin_changed.is_connected(cb):
			skin_changed.disconnect(cb))





func merge_cloud(cloud_earned: int, cloud_owned: Array, cloud_equipped: String, cloud_bonus: int = 0, cloud_used: Array = [], cloud_gems: int = -1) -> void :
	earned = maxi(earned, cloud_earned)
	if cloud_gems >= 0:
		gems_granted = cloud_gems
	bonus = maxi(0, cloud_bonus)
	for id in cloud_owned:
		if SKINS.has(id) and not owned.has(id):
			owned.append(id)
	for c in cloud_used:
		if not used_codes.has(c):
			used_codes.append(str(c))
	if cloud_equipped != "" and owns(cloud_equipped):
		equipped = cloud_equipped
	_save()
	tokens_changed.emit()
	skin_changed.emit(equipped)



func sig() -> String:
	return "%d,%s,%s,%d" % [earned, ",".join(PackedStringArray(owned)), equipped, used_codes.size()]





func _push() -> void :
	var c: Variant = Network.get("cloud")
	if c != null and c.has_method("push_now"):
		c.push_now()


func _save() -> void :
	if DisplayServer.get_name() == "headless":
		return
	var cfg: = ConfigFile.new()
	cfg.set_value("eco", "earned", earned)
	cfg.set_value("eco", "bonus", bonus)
	cfg.set_value("eco", "gems", gems_granted)
	cfg.set_value("eco", "used_codes", used_codes)
	cfg.set_value("eco", "owned", owned)
	cfg.set_value("eco", "equipped", equipped)
	cfg.save(SAVE_FILE)


func _load() -> void :
	var cfg: = ConfigFile.new()
	if cfg.load(SAVE_FILE) != OK:
		return
	earned = int(cfg.get_value("eco", "earned", 0))
	bonus = int(cfg.get_value("eco", "bonus", 0))
	gems_granted = int(cfg.get_value("eco", "gems", 0))
	used_codes = Array(cfg.get_value("eco", "used_codes", []))
	owned = Array(cfg.get_value("eco", "owned", ["classic"]))
	equipped = str(cfg.get_value("eco", "equipped", "classic"))
	owned = owned.filter( func(id: Variant) -> bool: return SKINS.has(id))
	if not owned.has("classic"):
		owned.append("classic")
	if not owns(equipped):
		equipped = "classic"
