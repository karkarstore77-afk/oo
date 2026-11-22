extends Node









signal connected_to_server
signal connection_failed
signal p2p_status(text: String)
signal disconnected
signal room_joined(code: String)
signal room_failed(reason: String)
signal invite_code_changed(code: String, by_admin: bool)
signal invite_code_update_failed(reason: String)
signal peer_joined(id: int, player_name: String)
signal peer_left(id: int)
signal game_started(level_path: String)
signal state_received(id: int, pos: Vector2, anim_name: String, flip: bool)
signal leaderboard_received(level: String, entries: Array)
signal time_result(level: String, rank: int, is_best: bool)
signal skin_received(id: int, skin: String)
signal world_changed(world_id: String, world_name: String)
signal mode_changed(mode_name: String)
signal go_received()
signal race_done(id: int, place: int, time: float)
signal shot_received(id: int, pos: Vector2, dir: float)
signal pvp_updated()
signal pvp_kill(killer: int, victim: int)
signal pvp_respawn(id: int, spawn_index: int)
signal pvp_ended(winner: int)
signal lobby_requested()
signal chat_received(id: int, player_name: String, message: String)
signal voice_packet_received(id: int, packet: PackedByteArray)

enum Mode{OFFLINE, LAN, ONLINE}


const CONNECT_TIMEOUT: = 8.0


const LAN_PORT: = 1234
# no practical player limit (ENet supports up to 4095 peers)
const MAX_ROOM_PLAYERS: = 4000
const P2P_PORT: = 24680
const IP_LOOKUP_URL: = "https://api.ipify.org"
const CloudScript: = preload("res://scripts/cloud.gd")
const RelayClient: = preload("res://scripts/relay_client.gd")
const RELAY_TIMEOUT: = 80.0
const RELAY_URL: = "wss://roofgroove-relay.roofgroove-relay.workers.dev"
const LEVEL_PATH: = "res://sence/world_generated.tscn"
const LEVEL_ID: = "hard"
const CODE_CHARS: = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CFG_FILE: = "user://online.cfg"
const MIN_TIME: = 10.0
const NAME_MAX: = 12
const USERNAME_MIN: = 3
const CHAT_MAX_CHARS := 240
const VOICE_PACKET_BYTES := 640
const VOICE_MAX_MEMBERS := 16
const BUILTIN_ENDLESS_WORLD := "__roofgroove_endless__"
const BUILTIN_CLASSIC_WORLD := "__roofgroove_classic__"


var mode: Mode = Mode.OFFLINE
var player_name: = "Player"
var username_locked: = false
var uid: = ""
var last_ip: = ""
var room_code: = ""
var invite_code: = ""
var active_room_id: = ""
var room_host_id: = 0
const MODES: = ["adventure", "race", "pvp"]
const PVP_TIME: = 180.0
const PVP_KILL_LIMIT: = 10
const PVP_DAMAGE: = 20
const PVP_HP: = 100
const PVP_SPAWNS: = 6
const READY_TIMEOUT: = 10.0

var members: Dictionary = {}
var member_skins: Dictionary = {}
var room_mode: = "adventure"
var room_seed: = 0
var race_results: Array = []
var pvp_hp: Dictionary = {}
var pvp_kills: Dictionary = {}
var pvp_deaths: Dictionary = {}
var pvp_alive: Dictionary = {}
var pvp_active: = false
var pvp_time_limit: = PVP_TIME
var room_world: = ""
var room_world_name: = ""
var local_best: Dictionary = {}


var run_time: = 0.0
var deaths: = 0
var run_active: = false
var teleported_run: = false
var cloud: Node = null

var _join_code: = ""
var is_p2p_host: = false
var public_ip: = ""
var p2p_note: = ""
var _upnp: UPNP = null
var _relay: Node = null
var _fallback: Dictionary = {}
var _relay_phase: = false
var _attempt: = 0


var checkpoint: = 0
var checkpoint_seed: = 0
var best_checkpoint: = 0
var total_time: = 0.0
var total_deaths: = 0
var _save_accum: = 0.0


const RANKS: = [
	{"min": 0, "name": "Rookie", "color": Color(0.70, 0.70, 0.70)}, 
	{"min": 3, "name": "Beginner", "color": Color(0.62, 0.78, 0.62)}, 
	{"min": 5, "name": "Bronze", "color": Color(0.80, 0.50, 0.20)}, 
	{"min": 10, "name": "Adept", "color": Color(0.86, 0.60, 0.30)}, 
	{"min": 15, "name": "Silver", "color": Color(0.80, 0.85, 0.90)}, 
	{"min": 22, "name": "Skilled", "color": Color(0.65, 0.88, 0.80)}, 
	{"min": 30, "name": "Gold", "color": Color(1.00, 0.85, 0.20)}, 
	{"min": 45, "name": "Veteran", "color": Color(1.00, 0.72, 0.25)}, 
	{"min": 60, "name": "Platinum", "color": Color(0.50, 0.90, 0.95)}, 
	{"min": 80, "name": "Elite", "color": Color(0.40, 0.85, 0.75)}, 
	{"min": 100, "name": "Diamond", "color": Color(0.45, 0.70, 1.00)}, 
	{"min": 130, "name": "Master", "color": Color(0.55, 0.60, 1.00)}, 
	{"min": 160, "name": "Grandmaster", "color": Color(0.65, 0.50, 1.00)}, 
	{"min": 200, "name": "Champion", "color": Color(0.80, 0.45, 1.00)}, 
	{"min": 250, "name": "Hero", "color": Color(0.95, 0.45, 0.90)}, 
	{"min": 300, "name": "Warlord", "color": Color(1.00, 0.40, 0.60)}, 
	{"min": 380, "name": "Titan", "color": Color(1.00, 0.35, 0.35)}, 
	{"min": 470, "name": "Mythic", "color": Color(1.00, 0.50, 0.25)}, 
	{"min": 570, "name": "Immortal", "color": Color(1.00, 0.65, 0.20)}, 
	{"min": 700, "name": "Legend", "color": Color(1.00, 0.40, 0.80)}, 
	{"min": 850, "name": "Ascendant", "color": Color(1.00, 0.85, 0.45)}, 
	{"min": 1000, "name": "Celestial", "color": Color(0.60, 0.95, 1.00)}, 
	{"min": 1250, "name": "Cosmic", "color": Color(0.50, 0.55, 1.00)}, 
	{"min": 1500, "name": "Eternal", "color": Color(0.85, 0.55, 1.00)}, 
	{"min": 2000, "name": "Godlike", "color": Color(1.00, 0.95, 0.60)}, 
]

var _connected: = false
var _pending: Dictionary = {}


var _rooms: Dictionary = {}
var _peer_room: Dictionary = {}
var _peer_names: Dictionary = {}
var _peer_skins: Dictionary = {}
var _peer_pos: Dictionary = {}
var _last_hit_ms: Dictionary = {}
var _last_chat_ms: Dictionary = {}
var _last_voice_ms: Dictionary = {}
var _room_poll_elapsed: = 0.0
var _room_heartbeat_elapsed: = 0.0
var _room_polling: = false


func _ready() -> void :
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connect_fail)
	multiplayer.server_disconnected.connect(_on_server_gone)
	_load_cfg()
	cloud = CloudScript.new()
	cloud.name = "Cloud"
	add_child(cloud)





func _process(delta: float) -> void:
	if not is_p2p_host or active_room_id == "":
		return
	_room_poll_elapsed += delta
	_room_heartbeat_elapsed += delta
	if _room_poll_elapsed >= 6.0 and not _room_polling:
		_room_poll_elapsed = 0.0
		_poll_active_room.call_deferred(active_room_id)
	if _room_heartbeat_elapsed >= 30.0:
		_room_heartbeat_elapsed = 0.0
		_send_room_heartbeat.call_deferred(active_room_id)


func _poll_active_room(room_id: String) -> void:
	if _room_polling or room_id != active_room_id:
		return
	_room_polling = true
	var r: Dictionary = await cloud.get_active_room(room_id)
	_room_polling = false
	if room_id != active_room_id or not r["ok"] or not (r["data"] is Dictionary):
		return
	var fields: Dictionary = r["data"].get("fields", {})
	var new_code: String = normalize_code(str(cloud._fv(fields, "invite_code", "")))
	if new_code != "" and new_code != invite_code and _valid_invite_code(new_code):
		var alias_result: Dictionary = await cloud.replace_room_invite(room_id, invite_code, new_code)
		if not alias_result.get("ok", false):
			await cloud.update_active_room(room_id, {"invite_code": {"stringValue": invite_code}})
			invite_code_update_failed.emit("Admin invite code is unavailable; the previous code stays active")
			return
		invite_code = new_code
		# The host app never edits invite_code; a Firestore change therefore came from an admin.
		var by_admin: = true
		invite_code_changed.emit(invite_code, by_admin)
		if _rooms.has(room_code):
			for member_id in _rooms[room_code]["members"]:
				_to(member_id, &"cl_invite_code_changed", [invite_code, by_admin])


func _send_room_heartbeat(room_id: String) -> void:
	if room_id == active_room_id and cloud != null:
		await cloud.update_active_room(room_id, {
			"last_seen": {"integerValue": str(int(Time.get_unix_time_from_system() * 1000.0))},
		})


func _close_room_record(room_id: String, code: String) -> void:
	if cloud != null:
		await cloud.close_active_room(room_id, code)


func in_room() -> bool:
	return room_code != ""


func is_room_host() -> bool:
	return in_room() and room_host_id == multiplayer.get_unique_id()


func set_player_name(n: String) -> void :
	if username_locked:
		return
	player_name = _clean_name(n)
	save_cfg()



func register_username(n: String) -> String:
	if username_locked:
		return "Username is already set"
	var name_clean: = n.strip_edges().strip_escapes()
	if name_clean.length() < USERNAME_MIN:
		return "Username is too short (min 3 letters)"
	if name_clean.length() > NAME_MAX:
		return "Username is too long"
	var rx: = RegEx.new()
	rx.compile("^[A-Za-z0-9_\\x{0600}-\\x{06FF}]+$")
	if rx.search(name_clean) == null:
		return "Use letters, numbers and _ only"
	player_name = name_clean
	username_locked = true
	save_cfg()
	return ""



func adopt_locked_username(n: String) -> void :
	var name_clean: = n.strip_edges().strip_escapes().left(NAME_MAX)
	if name_clean == "":
		return
	player_name = name_clean
	username_locked = true
	save_cfg()


func reset_run() -> void :
	run_time = 0.0
	deaths = 0
	run_active = false
	teleported_run = false


func host_lan() -> Error:
	leave()
	var peer: = ENetMultiplayerPeer.new()
	var err: = peer.create_server(LAN_PORT, MAX_ROOM_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.LAN
	_connected = true
	_rooms["LAN"] = _new_room(1, "LAN")
	_peer_room[1] = "LAN"
	_peer_names[1] = player_name
	_peer_skins[1] = Economy.equipped
	cl_room_joined("LAN", {1: player_name}, 1, false)
	return OK


func join_lan(ip: String) -> Error:
	leave()
	_pending = {"type": "join", "code": "LAN"}
	return _open_client(ip, LAN_PORT, Mode.LAN)


func create_online_room() -> Error:
	leave()
	if cloud == null or not cloud.is_signed_in():
		return ERR_UNAUTHORIZED
	print("[net] create_online_room port=", P2P_PORT)
	var peer: = ENetMultiplayerPeer.new()
	var err: = peer.create_server(P2P_PORT, MAX_ROOM_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.ONLINE
	_connected = true
	is_p2p_host = true
	_attempt += 1
	_p2p_setup.call_deferred(_attempt)
	return OK


func join_online_room(code: String) -> Error:
	leave()
	var norm: = normalize_code(code)
	if not _valid_invite_code(norm):
		return ERR_INVALID_PARAMETER
	_attempt += 1
	_join_code = norm
	invite_code = norm
	p2p_status.emit("Looking up room code ...")
	_join_online_room_async.call_deferred(norm, _attempt)
	return OK


func normalize_code(code: String) -> String:
	return code.strip_edges().to_upper().replace("-", "").replace(" ", "")


func _valid_invite_code(code: String) -> bool:
	if code.length() < 1 or code.length() > 24:
		return false
	for ch in code:
		if not "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".contains(ch):
			return false
	return true


func display_code(code: String) -> String:
	var out: = ""
	for i in code.length():
		if i > 0 and i % 4 == 0:
			out += "-"
		out += code[i]
	return out


func _random_invite_code() -> String:
	var rng: = RandomNumberGenerator.new()
	rng.randomize()
	var result: = ""
	for _i in 10:
		result += CODE_CHARS[rng.randi_range(0, CODE_CHARS.length() - 1)]
	return result


func _random_room_id() -> String:
	var rng: = RandomNumberGenerator.new()
	rng.randomize()
	return ("room_%08x%08x" % [rng.randi(), rng.randi()]).to_upper()


func _join_online_room_async(code: String, attempt_id: int) -> void:
	var lookup: Dictionary = await cloud.find_active_room(code)
	if attempt_id != _attempt or mode != Mode.OFFLINE:
		return
	if not lookup.get("ok", false):
		room_failed.emit(str(lookup.get("message", "Could not find an active room with this code")))
		return
	var room: Dictionary = lookup["room"]
	var room_id: String = str(room.get("room_id", ""))
	if room_id == "":
		room_failed.emit("The room record is incomplete")
		return
	_pending = {"type": "join", "code": room_id}
	_fallback = {"url": RELAY_URL, "room": room_id}
	_warm_relay(RELAY_URL)
	_start_relay_join()


func _is_private_ip(ip: String) -> bool:
	if ip == "" or ip.contains(":"):
		return true
	var p: = ip.split(".")
	if p.size() != 4:
		return true
	var a: = int(p[0])
	var b: = int(p[1])
	return a == 10 or a == 127 or a == 0 or (a == 192 and b == 168) or (a == 172 and b >= 16 and b <= 31)\
	or (a == 100 and b >= 64 and b <= 127) or (a == 169 and b == 254)


func _upnp_worker(port: int, result: Dictionary) -> void :
	var u: = UPNP.new()
	if u.discover(2000, 2, "InternetGatewayDevice") != UPNP.UPNP_RESULT_SUCCESS:
		return
	var gw: = u.get_gateway()
	if gw == null or not gw.is_valid_gateway():
		return
	if u.add_port_mapping(port, port, "RoofGroove", "UDP", 0) != UPNP.UPNP_RESULT_SUCCESS:
		return
	result["upnp"] = u
	result["ext"] = u.query_external_address()


func _lookup_public_ip() -> String:
	var req: = HTTPRequest.new()
	req.timeout = 6.0
	add_child(req)
	if req.request(IP_LOOKUP_URL) != OK:
		req.queue_free()
		return ""
	var res: Array = await req.request_completed
	req.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200:
		return ""
	var txt: = (res[3] as PackedByteArray).get_string_from_utf8().strip_edges()
	return txt if txt.split(".").size() == 4 else ""


## Runs after the local host socket is open: forwards the port (UPnP), finds the address friends
## must use, builds the room code and opens the lobby. No central server is involved.
func _p2p_setup(attempt_id: int) -> void:
	p2p_status.emit("Connecting to the relay server ...")
	if attempt_id != _attempt or not is_p2p_host:
		return
	_warm_relay(RELAY_URL)
	p2p_note = ""
	public_ip = "relay"
	var room_id: String = _random_room_id()
	var invite: String = _random_invite_code()
	var registered: Dictionary = await cloud.register_active_room(room_id, invite, "relay", P2P_PORT, "")
	if not registered.get("ok", false):
		leave()
		room_failed.emit("Could not register the room in Firebase: " + str(registered.get("message", "Firebase error")))
		return
	if attempt_id != _attempt or not is_p2p_host:
		return
	active_room_id = room_id
	room_code = room_id
	invite_code = invite
	_room_poll_elapsed = 0.0
	_room_heartbeat_elapsed = 0.0
	print("[net] room hosted through relay invite=", invite_code)
	_start_relay_host(RELAY_URL, room_id)
	_rooms[room_id] = _new_room(1, room_id)
	_peer_room[1] = room_id
	_peer_names[1] = player_name
	_peer_skins[1] = Economy.equipped
	cl_room_joined(room_id, {1: player_name}, 1, false)


## Online rooms always tunnel their ENet traffic through the configured WebSocket relay.
func _get_relay_url() -> String:
	return RELAY_URL


## Free hosts put idle servers to sleep; a plain HTTP request wakes the relay up in the background.
func _warm_relay(url: String) -> void :
	var req: = HTTPRequest.new()
	req.timeout = 70.0
	add_child(req)
	req.request_completed.connect( func(_result, _code, _headers, _body): req.queue_free())
	if req.request(url.replace("wss://", "https://").replace("ws://", "http://") + "/health") != OK:
		req.queue_free()


func _stop_relay() -> void :
	if _relay != null and is_instance_valid(_relay):
		_relay.stop()
	_relay = null


func _start_relay_host(url: String, room_id: String) -> void :
	_stop_relay()
	_relay = RelayClient.new()
	_relay.name = "RelayClient"
	add_child(_relay)
	_relay.failed.connect( func(reason: String): push_warning("[net] relay host: " + reason))
	_relay.start_host(url, room_id, P2P_PORT)


func _start_relay_join() -> void :
	var fb: Dictionary = _fallback
	_fallback = {}
	if fb.is_empty():
		return
	_relay_phase = true
	var old: = multiplayer.multiplayer_peer
	if old != null and not (old is OfflineMultiplayerPeer):
		old.close()
	multiplayer.multiplayer_peer = null
	mode = Mode.ONLINE
	_pending = {"type": "join", "code": str(fb["room"])}
	p2p_status.emit("Connecting through the relay server ...")
	_stop_relay()
	_relay = RelayClient.new()
	_relay.name = "RelayClient"
	add_child(_relay)
	_relay.client_ready.connect(_on_relay_client_ready)
	_relay.failed.connect(_on_relay_client_failed)
	_relay.start_client(str(fb["url"]), str(fb["room"]))
	var my_attempt: int = _attempt
	get_tree().create_timer(RELAY_TIMEOUT).timeout.connect( func(): _on_relay_timeout(my_attempt))


func _on_relay_client_ready(port: int) -> void :
	if not _relay_phase or mode == Mode.OFFLINE or _connected:
		return
	if _open_client("127.0.0.1", port, Mode.ONLINE) != OK:
		_on_relay_client_failed("enet")


func _on_relay_client_failed(_reason: String) -> void :
	if _connected or mode == Mode.OFFLINE:
		return
	leave()
	connection_failed.emit()


func _on_relay_timeout(attempt_id: int) -> void :
	if attempt_id != _attempt or _connected or mode == Mode.OFFLINE:
		return
	leave()
	connection_failed.emit()


func _close_upnp(u: UPNP) -> void :
	if u == null:
		return
	WorkerThreadPool.add_task( func(): u.delete_port_mapping(P2P_PORT, "UDP"))


func request_start() -> void :
	if not is_room_host():
		return
	if multiplayer.is_server():
		_handle_start(1)
	else:
		srv_start_game.rpc_id(1)



func set_room_mode(m: String) -> void :
	if not is_room_host() or not (m in MODES):
		return
	if multiplayer.is_server():
		_handle_mode(1, m)
	else:
		srv_set_mode.rpc_id(1, m)



func send_ready() -> void :
	if multiplayer.is_server():
		_handle_ready(1)
	elif _connected:
		srv_ready.rpc_id(1)


func send_race_done(t: float) -> void :
	if multiplayer.is_server():
		_handle_race_done(1, t)
	elif _connected:
		srv_race_done.rpc_id(1, t)


func send_shot(pos: Vector2, dir: float) -> void :
	if multiplayer.is_server():
		_handle_shot(1, pos, dir)
	elif _connected:
		srv_shot.rpc_id(1, pos, dir)


func send_hit(victim: int) -> void :
	if multiplayer.is_server():
		_handle_hit(1, victim)
	elif _connected:
		srv_hit.rpc_id(1, victim)



func request_rematch() -> void :
	if not is_room_host():
		return
	if multiplayer.is_server():
		_handle_rematch(1)
	elif _connected:
		srv_rematch.rpc_id(1)



func send_my_skin() -> void :
	if not in_room():
		return
	member_skins[multiplayer.get_unique_id()] = Economy.equipped
	if multiplayer.is_server():
		_handle_skin(1, Economy.equipped)
	elif _connected:
		srv_set_skin.rpc_id(1, Economy.equipped)



func set_room_world(world_id: String, world_name: String) -> void :
	if not is_room_host():
		return
	if multiplayer.is_server():
		_handle_world(1, world_id, world_name)
	else:
		srv_set_world.rpc_id(1, world_id, world_name)


func _on_my_skin_changed(_id: String) -> void :
	send_my_skin()


func skin_of(id: int) -> String:
	return str(member_skins.get(id, "classic"))


func send_state(pos: Vector2, anim_name: String, flip: bool) -> void :
	if not in_room():
		return
	if multiplayer.is_server():
		_handle_state(1, pos, anim_name, flip)
	elif _connected:
		srv_state.rpc_id(1, pos, anim_name, flip)


func request_leaderboard(level: String = LEVEL_ID) -> void :
	# No central server any more: this is the best times saved on this device.
	var entries: Array = []
	if local_best.has(level):
		entries.append({"name": player_name, "time": float(local_best[level]), "deaths": 0})
	leaderboard_received.emit.call_deferred(level, entries)


func submit_time(level: String, t: float) -> void :
	if not is_finite(t) or t < MIN_TIME or t > 86400.0:
		time_result.emit.call_deferred(level, -1, false)
		return
	var is_best: = t < float(local_best.get(level, INF))
	if is_best:
		local_best[level] = t
		save_cfg()
	time_result.emit.call_deferred(level, 0, is_best)


func leave() -> void :
	var room_id_to_close: String = active_room_id if is_p2p_host else ""
	var invite_to_close: String = invite_code
	if room_id_to_close != "":
		_close_room_record.call_deferred(room_id_to_close, invite_to_close)
	_pending = {}
	_join_code = ""
	_fallback = {}
	_relay_phase = false
	_stop_relay()
	_attempt += 1
	mode = Mode.OFFLINE
	_connected = false
	_reset_room()
	_rooms.clear()
	_peer_room.clear()
	_peer_names.clear()
	_peer_skins.clear()
	_peer_pos.clear()
	_last_chat_ms.clear()
	_last_voice_ms.clear()
	var peer: = multiplayer.multiplayer_peer
	if peer != null and not (peer is OfflineMultiplayerPeer):
		peer.close()
	multiplayer.multiplayer_peer = null
	if _upnp != null:
		_close_upnp(_upnp)
		_upnp = null
	is_p2p_host = false
	public_ip = ""
	p2p_note = ""


func get_lan_ips() -> PackedStringArray:
	# Private LAN addresses first, then VPN-style ones (Tailscale 100.x, Hamachi 25.x, Radmin 26.x, ZeroTier ...)
	var lan: = PackedStringArray()
	var other: = PackedStringArray()
	for a in IP.get_local_addresses():
		if a.contains(":") or a.begins_with("127.") or a.begins_with("169.254.") or a.begins_with("0."):
			continue
		if a.split(".").size() != 4:
			continue
		var p: = a.split(".")
		var b: = int(p[1])
		if a.begins_with("192.168.") or a.begins_with("10.") or (int(p[0]) == 172 and b >= 16 and b <= 31):
			lan.append(a)
		else:
			other.append(a)
	lan.append_array(other)
	return lan


func format_time(t: float) -> String:
	var m: = int(t / 60.0)
	var s: = t - m * 60.0
	return "%d:%05.2f" % [m, s]



func rank_for(cp: int) -> Dictionary:
	var out: Dictionary = RANKS[0]
	for r in RANKS:
		if cp >= int(r["min"]):
			out = r
	return out




func resume_checkpoint(world_seed: int) -> int:


	if checkpoint > 0 and checkpoint_seed != 0 and checkpoint_seed != world_seed:
		checkpoint = 0
	checkpoint_seed = world_seed
	return checkpoint


func reach_checkpoint(idx: int, world_seed: int) -> void :
	if idx > best_checkpoint:
		Economy.add_tokens(Economy.TOKENS_PER_CHECKPOINT)
	checkpoint = idx
	checkpoint_seed = world_seed
	best_checkpoint = maxi(best_checkpoint, idx)
	save_cfg()
	if cloud != null:
		cloud.push_now()



func tick_profile(delta: float) -> void :
	total_time += delta
	_save_accum += delta
	if _save_accum >= 10.0:
		_save_accum = 0.0
		save_cfg()


func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _upnp != null:
			var u: = _upnp
			_upnp = null
			u.delete_port_mapping(P2P_PORT, "UDP")
		save_cfg()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_cfg()


func save_cfg() -> void :
	var cfg: = ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "name_locked", username_locked)
	cfg.set_value("player", "uid", uid)
	cfg.set_value("player", "last_ip", last_ip)
	cfg.set_value("best", "times", local_best)
	cfg.set_value("progress", "checkpoint", checkpoint)
	cfg.set_value("progress", "checkpoint_seed", checkpoint_seed)
	cfg.set_value("progress", "best_checkpoint", best_checkpoint)
	cfg.set_value("progress", "total_time", total_time)
	cfg.set_value("progress", "total_deaths", total_deaths)
	cfg.save(CFG_FILE)





func _load_cfg() -> void :
	var cfg: = ConfigFile.new()
	cfg.load(CFG_FILE)
	player_name = str(cfg.get_value("player", "name", ""))
	if player_name == "":
		player_name = "Player%d" % (randi() % 900 + 100)
	username_locked = bool(cfg.get_value("player", "name_locked", false))
	uid = str(cfg.get_value("player", "uid", ""))
	last_ip = str(cfg.get_value("player", "last_ip", ""))
	local_best = cfg.get_value("best", "times", {})
	checkpoint = int(cfg.get_value("progress", "checkpoint", 0))
	checkpoint_seed = int(cfg.get_value("progress", "checkpoint_seed", 0))
	best_checkpoint = int(cfg.get_value("progress", "best_checkpoint", 0))
	total_time = float(cfg.get_value("progress", "total_time", 0.0))
	total_deaths = int(cfg.get_value("progress", "total_deaths", 0))
	if uid == "":
		uid = "%08x%08x" % [randi(), randi()]
		save_cfg()



func _open_client(address: String, port: int, m: Mode) -> Error:
	var peer: = ENetMultiplayerPeer.new()
	var err: = peer.create_client(address, port)
	if err != OK:
		_pending = {}
		return err
	multiplayer.multiplayer_peer = peer
	mode = m
	return OK


func _same_lan_subnet(host_lan_ip: String) -> bool:
	var host_parts: PackedStringArray = host_lan_ip.split(".")
	if host_parts.size() != 4:
		return false
	var prefix: String = ".".join(host_parts.slice(0, 3))
	for local_ip in get_lan_ips():
		if ".".join(local_ip.split(".").slice(0, 3)) == prefix:
			return true
	return false



func _on_attempt_timeout(attempt_id: int) -> void :
	if attempt_id != _attempt or _connected or mode == Mode.OFFLINE:
		return
	if _relay_phase:
		return
	if not _fallback.is_empty():
		_start_relay_join()
		return
	leave()
	connection_failed.emit()


func _reset_room() -> void :
	room_code = ""
	invite_code = ""
	active_room_id = ""
	room_host_id = 0
	members = {}
	member_skins = {}
	room_world = ""
	room_world_name = ""
	room_mode = "adventure"
	room_seed = 0
	_reset_match()


func _reset_match() -> void :
	race_results = []
	pvp_hp = {}
	pvp_kills = {}
	pvp_deaths = {}
	pvp_alive = {}
	pvp_active = false


func _on_connected_ok() -> void :
	print("[net] connected to host")
	_connected = true
	connected_to_server.emit()
	var p: = _pending
	_pending = {}
	match str(p.get("type", "")):
		"join":
			srv_join_room.rpc_id(1, p["code"], player_name)


func _on_connect_fail() -> void :
	print("[net] connection failed")
	if not _fallback.is_empty() and not _relay_phase:
		_start_relay_join()
		return
	leave()
	connection_failed.emit()


func _on_server_gone() -> void :
	if mode == Mode.OFFLINE:
		return
	if _relay_phase and not _connected:
		return
	leave()
	disconnected.emit()



@rpc("authority", "call_remote", "reliable")
func cl_room_joined(code: String, mem: Dictionary, host_id: int, started: bool) -> void :
	room_code = code
	if mode == Mode.LAN:
		invite_code = code
	elif is_p2p_host and invite_code == "":
		invite_code = code
	members = mem
	room_host_id = host_id
	room_joined.emit(code)
	if not Economy.skin_changed.is_connected(_on_my_skin_changed):
		Economy.skin_changed.connect(_on_my_skin_changed)
	send_my_skin()
	if started:
		game_started.emit(LEVEL_PATH)


@rpc("authority", "call_remote", "reliable")
func cl_invite_code_changed(code: String, by_admin: bool) -> void:
	invite_code = code
	invite_code_changed.emit(code, by_admin)


@rpc("authority", "call_remote", "reliable")
func cl_room_failed(reason: String) -> void :
	room_failed.emit(reason)


@rpc("authority", "call_remote", "reliable")
func cl_peer_joined(id: int, pname: String) -> void :
	members[id] = pname
	peer_joined.emit(id, pname)


@rpc("authority", "call_remote", "reliable")
func cl_peer_left(id: int, new_host: int) -> void :
	members.erase(id)
	member_skins.erase(id)
	room_host_id = new_host
	peer_left.emit(id)


@rpc("authority", "call_remote", "reliable")
func cl_start_game() -> void :
	print("[net] cl_start_game mode=", room_mode, " world=", room_world)
	_reset_match()
	game_started.emit(LEVEL_PATH)


@rpc("authority", "call_remote", "reliable")
func cl_mode(m: String) -> void :
	room_mode = m if m in MODES else "adventure"
	mode_changed.emit(room_mode)


@rpc("authority", "call_remote", "reliable")
func cl_seed(seed_value: int) -> void :
	room_seed = seed_value


@rpc("authority", "call_remote", "reliable")
func cl_go(pvp_seconds: float) -> void :
	pvp_active = room_mode == "pvp"
	pvp_time_limit = pvp_seconds
	go_received.emit()


@rpc("authority", "call_remote", "reliable")
func cl_race_done(id: int, place: int, t: float) -> void :
	race_results.append({"id": id, "place": place, "time": t})
	race_done.emit(id, place, t)


@rpc("authority", "call_remote", "reliable")
func cl_shot(id: int, pos: Vector2, dir: float) -> void :
	shot_received.emit(id, pos, dir)


@rpc("authority", "call_remote", "reliable")
func cl_pvp_state(hp: Dictionary, kills: Dictionary, deaths: Dictionary, alive: Dictionary) -> void :
	pvp_hp = hp
	pvp_kills = kills
	pvp_deaths = deaths
	pvp_alive = alive
	pvp_updated.emit()


@rpc("authority", "call_remote", "reliable")
func cl_pvp_kill(killer: int, victim: int) -> void :
	pvp_kill.emit(killer, victim)


@rpc("authority", "call_remote", "reliable")
func cl_pvp_respawn(id: int, spawn_index: int) -> void :
	pvp_respawn.emit(id, spawn_index)


@rpc("authority", "call_remote", "reliable")
func cl_pvp_end(winner: int) -> void :
	pvp_active = false
	pvp_ended.emit(winner)


@rpc("authority", "call_remote", "reliable")
func cl_lobby() -> void :
	_reset_match()
	lobby_requested.emit()


@rpc("authority", "call_remote", "reliable")
func cl_skin(id: int, skin: String) -> void :
	member_skins[id] = skin
	skin_received.emit(id, skin)


@rpc("authority", "call_remote", "reliable")
func cl_world(world_id: String, world_name: String) -> void :
	room_world = world_id
	room_world_name = world_name
	world_changed.emit(world_id, world_name)


@rpc("authority", "call_remote", "unreliable_ordered")
func cl_state(id: int, pos: Vector2, anim_name: String, flip: bool) -> void :
	state_received.emit(id, pos, anim_name, flip)


@rpc("any_peer", "call_remote", "reliable")
func srv_join_room(code: String, pname: String) -> void :
	if multiplayer.is_server():
		_handle_join(multiplayer.get_remote_sender_id(), code, pname)


@rpc("any_peer", "call_remote", "reliable")
func srv_start_game() -> void :
	if multiplayer.is_server():
		_handle_start(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func srv_set_skin(skin: String) -> void :
	if multiplayer.is_server():
		_handle_skin(multiplayer.get_remote_sender_id(), skin)


@rpc("any_peer", "call_remote", "reliable")
func srv_set_mode(m: String) -> void :
	if multiplayer.is_server():
		_handle_mode(multiplayer.get_remote_sender_id(), m)


@rpc("any_peer", "call_remote", "reliable")
func srv_ready() -> void :
	if multiplayer.is_server():
		_handle_ready(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func srv_race_done(t: float) -> void :
	if multiplayer.is_server():
		_handle_race_done(multiplayer.get_remote_sender_id(), t)


@rpc("any_peer", "call_remote", "reliable")
func srv_shot(pos: Vector2, dir: float) -> void :
	if multiplayer.is_server():
		_handle_shot(multiplayer.get_remote_sender_id(), pos, dir)


@rpc("any_peer", "call_remote", "reliable")
func srv_hit(victim: int) -> void :
	if multiplayer.is_server():
		_handle_hit(multiplayer.get_remote_sender_id(), victim)


@rpc("any_peer", "call_remote", "reliable")
func srv_rematch() -> void :
	if multiplayer.is_server():
		_handle_rematch(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func srv_set_world(world_id: String, world_name: String) -> void :
	if multiplayer.is_server():
		_handle_world(multiplayer.get_remote_sender_id(), world_id, world_name)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func srv_state(pos: Vector2, anim_name: String, flip: bool) -> void :
	if multiplayer.is_server():
		_handle_state(multiplayer.get_remote_sender_id(), pos, anim_name, flip)


func _to(id: int, method: StringName, args: Array = []) -> void :
	if id == multiplayer.get_unique_id():
		callv(method, args)
	else:
		callv("rpc_id", [id, method] + args)


func _handle_join(id: int, code: String, pname: String) -> void :
	code = code.strip_edges().to_upper()
	_handle_leave(id)
	if not _rooms.has(code):
		_to(id, &"cl_room_failed", ["Room not found"])
		return
	var room: Dictionary = _rooms[code]
	var mem: Array = room["members"]
	if mem.size() >= MAX_ROOM_PLAYERS:
		_to(id, &"cl_room_failed", ["Room is full"])
		return
	_peer_names[id] = _unique_name(code, pname)
	for m in mem:
		_to(m, &"cl_peer_joined", [id, _peer_names[id]])
	var existing: Array = mem.duplicate()
	mem.append(id)
	_peer_room[id] = code

	_to(id, &"cl_world", [str(room.get("world", "")), str(room.get("world_name", ""))])
	_to(id, &"cl_mode", [str(room.get("mode", "adventure"))])
	_to(id, &"cl_seed", [int(room.get("seed", 0))])
	_to(id, &"cl_room_joined", [code, _member_names(code), room["host"], room["started"]])
	for m in existing:
		_to(id, &"cl_skin", [m, str(_peer_skins.get(m, "classic"))])


func _new_room(host_id: int, code: String) -> Dictionary:
	return {"code": code, "members": [host_id], "host": host_id, "started": false, "world": "", "world_name": "", 
		"mode": "adventure", "seed": 0, "ready": [], "go": false, "race_done": {}, "pvp": {}}


func _room_of(id: int) -> Dictionary:
	var code: String = _peer_room.get(id, "")
	if code == "" or not _rooms.has(code):
		return {}
	return _rooms[code]


func _room_code_of(room: Dictionary) -> String:
	return str(room.get("code", ""))


func _handle_mode(id: int, m: String) -> void :
	var room: = _room_of(id)
	if room.is_empty() or room["host"] != id or room["started"] or not (m in MODES):
		return
	room["mode"] = m
	for mem in room["members"]:
		_to(mem, &"cl_mode", [m])



func _handle_ready(id: int) -> void :
	var room: = _room_of(id)
	if room.is_empty() or not room["started"] or room["go"]:
		return
	var ready_ids: Array = room["ready"]
	if not ready_ids.has(id):
		ready_ids.append(id)
	var code: = _room_code_of(room)
	if ready_ids.size() >= (room["members"] as Array).size():
		_do_go(code)
	elif ready_ids.size() == 1:
		get_tree().create_timer(READY_TIMEOUT).timeout.connect(_do_go.bind(code, true))


func _do_go(code: String, from_timeout: bool = false) -> void :
	if not _rooms.has(code):
		return
	var room: Dictionary = _rooms[code]
	if room["go"] or not room["started"]:
		return
	room["go"] = true
	var secs: = 0.0
	if room["mode"] == "pvp":
		secs = PVP_TIME
		var pv: = {"hp": {}, "kills": {}, "deaths": {}, "alive": {}, "over": false}
		for m in room["members"]:
			pv["hp"][m] = PVP_HP
			pv["kills"][m] = 0
			pv["deaths"][m] = 0
			pv["alive"][m] = true
		room["pvp"] = pv
		get_tree().create_timer(PVP_TIME).timeout.connect(_pvp_time_up.bind(code))
	for m in room["members"]:
		_to(m, &"cl_go", [secs])
	if room["mode"] == "pvp":
		_pvp_broadcast(code)


func _handle_race_done(id: int, t: float) -> void :
	var room: = _room_of(id)
	if room.is_empty() or room["mode"] != "race" or not room["go"]:
		return
	var done: Dictionary = room["race_done"]
	if done.has(id) or not is_finite(t) or t < 1.0 or t > 3600.0:
		return
	done[id] = t
	for m in room["members"]:
		_to(m, &"cl_race_done", [id, done.size(), t])


func _handle_shot(id: int, pos: Vector2, dir: float) -> void :
	var room: = _room_of(id)
	if room.is_empty() or room["mode"] != "pvp":
		return
	var pv: Dictionary = room["pvp"]
	if pv.is_empty() or pv["over"] or not pv["alive"].get(id, false) or not pos.is_finite():
		return
	for m in room["members"]:
		if m != id:
			_to(m, &"cl_shot", [id, pos, signf(dir)])


func _handle_hit(id: int, victim: int) -> void :
	var room: = _room_of(id)
	if room.is_empty() or room["mode"] != "pvp" or id == victim:
		return
	var pv: Dictionary = room["pvp"]
	if pv.is_empty() or pv["over"] or _peer_room.get(victim, "") != _peer_room.get(id, "x"):
		return
	if not pv["alive"].get(id, false) or not pv["alive"].get(victim, false):
		return
	var now: = Time.get_ticks_msec()
	if now - int(_last_hit_ms.get(id, 0)) < 150:
		return
	_last_hit_ms[id] = now
	if _peer_pos.has(id) and _peer_pos.has(victim) and (_peer_pos[id] as Vector2).distance_to(_peer_pos[victim]) > 520.0:
		return
	pv["hp"][victim] = maxi(0, int(pv["hp"][victim]) - PVP_DAMAGE)
	var code: = _room_code_of(room)
	if int(pv["hp"][victim]) <= 0:
		pv["alive"][victim] = false
		pv["kills"][id] = int(pv["kills"][id]) + 1
		pv["deaths"][victim] = int(pv["deaths"][victim]) + 1
		for m in room["members"]:
			_to(m, &"cl_pvp_kill", [id, victim])
		_pvp_broadcast(code)
		if int(pv["kills"][id]) >= PVP_KILL_LIMIT:
			_pvp_end(code, id)
			return
		get_tree().create_timer(2.5).timeout.connect(_pvp_respawn.bind(code, victim))
	else:
		_pvp_broadcast(code)


func _pvp_respawn(code: String, victim: int) -> void :
	if not _rooms.has(code):
		return
	var room: Dictionary = _rooms[code]
	var pv: Dictionary = room["pvp"]
	if pv.is_empty() or pv["over"] or not (room["members"] as Array).has(victim):
		return
	pv["hp"][victim] = PVP_HP
	pv["alive"][victim] = true
	for m in room["members"]:
		_to(m, &"cl_pvp_respawn", [victim, randi() % PVP_SPAWNS])
	_pvp_broadcast(code)


func _pvp_broadcast(code: String) -> void :
	if not _rooms.has(code):
		return
	var room: Dictionary = _rooms[code]
	var pv: Dictionary = room["pvp"]
	if pv.is_empty():
		return
	for m in room["members"]:
		_to(m, &"cl_pvp_state", [pv["hp"], pv["kills"], pv["deaths"], pv["alive"]])


func _pvp_time_up(code: String) -> void :
	if not _rooms.has(code):
		return
	var pv: Dictionary = _rooms[code]["pvp"]
	if pv.is_empty() or pv["over"]:
		return
	var best: = 0
	var best_kills: = -1
	var tie: = false
	for m in pv["kills"]:
		var k: = int(pv["kills"][m])
		if k > best_kills:
			best_kills = k
			best = m
			tie = false
		elif k == best_kills:
			tie = true
	_pvp_end(code, 0 if tie else best)


func _pvp_end(code: String, winner: int) -> void :
	if not _rooms.has(code):
		return
	var room: Dictionary = _rooms[code]
	var pv: Dictionary = room["pvp"]
	if pv.is_empty() or pv["over"]:
		return
	pv["over"] = true
	_pvp_broadcast(code)
	for m in room["members"]:
		_to(m, &"cl_pvp_end", [winner])


func _handle_rematch(id: int) -> void :
	var room: = _room_of(id)
	if room.is_empty() or room["host"] != id or not room["started"]:
		return
	room["started"] = false
	room["go"] = false
	room["ready"] = []
	room["race_done"] = {}
	room["pvp"] = {}
	for m in room["members"]:
		_to(m, &"cl_lobby")


func _handle_skin(id: int, skin: String) -> void :
	var code: String = _peer_room.get(id, "")
	if code == "" or not _rooms.has(code):
		return
	if skin.length() > 24 or not Economy.SKINS.has(skin):
		skin = "classic"
	_peer_skins[id] = skin
	for m in _rooms[code]["members"]:
		if m != id:
			_to(m, &"cl_skin", [id, skin])


func _handle_world(id: int, world_id: String, world_name: String) -> void :
	var code: String = _peer_room.get(id, "")
	if code == "" or not _rooms.has(code):
		return
	var room: Dictionary = _rooms[code]
	if room["host"] != id or room["started"]:
		return
	world_id = world_id.strip_edges().left(80)
	world_name = world_name.strip_edges().strip_escapes().left(40)
	room["world"] = world_id
	room["world_name"] = world_name
	for m in room["members"]:
		_to(m, &"cl_world", [world_id, world_name])


func _handle_leave(id: int) -> void :
	_last_chat_ms.erase(id)
	_last_voice_ms.erase(id)
	var code: String = _peer_room.get(id, "")
	if code == "":
		return
	_peer_room.erase(id)
	if not _rooms.has(code):
		return
	var room: Dictionary = _rooms[code]
	var mem: Array = room["members"]
	mem.erase(id)
	if mem.is_empty():
		_rooms.erase(code)
		return
	if room["host"] == id:
		room["host"] = mem[0]
	var pv: Dictionary = room.get("pvp", {})
	if not pv.is_empty():
		for k in ["hp", "kills", "deaths", "alive"]:
			(pv[k] as Dictionary).erase(id)
	for m in mem:
		_to(m, &"cl_peer_left", [id, room["host"]])


func _handle_start(id: int) -> void :
	var code: String = _peer_room.get(id, "")
	if code == "" or not _rooms.has(code):
		return
	var room: Dictionary = _rooms[code]
	if room["host"] != id:
		return
	room["started"] = true
	room["seed"] = randi()
	room["ready"] = []
	room["go"] = false
	room["race_done"] = {}
	room["pvp"] = {}
	for m in room["members"]:
		_to(m, &"cl_seed", [int(room["seed"])])
		_to(m, &"cl_start_game")


func _handle_state(id: int, pos: Vector2, anim_name: String, flip: bool) -> void :
	var code: String = _peer_room.get(id, "")
	if code == "" or not _rooms.has(code):
		return
	if not pos.is_finite() or anim_name.length() > 24:
		return
	_peer_pos[id] = pos
	for m in _rooms[code]["members"]:
		if m != id:
			_to(m, &"cl_state", [id, pos, anim_name, flip])


func _on_peer_disconnected(id: int) -> void :
	if not multiplayer.is_server():
		return
	_handle_leave(id)
	_peer_names.erase(id)
	_peer_skins.erase(id)
	_peer_pos.erase(id)
	_last_hit_ms.erase(id)


func _member_names(code: String) -> Dictionary:
	var d: = {}
	for m in _rooms[code]["members"]:
		d[m] = _peer_names.get(m, "Player")
	return d



func _unique_name(code: String, wanted: String) -> String:
	var base: = _clean_name(wanted)
	var taken: Array = []
	for m in _rooms[code]["members"]:
		taken.append(_peer_names.get(m, ""))
	if not (base in taken):
		return base
	var n: = 2
	while true:
		var cand: = "%s %d" % [base.left(NAME_MAX - 2), n]
		if not (cand in taken):
			return cand
		n += 1
	return base


func _clean_name(s: String) -> String:
	s = s.strip_edges().strip_escapes().left(NAME_MAX)
	return s if s != "" else "Player"




func send_chat_message(raw_message: String) -> void:
	if not in_room():
		return
	var message := raw_message.strip_edges().strip_escapes().replace("\n", " ").replace("\r", " ").left(CHAT_MAX_CHARS)
	if message.is_empty():
		return
	if multiplayer.is_server():
		_handle_chat(1, message)
	elif _connected:
		srv_chat_message.rpc_id(1, message)


func send_voice_packet(packet: PackedByteArray) -> void:
	if not in_room() or packet.size() != VOICE_PACKET_BYTES:
		return
	if multiplayer.is_server():
		_handle_voice_packet(1, packet)
	elif _connected:
		srv_voice_packet.rpc_id(1, packet)


@rpc("any_peer", "call_remote", "reliable")
func srv_chat_message(message: String) -> void:
	if multiplayer.is_server():
		_handle_chat(multiplayer.get_remote_sender_id(), message)


@rpc("authority", "call_remote", "reliable")
func cl_chat_message(id: int, name: String, message: String) -> void:
	chat_received.emit(id, name, message)


@rpc("any_peer", "call_remote", "unreliable")
func srv_voice_packet(packet: PackedByteArray) -> void:
	if multiplayer.is_server():
		_handle_voice_packet(multiplayer.get_remote_sender_id(), packet)


@rpc("authority", "call_remote", "unreliable")
func cl_voice_packet(id: int, packet: PackedByteArray) -> void:
	if packet.size() == VOICE_PACKET_BYTES:
		voice_packet_received.emit(id, packet)


func _handle_chat(id: int, raw_message: String) -> void:
	var room := _room_of(id)
	if room.is_empty() or not bool(room.get("started", false)):
		return
	var message := raw_message.strip_edges().strip_escapes().replace("\n", " ").replace("\r", " ").left(CHAT_MAX_CHARS)
	if message.is_empty():
		return
	var now := Time.get_ticks_msec()
	if _last_chat_ms.has(id) and now - int(_last_chat_ms[id]) < 800:
		return
	_last_chat_ms[id] = now
	var name := str(_peer_names.get(id, "Player")).left(NAME_MAX)
	for member_id in room["members"]:
		_to(int(member_id), &"cl_chat_message", [id, name, message])


func _handle_voice_packet(id: int, packet: PackedByteArray) -> void:
	var room := _room_of(id)
	if room.is_empty() or not bool(room.get("started", false)):
		return
	if packet.size() != VOICE_PACKET_BYTES or (room["members"] as Array).size() > VOICE_MAX_MEMBERS:
		return
	var now := Time.get_ticks_msec()
	if _last_voice_ms.has(id) and now - int(_last_voice_ms[id]) < 10:
		return
	_last_voice_ms[id] = now
	for member_id in room["members"]:
		if int(member_id) != id:
			_to(int(member_id), &"cl_voice_packet", [id, packet])
