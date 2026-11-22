extends RefCounted



const SIZE: = 128
const RADIUS: = 61.0
const BORDER: = 5.0
const STROKE: = 7.0

static var _cache: Dictionary = {}


static func get_texture(kind: String, pressed: bool) -> ImageTexture:
	var key: = "%s_%s" % [kind, pressed]
	if _cache.has(key):
		return _cache[key]

	var fill: = Color(0.2, 0.42, 0.95, 0.88) if pressed else Color(0.1, 0.16, 0.36, 0.78)
	var fill_top: = fill.lightened(0.22)
	var lip: = Color(0.02, 0.04, 0.12, 0.85)
	var rim: = Color(1.0, 0.86, 0.4, 1.0) if pressed else Color(0.62, 0.88, 1.0, 0.95)
	var glyph: = Color(1, 1, 1, 1.0 if pressed else 0.95)
	var segs: = _segments(kind)
	if pressed:
		for s in segs:
			s[0] += Vector2(0, 3)
			s[1] += Vector2(0, 3)

	var img: = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var c: = SIZE / 2.0
	for y in SIZE:
		for x in SIZE:
			var p: = Vector2(x + 0.5, y + 0.5)
			var d: = p.distance_to(Vector2(c, c))
			var shape_a: = clampf(RADIUS - d + 0.5, 0.0, 1.0)
			if shape_a <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var t: = clampf(d - (RADIUS - BORDER) + 0.5, 0.0, 1.0)
			var base: = fill_top.lerp(fill, clampf(p.y / SIZE, 0.0, 1.0))

			if not pressed and p.y > c + RADIUS * 0.62 and d > RADIUS - BORDER - 7.0:
				base = lip

			if not pressed and p.y < c - RADIUS * 0.45 and d < RADIUS - BORDER - 4.0:
				base = base.lightened(0.18)
			base = base.lerp(rim, t)
			base.a *= shape_a

			var dseg: = 1000.0
			for s in segs:
				dseg = minf(dseg, _dist_to_segment(p, s[0], s[1]))
			var g: = clampf(STROKE - dseg + 0.5, 0.0, 1.0) * glyph.a

			var out_a: = g + base.a * (1.0 - g)
			var out: = Color(0, 0, 0, 0)
			if out_a > 0.0:
				var rgb: = (glyph.r * g + base.r * base.a * (1.0 - g)) / out_a
				var gg: = (glyph.g * g + base.g * base.a * (1.0 - g)) / out_a
				var bb: = (glyph.b * g + base.b * base.a * (1.0 - g)) / out_a
				out = Color(rgb, gg, bb, out_a)
			img.set_pixel(x, y, out)

	var tex: = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _segments(kind: String) -> Array:
	match kind:
		"left":
			return [[Vector2(78, 36), Vector2(48, 64)], [Vector2(48, 64), Vector2(78, 92)]]
		"right":
			return [[Vector2(50, 36), Vector2(80, 64)], [Vector2(80, 64), Vector2(50, 92)]]
		_:
			return [[Vector2(36, 80), Vector2(64, 50)], [Vector2(64, 50), Vector2(92, 80)]]


static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: = b - a
	var t: = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
