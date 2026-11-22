extends Control





const UI: = preload("res://scripts/ui_kit.gd")
const WorldData: = preload("res://scripts/world_data.gd")
const CustomWorld: = preload("res://scripts/custom_world.gd")
const WorldEditor: = preload("res://scripts/world_editor.gd")
const MENU_SCENE: = "res://sence/play_menu.tscn"
const SELF_SCENE: = "res://sence/worlds_menu.tscn"

enum Tab{GAME, COMMUNITY, MINE}

var _tab: int = Tab.GAME
var _list: VBoxContainer
var _status: Label
var _tab_buttons: Array = []
var _new_btn: Button
var _refresh_btn: Button
var _online: Array = []
var _online_loaded: = false
var _loading: = false


func _ready() -> void :
	Engine.time_scale = 1.0
	var bg: = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 88.0
	var vp: = get_viewport_rect().size
	var root: = VBoxContainer.new()
	root.custom_minimum_size = Vector2(minf(vp.x - 40.0, 720.0), vp.y - 30.0)
	root.add_theme_constant_override("separation", 8)
	center.add_child(root)

	root.add_child(UI.label("WORLDS", 26))

	var tabs: = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	root.add_child(tabs)
	var names: = {Tab.GAME: "GAME WORLDS", Tab.COMMUNITY: "COMMUNITY", Tab.MINE: "MY WORLDS"}
	for t in names:
		var b: = UI.button(str(names[t]), 12, 44.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select_tab.bind(t))
		tabs.add_child(b)
		_tab_buttons.append(b)

	var scroll: = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

	_status = UI.label("", 12, Color(1, 0.85, 0.4), 600.0)
	root.add_child(_status)

	var foot: = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	root.add_child(foot)
	var back: = UI.button("BACK", 16, 48.0)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_go_back)
	foot.add_child(back)
	_refresh_btn = UI.button("REFRESH", 16, 48.0)
	_refresh_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refresh_btn.pressed.connect( func() -> void : _load_online(true))
	foot.add_child(_refresh_btn)
	_new_btn = UI.button("NEW WORLD", 16, 48.0)
	_new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_btn.pressed.connect(_on_new)
	foot.add_child(_new_btn)

	_select_tab(Tab.GAME)


func _select_tab(t: int) -> void :
	_tab = t
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).disabled = (i == t)
	_new_btn.visible = t == Tab.MINE
	_refresh_btn.visible = t != Tab.MINE
	_status.text = ""
	if t != Tab.MINE and not _online_loaded:
		_load_online(false)
	_show()


func _load_online(force: bool) -> void :
	if _loading or (_online_loaded and not force):
		return
	_loading = true
	_status.text = tr("Loading ...")
	var r: Dictionary = await WorldData.list_online()
	if not is_inside_tree():
		return
	_loading = false
	if bool(r.get("ok", false)):
		_online = r["worlds"]
		_online_loaded = true
		_status.text = ""
	else:
		_status.text = tr(str(r.get("error", "Could not reach the server")))
	_show()


func _clear() -> void :
	for c in _list.get_children():
		c.queue_free()


func _show() -> void :
	_clear()
	match _tab:
		Tab.GAME:
			_add_row(tr("ENDLESS WORLD"), tr("The main world - never ends"), [
				[tr("PLAY"), func() -> void : get_tree().change_scene_to_file("res://sence/world_generated.tscn")]])
			_add_row(tr("CLASSIC WORLD"), tr("The original hard world"), [
				[tr("PLAY"), func() -> void : get_tree().change_scene_to_file("res://sence/world.tscn")]])
			for w in _online:
				if bool(w["official"]):
					_add_online_row(w)
		Tab.COMMUNITY:
			var any: = false
			for w in _online:
				if not bool(w["official"]):
					_add_online_row(w)
					any = true
			if not any and _online_loaded:
				_list.add_child(UI.label(tr("No player worlds yet - be the first!"), 13, Color(0.8, 0.8, 0.85), 600.0))
		Tab.MINE:
			var mine: = WorldData.list_local()
			if mine.is_empty():
				_list.add_child(UI.label(tr("You have no worlds yet. Tap NEW WORLD to build one!"), 13, Color(0.8, 0.8, 0.85), 600.0))
			for e in mine:
				_add_mine_row(e)


func _add_online_row(w: Dictionary) -> void :
	var sub: = "%s: %s   %s %d   %s %d" % [tr("by"), str(w["author"]), tr("ISLANDS"), int(w["islands"]), tr("MONSTERS"), int(w["monsters"])]
	var buttons: Array = [[tr("PLAY"), func() -> void : _play_online(str(w["id"]), str(w["name"]))]]
	var c: Node = Network.cloud
	if c != null and c.is_signed_in() and str(w["author_uid"]) == str(c.uid):
		buttons.append([tr("DELETE"), func() -> void : _delete_online(str(w["id"]))])
	_add_row(str(w["name"]), sub, buttons)


func _add_mine_row(e: Dictionary) -> void :
	var w: Dictionary = e["world"]
	var tags: Array = []
	if WorldData.is_verified(w):
		tags.append(tr("TESTED"))
	if str(w.get("published_id", "")) != "":
		tags.append(tr("PUBLISHED"))
	var title: = str(w["name"]) if str(w["name"]) != "" else tr("Untitled")
	var file: = str(e["file"])
	_add_row(title, "  ".join(tags), [
		[tr("EDIT"), func() -> void : _edit(file)], 
		[tr("PLAY"), func() -> void : _play_local(w, title)], 
		[tr("DELETE"), func() -> void : _delete_local(file, w)]])



func _add_row(title: String, sub: String, buttons: Array) -> void :
	var panel: = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin: = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var texts: = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	var t: = UI.label(title, 15, Color.WHITE, 260.0)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(t)
	if sub != "":
		var s: = UI.label(sub, 10, Color(0.75, 0.8, 0.9), 260.0)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		texts.add_child(s)
	for bt in buttons:
		var b: = UI.button(str(bt[0]), 12, 44.0)
		b.custom_minimum_size.x = 84
		var cb: Callable = bt[1]
		if str(bt[0]) == tr("DELETE"):

			b.pressed.connect( func() -> void :
				if b.text == tr("SURE?"):
					cb.call()
				else:
					b.text = tr("SURE?"))
		else:
			b.pressed.connect(cb)
		row.add_child(b)
	_list.add_child(panel)





func _on_new() -> void :
	WorldEditor.edit_file = ""
	get_tree().change_scene_to_file("res://sence/world_editor.tscn")


func _edit(file: String) -> void :
	WorldEditor.edit_file = file
	get_tree().change_scene_to_file("res://sence/world_editor.tscn")


func _play_local(w: Dictionary, title: String) -> void :
	if int(w["finish"]) < 0:
		_status.text = tr("Place a FINISH on an island first")
		return
	CustomWorld.play(get_tree(), w.duplicate(true), title, SELF_SCENE, false)


func _play_online(id: String, world_name: String) -> void :
	_status.text = tr("Loading ...")
	var r: Dictionary = await WorldData.fetch_online(id)
	if not is_inside_tree():
		return
	if not bool(r.get("ok", false)):
		_status.text = tr(str(r.get("error", "Could not load the world")))
		return
	CustomWorld.play(get_tree(), (r["world"] as Dictionary).duplicate(true), world_name, SELF_SCENE, false)


func _delete_local(file: String, w: Dictionary) -> void :

	var pid: = str(w.get("published_id", ""))
	if pid != "" and WorldData.signed_in():
		await WorldData.delete_online(pid)
		_online_loaded = false
	WorldData.delete_local(file)
	if is_inside_tree():
		_show()


func _delete_online(id: String) -> void :
	_status.text = tr("Loading ...")
	var ok: bool = await WorldData.delete_online(id)
	if not is_inside_tree():
		return
	_status.text = "" if ok else tr("Could not reach the server")
	_load_online(true)


func _go_back() -> void :
	get_tree().change_scene_to_file(MENU_SCENE)


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()
