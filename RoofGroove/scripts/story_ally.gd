extends Node2D



const StoryData: = preload("res://scripts/story_data.gd")

const TIP_GAP_MS: = 5000
const WARN_RANGE: = 150.0

static var _last_say_ms: = -100000
static var _warned: Dictionary = {}

var skin: = ""
var slot: = 0
var end_island: = 0

var _spr: AnimatedSprite2D
var _player: Node2D
var _t: = 0.0
var _idle_cd: = 10.0
var _placed: = false
var _leaving: = false


func _ready() -> void :
	z_index = 4
	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = Economy.frames_for(skin)
	_spr.play("idle")
	_spr.modulate.a = 0.0
	add_child(_spr)
	create_tween().tween_property(_spr, "modulate:a", 0.85, 0.5)
	_idle_cd = 9.0 + float(slot) * 4.0


func depart() -> void :
	if _leaving:
		return
	_leaving = true
	var tw: = create_tween()
	tw.tween_property(_spr, "modulate:a", 0.0, 1.0)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void :
	_t += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("local_player") as Node2D
		if _player == null:
			return
	var flip: = false
	var an: Variant = _player.get("anim")
	if an != null:
		flip = bool(an.flip_h)
	var face: = -1.0 if flip else 1.0
	var target: = _player.global_position + Vector2( - face * (24.0 + 20.0 * float(slot)), -16.0 + sin(_t * 3.0 + float(slot)) * 3.0)
	if not _placed or global_position.distance_to(target) > 320.0:
		global_position = target
		_placed = true
	var before: = global_position
	global_position = global_position.lerp(target, 1.0 - exp(-6.0 * delta))
	var spd: = (global_position - before).length() / maxf(delta, 0.001)
	_spr.flip_h = flip
	var want: = &"run" if spd > 30.0 else &"idle"
	if _spr.animation != want:
		_spr.play(want)
	if _leaving:
		return

	_idle_cd -= delta
	var now: = Time.get_ticks_msec()
	if now - _last_say_ms < TIP_GAP_MS:
		return
	var m: = _monster_ahead(face)
	if m != null and not _warned.has(m.get_instance_id()):
		_warned[m.get_instance_id()] = true
		_say(StoryData.pick(StoryData.kind_tip(str(m.get("kind")))))
		_idle_cd = maxf(_idle_cd, 8.0)
	elif _idle_cd <= 0.0:
		var tips: = StoryData.tips(skin)
		if not tips.is_empty():
			_say(StoryData.pick(tips[randi() % tips.size()]))
		_idle_cd = randf_range(16.0, 24.0) + 3.0 * float(slot)


func _monster_ahead(face: float) -> Node2D:
	var best: Node2D = null
	var best_d: = WARN_RANGE
	for n in get_tree().get_nodes_in_group("monsters"):
		var m: = n as Node2D
		if m == null:
			continue
		var dx: = (m.global_position.x - global_position.x) * face
		if dx <= 0.0 or dx > best_d or absf(m.global_position.y - global_position.y) > 70.0:
			continue
		best_d = dx
		best = m
	return best


func _say(text: String) -> void :
	_last_say_ms = Time.get_ticks_msec()
	var w: = get_parent()
	if w != null and w.has_method("show_tip"):
		w.call("show_tip", skin, text)
