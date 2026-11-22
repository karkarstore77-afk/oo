extends Node2D







const UI: = preload("res://scripts/ui_kit.gd")
const FONT: = preload("res://fonts/PixelOperator8.ttf")
const MAIN_MENU: = "res://sence/main_menu.tscn"
const LOBBY: = "res://sence/lobby_preview.tscn"

const WALL_X: = 248.0
const TOP_Y: = -230.0
const FIRE_CD: = 0.28
const GUN_SPAWN_DIST: = 10.0


const SPAWNS: = [Vector2(-120, -10.5), Vector2(120, -10.5), Vector2(0, -10.5), 
	Vector2(-220, -26.5), Vector2(220, -26.5), Vector2(0, -58.5)]

const BLOCKS: = [
	[-240.0, -200.0, -16.0, 16.0], [-200.0, -170.0, -32.0, 32.0], [-150.0, -80.0, -32.0, 8.0], 
	[-40.0, 40.0, -48.0, 8.0], 
	[80.0, 150.0, -32.0, 8.0], [170.0, 200.0, -32.0, 32.0], [200.0, 240.0, -16.0, 16.0], 
]


class Bullet extends Node2D:
	const SPEED: = 320.0
	var dir: = 1.0
	var life: = 0.9
	var local: = false
	var ns: Node = null
	var exclude: Array[RID] = []

	func _physics_process(delta: float) -> void :
		var from: = global_position
		var to: = from + Vector2(dir * SPEED * delta, 0.0)
		var q: = PhysicsRayQueryParameters2D.create(from, to, 1)
		q.exclude = exclude
		if not get_world_2d().direct_space_state.intersect_ray(q).is_empty():
			queue_free()
			return
		global_position = to
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		if local and ns != null:
			var pos: Dictionary = ns.call("get_player_positions")
			for id in pos:
				if not bool(Network.pvp_alive.get(int(id), true)):
					continue
				var p: Vector2 = pos[id]
				if absf(p.x - to.x) < 9.0 and absf(p.y - to.y) < 13.0:
					Network.send_hit(int(id))
					queue_free()
					return
		queue_redraw()

	func _draw() -> void :
		draw_rect(Rect2(-4.0, -1.0, 8.0, 2.0), Color(1.0, 0.92, 0.35))
		draw_rect(Rect2(-6.0, -0.5, 2.0, 1.0), Color(1.0, 0.5, 0.1))



class Overlay extends Node2D:
	var pid: = 0
	var body: Node2D = null

	func _process(_delta: float) -> void :
		if body == null or not is_instance_valid(body):
			queue_free()
			return
		if Network.pvp_active:
			body.visible = bool(Network.pvp_alive.get(pid, true))
		queue_redraw()

	func _draw() -> void :
		var spr: = body.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		var dir: = -1.0 if (spr != null and spr.flip_h) else 1.0
		var gx: = 3.0 if dir > 0.0 else -11.0
		draw_rect(Rect2(gx, 0.0, 8.0, 3.0), Color(0.18, 0.18, 0.22))
		draw_rect(Rect2(gx + (1.0 if dir > 0.0 else 5.0), 3.0, 2.0, 3.0), Color(0.3, 0.2, 0.15))
		var frac: = clampf(float(Network.pvp_hp.get(pid, Network.PVP_HP)) / float(Network.PVP_HP), 0.0, 1.0)
		draw_rect(Rect2(-12.0, -23.0, 24.0, 3.0), Color(0, 0, 0, 0.75))
		draw_rect(Rect2(-12.0, -23.0, 24.0 * frac, 3.0), Color(1.0 - frac, 0.3 + 0.6 * frac, 0.25))


var _player
var _spr: AnimatedSprite2D
var _ns: Node
var _overlays: Dictionary = {}
var _fire_cd: = 0.0
var _fire_held: = false
var _dead: = false
var _playing: = false
var _ended: = false
var _time_left: = Network.PVP_TIME
var _my_id: = 1
var _center_label: Label
var _feed_label: Label
var _feed_t: = 0.0
var _end_layer: CanvasLayer


func _ready() -> void :
	Engine.time_scale = 1.0
	get_tree().paused = false
	_my_id = multiplayer.get_unique_id()
	add_child(preload("res://scripts/sky_background.gd").new())
	_build_arena()
	_ns = get_node_or_null("NetSession")
	_player = get_node_or_null("player")
	if _player != null:
		_spr = _player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		_player.position = SPAWNS[_spawn_index()]
		_player.input_locked = true
		var cam: = _player.get_node_or_null("Camera2D") as Camera2D
		if cam != null:
			cam.zoom = Vector2(4, 4)
			cam.limit_left = int( - WALL_X)
			cam.limit_right = int(WALL_X)
			cam.limit_top = int(TOP_Y)
			cam.limit_bottom = 48
		_attach_overlay(_player, _my_id)
		_build_ui()
	if Network.in_room():
		add_child(preload("res://scripts/gameplay_chat.gd").new())
	Network.go_received.connect(_begin, CONNECT_ONE_SHOT)
	Network.shot_received.connect( func(_id: int, pos: Vector2, dir: float) -> void : _spawn_bullet(pos, dir, false))
	Network.pvp_updated.connect(_on_pvp_updated)
	Network.pvp_kill.connect(_on_kill)
	Network.pvp_respawn.connect(_on_respawn)
	Network.pvp_ended.connect(_on_ended)
	Network.lobby_requested.connect( func() -> void : get_tree().change_scene_to_file(LOBBY))
	if Network.in_room():
		_center_label.text = tr("WAITING FOR PLAYERS ...")
		Network.send_ready()
	else:
		_begin()


func _spawn_index() -> int:
	if not Network.in_room():
		return 0
	var ids: = Network.members.keys()
	ids.sort()
	return maxi(0, ids.find(_my_id)) % SPAWNS.size()





func _build_arena() -> void :
	_add_solid(Rect2( - WALL_X, 0.0, WALL_X * 2.0, 48.0))
	_add_solid(Rect2( - WALL_X - 16.0, TOP_Y - 16.0, 16.0, 300.0))
	_add_solid(Rect2(WALL_X, TOP_Y - 16.0, 16.0, 300.0))
	_add_solid(Rect2( - WALL_X, TOP_Y - 16.0, WALL_X * 2.0, 16.0))
	for b in BLOCKS:
		_add_solid(Rect2(float(b[0]), float(b[2]), float(b[1]) - float(b[0]), float(b[3])))


func _add_solid(r: Rect2) -> void :
	var body: = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = r.get_center()
	var cs: = CollisionShape2D.new()
	var shape: = RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


func _draw() -> void :
	draw_rect(Rect2( - WALL_X, 0.0, WALL_X * 2.0, 48.0), Color(0.27, 0.23, 0.38))
	draw_rect(Rect2( - WALL_X, 0.0, WALL_X * 2.0, 3.0), Color(0.62, 0.58, 0.8))
	for b in BLOCKS:
		var r: = Rect2(float(b[0]), float(b[2]), float(b[1]) - float(b[0]), float(b[3]))
		draw_rect(r, Color(0.36, 0.4, 0.62))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3.0)), Color(0.75, 0.82, 0.98))
	var wall: = Color(0.16, 0.14, 0.24)
	draw_rect(Rect2( - WALL_X - 16.0, TOP_Y - 16.0, 16.0, 300.0), wall)
	draw_rect(Rect2(WALL_X, TOP_Y - 16.0, 16.0, 300.0), wall)
	draw_rect(Rect2( - WALL_X, TOP_Y - 16.0, WALL_X * 2.0, 16.0), wall)





func _build_ui() -> void :
	var layer: = CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_center_label = Label.new()
	_center_label.add_theme_font_override("font", FONT)
	_center_label.add_theme_font_size_override("font_size", 28)
	_center_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_center_label.add_theme_constant_override("outline_size", 10)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_center_label)
	_center_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_center_label.grow_horizontal = Control.GROW_DIRECTION_BOTH

	_feed_label = Label.new()
	_feed_label.add_theme_font_override("font", FONT)
	_feed_label.add_theme_font_size_override("font_size", 14)
	_feed_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_feed_label.add_theme_constant_override("outline_size", 6)
	_feed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_feed_label)
	_feed_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_feed_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_feed_label.offset_top = 90

	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		var fire: = UI.button("FIRE", 16, 78.0)
		fire.custom_minimum_size = Vector2(120, 78)
		fire.focus_mode = Control.FOCUS_NONE
		fire.theme_type_variation = &"DangerButton"
		fire.button_down.connect( func() -> void : _fire_held = true)
		fire.button_up.connect( func() -> void : _fire_held = false)
		layer.add_child(fire)
		fire.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		fire.offset_left = 24
		fire.offset_top = -300
		fire.offset_right = 144
		fire.offset_bottom = -222


func _begin() -> void :
	if _playing:
		return
	_playing = true
	_center_label.add_theme_font_size_override("font_size", 56)
	for n in ["3", "2", "1"]:
		_center_label.text = n
		await get_tree().create_timer(0.7).timeout
		if not is_inside_tree():
			return
	_center_label.text = tr("FIGHT!")
	_time_left = Network.pvp_time_limit if Network.in_room() else Network.PVP_TIME
	if _player != null and not _dead:
		_player.input_locked = false
	_running = true
	await get_tree().create_timer(0.8).timeout
	if is_inside_tree() and not _dead:
		_center_label.text = ""


var _running: = false


func _process(delta: float) -> void :
	_fire_cd = maxf(0.0, _fire_cd - delta)
	if _running and not _ended:
		_time_left = maxf(0.0, _time_left - delta)
	if _feed_t > 0.0:
		_feed_t -= delta
		if _feed_t <= 0.0:
			_feed_label.text = ""
	if _ns != null and _ns.has_method("get_ghosts"):
		var ghosts: Dictionary = _ns.call("get_ghosts")
		for id in ghosts:
			if not _overlays.has(id) or not is_instance_valid(_overlays[id]):
				if is_instance_valid(ghosts[id]):
					_attach_overlay(ghosts[id], int(id))
	if _running and not _dead and not _ended and (Input.is_key_pressed(KEY_F) or _fire_held):
		_fire()


func _attach_overlay(body: Node2D, id: int) -> void :
	var o: = Overlay.new()
	o.pid = id
	o.body = body
	body.add_child(o)
	_overlays[id] = o





func _fire() -> void :
	if _fire_cd > 0.0 or _player == null or _spr == null:
		return
	_fire_cd = FIRE_CD
	var dir: = -1.0 if _spr.flip_h else 1.0
	var pos: Vector2 = _player.global_position + Vector2(GUN_SPAWN_DIST * dir, 2.0)
	_spawn_bullet(pos, dir, true)
	if Network.in_room():
		Network.send_shot(pos, dir)


func _spawn_bullet(pos: Vector2, dir: float, local: bool) -> void :
	var b: = Bullet.new()
	b.dir = dir
	b.local = local
	b.ns = _ns
	if local and _player != null:
		b.exclude = [_player.get_rid()]
	b.position = pos
	add_child(b)





func _name_of(id: int) -> String:
	return str(Network.members.get(id, "Player"))


func _on_pvp_updated() -> void :
	if not bool(Network.pvp_alive.get(_my_id, true)) and not _dead and not _ended:
		_die()


func _die() -> void :
	_dead = true
	if _player != null:
		_player.input_locked = true
		_player.visible = false
	_center_label.add_theme_font_size_override("font_size", 24)
	_center_label.text = tr("YOU DIED - RESPAWNING ...")


func _on_respawn(id: int, spawn_index: int) -> void :
	if id != _my_id or _player == null or _ended:
		return
	_dead = false
	_player.global_position = SPAWNS[spawn_index % SPAWNS.size()]
	_player.velocity = Vector2.ZERO
	_player.visible = true
	_player.input_locked = false
	_center_label.text = ""


func _on_kill(killer: int, victim: int) -> void :
	_feed_label.text = "%s  >  %s" % [_name_of(killer), _name_of(victim)]
	_feed_t = 3.0


func _on_ended(winner: int) -> void :
	_ended = true
	_running = false
	if _player != null:
		_player.input_locked = true
	_center_label.text = ""
	_end_layer = CanvasLayer.new()
	_end_layer.layer = 50
	add_child(_end_layer)
	var center: = CenterContainer.new()
	_end_layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: = PanelContainer.new()
	center.add_child(panel)
	var margin: = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	var head: = tr("DRAW") if winner == 0 else tr("WINNER") + ": " + _name_of(winner)
	col.add_child(UI.label(head, 22, Color(1, 0.85, 0.3)))
	col.add_child(UI.label(_scoreboard_text(), 13, Color.WHITE, 380.0))
	var menu: = UI.button("MENU", 16, 46.0)
	menu.pressed.connect( func() -> void :
		Network.leave()
		get_tree().change_scene_to_file(MAIN_MENU))
	col.add_child(menu)
	if Network.is_room_host():
		var back: = UI.button("BACK TO LOBBY", 16, 46.0)
		back.pressed.connect(Network.request_rematch)
		col.add_child(back)


func _scoreboard_text() -> String:
	var rows: Array = []
	for id in Network.pvp_kills:
		rows.append({"id": int(id), "k": int(Network.pvp_kills[id]), "d": int(Network.pvp_deaths.get(id, 0))})
	rows.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a["k"]) > int(b["k"]))
	var out: = ""
	for r in rows:
		out += "%s   %d / %d\n" % [_name_of(int(r["id"])), int(r["k"]), int(r["d"])]
	return out



func hud_text() -> String:
	if not Network.in_room():
		return tr("PRACTICE - press F or FIRE to shoot")
	var t: = int(ceil(_time_left))
	var hp: = int(Network.pvp_hp.get(_my_id, Network.PVP_HP))
	var txt: = "PVP   %s %d:%02d   %s %d/%d   HP %d" % [
		tr("TIME"), t / 60, t % 60, tr("KILLS"), int(Network.pvp_kills.get(_my_id, 0)), Network.PVP_KILL_LIMIT, hp]
	var rows: Array = []
	for id in Network.pvp_kills:
		rows.append({"id": int(id), "k": int(Network.pvp_kills[id])})
	rows.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a["k"]) > int(b["k"]))
	for i in mini(rows.size(), 4):
		txt += "\n%d. %s  %d" % [i + 1, _name_of(int(rows[i]["id"])), int(rows[i]["k"])]
	return txt


func back_scene() -> String:
	return MAIN_MENU
