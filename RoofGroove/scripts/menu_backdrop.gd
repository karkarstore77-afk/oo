extends RefCounted
## Night-sky background shared by the loading and login screens: gradient + twinkling stars.


static func add(parent: Control) -> void :
	var gradient: = Gradient.new()
	gradient.colors = PackedColorArray([Color("#0b0719"), Color("#1e1040"), Color("#3a1d5c")])
	gradient.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	var tex: = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	var bg: = TextureRect.new()
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng: = RandomNumberGenerator.new()
	rng.randomize()
	var area: = parent.get_viewport_rect().size
	for i in 48:
		var star: = ColorRect.new()
		var px: = 2.0 if rng.randf() < 0.7 else 3.0
		star.size = Vector2(px, px)
		star.position = Vector2(rng.randf_range(0.0, area.x), rng.randf_range(0.0, area.y * 0.78))
		star.color = Color(1.0, 0.96, 0.85, rng.randf_range(0.3, 0.95))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(star)
		var tw: Tween = star.create_tween().set_loops()
		tw.tween_interval(rng.randf_range(0.0, 2.0))
		tw.tween_property(star, "modulate:a", 0.15, rng.randf_range(0.8, 1.8))
		tw.tween_property(star, "modulate:a", 1.0, rng.randf_range(0.8, 1.8))
