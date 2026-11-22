extends Control


const RoomStart: = preload("res://scripts/room_start.gd")
const NOTE_TEXT: = "No server needed: the player who creates the room is the host. Share the room code with your friends."

var _font: Font = preload("res://fonts/PixelOperator8.ttf")
var _note: Label
var _main: VBoxContainer
var _lobby: VBoxContainer
var _board: VBoxContainer
var _status: Label
var _name_edit: LineEdit
var _ip_edit: LineEdit
var _code_edit: LineEdit
var _lobby_title: Label
var _lobby_players: Label
var _start_btn: Button
var _lobby_wait: Label
var _board_label: Label


func _ready() -> void :
	var bg: = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 88.0

	var scroll: = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center.add_child(scroll)

	var root: = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	scroll.add_child(root)

	root.add_child(_label("ONLINE / LAN", 28))
	_status = _label("", 14)
	_status.modulate = Color(1, 0.85, 0.4)
	root.add_child(_status)


	_note = _label(NOTE_TEXT, 11)
	_note.modulate = Color(1, 0.7, 0.3)
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_note)

	_build_main(root)
	_build_lobby(root)
	_build_board(root)
	_show(_main)

	Network.room_joined.connect(_on_room_joined)
	Network.room_failed.connect(_on_room_failed)
	Network.connection_failed.connect(_on_conn_failed)
	Network.p2p_status.connect( func(t): _set_status(tr(t)))
	Network.disconnected.connect(_on_disconnected)
	Network.peer_joined.connect( func(_id, _n): _refresh_lobby())
	Network.peer_left.connect( func(_id): _refresh_lobby())
	Network.game_started.connect(_on_game_started)


	if FriendsSystem.pending_join_code != "":
		var invite_code: String = FriendsSystem.pending_join_code
		FriendsSystem.pending_join_code = ""
		if Network.join_online_room(invite_code) == OK:
			_set_status("Joining your friend's room ...")
		else:
			_set_status("Invalid room code")
	Network.leaderboard_received.connect(_on_leaderboard)



func _build_main(root: Container) -> void :
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 8)
	root.add_child(_main)

	_main.add_child(_label("YOUR NAME", 14))
	_name_edit = _edit("Player", Network.player_name)
	_name_edit.max_length = Network.NAME_MAX
	_name_edit.select_all_on_focus = true
	_name_edit.editable = not Network.username_locked
	_main.add_child(_name_edit)

	_main.add_child(_label("PLAY ON WIFI (LAN)", 14))
	_main.add_child(_btn("HOST LAN GAME", _on_host_lan))
	_ip_edit = _edit("Host IP  e.g. 192.168.1.5", Network.last_ip)
	_main.add_child(_ip_edit)
	_main.add_child(_btn("JOIN LAN GAME", _on_join_lan))

	_main.add_child(_label("PLAY OVER INTERNET", 14))
	_main.add_child(_btn("CREATE ROOM", _on_create_room))
	_code_edit = _edit("ROOM CODE", "")
	_code_edit.max_length = 24
	_main.add_child(_code_edit)
	_main.add_child(_btn("JOIN ROOM", _on_join_room))

	_main.add_child(_btn("LEADERBOARD", _on_leaderboard_pressed))
	_main.add_child(_btn("BACK", func(): get_tree().change_scene_to_file("res://sence/play_menu.tscn")))


func _build_lobby(root: Container) -> void :
	_lobby = VBoxContainer.new()
	_lobby.add_theme_constant_override("separation", 10)
	root.add_child(_lobby)
	_lobby_title = _label("", 20)
	_lobby.add_child(_lobby_title)
	_lobby_players = _label("", 16)
	_lobby.add_child(_lobby_players)
	_lobby_wait = _label("Waiting for the host to start...", 14)
	_lobby.add_child(_lobby_wait)
	_start_btn = _btn("START GAME", func(): Network.request_start())
	_lobby.add_child(_start_btn)
	_lobby.add_child(_btn("LEAVE", _on_leave_pressed))


func _build_board(root: Container) -> void :
	_board = VBoxContainer.new()
	_board.add_theme_constant_override("separation", 10)
	root.add_child(_board)
	_board.add_child(_label("BEST TIMES", 20))
	_board_label = _label("", 14)
	_board.add_child(_board_label)
	_board.add_child(_btn("BACK", _on_board_back))



func _apply_name() -> void :
	Network.set_player_name(_name_edit.text)


func _on_host_lan() -> void :
	_apply_name()
	if Network.host_lan() != OK:
		_set_status(tr("Could not start host (port %d busy?)") % Network.LAN_PORT)


func _on_join_lan() -> void :
	_apply_name()
	var ip: = _ip_edit.text.strip_edges()
	if ip == "":
		_set_status("Enter the host IP first")
		return
	Network.last_ip = ip
	Network.save_cfg()
	if Network.join_lan(ip) == OK:
		_set_status(tr("Connecting to %s ...") % ip)
	else:
		_set_status("Bad address")


func _on_create_room() -> void :
	_apply_name()
	var err: = Network.create_online_room()
	if err == OK:
		_set_status("Creating room ...")
	elif err == ERR_UNAUTHORIZED:
		_set_status("Sign in to your account before hosting an online room")
	else:
		_set_status(tr("Could not start host (port %d busy?)") % Network.P2P_PORT)


func _on_join_room() -> void :
	_apply_name()
	var code: = Network.normalize_code(_code_edit.text)
	if not Network._valid_invite_code(code):
		_set_status(tr("Room code must be 1 to 24 letters or numbers"))
		return
	var err: = Network.join_online_room(code)
	if err == OK:
		_set_status("Connecting to the host ...")
	elif err == ERR_INVALID_PARAMETER:
		_set_status("Invalid room code")
	else:
		_set_status("Could not connect to the host")


func _on_leaderboard_pressed() -> void :
	_show(_board)
	_board_label.text = "Loading..."
	Network.request_leaderboard(Network.LEVEL_ID)


func _on_board_back() -> void :
	Network.leave()
	_show(_main)


func _on_leave_pressed() -> void :
	Network.leave()
	_show(_main)



func _on_room_joined(_code: String) -> void :
	_set_status("")
	get_tree().change_scene_to_file("res://sence/lobby_preview.tscn")


func _on_room_failed(reason: String) -> void :
	Network.leave()
	_set_status(tr(reason))
	_show(_main)


func _on_conn_failed() -> void :
	_set_status("Could not connect to the host (check the code, or ask the host to open the port)")
	if _board.visible:
		_board_label.text = "Could not load"
	else:
		_show(_main)


func _on_disconnected() -> void :
	_set_status("Disconnected from host")
	_show(_main)


func _on_game_started(_path: String) -> void :

	RoomStart.go(Network)


func _on_leaderboard(_level: String, entries: Array) -> void :
	if not _board.visible:
		return
	if entries.is_empty():
		_board_label.text = "No times yet"
		return
	var lines: = PackedStringArray()
	for i in entries.size():
		var e: Dictionary = entries[i]
		lines.append("%2d. %-12s %s  (%d %s)" % [i + 1, e["name"], Network.format_time(float(e["time"])), int(e["deaths"]), tr("deaths")])
	_board_label.text = "\n".join(lines)


func _refresh_lobby() -> void :
	if not Network.in_room():
		return
	if Network.mode == Network.Mode.LAN:
		var ips: = Network.get_lan_ips()
		_lobby_title.text = tr("LAN GAME") + "\n" + (", ".join(ips) if ips.size() > 0 else tr("(no LAN IP found)"))
	else:
		_lobby_title.text = tr("ROOM") + "  " + Network.display_code(Network.invite_code)
		if Network.is_p2p_host and Network.p2p_note != "":
			_lobby_title.text += "\n" + tr(_p2p_hint(Network.p2p_note))
	var lines: = PackedStringArray()
	for id in Network.members:
		var host_tag: = ("  " + tr("(HOST)")) if id == Network.room_host_id else ""
		lines.append("- %s%s" % [Network.members[id], host_tag])
	_lobby_players.text = "\n".join(lines)
	_start_btn.visible = Network.is_room_host()
	_lobby_wait.visible = not Network.is_room_host()



func _show(panel: Control) -> void :
	for p in [_main, _lobby, _board]:
		p.visible = (p == panel)
	if _note != null:
		_note.visible = (panel == _main or panel == _lobby)


func _set_status(t: String) -> void :
	_status.text = t


func _label(t: String, size: int) -> Label:
	var l: = Label.new()
	l.text = t
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _btn(t: String, cb: Callable) -> Button:
	var b: = Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(cb)
	return b


func _edit(placeholder: String, value: String) -> LineEdit:
	var e: = LineEdit.new()
	e.placeholder_text = placeholder
	e.text = value
	e.custom_minimum_size = Vector2(0, 40)
	e.add_theme_font_override("font", _font)
	e.add_theme_font_size_override("font_size", 14)
	return e


func _p2p_hint(note: String) -> String:
	match note:
		"NO_UPNP":
			return "Your router did not open the port automatically. Forward UDP port 24680 to this device so friends outside your WiFi can join."
		"CGNAT":
			return "Your internet provider shares your address (CGNAT), so only players on your WiFi can join. Try another network or a VPN."
		"NO_INTERNET_ADDRESS":
			return "No internet address found: only players on the same WiFi can join."
	return ""
