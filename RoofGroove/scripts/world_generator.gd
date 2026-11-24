extends Node2D














const TILE: = 16
const DEPTH: = 6
const HEIGHT_SAFETY: = 0.85
const ROW_MIN: = -8
const ROW_MAX: = 10
const CHECKPOINT_EVERY: = 5
const FONT: = preload("res://fonts/PixelOperator8.ttf")
const StoryData: = preload("res://scripts/story_data.gd")
const StoryState: = preload("res://scripts/story_state.gd")
const DialogueBox: = preload("res://scripts/dialogue_box.gd")
const Cutscene: = preload("res://scripts/cutscene.gd")
const StoryMonster: = preload("res://scripts/story_monster.gd")
const StoryArena: = preload("res://scripts/story_arena.gd")


const STORY_ORB_CHANCE: = 0.3


# Boss arenas: one every ARENA_EVERY checkpoints (change it to 100 for more, 200 for fewer).
# Each one is a bit harder than the last, and they alternate between the ground and space arena.
const ARENA_FIRST: = 150
const ARENA_EVERY: = 150
const ARENA_WINDOW: = 40  # an arena only opens within this many checkpoints after its checkpoint
const ARENA_GEMS: = 10  # gems for beating each arena
const StoryAlly: = preload("res://scripts/story_ally.gd")
const StoryTip: = preload("res://scripts/story_tip.gd")
const StoryPickup: = preload("res://scripts/story_pickup.gd")
const StoryEffects: = preload("res://scripts/story_effects.gd")
const StoryHud: = preload("res://scripts/story_hud.gd")
const StoryGun: = preload("res://scripts/story_gun.gd")
const StoryCheats: = preload("res://scripts/story_cheats.gd")
const PLAYER_SCRIPT_PATH: = "res://scripts/player.gd"
const TILESET_TEX: = preload("res://sprites/world_tileset.png")
const CLOUD_TEX: = preload("res://sprites/cloud_tileset.png")


const CLOUD_TINT: = {
	"Sunrise": Color(1.0, 0.9, 0.88), 
	"Morning": Color(1.0, 1.0, 1.0), 
	"Sunset": Color(1.0, 0.86, 0.78), 
	"Night": Color(0.62, 0.67, 0.88), 
}


const GRASS: = Vector2i(0, 0)
const DIRT: = Vector2i(0, 1)
const ROCKS: = [Vector2i(1, 0), Vector2i(1, 1)]
const BLOCKS: = [Vector2i(0, 2), Vector2i(1, 2)]


@export var endless: = true

@export var length_tiles: = 160

@export_range(0.0, 1.0) var difficulty: = 0.6

@export var ramp_tiles: = 500

@export var fixed_seed: = 1337

@export var build_ahead_tiles: = 90
@export var keep_behind_tiles: = 60
@export var player_path: NodePath = ^"player"

@export var spawn_marker_path: NodePath = ^"SpawnPoint"
@export var killzone_path: NodePath = ^"Killzone for world"
@export var finish_label_path: NodePath = ^"Label"

var _time_of_day: = "Morning"
var _rng: = RandomNumberGenerator.new()
var _seed: = 0
var _islands: Array = []
var _built: Dictionary = {}
var _layer: TileMapLayer
var _colliders: Node2D
var _player: Node2D
var _accum: = 0.0

var _speed: = 150.0
var _jump: = 200.0
var _gravity: = 900.0
var _tps: = 60.0
var _apex: = 0.0
var _max_up: = 0
var _safety_start: = 0.5
var _safety_end: = 0.8

var _gen_x: = 0
var _gen_row: = 0
var _gen_done: = false
var _spawn_pos: = Vector2.ZERO

var _cp: = 0
var _spawn_island: = 0
var _flag_polys: Dictionary = {}
var _toast_label: Label
var _chapters: Array = []
var _allies: Array = []
var _npcs: Dictionary = {}
var _tip: Node
var _ally_t: = 0.0
var _explain_cd: = 0.0
var _dialog_open: = false
var _arena_dismissed: Dictionary = {}
var _arena_open: = false
var _arena_t: = 0.0
var _last_story_push: = -100000
var _toast_tween: Tween




func _enter_tree() -> void :
	_read_player_physics()
	_seed = _get_seed()
	_rng.seed = _seed
	_max_up = _max_up_tiles()
	_safety_end = 0.55 + 0.35 * difficulty
	_safety_start = _safety_end * 0.7

	_islands.clear()
	_built.clear()
	_gen_done = false
	_add_island(0, 10, 0, DEPTH)
	_gen_x = 10
	_gen_row = 0


	_cp = 0
	var net: = get_node_or_null("/root/Network")
	if StoryState.active:
		StoryState.load_state()
		_cp = StoryState.story_cp
	elif net != null and net.has_method("resume_checkpoint"):
		_cp = int(net.call("resume_checkpoint", _seed))
	if endless:
		_extend_to_count(_cp * CHECKPOINT_EVERY + 1)
	else:
		_extend_to(length_tiles + 100)
	_spawn_island = mini(_cp * CHECKPOINT_EVERY, _islands.size() - 1)

	_place_nodes()
	print("[world] seed=%d endless=%s apex=%.1fpx max_up=%d tiles" % [_seed, str(endless), _apex, _max_up])


func _ready() -> void :
	if DayCycle:
		DayCycle.time_changed.connect( func(t): _time_of_day = t)
	_build_background()
	_build_layer()
	_build_toast()
	_start_music()
	_story_respawn_line()
	_story_spawn_allies()
	_update_window()


func _process(delta: float) -> void :
	_check_checkpoint()
	_story_tick(delta)
	_accum += delta
	if _accum >= 0.1:
		_accum = 0.0
		_update_window()



func get_spawn_position() -> Vector2:
	return to_global(_spawn_pos)


func _get_seed() -> int:
	if fixed_seed > 0:
		return fixed_seed
	var net: = get_node_or_null("/root/Network")
	if net != null and net.has_method("get_world_seed"):
		return int(net.call("get_world_seed"))
	var d: = Time.get_date_dict_from_system(true)
	return int(d["year"]) * 10000 + int(d["month"]) * 100 + int(d["day"])





func _read_player_physics() -> void :
	var player_script: Script = load(PLAYER_SCRIPT_PATH)
	var c: Dictionary = player_script.get_script_constant_map()
	_speed = absf(float(c.get("SPEED", 150.0)))
	_jump = absf(float(c.get("JUMP_FORCE", -200.0)))
	_gravity = absf(float(c.get("GRAVITY", 900.0)))
	_tps = float(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))
	_apex = _simulate_apex()



func _simulate_apex() -> float:
	var dt: = 1.0 / _tps
	var v: = _jump
	var y: = 0.0
	var best: = 0.0
	for i in 600:
		y += v * dt
		best = maxf(best, y)
		v -= _gravity * dt
		if v < 0.0 and y <= 0.0:
			break
	return best



func _reach(dy: float) -> float:
	if dy >= _apex:
		return 0.0
	var dt: = 1.0 / _tps
	var v: = _jump
	var y: = 0.0
	var t: = 0.0
	for i in 1200:
		y += v * dt
		t += dt
		v -= _gravity * dt
		if v < 0.0 and y <= dy:
			break
	return _speed * t


func _max_up_tiles() -> int:
	return int(floor(_apex * HEIGHT_SAFETY / TILE))



func _max_gap_tiles(dy_tiles: int, safety: float) -> int:
	var r: = snappedf(_reach(dy_tiles * TILE) * safety, 0.001)
	return maxi(int(floor(r / TILE)), 0)





func _progress(x: int) -> float:
	var total: = float(ramp_tiles if endless else length_tiles)
	return clampf(float(x) / maxf(total, 1.0), 0.0, 1.0)



func _extend_to(tx: int) -> void :
	while _gen_x < tx and not _gen_done:
		_generate_next()



func _extend_to_count(n: int) -> void :
	while _islands.size() < n and not _gen_done:
		_generate_next()


func _generate_next() -> void :
	var p: = _progress(_gen_x)
	var safety: = lerpf(_safety_start, _safety_end, p)
	var dy: = _pick_dy(_max_up, _gen_row)

	var gap: = 0
	var max_gap: = _max_gap_tiles(dy, safety)
	if max_gap >= 1:
		gap = _rng.randi_range(1, max_gap)

	var wmin: = int(lerpf(4.0, 2.0, p))
	var wmax: = int(lerpf(9.0, 4.0, p))
	var w: = _rng.randi_range(maxi(wmin, 2), maxi(wmax, 2))
	var thin: = p > 0.15 and _rng.randf() < 0.25
	if thin:
		w = _rng.randi_range(2, 3)



	if _islands.size() % CHECKPOINT_EVERY == 0:
		thin = false
		w = maxi(w, 6)


	if dy == 0 and gap == 0:
		gap = 1

	_gen_row -= dy
	_gen_x += gap
	_add_island(_gen_x, w, _gen_row, 1 if thin else DEPTH)
	_gen_x += w


	if not endless and _gen_x >= length_tiles:
		_gen_x += mini(2, _max_gap_tiles(0, _safety_start))
		_add_island(_gen_x, 16, _gen_row, DEPTH)
		_gen_x += 16
		_gen_done = true



func _pick_dy(max_up: int, row: int) -> int:
	var r: = _rng.randf()
	var dy: = 0
	if r < 0.4:
		dy = 0
	elif r < 0.65:
		dy = _rng.randi_range(1, max_up) if max_up >= 1 else 0
	else:
		dy = - _rng.randi_range(1, 3)
	var new_row: = row - dy
	if new_row < ROW_MIN or new_row > ROW_MAX:
		dy = clampi( - dy, -3, max_up)
		new_row = row - dy
		if new_row < ROW_MIN or new_row > ROW_MAX:
			dy = 0
	return dy


func _add_island(x0: int, w: int, row: int, depth: int) -> void :
	_islands.append({"x0": x0, "w": w, "x1": x0 + w, "row": row, "depth": depth})



func _hash01(x: int, d: int) -> float:
	var h: int = (x * 73856093) ^ (d * 19349663) ^ (_seed * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 65535) / 65536.0


func _atlas_for(tx: int, d: int) -> Vector2i:
	if d == 0:
		return GRASS
	if d == 1:
		if _hash01(tx, d) < 0.08:
			return BLOCKS[int(_hash01(tx, d + 100) * BLOCKS.size()) % BLOCKS.size()]
		return DIRT
	return ROCKS[(tx + d) % 2]



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





func _update_window() -> void :
	if _layer == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_node_or_null(player_path) as Node2D
		if _player == null:
			return

	var px: = floori(to_local(_player.global_position).x / TILE)
	var hi_x: = px + build_ahead_tiles
	var lo_x: = px - keep_behind_tiles

	if endless:
		_extend_to(hi_x + 30)

	var lo: = _first_ending_after(lo_x)
	var hi: = _last_starting_at_or_before(hi_x)

	for i in _built.keys():
		if i < lo or i > hi:
			_free_island(i)
	for i in range(lo, hi + 1):
		if not _built.has(i):
			_build_island(i)



func _first_ending_after(tx: int) -> int:
	var a: = 0
	var b: = _islands.size()
	while a < b:
		var m: = (a + b) >> 1
		if int(_islands[m]["x1"]) > tx:
			b = m
		else:
			a = m + 1
	return a



func _last_starting_at_or_before(tx: int) -> int:
	var a: = 0
	var b: = _islands.size()
	while a < b:
		var m: = (a + b) >> 1
		if int(_islands[m]["x0"]) > tx:
			b = m
		else:
			a = m + 1
	return a - 1


func _build_island(i: int) -> void :
	var isl: Dictionary = _islands[i]
	var x0: int = isl["x0"]
	var w: int = isl["w"]
	var row: int = isl["row"]
	var depth: int = isl["depth"]


	for cx in w:
		for d in depth:
			_layer.set_cell(Vector2i(x0 + cx, row + d), 0, _cloud_atlas(x0 + cx, cx, w, d, depth))


	var body: = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector2((x0 + w * 0.5) * TILE, (row + depth * 0.5) * TILE)
	var cs: = CollisionShape2D.new()
	var shape: = RectangleShape2D.new()
	shape.size = Vector2(w * TILE, depth * TILE)
	cs.shape = shape
	body.add_child(cs)
	if i > 0 and i % CHECKPOINT_EVERY == 0:
		_add_flag(body, i, w, depth)
		_add_story_npc(body, i, w, depth)
	elif StoryState.active:
		if i >= 3 and w >= 3 and _hash01(i, 913) < 0.3 + 0.4 * clampf(float(i) / 5000.0, 0.0, 1.0):
			_add_story_monster(body, i, w, depth)

		if i >= 4 and w >= 3 and _hash01(i, 421) < STORY_ORB_CHANCE:
			_add_story_pickup(body, i, w, depth)
	_colliders.add_child(body)
	_built[i] = body


func _free_island(i: int) -> void :
	var isl: Dictionary = _islands[i]
	var x0: int = isl["x0"]
	var w: int = isl["w"]
	var row: int = isl["row"]
	var depth: int = isl["depth"]
	for cx in w:
		for d in depth:
			_layer.erase_cell(Vector2i(x0 + cx, row + d))
	var body: Node = _built[i]
	if is_instance_valid(body):
		body.queue_free()
	_built.erase(i)
	_flag_polys.erase(i)





func _place_nodes() -> void :
	var start: Dictionary = _islands[_spawn_island]


	_spawn_pos = Vector2((int(start["x0"]) + int(start["w"]) * 0.5) * TILE, int(start["row"]) * TILE - 10.5)
	var marker: = get_node_or_null(spawn_marker_path) as Node2D
	if marker:
		marker.position = _spawn_pos
	var player: = get_node_or_null(player_path) as Node2D
	if player:
		player.position = _spawn_pos


	var label: = get_node_or_null(finish_label_path) as Control
	if label:
		if endless:

			label.visible = false
			label.position = Vector2(10000000.0, 0.0)
		else:
			var last: Dictionary = _islands[_islands.size() - 1]
			label.position = Vector2((int(last["x0"]) + 4) * TILE, int(last["row"]) * TILE - 40)


	var kz: = get_node_or_null(killzone_path) as Node2D
	if kz:
		var has_shape: = false
		for c in kz.get_children():
			if c is CollisionShape2D:
				has_shape = true
		if not has_shape:
			var cs: = CollisionShape2D.new()
			cs.shape = WorldBoundaryShape2D.new()
			kz.add_child(cs)
		kz.position = Vector2(0, (ROW_MAX + DEPTH + 5) * TILE)


func _build_background() -> void :

	add_child(preload("res://scripts/sky_background.gd").new())


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
	_layer.name = "GeneratedMap"
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


func _start_music() -> void :

	GameAudio.play_music()





func _add_flag(body: Node2D, i: int, w: int, depth: int) -> void :
	var flag: = Node2D.new()
	flag.position = Vector2((1.5 - w * 0.5) * TILE, - depth * TILE * 0.5)
	var pole: = Polygon2D.new()
	pole.polygon = PackedVector2Array([Vector2(-1, -28), Vector2(1, -28), Vector2(1, 0), Vector2(-1, 0)])
	pole.color = Color(0.85, 0.85, 0.85)
	flag.add_child(pole)
	var cloth: = Polygon2D.new()
	cloth.polygon = PackedVector2Array([Vector2(1, -28), Vector2(15, -21), Vector2(1, -14)])
	cloth.color = _flag_color(i)
	flag.add_child(cloth)
	body.add_child(flag)
	_flag_polys[i] = cloth



func _flag_color(i: int) -> Color:
	return Color(0.3, 0.9, 0.4) if i <= _cp * CHECKPOINT_EVERY else Color(0.55, 0.55, 0.6)


func _check_checkpoint() -> void :
	if _player == null or not is_instance_valid(_player):
		return
	var idx: = (_cp + 1) * CHECKPOINT_EVERY
	if idx >= _islands.size():
		return
	var isl: Dictionary = _islands[idx]
	var pos: = to_local(_player.global_position)
	var top: = int(isl["row"]) * TILE

	if pos.x >= int(isl["x0"]) * TILE and pos.x <= int(isl["x1"]) * TILE and pos.y <= top + 4 and pos.y >= top - 120:
		_reach_checkpoint(_cp + 1)


func _reach_checkpoint(n: int) -> void :
	if StoryState.active:
		_story_reach(n)
		return
	var net: = get_node_or_null("/root/Network")
	var old_best: = 0
	var tokens_before: int = Economy.earned
	if net != null:
		old_best = int(net.get("best_checkpoint"))

		if net.has_method("reach_checkpoint") and not bool(net.get("teleported_run")):
			net.call("reach_checkpoint", n, _seed)
	_cp = n
	GameAudio.play_sfx("power_up")
	var fp: Polygon2D = _flag_polys.get(n * CHECKPOINT_EVERY)
	if fp != null and is_instance_valid(fp):
		fp.color = _flag_color(n * CHECKPOINT_EVERY)

	var text: = tr("CHECKPOINT %d") % n
	if Economy.earned > tokens_before:
		text += "\n" + tr("+%d TOKENS") % (Economy.earned - tokens_before)
	var color: = Color(0.5, 1.0, 0.55)
	if net != null and net.has_method("rank_for"):
		var r_old: Dictionary = net.call("rank_for", old_best)
		var r_new: Dictionary = net.call("rank_for", maxi(old_best, n))
		if r_new["name"] != r_old["name"]:
			text += "\n" + tr("RANK UP: %s") % tr(str(r_new["name"])).to_upper()
			color = r_new["color"]
	_toast(text, color)
	if StoryState.active:
		_story_meet(n)





func _chapter_for_cp(n: int) -> Dictionary:
	if _chapters.is_empty():
		_chapters = StoryData.chapters()
	for ch in _chapters:
		if int(ch["cp"]) == n:
			return ch
	return {}


func _add_story_npc(body: Node2D, i: int, w: int, depth: int) -> void :
	if not StoryState.active:
		return
	var ch: = _chapter_for_cp(int(i / CHECKPOINT_EVERY))
	if ch.is_empty() or StoryState.has_seen(str(ch["id"])):
		return
	var spr: = AnimatedSprite2D.new()
	spr.sprite_frames = Economy.frames_for(str(ch["skin"]))
	spr.position = Vector2((1.5 - w * 0.5) * TILE + 30.0, - depth * TILE * 0.5 - 12.0)
	spr.flip_h = true
	spr.play("idle")
	body.add_child(spr)
	_npcs[int(ch["cp"])] = spr



func _story_monster_kind(i: int) -> String:
	var pool: Array[String] = ["slime"]
	if i >= 40:
		pool.append("bat")
	if i >= 80:
		pool.append("thorn")
	if i >= 150:
		pool.append("charger")
	if i >= 250:
		pool.append("jumper")
	return pool[int(_hash01(i, 55) * float(pool.size())) % pool.size()]


func _add_story_monster(body: Node2D, i: int, w: int, depth: int) -> void :
	var half: = w * TILE * 0.5 - 10.0
	if half < 6.0:
		return
	var m: = StoryMonster.new()
	m.kind = _story_monster_kind(i)
	m.origin_x = 0.0
	m.half = half
	m.speed_mult = 1.0 + 0.6 * clampf(float(i) / 5000.0, 0.0, 1.0)
	m.position = Vector2(lerpf( - half * 0.6, half * 0.6, _hash01(i, 77)), - depth * TILE * 0.5 - 7.0)
	body.add_child(m)


func _story_spawn_allies() -> void :
	if not StoryState.active:
		return
	StoryMonster.dying = false
	StoryMonster.shield_ready = false
	StoryEffects.clear()
	_tip = StoryTip.new()
	add_child(_tip)
	add_child(StoryHud.new())
	if StoryCheats.gun:
		add_child(StoryGun.new())
	if _chapters.is_empty():
		_chapters = StoryData.chapters()
	var here: = _cp * CHECKPOINT_EVERY
	for ch in _chapters:
		if bool(ch.get("final", false)) or not StoryState.has_seen(str(ch["id"])):
			continue
		var start: = int(ch["cp"]) * CHECKPOINT_EVERY
		var end: = start + StoryData.COMPANION_ISLANDS
		if start <= here and here < end:
			_spawn_ally(str(ch["skin"]), end)


func _spawn_ally(skin: String, end_island: int) -> void :
	var a: = StoryAlly.new()
	a.skin = skin
	a.end_island = end_island
	add_child(a)
	_allies.append(a)
	_reslot_allies()
	if skin == "fairy":
		StoryMonster.shield_ready = true


func _reslot_allies() -> void :
	for k in _allies.size():
		_allies[k].slot = k


func _story_tick(delta: float) -> void :
	if not StoryState.active:
		return
	StoryEffects.tick(delta)
	_story_explain_tick(delta)
	_story_arena_tick(delta)
	if _allies.is_empty() or _player == null or not is_instance_valid(_player):
		return
	_ally_t += delta
	if _ally_t < 0.5:
		return
	_ally_t = 0.0

	var cur: = _last_starting_at_or_before(floori(to_local(_player.global_position).x / TILE))
	for a in _allies.duplicate():
		if not is_instance_valid(a):
			_allies.erase(a)
			continue
		if cur >= a.end_island:
			_allies.erase(a)
			show_tip(a.skin, StoryData.pick(StoryData.farewell()))
			if a.skin == "fairy":
				StoryMonster.shield_ready = false
			a.depart()
	_reslot_allies()


func _story_arena_tick(delta: float) -> void :
	if _arena_open or _dialog_open:
		return
	_arena_t += delta
	if _arena_t < 1.0:
		return
	_arena_t = 0.0
	for a in _arenas():
		var start_cp: int = int(a["cp"])
		if _cp >= start_cp and _cp < start_cp + ARENA_WINDOW and not StoryState.has_seen(str(a["id"])):
			_open_arena(a)
			return


func _arenas() -> Array:
	var list: Array = []
	var cp: int = ARENA_FIRST
	var n: int = 1
	while cp < StoryData.FINAL_CP:
		list.append({"id": "arena_%d" % n, "cp": cp, "theme": "ground" if n % 2 == 1 else "space", "tokens": 20 + 5 * n, "level": n})
		cp += ARENA_EVERY
		n += 1
	return list


func _open_arena(a: Dictionary) -> void :
	_arena_open = true
	_dialog_open = true
	get_tree().paused = true
	var arena: = StoryArena.new()
	arena.theme_name = str(a["theme"])
	arena.level = int(a.get("level", 1))
	add_child(arena)
	arena.finished.connect(_on_arena_done.bind(a, arena))
	arena.start()


func _on_arena_done(won: bool, a: Dictionary, arena: Node) -> void :
	arena.queue_free()
	get_tree().paused = false
	_dialog_open = false
	_arena_open = false
	if won:
		StoryState.mark_seen(str(a["id"]))
		Economy.add_tokens(int(a["tokens"]))
		Economy.add_arena_gems(ARENA_GEMS)
		GameAudio.play_sfx("success")
		_toast(tr("+%d TOKENS") % int(a["tokens"]) + "   " + tr("+%d GEMS") % ARENA_GEMS, Color(1.0, 0.86, 0.4))


func show_tip(skin: String, text: String) -> void :
	if _tip != null and is_instance_valid(_tip):
		_tip.call("show_tip", skin, text)



func _story_explain_tick(delta: float) -> void :
	if _dialog_open or _player == null or not is_instance_valid(_player):
		return
	_explain_cd -= delta
	if _explain_cd > 0.0:
		return
	_explain_cd = 0.25
	var pp: Vector2 = _player.global_position
	for n in get_tree().get_nodes_in_group("monsters"):
		var kind: = str(n.get("kind"))
		if StoryState.has_seen("mon_" + kind):
			continue
		var d: Vector2 = n.global_position - pp
		if absf(d.x) < 190.0 and absf(d.y) < 90.0:
			StoryState.mark_seen("mon_" + kind)
			_open_dialogue(StoryData.monster_intro(kind), Callable())
			return
	if not StoryState.has_seen("orbs"):
		for n in get_tree().get_nodes_in_group("pickups"):
			var d: Vector2 = n.global_position - pp
			if absf(d.x) < 170.0 and absf(d.y) < 90.0:
				StoryState.mark_seen("orbs")
				_open_dialogue(StoryData.orb_intro(), Callable())
				return


func _open_dialogue(pages: Array, done: Callable) -> void :
	_dialog_open = true
	get_tree().paused = true
	var layer: = CanvasLayer.new()
	layer.layer = 12
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var box: = DialogueBox.new()
	box.show_portrait = true
	layer.add_child(box)
	box.finished.connect( func() -> void :
		layer.queue_free()
		get_tree().paused = false
		_dialog_open = false
		if done.is_valid():
			done.call())
	box.start(pages)


func _story_reach(n: int) -> void :
	_cp = n
	StoryState.set_cp(n)
	var net: = get_node_or_null("/root/Network")
	if net != null and net.get("cloud") != null and Time.get_ticks_msec() - _last_story_push > 20000:
		_last_story_push = Time.get_ticks_msec()
		net.cloud.push_now()
	GameAudio.play_sfx("power_up")
	var fp: Polygon2D = _flag_polys.get(n * CHECKPOINT_EVERY)
	if fp != null and is_instance_valid(fp):
		fp.color = _flag_color(n * CHECKPOINT_EVERY)
	_toast(tr("CHECKPOINT %d") % n + " / %d" % StoryData.FINAL_CP, Color(0.5, 1.0, 0.55))
	_story_meet(n)


func _story_meet(n: int) -> void :
	var ch: = _chapter_for_cp(n)
	if ch.is_empty() or StoryState.has_seen(str(ch["id"])):
		return
	StoryState.mark_seen(str(ch["id"]))
	_open_dialogue(ch["pages"], _on_chapter_done.bind(ch))


func _on_chapter_done(ch: Dictionary) -> void :
	Economy.add_tokens(StoryData.CHAPTER_TOKENS)
	var msg: = ""
	if not bool(ch.get("final", false)):
		_spawn_ally(str(ch["skin"]), int(ch["cp"]) * CHECKPOINT_EVERY + StoryData.COMPANION_ISLANDS)
		msg = tr("%s JOINS YOU!") % StoryData.speaker_name(str(ch["skin"])).to_upper()
		var npc: Variant = _npcs.get(int(ch["cp"]))
		if npc != null and is_instance_valid(npc):
			var tw: = create_tween()
			tw.tween_property(npc, "modulate:a", 0.0, 0.6)
			tw.tween_callback(npc.queue_free)
	if bool(ch.get("note", false)):
		var got: = StoryState.notes(_chapters)
		msg += ("\n" if msg != "" else "") + tr("NOTE %d / %d") % [got, StoryData.NOTES_TOTAL]
	if msg != "":
		_toast(msg + "\n" + tr("+%d TOKENS") % StoryData.CHAPTER_TOKENS, Color(1.0, 0.86, 0.4))
	if bool(ch.get("final", false)):
		StoryState.mark_finished()
		Economy.add_tokens(StoryData.FINALE_TOKENS)
		StoryState.reset_run()
		StoryState.active = false
		Cutscene.play(get_tree(), StoryData.ending(), "res://sence/main_menu.tscn")



func _add_story_pickup(body: Node2D, i: int, w: int, depth: int) -> void :
	var kinds: = ["jump", "slow", "speed", "weak", "float", "heavy"]
	var p: = StoryPickup.new()
	p.kind = str(kinds[int(_hash01(i, 88) * 6.0) % 6])
	var half: = w * TILE * 0.5 - 14.0
	p.position = Vector2(lerpf( - half * 0.5, half * 0.5, _hash01(i, 99)), - depth * TILE * 0.5 - 32.0)
	p.collected.connect(_on_orb)
	body.add_child(p)


func _on_orb(kind: String) -> void :
	var good: = bool(StoryEffects.DEFS[kind]["good"])
	_toast("%s  %ds" % [StoryData.effect_name(kind), int(StoryEffects.DEFS[kind]["dur"])], 
		Color(0.55, 1.0, 0.65) if good else Color(1.0, 0.45, 0.45))



func god_rescue() -> void :
	if _player == null or not is_instance_valid(_player):
		return
	var idx: = mini(_cp * CHECKPOINT_EVERY, _islands.size() - 1)
	var isl: Dictionary = _islands[idx]
	_player.position = Vector2((int(isl["x0"]) + int(isl["w"]) * 0.5) * TILE, int(isl["row"]) * TILE - 10.5)
	_player.set("velocity", Vector2.ZERO)


func _story_respawn_line() -> void :
	if not StoryState.active or not StoryState.respawning:
		return
	StoryState.respawning = false
	var lines: = StoryData.respawn_lines()
	_toast(StoryData.pick(lines[randi() % lines.size()]), Color(0.7, 0.9, 1.0))






func teleport_to_checkpoint(n: int) -> void :
	if StoryState.active:
		return
	var idx: = maxi(n, 0) * CHECKPOINT_EVERY
	if endless:
		_extend_to_count(idx + 1)
	idx = clampi(idx, 0, _islands.size() - 1)
	var cp: = floori(float(idx) / CHECKPOINT_EVERY)
	var isl: Dictionary = _islands[idx]
	var pos: = Vector2((int(isl["x0"]) + int(isl["w"]) * 0.5) * TILE, int(isl["row"]) * TILE - 10.5)
	_move_player_to(to_global(pos))
	_cp = cp
	_save_resume_point(cp)
	_recolor_flags()
	_toast(tr("TELEPORTED"), Color(0.6, 0.85, 1.0))



func teleport_to_position(gpos: Vector2) -> void :
	if StoryState.active:
		return
	var tx: = floori(to_local(gpos).x / TILE)
	if endless:
		_extend_to(tx + build_ahead_tiles + 30)
	_move_player_to(gpos + Vector2(0, -4))

	var dest_island: = clampi(_first_ending_after(tx), 0, _islands.size() - 1)
	var dest_cp: = floori(float(dest_island) / CHECKPOINT_EVERY)
	var net: = get_node_or_null("/root/Network")
	var best: = 0
	if net != null:
		best = int(net.get("best_checkpoint"))
	var beyond: = dest_cp > best
	if beyond and net != null:
		net.set("teleported_run", true)
	if dest_cp > _cp:
		_cp = dest_cp
		if not beyond:
			_save_resume_point(dest_cp)
		_recolor_flags()
	if beyond:
		_toast(tr("TELEPORTED - progress and time will not be saved"), Color(1.0, 0.8, 0.4))
	else:
		_toast(tr("TELEPORTED"), Color(0.6, 0.85, 1.0))


func _save_resume_point(cp: int) -> void :
	var net: = get_node_or_null("/root/Network")
	if net == null:
		return
	net.set("checkpoint", cp)
	net.set("checkpoint_seed", _seed)
	if net.has_method("save_cfg"):
		net.call("save_cfg")


func _move_player_to(gpos: Vector2) -> void :
	if _player == null or not is_instance_valid(_player):
		_player = get_node_or_null(player_path) as Node2D
	if _player == null:
		return
	_player.global_position = gpos
	if _player is CharacterBody2D:
		(_player as CharacterBody2D).velocity = Vector2.ZERO
	_update_window()
	var cam: = _player.get_node_or_null("Camera2D")
	if cam != null and cam.has_method("reset_smoothing"):
		cam.call("reset_smoothing")


func _recolor_flags() -> void :
	for i in _flag_polys.keys():
		var fp = _flag_polys[i]
		if fp != null and is_instance_valid(fp):
			fp.color = _flag_color(i)


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
