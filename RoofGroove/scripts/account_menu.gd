extends Control


var _font: Font = preload("res://fonts/PixelOperator8.ttf")
var _status: Label
var _stats: Label
var _code: Label
var _board_label: Label
var _main: VBoxContainer
var _login: VBoxContainer
var _board: VBoxContainer
var _sign_in_btn: Button
var _discord_btn: Button
var _wait: VBoxContainer
var _wait_label: Label
var _code_btn: Button
var _sign_out_btn: Button
var _rank_btn: Button
var _url: = ""


func _ready() -> void :
	var bg: = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 88.0

	var root: = VBoxContainer.new()
	root.custom_minimum_size = Vector2(480, 0)
	root.add_theme_constant_override("separation", 10)
	center.add_child(root)

	root.add_child(_label("ACCOUNT", 28))
	_status = _label("", 12)
	_status.modulate = Color(1, 0.85, 0.4)
	root.add_child(_status)

	_build_main(root)
	_build_login(root)
	_build_wait(root)
	_build_board(root)

	var c: Node = Network.cloud
	if c == null:
		_status.text = "Cloud is not available"
	else:
		c.device_code_ready.connect(_on_code)
		c.browser_login_started.connect(_on_browser_started)
		c.login_status.connect(_on_status)
		c.login_succeeded.connect(_on_login_ok)
		c.login_failed.connect(_on_login_failed)
		c.leaderboard_ready.connect(_on_board)
		if not c.is_configured():
			_status.text = "Account service is not set up (firebase_config.gd)"
	_refresh()
	_show(_main)

	if Network.has_meta("open_ranking"):
		Network.remove_meta("open_ranking")
		if _rank_btn != null and not _rank_btn.disabled:
			_on_ranking()


func _exit_tree() -> void :
	var c: Node = Network.cloud
	if c == null:
		return
	c.device_code_ready.disconnect(_on_code)
	c.browser_login_started.disconnect(_on_browser_started)
	c.login_status.disconnect(_on_status)
	c.login_succeeded.disconnect(_on_login_ok)
	c.login_failed.disconnect(_on_login_failed)
	c.leaderboard_ready.disconnect(_on_board)



func _build_main(root: Container) -> void :
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 10)
	root.add_child(_main)
	_stats = _label("", 14)
	_main.add_child(_stats)
	_sign_in_btn = _btn("SIGN IN WITH GOOGLE", _on_sign_in)
	_main.add_child(_sign_in_btn)
	_discord_btn = _btn("SIGN IN WITH DISCORD", _on_discord_sign_in)
	_main.add_child(_discord_btn)
	_rank_btn = _btn("CHECKPOINT RANKING", _on_ranking)
	_main.add_child(_rank_btn)
	_sign_out_btn = _btn("SIGN OUT", _on_sign_out)
	_main.add_child(_sign_out_btn)
	_main.add_child(_btn("BACK", func(): get_tree().change_scene_to_file("res://sence/account_hub.tscn")))


func _build_login(root: Container) -> void :
	_login = VBoxContainer.new()
	_login.add_theme_constant_override("separation", 10)
	root.add_child(_login)
	_login.add_child(_label("OPEN THE PAGE BELOW AND ENTER THIS CODE:", 12))
	_code = _label("", 32)
	_code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_login.add_child(_code)
	_login.add_child(_btn("OPEN google.com/device", func(): OS.shell_open(_url)))
	_login.add_child(_btn("COPY CODE", func(): DisplayServer.clipboard_set(_code.text)))
	_login.add_child(_btn("CANCEL", _on_cancel))


func _build_wait(root: Container) -> void :
	_wait = VBoxContainer.new()
	_wait.add_theme_constant_override("separation", 10)
	root.add_child(_wait)
	_wait_label = _label("FINISH SIGNING IN IN YOUR BROWSER, THEN COME BACK TO THE GAME.", 14)
	_wait.add_child(_wait_label)
	_code_btn = _btn("USE A CODE INSTEAD", _on_use_code)
	_wait.add_child(_code_btn)
	_wait.add_child(_btn("CANCEL", _on_cancel))


func _build_board(root: Container) -> void :
	_board = VBoxContainer.new()
	_board.add_theme_constant_override("separation", 10)
	root.add_child(_board)
	_board.add_child(_label("TOP PLAYERS", 20))
	_board_label = _label("", 14)
	_board.add_child(_board_label)
	_board.add_child(_btn("BACK", func(): _show(_main)))



func _on_sign_in() -> void :
	var c: Node = Network.cloud
	if c == null or not c.google_configured():
		_status.text = "Google sign-in is not configured in scripts/firebase_config.gd"
		return
	_status.text = "Connecting ..."
	c.start_google_login()


func _on_discord_sign_in() -> void :
	var c: Node = Network.cloud
	if c == null:
		return
	if not c.discord_ready():
		_status.text = "Discord sign in is not set up yet"
		return
	_status.text = "Connecting ..."
	c.start_discord_login()


func _on_use_code() -> void :
	var c: Node = Network.cloud
	if c == null:
		return
	c.cancel_login()
	await get_tree().create_timer(0.3).timeout
	_status.text = "Connecting ..."
	c.start_google_login(true)


func _on_browser_started(provider: String) -> void :
	_code_btn.visible = provider == "google"
	_wait_label.text = tr("FINISH SIGNING IN IN YOUR BROWSER, THEN COME BACK TO THE GAME.")
	_show(_wait)


func _on_sign_out() -> void :
	Network.cloud.sign_out()
	_status.text = "Signed out"
	_refresh()


func _on_cancel() -> void :
	Network.cloud.cancel_login()
	_status.text = ""
	_show(_main)


func _on_ranking() -> void :
	_board_label.text = "Loading ..."
	_show(_board)
	Network.cloud.fetch_leaderboard()



func _on_status(t: String) -> void :
	_status.text = tr(t)


func _on_code(code: String, url: String) -> void :
	_url = url
	_code.text = code
	DisplayServer.clipboard_set(code)
	_status.text = "Code copied. Approve the sign in on the Google page."
	_show(_login)
	OS.shell_open(url)


func _on_login_ok() -> void :
	_status.text = "Signed in"
	_refresh()
	_show(_main)


func _on_login_failed(reason: String) -> void :
	if reason == "cancelled":
		_status.text = ""
		_refresh()
		_show(_main)
		return
	_status.text = tr("Sign in failed: ") + tr(reason)
	_refresh()
	_show(_main)


func _on_board(ok: bool, entries: Array) -> void :
	if not ok:
		_board_label.text = "Could not load the ranking"
		return
	if entries.is_empty():
		_board_label.text = "No players yet"
		return
	var lines: = PackedStringArray()
	for i in entries.size():
		var e: Dictionary = entries[i]
		var rk: Dictionary = Network.rank_for(int(e["best"]))
		lines.append("%d. %s   CP %d   %s" % [i + 1, e["name"], int(e["best"]), tr(str(rk["name"]))])
	_board_label.text = "\n".join(lines)



func _refresh() -> void :
	var c: Node = Network.cloud
	var signed: bool = c != null and c.is_signed_in()
	var rk: Dictionary = Network.rank_for(Network.best_checkpoint)
	var who: = (tr("Signed in: ") + str(c.email)) if signed else (tr("YOU HAVE BEEN BANNED") if (c != null and c.banned) else tr("Not signed in"))
	_stats.text = tr("%s\n\nRANK  %s\nCHECKPOINT  %d  (BEST %d)\nTIME  %s\nDEATHS  %d") % [
		who, tr(str(rk["name"])).to_upper(), Network.checkpoint, Network.best_checkpoint, 
		Network.format_time(Network.total_time), Network.total_deaths]
	_stats.add_theme_color_override("font_color", rk["color"])
	_sign_in_btn.visible = not signed
	_discord_btn.visible = not signed
	_sign_out_btn.visible = signed
	_rank_btn.visible = signed


func _show(panel: Control) -> void :
	for p in [_main, _login, _wait, _board]:
		p.visible = (p == panel)


func _label(t: String, size: int) -> Label:
	var l: = Label.new()
	l.text = tr(t)
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _btn(t: String, cb: Callable) -> Button:
	var b: = Button.new()
	b.text = tr(t)
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(cb)
	return b
