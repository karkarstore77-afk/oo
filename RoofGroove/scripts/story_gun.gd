extends CanvasLayer


class Bullet extends Node2D:
	var dir: = 1.0
	var life: = 1.1

	func _process(delta: float) -> void :
		life -= delta
		position.x += dir * 380.0 * delta
		for n in get_tree().get_nodes_in_group("monsters"):
			var m: = n as Node2D
			if m != null and m.global_position.distance_to(global_position) < 13.0:
				m.call("kill", true)
				queue_free()
				return
		if life <= 0.0:
			queue_free()
		queue_redraw()

	func _draw() -> void :
		draw_rect(Rect2(-4.0, -1.5, 8.0, 3.0), Color(1.0, 0.92, 0.35))
		draw_rect(Rect2(-7.0, -1.0, 3.0, 2.0), Color(1.0, 0.5, 0.1))

var _cd: = 0.0
var _btn: Button


func _ready() -> void :
	layer = 11
	_btn = Button.new()
	_btn.text = "FIRE"
	_btn.theme_type_variation = &"DangerButton"
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.visible = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	_btn.button_down.connect(fire)
	add_child(_btn)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void :
	var vp: = get_viewport().get_visible_rect().size
	var d: = vp.y * 0.2
	_btn.custom_minimum_size = Vector2(d * 0.9, d * 0.55)
	_btn.size = _btn.custom_minimum_size
	_btn.position = Vector2(vp.x * 0.03, vp.y - d * 2.2)
	_btn.add_theme_font_size_override("font_size", clampi(int(d * 0.22), 12, 28))


func _process(delta: float) -> void :
	_cd -= delta


func _unhandled_input(event: InputEvent) -> void :
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		fire()


func fire() -> void :
	if _cd > 0.0 or get_tree().paused:
		return
	var p: = get_tree().get_first_node_in_group("local_player") as Node2D
	if p == null:
		return
	_cd = 0.25
	var face: = 1.0
	var an: Variant = p.get("anim")
	if an != null and bool(an.flip_h):
		face = -1.0
	var b: = Bullet.new()
	b.dir = face
	p.get_parent().add_child(b)
	b.global_position = p.global_position + Vector2(face * 10.0, -2.0)
	GameAudio.play_sfx("tap")
