extends Control

const UI: = preload("res://scripts/ui_kit.gd")
const SAFE_AREA: = preload("res://scripts/safe_area.gd")
const Fx: = preload("res://scripts/ui_fx.gd")
const Layout: = preload("res://scripts/menu_layout.gd")
const AvatarFx: = preload("res://scripts/avatar_fx.gd")

const BG: = Color("#14141f")
const CARD_BG: = Color("#20212e")
const CARD_BORDER: = Color("#34364d")
const GOLD: = Color("#ffd666")
const GREEN: = Color("#58d68d")
const RED: = Color("#ff8a80")
const MUTED: = Color("#a7a9b8")

var _content: VBoxContainer
var _status: Label
var _refresh_button: Button
var _tabs: Dictionary = {}
var _tab: String = "all"
var _search_input: LineEdit
var _search_kind: OptionButton
var _search_text: = ""
var _search_by_id: = false
var _search_results: Array = []
var _search_done: = false
var _search_list: VBoxContainer
var _refreshing: = false
var _searching: = false
var _responding: = false
var _confirm_id: = ""
var _animate: = true
var _col_width: = 600.0


func _ready() -> void :
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: = ColorRect.new()
	bg.color = BG
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe: = MarginContainer.new()
	safe.set_script(SAFE_AREA)
	add_child(safe)
	for side in ["left", "right", "top", "bottom"]:
		var extra: int = Layout.SPACE if side == "top" else 0
		safe.add_theme_constant_override("margin_" + side, 14 + extra)
	var scroll: = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	safe.add_child(scroll)
	var center: = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_col_width = minf(get_viewport_rect().size.x - 36.0, 760.0)
	var root: = VBoxContainer.new()
	root.custom_minimum_size = Vector2(_col_width, 0)
	root.add_theme_constant_override("separation", 10)
	center.add_child(root)

	root.add_child(UI.label(tr("FRIENDS"), 30))
	var id_row: = HBoxContainer.new()
	id_row.alignment = BoxContainer.ALIGNMENT_CENTER
	id_row.add_theme_constant_override("separation", 10)
	root.add_child(id_row)
	id_row.add_child(UI.label(tr("Your ID: %s") % FriendsSystem.player_id, 14, GOLD))
	var copy_button: Button = UI.button(tr("COPY"), 11, 32.0)
	copy_button.pressed.connect(_copy_id)
	id_row.add_child(copy_button)

	var tab_row: = GridContainer.new()
	tab_row.columns = 5 if get_viewport_rect().size.x >= 700.0 else 3
	tab_row.add_theme_constant_override("h_separation", 6)
	tab_row.add_theme_constant_override("v_separation", 6)
	root.add_child(tab_row)
	for key in ["all", "online", "offline", "requests", "add"]:
		var button: Button = UI.button("", 13, 42.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_tab.bind(key))
		tab_row.add_child(button)
		_tabs[key] = button

	_status = UI.label("", 13, GOLD, _col_width)
	_status.custom_minimum_size.y = 22
	root.add_child(_status)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	root.add_child(_content)

	var footer: = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	root.add_child(footer)
	_refresh_button = UI.button(tr("REFRESH"), 14, 44.0)
	_refresh_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refresh_button.pressed.connect(_refresh)
	footer.add_child(_refresh_button)
	var back: Button = UI.button(tr("BACK"), 16, 44.0)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect( func(): get_tree().change_scene_to_file("res://sence/account_hub.tscn"))
	footer.add_child(back)

	FriendsSystem.friends_updated.connect(_redraw)
	FriendsSystem.requests_updated.connect(_redraw)
	FriendsSystem.profile_updated.connect(_redraw)
	_select_tab("all")
	_refresh()


func _exit_tree() -> void :
	if FriendsSystem.friends_updated.is_connected(_redraw):
		FriendsSystem.friends_updated.disconnect(_redraw)
	if FriendsSystem.requests_updated.is_connected(_redraw):
		FriendsSystem.requests_updated.disconnect(_redraw)
	if FriendsSystem.profile_updated.is_connected(_redraw):
		FriendsSystem.profile_updated.disconnect(_redraw)


# ---------------------------------------------------------------- helpers

func _signed_in() -> bool:
	return Network.cloud != null and Network.cloud.is_signed_in()


func _say(text: String) -> void :
	if _status == null:
		return
	_status.text = text
	if text != "":
		Fx.fade_in(_status, 0.0, 0.2)


func _copy_id() -> void :
	DisplayServer.clipboard_set(FriendsSystem.player_id)
	_say(tr("ID copied"))


func _counts() -> Dictionary:
	var online: = 0
	for f in FriendsSystem.friends.values():
		if bool(f.get("online", false)):
			online += 1
	var pending: = 0
	for r in FriendsSystem.incoming_requests:
		if str(r.get("status", "")) == "pending":
			pending += 1
	var total: int = FriendsSystem.friends.size()
	return {"all": total, "online": online, "offline": total - online, "requests": pending + FriendsSystem.inbox_unread}


func _update_tab_titles() -> void :
	var counts: Dictionary = _counts()
	for key in _tabs:
		var button: Button = _tabs[key]
		var title: String = tr(str(key).to_upper())
		if key == "requests":
			if int(counts["requests"]) > 0:
				title += " (%d)" % int(counts["requests"])
		elif key != "add":
			title += " (%d)" % int(counts[key])
		button.text = title


func _ago(ts: int) -> String:
	if ts <= 0:
		return ""
	var d: int = int(Time.get_unix_time_from_system()) - ts
	if d < 60:
		return tr("just now")
	if d < 3600:
		return tr("%d min ago") % (d / 60)
	if d < 86400:
		return tr("%d h ago") % (d / 3600)
	return tr("%d d ago") % (d / 86400)


func _letter_for(player_name: String) -> String:
	var first: = player_name.strip_edges().substr(0, 1).to_upper()
	if first.length() == 1 and first >= "A" and first <= "Z":
		return first
	return "A"


func _color_for(player_name: String) -> int:
	return absi(player_name.hash()) % 8


func _relation(uid: String) -> String:
	for f in FriendsSystem.friends.values():
		if str(f.get("uid", "")) == uid:
			return "friend"
	for r in FriendsSystem.outgoing_requests:
		if str(r.get("uid", "")) == uid and str(r.get("status", "")) == "pending":
			return "sent"
	for r in FriendsSystem.incoming_requests:
		if str(r.get("uid", "")) == uid and str(r.get("status", "")) == "pending":
			return "incoming"
	return "none"


func _make_card() -> PanelContainer:
	var panel: = PanelContainer.new()
	var s: = StyleBoxFlat.new()
	s.bg_color = CARD_BG
	s.border_color = CARD_BORDER
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", s)
	return panel


func _make_avatar(letter: String, color_index: int, px: float, badge: String = "", extras: Dictionary = {}) -> Control:
	return AvatarFx.build(letter, color_index, px, badge, extras)


func _make_text_block(title: String, badge: String, line: String, online: bool, show_dot: bool) -> VBoxContainer:
	var box: = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	var top: = HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	var name_label: = UI.label(title, 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.clip_text = true
	name_label.custom_minimum_size.x = 70
	top.add_child(name_label)
	if badge != "":
		top.add_child(UI.label("♛ " + badge, 11, AvatarFx.badge_color(badge)))
	var second: = HBoxContainer.new()
	second.add_theme_constant_override("separation", 6)
	box.add_child(second)
	if show_dot:
		var dot: = UI.label("●", 12, GREEN if online else MUTED)
		second.add_child(dot)
		if online:
			dot.tree_entered.connect(_start_pulse.bind(dot))
	var info: = UI.label(line, 12, GREEN if online else MUTED)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.clip_text = true
	second.add_child(info)
	return box


func _start_pulse(n: CanvasItem) -> void :
	Fx.pulse(n, 0.4, 2.0)


# ---------------------------------------------------------------- tabs

func _select_tab(key: String) -> void :
	_tab = key
	_confirm_id = ""
	_animate = true
	for tab_key in _tabs:
		var button: Button = _tabs[tab_key]
		button.modulate = GOLD if tab_key == key else Color.WHITE
	_draw_tab()


func _clear_content() -> void :
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_search_input = null
	_search_kind = null
	_search_list = null


func _add_in(node: Control, index: int) -> void :
	_content.add_child(node)
	if _animate:
		Fx.fade_in(node, minf(float(index) * 0.04, 0.4), 0.28)


func _draw_tab() -> void :
	_clear_content()
	_update_tab_titles()
	var index: = 0
	if not _signed_in():
		var panel: = _make_card()
		var box: = VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		panel.add_child(box)
		box.add_child(UI.label(tr("Sign in to use friends"), 15, GOLD, _col_width - 40.0))
		var go: Button = UI.button(tr("GO TO ACCOUNT"), 13, 42.0)
		go.pressed.connect( func(): get_tree().change_scene_to_file("res://sence/account_menu.tscn"))
		box.add_child(go)
		_add_in(panel, index)
		index += 1
		if _tab == "add" or _tab == "requests":
			_animate = false
			return
	if _tab == "add":
		_draw_add_tab()
	elif _tab == "requests":
		_draw_requests_tab()
	else:
		_draw_friends_tab(index)
	_animate = false


func _draw_friends_tab(start_index: int) -> void :
	var ids: Array = FriendsSystem.friends.keys()
	ids.sort_custom( func(a, b):
		var oa: bool = bool(FriendsSystem.friends[a].get("online", false))
		var ob: bool = bool(FriendsSystem.friends[b].get("online", false))
		if oa != ob:
			return oa
		return str(FriendsSystem.friends[a].get("name", "")).to_lower() < str(FriendsSystem.friends[b].get("name", "")).to_lower())
	var shown: = 0
	for fid in ids:
		var person: Dictionary = FriendsSystem.friends[fid]
		var online: bool = bool(person.get("online", false))
		if _tab == "online" and not online:
			continue
		if _tab == "offline" and online:
			continue
		_add_in(_friend_card(person, str(fid)), start_index + shown)
		shown += 1
	if shown == 0:
		_content.add_child(UI.label(tr("No players in this list yet."), 15, Color("#c3c5d4"), _col_width))


func _friend_card(person: Dictionary, fid: String) -> Control:
	var card: = _make_card()
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var player_name: = str(person.get("name", "Player"))
	row.add_child(_make_avatar(str(person.get("letter", _letter_for(player_name))), int(person.get("color", _color_for(player_name))), 52.0, str(person.get("badge", "")), AvatarFx.extras_of(person)))
	var online: bool = bool(person.get("online", false))
	var line: = "#%s" % str(person.get("player_id", fid))
	if online:
		line = tr("ONLINE") + "   " + line
	else:
		var seen: = _ago(int(person.get("last_seen", 0)))
		line = tr("OFFLINE") + ("  " + seen if seen != "" else "") + "   " + line
	row.add_child(_make_text_block(player_name, str(person.get("badge", "")), line, online, true))
	var uid: = str(person.get("uid", ""))
	if online and _signed_in() and Network.in_room() and Network.mode == Network.Mode.ONLINE:
		var invite: Button = UI.button(tr("INVITE"), 11, 40.0)
		invite.pressed.connect(_on_invite.bind(fid))
		row.add_child(invite)
	if uid != "":
		var view: Button = UI.button(tr("PROFILE"), 11, 40.0)
		view.pressed.connect(_open_profile.bind(uid, false))
		row.add_child(view)
	var remove: Button = UI.button("X", 13, 40.0)
	remove.pressed.connect(_on_remove.bind(fid, remove))
	row.add_child(remove)
	return card


func _draw_add_tab() -> void :
	_content.add_child(UI.label(tr("Find players by display name or player ID"), 14, Color("#d6d9ec"), _col_width))
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_content.add_child(row)
	_search_kind = OptionButton.new()
	_search_kind.add_item(tr("NAME"))
	_search_kind.add_item(tr("ID"))
	_search_kind.select(1 if _search_by_id else 0)
	row.add_child(_search_kind)
	_search_input = LineEdit.new()
	_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_input.placeholder_text = tr("Type a name or ID")
	_search_input.custom_minimum_size.y = 42
	_search_input.text = _search_text
	_search_input.text_submitted.connect( func(_text): _search())
	row.add_child(_search_input)
	var search_button: Button = UI.button(tr("SEARCH"), 12, 42.0)
	search_button.pressed.connect(_search)
	row.add_child(search_button)
	_search_list = VBoxContainer.new()
	_search_list.add_theme_constant_override("separation", 8)
	_content.add_child(_search_list)
	_render_search_results()


func _render_search_results() -> void :
	if _search_list == null or not is_instance_valid(_search_list):
		return
	for child in _search_list.get_children():
		_search_list.remove_child(child)
		child.queue_free()
	var index: = 0
	for person in _search_results:
		var card: = _make_card()
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var player_name: = str(person.get("name", "Player"))
		row.add_child(_make_avatar(str(person.get("letter", "A")), int(person.get("color", 0)), 48.0, str(person.get("badge", "")), AvatarFx.extras_of(person)))
		var online: bool = bool(person.get("online", false))
		var line: = "#%s" % str(person.get("player_id", ""))
		if online:
			line = tr("ONLINE") + "   " + line
		row.add_child(_make_text_block(player_name, str(person.get("badge", "")), line, online, online))
		var uid: = str(person.get("uid", ""))
		var view: Button = UI.button(tr("PROFILE"), 11, 40.0)
		view.pressed.connect(_open_profile.bind(uid, true))
		row.add_child(view)
		var relation: = _relation(uid)
		var add: Button
		if relation == "friend":
			add = UI.button(tr("FRIENDS"), 11, 40.0)
			add.disabled = true
		elif relation == "sent":
			add = UI.button(tr("SENT"), 11, 40.0)
			add.disabled = true
		elif relation == "incoming":
			add = UI.button(tr("REQUESTS"), 11, 40.0)
			add.pressed.connect(_select_tab.bind("requests"))
		else:
			add = UI.button(tr("ADD"), 12, 40.0)
			add.pressed.connect(_send_request.bind(person))
		row.add_child(add)
		_search_list.add_child(card)
		Fx.fade_in(card, minf(float(index) * 0.04, 0.3), 0.25)
		index += 1
	if _search_results.is_empty():
		var message: = tr("No matches found.") if _search_done else tr("Search for a player to see matches.")
		_search_list.add_child(UI.label(message, 13, MUTED, _col_width))


func _draw_requests_tab() -> void :
	FriendsSystem.inbox_unread = 0
	var index: = 0
	_add_in(UI.label(tr("REQUESTS SENT TO YOU"), 17, GOLD), index)
	index += 1
	var incoming: = 0
	for request in FriendsSystem.incoming_requests:
		if str(request.get("status", "")) != "pending":
			continue
		incoming += 1
		_add_in(_incoming_card(request), index)
		index += 1
	if incoming == 0:
		_add_in(UI.label(tr("No pending requests."), 13, MUTED, _col_width), index)
		index += 1

	_content.add_child(HSeparator.new())
	_add_in(UI.label(tr("INBOX"), 17, GOLD), index)
	index += 1
	for event in FriendsSystem.inbox_events:
		var line: = "• " + str(event.get("text", ""))
		var ago: = _ago(int(event.get("time", 0)))
		if ago != "":
			line += "   (" + ago + ")"
		_add_in(UI.label(line, 13, Color("#e3e5f1"), _col_width), index)
		index += 1
	if FriendsSystem.inbox_events.is_empty():
		_add_in(UI.label(tr("No new messages."), 13, MUTED, _col_width), index)
		index += 1
	else:
		var clear_inbox: Button = UI.button(tr("CLEAR INBOX"), 11, 36.0)
		clear_inbox.pressed.connect(_clear_inbox)
		_add_in(clear_inbox, index)
		index += 1

	_content.add_child(HSeparator.new())
	_add_in(UI.label(tr("REQUESTS YOU SENT"), 17, GOLD), index)
	index += 1
	var sent: = 0
	for request in FriendsSystem.outgoing_requests:
		if sent >= 15:
			break
		var state: = str(request.get("status", "pending"))
		var state_color: = MUTED
		if state == "accepted":
			state_color = GREEN
		elif state == "rejected":
			state_color = RED
		var text: = "%s  #%s   —   %s" % [request.get("name", "Player"), request.get("player_id", ""), tr(state.to_upper())]
		_add_in(UI.label(text, 13, state_color, _col_width), index)
		index += 1
		sent += 1
	if sent == 0:
		_add_in(UI.label(tr("No requests sent yet."), 13, MUTED, _col_width), index)


func _incoming_card(request: Dictionary) -> Control:
	var card: = _make_card()
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var player_name: = str(request.get("name", "Player"))
	row.add_child(_make_avatar(_letter_for(player_name), _color_for(player_name), 48.0))
	row.add_child(_make_text_block(player_name, "", "#%s" % str(request.get("player_id", "")), false, false))
	var request_id: = str(request.get("id", ""))
	var view: Button = UI.button(tr("PROFILE"), 11, 40.0)
	view.pressed.connect(_open_profile.bind(str(request.get("uid", "")), false))
	row.add_child(view)
	var accept: Button = UI.button(tr("ACCEPT"), 11, 40.0)
	accept.modulate = GREEN
	accept.pressed.connect(_respond.bind(request_id, true))
	row.add_child(accept)
	var reject: Button = UI.button(tr("DECLINE"), 11, 40.0)
	reject.modulate = RED
	reject.pressed.connect(_respond.bind(request_id, false))
	row.add_child(reject)
	return card


# ---------------------------------------------------------------- actions

func _search() -> void :
	if _searching or _search_input == null:
		return
	var text: String = _search_input.text.strip_edges()
	_search_text = text
	_search_by_id = _search_kind.selected == 1
	if text == "":
		_say(tr("Type a name or ID"))
		return
	if not _signed_in():
		_say(tr("Sign in to search for players."))
		return
	_searching = true
	_say(tr("Searching..."))
	var results: Array = await FriendsSystem.search_players(text, _search_by_id)
	_searching = false
	if not is_inside_tree():
		return
	_search_results = results
	_search_done = true
	_say("%d %s" % [_search_results.size(), tr("result(s)")])
	_render_search_results()


func _send_request(person: Dictionary) -> void :
	_say(tr("Sending request..."))
	var result: Dictionary = await FriendsSystem.send_friend_request(person)
	if not is_inside_tree():
		return
	_say(tr(str(result.get("message", ""))))
	_render_search_results()


func _respond(request_id: String, accept: bool) -> void :
	if _responding:
		return
	_responding = true
	_say(tr("Updating request..."))
	var result: Dictionary = await FriendsSystem.respond_to_request(request_id, accept)
	_responding = false
	if not is_inside_tree():
		return
	_say(tr(str(result.get("message", ""))))
	_redraw()


func _on_invite(fid: String) -> void :
	var result: Dictionary = await FriendsSystem.send_invite(fid)
	if not is_inside_tree():
		return
	_say(str(result.get("message", "")))


func _on_remove(fid: String, button: Button) -> void :
	if _confirm_id != fid:
		_confirm_id = fid
		button.text = tr("SURE?")
		button.modulate = RED
		get_tree().create_timer(3.0).timeout.connect(_reset_confirm.bind(fid))
		return
	_confirm_id = ""
	FriendsSystem.remove_friend(fid)
	_say(tr("Friend removed"))


func _reset_confirm(fid: String) -> void :
	if _confirm_id == fid and is_inside_tree():
		_confirm_id = ""
		_draw_tab()


func _clear_inbox() -> void :
	FriendsSystem.inbox_events.clear()
	FriendsSystem._save()
	_draw_tab()


func _open_profile(uid: String, allow_add: bool) -> void :
	if uid == "":
		return
	Network.set_meta("profile_target_uid", uid)
	Network.set_meta("profile_can_add", allow_add)
	get_tree().change_scene_to_file("res://sence/profile_menu.tscn")


func _refresh() -> void :
	if _refreshing:
		return
	if not _signed_in():
		_say(tr("Sign in to sync your friends."))
		_update_tab_titles()
		return
	_refreshing = true
	_refresh_button.disabled = true
	_say(tr("Refreshing..."))
	await FriendsSystem.refresh_requests()
	await FriendsSystem.refresh_all()
	_refreshing = false
	if not is_inside_tree():
		return
	_refresh_button.disabled = false
	_say("")
	_redraw()


func _redraw() -> void :
	if not is_inside_tree():
		return
	# Do not wipe the search box while the player is typing in it.
	if _tab == "add" and _search_input != null and is_instance_valid(_search_input) and _search_input.has_focus():
		_update_tab_titles()
		return
	_draw_tab()
