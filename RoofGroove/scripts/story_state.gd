extends RefCounted



const SAVE_FILE: = "user://story.cfg"


static var active: = false

static var seen: Array = []
static var finished: = false

static var last_deaths: = 0

static var intro_seen: = false

static var respawning: = false

static var story_cp: = 0

static var _loaded: = false


static func load_state() -> void :
	if _loaded:
		return
	_loaded = true
	var cfg: = ConfigFile.new()
	if cfg.load(SAVE_FILE) != OK:
		return
	seen.clear()
	for v in cfg.get_value("story", "seen", []):
		seen.append(str(v))
	finished = bool(cfg.get_value("story", "finished", false))
	intro_seen = bool(cfg.get_value("story", "intro_seen", false))
	story_cp = int(cfg.get_value("story", "cp", 0))


static func save_state() -> void :
	var cfg: = ConfigFile.new()
	cfg.set_value("story", "seen", seen)
	cfg.set_value("story", "finished", finished)
	cfg.set_value("story", "intro_seen", intro_seen)
	cfg.set_value("story", "cp", story_cp)
	cfg.save(SAVE_FILE)


static func has_seen(id: String) -> bool:
	load_state()
	return seen.has(id)


static func mark_seen(id: String) -> void :
	load_state()
	if not seen.has(id):
		seen.append(id)
		save_state()



static func has_progress() -> bool:
	load_state()
	return story_cp > 0 or not seen.is_empty() or intro_seen or finished



static func sig() -> String:
	load_state()
	return "%d|%d|%s|%s" % [story_cp, seen.size(), str(finished), str(intro_seen)]



static func apply_cloud(cp: int, seen_arr: Array, fin: bool, intro: bool) -> void :
	load_state()
	story_cp = maxi(cp, 0)
	seen = seen_arr.duplicate()
	finished = fin
	intro_seen = intro
	save_state()


static func mark_intro_seen() -> void :
	load_state()
	if not intro_seen:
		intro_seen = true
		save_state()


static func set_cp(n: int) -> void :
	load_state()
	story_cp = n
	save_state()



static func reset_run() -> void :
	load_state()
	seen.clear()
	story_cp = 0
	save_state()


static func mark_finished() -> void :
	load_state()
	finished = true
	save_state()



static func notes(chapters: Array) -> int:
	load_state()
	var n: = 0
	for ch in chapters:
		if bool(ch.get("note", false)) and seen.has(str(ch["id"])):
			n += 1
	return n


static func reset() -> void :
	load_state()
	seen.clear()
	finished = false
	last_deaths = 0
	save_state()
