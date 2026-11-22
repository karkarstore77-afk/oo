extends RefCounted











const VERSION: = 1
const DIR: = "user://worlds"
const COLLECTION: = "worlds"
const MAX_ISLANDS: = 150
const MAX_MONSTERS: = 80
const MAX_CHECKPOINTS: = 30
const MIN_W: = 2
const MAX_W: = 40
const X_MAX: = 1200
const Y_MIN: = -40
const Y_MAX: = 40
const NAME_MAX: = 24
const LIST_SIZE: = 60
const MONSTER_TYPES: = ["slime", "bat", "thorn", "charger", "jumper"]

static var _online_cache: = {}


static func empty_world() -> Dictionary:
	return {
		"v": VERSION, "name": "", "published_id": "", 
		"islands": [{"x": 0, "y": 0, "w": 10}], 
		"monsters": [], "checkpoints": [], "start": 0, "finish": -1, "verified": "", 
	}



static func sanitize(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var d: Dictionary = raw
	var src: Variant = d.get("islands", [])
	if not (src is Array):
		return {}
	var islands: Array = []
	for e in src:
		if islands.size() >= MAX_ISLANDS:
			break
		if not (e is Dictionary):
			continue
		islands.append({
			"x": clampi(int(e.get("x", 0)), 0, X_MAX), 
			"y": clampi(int(e.get("y", 0)), Y_MIN, Y_MAX), 
			"w": clampi(int(e.get("w", 4)), MIN_W, MAX_W), 
		})
	if islands.is_empty():
		return {}

	var monsters: Array = []
	var msrc: Variant = d.get("monsters", [])
	if msrc is Array:
		for e in msrc:
			if monsters.size() >= MAX_MONSTERS:
				break
			if not (e is Dictionary):
				continue
			var i: = int(e.get("i", -1))
			var t: = str(e.get("t", "slime"))
			if i < 0 or i >= islands.size() or not (t in MONSTER_TYPES) or int(islands[i]["w"]) < 3:
				continue
			monsters.append({"t": t, "i": i, "o": clampf(float(e.get("o", 0.0)), -1.0, 1.0)})

	var cps: Array = []
	var csrc: Variant = d.get("checkpoints", [])
	if csrc is Array:
		for e in csrc:
			var i: = int(e)
			if cps.size() < MAX_CHECKPOINTS and i >= 0 and i < islands.size() and not cps.has(i):
				cps.append(i)
	cps.sort()

	var start: = int(d.get("start", 0))
	if start < 0 or start >= islands.size():
		start = 0
	var finish: = int(d.get("finish", -1))
	if finish < 0 or finish >= islands.size():
		finish = -1
	return {
		"v": VERSION, 
		"name": str(d.get("name", "")).strip_edges().strip_escapes().left(NAME_MAX), 
		"published_id": str(d.get("published_id", "")).left(80), 
		"islands": islands, "monsters": monsters, "checkpoints": cps, 
		"start": start, "finish": finish, 
		"verified": str(d.get("verified", "")).left(40), 
	}



static func content_hash(w: Dictionary) -> String:
	var c: = {
		"islands": w.get("islands", []), "monsters": w.get("monsters", []), 
		"checkpoints": w.get("checkpoints", []), "start": w.get("start", 0), "finish": w.get("finish", -1), 
	}
	return JSON.stringify(c).md5_text()


static func is_verified(w: Dictionary) -> bool:
	return str(w.get("verified", "")) != "" and str(w["verified"]) == content_hash(w)




static func generate_race(seed_value: int) -> Dictionary:
	var rng: = RandomNumberGenerator.new()
	rng.seed = seed_value
	var count: = 30
	var islands: Array = [{"x": 0, "y": 0, "w": 8}]
	var monsters: Array = []
	var cps: Array = []
	var x: = 8
	var y: = 0
	for i in range(1, count):
		var dy: = rng.randi_range(-1, 2)
		var gap: = rng.randi_range(1, 2 if dy < 0 else 3)
		y = clampi(y + dy, -12, 12)
		var w: = 10 if i == count - 1 else rng.randi_range(4, 9)
		x += gap
		islands.append({"x": x, "y": y, "w": w})
		if i >= 2 and i < count - 1 and w >= 5 and rng.randf() < 0.4:
			monsters.append({"t": MONSTER_TYPES[rng.randi() % MONSTER_TYPES.size()], "i": i, "o": snappedf(rng.randf_range(-0.5, 0.5), 0.05)})
		if i % 8 == 0 and i < count - 1:
			cps.append(i)
		x += w
	return sanitize({"name": "Race Track", "islands": islands, "monsters": monsters, 
		"checkpoints": cps, "start": 0, "finish": count - 1})



static func publish_problem(w: Dictionary) -> String:
	if str(w.get("name", "")).strip_edges().length() < 3:
		return "Give your world a name (3+ letters)"
	if int(w.get("finish", -1)) < 0:
		return "Place a FINISH on an island first"
	if (w["islands"] as Array).size() < 3:
		return "A world needs at least 3 islands"
	if not is_verified(w):
		return "Finish your world once (TEST) before publishing"
	return ""





static func new_file_id() -> String:
	return "w%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 1000]


static func _path(file_id: String) -> String:
	return "%s/%s.json" % [DIR, file_id.validate_filename()]


static func save_local(w: Dictionary, file_id: String) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f: = FileAccess.open(_path(file_id), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(w))
	return true


static func load_local(file_id: String) -> Dictionary:
	if not FileAccess.file_exists(_path(file_id)):
		return {}
	var f: = FileAccess.open(_path(file_id), FileAccess.READ)
	if f == null:
		return {}
	return sanitize(JSON.parse_string(f.get_as_text()))


static func delete_local(file_id: String) -> void :
	if FileAccess.file_exists(_path(file_id)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(file_id)))



static func list_local() -> Array:
	var out: Array = []
	var dir: = DirAccess.open(DIR)
	if dir == null:
		return out
	for fn in dir.get_files():
		if not fn.ends_with(".json"):
			continue
		var id: = fn.get_basename()
		var w: = load_local(id)
		if not w.is_empty():
			out.append({"file": id, "name": str(w["name"]), "world": w})
	out.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return str(a["file"]) > str(b["file"]))
	return out





static func _fv(fields: Dictionary, key: String, def: Variant) -> Variant:
	if not fields.has(key) or not (fields[key] is Dictionary):
		return def
	var v: Dictionary = fields[key]
	if v.has("integerValue"):
		return int(v["integerValue"])
	if v.has("stringValue"):
		return str(v["stringValue"])
	if v.has("booleanValue"):
		return bool(v["booleanValue"])
	return def


static func _cloud() -> Node:
	return Network.cloud


static func signed_in() -> bool:
	var c: = _cloud()
	return c != null and c.is_signed_in()



static func _fetch(path: String) -> Dictionary:
	var c: = _cloud()
	if c == null:
		return {"ok": false, "code": 0, "data": {}}
	if c.is_signed_in():
		return await c.doc_get(path)
	return await c._http(HTTPClient.METHOD_GET, c._doc_url(path), [])




static func publish(w: Dictionary) -> Dictionary:
	var c: = _cloud()
	if c == null or not c.is_signed_in():
		return {"ok": false, "error": "Sign in with Google to publish"}
	var problem: = publish_problem(w)
	if problem != "":
		return {"ok": false, "error": problem}
	var content: = {
		"v": VERSION, "name": w["name"], "islands": w["islands"], "monsters": w["monsters"], 
		"checkpoints": w["checkpoints"], "start": w["start"], "finish": w["finish"], 
	}
	var now: = int(Time.get_unix_time_from_system())
	var id: = str(w.get("published_id", ""))
	var is_update: = id != ""
	if not is_update:
		id = "%s_%d" % [str(c.uid).left(10), now]
	var fields: = {
		"name": {"stringValue": str(w["name"])}, 
		"author_uid": {"stringValue": str(c.uid)}, 
		"author_name": {"stringValue": Network.player_name}, 
		"data": {"stringValue": JSON.stringify(content)}, 
		"created": {"integerValue": str(now)}, 
		"official": {"booleanValue": false}, 
		"islands": {"integerValue": str((w["islands"] as Array).size())}, 
		"monsters": {"integerValue": str((w["monsters"] as Array).size())}, 
		"checkpoints": {"integerValue": str((w["checkpoints"] as Array).size())}, 
	}
	var path: = "%s/%s" % [COLLECTION, id]
	var r: Dictionary
	if is_update:
		r = await c.doc_set(path, fields)
	else:
		r = await c.doc_create(path, fields)
	if not bool(r["ok"]):
		return {"ok": false, "error": c._error_text(r)}
	_online_cache.erase(id)
	return {"ok": true, "id": id}



static func list_online() -> Dictionary:
	var masks: = ["name", "author_uid", "author_name", "created", "official", "islands", "monsters", "checkpoints"]
	var q: = "%s?pageSize=%d&orderBy=created%%20desc" % [COLLECTION, LIST_SIZE]
	for m in masks:
		q += "&mask.fieldPaths=" + m
	var r: Dictionary = await _fetch(q)
	if not bool(r["ok"]):
		var code: = int(r["code"])
		var err: = "Could not reach the server"
		if code == 401:
			err = "Sign in to browse worlds"
		elif code == 403:
			err = "Firebase denied access to worlds. Check Firestore rules."
		return {"ok": false, "error": err, "worlds": []}
	var out: Array = []
	var docs: Variant = (r["data"] as Dictionary).get("documents", [])
	if docs is Array:
		for d in docs:
			if not (d is Dictionary):
				continue
			var f: Dictionary = d.get("fields", {})
			out.append({
				"id": str(d.get("name", "")).get_file(), 
				"name": str(_fv(f, "name", "?")), 
				"author": str(_fv(f, "author_name", "?")), 
				"author_uid": str(_fv(f, "author_uid", "")), 
				"official": bool(_fv(f, "official", false)), 
				"created": int(_fv(f, "created", 0)), 
				"islands": int(_fv(f, "islands", 0)), 
				"monsters": int(_fv(f, "monsters", 0)), 
				"checkpoints": int(_fv(f, "checkpoints", 0)), 
			})
	return {"ok": true, "worlds": out}



static func fetch_online(id: String) -> Dictionary:
	if _online_cache.has(id):
		return {"ok": true, "world": _online_cache[id]}
	if id == "" or id.contains("/") or id.length() > 80:
		return {"ok": false, "error": "Invalid world"}
	var r: Dictionary = await _fetch("%s/%s" % [COLLECTION, id])
	if not bool(r["ok"]):
		if int(r.get("code", 0)) == 403:
			return {"ok": false, "error": "Firebase denied access to worlds. Check Firestore rules."}
		return {"ok": false, "error": "Could not load the world"}
	var f: Dictionary = (r["data"] as Dictionary).get("fields", {})
	var w: = sanitize(JSON.parse_string(str(_fv(f, "data", ""))))
	if w.is_empty():
		return {"ok": false, "error": "Invalid world"}
	w["name"] = str(_fv(f, "name", w["name"])).left(NAME_MAX)
	w["published_id"] = id
	_online_cache[id] = w
	return {"ok": true, "world": w}


static func delete_online(id: String) -> bool:
	var c: = _cloud()
	if c == null or not c.is_signed_in():
		return false
	var r: Dictionary = await c.doc_delete("%s/%s" % [COLLECTION, id])
	_online_cache.erase(id)
	return bool(r["ok"])
