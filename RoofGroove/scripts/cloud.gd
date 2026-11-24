extends Node



signal device_code_ready(code: String, url: String)
signal login_status(text: String)
signal login_succeeded
signal login_failed(reason: String)
## Good news for the Pixel Account screens (account created, reset link sent ...).
signal pixel_notice(text: String)
signal browser_login_started(provider: String)
signal sync_done(ok: bool)
signal leaderboard_ready(ok: bool, entries: Array)
signal banned_detected

const Cfg: = preload("res://scripts/firebase_config.gd")
const StoryState: = preload("res://scripts/story_state.gd")
const UI: = preload("res://scripts/ui_kit.gd")
const BAN_CHECK_EVERY: = 300.0
const UNBAN_CHECK_EVERY: = 20.0
const SAVE_FILE: = "user://cloud.cfg"
const FORM: = ["Content-Type: application/x-www-form-urlencoded"]
const JSON_H: = ["Content-Type: application/json"]
# Server that swaps the Google code for an id_token (used only when the Desktop secret is not in firebase_config.gd).
const GOOGLE_EXCHANGE_URL: = "https://roofgroove-discord-auth.vercel.app/api/googleLogin"
const DISCORD_FORM: = ["Content-Type: application/x-www-form-urlencoded", "User-Agent: DiscordBot (https://roofgroove-discord-auth.vercel.app, 1.0)"]
const DISCORD_JSON: = ["Content-Type: application/json", "User-Agent: DiscordBot (https://roofgroove-discord-auth.vercel.app, 1.0)"]
const SYNC_EVERY: = 60.0
const FB_AUTH: = "https://identitytoolkit.googleapis.com/v1/accounts:"
## Our server sends the designed HTML emails (verify email / reset password). If it is not set up it answers
## with an error and the game falls back to Firebase's plain emails.
const MAIL_URL: = "https://roofgroove-discord-auth.vercel.app/api/sendAccountEmail"
## Firebase error code -> short message (translated in loc.gd).
const PIXEL_ERRORS: = {
	"EMAIL_EXISTS": "This email already has an account",
	"INVALID_EMAIL": "Enter a valid email address",
	"WEAK_PASSWORD": "Password must be at least 6 characters",
	"INVALID_LOGIN_CREDENTIALS": "Wrong email or password",
	"INVALID_PASSWORD": "Wrong email or password",
	"EMAIL_NOT_FOUND": "Wrong email or password",
	"TOO_MANY_ATTEMPTS_TRY_LATER": "Too many attempts. Try again later",
	"OPERATION_NOT_ALLOWED": "Pixel Account is not enabled yet (Firebase > Authentication > Email/Password)",
}
const LOOPBACK_PORTS: = [53682, 53683, 53684, 53685]
const LOOPBACK_TIMEOUT: = 300.0

var uid: = ""
var email: = ""
var id_token: = ""
var refresh_token: = ""
var token_expiry: = 0.0
var banned: = false

var _pushing: = false
var _logging_in: = false
var _login_cancel: = false
var _last_sig: = ""
var _timer: = 0.0
var _presence_timer: = 0.0
var _ban_timer: = 0.0
var _verifying: = false
var _ban_dialog: CanvasLayer = null
var _ban_status: Label = null
var _paused_by_ban: = false
var _rechecking: = false


func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	if banned and refresh_token == "":
		banned = false
		_save()
	if banned:
		_show_ban_screen.call_deferred()
		recheck_ban.call_deferred()
	elif refresh_token != "" and is_configured():
		_resume.call_deferred()


func _process(delta: float) -> void :
	if banned:
		_ban_timer += delta
		if _ban_timer >= UNBAN_CHECK_EVERY:
			_ban_timer = 0.0
			recheck_ban()
		return
	if not is_signed_in():
		return
	_presence_timer += delta
	if _presence_timer >= 35.0:
		_presence_timer = 0.0
		push_presence()
	_ban_timer += delta
	if _ban_timer >= BAN_CHECK_EVERY:
		_ban_timer = 0.0
		_verify_account()
	_timer += delta
	if _timer >= SYNC_EVERY:
		_timer = 0.0
		if _sig() != _last_sig:
			push_now()





func is_configured() -> bool:
	for v in [Cfg.API_KEY, Cfg.PROJECT_ID]:
		if str(v) == "" or str(v).begins_with("PUT_"):
			return false
	return true


func google_configured() -> bool:
	var device_flow_ready: bool = _real(Cfg.GOOGLE_CLIENT_ID) and _real(Cfg.GOOGLE_CLIENT_SECRET)
	return is_configured() and (device_flow_ready or google_loopback_ready())


func is_signed_in() -> bool:
	return refresh_token != "" and uid != "" and not banned


func cancel_login() -> void :
	_login_cancel = true


func sign_out() -> void :
	uid = ""
	email = ""
	id_token = ""
	refresh_token = ""
	token_expiry = 0.0
	_last_sig = ""
	_save()



func google_loopback_ready() -> bool:
	return _real(Cfg.GOOGLE_DESKTOP_CLIENT_ID) and (_real(Cfg.GOOGLE_DESKTOP_CLIENT_SECRET) or _real(GOOGLE_EXCHANGE_URL))


func discord_ready() -> bool:
	return _real(Cfg.DISCORD_CLIENT_ID) and _real(Cfg.DISCORD_LOGIN_URL)


func _real(v: Variant) -> bool:
	var t: = str(v)
	return t != "" and not t.begins_with("PUT_")


## Google sign in. Uses the browser + automatic return to the game (no code to type) when a
## Desktop OAuth client is configured, otherwise the old device-code flow.
func start_google_login(force_code: = false) -> void :
	if _logging_in:
		return
	_logging_in = true
	_login_cancel = false
	if google_loopback_ready() and not force_code:
		await _login_google_loopback()
	else:
		await _login_flow()
	_logging_in = false


## ---- Pixel Account (email + password through Firebase Authentication) --------------------------
func start_pixel_login(mail: String, password: String) -> void :
	if _logging_in:
		return
	_logging_in = true
	_login_cancel = false
	await _pixel_sign_in(mail.strip_edges().to_lower(), password)
	_logging_in = false


func start_pixel_signup(mail: String, password: String) -> void :
	if _logging_in:
		return
	_logging_in = true
	await _pixel_sign_up(mail.strip_edges().to_lower(), password)
	_logging_in = false


func start_password_reset(mail: String) -> void :
	if _logging_in:
		return
	_logging_in = true
	var clean_mail: = mail.strip_edges().to_lower()
	var r: Dictionary = {"ok": await _send_account_email("reset", clean_mail, "")}
	if not r["ok"]:
		r = await _http(HTTPClient.METHOD_POST, FB_AUTH + "sendOobCode?key=" + Cfg.API_KEY, _mail_headers(), 
			JSON.stringify({"requestType": "PASSWORD_RESET", "email": clean_mail}))
	_logging_in = false
	if r["ok"]:
		pixel_notice.emit("RESET LINK SENT - CHECK YOUR EMAIL")
	else:
		login_failed.emit(_pixel_error(_error_text(r)))


## Firebase writes the verification / password reset emails in this language (ar, en, fr).
func _mail_headers() -> Array:
	return ["Content-Type: application/json", "X-Firebase-Locale: " + str(Loc.current)]


## Asks our server to send the designed email. Returns false when the server is not set up (or fails),
## so the caller can use Firebase's own email instead.
func _send_account_email(kind: String, mail: String, tok: String) -> bool:
	var r: Dictionary = await _http(HTTPClient.METHOD_POST, MAIL_URL, JSON_H, 
		JSON.stringify({"type": kind, "email": mail, "idToken": tok, "lang": str(Loc.current)}))
	return bool(r["ok"])


func _pixel_error(msg: String) -> String:
	for code in PIXEL_ERRORS:
		if str(code) in msg:
			return str(PIXEL_ERRORS[code])
	return msg


func _pixel_sign_up(mail: String, password: String) -> void :
	var r: Dictionary = await _http(HTTPClient.METHOD_POST, FB_AUTH + "signUp?key=" + Cfg.API_KEY, _mail_headers(), 
		JSON.stringify({"email": mail, "password": password, "returnSecureToken": true}))
	if not r["ok"] or not (r["data"] is Dictionary):
		login_failed.emit(_pixel_error(_error_text(r)))
		return
	var tok: = str((r["data"] as Dictionary).get("idToken", ""))
	# The account only works after the player opens the link we email (stops fake accounts).
	if not await _send_account_email("verify", mail, tok):
		var v: Dictionary = await _http(HTTPClient.METHOD_POST, FB_AUTH + "sendOobCode?key=" + Cfg.API_KEY, _mail_headers(), 
			JSON.stringify({"requestType": "VERIFY_EMAIL", "idToken": tok}))
		if not v["ok"]:
			login_failed.emit(_pixel_error(_error_text(v)))
			return
	pixel_notice.emit("ACCOUNT CREATED - CHECK YOUR EMAIL FOR THE VERIFICATION LINK, THEN SIGN IN")


func _pixel_sign_in(mail: String, password: String) -> void :
	var r: Dictionary = await _http(HTTPClient.METHOD_POST, FB_AUTH + "signInWithPassword?key=" + Cfg.API_KEY, JSON_H, 
		JSON.stringify({"email": mail, "password": password, "returnSecureToken": true}))
	if not r["ok"] or not (r["data"] is Dictionary):
		var msg: = _error_text(r)
		if "USER_DISABLED" in msg:
			_handle_banned()
			login_failed.emit("YOU HAVE BEEN BANNED")
			return
		login_failed.emit(_pixel_error(msg))
		return
	var d: Dictionary = r["data"]
	var tok: = str(d.get("idToken", ""))
	var look: Dictionary = await _http(HTTPClient.METHOD_POST, FB_AUTH + "lookup?key=" + Cfg.API_KEY, JSON_H, JSON.stringify({"idToken": tok}))
	var verified: = false
	if look["ok"] and look["data"] is Dictionary:
		var users: Array = (look["data"] as Dictionary).get("users", [])
		if not users.is_empty():
			verified = bool((users[0] as Dictionary).get("emailVerified", false))
	if not verified:
		if not await _send_account_email("verify", mail, tok):
			await _http(HTTPClient.METHOD_POST, FB_AUTH + "sendOobCode?key=" + Cfg.API_KEY, _mail_headers(), 
				JSON.stringify({"requestType": "VERIFY_EMAIL", "idToken": tok}))
		login_failed.emit("EMAIL NOT VERIFIED - WE SENT YOU A NEW LINK")
		return
	var new_uid: = str(d.get("localId", ""))
	var new_refresh: = str(d.get("refreshToken", ""))
	if new_uid == "" or tok == "" or new_refresh == "":
		login_failed.emit("Firebase returned an incomplete sign-in session")
		return
	uid = new_uid
	email = mail
	id_token = tok
	refresh_token = new_refresh
	token_expiry = Time.get_unix_time_from_system() + float(d.get("expiresIn", 3600))
	banned = false
	_save()
	await _merge_with_cloud()
	if not is_signed_in():
		login_failed.emit("Firebase session was lost while syncing the account")
		return
	login_succeeded.emit()


func start_discord_login() -> void :
	if _logging_in:
		return
	_logging_in = true
	_login_cancel = false
	await _login_discord()
	_logging_in = false



func push_now() -> void :
	if not is_signed_in() or _pushing:
		return
	_pushing = true
	var fields: = {
		"name": {"stringValue": Network.player_name}, 
		"best_checkpoint": {"integerValue": str(Network.best_checkpoint)}, 
		"checkpoint": {"integerValue": str(Network.checkpoint)}, 
		"seed": {"integerValue": str(Network.checkpoint_seed)}, 
		"play_time": {"doubleValue": Network.total_time}, 
		"deaths": {"integerValue": str(Network.total_deaths)}, 
		"player_id": {"stringValue": FriendsSystem.player_id}, 
		"search_name": {"stringValue": Network.player_name.strip_edges().to_lower()},
		"profile_letter": {"stringValue": FriendsSystem.profile_letter},
		"profile_color": {"integerValue": str(FriendsSystem.profile_color)},
		"created_at": {"integerValue": str(maxi(1, FriendsSystem.member_since))},
		"username_locked": {"booleanValue": Network.username_locked}, 
		"tokens_earned": {"integerValue": str(Economy.earned)}, 
		"arena_gems": {"integerValue": str(Economy.arena_gems)}, 
		"skins_owned": {"arrayValue": {"values": Economy.owned.map( func(id): return {"stringValue": str(id)})}}, 
		"skin_equipped": {"stringValue": Economy.equipped}, 
		"codes_used": {"arrayValue": {"values": Economy.used_codes.map( func(c): return {"stringValue": str(c)})}}, 
	}

	if StoryState.has_progress():
		fields["story_cp"] = {"integerValue": str(StoryState.story_cp)}
		fields["story_seen"] = {"arrayValue": {"values": StoryState.seen.map( func(id): return {"stringValue": str(id)})}}
		fields["story_finished"] = {"booleanValue": StoryState.finished}
		fields["story_intro_seen"] = {"booleanValue": StoryState.intro_seen}

	var mask: = PackedStringArray()
	for k in fields:
		mask.append("updateMask.fieldPaths=" + str(k))
	var push_url: = _doc_url("players/" + uid) + "?" + "&".join(mask)
	var sig: = _sig()
	var r: Dictionary = await _authed(HTTPClient.METHOD_PATCH, push_url, JSON.stringify({"fields": fields}))
	_pushing = false
	if r["ok"]:
		_last_sig = sig
	sync_done.emit(r["ok"])



func fetch_leaderboard() -> void :
	var q: = {"structuredQuery": {
		"from": [{"collectionId": "players"}], 
		"orderBy": [{"field": {"fieldPath": "best_checkpoint"}, "direction": "DESCENDING"}], 
		"limit": 20, 
	}}
	var r: Dictionary = await _authed(HTTPClient.METHOD_POST, _doc_url("").trim_suffix("/") + ":runQuery", JSON.stringify(q))
	var entries: Array = []
	if r["ok"] and r["data"] is Array:
		for item in r["data"]:
			if item is Dictionary and item.has("document"):
				var f: Dictionary = item["document"].get("fields", {})
				entries.append({
					"name": str(_fv(f, "name", "Player")), 
					"best": int(_fv(f, "best_checkpoint", 0)), 
					"time": float(_fv(f, "play_time", 0.0)), 
					"deaths": int(_fv(f, "deaths", 0)), 
				})
	leaderboard_ready.emit(r["ok"], entries)


func fetch_messages_for(target_id: String) -> Array:
	var query: = {"structuredQuery": {
		"from": [{"collectionId": "inbox_messages"}], 
		"where": {"fieldFilter": {
			"field": {"fieldPath": "to_id"}, 
			"op": "EQUAL", 
			"value": {"stringValue": target_id}, 
		}}, 
		"limit": 30, 
	}}
	var r: Dictionary = await _authed(HTTPClient.METHOD_POST, _doc_url("").trim_suffix("/") + ":runQuery", JSON.stringify(query))
	var out: Array = []
	if r["ok"] and r["data"] is Array:
		for item in r["data"]:
			if item is Dictionary and item.has("document"):
				out.append(item["document"])
	return out


func search_players(prefix: String, by_id: bool) -> Dictionary:
	var field_path: String = "player_id" if by_id else "search_name"
	var needle: String = prefix.strip_edges() if by_id else prefix.strip_edges().to_lower()
	if needle == "":
		return {"ok": true, "documents": []}
	var query: = {"structuredQuery": {
		"from": [{"collectionId": "players"}],
		"where": {"fieldFilter": {
			"field": {"fieldPath": field_path},
			"op": "GREATER_THAN_OR_EQUAL",
			"value": {"stringValue": needle},
		}},
		"orderBy": [{"field": {"fieldPath": field_path}, "direction": "ASCENDING"}],
		"limit": 100,
	}}
	var r: Dictionary = await _authed(HTTPClient.METHOD_POST, _doc_url("").trim_suffix("/") + ":runQuery", JSON.stringify(query))
	var docs: Array = []
	if r["ok"] and r["data"] is Array:
		for item in r["data"]:
			if item is Dictionary and item.has("document"):
				var doc: Dictionary = item["document"]
				var fields: Dictionary = doc.get("fields", {})
				var value: String = str(_fv(fields, field_path, ""))
				var comparable: String = value if by_id else value.to_lower()
				if comparable.begins_with(needle):
					docs.append(doc)
					if docs.size() >= 20:
						break
	return {"ok": r["ok"], "code": int(r.get("code", 0)), "documents": docs}


func query_documents(collection: String, field_path: String, op: String, value: Dictionary, limit: int = 50) -> Dictionary:
	var query: = {"structuredQuery": {
		"from": [{"collectionId": collection}],
		"where": {"fieldFilter": {
			"field": {"fieldPath": field_path},
			"op": op,
			"value": value,
		}},
		"limit": limit,
	}}
	var r: Dictionary = await _authed(HTTPClient.METHOD_POST, _doc_url("").trim_suffix("/") + ":runQuery", JSON.stringify(query))
	var docs: Array = []
	if r["ok"] and r["data"] is Array:
		for item in r["data"]:
			if item is Dictionary and item.has("document"):
				docs.append(item["document"])
	return {"ok": r["ok"], "code": int(r.get("code", 0)), "documents": docs}


func update_profile(fields: Dictionary) -> Dictionary:
	if not is_signed_in():
		return {"ok": false, "message": "Sign in first"}
	return await _patch_firestore_doc("players/" + uid, fields)


func push_presence() -> void:
	if not is_signed_in():
		return
	await _patch_firestore_doc("players/" + uid, {
		"last_seen": {"integerValue": str(int(Time.get_unix_time_from_system()))},
	})





func _login_flow() -> void :
	if not google_configured():
		login_failed.emit("firebase_config.gd is not filled in")
		return
	login_status.emit("Contacting Google ...")
	var r: Dictionary = await _http(HTTPClient.METHOD_POST, "https://oauth2.googleapis.com/device/code", FORM, 
		_form({"client_id": Cfg.GOOGLE_CLIENT_ID, "scope": "openid email profile"}))
	if not r["ok"] or not (r["data"] is Dictionary):
		login_failed.emit(_error_text(r))
		return
	var d: Dictionary = r["data"]
	var interval: = float(d.get("interval", 5))
	var expires: = float(d.get("expires_in", 1800))
	device_code_ready.emit(str(d.get("user_code", "")), str(d.get("verification_url", "https://www.google.com/device")))

	var elapsed: = 0.0
	while elapsed < expires and not _login_cancel:
		await get_tree().create_timer(interval).timeout
		elapsed += interval
		if _login_cancel:
			break
		var t: Dictionary = await _http(HTTPClient.METHOD_POST, "https://oauth2.googleapis.com/token", FORM, _form({
			"client_id": Cfg.GOOGLE_CLIENT_ID, 
			"client_secret": Cfg.GOOGLE_CLIENT_SECRET, 
			"device_code": str(d.get("device_code", "")), 
			"grant_type": "urn:ietf:params:oauth:grant-type:device_code", 
		}))
		var td: Dictionary = t["data"] if t["data"] is Dictionary else {}
		if t["ok"]:
			login_status.emit("Signing in ...")
			await _firebase_sign_in(str(td.get("id_token", "")))
			return
		var err: = str(td.get("error", ""))
		if err == "authorization_pending":
			continue
		if err == "slow_down":
			interval += 5.0
			continue
		login_failed.emit("denied" if err == "access_denied" else _error_text(t))
		return
	if _login_cancel:
		login_failed.emit("cancelled")
	else:
		login_failed.emit("the code expired")


func _rand_b64url(n_bytes: int) -> String:
	return _b64url(Crypto.new().generate_random_bytes(n_bytes))


func _b64url(b: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(b).replace("+", "-").replace("/", "_").replace("=", "")


func _parse_query(q: String) -> Dictionary:
	var out: = {}
	for part in q.split("&", false):
		var kv: = part.split("=", true, 1)
		out[kv[0].uri_decode()] = (kv[1] if kv.size() > 1 else "").replace("+", " ").uri_decode()
	return out


func _listen_loopback() -> TCPServer:
	for port in LOOPBACK_PORTS:
		var srv: = TCPServer.new()
		if srv.listen(port, "127.0.0.1") == OK:
			return srv
	return null


func _read_request(conn: StreamPeerTCP) -> String:
	var data: = ""
	var waited: = 0.0
	while waited < 3.0:
		conn.poll()
		var n: = conn.get_available_bytes()
		if n > 0:
			data += conn.get_utf8_string(n)
			if data.contains("\r\n\r\n") or data.contains("\n\n"):
				break
		elif conn.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break
		await get_tree().process_frame
		waited += get_process_delta_time()
	return data


func _reply_page(conn: StreamPeerTCP, ok: bool) -> void :
	var msg: = "Signed in. You can close this tab and go back to the game." if ok else "Sign in failed. Go back to the game and try again."
	var html: = "<!doctype html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>Roof Groove</title></head><body style='font-family:sans-serif;background:#14141f;color:#fff;text-align:center;padding-top:20vh'><h1>Roof Groove</h1><p>%s</p></body></html>" % msg
	var body: = html.to_utf8_buffer()
	var head: = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % body.size()
	conn.put_data(head.to_utf8_buffer())
	conn.put_data(body)
	await get_tree().create_timer(0.15).timeout
	conn.disconnect_from_host()


## Waits for the browser to come back to http://127.0.0.1:PORT/callback. Returns the query
## parameters, or {} when cancelled / timed out.
func _wait_for_redirect(srv: TCPServer, state: String) -> Dictionary:
	var elapsed: = 0.0
	while elapsed < LOOPBACK_TIMEOUT and not _login_cancel:
		if srv.is_connection_available():
			var conn: StreamPeerTCP = srv.take_connection()
			var req: = await _read_request(conn)
			var first: = req.get_slice("\n", 0).strip_edges()
			var path: = first.get_slice(" ", 1)
			if path.begins_with("/callback") and path.contains("?"):
				var params: Dictionary = _parse_query(path.get_slice("?", 1))
				var good: bool = str(params.get("state", "")) == state and (params.has("code") or params.has("error"))
				await _reply_page(conn, good and params.has("code"))
				if good:
					return params
			else:
				await _reply_page(conn, false)
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return {}


func _login_google_loopback() -> void :
	var srv: = _listen_loopback()
	if srv == null:
		login_failed.emit("could not open a local port for the sign in")
		return
	var redirect: = "http://127.0.0.1:%d/callback" % srv.get_local_port()
	var verifier: = _rand_b64url(48)
	var challenge: = _b64url(verifier.sha256_buffer())
	var state: = _rand_b64url(16)
	var url: = "https://accounts.google.com/o/oauth2/v2/auth?" + _form({
		"client_id": Cfg.GOOGLE_DESKTOP_CLIENT_ID, "redirect_uri": redirect, "response_type": "code", 
		"scope": "openid email profile", "code_challenge": challenge, "code_challenge_method": "S256", 
		"state": state, "prompt": "select_account"})
	login_status.emit("Opening Google ...")
	browser_login_started.emit("google")
	OS.shell_open(url)
	var params: Dictionary = await _wait_for_redirect(srv, state)
	srv.stop()
	if params.is_empty():
		login_failed.emit("cancelled" if _login_cancel else "the sign in timed out")
		return
	if params.has("error") or not params.has("code"):
		login_failed.emit("denied")
		return
	login_status.emit("Signing in ...")
	var t: Dictionary
	if _real(Cfg.GOOGLE_DESKTOP_CLIENT_SECRET):
		t = await _http(HTTPClient.METHOD_POST, "https://oauth2.googleapis.com/token", FORM, _form({
			"client_id": Cfg.GOOGLE_DESKTOP_CLIENT_ID, "client_secret": Cfg.GOOGLE_DESKTOP_CLIENT_SECRET, 
			"code": str(params["code"]), "code_verifier": verifier, "redirect_uri": redirect, "grant_type": "authorization_code"}))
	else:
		# The secret stays on the server: it swaps the code for an id_token for us.
		t = await _http(HTTPClient.METHOD_POST, GOOGLE_EXCHANGE_URL, JSON_H, JSON.stringify({
			"code": str(params["code"]), "code_verifier": verifier, "redirect_uri": redirect}))
	if not t["ok"] or not (t["data"] is Dictionary):
		login_failed.emit("Google: " + _error_text(t))
		return
	await _firebase_sign_in(str((t["data"] as Dictionary).get("id_token", "")))


func _login_discord() -> void :
	if not discord_ready():
		login_failed.emit("Discord is not set up yet (see firebase_config.gd)")
		return
	var srv: = _listen_loopback()
	if srv == null:
		login_failed.emit("could not open a local port for the sign in")
		return
	var redirect: = "http://127.0.0.1:%d/callback" % srv.get_local_port()
	var verifier: = _rand_b64url(48)
	var challenge: = _b64url(verifier.sha256_buffer())
	var state: = _rand_b64url(16)
	var url: = "https://discord.com/oauth2/authorize?" + _form({
		"client_id": Cfg.DISCORD_CLIENT_ID, "response_type": "code", "redirect_uri": redirect, 
		"scope": "identify", "code_challenge": challenge, "code_challenge_method": "S256", "state": state, "prompt": "consent"})
	login_status.emit("Opening Discord ...")
	browser_login_started.emit("discord")
	OS.shell_open(url)
	var params: Dictionary = await _wait_for_redirect(srv, state)
	srv.stop()
	if params.is_empty():
		login_failed.emit("cancelled" if _login_cancel else "the sign in timed out")
		return
	if params.has("error") or not params.has("code"):
		login_failed.emit("denied")
		return
	login_status.emit("Signing in ...")
	var t: Dictionary = await _http(HTTPClient.METHOD_POST, "https://discord.com/api/oauth2/token", DISCORD_FORM, _form({
		"client_id": Cfg.DISCORD_CLIENT_ID, "grant_type": "authorization_code", "code": str(params["code"]), 
		"redirect_uri": redirect, "code_verifier": verifier}))
	if not t["ok"] or not (t["data"] is Dictionary) or str((t["data"] as Dictionary).get("access_token", "")) == "":
		var why: = _error_text(t)
		if "invalid_client" in why:
			why += " (Discord Developer Portal > OAuth2: turn on Public Client)"
		elif "redirect" in why.to_lower():
			why += " (add http://127.0.0.1:53682/callback ... 53685 to Discord Redirects)"
		login_failed.emit("Discord: " + why)
		return
	var f: Dictionary = await _http(HTTPClient.METHOD_POST, Cfg.DISCORD_LOGIN_URL, DISCORD_JSON, 
		JSON.stringify({"access_token": str((t["data"] as Dictionary)["access_token"])}))
	if not f["ok"] or not (f["data"] is Dictionary) or str((f["data"] as Dictionary).get("token", "")) == "":
		if int(f["code"]) == 404:
			login_failed.emit("Discord login server not found (404). Deploy vercel_discord_auth again and check DISCORD_LOGIN_URL in firebase_config.gd")
		else:
			login_failed.emit("Discord login server: " + _error_text(f))
		return
	var fd: Dictionary = f["data"]
	await _firebase_custom_sign_in(
		str(fd["token"]),
		"Discord: " + str(fd.get("name", "")),
		str(fd.get("uid", ""))
	)


func _firebase_custom_sign_in(custom_token: String, label: String, discord_uid: String) -> void :
	var r: Dictionary = await _http(HTTPClient.METHOD_POST, 
		"https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=" + Cfg.API_KEY, JSON_H, 
		JSON.stringify({"token": custom_token, "returnSecureToken": true}))
	if not r["ok"] or not (r["data"] is Dictionary):
		var msg: = _error_text(r)
		if "USER_DISABLED" in msg:
			_handle_banned()
			login_failed.emit("YOU HAVE BEEN BANNED")
			return
		login_failed.emit(msg)
		return
	var d: Dictionary = r["data"]
	var new_id_token: String = str(d.get("idToken", ""))
	var new_refresh_token: String = str(d.get("refreshToken", ""))
	# Firebase echoes the uid of the custom token as localId, so a login server that does not send "uid" still works.
	var final_uid: = discord_uid if discord_uid != "" else str(d.get("localId", ""))
	if final_uid == "" or new_id_token == "" or new_refresh_token == "":
		var missing: PackedStringArray = []
		if final_uid == "":
			missing.append("uid")
		if new_id_token == "":
			missing.append("idToken")
		if new_refresh_token == "":
			missing.append("refreshToken")
		login_failed.emit("Discord or Firebase returned an incomplete sign-in session (missing: %s)" % ", ".join(missing))
		return
	uid = final_uid
	email = label
	id_token = new_id_token
	refresh_token = new_refresh_token
	token_expiry = Time.get_unix_time_from_system() + float(d.get("expiresIn", 3600))
	banned = false
	_save()
	await _merge_with_cloud()
	if not is_signed_in():
		login_failed.emit("Firebase session was lost while syncing the Discord account")
		return
	login_succeeded.emit()


func _firebase_sign_in(google_id_token: String) -> void :
	if google_id_token == "":
		login_failed.emit("Google did not return an id token")
		return
	var body: = JSON.stringify({
		"postBody": "id_token=%s&providerId=google.com" % google_id_token, 
		"requestUri": "http://localhost", 
		"returnIdpCredential": true, 
		"returnSecureToken": true, 
	})
	var r: Dictionary = await _http(HTTPClient.METHOD_POST, 
		"https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=" + Cfg.API_KEY, JSON_H, body)
	if not r["ok"] or not (r["data"] is Dictionary):
		var msg: = _error_text(r)
		if "USER_DISABLED" in msg:
			_handle_banned()
			login_failed.emit("YOU HAVE BEEN BANNED")
			return
		if "INVALID_IDP_RESPONSE" in msg or "audience" in msg.to_lower():
			msg += " (add the TV client ID to Google's allowed client IDs in Firebase Auth)"
		login_failed.emit(msg)
		return
	var d: Dictionary = r["data"]
	uid = str(d.get("localId", ""))
	email = str(d.get("email", d.get("displayName", "")))
	id_token = str(d.get("idToken", ""))
	refresh_token = str(d.get("refreshToken", ""))
	token_expiry = Time.get_unix_time_from_system() + float(d.get("expiresIn", 3600))
	banned = false
	_save()
	await _merge_with_cloud()
	login_succeeded.emit()



func _merge_with_cloud() -> void :
	var cloud_pid: = ""
	var r: Dictionary = await _authed(HTTPClient.METHOD_GET, _doc_url("players/" + uid))
	if r["ok"] and r["data"] is Dictionary:
		var f: Dictionary = r["data"].get("fields", {})
		cloud_pid = str(_fv(f, "player_id", ""))

		if bool(_fv(f, "username_locked", false)):
			var cloud_name: = str(_fv(f, "name", ""))
			if cloud_name != "" and cloud_name != Network.player_name:
				Network.username_locked = false
				Network.adopt_locked_username(cloud_name)
		var cloud_best: = int(_fv(f, "best_checkpoint", 0))
		if cloud_best > Network.best_checkpoint:
			Network.checkpoint = int(_fv(f, "checkpoint", 0))
			Network.checkpoint_seed = int(_fv(f, "seed", 0))
		Network.best_checkpoint = maxi(Network.best_checkpoint, cloud_best)
		Network.total_deaths = maxi(Network.total_deaths, int(_fv(f, "deaths", 0)))
		Network.total_time = maxf(Network.total_time, float(_fv(f, "play_time", 0.0)))
		Network.save_cfg()
		_merge_economy(f)
		_merge_story(f)
		FriendsSystem.apply_cloud_profile(f)
	elif int(r["code"]) != 404:
		return
	else:
		FriendsSystem.member_since = int(Time.get_unix_time_from_system())
	await FriendsSystem.register_id(cloud_pid)
	await push_now()
	await push_presence()






func _merge_story(f: Dictionary) -> void :
	if not (f.has("story_cp") or f.has("story_seen")):
		return
	StoryState.apply_cloud(int(_fv(f, "story_cp", 0)), _str_array(f, "story_seen"), 
		bool(_fv(f, "story_finished", false)), bool(_fv(f, "story_intro_seen", StoryState.intro_seen)))



func pull_story() -> void :
	if not is_signed_in():
		return
	if _sig() != _last_sig:
		push_now()
		return
	var r: Dictionary = await _authed(HTTPClient.METHOD_GET, _doc_url("players/" + uid))
	if r["ok"] and r["data"] is Dictionary:
		_merge_story(r["data"].get("fields", {}))




func fetch_cheat_codes() -> Dictionary:
	var url: = _doc_url("app/cheats")
	var r: Dictionary
	if is_signed_in():
		r = await _authed(HTTPClient.METHOD_GET, url)
	else:
		r = await _http(HTTPClient.METHOD_GET, url, [])
	if not r["ok"] or not (r["data"] is Dictionary):
		return {"ok": false, "codes": {}}
	var f: Dictionary = r["data"].get("fields", {})
	var codes: = {}
	var cheats_enabled: bool = bool(_fv(f, "enabled", true))
	if cheats_enabled:
		for k in f:
			if str(k) == "enabled":
				continue
			var v: Variant = _fv(f, str(k), null)
			if v is String and str(v).strip_edges() != "":
				codes[str(k).to_upper()] = str(v).strip_edges().to_lower()
	return {"ok": true, "codes": codes, "enabled": cheats_enabled}


func _str_array(f: Dictionary, key: String) -> Array:
	var out: Array = []
	var sv: Variant = f.get(key, {})
	if sv is Dictionary:
		var av: Variant = sv.get("arrayValue", {})
		if av is Dictionary:
			for item in av.get("values", []):
				if item is Dictionary and item.has("stringValue"):
					out.append(str(item["stringValue"]))
	return out


func _merge_economy(f: Dictionary) -> void :
	Economy.merge_cloud(
		int(_fv(f, "tokens_earned", 0)), 
		_str_array(f, "skins_owned"), 
		str(_fv(f, "skin_equipped", "")), 
		int(_fv(f, "tokens_bonus", 0)), 
		_str_array(f, "codes_used"), 
		int(_fv(f, "gems", 0)), 
		int(_fv(f, "arena_gems", 0)))



func sync_economy() -> void :
	if not is_signed_in():
		return
	var r: Dictionary = await _authed(HTTPClient.METHOD_GET, _doc_url("players/" + uid))
	if r["ok"] and r["data"] is Dictionary:
		_merge_economy(r["data"].get("fields", {}))




func redeem_remote_code(raw: String) -> Dictionary:
	var code: = raw.strip_edges().to_upper()
	if code.length() < 3 or code.length() > 40:
		return {"status": "invalid"}
	for ch in code:
		if not "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_".contains(ch):
			return {"status": "invalid"}
	if not is_signed_in():
		return {"status": "signin"}
	if Economy.used_codes.has(code):
		return {"status": "used"}

	var rs: Dictionary = await _authed(HTTPClient.METHOD_GET, _doc_url("skins"))
	var denied: = false
	if rs["ok"] and rs["data"] is Dictionary:
		for d in rs["data"].get("documents", []):
			if not (d is Dictionary):
				continue
			var sf: Dictionary = d.get("fields", {})
			var sc: = str(_fv(sf, "code", "no")).strip_edges().to_upper()
			if sc == "" or sc == "NO" or sc != code:
				continue
			var skin_id: = str(d.get("name", "")).get_file()
			return {"status": Economy.apply_reward(code, skin_id, int(_fv(sf, "tokens", 0)))}
	elif int(rs["code"]) == 403:
		denied = true
	elif int(rs["code"]) != 404:
		return {"status": "offline"}

	var r: Dictionary = await _authed(HTTPClient.METHOD_GET, _doc_url("codes/" + code))
	if not r["ok"]:
		match int(r["code"]):
			404:
				return {"status": "denied" if denied else "invalid"}
			403:
				return {"status": "denied"}
			_:
				return {"status": "offline"}
	var f: Dictionary = r["data"].get("fields", {}) if r["data"] is Dictionary else {}
	if not bool(_fv(f, "active", true)):
		return {"status": "inactive"}
	var res: String = Economy.apply_reward(code, str(_fv(f, "skin", "")), int(_fv(f, "tokens", 0)))
	return {"status": res}


func _resume() -> void :
	if await _refresh():
		await _merge_with_cloud()





func _ensure_token() -> bool:
	if refresh_token == "":
		return false
	if id_token != "" and Time.get_unix_time_from_system() < token_expiry - 60.0:
		return true
	return await _refresh()


func _refresh() -> bool:
	if refresh_token == "":
		return false
	var r: Dictionary = await _http(HTTPClient.METHOD_POST, 
		"https://securetoken.googleapis.com/v1/token?key=" + Cfg.API_KEY, FORM, 
		_form({"grant_type": "refresh_token", "refresh_token": refresh_token}))
	if not r["ok"] or not (r["data"] is Dictionary):
		if "USER_DISABLED" in _error_text(r):
			_handle_banned()
		elif int(r["code"]) == 400:
			sign_out()
		return false
	var d: Dictionary = r["data"]
	id_token = str(d.get("id_token", ""))
	refresh_token = str(d.get("refresh_token", refresh_token))
	uid = str(d.get("user_id", uid))
	token_expiry = Time.get_unix_time_from_system() + float(d.get("expires_in", 3600))
	_save()
	return id_token != ""



func _verify_account() -> void :
	if _verifying or not is_signed_in():
		return
	_verifying = true
	if await _ensure_token():
		var r: Dictionary = await _http(HTTPClient.METHOD_POST, 
			"https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=" + Cfg.API_KEY, JSON_H, 
			JSON.stringify({"idToken": id_token}))
		if not r["ok"] and "USER_DISABLED" in _error_text(r):
			_handle_banned()
	_verifying = false



func _handle_banned() -> void :
	var first: = not banned
	banned = true
	_save()
	if first:
		banned_detected.emit()
	_show_ban_screen()



func recheck_ban() -> bool:
	if not banned:
		return true
	if _rechecking:
		return false
	_rechecking = true
	var lifted: = false
	if refresh_token == "":
		lifted = true
	elif await _refresh():
		lifted = true
	_rechecking = false
	if lifted:
		_lift_ban()
	return lifted


func _lift_ban() -> void :
	banned = false
	_save()
	if _ban_dialog != null and is_instance_valid(_ban_dialog):
		_ban_dialog.queue_free()
	_ban_dialog = null
	_ban_status = null
	if _paused_by_ban:
		get_tree().paused = false
		_paused_by_ban = false
	if is_signed_in():
		_merge_with_cloud()


func _show_ban_screen() -> void :
	if _ban_dialog != null and is_instance_valid(_ban_dialog):
		return
	var layer: = CanvasLayer.new()
	layer.layer = 200
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_ban_dialog = layer

	var dim: = ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.02, 0.97)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: = CenterContainer.new()
	layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box: = VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 0)
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	box.add_child(UI.label("YOU HAVE BEEN BANNED", 32, Color(1, 0.4, 0.4), 520.0))
	box.add_child(UI.label("Your account was disabled by the game admin.\nYou cannot play until it is enabled again.", 16, Color.WHITE, 520.0))
	_ban_status = UI.label("", 14, Color(1, 0.85, 0.4), 520.0)
	box.add_child(_ban_status)
	var retry_btn: = UI.button("TRY AGAIN", 20, 56.0)
	retry_btn.pressed.connect(_on_ban_retry)
	box.add_child(retry_btn)
	var quit_btn: = UI.button("QUIT", 18, 48.0)
	quit_btn.pressed.connect( func(): get_tree().quit())
	box.add_child(quit_btn)


	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_ban = true


func _on_ban_retry() -> void :
	if _ban_status != null:
		_ban_status.text = tr("Checking...")
	var ok: bool = await recheck_ban()
	if not ok and _ban_status != null and is_instance_valid(_ban_status):
		_ban_status.text = tr("You are still banned (or there is no internet connection)")


func _authed(method: int, url: String, body: String = "") -> Dictionary:
	if not await _ensure_token():
		return {"ok": false, "code": 0, "data": {}}
	return await _http(method, url, ["Authorization: Bearer " + id_token, "Content-Type: application/json"], body)


func _http(method: int, url: String, headers: Array, body: String = "") -> Dictionary:
	var req: = HTTPRequest.new()
	# Firestore can take longer on a cold start or on mobile connections.
	req.timeout = 30.0
	add_child(req)
	var err: = req.request(url, PackedStringArray(headers), method, body)
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "result": -err, "data": {}}
	var res: Array = await req.request_completed
	req.queue_free()
	var code: = int(res[1])
	var text: = (res[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = null
	var trimmed: = text.strip_edges()
	# Only parse real JSON (a web error page like Vercel's 404 is plain text/HTML).
	if trimmed.begins_with("{") or trimmed.begins_with("["):
		parsed = JSON.parse_string(trimmed)
	return {
		"ok": int(res[0]) == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300, 
		"code": code, 
		"result": int(res[0]), 
		"data": parsed if parsed != null else {}, 
	}






func doc_get(path: String) -> Dictionary:
	return await _authed(HTTPClient.METHOD_GET, _doc_url(path))



func doc_set(path: String, fields: Dictionary) -> Dictionary:
	return await _authed(HTTPClient.METHOD_PATCH, _doc_url(path), JSON.stringify({"fields": fields}))


func doc_delete(path: String) -> Dictionary:
	return await _authed(HTTPClient.METHOD_DELETE, _doc_url(path))



func doc_create(path: String, fields: Dictionary) -> Dictionary:
	return await _authed(HTTPClient.METHOD_PATCH, _doc_url(path) + "?currentDocument.exists=false", JSON.stringify({"fields": fields}))


func register_active_room(room_id: String, invite_code: String, host_ip: String, host_port: int, host_lan_ip: String) -> Dictionary:
	if not is_signed_in():
		return {"ok": false, "message": "Sign in before hosting an online room"}
	var fields: = {
		"room_id": {"stringValue": room_id},
		"invite_code": {"stringValue": invite_code},
		"host_uid": {"stringValue": uid},
		"host_ip": {"stringValue": host_ip},
		"host_lan_ip": {"stringValue": host_lan_ip},
		"host_port": {"integerValue": str(host_port)},
		"active": {"booleanValue": true},
		"last_seen": {"integerValue": str(int(Time.get_unix_time_from_system() * 1000.0))},
	}
	var r: Dictionary = await doc_create("active_rooms/" + room_id, fields)
	if not r["ok"]:
		return {"ok": false, "message": "active_rooms create denied (HTTP %d): %s. Publish the room Firestore rules in this Firebase project." % [int(r.get("code", 0)), _error_text(r)]}
	var alias_fields: = {
		"room_id": {"stringValue": room_id},
		"host_uid": {"stringValue": uid},
		"active": {"booleanValue": true},
	}
	var alias_result: Dictionary = await doc_create("room_codes/" + invite_code, alias_fields)
	if not alias_result["ok"]:
		await update_active_room(room_id, {"active": {"booleanValue": false}})
		return {"ok": false, "message": "room_codes create denied (HTTP %d): %s. Check the room_codes Firestore rule." % [int(alias_result.get("code", 0)), _error_text(alias_result)]}
	return {"ok": true, "message": ""}


func find_active_room(invite_code: String) -> Dictionary:
	var api_key: String = "?key=" + Cfg.API_KEY
	var alias_result: Dictionary = await _http(HTTPClient.METHOD_GET,
		_doc_url("room_codes/" + invite_code) + api_key, [])
	if not alias_result["ok"] or not (alias_result["data"] is Dictionary):
		if int(alias_result["code"]) == 403 or int(alias_result["code"]) == 404:
			return {"ok": false, "message": "No active room has this invite code"}
		return {"ok": false, "message": _error_text(alias_result)}
	var alias_fields: Dictionary = alias_result["data"].get("fields", {})
	if not bool(_fv(alias_fields, "active", false)):
		return {"ok": false, "message": "No active room has this invite code"}
	var room_id: String = str(_fv(alias_fields, "room_id", ""))
	if room_id == "":
		return {"ok": false, "message": "The room record is incomplete"}
	var room_result: Dictionary = await _http(HTTPClient.METHOD_GET,
		_doc_url("active_rooms/" + room_id) + api_key, [])
	if not room_result["ok"] or not (room_result["data"] is Dictionary):
		return {"ok": false, "message": "No active room has this invite code"}
	var fields: Dictionary = room_result["data"].get("fields", {})
	var last_seen: int = int(_fv(fields, "last_seen", 0))
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	if not bool(_fv(fields, "active", false)) or now_ms - last_seen > 90000:
		return {"ok": false, "message": "No active room has this invite code"}
	return {"ok": true, "room": {
		"room_id": room_id,
		"invite_code": invite_code,
		"host_ip": str(_fv(fields, "host_ip", "")),
		"host_lan_ip": str(_fv(fields, "host_lan_ip", "")),
		"host_port": int(_fv(fields, "host_port", 0)),
	}}


func get_active_room(room_id: String) -> Dictionary:
	return await _authed(HTTPClient.METHOD_GET, _doc_url("active_rooms/" + room_id))


func update_active_room(room_id: String, fields: Dictionary) -> Dictionary:
	return await _patch_firestore_doc("active_rooms/" + room_id, fields)


func _patch_firestore_doc(path: String, fields: Dictionary) -> Dictionary:
	var masks: = PackedStringArray()
	for key in fields:
		masks.append("updateMask.fieldPaths=" + str(key).uri_encode())
	var url: String = _doc_url(path) + "?" + "&".join(masks)
	return await _authed(HTTPClient.METHOD_PATCH, url, JSON.stringify({"fields": fields}))


func replace_room_invite(room_id: String, old_code: String, new_code: String) -> Dictionary:
	if old_code == new_code:
		return {"ok": true, "message": ""}
	var alias_fields: = {
		"room_id": {"stringValue": room_id},
		"host_uid": {"stringValue": uid},
		"active": {"booleanValue": true},
	}
	var created: Dictionary = await doc_create("room_codes/" + new_code, alias_fields)
	if not created["ok"]:
		return {"ok": false, "message": _error_text(created)}
	var deleted: Dictionary = await doc_delete("room_codes/" + old_code)
	if not deleted["ok"]:
		await doc_delete("room_codes/" + new_code)
		return {"ok": false, "message": _error_text(deleted)}
	return {"ok": true, "message": ""}


func close_active_room(room_id: String, invite_code: String) -> void:
	await update_active_room(room_id, {
		"active": {"booleanValue": false},
		"last_seen": {"integerValue": str(int(Time.get_unix_time_from_system() * 1000.0))},
	})
	if invite_code != "":
		await doc_delete("room_codes/" + invite_code)


func _doc_url(path: String) -> String:
	return "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/%s" % [Cfg.PROJECT_ID, path]


func _form(d: Dictionary) -> String:
	var parts: = PackedStringArray()
	for k in d:
		parts.append("%s=%s" % [str(k).uri_encode(), str(d[k]).uri_encode()])
	return "&".join(parts)



func _fv(fields: Dictionary, key: String, def: Variant) -> Variant:
	if not fields.has(key) or not (fields[key] is Dictionary):
		return def
	var v: Dictionary = fields[key]
	if v.has("integerValue"):
		return int(v["integerValue"])
	if v.has("doubleValue"):
		return float(v["doubleValue"])
	if v.has("stringValue"):
		return str(v["stringValue"])
	if v.has("booleanValue"):
		return bool(v["booleanValue"])
	return def


func _error_text(r: Dictionary) -> String:
	var d: Variant = r["data"]
	if d is Dictionary and d.has("error"):
		var e: Variant = d["error"]
		if e is Dictionary:
			return str(e.get("message", "error"))
		var desc: = str(d.get("error_description", ""))
		return str(e) if desc == "" else "%s (%s)" % [str(e), desc]
	if int(r["code"]) == 0:
		match int(r.get("result", 0)):
			HTTPRequest.RESULT_CANT_RESOLVE:
				return "cannot resolve the server address (DNS / no internet)"
			HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR:
				return "cannot reach the server (no internet or blocked)"
			HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
				return "secure connection failed (TLS) - check the device date and time"
			HTTPRequest.RESULT_TIMEOUT:
				return "the request timed out"
		return "no internet connection (error %d)" % int(r.get("result", 0))
	return "HTTP %d" % int(r["code"])



func _sig() -> String:
	return "%s|%d|%d|%d|%d|%s|%s" % [Network.player_name, Network.best_checkpoint, Network.checkpoint, Network.total_deaths, int(Network.total_time / 60.0), FriendsSystem.player_id, Economy.sig() + "|" + StoryState.sig()]


func _save() -> void :
	var cfg: = ConfigFile.new()
	cfg.set_value("cloud", "refresh_token", refresh_token)
	cfg.set_value("cloud", "uid", uid)
	cfg.set_value("cloud", "email", email)
	cfg.set_value("cloud", "banned", banned)
	cfg.save(SAVE_FILE)


func _load() -> void :
	var cfg: = ConfigFile.new()
	if cfg.load(SAVE_FILE) != OK:
		return
	refresh_token = str(cfg.get_value("cloud", "refresh_token", ""))
	uid = str(cfg.get_value("cloud", "uid", ""))
	email = str(cfg.get_value("cloud", "email", ""))
	banned = bool(cfg.get_value("cloud", "banned", false))
