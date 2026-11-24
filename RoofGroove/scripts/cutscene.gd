extends Control







const SCENE_PATH: = "res://sence/cutscene.tscn"
const SkyScript: = preload("res://scripts/sky_background.gd")
const DialogueBox: = preload("res://scripts/dialogue_box.gd")
const StoryData: = preload("res://scripts/story_data.gd")
const TIME_IDX: = {"Sunrise": 0, "Morning": 1, "Sunset": 2, "Night": 3}

static var pending_pages: Array = []
static var pending_next: = "res://sence/main_menu.tscn"

var _vp: = Vector2(1152, 648)
var _px: = 4.0
var _cam: Camera2D
var _stage: Node2D
var _main_island: RoofIsland
var _far: Array = []
var _flag: Node2D
var _cloth: Polygon2D
var _actors: Dictionary = {}
var _cast_keys: Array = []
var _ghost: AnimatedSprite2D
var _flash: ColorRect
var _fade: ColorRect
var _box: Control
var _shake: = 0.0
var _spread: = 0.0
var _bob: = 0.0
var _last_time: = ""
var _leaving: = false



class RoofIsland extends Node2D:
	var w: = 320.0
	var h: = 120.0
	var px: = 4.0
	var tint: = Color.WHITE
	var has_house: = false
	var house_x: = 0.0
	var house_unit: = 8.0
	var roof_color: = Color(0.78, 0.3, 0.28)

	func _draw() -> void :
		var rows: = int(h / px)
		var col_top: = Color(0.98, 0.99, 1.0) * tint
		var col_bot: = Color(0.6, 0.72, 0.95) * tint
		var edge: = Color(0.22, 0.34, 0.66) * tint

		if has_house:
			var u: = house_unit
			var wall_w: = 8.0 * u
			var wall_h: = 6.0 * u
			var wall: = Color(0.86, 0.66, 0.46) * tint
			var shade: = Color(0.66, 0.46, 0.32) * tint
			var glow: = Color(1.0, 0.88, 0.5)
			draw_rect(Rect2(house_x - wall_w * 0.5, - wall_h, wall_w, wall_h), wall)
			draw_rect(Rect2(house_x - wall_w * 0.5, - wall_h, wall_w, u * 0.5), shade)
			draw_rect(Rect2(house_x - u, -2.5 * u, 2.0 * u, 2.5 * u), Color(0.35, 0.2, 0.15) * tint)
			draw_rect(Rect2(house_x + 2.0 * u, -4.5 * u, 1.5 * u, 1.5 * u), glow)
			draw_rect(Rect2(house_x - 3.5 * u, -4.5 * u, 1.5 * u, 1.5 * u), glow)
			for i in 5:
				var rw: = wall_w + 2.0 * u - float(i) * 2.0 * u
				draw_rect(Rect2(house_x - rw * 0.5, - wall_h - float(i + 1) * u, rw, u), roof_color * tint)

		for r in rows:
			var inset: = maxf(0.0, float(r - 1)) * px
			var rw2: = w - inset * 2.0
			if rw2 < px * 2.0:
				break
			var t: = float(r) / maxf(1.0, float(rows - 1))
			var x0: = - rw2 * 0.5
			var y0: = float(r) * px
			draw_rect(Rect2(x0, y0, rw2, px), edge if r == 0 else col_top.lerp(col_bot, t))
			draw_rect(Rect2(x0, y0, px, px), edge)
			draw_rect(Rect2(x0 + rw2 - px, y0, px, px), edge)


func _ready() -> void :
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Engine.time_scale = 1.0
	get_tree().paused = false
	if pending_pages.is_empty():
		_leave_now.call_deferred()
		return
	DayCycle.frozen = true

	add_child(SkyScript.new())
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()

	var stage_layer: = CanvasLayer.new()
	stage_layer.layer = 2
	add_child(stage_layer)
	_stage = Node2D.new()
	stage_layer.add_child(_stage)
	_build_stage()

	var fx_layer: = CanvasLayer.new()
	fx_layer.layer = 9
	add_child(fx_layer)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.7)

	get_viewport().size_changed.connect(_layout)
	_layout()

	var ui_layer: = CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	_box = DialogueBox.new()
	ui_layer.add_child(_box)
	_box.page_shown.connect(_on_page)
	_box.finished.connect(_leave)
	_box.start(pending_pages)
	GameAudio.play_music()


func _exit_tree() -> void :
	DayCycle.frozen = false





func _build_stage() -> void :

	var defs: = [
		{"fx": 0.1, "fy": 0.3, "w": 0.16, "house": true}, 
		{"fx": 0.9, "fy": 0.24, "w": 0.2, "house": true}, 
		{"fx": 0.3, "fy": 0.13, "w": 0.1, "house": false}, 
		{"fx": 0.7, "fy": 0.1, "w": 0.12, "house": true}, 
		{"fx": 0.5, "fy": 0.34, "w": 0.09, "house": false}, 
	]
	for i in defs.size():
		var d: Dictionary = defs[i]
		var isl: = RoofIsland.new()
		isl.tint = Color(0.88, 0.92, 1.0)
		isl.has_house = bool(d["house"])
		isl.roof_color = [Color(0.78, 0.3, 0.28), Color(0.3, 0.55, 0.78), Color(0.55, 0.72, 0.36)][i % 3]
		_stage.add_child(isl)
		_far.append({"node": isl, "fx": float(d["fx"]), "fy": float(d["fy"]), "w": float(d["w"]), "phase": float(i) * 1.7})


	_main_island = RoofIsland.new()
	_main_island.has_house = true
	_stage.add_child(_main_island)

	_flag = Node2D.new()
	var pole: = Polygon2D.new()
	pole.polygon = PackedVector2Array([Vector2(-1, -28), Vector2(1, -28), Vector2(1, 0), Vector2(-1, 0)])
	pole.color = Color(0.88, 0.88, 0.9)
	_flag.add_child(pole)
	_cloth = Polygon2D.new()
	_cloth.polygon = PackedVector2Array([Vector2(1, -28), Vector2(15, -21), Vector2(1, -14)])
	_cloth.color = Color(0.55, 0.55, 0.62)
	_flag.add_child(_cloth)
	_stage.add_child(_flag)


func _char_scale() -> float:
	return clampf(minf(_vp.y * 0.0105, _vp.x * 0.0058), 2.5, 10.0)


func _ground() -> float:
	return _vp.y * 0.6


func _layout() -> void :
	_vp = get_viewport_rect().size
	_px = maxf(2.0, roundf(_vp.y / 150.0))
	var s: = _char_scale()
	var iw: = minf(_vp.x * 0.72, _vp.y * 1.15)

	_main_island.px = _px
	_main_island.w = iw
	_main_island.h = _vp.y * 0.32
	_main_island.house_unit = maxf(2.0, s * 0.55)
	_main_island.house_x = iw * 0.36
	_main_island.position = Vector2(_vp.x * 0.5, _ground())
	_main_island.queue_redraw()

	_flag.position = Vector2(_vp.x * 0.5 - iw * 0.4, _ground())
	_flag.scale = Vector2(s * 0.55, s * 0.55)

	for e in _far:
		var isl: RoofIsland = e["node"]
		isl.px = maxf(2.0, _px * 0.75)
		isl.w = _vp.x * float(e["w"])
		isl.h = _vp.y * 0.11
		isl.house_unit = maxf(1.5, s * 0.25)
		isl.house_x = isl.w * 0.12
		isl.queue_redraw()
	_place_far()

	var n: = _cast_keys.size()
	for i in n:
		var spr: AnimatedSprite2D = _actors.get(str(_cast_keys[i]))
		if spr != null and is_instance_valid(spr):
			_place_actor(spr, i, n)


func _place_far() -> void :
	for e in _far:
		var isl: RoofIsland = e["node"]
		var base: = Vector2(_vp.x * float(e["fx"]), _vp.y * float(e["fy"]))
		var dir: = (Vector2(float(e["fx"]) - 0.5, float(e["fy"]) - 0.3)).normalized()
		var bob: = sin(_bob * 0.8 + float(e["phase"])) * _vp.y * 0.008
		isl.position = base + dir * _spread * _vp.x * 0.3 + Vector2(0, bob)


func _slot_fraction(i: int, n: int) -> float:
	match n:
		1:
			return 0.5
		2:
			return [0.38, 0.62][i]
		3:
			return [0.28, 0.5, 0.72][i]
	return [0.2, 0.4, 0.6, 0.8][mini(i, 3)]


func _place_actor(spr: AnimatedSprite2D, i: int, n: int) -> void :
	var s: = _char_scale()
	var x: = _vp.x * _slot_fraction(i, n)
	spr.scale = Vector2(s, s)
	spr.position = Vector2(x, _ground() - 12.0 * s)
	spr.flip_h = n > 1 and x > _vp.x * 0.5 + 1.0


func _process(delta: float) -> void :
	if _cam == null:
		return
	_cam.position.x += 14.0 * delta
	_bob += delta
	_place_far()
	if _shake > 0.05:
		_stage.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		_shake = move_toward(_shake, 0.0, 26.0 * delta)
	elif _stage.position != Vector2.ZERO:
		_stage.position = Vector2.ZERO





func _on_page(_i: int, page: Dictionary) -> void :
	var t: = str(page.get("time", ""))
	if t != "" and t != _last_time and TIME_IDX.has(t):
		_last_time = t
		DayCycle.set_time_of_day(int(TIME_IDX[t]))
	var fx: = str(page.get("fx", ""))
	if page.has("cast"):
		_set_cast(page["cast"], fx)
	match fx:
		"flash":
			_flash_screen(0.9)
		"shake":
			_shake = 10.0
			_tween_spread(1.0)
		"gather":
			_shake = 6.0
			_tween_spread(-0.35)
		"flag":
			_flag_glow()


func _set_cast(cast: Array, fx: String) -> void :
	for key in _actors.keys():
		if not cast.has(key):
			var old: AnimatedSprite2D = _actors[key]
			_actors.erase(key)
			var tw: = create_tween()
			tw.tween_property(old, "modulate:a", 0.0, 0.25)
			tw.tween_callback(old.queue_free)
	_cast_keys = cast.duplicate()
	var n: = cast.size()
	for i in n:
		var key: = str(cast[i])
		var spr: AnimatedSprite2D = _actors.get(key)
		var is_new: = spr == null
		if is_new:
			spr = AnimatedSprite2D.new()
			spr.sprite_frames = Economy.frames_for(StoryData.skin_for(key))
			spr.play("idle")
			spr.modulate.a = 0.0
			_stage.add_child(spr)
			_actors[key] = spr
		_place_actor(spr, i, n)
		if is_new:
			if key == "hero" and fx == "fall":
				_do_fall(spr)
			else:
				create_tween().tween_property(spr, "modulate:a", 1.0, 0.3)


func _do_fall(spr: AnimatedSprite2D) -> void :
	var target: = spr.position
	spr.position = Vector2(target.x, - _vp.y * 0.4)
	spr.modulate.a = 1.0
	spr.play("jump")
	var tw: = create_tween()
	tw.tween_property(spr, "position", target, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback( func() -> void :
		spr.play("idle")
		_shake = 12.0
		_flash_screen(0.45))


func _flash_screen(strength: float) -> void :
	_flash.color.a = strength
	create_tween().tween_property(_flash, "color:a", 0.0, 0.6)


func _tween_spread(to: float) -> void :
	create_tween().tween_property(self, "_spread", to, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)



func _flag_glow() -> void :
	_cloth.color = Color(0.3, 0.9, 0.4)
	var base: = _flag.scale
	var tw: = create_tween()
	tw.tween_property(_flag, "scale", base * 1.3, 0.2)
	tw.tween_property(_flag, "scale", base, 0.25)
	var s: = _char_scale()
	if _ghost == null:
		_ghost = AnimatedSprite2D.new()
		_ghost.sprite_frames = Economy.frames_for(StoryData.skin_for("hero"))
		_ghost.play("idle")
		_ghost.modulate = Color(0.6, 1.0, 0.75, 0.0)
		_stage.add_child(_ghost)
	_ghost.scale = Vector2(s, s)
	_ghost.position = _flag.position + Vector2(14.0 * s, -12.0 * s)
	create_tween().tween_property(_ghost, "modulate:a", 0.55, 0.6)
	var bob: = create_tween().set_loops()
	bob.tween_property(_ghost, "position:y", _ghost.position.y - 5.0 * s * 0.5, 0.8)
	bob.tween_property(_ghost, "position:y", _ghost.position.y, 0.8)





func _leave() -> void :
	if _leaving:
		return
	_leaving = true
	var tw: = create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.45)
	tw.tween_callback(_leave_now)


func _leave_now() -> void :
	DayCycle.frozen = false
	SceneTransition.go(pending_next)



static func play(tree: SceneTree, pages: Array, next_scene: String) -> void :
	pending_pages = pages
	pending_next = next_scene
	SceneTransition.go(SCENE_PATH)
