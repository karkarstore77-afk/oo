extends CanvasLayer





const PX: = 2


const CLOUD_A_LOW: = Color(0.82, 0.9, 0.99)
const CLOUD_B_LOW: = Color(0.76, 0.86, 0.98)
const CLOUD_C_LOW: = Color(0.7, 0.81, 0.96)


const SUN_POS: = {
	"Sunrise": Vector2(0.18, -0.07), 
	"Morning": Vector2(0.3, -0.27), 
	"Sunset": Vector2(0.8, -0.08), 
	"Night": Vector2(0.72, -0.3), 
}
const SUN_COLOR: = {
	"Sunrise": Color(1.0, 0.74, 0.42), 
	"Morning": Color(1.0, 0.98, 0.84), 
	"Sunset": Color(1.0, 0.55, 0.3), 
	"Night": Color(0.92, 0.94, 1.0), 
}
const COLOR_KEYS: = ["sky_top", "sky_mid", "sky_low", "far_body", "near_body", "cloud_tint", "window"]
const BLEND_SPEED: = 1.6
const STAR_COUNT: = 70

static var _cache: Dictionary = {}

var _cur: Dictionary = {}
var _target: Dictionary = {}
var _target_time: = "Morning"
var _sun_pos: = Vector2(0.3, -0.27)
var _sun_col: = Color(1.0, 0.98, 0.84)
var _night: = 0.0
var _night_target: = 0.0
var _stars: Array = []

var _canvas: Control
var _layers: Array = []
var _time: = 0.0
var _base_cam_y: = INF


func _ready() -> void :
	layer = -10
	_make_stars()
	DayCycle.time_changed.connect(_on_time_changed)
	_on_time_changed(DayCycle.get_time_name())
	_cur = _target.duplicate()
	_sun_pos = SUN_POS[_target_time]
	_sun_col = SUN_COLOR[_target_time]
	_night = _night_target

	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_on_canvas_draw)

	_build_layers()


func _make_stars() -> void :
	var rng: = RandomNumberGenerator.new()
	rng.seed = 77
	for i in STAR_COUNT:
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.4, 1.0)))


func _on_time_changed(time_name: String) -> void :
	_target = DayCycle.get_colors()
	_target_time = time_name if SUN_POS.has(time_name) else "Morning"
	_night_target = 1.0 if _target_time == "Night" else 0.0


func _process(delta: float) -> void :
	_time += delta
	var k: = 1.0 - exp( - BLEND_SPEED * delta)
	for key in COLOR_KEYS:
		if _target.has(key) and _cur.has(key):
			_cur[key] = (_cur[key] as Color).lerp(_target[key], k)
	_sun_pos = _sun_pos.lerp(SUN_POS[_target_time], k)
	_sun_col = _sun_col.lerp(SUN_COLOR[_target_time], k)
	_night = lerpf(_night, _night_target, k)
	_canvas.queue_redraw()





func _build_layers() -> void :
	_layers = [
		{"kind": "wisp", "tex": _tex("wisps", func(): return _make_wisps(1024, 90, 11)), "win": null, "low": null, 
			"fx": 0.01, "drift": 5.0, "y": -0.34, "vy": 0.2, "bottom": false}, 
		{"kind": "far", "tex": _tex("far", func(): return _make_skyline(1024, 170, Color.WHITE, Color.WHITE, 0.0, 14, 26, 50, 105, 0, 8, 7)), 
			"win": _tex("far_w", func(): return _make_skyline(1024, 170, Color(0, 0, 0, 0), Color.WHITE, 0.1, 14, 26, 50, 105, 0, 8, 7)), "low": null, 
			"fx": 0.02, "drift": 0.0, "y": 0.18, "vy": 0.35, "bottom": true}, 
		{"kind": "cloud", "tex": _tex("cloud_a", func(): return _make_cloud_sea(1024, 120, Color(1.0, 1.0, 1.0), Color(0.98, 0.99, 1.0), Color(0.9, 0.95, 1.0), CLOUD_A_LOW, 6.0, 5.0, 2.0, 21)), 
			"win": null, "low": CLOUD_A_LOW, 
			"fx": 0.045, "drift": 3.0, "y": 0.06, "vy": 0.55, "bottom": false}, 
		{"kind": "near", "tex": _tex("near", func(): return _make_skyline(1024, 240, Color.WHITE, Color.WHITE, 0.0, 22, 40, 70, 120, 4, 14, 3)), 
			"win": _tex("near_w", func(): return _make_skyline(1024, 240, Color(0, 0, 0, 0), Color.WHITE, 0.16, 22, 40, 70, 120, 4, 14, 3)), "low": null, 
			"fx": 0.06, "drift": 0.0, "y": 0.3, "vy": 0.75, "bottom": true}, 
		{"kind": "cloud", "tex": _tex("cloud_b", func(): return _make_cloud_sea(1024, 120, Color(1.0, 1.0, 1.0), Color(0.97, 0.98, 1.0), Color(0.86, 0.92, 0.99), CLOUD_B_LOW, 7.0, 6.0, 2.0, 33)), 
			"win": null, "low": CLOUD_B_LOW, 
			"fx": 0.09, "drift": 6.0, "y": 0.17, "vy": 0.85, "bottom": false}, 
		{"kind": "cloud", "tex": _tex("cloud_c", func(): return _make_cloud_sea(1024, 120, Color(0.97, 0.99, 1.0), Color(0.92, 0.95, 1.0), Color(0.8, 0.88, 0.98), CLOUD_C_LOW, 8.0, 6.0, 3.0, 47)), 
			"win": null, "low": CLOUD_C_LOW, 
			"fx": 0.15, "drift": 10.0, "y": 0.3, "vy": 1.0, "bottom": false}, 
	]


func _tex(key: String, builder: Callable) -> Texture2D:
	if not _cache.has(key):
		_cache[key] = builder.call()
	return _cache[key]





func _on_canvas_draw() -> void :
	var vp: = _canvas.size
	if vp.x < 2.0 or vp.y < 2.0:
		return
	var s: = vp.y / 648.0
	var horizon: = vp.y * 0.5

	var cam_x: = 0.0
	var shift: = 0.0
	var cam: = get_viewport().get_camera_2d()
	var tilt: Vector2 = GyroTilt.tilt * (0.35 if cam != null else 1.0)
	if cam != null:
		var center: = cam.get_screen_center_position()
		var zoom: = cam.zoom.x
		if _base_cam_y == INF:
			_base_cam_y = center.y
		cam_x = center.x * zoom
		shift = clampf( - (center.y - _base_cam_y) * zoom * 0.03, - vp.y * 0.25, vp.y * 0.25)


	var sky_top: Color = _cur["sky_top"]
	var sky_mid: Color = _cur["sky_mid"]
	var sky_low: Color = _cur["sky_low"]
	var mid_y: = horizon * 0.55
	_gradient_quad(0.0, mid_y + 1.0, vp.x, sky_top, sky_mid)
	_gradient_quad(mid_y, horizon + 1.0, vp.x, sky_mid, sky_low)
	_canvas.draw_rect(Rect2(0, horizon, vp.x, vp.y - horizon), sky_low)


	if _night > 0.02:
		for st in _stars:
			var star: Vector3 = st
			var twinkle: = 0.75 + 0.25 * sin(_time * 2.0 + star.x * 40.0)
			var a: = _night * star.z * twinkle
			var sz: = maxf(2.0, roundf(2.0 * s))
			_canvas.draw_rect(Rect2(roundf(star.x * vp.x), roundf(star.y * horizon * 0.85), sz, sz), Color(1, 1, 1, a))


	var sun: = Vector2(vp.x * _sun_pos.x, horizon + vp.y * _sun_pos.y + shift * 0.1) - tilt * 26.0 * s
	for i in 8:
		var t: = float(i) / 7.0
		_canvas.draw_circle(sun, lerpf(190.0, 52.0, t) * s, Color(_sun_col.r, _sun_col.g, _sun_col.b, 0.035))
	_canvas.draw_circle(sun, 42.0 * s, _sun_col)


	for entry in _layers:
		var L: Dictionary = entry
		var tex: Texture2D = L["tex"]
		var tw: = float(tex.get_width() * PX)
		var th: = float(tex.get_height() * PX)
		var y: = horizon + vp.y * float(L["y"]) + shift * float(L["vy"])
		if L["bottom"]:
			y -= th
		var depth: = float(L["fx"]) / 0.15
		y = roundf(y + tilt.y * 14.0 * s * depth)

		var tint: = Color.WHITE
		var fill: Variant = null
		match str(L["kind"]):
			"far":
				tint = _cur["far_body"]
				fill = tint
			"near":
				tint = _cur["near_body"]
				fill = tint
			"cloud":
				tint = _cur["cloud_tint"]
				fill = (L["low"] as Color) * tint
			"wisp":
				tint = _cur["cloud_tint"]

		var win: Variant = L["win"]
		var win_tint: Color = _cur["window"]
		var scroll: = cam_x * float(L["fx"]) + _time * float(L["drift"]) + tilt.x * 90.0 * s * depth
		var x: = roundf( - fposmod(scroll, tw))
		while x < vp.x:
			var rect: = Rect2(x, y, tw, th)
			_canvas.draw_texture_rect(tex, rect, false, tint)
			if win != null:
				_canvas.draw_texture_rect(win as Texture2D, rect, false, win_tint)
			x += tw
		if fill is Color and y + th < vp.y:
			_canvas.draw_rect(Rect2(0, y + th - 1.0, vp.x, vp.y - (y + th) + 1.0), fill)


func _gradient_quad(y0: float, y1: float, w: float, c0: Color, c1: Color) -> void :
	_canvas.draw_polygon(
		PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0, y1)]), 
		PackedColorArray([c0, c0, c1, c1]))





static func _make_skyline(w: int, h: int, body: Color, window: Color, lit: float, 
		min_w: int, max_w: int, min_h: int, max_h: int, gap_min: int, gap_max: int, seed_value: int) -> ImageTexture:
	var img: = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng: = RandomNumberGenerator.new()
	rng.seed = seed_value
	var x: = rng.randi_range(0, 10)
	while x < w:
		var bw: = rng.randi_range(min_w, max_w)
		if x + bw >= w:
			break
		var bh: = rng.randi_range(min_h, max_h)
		if rng.randf() < 0.14:
			bh = mini(int(bh * 1.55), h - 26)
		var top: = h - bh
		img.fill_rect(Rect2i(x, top, bw, bh), body)
		img.fill_rect(Rect2i(x, top, 1, bh), body.lightened(0.14))

		var style: = rng.randf()
		if style < 0.28 and top >= 20:
			var ah: = rng.randi_range(8, 18)
			img.fill_rect(Rect2i(x + (bw >> 1), top - ah, 1, ah), body)
		elif style < 0.55 and top >= 24:
			var sh: = rng.randi_range(6, 14)
			img.fill_rect(Rect2i(x + 3, top - sh, bw - 6, sh), body)

		var wy: = top + 5
		var limit: = mini(h - 4, top + 110)
		while wy < limit:
			var wx: = x + 3
			while wx < x + bw - 3:
				if rng.randf() < lit:
					img.fill_rect(Rect2i(wx, wy, 2, 2), window)
				wx += 4
			wy += 5

		x += bw + rng.randi_range(gap_min, gap_max)
	return ImageTexture.create_from_image(img)


static func _make_cloud_sea(w: int, h: int, rim: Color, top: Color, mid: Color, low: Color, 
		amp_a: float, amp_b: float, amp_c: float, seed_value: int) -> ImageTexture:
	var img: = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng: = RandomNumberGenerator.new()
	rng.seed = seed_value
	var p1: = rng.randf() * TAU
	var p2: = rng.randf() * TAU
	var p3: = rng.randf() * TAU
	var k1: = rng.randi_range(4, 6)
	var k2: = rng.randi_range(11, 14)
	var k3: = rng.randi_range(27, 33)
	var total: = amp_a + amp_b + amp_c
	for x in w:
		var a: = TAU * float(x) / float(w)
		var prof: = amp_a * absf(sin(a * k1 + p1)) + amp_b * absf(sin(a * k2 + p2)) + amp_c * absf(sin(a * k3 + p3))
		var y0: = int(total - prof)
		var body_h: = h - y0
		var y1: = y0 + 2
		var y2: = y0 + int(body_h * 0.28)
		var y3: = y0 + int(body_h * 0.62)
		img.fill_rect(Rect2i(x, y0, 1, 2), rim)
		img.fill_rect(Rect2i(x, y1, 1, maxi(0, y2 - y1)), top)
		img.fill_rect(Rect2i(x, y2, 1, maxi(0, y3 - y2)), mid)
		img.fill_rect(Rect2i(x, y3, 1, maxi(0, h - y3)), low)
	return ImageTexture.create_from_image(img)


static func _make_wisps(w: int, h: int, seed_value: int) -> ImageTexture:
	var img: = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng: = RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 7:
		var rx: = rng.randi_range(40, 110)
		var ry: = rng.randi_range(3, 7)
		var cx: = rng.randi_range(rx + 2, w - rx - 2)
		var cy: = rng.randi_range(ry + 2, h - ry - 2)
		var col: = Color(1.0, 1.0, 1.0, rng.randf_range(0.3, 0.55))
		for yy in range( - ry, ry + 1):
			var hw: = int(rx * sqrt(1.0 - pow(float(yy) / float(ry), 2.0)))
			img.fill_rect(Rect2i(cx - hw, cy + yy, hw * 2, 1), col)
	return ImageTexture.create_from_image(img)
