extends Node







signal friends_updated
signal requests_updated
signal profile_updated
signal id_ready(player_id: String)
signal invite_received(from_name: String, code: String)

const FRIENDS_FILE: = "user://friends.cfg"
const MIN_PUBLIC_ID: = 10000
const MAX_FRIENDS: = 50
const BIO_MAX: = 40
const VALID_BADGES: Array[String] = ["VIP", "DEV"]
const INVITE_POLL_SECONDS: = 8.0
const INVITE_MAX_AGE: = 120.0
const UI: = preload("res://scripts/ui_kit.gd")
const PROFILE_COLORS: Array[Color] = [
	Color("#2761c5"), Color("#13a58e"), Color("#8c55d8"), Color("#db7840"),
	Color("#bf4775"), Color("#5a9d4b"), Color("#c49a2e"), Color("#4e90aa"),
]

var friends: Dictionary = {}
var incoming_requests: Array = []
var outgoing_requests: Array = []
var inbox_events: Array = []
var seen_request_events: Array = []
var seen_messages: Array = []
var inbox_unread: = 0
var _refreshing_messages: = false
var player_id: = ""
var profile_letter: String = "A"
var profile_color: int = 0
var member_since: int = 0
var profile_badge: String = ""
## Badges the player owns (given from Firebase: players/{uid}.badge = "VIP" or "VIP,DEV").
var owned_badges: Array[String] = []
## "" = show the first badge, "NONE" = show no badge, or one of the owned badges.
var badge_choice: String = ""
var profile_shape: int = 0
var profile_frame: int = 0
var profile_letter_color: int = 0
var profile_bio: String = ""
var _badge_initialized: = false
var _registering: = false
var _refreshing_social: = false
var _request_poll_elapsed: = 0.0
var pending_join_code: = ""
var _polling: = false
var _popup: CanvasLayer = null


func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_load()
	if player_id == "" or player_id == "0":
		player_id = _random_id()
		_save()
	var timer: = Timer.new()
	timer.wait_time = INVITE_POLL_SECONDS
	timer.autostart = true
	timer.timeout.connect(_poll_invites)
	add_child(timer)


func _process(delta: float) -> void:
	if Network.cloud == null or not Network.cloud.is_signed_in():
		return
	_request_poll_elapsed += delta
	if _request_poll_elapsed >= 25.0:
		_request_poll_elapsed = 0.0
		refresh_requests()
		refresh_all()
		refresh_messages()





func register_id(cloud_pid: String = "") -> void :
	var c: Node = Network.cloud
	if c == null or not c.is_signed_in() or _registering:
		return
	_registering = true


	if cloud_pid != "" and cloud_pid != player_id:
		var rc: Dictionary = await c.doc_get("ids/" + cloud_pid)
		if rc["ok"] and _str_field(rc["data"], "uid") == c.uid:
			player_id = cloud_pid
			_save()


	for attempt in 8:
		var r: Dictionary = await c.doc_get("ids/" + player_id)
		if r["ok"]:
			if _str_field(r["data"], "uid") == c.uid:
				break
			player_id = _random_id()
			_save()
			continue
		if int(r["code"]) != 404:
			break
		var w: Dictionary = await c.doc_create("ids/" + player_id, {"uid": {"stringValue": c.uid}})
		if w["ok"]:
			break
		player_id = _random_id()
		_save()

	_registering = false
	id_ready.emit(player_id)
	friends_updated.emit()






func add_friend(friend_id: String) -> Dictionary:
	friend_id = friend_id.strip_edges()
	if friend_id == "" or friend_id.to_int() <= 0 or str(friend_id.to_int()) != friend_id:
		return _result(false, "Enter a numeric ID")
	if friend_id == player_id:
		return _result(false, "That's your own ID")
	if friends.has(friend_id):
		return _result(false, "Already in your friends list")
	if friends.size() >= MAX_FRIENDS:
		return _result(false, "Friends list is full")

	var c: Node = Network.cloud
	if c == null or not c.is_signed_in():
		return _result(false, "Sign in first (ACCOUNT / RANKING)")

	var r: Dictionary = await c.doc_get("ids/" + friend_id)
	if int(r["code"]) == 404:
		return _result(false, "ID not found")
	if not r["ok"]:
		return _result(false, "Connection problem, try again")
	var fuid: = _str_field(r["data"], "uid")
	if fuid == "":
		return _result(false, "ID not found")
	if fuid == c.uid:
		return _result(false, "That's your own ID")

	var stats: Dictionary = await _fetch_stats(c, fuid)
	friends[friend_id] = {
		"uid": fuid, 
		"name": stats["name"], 
		"checkpoints": stats["checkpoints"], 
		"best_time": stats["best_time"], 
	}
	_save()
	friends_updated.emit()
	return _result(true, tr("Added %s") % stats["name"])


func remove_friend(friend_id: String) -> bool:
	if not friends.has(friend_id):
		return false
	var friend_uid: String = str(friends[friend_id].get("uid", ""))
	friends.erase(friend_id)
	_save()
	var c: Node = Network.cloud
	if c != null and c.is_signed_in() and friend_uid != "":
		var pair: Array = [c.uid, friend_uid]
		pair.sort()
		c.doc_delete("friendships/" + str(pair[0]) + "__" + str(pair[1]))
	friends_updated.emit()
	return true


## "VIP", "DEV" or "VIP,DEV" (also accepts + or spaces) -> list of valid badges, without repeats.
static func parse_badges(raw: String) -> Array[String]:
	var out: Array[String] = []
	var cleaned: String = raw.to_upper().replace("+", ",").replace(";", ",").replace(" ", ",")
	for part in cleaned.split(",", false):
		var b: String = part.strip_edges()
		if VALID_BADGES.has(b) and not out.has(b):
			out.append(b)
	return out


## Which badge to show: the player's choice, "NONE" hides it, otherwise the first one owned.
static func pick_badge(owned: Array, choice: String) -> String:
	if owned.is_empty() or choice == "NONE":
		return ""
	if choice != "" and owned.has(choice):
		return choice
	return str(owned[0])


func get_friend_stats(friend_id: String) -> Dictionary:
	return friends[friend_id].duplicate() if friends.has(friend_id) else {}


func fetch_profile(uid: String) -> Dictionary:
	var c: Node = Network.cloud
	if c == null or not c.is_signed_in():
		return {}
	return await _fetch_stats(c, uid)


func refresh_own_profile() -> Dictionary:
	var c: Node = Network.cloud
	if c == null or not c.is_signed_in():
		return {}
	var result: Dictionary = await c.doc_get("players/" + c.uid)
	if not result["ok"]:
		return {}
	var fields: Dictionary = result["data"].get("fields", {})
	apply_cloud_profile(fields)
	return _profile_from_fields(c.uid, fields)


func apply_cloud_profile(fields: Dictionary) -> void:
	profile_letter = str(_field(fields, "profile_letter", profile_letter)).to_upper()
	if profile_letter.length() != 1 or profile_letter < "A" or profile_letter > "Z":
		profile_letter = "A"
	profile_color = clampi(int(_field(fields, "profile_color", profile_color)), 0, 7)
	var remote_created: int = int(_field(fields, "created_at", member_since))
	if remote_created > 0:
		member_since = remote_created
	elif member_since <= 0:
		member_since = int(Time.get_unix_time_from_system())
	profile_shape = clampi(int(_field(fields, "profile_shape", profile_shape)), 0, 2)
	profile_frame = clampi(int(_field(fields, "profile_frame", profile_frame)), 0, 8)
	profile_letter_color = clampi(int(_field(fields, "profile_letter_color", profile_letter_color)), 0, 5)
	profile_bio = str(_field(fields, "profile_bio", profile_bio)).strip_edges().left(BIO_MAX)
	var next_owned: Array[String] = parse_badges(str(_field(fields, "badge", "")))
	for b in next_owned:
		if not owned_badges.has(b) and _badge_initialized:
			inbox_events.push_front({"text": "You received the %s badge" % b, "time": int(Time.get_unix_time_from_system())})
			inbox_events = inbox_events.slice(0, 30)
	owned_badges = next_owned
	badge_choice = str(_field(fields, "badge_shown", badge_choice)).strip_edges().to_upper()
	profile_badge = pick_badge(owned_badges, badge_choice)
	_badge_initialized = true
	_save()
	profile_updated.emit()


func save_profile(letter: String, color_index: int, extra: Dictionary = {}) -> Dictionary:
	letter = letter.strip_edges().to_upper()
	if letter.length() != 1 or letter < "A" or letter > "Z":
		return _result(false, "Choose a letter from A to Z")
	profile_letter = letter
	profile_color = clampi(color_index, 0, 7)
	if extra.has("shape"):
		profile_shape = clampi(int(extra["shape"]), 0, 2)
	if extra.has("frame"):
		profile_frame = clampi(int(extra["frame"]), 0, 8)
	if extra.has("letter_color"):
		profile_letter_color = clampi(int(extra["letter_color"]), 0, 5)
	if extra.has("bio"):
		profile_bio = str(extra["bio"]).strip_edges().strip_escapes().replace("\n", " ").left(BIO_MAX)
	if extra.has("badge_choice"):
		var choice: String = str(extra["badge_choice"]).strip_edges().to_upper()
		badge_choice = choice if (choice == "" or choice == "NONE" or owned_badges.has(choice)) else ""
		profile_badge = pick_badge(owned_badges, badge_choice)
	_save()
	var c: Node = Network.cloud
	if c == null or not c.is_signed_in():
		return _result(true, "Saved on this device. Sign in to sync it to your account.")
	var r: Dictionary = await c.update_profile({
		"profile_letter": {"stringValue": profile_letter},
		"profile_color": {"integerValue": str(profile_color)},
		"profile_shape": {"integerValue": str(profile_shape)},
		"profile_frame": {"integerValue": str(profile_frame)},
		"profile_letter_color": {"integerValue": str(profile_letter_color)},
		"profile_bio": {"stringValue": profile_bio},
		"badge_shown": {"stringValue": badge_choice},
		"search_name": {"stringValue": Network.player_name.strip_edges().to_lower()},
	})
	if not r.get("ok", false):
		return _result(false, "Could not save the profile online")
	profile_updated.emit()
	return _result(true, "Profile saved")


func search_players(query: String, by_id: bool) -> Array:
	var c: Node = Network.cloud
	if c == null or not c.is_signed_in():
		return []
	var r: Dictionary = await c.search_players(query, by_id)
	var out: Array = []
	if not r.get("ok", false):
		return out
	for doc in r.get("documents", []):
		if not (doc is Dictionary):
			continue
		var uid: String = str(doc.get("name", "")).get_file()
		if uid == "" or uid == c.uid:
			continue
		var fields: Dictionary = doc.get("fields", {})
		var card: Dictionary = _profile_from_fields(uid, fields)
		if by_id and not str(card.get("player_id", "")).begins_with(query.strip_edges()):
			continue
		if not by_id and not str(card.get("name", "")).to_lower().begins_with(query.strip_edges().to_lower()):
			continue
		out.append(card)
	if by_id:
		var wanted: = query.strip_edges()
		out.sort_custom( func(a, b): return str(a.get("player_id", "")) == wanted and str(b.get("player_id", "")) != wanted)
	return out


## Messages written by the game admin in Firestore (collection inbox_messages) appear in the inbox.
## Fields: to_id (the player's ID, or "all"), text, and optionally time (unix seconds).
func refresh_messages() -> void :
	var c: Node = Network.cloud
	if c == null or not c.is_signed_in() or player_id == "" or _refreshing_messages:
		return
	_refreshing_messages = true
	var docs: Array = []
	docs.append_array(await c.fetch_messages_for(player_id))
	docs.append_array(await c.fetch_messages_for("all"))
	_refreshing_messages = false
	var changed: = false
	for doc in docs:
		var message_id: String = str(doc.get("name", "")).get_file()
		if message_id == "" or seen_messages.has(message_id):
			continue
		seen_messages.append(message_id)
		var fields: Dictionary = doc.get("fields", {})
		var text: String = str(_field(fields, "text", "")).strip_edges()
		if text == "":
			continue
		var stamp: int = int(_field(fields, "time", 0))
		if stamp <= 0:
			stamp = int(Time.get_unix_time_from_system())
		inbox_events.push_front({"text": text, "time": stamp})
		inbox_unread += 1
		changed = true
	if seen_messages.size() > 300:
		seen_messages = seen_messages.slice(seen_messages.size() - 300)
	if changed:
		inbox_events.sort_custom( func(a, b): return int(a.get("time", 0)) > int(b.get("time", 0)))
		inbox_events = inbox_events.slice(0, 30)
		_save()
		requests_updated.emit()


func send_friend_request(target: Dictionary) -> Dictionary:
	var c: Node = Network.cloud
	if c == null or not c.is_signed_in():
		return _result(false, "Sign in first")
	var to_uid: String = str(target.get("uid", ""))
	if to_uid == "" or to_uid == c.uid:
		return _result(false, "Invalid player")
	for f in friends.values():
		if str(f.get("uid", "")) == to_uid:
			return _result(false, "Already friends")
	for request in outgoing_requests:
		if str(request.get("uid", "")) == to_uid and str(request.get("status", "")) == "pending":
			return _result(false, "Friend request already sent")
	for request in incoming_requests:
		if str(request.get("uid", "")) == to_uid and str(request.get("status", "")) == "pending":
			return _result(false, "This player already sent you a request; open Requests")
	var request_id: String = _new_request_id()
	var fields: = {
		"from_uid": {"stringValue": c.uid},
		"to_uid": {"stringValue": to_uid},
		"from_name": {"stringValue": Network.player_name},
		"from_player_id": {"stringValue": player_id},
		"to_name": {"stringValue": str(target.get("name", "Player"))},
		"to_player_id": {"stringValue": str(target.get("player_id", ""))},
		"status": {"stringValue": "pending"},
		"created_at": {"integerValue": str(int(Time.get_unix_time_from_system()))},
	}
	var r: Dictionary = await c.doc_create("friend_requests/" + request_id, fields)
	if not r["ok"]:
		return _result(false, "Could not send request (%d)" % int(r.get("code", 0)))
	await refresh_requests()
	return _result(true, "Friend request sent")


func refresh_requests() -> void:
	var c: Node = Network.cloud
	if c == null or not c.is_signed_in():
		return
	var incoming: Dictionary = await c.query_documents("friend_requests", "to_uid", "EQUAL", {"stringValue": c.uid}, 100)
	var outgoing: Dictionary = await c.query_documents("friend_requests", "from_uid", "EQUAL", {"stringValue": c.uid}, 100)
	if incoming.get("ok", false):
		incoming_requests = _parse_requests(incoming.get("documents", []), true)
	if outgoing.get("ok", false):
		var previous: Dictionary = {}
		for item in outgoing_requests:
			previous[str(item.get("id", ""))] = str(item.get("status", ""))
		outgoing_requests = _parse_requests(outgoing.get("documents", []), false)
		for item in outgoing_requests:
			var rid: String = str(item.get("id", ""))
			if str(item.get("status", "")) == "accepted" and previous.get(rid, "") != "accepted" and not seen_request_events.has(rid):
				inbox_events.push_front({"text": "%s accepted your friend request" % item.get("name", "Player"), "time": int(Time.get_unix_time_from_system())})
				seen_request_events.append(rid)
		inbox_events = inbox_events.slice(0, 30)
		seen_request_events = seen_request_events.slice(-100)
		_save()
	requests_updated.emit()


func respond_to_request(request_id: String, accept: bool) -> Dictionary:
	var c: Node = Network.cloud
	if c == null or not c.is_signed_in():
		return _result(false, "Sign in first")
	var result: Dictionary = await c.doc_get("friend_requests/" + request_id)
	if not result["ok"]:
		return _result(false, "Request is no longer available")
	var fields: Dictionary = result["data"].get("fields", {})
	if str(_field(fields, "to_uid", "")) != c.uid or str(_field(fields, "status", "")) != "pending":
		return _result(false, "This request cannot be changed")
	var next_status: String = "accepted" if accept else "rejected"
	var updated: Dictionary = await c._patch_firestore_doc("friend_requests/" + request_id, {"status": {"stringValue": next_status}})
	if not updated.get("ok", false):
		return _result(false, "Could not update request")
	if accept:
		var from_uid: String = str(_field(fields, "from_uid", ""))
		var members: Array = [from_uid, c.uid]
		members.sort()
		var pair_id: String = str(members[0]) + "__" + str(members[1])
		var friendship: Dictionary = await c.doc_create("friendships/" + pair_id, {
			"members": {"arrayValue": {"values": [{"stringValue": from_uid}, {"stringValue": c.uid}]}},
			"request_id": {"stringValue": request_id},
			"created_at": {"integerValue": str(int(Time.get_unix_time_from_system()))},
		})
		if not friendship.get("ok", false) and int(friendship.get("code", 0)) not in [400, 409]:
			return _result(false, "Request accepted, but friend list did not sync")
		inbox_events.push_front({"text": "You are now friends with %s" % _field(fields, "from_name", "Player"), "time": int(Time.get_unix_time_from_system())})
	await refresh_requests()
	await refresh_all()
	return _result(true, "Request accepted" if accept else "Request declined")


func _parse_requests(docs: Array, incoming: bool) -> Array:
	var out: Array = []
	for doc in docs:
		if not (doc is Dictionary):
			continue
		var f: Dictionary = doc.get("fields", {})
		out.append({
			"id": str(doc.get("name", "")).get_file(),
			"uid": str(_field(f, "from_uid" if incoming else "to_uid", "")),
			"name": str(_field(f, "from_name" if incoming else "to_name", "Player")),
			"player_id": str(_field(f, "from_player_id" if incoming else "to_player_id", "")),
			"status": str(_field(f, "status", "pending")),
		})
	return out


func _profile_from_fields(uid: String, f: Dictionary) -> Dictionary:
	var last_seen: int = int(_field(f, "last_seen", 0))
	var owned: Array[String] = parse_badges(str(_field(f, "badge", "")))
	var choice: String = str(_field(f, "badge_shown", "")).strip_edges().to_upper()
	var badge: String = pick_badge(owned, choice)
	return {
		"badges": owned,
		"badge_choice": choice,
		"shape": clampi(int(_field(f, "profile_shape", 0)), 0, 2),
		"frame": clampi(int(_field(f, "profile_frame", 0)), 0, 8),
		"letter_color": clampi(int(_field(f, "profile_letter_color", 0)), 0, 5),
		"bio": str(_field(f, "profile_bio", "")).strip_edges().left(BIO_MAX),
		"uid": uid,
		"name": str(_field(f, "name", "Player")),
		"player_id": str(_field(f, "player_id", "")),
		"checkpoints": int(_field(f, "best_checkpoint", 0)),
		"checkpoint": int(_field(f, "checkpoint", 0)),
		"best_time": float(_field(f, "play_time", 0.0)),
		"deaths": int(_field(f, "deaths", 0)),
		"member_since": int(_field(f, "created_at", 0)),
		"last_seen": last_seen,
		"online": last_seen > 0 and int(Time.get_unix_time_from_system()) - last_seen <= 110,
		"badge": badge,
		"letter": str(_field(f, "profile_letter", "A")),
		"color": clampi(int(_field(f, "profile_color", 0)), 0, 7),
	}


func _field(fields: Dictionary, key: String, default: Variant = "") -> Variant:
	var value: Variant = fields.get(key, {})
	if not (value is Dictionary):
		return default
	for type_key in ["stringValue", "integerValue", "doubleValue", "booleanValue"]:
		if value.has(type_key):
			return value[type_key]
	return default


func _new_request_id() -> String:
	return "r_%08x%08x" % [randi(), randi()]



func refresh_all() -> void :
	var c: Node = Network.cloud
	if c == null or not c.is_signed_in() or _refreshing_social:
		return
	_refreshing_social = true
	var query: Dictionary = await c.query_documents("friendships", "members", "ARRAY_CONTAINS", {"stringValue": c.uid}, 100)
	if query.get("ok", false):
		var updated: Dictionary = {}
		for doc in query.get("documents", []):
			var members: Array = c._str_array(doc.get("fields", {}), "members")
			var other_uid: String = ""
			for member in members:
				if str(member) != c.uid:
					other_uid = str(member)
			if other_uid == "":
				continue
			var stats: Dictionary = await _fetch_stats(c, other_uid)
			var key: String = str(stats.get("player_id", other_uid))
			updated[key] = stats
		# Keep older locally stored friends while their account migrates to requests.
		for fid in friends:
			var old: Dictionary = friends[fid]
			if not updated.has(str(fid)) and not updated.has(str(old.get("uid", ""))):
				updated[str(fid)] = old
		friends = updated
	else:
		for fid in friends.keys():
			var stats: Dictionary = await _fetch_stats(c, str(friends[fid].get("uid", "")))
			friends[fid] = stats
	_refreshing_social = false
	_save()
	friends_updated.emit()







func send_invite(friend_id: String) -> Dictionary:
	if not friends.has(friend_id):
		return _result(false, "Not in your friends list")
	var c: Node = Network.cloud
	if c == null or not c.is_signed_in():
		return _result(false, "Sign in first (ACCOUNT / RANKING)")
	if not Network.in_room() or Network.mode != Network.Mode.ONLINE or Network.room_code == "":
		return _result(false, "Invites work in online rooms only")
	var friend: Dictionary = friends[friend_id]
	var fields: = {
		"from_uid": {"stringValue": c.uid}, 
		"from_name": {"stringValue": Network.player_name}, 
		"code": {"stringValue": Network.invite_code}, 
	}
	var r: Dictionary = await c.doc_set("invites/" + str(friend.get("uid", "")), fields)
	if r["ok"]:
		return _result(true, tr("Invite sent to %s") % friend.get("name", "friend"))

	var code: = int(r.get("code", 0))
	push_warning("send_invite failed: HTTP %d  %s" % [code, c._error_text(r)])
	return _result(false, tr("Could not send the invite") + " (%s)" % (str(code) if code > 0 else tr("no internet")))


func _poll_invites() -> void :
	if _polling:
		return
	var c: Node = Network.cloud
	if c == null or not c.is_signed_in() or friends.is_empty():
		return
	_polling = true
	var path: = "invites/" + str(c.uid)
	var r: Dictionary = await c.doc_get(path)
	if r["ok"] and r["data"] is Dictionary and r["data"].has("fields"):
		var from_uid: = _str_field(r["data"], "from_uid")
		var from_name: = _str_field(r["data"], "from_name")
		var code: = _str_field(r["data"], "code")
		var age: = 9999.0
		var stamp: = str(r["data"].get("updateTime", ""))
		if stamp.length() >= 19:
			age = Time.get_unix_time_from_system() - Time.get_unix_time_from_datetime_string(stamp.substr(0, 19))
		await c.doc_delete(path)
		var from_friend: = false
		for fid in friends:
			if str(friends[fid].get("uid", "")) == from_uid:
				from_friend = true
				from_name = str(friends[fid].get("name", from_name))
		if from_friend and Network._valid_invite_code(code) and age <= INVITE_MAX_AGE and not Network.in_room():
			invite_received.emit(from_name, code)
			_show_invite_popup(from_name, code)
	_polling = false


func _show_invite_popup(from_name: String, code: String) -> void :
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = CanvasLayer.new()
	_popup.layer = 100
	add_child(_popup)

	var panel: = PanelContainer.new()
	_popup.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 40
	var margin: = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	col.add_child(UI.label("%s invited you to play" % from_name, 16))
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var join: = UI.button("JOIN", 16, 44.0)
	join.pressed.connect( func(): _accept_invite(code))
	row.add_child(join)
	var dismiss: = UI.button("LATER", 16, 44.0)
	dismiss.pressed.connect(_close_popup)
	row.add_child(dismiss)

	get_tree().create_timer(25.0).timeout.connect(_auto_close_popup.bind(_popup))


func _accept_invite(code: String) -> void :
	pending_join_code = code
	_close_popup()
	get_tree().change_scene_to_file("res://sence/online_menu.tscn")


func _auto_close_popup(ref: CanvasLayer) -> void :
	if is_instance_valid(ref) and ref == _popup:
		_close_popup()


func _close_popup() -> void :
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null




func _fetch_stats(c: Node, uid: String) -> Dictionary:
	var out: = {"name": "Player", "uid": uid, "player_id": "", "checkpoints": 0, "best_time": 0.0, "online": false, "badge": ""}
	if uid == "":
		return out
	var r: Dictionary = await c.doc_get("players/" + uid)
	if r["ok"] and r["data"] is Dictionary:
		out = _profile_from_fields(uid, r["data"].get("fields", {}))
	return out


func _str_field(data: Variant, key: String) -> String:
	if data is Dictionary and data.has("fields"):
		var f: Variant = data["fields"].get(key, {})
		if f is Dictionary and f.has("stringValue"):
			return str(f["stringValue"])
	return ""


func _random_id() -> String:
	return str(MIN_PUBLIC_ID + randi() % 90000)


func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}


func _load() -> void :
	var cfg: = ConfigFile.new()
	if cfg.load(FRIENDS_FILE) != OK:
		return
	player_id = str(cfg.get_value("player", "id", ""))
	profile_letter = str(cfg.get_value("profile", "letter", "A"))
	profile_color = clampi(int(cfg.get_value("profile", "color", 0)), 0, 7)
	member_since = int(cfg.get_value("profile", "member_since", 0))
	profile_badge = str(cfg.get_value("profile", "badge", ""))
	owned_badges = parse_badges(str(cfg.get_value("profile", "owned_badges", profile_badge)))
	badge_choice = str(cfg.get_value("profile", "badge_choice", ""))
	profile_shape = clampi(int(cfg.get_value("profile", "shape", 0)), 0, 2)
	profile_frame = clampi(int(cfg.get_value("profile", "frame", 0)), 0, 8)
	profile_letter_color = clampi(int(cfg.get_value("profile", "letter_color", 0)), 0, 5)
	profile_bio = str(cfg.get_value("profile", "bio", "")).left(BIO_MAX)
	_badge_initialized = bool(cfg.get_value("profile", "badge_initialized", false))
	inbox_events = Array(cfg.get_value("profile", "inbox", []))
	seen_request_events = Array(cfg.get_value("profile", "seen_request_events", []))
	seen_messages = Array(cfg.get_value("profile", "seen_messages", []))
	if cfg.has_section("friends"):
		for fid in cfg.get_section_keys("friends"):
			var data: Variant = cfg.get_value("friends", fid, {})
			if data is Dictionary:
				friends[fid] = data


func _save() -> void :
	var cfg: = ConfigFile.new()
	cfg.set_value("player", "id", player_id)
	cfg.set_value("profile", "letter", profile_letter)
	cfg.set_value("profile", "color", profile_color)
	cfg.set_value("profile", "member_since", member_since)
	cfg.set_value("profile", "badge", profile_badge)
	cfg.set_value("profile", "owned_badges", ",".join(PackedStringArray(owned_badges)))
	cfg.set_value("profile", "badge_choice", badge_choice)
	cfg.set_value("profile", "shape", profile_shape)
	cfg.set_value("profile", "frame", profile_frame)
	cfg.set_value("profile", "letter_color", profile_letter_color)
	cfg.set_value("profile", "bio", profile_bio)
	cfg.set_value("profile", "badge_initialized", _badge_initialized)
	cfg.set_value("profile", "inbox", inbox_events)
	cfg.set_value("profile", "seen_request_events", seen_request_events)
	cfg.set_value("profile", "seen_messages", seen_messages)
	for fid in friends:
		cfg.set_value("friends", fid, friends[fid])
	cfg.save(FRIENDS_FILE)
