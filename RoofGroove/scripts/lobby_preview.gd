extends Node2D




const PLAYER_SCENE: = preload("res://sence/player.tscn")
const UI: = preload("res://scripts/ui_kit.gd")
const SAFE_AREA: = preload("res://scripts/safe_area.gd")
const RoomStart: = preload("res://scripts/room_start.gd")
const WorldData: = preload("res://scripts/world_data.gd")

const HALF_WIDTH: = 170.0
const FLOOR_Y: = 16.0
const SEND_EVERY: = 0.05

var _player: CharacterBody2D
var _ghosts: Dictionary = {}
var _send_timer: = 0.0
var _sky: GradientTexture2D
var _arena: Node2D
var _title: Label
var _hint_label: Label
var _copy_btn: Button
var _players_label: Label
var _count_label: Label
var _start_btn: Button
var _wait_label: Label
var _invite_btn: Button
var _invite_panel: PanelContainer
var _invite_list: VBoxContainer
var _invite_status: Label
var _world_label: Label
var _mode_btn: Button
var _world_btn: Button
var _world_panel: PanelContainer
var _world_list: VBoxContainer
var _world_status: Label


func _ready() -> void :
	if not Network.in_room():
		SceneTransition.go("res://sence/online_menu.tscn")
		return

	_build_sky()
	_build_arena()
	_build_player()
	_build_ui()

	Network.peer_joined.connect( func(_id, _n): _refresh())
	Network.peer_left.connect(_on_peer_left)
	Network.state_received.connect(_on_state)
	Network.game_started.connect(_on_game_started)
	Network.world_changed.connect( func(_id, _n): _refresh())
	Network.mode_changed.connect( func(_m): _refresh())
	Network.invite_code_changed.connect(_on_invite_code_changed)
	Network.invite_code_update_failed.connect(_on_invite_code_update_failed)
	Network.disconnected.connect(_leave_to_menu)
	DayCycle.time_changed.connect( func(_t): _update_sky())
	_refresh()



func _build_sky() -> void :
	var layer: = CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var rect: = TextureRect.new()
	_sky = GradientTexture2D.new()
	_sky.fill_from = Vector2(0, 0)
	_sky.fill_to = Vector2(0, 1)
	_sky.width = 4
	_sky.height = 256
	rect.texture = _sky
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	_update_sky()


func _update_sky() -> void :
	var c: Dictionary = DayCycle.get_colors()
	var g: = Gradient.new()
	g.colors = PackedColorArray([c["sky_top"], c["sky_mid"], c["sky_low"]])
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	_sky.gradient = g
	if _arena != null:
		_arena.queue_redraw()


func _build_arena() -> void :
	_arena = Node2D.new()
	_arena.set_script(preload("res://scripts/lobby_arena.gd"))
	_arena.set("half_width", HALF_WIDTH)
	_arena.set("floor_y", FLOOR_Y)
	add_child(_arena)


func _build_player() -> void :
	_player = PLAYER_SCENE.instantiate()
	_player.position = Vector2(0, FLOOR_Y - 20.0)
	add_child(_player)
	var cam: = _player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.zoom = Vector2(4.5, 4.5)
		cam.limit_left = int( - HALF_WIDTH)
		cam.limit_right = int(HALF_WIDTH)
		cam.limit_top = -110
		cam.limit_bottom = int(FLOOR_Y + 40.0)



func _build_ui() -> void :
	var layer: = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)

	var safe: = MarginContainer.new()
	safe.set_script(SAFE_AREA)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(safe)

	var top: = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	safe.add_child(top)

	var left: = VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	top.add_child(left)
	_title = UI.label("", 18)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(_title)
	_count_label = UI.label("", 13, Color(1, 0.85, 0.4))
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(_count_label)
	_hint_label = UI.label("", 11, Color(1, 0.7, 0.3), 520.0)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(_hint_label)
	_players_label = UI.label("", 13)
	_players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(_players_label)

	var right: = VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_theme_constant_override("separation", 8)
	top.add_child(right)
	_start_btn = UI.button("START", 18, 52.0)
	_start_btn.custom_minimum_size.x = 190
	_start_btn.pressed.connect( func(): Network.request_start())
	right.add_child(_start_btn)
	_wait_label = UI.label("Waiting for host...", 12, Color(0.85, 0.85, 0.9))
	right.add_child(_wait_label)
	_world_label = UI.label("", 11, Color(0.85, 0.95, 1.0))
	right.add_child(_world_label)
	_mode_btn = UI.button("MODE", 16, 44.0)
	_mode_btn.custom_minimum_size.x = 190
	_mode_btn.pressed.connect(_cycle_mode)
	right.add_child(_mode_btn)
	_world_btn = UI.button("WORLD", 16, 44.0)
	_world_btn.custom_minimum_size.x = 190
	_world_btn.pressed.connect(_open_worlds)
	right.add_child(_world_btn)
	_copy_btn = UI.button("COPY CODE", 16, 44.0)
	_copy_btn.custom_minimum_size.x = 190
	_copy_btn.pressed.connect( func(): DisplayServer.clipboard_set(Network.display_code(Network.invite_code)))
	right.add_child(_copy_btn)
	_invite_btn = UI.button("INVITE", 16, 44.0)
	_invite_btn.custom_minimum_size.x = 190
	_invite_btn.pressed.connect(_open_invites)
	right.add_child(_invite_btn)
	var leave: = UI.button("LEAVE", 16, 44.0)
	leave.custom_minimum_size.x = 190
	leave.pressed.connect(_leave_to_menu)
	right.add_child(leave)
	_build_invite_panel(layer)
	_build_world_panel(layer)


func _refresh() -> void :
	if not Network.in_room():
		return
	if Network.mode == Network.Mode.LAN:
		var ips: = Network.get_lan_ips()
		_title.text = "LAN  " + (", ".join(ips) if ips.size() > 0 else "")
	else:
		_title.text = tr("ROOM") + "  " + Network.display_code(Network.invite_code)
	_count_label.text = tr("PLAYERS %d") % Network.members.size()
	var lines: = PackedStringArray()
	for id in Network.members:
		if lines.size() >= 12:
			lines.append("+ %d ..." % (Network.members.size() - 12))
			break
		var host_tag: = ("  " + tr("(HOST)")) if id == Network.room_host_id else ""
		lines.append("- %s%s" % [Network.members[id], host_tag])
	_players_label.text = "\n".join(lines)
	_hint_label.text = tr(_p2p_hint(Network.p2p_note)) if (Network.is_p2p_host and Network.p2p_note != "") else ""
	_hint_label.visible = _hint_label.text != ""
	_copy_btn.visible = Network.mode == Network.Mode.ONLINE
	_start_btn.visible = Network.is_room_host()
	_invite_btn.visible = Network.mode == Network.Mode.ONLINE
	_wait_label.visible = not Network.is_room_host()
	_mode_btn.visible = Network.is_room_host()
	_mode_btn.text = tr("MODE") + ": " + tr(Network.room_mode.to_upper())
	_world_btn.visible = Network.is_room_host() and Network.room_mode != "pvp"
	if Network.room_mode == "pvp":
		_world_label.text = tr("MODE") + ": " + tr("PVP") + " - " + tr("ARENA")
	else:
		_world_label.text = tr("MODE") + ": " + tr(Network.room_mode.to_upper()) + "\n" + tr("WORLD") + ": " + (Network.room_world_name if Network.room_world != "" else tr("DEFAULT"))


func _on_invite_code_changed(code: String, by_admin: bool) -> void:
	_refresh()
	if by_admin:
		_hint_label.text = tr("Invite code changed by Admin: %s") % Network.display_code(code)
		_hint_label.visible = true
		await get_tree().create_timer(5.0).timeout
		if is_inside_tree():
			_refresh()


func _on_invite_code_update_failed(message: String) -> void:
	_hint_label.text = tr(message)
	_hint_label.visible = true



func _physics_process(delta: float) -> void :
	if _player == null:
		return
	_send_timer += delta
	if _send_timer >= SEND_EVERY:
		_send_timer = 0.0
		var anim: AnimatedSprite2D = _player.get_node_or_null("AnimatedSprite2D")
		if anim:
			Network.send_state(_player.global_position, str(anim.animation), anim.flip_h)

	if _player.global_position.y > FLOOR_Y + 200.0:
		_player.global_position = Vector2(0, FLOOR_Y - 20.0)
		_player.velocity = Vector2.ZERO


func _on_state(id: int, pos: Vector2, anim_name: String, flip: bool) -> void :
	if not _ghosts.has(id):
		var ghost = PLAYER_SCENE.instantiate()
		ghost.is_remote = true
		ghost.peer_id = id
		ghost.display_name = str(Network.members.get(id, "Player"))
		add_child(ghost)
		_ghosts[id] = ghost
	_ghosts[id].apply_net_state(pos, anim_name, flip)


func _on_peer_left(id: int) -> void :
	if _ghosts.has(id):
		_ghosts[id].queue_free()
		_ghosts.erase(id)
	_refresh()


func _on_game_started(_path: String) -> void :
	if Network.room_world != "":
		_wait_label.visible = true
		_wait_label.text = tr("Loading ...")
	var err: String = await RoomStart.go(Network)
	if err != "" and is_inside_tree():
		_wait_label.visible = true
		_wait_label.text = tr(err)


func _leave_to_menu() -> void :
	Network.leave()
	SceneTransition.go("res://sence/online_menu.tscn")



func _build_invite_panel(layer: CanvasLayer) -> void :
	var center: = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_invite_panel = PanelContainer.new()
	_invite_panel.visible = false
	center.add_child(_invite_panel)
	var margin: = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_invite_panel.add_child(margin)
	var col: = VBoxContainer.new()
	col.custom_minimum_size = Vector2(380, 0)
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	col.add_child(UI.label("INVITE A FRIEND", 18))
	_invite_list = VBoxContainer.new()
	_invite_list.add_theme_constant_override("separation", 6)
	col.add_child(_invite_list)
	_invite_status = UI.label("", 12, Color(1, 0.85, 0.4), 380.0)
	col.add_child(_invite_status)
	var close: = UI.button("CLOSE", 16, 44.0)
	close.pressed.connect( func(): _invite_panel.visible = false)
	col.add_child(close)


func _open_invites() -> void :
	_invite_status.text = ""
	for child in _invite_list.get_children():
		child.queue_free()
	if FriendsSystem.friends.is_empty():
		_invite_list.add_child(UI.label("No friends yet. Add some from the FRIENDS menu.", 13, Color(0.8, 0.8, 0.85), 380.0))
	else:
		for fid in FriendsSystem.friends:
			var friend: Dictionary = FriendsSystem.friends[fid]
			var row: = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_invite_list.add_child(row)
			var name_label: = UI.label("%s  (ID %s)" % [friend.get("name", "Player"), fid], 14)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)
			var btn: = UI.button("INVITE", 14, 40.0)
			btn.pressed.connect( func(): _send_invite(fid, btn))
			row.add_child(btn)
	_invite_panel.visible = true


func _send_invite(fid: String, btn: Button) -> void :
	btn.disabled = true
	_invite_status.text = "Sending..."
	var r: Dictionary = await FriendsSystem.send_invite(fid)
	_invite_status.text = str(r["message"])
	if is_instance_valid(btn):
		btn.disabled = false



func _build_world_panel(layer: CanvasLayer) -> void :
	var center: = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world_panel = PanelContainer.new()
	_world_panel.visible = false
	center.add_child(_world_panel)
	var margin: = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_world_panel.add_child(margin)
	var col: = VBoxContainer.new()
	col.custom_minimum_size = Vector2(420, 0)
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	col.add_child(UI.label("CHOOSE A WORLD", 18))
	var scroll: = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_world_list = VBoxContainer.new()
	_world_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_world_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_world_list)
	_world_status = UI.label("", 12, Color(1, 0.85, 0.4), 420.0)
	col.add_child(_world_status)
	var close: = UI.button("CLOSE", 16, 44.0)
	close.pressed.connect( func(): _world_panel.visible = false)
	col.add_child(close)


func _cycle_mode() -> void :
	var i: int = Network.MODES.find(Network.room_mode)
	var next_mode := str(Network.MODES[(i + 1) % Network.MODES.size()])
	if next_mode == "race" and Network.room_world in [Network.BUILTIN_ENDLESS_WORLD, Network.BUILTIN_CLASSIC_WORLD]:
		Network.set_room_world("", "")
	Network.set_room_mode(next_mode)


func _open_worlds() -> void :
	_world_panel.visible = true
	_world_status.text = tr("Loading ...")
	for c in _world_list.get_children():
		c.queue_free()
	_add_world_choice("", tr("DEFAULT"))
	if Network.room_mode != "race":
		_add_world_choice(Network.BUILTIN_ENDLESS_WORLD, tr("ENDLESS WORLD"))
		_add_world_choice(Network.BUILTIN_CLASSIC_WORLD, tr("CLASSIC WORLD"))
	var r: Dictionary = await WorldData.list_online()
	if not is_inside_tree():
		return
	if not bool(r.get("ok", false)):
		_world_status.text = tr(str(r.get("error", "Could not reach the server")))
		return
	_world_status.text = ""
	for w in r["worlds"]:
		_add_world_choice(str(w["id"]), str(w["name"]))


func _add_world_choice(id: String, world_name: String) -> void :
	var b: = UI.button(world_name, 14, 44.0)
	b.pressed.connect( func():
		Network.set_room_world(id, world_name if id != "" else "")
		_world_panel.visible = false)
	_world_list.add_child(b)


func _p2p_hint(note: String) -> String:
	match note:
		"NO_UPNP":
			return "Your router did not open the port automatically. Forward UDP port 24680 to this device so friends outside your WiFi can join."
		"CGNAT":
			return "Your internet provider shares your address (CGNAT), so only players on your WiFi can join. Try another network or a VPN."
		"NO_INTERNET_ADDRESS":
			return "No internet address found: only players on the same WiFi can join."
	return ""
