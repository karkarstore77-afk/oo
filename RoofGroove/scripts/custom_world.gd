extends Node2D






const WorldData: = preload("res://scripts/world_data.gd")
const StoryMonster: = preload("res://scripts/story_monster.gd")
const SCENE: = "res://sence/custom_world.tscn"
const TILE: = 16
const DEPTH: = 6
const FONT: = preload("res://fonts/PixelOperator8.ttf")
const CLOUD_TEX: = preload("res://sprites/cloud_tileset.png")
const CLOUD_TINT: = {
	"Sunrise": Color(1.0, 0.9, 0.88), 
	"Morning": Color(1.0, 1.0, 1.0), 
	"Sunset": Color(1.0, 0.86, 0.78), 
	"Night": Color(0.62, 0.67, 0.88), 
}

static var current: Dictionary = {}
static var title: = ""
static var back_to: = "res://sence/worlds_menu.tscn"
static var test_mode: = false
static var race: = false
static var race_started: = false
static var test_finished: = false
static var last_cp: = -1
static var reached: Array = []
static var _key: = ""

var _layer: TileMapLayer
var _colliders: Node2D
var _player: Node2D
var _flag_polys: Dictionary = {}
var _toast_label: Label
var _toast_tween: Tween
var _finish_area: Area2D
var _race_label: Label
var _race_panel: CanvasLayer
var _race_lobby_btn: Button
var _race_waited: = 0.0



static func setup(world: Dictionary, world_title: String, back_scene: String, test: bool, race_mode: bool = false) -> void :
	current = world
	title = world_title
	back_to = back_scene
	test_mode = test
	test_finished = false
	race = race_mode
	race_started = false
	_key = ""


static func play(tree: SceneTree, world: Dictionary, world_title: String, back_scene: String, test: bool = false, race_mode: bool = false) -> void :
	setup(world, world_title, back_scene, test, race_mode)
	SceneTransition.go(SCENE)


func _enter_tree() -> void :
	if current.is_empty():
		current = WorldData.empty_world()
	var key: = WorldData.content_hash(current)
	if key != _key:
		_key = key
		last_cp = -1
		reached = []

	var islands: Array = current["islands"]
	var spawn_i: int = last_cp if last_cp >= 0 else int(current["start"])
	var s: Dictionary = islands[spawn_i]
	var spawn: = Vector2((int(s["x"]) + int(s["w"]) * 0.5) * TILE, int(s["y"]) * TILE - 10.5)
	_player = get_node_or_null("player") as Node2D
	if _player:
		_player.position = spawn
	var label: = get_node_or_null("Label") as Control
	if label:
		label.visible = false
		label.position = Vector2(10000000.0, 0.0)
	var low: = 0
	for isl in islands:
		low = maxi(low, int(isl["y"]))
	var kz: = get_node_or_null("Killzone for world") as Node2D
	if kz:
		kz.position = Vector2(0, (low + DEPTH + 8) * TILE)


func _ready() -> void :
	add_child(preload("res://scripts/sky_background.gd").new())
	_build_layer()
	_build_islands()
	_build_toast()
	GameAudio.play_music()
	if race:
		_race_setup()


func _process(delta: float) -> void :
	if race and not race_started and _race_label != null:
		_race_waited += delta
		if _race_waited > 14.0 and not _race_counting:
			_race_begin()
	if _player == null or not is_instance_valid(_player):
		return
	var islands: Array = current["islands"]
	var pos: = to_local(_player.global_position)
	for i in current["checkpoints"]:
		if reached.has(i) or i == int(current["start"]):
			continue
		var isl: Dictionary = islands[i]
		var top: = int(isl["y"]) * TILE
		if pos.x >= int(isl["x"]) * TILE and pos.x <= (int(isl["x"]) + int(isl["w"])) * TILE and pos.y <= top + 4 and pos.y >= top - 120:
			_reach(i)


func _reach(i: int) -> void :
	reached.append(i)
	last_cp = i
	GameAudio.play_sfx("power_up")
	var fp: Polygon2D = _flag_polys.get(i)
	if fp != null and is_instance_valid(fp):
		fp.color = Color(0.3, 0.9, 0.4)
	_toast(tr("CHECKPOINT %d") % (reached.size()), Color(0.5, 1.0, 0.55))





func _hash01(x: int, d: int) -> float:
	var h: int = (x * 73856093) ^ (d * 19349663) ^ (1337 * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 65535) / 65536.0


func _cloud_atlas(tx: int, cx: int, w: int, d: int, depth: int) -> Vector2i:
	var col: = 1
	if cx == 0:
		col = 0
	elif cx == w - 1:
		col = 2
	elif _hash01(tx, d + 7) < 0.5:
		col = 3
	var row: = 6
	if depth > 1:
		if d == 0:
			row = 0
		elif d == depth - 1:
			row = 5
		else:
			row = 1 + mini(d - 1, 3)
	return Vector2i(col, row)


func _build_layer() -> void :
	var ts: = TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src: = TileSetAtlasSource.new()
	src.texture = CLOUD_TEX
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	for cx in 4:
		for cy in 7:
			src.create_tile(Vector2i(cx, cy))
	_layer = TileMapLayer.new()
	_layer.name = "CustomMap"
	_layer.tile_set = ts
	add_child(_layer)
	move_child(_layer, 0)
	_layer.modulate = CLOUD_TINT.get(DayCycle.get_time_name(), Color.WHITE)
	DayCycle.time_changed.connect(_tint_clouds)
	_colliders = Node2D.new()
	_colliders.name = "Colliders"
	add_child(_colliders)
	move_child(_colliders, 1)


func _tint_clouds(time_name: String) -> void :
	if _layer == null or not is_instance_valid(_layer):
		return
	var tw: = create_tween()
	tw.tween_property(_layer, "modulate", CLOUD_TINT.get(time_name, Color.WHITE), 1.5)


func _build_islands() -> void :
	var islands: Array = current["islands"]
	var bodies: Array = []
	for i in islands.size():
		var isl: Dictionary = islands[i]
		var x0: int = isl["x"]
		var w: int = isl["w"]
		var row: int = isl["y"]
		for cx in w:
			for d in DEPTH:
				_layer.set_cell(Vector2i(x0 + cx, row + d), 0, _cloud_atlas(x0 + cx, cx, w, d, DEPTH))
		var body: = StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = Vector2((x0 + w * 0.5) * TILE, (row + DEPTH * 0.5) * TILE)
		var cs: = CollisionShape2D.new()
		var shape: = RectangleShape2D.new()
		shape.size = Vector2(w * TILE, DEPTH * TILE)
		cs.shape = shape
		body.add_child(cs)
		_colliders.add_child(body)
		bodies.append(body)

	for i in current["checkpoints"]:
		if i != int(current["start"]):
			_add_flag(bodies[i], i, int(islands[i]["w"]), Color(0.3, 0.9, 0.4) if reached.has(i) else Color(0.55, 0.55, 0.6), true)
	var fin: int = current["finish"]
	if fin >= 0:
		_add_flag(bodies[fin], fin, int(islands[fin]["w"]), Color(1.0, 0.82, 0.2), false)
		_add_finish_area(islands[fin])

	for m in current["monsters"]:
		var i: int = m["i"]
		var half: = int(islands[i]["w"]) * TILE * 0.5 - 10.0
		if half < 6.0:
			continue
		var mon: = StoryMonster.new()
		mon.kind = str(m["t"])
		mon.origin_x = 0.0
		mon.half = half
		mon.speed_mult = 1.0
		mon.position = Vector2(float(m["o"]) * half * 0.8, - DEPTH * TILE * 0.5 - 7.0)
		bodies[i].add_child(mon)


func _add_flag(body: Node2D, i: int, w: int, color: Color, track: bool) -> void :
	var flag: = Node2D.new()
	flag.position = Vector2((1.5 - w * 0.5) * TILE, - DEPTH * TILE * 0.5)
	var pole: = Polygon2D.new()
	pole.polygon = PackedVector2Array([Vector2(-1, -28), Vector2(1, -28), Vector2(1, 0), Vector2(-1, 0)])
	pole.color = Color(0.85, 0.85, 0.85)
	flag.add_child(pole)
	var cloth: = Polygon2D.new()
	cloth.polygon = PackedVector2Array([Vector2(1, -28), Vector2(15, -21), Vector2(1, -14)])
	cloth.color = color
	flag.add_child(cloth)
	if not track:
		var lab: = Label.new()
		lab.text = "FINISH"
		lab.add_theme_font_override("font", FONT)
		lab.add_theme_font_size_override("font_size", 8)
		lab.position = Vector2(-16, -42)
		flag.add_child(lab)
	body.add_child(flag)
	if track:
		_flag_polys[i] = cloth



func _add_finish_area(isl: Dictionary) -> void :
	_finish_area = Area2D.new()
	_finish_area.position = Vector2((int(isl["x"]) + int(isl["w"]) * 0.5) * TILE, int(isl["y"]) * TILE - 28.0)
	var cs: = CollisionShape2D.new()
	var rect: = RectangleShape2D.new()
	rect.size = Vector2(int(isl["w"]) * TILE, 56.0)
	cs.shape = rect
	_finish_area.add_child(cs)
	_finish_area.body_entered.connect(_on_finish_body)
	add_child(_finish_area)


func _on_finish_body(body: Node) -> void :
	if not body.is_in_group("local_player"):
		return
	var ns: = get_node_or_null("NetSession")
	if ns != null and ns.has_method("trigger_finish"):
		ns.call("trigger_finish", body)





func hud_text() -> String:
	if race:
		return _race_hud()
	var cps: int = (current["checkpoints"] as Array).size()
	var txt: = "%s\n%s %d/%d   %s %s   %s %d" % [
		title, tr("CHECKPOINT"), reached.size(), cps, 
		tr("TIME"), Network.format_time(Network.run_time), tr("DEATHS"), Network.deaths]
	if Network.in_room():
		txt += "\n" + tr("%s   PLAYERS %d") % [Network.display_code(Network.invite_code), Network.members.size()]
	return txt



func on_finished(t: float) -> String:
	if race:
		if Network.in_room():
			Network.send_race_done(t)
			_race_show_panel()
			return tr("WAITING FOR RESULTS ...")
		return tr("RACE COMPLETE")
	if test_mode:
		test_finished = true
		return tr("TEST PASSED - you can publish this world")
	return tr("WORLD COMPLETE")


func back_scene() -> String:
	return back_to





func _build_toast() -> void :
	var layer: = CanvasLayer.new()
	layer.layer = 11
	add_child(layer)
	_toast_label = Label.new()
	_toast_label.add_theme_font_override("font", FONT)
	_toast_label.add_theme_font_size_override("font_size", 20)
	_toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast_label.add_theme_constant_override("outline_size", 6)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.modulate.a = 0.0
	layer.add_child(_toast_label)
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast_label.offset_top = 60
	_toast_label.offset_bottom = 130


func _toast(text: String, color: Color) -> void :
	if _toast_label == null:
		return
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", color)
	_toast_label.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.6)





var _race_counting: = false


func _race_setup() -> void :
	if race_started:
		return
	if _player != null:
		_player.set("input_locked", true)
	var layer: = CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_race_label = Label.new()
	_race_label.add_theme_font_override("font", FONT)
	_race_label.add_theme_font_size_override("font_size", 56)
	_race_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_race_label.add_theme_constant_override("outline_size", 12)
	_race_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_race_label.text = tr("WAITING FOR PLAYERS ...")
	_race_label.add_theme_font_size_override("font_size", 22)
	layer.add_child(_race_label)
	_race_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_race_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	if Network.in_room():
		Network.go_received.connect(_race_begin, CONNECT_ONE_SHOT)
		Network.send_ready()
	else:
		_race_begin()


func _race_begin() -> void :
	if _race_counting or race_started:
		return
	_race_counting = true
	_race_label.add_theme_font_size_override("font_size", 56)
	for n in ["3", "2", "1"]:
		_race_label.text = n
		await get_tree().create_timer(0.8).timeout
		if not is_inside_tree():
			return
	_race_label.text = tr("GO!")
	race_started = true
	Network.run_time = 0.0
	if _player != null and is_instance_valid(_player):
		_player.set("input_locked", false)
	await get_tree().create_timer(0.7).timeout
	if is_inside_tree() and _race_label != null:
		_race_label.text = ""


func _race_players() -> Array:

	var out: Array = []
	var my_id: = multiplayer.get_unique_id()
	var done: = {}
	for r in Network.race_results:
		done[int(r["id"])] = int(r["place"])
	var ns: = get_node_or_null("NetSession")
	var others: Dictionary = {}
	if ns != null and ns.has_method("get_player_positions"):
		others = ns.call("get_player_positions")
	var lx: = _player.global_position.x if _player != null and is_instance_valid(_player) else 0.0
	out.append({"id": my_id, "x": lx, "place": int(done.get(my_id, 0))})
	for id in others:
		out.append({"id": int(id), "x": (others[id] as Vector2).x, "place": int(done.get(int(id), 0))})
	return out


func _race_rank_of_me() -> int:
	var my_id: = multiplayer.get_unique_id()
	var players: = _race_players()
	var me: Dictionary = {}
	for p in players:
		if int(p["id"]) == my_id:
			me = p
	if int(me.get("place", 0)) > 0:
		return int(me["place"])
	var ahead: = 0
	for p in players:
		if int(p["id"]) == my_id:
			continue
		if int(p["place"]) > 0 or float(p["x"]) > float(me.get("x", 0.0)):
			ahead += 1
	return ahead + 1


func _race_hud() -> String:
	var n: = maxi(1, Network.members.size()) if Network.in_room() else 1
	return "%s\n%s %d/%d   %s %s   %s %d" % [
		title, tr("POSITION"), _race_rank_of_me(), n, 
		tr("TIME"), Network.format_time(Network.run_time), tr("DEATHS"), Network.deaths]


func _race_show_panel() -> void :
	if not Network.race_done.is_connected(_race_refresh_panel):
		Network.race_done.connect(_race_refresh_panel)
	if not Network.lobby_requested.is_connected(_race_to_lobby):
		Network.lobby_requested.connect(_race_to_lobby)
	if Network.is_room_host() and _race_lobby_btn == null:
		_race_panel = CanvasLayer.new()
		_race_panel.layer = 40
		add_child(_race_panel)
		_race_lobby_btn = Button.new()
		_race_lobby_btn.text = tr("BACK TO LOBBY")
		_race_lobby_btn.pressed.connect(Network.request_rematch)
		_race_panel.add_child(_race_lobby_btn)
		_race_lobby_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		_race_lobby_btn.offset_left = -200
		_race_lobby_btn.offset_top = -60
		_race_lobby_btn.offset_right = -16
		_race_lobby_btn.offset_bottom = -16
	_race_refresh_panel(0, 0, 0.0)


func _race_refresh_panel(_id: int, _place: int, _t: float) -> void :
	var ns: = get_node_or_null("NetSession")
	if ns == null:
		return
	var lines: = ""
	for r in Network.race_results:
		lines += "%d. %s   %s\n" % [int(r["place"]), str(Network.members.get(int(r["id"]), "Player")), Network.format_time(float(r["time"]))]
	ns.set("_rank_line", tr("RACE RESULTS") + "\n" + lines)
	ns.set("_top_lines", "")
	var pl: Label = ns.get("_panel_label")
	if pl != null:
		pl.text = str(ns.call("_panel_text", Network.run_time))


func _race_to_lobby() -> void :
	SceneTransition.go("res://sence/lobby_preview.tscn")
