extends Node2D








const StoryStateScript: = preload("res://scripts/story_state.gd")

const StoryCheats: = preload("res://scripts/story_cheats.gd")
const UIFx: = preload("res://scripts/ui_fx.gd")

const POP_COLORS: = {
	"slime": Color(0.62, 0.4, 0.9), "bat": Color(0.55, 0.4, 0.8), "thorn": Color(0.8, 0.84, 0.92), 
	"charger": Color(0.95, 0.35, 0.3), "jumper": Color(0.45, 0.9, 0.4), 
}

static var shield_ready: = false
static var dying: = false

var kind: = "slime"
var origin_x: = 0.0
var half: = 32.0
var speed_mult: = 1.0
var dead: = false
## Used by the boss arena: only draws the monster (no AI, no hits).
var visual_only: = false

var _ground_y: = 0.0
var _speed: = 28.0
var _dir: = 1.0
var _stompable: = true
var _t: = 0.0
var _phase: = 0.0
var _vy: = 0.0
var _hop: = 1.0
var _alert: = false
var _player: Node2D


func _ready() -> void :
	if visual_only:
		_phase = randf() * TAU
		return
	add_to_group("monsters")
	z_index = 3
	_phase = randf() * TAU
	_dir = 1.0 if randf() < 0.5 else -1.0
	_ground_y = position.y
	_stompable = kind != "thorn"
	match kind:
		"bat":
			_speed = 42.0
		"thorn":
			_speed = 0.0
		"charger":
			_speed = 30.0
		"jumper":
			_speed = 22.0
		_:
			_speed = 28.0
	_speed *= speed_mult


## Arena only: which way the monster looks, and whether it is angry.
func look(direction: float, alert: bool = false) -> void :
	_dir = 1.0 if direction >= 0.0 else -1.0
	_alert = alert


func _get_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("local_player") as Node2D
	return _player


func _process(delta: float) -> void :
	if visual_only:
		_t += delta
		queue_redraw()
		return
	if dead:
		return
	_t += delta
	var move: = _speed
	if kind == "charger":
		_alert = false
		var p: = _get_player()
		if p != null:
			var d: = p.global_position - global_position
			if absf(d.x) < 120.0 and absf(d.y) < 36.0:
				_alert = true
				if absf(d.x) > 2.0:
					_dir = signf(d.x)
				move = _speed * 2.8
	position.x += _dir * move * delta
	if position.x > origin_x + half:
		position.x = origin_x + half
		_dir = -1.0
	elif position.x < origin_x - half:
		position.x = origin_x - half
		_dir = 1.0
	match kind:
		"bat":
			position.y = _ground_y - 16.0 + sin(_t * 3.0 + _phase) * 4.0
		"jumper":
			_hop -= delta
			if _hop <= 0.0 and position.y >= _ground_y - 0.1:
				_vy = -150.0
				_hop = randf_range(1.0, 1.8)
			_vy += 500.0 * delta
			position.y += _vy * delta
			if position.y >= _ground_y:
				position.y = _ground_y
				_vy = 0.0
	queue_redraw()
	_check_player()


func _check_player() -> void :
	var p: = _get_player()
	if p == null:
		return
	var d: = p.global_position - global_position
	var box: = Vector2(9.0, 10.0) if kind == "thorn" else Vector2(13.0, 16.0)
	if absf(d.x) > box.x or absf(d.y) > box.y:
		return
	var body: = p as CharacterBody2D
	var airborne: = body != null and not body.is_on_floor()
	if kind == "bat" and airborne:

		if body.velocity.y > 0.0:
			body.velocity.y = -190.0
		GameAudio.play_sfx("hurt")
		kill()
	elif _stompable and airborne and body.velocity.y > 0.0 and d.y < -2.0:
		body.velocity.y = -190.0
		GameAudio.play_sfx("hurt")
		kill()
	else:
		_hit_player(p)


func _hit_player(p: Node2D) -> void :
	if StoryCheats.god:
		return
	if not shield_ready and StoryCheats.shield_charges > 0:
		StoryCheats.shield_charges -= 1
		shield_ready = true
	if shield_ready:
		shield_ready = false
		GameAudio.play_sfx("power_up")
		if _stompable:
			kill()
		else:
			_dir = - _dir
			position.x += _dir * 14.0
		return
	if dying:
		return
	dying = true
	GameAudio.play_sfx("explosion")
	StoryStateScript.respawning = true
	if p.has_method("lock_input"):
		p.call("lock_input")
	var tree: = get_tree()
	var scene_at_death: Node = tree.current_scene
	tree.create_timer(0.5).timeout.connect( func() -> void :
		dying = false
		Engine.time_scale = 1.0
		# Only restart if the player is still in the same level (not already back in a menu).
		if tree.current_scene == scene_at_death:
			tree.reload_current_scene())


func kill(force: bool = false) -> void :
	if dead or ( not _stompable and not force):
		return
	dead = true
	remove_from_group("monsters")
	UIFx.burst(get_parent(), global_position, POP_COLORS.get(kind, Color.WHITE), 14)
	var tw: = create_tween()
	tw.tween_property(self, "scale", Vector2(1.5, 0.1), 0.18)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)





func _draw() -> void :
	match kind:
		"bat":
			_draw_bat()
		"thorn":
			_draw_thorn()
		"charger":
			_draw_charger()
		"jumper":
			_draw_jumper()
		_:
			_draw_slime()


func _draw_slime() -> void :
	var u: = 2.0
	var bob: = sin(_t * 6.0 + _phase)
	var outline: = Color(0.08, 0.04, 0.14)
	var body: = Color(0.3, 0.17, 0.46)
	var light: = Color(0.48, 0.3, 0.66)
	var rows: = [4, 6, 8, 8, 8, 8]
	var top: = -7.0 + bob * 0.6
	for r in rows.size():
		var w: float = float(rows[r]) * u
		draw_rect(Rect2( - w * 0.5 - 1.0, top + float(r) * u - 0.5, w + 2.0, u + 1.0), outline)
	for r in rows.size():
		var w: float = float(rows[r]) * u
		draw_rect(Rect2( - w * 0.5, top + float(r) * u, w, u), light if r < 2 else body)
	draw_rect(Rect2(-4.0, top - 3.0, 2.0, 3.0), outline)
	draw_rect(Rect2(2.0, top - 3.0, 2.0, 3.0), outline)
	var step: = 1.0 if int(_t * 6.0 + _phase) % 2 == 0 else -1.0
	draw_rect(Rect2(-6.0, top + 12.0, 3.0, 2.0 + maxf(step, 0.0)), outline)
	draw_rect(Rect2(3.0, top + 12.0, 3.0, 2.0 + maxf( - step, 0.0)), outline)
	var glow: = Color(1.0, 0.88, 0.3)
	draw_rect(Rect2(-5.0, top + 4.0, 3.0, 3.0), glow)
	draw_rect(Rect2(2.0, top + 4.0, 3.0, 3.0), glow)
	draw_rect(Rect2(-4.0 + _dir, top + 5.0, 1.5, 1.5), outline)
	draw_rect(Rect2(3.0 + _dir, top + 5.0, 1.5, 1.5), outline)


func _draw_bat() -> void :
	var outline: = Color(0.05, 0.03, 0.1)
	var body: = Color(0.2, 0.14, 0.34)
	var wing: = Color(0.34, 0.22, 0.52)
	var flap: = sin(_t * 14.0 + _phase) * 5.0
	for s in [-1.0, 1.0]:
		var pts: = PackedVector2Array([
			Vector2(s * 3.0, -3.0), Vector2(s * 15.0, -7.0 + flap), 
			Vector2(s * 12.0, 0.0 + flap * 0.4), Vector2(s * 8.0, 3.0), Vector2(s * 3.0, 3.0)])
		draw_colored_polygon(pts, wing)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4]]), outline, 1.0)
	draw_rect(Rect2(-5.0, -5.0, 10.0, 10.0), outline)
	draw_rect(Rect2(-4.0, -4.0, 8.0, 8.0), body)
	draw_rect(Rect2(-4.0, -7.0, 2.0, 3.0), outline)
	draw_rect(Rect2(2.0, -7.0, 2.0, 3.0), outline)
	draw_rect(Rect2(-3.0, -2.0, 2.0, 2.0), Color(1.0, 0.3, 0.3))
	draw_rect(Rect2(1.0, -2.0, 2.0, 2.0), Color(1.0, 0.3, 0.3))
	draw_rect(Rect2(-2.0, 2.0, 1.0, 2.0), Color.WHITE)
	draw_rect(Rect2(1.0, 2.0, 1.0, 2.0), Color.WHITE)


func _draw_thorn() -> void :
	var outline: = Color(0.05, 0.08, 0.08)
	draw_rect(Rect2(-9.0, 0.0, 18.0, 8.0), outline)
	draw_rect(Rect2(-8.0, 1.0, 16.0, 6.0), Color(0.22, 0.3, 0.28))
	for k in 4:
		var x: = -8.0 + float(k) * 4.0
		var pts: = PackedVector2Array([Vector2(x, 1.0), Vector2(x + 2.0, -8.0), Vector2(x + 4.0, 1.0)])
		draw_colored_polygon(pts, Color(0.8, 0.84, 0.92))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2]]), outline, 1.0)
	var pulse: = 0.5 + 0.5 * sin(_t * 4.0 + _phase)
	draw_rect(Rect2(-1.0, 3.0, 2.0, 2.0), Color(1.0, 0.4 + 0.3 * pulse, 0.3))


func _draw_charger() -> void :
	var outline: = Color(0.12, 0.03, 0.04)
	var body: = Color(0.8, 0.25, 0.2) if _alert else Color(0.6, 0.24, 0.22)
	var run: = sin(_t * (22.0 if _alert else 8.0))
	draw_rect(Rect2(-9.0, -5.0, 18.0, 13.0), outline)
	draw_rect(Rect2(-8.0, -4.0, 16.0, 11.0), body)
	var hx: = _dir * 8.0
	draw_rect(Rect2(hx - 4.0, -4.0, 8.0, 9.0), outline)
	draw_rect(Rect2(hx - 3.0, -3.0, 6.0, 7.0), body.lightened(0.12))
	draw_rect(Rect2(hx + _dir * 1.0 - 1.0, -2.0, 2.0, 2.0), Color(1.0, 0.9, 0.2) if not _alert else Color(1.0, 0.1, 0.1))
	draw_rect(Rect2(hx + _dir * 3.0 - 1.0, 1.0, 2.0, 3.0), Color.WHITE)
	var horn: = PackedVector2Array([Vector2(hx - 2.0, -4.0), Vector2(hx - 1.0 + _dir * 2.0, -9.0), Vector2(hx + 2.0, -4.0)])
	draw_colored_polygon(horn, Color(0.95, 0.9, 0.8))
	draw_rect(Rect2(-7.0, 7.0, 3.0, 2.0 + maxf(run, 0.0) * 1.5), outline)
	draw_rect(Rect2(4.0, 7.0, 3.0, 2.0 + maxf( - run, 0.0) * 1.5), outline)


func _draw_jumper() -> void :
	var outline: = Color(0.03, 0.12, 0.05)
	var body: = Color(0.3, 0.72, 0.3)
	var belly: = Color(0.65, 0.92, 0.55)
	var air: = position.y < _ground_y - 1.0
	draw_rect(Rect2(-8.0, -2.0, 16.0, 10.0), outline)
	draw_rect(Rect2(-7.0, -1.0, 14.0, 8.0), body)
	draw_rect(Rect2(-4.0, 2.0, 8.0, 5.0), belly)
	draw_rect(Rect2(-7.0, -7.0, 14.0, 6.0), outline)
	draw_rect(Rect2(-6.0, -6.0, 12.0, 4.0), body)
	draw_rect(Rect2(-6.0, -9.0, 4.0, 4.0), Color.WHITE)
	draw_rect(Rect2(2.0, -9.0, 4.0, 4.0), Color.WHITE)
	draw_rect(Rect2(-4.0 + _dir, -8.0, 2.0, 2.0), outline)
	draw_rect(Rect2(4.0 + _dir, -8.0, 2.0, 2.0), outline)
	if air:
		draw_rect(Rect2(-10.0, 5.0, 4.0, 5.0), outline)
		draw_rect(Rect2(6.0, 5.0, 4.0, 5.0), outline)
	else:
		draw_rect(Rect2(-9.0, 5.0, 5.0, 3.0), outline)
		draw_rect(Rect2(4.0, 5.0, 5.0, 3.0), outline)
