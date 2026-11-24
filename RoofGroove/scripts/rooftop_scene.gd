extends Control
## Animated scene from the game for the login and loading screens: a glowing moon, two layers of
## skyline scrolling past, a rooftop and (optionally) the player's own skin running along it.
## The "ROOF GROOVE" title is cut out of the logo image and stays still.

const LOGO: Texture2D = preload("res://branding/logo_fixed.png")
const TITLE_REGION: = Rect2(150, 599, 1310, 581)
const SKY: = Color("#170d33")
const BORDER: = Color("#6b4bb0")
const FAR_COLOR: = Color("#241449")
const NEAR_COLOR: = Color("#160b2e")
const ROOF_COLOR: = Color("#0e0622")
const WINDOW_COLOR: = Color("#ffd28a")

## Set before adding to the tree.
var show_knight: = true
var show_title: = true

var _t: = 0.0
var _blink: = 0
var _blink_timer: = 0.0
var _far: Array = []
var _near: Array = []
var _far_width: = 0.0
var _near_width: = 0.0
var _layer: Control
var _knight: AnimatedSprite2D
var _title: TextureRect
var _hop_timer: = 2.2
var _hop_t: = -1.0
var _star: Dictionary = {}
var _star_timer: = 3.0


class Layer extends Control:
	var scene: Control

	func _draw() -> void :
		if scene != null:
			scene.call("paint", self)


class Frame extends Control:
	func _draw() -> void :
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = Color("#6b4bb0")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(18)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_build_city()
	_layer = Layer.new()
	_layer.scene = self
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if show_title:
		var atlas: = AtlasTexture.new()
		atlas.atlas = LOGO
		atlas.region = TITLE_REGION
		_title = TextureRect.new()
		_title.texture = atlas
		_title.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(_title)
	if show_knight:
		_knight = AnimatedSprite2D.new()
		_layer.add_child(_knight)
		Economy.bind(_knight)  # the skin the player is wearing
		_knight.speed_scale = 1.3
		_knight.play(&"run")
	var frame: = Frame.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_relayout)
	_relayout()


func _build_city() -> void :
	var rng: = RandomNumberGenerator.new()
	rng.seed = 21
	_far.clear()
	_near.clear()
	var x: = 0.0
	for i in 14:
		var bw: = rng.randf_range(34.0, 70.0)
		_far.append({"x": x, "w": bw, "h": rng.randf_range(60.0, 120.0), "seed": rng.randi()})
		x += bw + rng.randf_range(0.0, 8.0)
	_far_width = x
	x = 0.0
	for i in 12:
		var bw2: = rng.randf_range(44.0, 84.0)
		_near.append({"x": x, "w": bw2, "h": rng.randf_range(34.0, 78.0), "seed": rng.randi()})
		x += bw2 + rng.randf_range(0.0, 14.0)
	_near_width = x


func _unit() -> float:
	return clampf(size.y / 270.0, 0.5, 1.7)


func _relayout() -> void :
	var u: = _unit()
	var gy: = size.y * 0.9
	if _title != null:
		var th: = size.y * 0.5
		var tw: = minf(th * TITLE_REGION.size.x / TITLE_REGION.size.y, size.x * 0.8)
		th = tw * TITLE_REGION.size.y / TITLE_REGION.size.x
		_title.size = Vector2(tw, th)
		_title.position = Vector2((size.x - tw) * 0.5, size.y * 0.36)
	if _knight != null:
		var s: = 2.2 * u
		_knight.scale = Vector2(s, s)
		_knight.position = Vector2(size.x * 0.14, gy - 11.0 * s)


func _process(delta: float) -> void :
	_t += delta
	_blink_timer += delta
	if _blink_timer > 0.9:
		_blink_timer = 0.0
		_blink += 1
	if _knight != null:
		_hop_timer -= delta
		var s: = 2.2 * _unit()
		var gy: = size.y * 0.9
		var base: = gy - 11.0 * s
		if _hop_t >= 0.0:
			_hop_t += delta
			var k: = _hop_t / 0.7
			if k >= 1.0:
				_hop_t = -1.0
				_knight.play(&"run")
				_knight.position.y = base
			else:
				_knight.position.y = base - sin(k * PI) * 34.0 * s
		elif _hop_timer <= 0.0:
			_hop_timer = randf_range(2.6, 4.2)
			_hop_t = 0.0
			_knight.play(&"jump")
	_star_timer -= delta
	if _star.is_empty() and _star_timer <= 0.0:
		_star_timer = randf_range(3.0, 6.0)
		_star = {"x": randf_range(size.x * 0.45, size.x * 0.95), "y": randf_range(size.y * 0.05, size.y * 0.3), "t": 0.0}
	if not _star.is_empty():
		_star["t"] = float(_star["t"]) + delta
		if float(_star["t"]) > 0.7:
			_star = {}
	_layer.queue_redraw()


func _draw() -> void :
	# sky (also the shape the children are clipped to)
	var sb: = StyleBoxFlat.new()
	sb.bg_color = SKY
	sb.set_corner_radius_all(18)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))


func paint(v: Control) -> void :
	var u: = _unit()
	var w: = v.size.x
	var h: = v.size.y
	var gy: = h * 0.9
	# moon with a pulsing glow
	var pulse: = 0.5 + 0.5 * sin(_t * 1.4)
	var moon: = Vector2(w * 0.5, h * 0.3)
	var r: = h * 0.2
	v.draw_circle(moon, r * 1.7, Color(1.0, 0.7, 0.4, 0.07 + 0.04 * pulse))
	v.draw_circle(moon, r * 1.35, Color(1.0, 0.72, 0.4, 0.12 + 0.05 * pulse))
	v.draw_circle(moon, r, Color("#ffb347"))
	v.draw_circle(moon, r * 0.78, Color("#ffc968"))
	# skyline layers
	_paint_layer(v, _far, _far_width, 12.0, 0.0, u, gy, FAR_COLOR, 0.30)
	_paint_layer(v, _near, _near_width, 34.0, 1.0, u, gy, NEAR_COLOR, 0.65)
	# rooftop the player runs on
	v.draw_rect(Rect2(0.0, gy, w, h - gy), ROOF_COLOR)
	v.draw_rect(Rect2(0.0, gy, w, 4.0 * u), Color("#4a2f85"))
	var spacing: = 40.0 * u
	var shift: = fmod(_t * 90.0 * u, spacing)
	var x: = -shift
	while x < w:
		v.draw_rect(Rect2(x, gy + 12.0 * u, 20.0 * u, 3.0 * u), Color("#2c1a58"))
		x += spacing
	# shooting star
	if not _star.is_empty():
		var k: = float(_star["t"]) / 0.7
		var head: = Vector2(float(_star["x"]), float(_star["y"])) + Vector2(-1.0, 0.5) * 120.0 * k * u
		for i in 8:
			var tail: = head + Vector2(1.0, -0.5) * float(i) * 7.0 * u
			v.draw_rect(Rect2(tail, Vector2(3.0, 3.0) * u), Color(1.0, 0.95, 0.8, (1.0 - float(i) / 8.0) * (1.0 - k)))


func _paint_layer(v: Control, city: Array, pattern: float, speed: float, phase: float, u: float, gy: float, color: Color, window_alpha: float) -> void :
	var span: = pattern * u
	if span <= 1.0:
		return
	var offset: = fmod(_t * speed * u + phase * 13.0, span)
	var copies: = int(ceil(v.size.x / span)) + 2
	for c in copies:
		for b in city:
			var bx: = float(b["x"]) * u + float(c) * span - offset
			var bw: = float(b["w"]) * u
			if bx > v.size.x or bx + bw < 0.0:
				continue
			var bh: = float(b["h"]) * u
			var top: = gy - bh
			v.draw_rect(Rect2(bx, top, bw, bh + 1.0), color)
			var cols: = int(float(b["w"]) / 12.0)
			var rows: = int(float(b["h"]) / 14.0)
			var sd: = int(b["seed"]) & 0xffff
			for rr in rows:
				for cc in cols:
					var hsh: = (sd + rr * 31 + cc * 17 + (_blink if (rr + cc + sd) % 5 == 0 else 0)) % 7
					if hsh < 2:
						v.draw_rect(Rect2(bx + 5.0 * u + float(cc) * 12.0 * u, top + 7.0 * u + float(rr) * 14.0 * u, 5.0 * u, 7.0 * u), Color(WINDOW_COLOR.r, WINDOW_COLOR.g, WINDOW_COLOR.b, window_alpha))
