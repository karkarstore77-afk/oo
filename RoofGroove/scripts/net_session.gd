extends Node





const PLAYER_SCENE: = preload("res://sence/player.tscn")
const UI: = preload("res://scripts/ui_kit.gd")
const PauseMenu: = preload("res://scripts/pause_menu.gd")
const SEND_INTERVAL: = 0.05

@export var level_id: = "hard"

@export var finish_marker: NodePath = ^"../Label"

var _font: Font = preload("res://fonts/PixelOperator8.ttf")
var _ghosts: Dictionary = {}
var _last_pos: Dictionary = {}
var _pause_btn: Button
var _pause_menu: CanvasLayer
var _accum: = 0.0
var _finished: = false
var _local: Node = null
var _hud: Label
var _panel_root: Control
var _panel_label: Label
var _rank_line: = ""
var _top_lines: = ""


func _ready() -> void :
	print("[net] NetSession ready in_room=", Network.in_room(), " members=", Network.members.size())
	Engine.time_scale = 1.0
	GameAudio.play_music()
	Network.process_mode = Node.PROCESS_MODE_ALWAYS
	if Network.run_active:
		Network.deaths += 1
		Network.total_deaths += 1
		Network.save_cfg()
		if Network.cloud != null:
			Network.cloud.push_now()
	else:
		Network.run_active = true
	_build_ui()
	if Network.in_room():
		add_child(preload("res://scripts/gameplay_chat.gd").new())
	_setup_finish_zone()
	Network.state_received.connect(_on_state)
	Network.peer_left.connect(_on_peer_left)
	Network.disconnected.connect(_on_disconnected)
	Network.time_result.connect(_on_time_result)
	Network.leaderboard_received.connect(_on_leaderboard)
	Network.connection_failed.connect(_on_conn_failed)


func _process(delta: float) -> void :
	if not _finished:
		Network.run_time += delta / maxf(Engine.time_scale, 0.05)
		Network.tick_profile(delta / maxf(Engine.time_scale, 0.05))
	if _local == null or not is_instance_valid(_local):
		_local = get_tree().get_first_node_in_group("local_player")
	_update_hud()
	if Network.in_room() and _local != null:
		_accum += delta
		if _accum >= SEND_INTERVAL:
			_accum = 0.0
			var spr = _local.get_node("AnimatedSprite2D")
			Network.send_state(_local.global_position, String(spr.animation), spr.flip_h)



func _get_ghost(id: int) -> Node:
	if not _ghosts.has(id):
		print("[net] creating ghost for peer ", id)
	if _ghosts.has(id) and is_instance_valid(_ghosts[id]):
		return _ghosts[id]
	var g = PLAYER_SCENE.instantiate()
	g.is_remote = true
	g.peer_id = id
	g.display_name = String(Network.members.get(id, "Player"))

	for n in ["Camera2D", "CanvasLayer2", "Node2D", "MultiplayerSynchronizer"]:
		var c = g.get_node_or_null(n)
		if c:
			c.free()
	get_parent().add_child(g)
	_ghosts[id] = g
	return g


func _on_state(id: int, pos: Vector2, anim_name: String, flip: bool) -> void :
	_last_pos[id] = pos
	_get_ghost(id).apply_net_state(pos, anim_name, flip)



func get_ghosts() -> Dictionary:
	return _ghosts



func get_player_positions() -> Dictionary:
	return _last_pos.duplicate()



func can_pause() -> bool:
	return not _finished


func _on_peer_left(id: int) -> void :
	_last_pos.erase(id)
	if _ghosts.has(id):
		if is_instance_valid(_ghosts[id]):
			_ghosts[id].queue_free()
		_ghosts.erase(id)


func _on_disconnected() -> void :
	_last_pos.clear()
	for id in _ghosts.keys():
		_on_peer_left(id)



func _setup_finish_zone() -> void :
	var marker: = get_node_or_null(finish_marker)
	if marker == null:
		return
	var area: = Area2D.new()
	area.name = "FinishZone"
	var shape: = CollisionShape2D.new()
	var rect: = RectangleShape2D.new()
	rect.size = Vector2(24, 8000)
	shape.shape = rect
	area.add_child(shape)
	area.position = marker.position
	area.body_entered.connect(_on_finish_entered)
	get_parent().add_child.call_deferred(area)



func trigger_finish(body: Node) -> void :
	_on_finish_entered(body)


func _on_finish_entered(body: Node) -> void :
	if _finished or not body.is_in_group("local_player"):
		return
	_finished = true
	if body.has_method("lock_input"):
		body.lock_input()
	if _pause_btn != null:
		_pause_btn.visible = false
	var t: = Network.run_time

	var wp: = get_parent()
	if wp != null and wp.has_method("on_finished"):
		_rank_line = str(wp.call("on_finished", t))
		_top_lines = ""
		_panel_label.text = _panel_text(t)
		_panel_root.visible = true
		return
	if Network.teleported_run:

		_rank_line = tr("Teleport used - time not submitted")
		_top_lines = ""
		_panel_label.text = _panel_text(t)
		_panel_root.visible = true
		return
	_rank_line = tr("Saving score...")
	_top_lines = ""
	_panel_label.text = _panel_text(t)
	_panel_root.visible = true
	Network.submit_time(level_id, t)


func _on_time_result(_level: String, rank: int, is_best: bool) -> void :
	if not _finished:
		return
	if rank > 0:
		_rank_line = tr("RANK #%d%s") % [rank, tr("  NEW BEST!") if is_best else ""]
	elif rank == 0:
		_rank_line = tr("NEW BEST!") if is_best else tr("Saved on this device")
	else:
		_rank_line = tr("Time was not accepted")
	_panel_label.text = _panel_text(Network.run_time)


func _on_leaderboard(_level: String, entries: Array) -> void :
	if not _finished:
		return
	var lines: = PackedStringArray()
	for i in mini(entries.size(), 5):
		var e: Dictionary = entries[i]
		lines.append("%d. %s  %s" % [i + 1, e["name"], Network.format_time(float(e["time"]))])
	_top_lines = "\n".join(lines)
	_panel_label.text = _panel_text(Network.run_time)


func _on_conn_failed() -> void :
	if not _finished:
		return
	_rank_line = tr("Saved on this device")
	_panel_label.text = _panel_text(Network.run_time)


func _panel_text(t: float) -> String:
	var s: = tr("FINISHED!\nTime: %s   Deaths: %d\n%s") % [Network.format_time(t), Network.deaths, _rank_line]
	if _top_lines != "":
		s += "\n\n" + tr("TOP") + "\n" + _top_lines
	return s



func _build_ui() -> void :
	var layer: = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_hud = Label.new()
	_hud.position = Vector2(10, 8)
	_hud.add_theme_font_override("font", _font)
	_hud.add_theme_font_size_override("font_size", 14)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 4)
	layer.add_child(_hud)


	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	_pause_menu.call("setup", self)
	_pause_btn = UI.button("II", 18, 44.0)
	_pause_btn.focus_mode = Control.FOCUS_NONE
	_pause_btn.pressed.connect( func(): _pause_menu.call("open"))
	layer.add_child(_pause_btn)
	_pause_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_pause_btn.offset_left = -64.0
	_pause_btn.offset_right = -10.0
	_pause_btn.offset_top = 8.0
	_pause_btn.offset_bottom = 52.0

	_panel_root = CenterContainer.new()
	_panel_root.visible = false
	layer.add_child(_panel_root)
	_panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: = PanelContainer.new()
	_panel_root.add_child(panel)
	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_panel_label = Label.new()
	_panel_label.add_theme_font_override("font", _font)
	_panel_label.add_theme_font_size_override("font_size", 16)
	_panel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_panel_label)
	var back: = Button.new()
	back.text = "BACK TO MENU"
	back.custom_minimum_size = Vector2(0, 44)
	back.add_theme_font_override("font", _font)
	back.pressed.connect(_on_back_pressed)
	box.add_child(back)


func _update_hud() -> void :
	var wp: = get_parent()
	if wp != null and wp.has_method("hud_text"):
		_hud.text = str(wp.call("hud_text"))
		return
	var rk: Dictionary = Network.rank_for(Network.best_checkpoint)
	var txt: = tr("CHECKPOINT %d  (BEST %d)   %s\nTIME %s   DEATHS %d") % [
		Network.checkpoint, Network.best_checkpoint, tr(str(rk["name"])).to_upper(), 
		Network.format_time(Network.total_time), Network.total_deaths]
	if Network.in_room():
		txt += "\n" + tr("%s   PLAYERS %d") % [Network.display_code(Network.invite_code), Network.members.size()]
	if not OS.has_feature("mobile") and not get_window().has_focus():
		txt += "\n" + tr("WINDOW NOT FOCUSED - CLICK IT TO PLAY")
	_hud.text = txt


func _on_back_pressed() -> void :
	Network.reset_run()
	var wp: = get_parent()
	if wp != null and wp.has_method("back_scene") and not Network.in_room():
		get_tree().change_scene_to_file(str(wp.call("back_scene")))
		return
	get_tree().change_scene_to_file("res://sence/main_menu.tscn")
