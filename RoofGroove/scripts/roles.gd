extends Node
## Roles & per-feature permissions, controlled from Firebase (see CHANGES_AR.md).
##
## Firestore:
##   players/{uid}.roles        array of strings (or a comma string), for example ["admin","vip"]
##   players/{uid}.permissions  map of feature -> bool: a per-player override that wins over roles
##   role_permissions/{role}    one document per role; boolean fields = feature keys
##   role_permissions/default   baseline for everyone, signed in or not
## The old badge field ("VIP,DEV") still works: badges count as roles too.
## Missing documents or no internet: everything stays allowed (fail-open), so the game
## never locks anyone out by mistake.
##
## Feature keys: online, worlds, chat, voice, cheats, skins, feedback

signal changed

const Cfg: = preload("res://scripts/firebase_config.gd")

const FEATURES: Array[String] = ["online", "worlds", "chat", "voice", "cheats", "skins", "feedback"]
const REFRESH_EVERY: = 300.0

var _role_docs: = {}        # role name -> {feature: bool}
var _user_roles: Array = []
var _user_overrides: = {}   # feature -> bool
var _have_data: = false     # false until one fetch finished: fail-open until then
var _fetching: = false
var _timer: = 0.0


func _ready() -> void :
	refresh()


func _process(delta: float) -> void :
	_timer += delta
	if _timer >= REFRESH_EVERY:
		_timer = 0.0
		refresh()


func allowed(feature: String) -> bool:
	var key: = feature.to_lower()
	if _user_overrides.has(key):
		return bool(_user_overrides[key])
	var value: = true
	if _have_data:
		var def: Dictionary = _role_docs.get("default", {})
		if def.has(key):
			value = bool(def[key])
		var names: = _user_roles.duplicate()
		names.sort()
		for r in names:
			var doc: Dictionary = _role_docs.get(str(r), {})
			if doc.has(key):
				value = bool(doc[key])
	return value


func my_roles() -> Array:
	return _user_roles.duplicate()


## Called by cloud.gd with the signed-in player's Firestore fields (and with {} on sign-out).
func apply_user_doc(fields: Dictionary) -> void :
	var roles: Array = []
	var sv: Variant = fields.get("roles", null)
	if sv is Dictionary:
		var d: Dictionary = sv
		if d.has("arrayValue"):
			for item in d["arrayValue"].get("values", []):
				if item is Dictionary and item.has("stringValue"):
					_add_role(roles, str(item["stringValue"]))
		elif d.has("stringValue"):
			for part in str(d["stringValue"]).replace("+", ",").split(","):
				_add_role(roles, part)
	# the old badge field keeps working: "VIP,DEV" -> roles vip, dev
	for part in _str_field(fields, "badge", "").replace("+", ",").replace(" ", ",").split(",", false):
		_add_role(roles, part)
	var ov: = {}
	var mv: Variant = fields.get("permissions", null)
	if mv is Dictionary and mv.has("mapValue"):
		for k in mv["mapValue"].get("fields", {}):
			var tv: Variant = mv["mapValue"]["fields"][k]
			if tv is Dictionary and tv.has("booleanValue"):
				ov[str(k).to_lower()] = bool(tv["booleanValue"])
	_user_roles = roles
	_user_overrides = ov
	refresh()


func reset() -> void :
	apply_user_doc({})


func _add_role(roles: Array, raw: String) -> void :
	var r: = raw.strip_edges().to_lower()
	if r != "" and not roles.has(r):
		roles.append(r)


func _str_field(fields: Dictionary, key: String, def: String) -> String:
	var v: Variant = fields.get(key, null)
	if v is Dictionary and v.has("stringValue"):
		return str(v["stringValue"])
	return def


func refresh() -> void :
	if _fetching:
		return
	_fetching = true
	var names: Array = ["default"]
	for r in _user_roles:
		if not names.has(r):
			names.append(r)
	var got_any: = false
	for role_name in names:
		var f: Dictionary = await _get_doc_fields("role_permissions/" + str(role_name))
		if f.is_empty():
			continue
		got_any = true
		var doc: = {}
		for k in f:
			var tv: Variant = f[k]
			if tv is Dictionary and tv.has("booleanValue"):
				doc[str(k).to_lower()] = bool(tv["booleanValue"])
		_role_docs[str(role_name)] = doc
	_have_data = _have_data or got_any
	_fetching = false
	changed.emit()


func _get_doc_fields(path: String) -> Dictionary:
	var req: = HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)
	var url: = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/%s" % [Cfg.PROJECT_ID, path]
	var err: = req.request(url)
	if err != OK:
		req.queue_free()
		return {}
	var res: Array = await req.request_completed
	req.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200:
		return {}
	var data: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if data is Dictionary:
		return data.get("fields", {})
	return {}
