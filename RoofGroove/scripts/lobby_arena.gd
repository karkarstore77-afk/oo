extends Node2D


var half_width: = 170.0
var floor_y: = 16.0
const PLATFORMS: = [Rect2(-95, -26, 56, 6), Rect2(40, -52, 56, 6)]


func _ready() -> void :
	var body: = StaticBody2D.new()
	add_child(body)
	_add_box(body, Rect2( - half_width - 20, floor_y, half_width * 2 + 40, 40))
	_add_box(body, Rect2( - half_width - 20, -400, 20, 500))
	_add_box(body, Rect2(half_width, -400, 20, 500))
	for p in PLATFORMS:
		_add_box(body, p, true)


func _add_box(body: StaticBody2D, r: Rect2, one_way: bool = false) -> void :
	var cs: = CollisionShape2D.new()
	var shape: = RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.position + r.size / 2.0
	cs.one_way_collision = one_way
	body.add_child(cs)


func _draw() -> void :
	var c: Dictionary = DayCycle.get_colors()
	var ground: Color = c["near_body"]
	var top_col: Color = c["far_body"].lightened(0.2)
	draw_rect(Rect2( - half_width - 20, floor_y, half_width * 2 + 40, 40), ground.darkened(0.35))
	draw_rect(Rect2( - half_width - 20, floor_y, half_width * 2 + 40, 3), top_col)
	for p in PLATFORMS:
		draw_rect(p, ground.darkened(0.2))
		draw_rect(Rect2(p.position, Vector2(p.size.x, 2)), top_col)
