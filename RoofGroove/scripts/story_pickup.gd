extends Node2D



signal collected(kind: String)

const FX: = preload("res://scripts/story_effects.gd")
const UIFx: = preload("res://scripts/ui_fx.gd")

const COLORS: = {
	"jump": Color(1.0, 0.82, 0.25), "speed": Color(0.24, 0.86, 0.52), "float": Color(0.5, 0.9, 1.0), 
	"slow": Color(0.58, 0.36, 1.0), "weak": Color(1.0, 0.36, 0.36), "heavy": Color(0.72, 0.4, 0.2), 
}

var kind: = "jump"
var _t: = 0.0
var _taken: = false
var _player: Node2D


func _ready() -> void :
	add_to_group("pickups")
	z_index = 3
	_t = randf() * TAU


func _process(delta: float) -> void :
	if _taken:
		return
	_t += delta
	queue_redraw()
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("local_player") as Node2D
		if _player == null:
			return
	if _player.global_position.distance_to(global_position) < 14.0:
		_taken = true
		FX.apply(kind)
		GameAudio.play_sfx("power_up" if bool(FX.DEFS[kind]["good"]) else "hurt")
		collected.emit(kind)
		UIFx.burst(get_parent(), global_position, COLORS.get(kind, Color.WHITE), 16, 110.0)
		queue_free()


func _draw() -> void :
	var c: Color = COLORS.get(kind, Color.WHITE)
	var good: = kind in ["jump", "speed", "float"]
	var bob: = sin(_t * 3.0) * 2.0
	var r: = 9.0 + sin(_t * 5.0) * 0.8
	draw_circle(Vector2(0, bob), r + 3.0, Color(c.r, c.g, c.b, 0.25))
	draw_circle(Vector2(0, bob), r, Color(0.05, 0.05, 0.12))
	draw_circle(Vector2(0, bob), r - 1.5, c)
	if not good:
		for k in 8:
			var a: = TAU * float(k) / 8.0 + _t
			var p: = Vector2(cos(a), sin(a)) * (r + 2.0) + Vector2(0, bob)
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(0.05, 0.02, 0.1))
	var w: = Color(1, 1, 1)
	var o: = Vector2(0, bob)
	match kind:
		"jump":
			draw_colored_polygon(PackedVector2Array([o + Vector2(0, -5), o + Vector2(-4, 1), o + Vector2(4, 1)]), w)
			draw_rect(Rect2(o + Vector2(-1.5, 1), Vector2(3, 4)), w)
		"speed":
			for dx in [-3.0, 1.0]:
				draw_polyline(PackedVector2Array([o + Vector2(dx, -4), o + Vector2(dx + 3, 0), o + Vector2(dx, 4)]), w, 2.0)
		"float":
			draw_colored_polygon(PackedVector2Array([o + Vector2(0, -5), o + Vector2(-3, -1), o + Vector2(3, -1)]), w)
			draw_circle(o + Vector2(0, 3), 2.0, w)
		"slow":
			draw_rect(Rect2(o + Vector2(-4, -4), Vector2(3, 8)), w)
			draw_rect(Rect2(o + Vector2(1, -4), Vector2(3, 8)), w)
		"weak":
			draw_colored_polygon(PackedVector2Array([o + Vector2(0, 5), o + Vector2(-4, -1), o + Vector2(4, -1)]), w)
			draw_rect(Rect2(o + Vector2(-1.5, -5), Vector2(3, 4)), w)
		"heavy":
			draw_rect(Rect2(o + Vector2(-4, -3), Vector2(8, 7)), w)
			draw_rect(Rect2(o + Vector2(-2, -5), Vector2(4, 2)), w)
